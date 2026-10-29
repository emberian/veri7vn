use std::io::{self, Read};
use std::sync::atomic::AtomicBool;

fn main() {
    if std::env::args().nth(1).as_deref() == Some("--catalog") {
        println!("{}", oracle_statistics::catalog());
        return;
    }
    let result = (|| {
        let mut request = String::new();
        io::stdin()
            .take((oracle_statistics::MAX_REQUEST_BYTES + 1) as u64)
            .read_to_string(&mut request)
            .map_err(|e| serde_json::json!({"code":"io_error","message":e.to_string()}))?;
        oracle_statistics::call(&request, &Default::default(), &AtomicBool::new(false))
            .map_err(|e| serde_json::json!({"code":e.code(),"message":e.to_string()}))
    })();
    match result {
        Ok(reply) => println!("{reply}"),
        Err(error) => {
            println!(
                "{}",
                serde_json::json!({"schema":oracle_statistics::SCHEMA,"error":error})
            );
            std::process::exit(2);
        }
    }
}
