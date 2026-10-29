//! Bounded-input experimental JSONL tool. Use external process limits for hostile input.
use oracle_reasoning::{call, catalog, Limits};
use std::io::{self, BufRead, Write};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    if std::env::args().nth(1).as_deref() == Some("--catalog") {
        println!("{}", catalog());
        return Ok(());
    }
    let limits = Limits::default();
    let mut input = io::stdin().lock();
    let mut output = io::stdout().lock();
    loop {
        let mut bytes = Vec::new();
        let count = std::io::Read::take(&mut input, (limits.request_bytes + 1) as u64)
            .read_until(b'\n', &mut bytes)?;
        if count == 0 {
            break;
        }
        if count > limits.request_bytes {
            writeln!(
                output,
                "{}",
                serde_json::json!({"error": "request bytes exceeded; process exiting"})
            )?;
            break;
        }
        let result = std::str::from_utf8(&bytes)
            .map_err(|e| e.to_string())
            .and_then(|s| call(s, &limits).map_err(|e| e.to_string()));
        match result {
            Ok(reply) => writeln!(output, "{reply}")?,
            Err(error) => writeln!(output, "{}", serde_json::json!({"error": error}))?,
        }
        output.flush()?;
    }
    Ok(())
}
