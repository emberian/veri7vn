//! Conditional source-image query demo; learned proposals are never graph writes.
use oracle_runtime_core::{
    batch::{self, BatchDemand},
    binding_proposal::{self, ProposalInput},
    Budget, Cancellation, Image, Limits,
};
use std::path::Path;

fn bounded_file(path: &str, cap: u64) -> Result<String, Box<dyn std::error::Error>> {
    if std::fs::metadata(path)?.len() > cap {
        return Err("demo input cap exceeded".into());
    }
    let file = std::fs::File::open(path)?;
    use std::io::Read;
    let mut text = String::new();
    file.take(cap + 1).read_to_string(&mut text)?;
    if text.len() as u64 > cap {
        return Err("demo input cap exceeded".into());
    }
    Ok(text)
}
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 5 {
        return Err(
            "usage: binding_proposal IMAGE EXPECTED_SHA256 SOURCE_UTF8 PROPOSAL_JSON".into(),
        );
    }
    let image = Image::open(Path::new(&args[1]), &args[2], Limits::default())?;
    let source = bounded_file(&args[3], 65536)?;
    let input: ProposalInput = serde_json::from_str(&bounded_file(&args[4], 1048576)?)?;
    let budget = Budget::new(&image.limits, Cancellation::default())?;
    let proposals = binding_proposal::resolve(&image, "binding-demo", &source, input, &budget)?;
    let prepared = proposals
        .proposals()
        .iter()
        .map(|p| batch::prepare_program(image.clone(), p.program.clone(), &budget))
        .collect::<oracle_runtime_core::Result<Vec<_>>>()?;
    // Unknown candidate coverage stays attached even if every proposed query
    // returns the same value. No inference from candidate agreement is made.
    let execution = if prepared.is_empty() {
        None
    } else {
        let requests: Vec<_> = prepared.iter().map(|p| (p, BatchDemand::Full)).collect();
        Some(batch::execute(&image, "binding-demo", &requests, &budget)?)
    };
    println!(
        "{}",
        serde_json::to_string_pretty(&serde_json::json!({
            "proposals":proposals,"conditional_image_execution":execution,
            "claim":"image denotations for proposed programs; no source entailment or candidate completeness"
        }))?
    );
    Ok(())
}
