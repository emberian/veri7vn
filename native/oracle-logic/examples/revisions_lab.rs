//! Supplied incident evidence -> native revisions -> immutable query exports.
//! Optional operator-selected fresh solver; no action authority or persistence.
use oracle_logic::{revisions::*, Limits};
use serde::Deserialize;
use serde_json::json;
use std::{error::Error, path::PathBuf, sync::atomic::AtomicBool};
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Scenario {
    scope: ScopeKey,
    history: Vec<Revision>,
    queries: Vec<String>,
    gold_safe: Vec<bool>,
    authority: String,
}
fn main() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args().skip(1);
    let mut path = None;
    let mut solver = None;
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--input" => path = Some(PathBuf::from(args.next().ok_or("missing input path")?)),
            "--solver" => solver = Some(PathBuf::from(args.next().ok_or("missing solver path")?)),
            _ => return Err(
                "usage: revisions_lab [--input history.json] [--solver /operator/pinned/clingo]"
                    .into(),
            ),
        }
    }
    let text = if let Some(path) = path {
        if std::fs::metadata(&path)?.len() > 256 * 1024 {
            return Err("scenario byte limit".into());
        }
        std::fs::read_to_string(path)?
    } else {
        include_str!("../../../tools/usage/specialist/revisable-evidence/incident-history.json")
            .into()
    };
    let scenario: Scenario = serde_json::from_str(&text)?;
    if scenario.authority != "advice_only_supplied_fixture"
        || scenario.history.len() != scenario.gold_safe.len()
        || scenario.queries != ["safe"]
    {
        return Err("expected supplied incident fixture and one safe query".into());
    }
    if solver.as_ref().is_some_and(|p| !p.is_absolute()) {
        return Err("operator solver path must be absolute".into());
    }
    let mut workspace = Workspace::new(scenario.scope)?;
    let limits = Limits::default();
    let control = AtomicBool::new(false);
    let mut rows = Vec::new();
    for (change, gold) in scenario.history.into_iter().zip(scenario.gold_safe) {
        let commit = workspace.apply(change, 256)?;
        let prepared = workspace
            .snapshot()
            .prepare(scenario.queries.clone(), &limits)?;
        let result = if let Some(solver) = &solver {
            let evaluated = prepared.evaluate(solver, &limits, &control)?;
            let actual = evaluated.reply.answers.first().and_then(|a| a.skeptical);
            if actual != Some(gold) {
                return Err(format!(
                    "revision {} safe gold mismatch or incomplete solve: {:?} expected {}",
                    commit.revision, actual, gold
                )
                .into());
            }
            Some(serde_json::to_value(evaluated.reply)?)
        } else {
            None
        };
        rows.push(json!({"commit":commit,"request":prepared.request(),"receipt":prepared.receipt(),"support_templates":prepared.supports(),"gold_safe":gold,"fresh_result":result}));
    }
    let encoded = serde_json::to_string_pretty(&rows)?;
    if encoded.len() > 2 * 1024 * 1024 {
        return Err("export byte limit".into());
    }
    println!("{encoded}");
    Ok(())
}
