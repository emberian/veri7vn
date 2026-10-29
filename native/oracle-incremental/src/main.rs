//! Finite JSON provider and deliberately small comparison harness.
use oracle_incremental::{
    call_json, catalog, evaluate, recompute, Limits, Request, MAX_REQUEST_BYTES,
};
use serde_json::json;
use std::io::{Read, Write};
use std::time::Instant;

fn demo() -> Request {
    serde_json::from_str(include_str!("../examples/supports-cycle.json"))
        .expect("checked demo JSON")
}

fn main() {
    let mode = std::env::args().nth(1);
    let output = match mode.as_deref() {
        Some("--demo") => match evaluate(demo(), Limits::default()) {
            Ok(value) => json!({"status":"ok", "result":value}),
            Err(error) => json!({"status":"refused", "error":error}),
        },
        Some("--benchmark") => benchmark(),
        Some("--catalog") => catalog(),
        Some(_) => {
            json!({"status":"refused", "error":{"code":"invalid_arguments", "detail":"use stdin, --demo, --catalog or --benchmark"}})
        }
        None => {
            let mut bytes = Vec::new();
            let read = std::io::stdin()
                .take(MAX_REQUEST_BYTES as u64 + 1)
                .read_to_end(&mut bytes);
            match read {
                Err(error) => {
                    json!({"status":"refused", "error":{"code":"input_io", "detail":error.to_string()}})
                }
                Ok(_) if bytes.len() > MAX_REQUEST_BYTES => {
                    json!({"status":"refused", "error":{"code":"request_bytes_limit", "detail":"JSON exceeds 1 MiB"}})
                }
                Ok(_) => match std::str::from_utf8(&bytes) {
                    Err(error) => {
                        json!({"status":"refused", "error":{"code":"invalid_json", "detail":error.to_string()}})
                    }
                    Ok(text) => {
                        serde_json::from_str(&call_json(text)).expect("provider JSON envelope")
                    }
                },
            }
        }
    };
    let mut stdout = std::io::stdout().lock();
    serde_json::to_writer(&mut stdout, &output).expect("write JSON");
    writeln!(&mut stdout).expect("write newline");
}

fn benchmark() -> serde_json::Value {
    // Same 48-node chain, 80 versions: toggling the tail changes 47 of
    // 1128 possible reachable pairs. The semantic tests separately cover
    // duplicate-support updates that produce no output changes.
    let mut epochs = vec![
        json!({"version":0,"mutations":(0..47).map(|i|json!({"op":"insert","fact_id":format!("e{i}"),"from":i,"to":i+1})).collect::<Vec<_>>()}),
    ];
    for v in 1..80 {
        let mutation = if v % 2 == 1 {
            json!({"op":"retract","fact_id":"e46"})
        } else {
            json!({"op":"insert","fact_id":"e46","from":46,"to":47})
        };
        epochs.push(json!({"version":v,"mutations":[mutation],"queries":[{"op":"reachable","from":0,"to":47}]}));
    }
    let request: Request = serde_json::from_value(
        json!({"scope":"benchmark/supplied","nodes":(0..48).collect::<Vec<_>>(),"epochs":epochs}),
    )
    .expect("benchmark request");
    let limits = Limits::default();
    let started = Instant::now();
    let incremental = match evaluate(request.clone(), limits.clone()) {
        Ok(response) => response,
        Err(error) => return json!({"status":"refused","error":error}),
    };
    let incremental_total_us = started.elapsed().as_micros();
    let started = Instant::now();
    let fresh = match recompute(&request, &limits) {
        Ok(response) => response,
        Err(error) => return json!({"status":"refused","error":error}),
    };
    let fresh_total_us = started.elapsed().as_micros();
    let equal = incremental.epochs.iter().zip(&fresh.epochs).all(|(a, b)| {
        a.delta == b.delta && a.answers == b.answers && a.reachable_pairs == b.reachable_pairs
    });
    json!({
        "status": if equal {"ok"} else {"mismatch"},
        "semantic_match":equal,
        "workload":{"nodes":48,"epochs":80,"change":"toggle tail edge"},
        "incremental_total_us":incremental_total_us,
        "fresh_total_us":fresh_total_us,
        "incremental_settle_us":incremental.epochs.iter().map(|e|e.elapsed_us).collect::<Vec<_>>(),
        "fresh_compute_us":fresh.epochs.iter().map(|e|e.elapsed_us).collect::<Vec<_>>(),
        "worker_steps":incremental.epochs.iter().map(|e|e.worker_steps).collect::<Vec<_>>(),
        "output_events":incremental.epochs.iter().map(|e|e.observed_output_events).collect::<Vec<_>>(),
        "measurement":"single process, one cold graph; total includes preflight and result construction, settle times include input update and query answers; no speedup claim"
    })
}
