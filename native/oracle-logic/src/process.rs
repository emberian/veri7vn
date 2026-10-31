//! Native executable adapter. Bounds pipes, time and checker work, but is NOT
//! a sandbox or hard address-space limit. Host must supply OS containment.
use crate::*;
use std::io::{Read, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::thread;

fn read_bounded(
    mut pipe: impl Read,
    cap: usize,
    overflow: Arc<AtomicBool>,
) -> std::io::Result<Vec<u8>> {
    let mut bytes = Vec::new();
    pipe.by_ref()
        .take(cap.saturating_add(1) as u64)
        .read_to_end(&mut bytes)?;
    if bytes.len() > cap {
        overflow.store(true, Ordering::Relaxed);
    }
    Ok(bytes)
}

fn solve(
    executable: &Path,
    program: String,
    model_limit: usize,
    l: &Limits,
    budget: &mut Budget<'_>,
) -> Result<Vec<u8>, Error> {
    budget.tick()?;
    let mut child = Command::new(executable)
        .args(["--outf=2", "--warn=none", "--parallel-mode=1"])
        .arg(format!("--models={model_limit}"))
        .arg("-")
        .env_clear()
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|_| Error::Backend("cannot launch pinned clingo"))?;
    let mut stdin = child.stdin.take().expect("piped stdin");
    let stdout = child.stdout.take().expect("piped stdout");
    let stderr = child.stderr.take().expect("piped stderr");
    let overflow = Arc::new(AtomicBool::new(false));
    let out_over = overflow.clone();
    let err_over = overflow.clone();
    let cap = l.output_bytes;
    let writer = thread::spawn(move || stdin.write_all(program.as_bytes()));
    let out = thread::spawn(move || read_bounded(stdout, cap, out_over));
    let err = thread::spawn(move || read_bounded(stderr, cap.min(65536), err_over));
    let completion = loop {
        if let Err(e) = budget.tick() {
            break Err(e);
        }
        if overflow.load(Ordering::Relaxed) {
            break Err(Error::Limit("solver pipe bytes"));
        }
        match child.try_wait() {
            Ok(Some(status)) => break Ok(status),
            Ok(None) => thread::sleep(Duration::from_millis(2)),
            Err(_) => break Err(Error::Backend("wait failed")),
        }
    };
    // Always stop/reap only our child before joining bounded pipe readers.
    if completion.is_err() {
        let _ = child.kill();
    }
    let _ = child.wait();
    let written = writer.join().map_err(|_| Error::Backend("stdin thread"));
    let stdout = out.join().map_err(|_| Error::Backend("stdout thread"));
    let stderr = err.join().map_err(|_| Error::Backend("stderr thread"));
    let status = completion?;
    written?.map_err(|_| Error::Backend("stdin write"))?;
    let stdout = stdout?.map_err(|_| Error::Backend("stdout read"))?;
    let stderr = stderr?.map_err(|_| Error::Backend("stderr read"))?;
    if overflow.load(Ordering::Relaxed) {
        return Err(Error::Limit("solver pipe bytes"));
    }
    budget.charge_output(
        stdout
            .len()
            .checked_add(stderr.len())
            .ok_or(Error::Limit("pipe bytes"))?,
    )?;
    // Compare the carried exit bitset with the JSON before any absence claim.
    let code = status
        .code()
        .ok_or(Error::Backend("solver terminated by signal"))?;
    validate_solver_exit(&stdout, code)?;
    Ok(stdout)
}

fn save_model(models: &mut Vec<Vec<usize>>, m: Vec<usize>, l: &Limits) -> Result<usize, Error> {
    if let Some(i) = models.iter().position(|old| old == &m) {
        return Ok(i);
    }
    if models.len() >= l.models {
        return Err(Error::Limit("witness model bound"));
    }
    models.push(m);
    Ok(models.len() - 1)
}

