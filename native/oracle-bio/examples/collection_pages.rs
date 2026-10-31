//! Run with cargo run -p oracle-bio --example collection_pages.
//! Reuses immutable source/trie; printed pages are untrusted computation.
use oracle_bio::collection::{PreparedSearch, SearchInput, SequenceCollection};
use std::sync::atomic::AtomicBool;
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let input: SearchInput = serde_json::from_str(include_str!("supplied-fragments.json"))?;
    let control = AtomicBool::new(false);
    let source = SequenceCollection::prepare(&input.collection, &control)?;
    let search = PreparedSearch::prepare(&source, &input.patterns, &control)?;
    let mut cursor = None;
    loop {
        let page = search.page(input.page_size, cursor.as_ref(), &control)?;
        println!("{}", serde_json::to_string(&page)?);
        if page.complete {
            break;
        }
        cursor = page.next_cursor;
    }
    Ok(())
}
