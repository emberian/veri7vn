//! Native, snapshot-relative count/absence/uniqueness workflow.
use oracle_runtime_core::{coverage::{CoverageRequest, Traversal}, Cancellation, Image, Limits};
use serde_json::json;
use std::{io::Read, path::Path};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        return Err("usage: oracle-coverage IMAGE_SQLITE IMAGE_SHA256 < REQUEST_JSON".into());
    }
    let limits = Limits::default();
    let mut input = String::new();
    std::io::stdin().take(1_048_577).read_to_string(&mut input)?;
    if input.len() > 1_048_576 { return Err("request exceeds 1 MiB".into()); }
    let domain: CoverageRequest = serde_json::from_str(&input)?;
    let image = Image::open(Path::new(&args[1]), &args[2], limits)?;
    let covered = image.relation_coverage("coverage-cli", domain.clone(), Cancellation::default())?;
    let answers = if covered.receipt().traversal == Traversal::CompleteDeclaredSnapshotDomain {
        json!({"distinct_target_count": covered.count(image.verified_identity(), &domain)?,
            "absent_in_snapshot": covered.absent(image.verified_identity(), &domain)?,
            "unique_relation": covered.unique(image.verified_identity(), &domain)?})
    } else { serde_json::Value::Null };
    println!("{}", json!({"coverage":covered.receipt(),"answers":answers}));
    Ok(())
}
