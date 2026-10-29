use std::io::{self, Read};
use std::sync::atomic::AtomicBool;

fn main() {
    if std::env::args().nth(1).as_deref() == Some("--catalog") {
        println!("{}", oracle_science::catalog());
        return;
    }
    let result = (|| {
        let mut request = String::new();
        io::stdin()
            .take((oracle_science::MAX_REQUEST_BYTES + 1) as u64)
            .read_to_string(&mut request)
            .map_err(|e| e.to_string())?;
        oracle_science::call(&request, &Default::default(), &AtomicBool::new(false)).map_err(|e| {
            serde_json::json!({"code": e.code(), "message": e.to_string()}).to_string()
        })
    })();
    match result {
        Ok(reply) => println!("{reply}"),
        Err(error) => {
            let error = serde_json::from_str::<serde_json::Value>(&error)
                .unwrap_or_else(|_| serde_json::json!({"code": "io_error", "message": error}));
            println!(
                "{}",
                serde_json::json!({"schema": oracle_science::SCHEMA, "error": error})
            );
            std::process::exit(2);
        }
    }
}
