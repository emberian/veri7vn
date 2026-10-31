//! Reuse an immutable source for multiple explicitly declared feature batches.
use oracle_bio::translation::{translate_prepared, PreparedTranslationSource, TranslationInput};
use std::sync::{atomic::AtomicBool, Arc};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let input: TranslationInput = serde_json::from_str(include_str!("translation-supplied.json"))?;
    let control = AtomicBool::new(false);
    let source = Arc::new(PreparedTranslationSource::prepare(&input.source, &control)?);
    for features in input.features.chunks(1) {
        let result = translate_prepared(
            &source,
            features,
            &input.genetic_code,
            input.initiation,
            input.remainder,
            input.stops,
            input.ambiguity,
            &control,
        )?;
        println!("{}", serde_json::to_string(&result)?);
    }
    Ok(())
}