fn query(
    p: &Request,
    executable: &Path,
    program: &str,
    l: &Limits,
    budget: &mut Budget<'_>,
) -> Result<Reply, Error> {
    let bytes = solve(executable, program.into(), 1, l, budget)?;
    let first = decode_probe(p, &bytes, l, budget)?;
    let Some(first) = first else {
        return Ok(Reply {
            scope: p.scope.clone(),
            status: Status::Inconsistent,
            reason: "solver-trusted consistency probe UNSAT".into(),
            enumeration_complete: false,
            completeness_trust: "solver_trusted_query_unsat_no_certificate",
            witness_check: "handwritten_gl_reduct",
            models: vec![],
            answers: p
                .queries
                .iter()
                .map(|&atom| Answer {
                    atom,
                    skeptical: None,
                    credulous: None,
                    true_witness: None,
                    false_witness: None,
                })
                .collect(),
        });
    };
    let mut models = Vec::new();
    save_model(&mut models, first, l)?;
    let mut answers = Vec::new();
    for &atom in &p.queries {
        let mut next = || -> Result<Answer, Error> {
            budget.tick()?;
            // Existing checked witnesses can settle both existential directions.
            let mut yes = models.iter().position(|m| m.binary_search(&atom).is_ok());
            let mut no = models.iter().position(|m| m.binary_search(&atom).is_err());
            if yes.is_none() || no.is_none() {
                let seek_true = yes.is_none();
                let constraint = if seek_true {
                    format!(":-not a{atom}.\n")
                } else {
                    format!(":-a{atom}.\n")
                };
                let mut source = program.to_owned();
                source.push_str(&constraint);
                budget.tick()?;
                let bytes = solve(executable, source, 1, l, budget)?;
                if let Some(m) = decode_probe(p, &bytes, l, budget)? {
                    // Checking the original program plus requested polarity is
                    // equivalent to checking this integrity-constrained program.
                    if m.binary_search(&atom).is_ok() != seek_true {
                        return Err(Error::Witness("probe polarity"));
                    }
                    let index = save_model(&mut models, m, l)?;
                    if seek_true {
                        yes = Some(index);
                    } else {
                        no = Some(index);
                    }
                }
            }
            Ok(Answer {
                atom,
                skeptical: Some(no.is_none()),
                credulous: Some(yes.is_some()),
                true_witness: yes,
                false_witness: no,
            })
        };
        match next() {
            Ok(answer) => answers.push(answer),
            Err(error) => return Ok(partial_query(p, &error.to_string(), models, answers)),
        }
    }
    if answers.iter().any(|a| {
        models.iter().any(|m| {
            let contains = m.binary_search(&a.atom).is_ok();
            (a.skeptical == Some(true) && !contains) || (a.credulous == Some(false) && contains)
        })
    }) {
        return Ok(partial_query(
            p,
            "checked witness contradicts earlier solver UNSAT",
            models,
            answers,
        ));
    }
    Ok(Reply {
        scope: p.scope.clone(),
        status: Status::Consistent,
        reason: "consistency witness and bounded opposite-polarity satisfiability probes".into(),
        enumeration_complete: false,
        completeness_trust: "solver_trusted_query_unsat_no_certificate",
        witness_check: "handwritten_gl_reduct",
        models,
        answers,
    })
}

/// Operator-pinned absolute executable; no request-owned paths/flags or shell.
/// All solves share one deadline, output allowance and checker-work budget.
/// Native executable must not spawn descendants; production needs host limits.
pub fn call(
    input: &str,
    executable: &Path,
    l: &Limits,
    cancel: &dyn WorkControl,
) -> Result<String, Error> {
    // Deadline includes bounded JSON decoding/validation and source encoding.
    let mut budget = Budget::new(l, cancel);
    let p = parse(input, l)?;
    let reply = execute_with_budget(&p, executable, l, &mut budget)?;
    serde_json::to_string(&reply).map_err(|_| Error::Backend("reply JSON"))
}

/// Typed invocation keeps solver bytes at the actual subprocess boundary.
pub fn execute(
    p: &Request,
    executable: &Path,
    l: &Limits,
    control: &dyn WorkControl,
) -> Result<Reply, Error> {
    let mut budget = Budget::new(l, control);
    validate(p, l)?;
    execute_with_budget(p, executable, l, &mut budget)
}

fn execute_with_budget(
    p: &Request,
    executable: &Path,
    l: &Limits,
    budget: &mut Budget<'_>,
) -> Result<Reply, Error> {
    if !executable.is_absolute() {
        return Err(Error::Invalid("absolute pinned executable required"));
    }
    let mut run = || -> Result<Reply, Error> {
        budget.tick()?;
        // Charge all input literals/rules before encoding. Bounded encoding is
        // followed by another deadline check before any process is launched.
        for r in &p.rules {
            budget.tick()?;
            for _ in r.positive.iter().chain(&r.negative) {
                budget.tick()?;
            }
        }
        let program = encode(&p);
        budget.tick()?;
        match p.operation {
            Operation::Query => query(&p, executable, &program, l, budget),
            Operation::Enumerate => {
                let count = l.models.checked_add(1).ok_or(Error::Limit("model bound"))?;
                let bytes = solve(executable, program, count, l, budget)?;
                decode(&p, &bytes, l, budget)
            }
        }
    };
    let reply = match run() {
        Ok(r) => r,
        Err(e) => inconclusive(&p, &e.to_string()),
    };
    let text = serde_json::to_string(&reply).map_err(|_| Error::Backend("reply JSON"))?;
    if text.len() > l.output_bytes {
        return Err(Error::Limit("reply bytes"));
    }
    Ok(reply)
}
