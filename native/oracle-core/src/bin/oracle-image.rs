use oracle_runtime_core::build_image;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 5 {
        return Err(
            "usage: oracle-image KQA_JSON OUTPUT_SQLITE MAX_SOURCE_BYTES MAX_RECORD_BYTES".into(),
        );
    }
    let receipt = build_image(
        Path::new(&args[1]),
        Path::new(&args[2]),
        args[3].parse()?,
        args[4].parse()?,
    )?;
    println!("{}", serde_json::to_string(&receipt)?);
    Ok(())
}
