use oracle_bio::collection::*;
use std::sync::{atomic::AtomicBool, Arc};
fn record(label: &str, sequence: &str) -> SequenceRecord {
    SequenceRecord {
        label: label.into(),
        sequence: sequence.into(),
    }
}
fn input(sequences: &[&str], patterns: &[&str], page_size: usize) -> SearchInput {
    SearchInput {
        collection: CollectionInput {
            schema: COLLECTION_SCHEMA.into(),
            records: sequences.iter().map(|s| record("duplicate", s)).collect(),
        },
        patterns: patterns.iter().map(|s| record("duplicate", s)).collect(),
        page_size,
        cursor: None,
    }
}
fn rc(s: &str) -> String {
    s.chars()
        .rev()
        .map(|b| match b {
            'A' => 'T',
            'C' => 'G',
            'G' => 'C',
            _ => 'A',
        })
        .collect()
}
// Independent direct pattern-by-pattern enumeration; no trie or cursor logic.
fn naive(input: &SearchInput) -> Vec<(usize, usize, usize, usize, Strand)> {
    let mut hits = vec![];
    for (ri, r) in input.collection.records.iter().enumerate() {
        let text = r.sequence.to_ascii_uppercase();
        for start in 0..text.len() {
            for (pi, p) in input.patterns.iter().enumerate() {
                let p = p.sequence.to_ascii_uppercase();
                let reverse = rc(&p);
                if text[start..].starts_with(&p) {
                    hits.push((
                        ri,
                        start,
                        start + p.len(),
                        pi,
                        if p == reverse {
                            Strand::Both
                        } else {
                            Strand::Forward
                        },
                    ));
                }
                if p != reverse && text[start..].starts_with(&reverse) {
                    hits.push((ri, start, start + p.len(), pi, Strand::Reverse));
                }
            }
        }
    }
    hits
}
fn pages(mut input: SearchInput) -> Vec<(usize, usize, usize, usize, Strand)> {
    let control = AtomicBool::new(false);
    let mut hits = vec![];
    for _ in 0..1000 {
        let page = search_collection(&input, &control).unwrap();
        assert_eq!(page.coverage_start, input.cursor);
        hits.extend(
            page.hits
                .into_iter()
                .map(|h| (h.record_index, h.start, h.end, h.pattern_index, h.strand)),
        );
        if page.complete {
            assert!(page.next_cursor.is_none());
            return hits;
        }
        assert!(page.next_cursor.is_some());
        assert_ne!(page.next_cursor, input.cursor);
        input.cursor = page.next_cursor;
    }
    panic!("pagination did not terminate");
}
#[test]
fn independent_exhaustive_small_sequences_and_paging() {
    for bits in 0..256 {
        let sequence: String = (0..4)
            .map(|i| b"ACGT"[(bits >> (i * 2)) & 3] as char)
            .collect();
        for size in [1, 2, 3, 17] {
            let request = input(
                &[&sequence, "", "AC", "GT"],
                &["A", "AA", "AC", "ACG", "AT", "A"],
                size,
            );
            assert_eq!(pages(request.clone()), naive(&request));
        }
    }
}
#[test]
fn reverse_coordinates_overlap_palindrome_duplicates_and_boundaries() {
    let request = input(
        &["TTTCGTAA", "AAAA", "ATAT", "AC", "GT"],
        &["ACG", "AA", "AT", "ACG", "ACGT"],
        1,
    );
    let got = pages(request.clone());
    assert_eq!(got, naive(&request));
    assert!(got.contains(&(0, 3, 6, 0, Strand::Reverse)));
    assert!(got.contains(&(1, 2, 4, 1, Strand::Forward)));
    assert!(got.contains(&(2, 2, 4, 2, Strand::Both)));
    assert!(!got.iter().any(|h| h.3 == 4)); // AC / GT must not concatenate.
}
#[test]
fn exact_cap_completion_empty_collection_and_one_more_hit() {
    let control = AtomicBool::new(false);
    let exact = search_collection(&input(&["AAA"], &["A"], 3), &control).unwrap();
    assert_eq!(exact.hits.len(), 3);
    assert!(exact.complete);
    let capped = search_collection(&input(&["AAAA"], &["A"], 3), &control).unwrap();
    assert_eq!(capped.hits.len(), 3);
    assert!(!capped.complete);
    assert!(
        search_collection(&input(&[], &["A"], 1), &control)
            .unwrap()
            .complete
    );
}
#[test]
fn source_identity_and_cursor_bind_order_content_and_pattern_provenance() {
    let control = AtomicBool::new(false);
    let mut request = input(&["AAA"], &["A", "A"], 1);
    let page = search_collection(&request, &control).unwrap();
    request.cursor = page.next_cursor;
    request.collection.records[0].sequence = "aaa".into();
    assert!(search_collection(&request, &control).is_err()); // source bytes, not only normalized content
    request.collection.records[0].sequence = "AAA".into();
    request.patterns[1].label = "other".into();
    assert!(search_collection(&request, &control).is_err());
}
#[test]
fn prepared_immutable_collection_can_be_shared_without_registry() {
    let control = AtomicBool::new(false);
    let mut source = input(&["ACGT"], &["AC"], 1);
    let prepared = Arc::new(SequenceCollection::prepare(&source.collection, &control).unwrap());
    source.collection.records[0].sequence = "AAAA".into();
    let clone = prepared.clone();
    let result = search_prepared(&clone, &source.patterns, 10, None, &control).unwrap();
    assert_eq!(result.hits.len(), 2);
}
#[test]
fn admission_and_shared_cancellation_never_claim_absence() {
    let control = AtomicBool::new(false);
    for request in [
        input(&["ACN"], &["AC"], 1),
        input(&["AC"], &[""], 1),
        input(&["AC"], &["N"], 1),
        input(&["AC"], &["AC"], 0),
        input(&["AC"], &["A"], MAX_PAGE + 1),
        input(&[&"A".repeat(MAX_BASES + 1)], &["A"], 1),
    ] {
        assert!(search_collection(&request, &control).is_err());
    }
    assert!(search_collection(&input(&["A"], &["A"], 1), &AtomicBool::new(true)).is_err());
    let repetitive = input(&[&"A".repeat(8192)], &[&"A".repeat(4096)], 1);
    // No hit before the long tail; tiny page does not evade the work cap.
    let mut rare = repetitive;
    rare.patterns[0].sequence.replace_range(4095.., "C");
    assert!(search_collection(&rare, &control).is_err());
}
