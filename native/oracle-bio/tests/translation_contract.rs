use oracle_bio::collection::SequenceRecord;
use oracle_bio::translation::*;
use std::sync::{atomic::AtomicBool, Arc};
fn input(sequence: &str) -> TranslationInput {
    TranslationInput {
        source: TranslationSourceInput {
            schema: SOURCE_SCHEMA.into(),
            records: vec![SequenceRecord {
                label: "supplied".into(),
                sequence: sequence.into(),
            }],
        },
        features: vec![CodingFeature {
            label: "supplied CDS".into(),
            record_index: 0,
            start: 0,
            end: sequence.len(),
            strand: Strand::Forward,
            frame: 0,
        }],
        genetic_code: CODE_ID.into(),
        initiation: InitiationPolicy::LiteralCodon,
        remainder: RemainderPolicy::Reject,
        stops: StopPolicy::Include,
        ambiguity: AmbiguityPolicy::Reject,
    }
}
fn run(input: &TranslationInput) -> TranslationResult {
    translate_intervals(input, &AtomicBool::new(false)).unwrap()
}
#[test]
fn independently_tabulated_standard_code_families() {
    // Explicit codons tabulated independently of native table encoding/order.
    let groups = [
        ("TTTTTCTTATTG", "FFLL"),
        ("TCTTCCTCATCG", "SSSS"),
        ("TATTACTAATAG", "YY**"),
        ("TGTTGCTGATGG", "CC*W"),
        ("CTTCTCCTACTG", "LLLL"),
        ("CCTCCCCCACCG", "PPPP"),
        ("CATCACCAACAG", "HHQQ"),
        ("CGTCGCCGACGG", "RRRR"),
        ("ATTATCATAATG", "IIIM"),
        ("ACTACCACAACG", "TTTT"),
        ("AATAACAAAAAG", "NNKK"),
        ("AGTAGCAGAAGG", "SSRR"),
        ("GTTGTCGTAGTG", "VVVV"),
        ("GCTGCCGCAGCG", "AAAA"),
        ("GATGACGAAGAG", "DDEE"),
        ("GGTGGCGGAGGG", "GGGG"),
    ];
    for (dna, gold) in groups {
        assert_eq!(run(&input(dna)).translations[0].protein, gold);
    }
}
#[test]
fn reverse_asymmetric_original_coordinates_and_selected_frame() {
    let mut request = input("AACATGGGCATCC");
    request.features[0].start = 2;
    request.features[0].end = 11;
    request.features[0].strand = Strand::Reverse;
    let result = run(&request);
    let feature = &result.translations[0];
    assert_eq!(feature.protein, "MPM"); // CAT GGG CAT -> oriented ATG CCC ATG
    assert_eq!(
        feature
            .codons
            .iter()
            .map(|c| (c.source.start, c.source.end, c.codon.as_str()))
            .collect::<Vec<_>>(),
        vec![(8, 11, "ATG"), (5, 8, "CCC"), (2, 5, "ATG")]
    );
    request.features[0].frame = 1;
    request.remainder = RemainderPolicy::Drop;
    let result = run(&request);
    let feature = &result.translations[0];
    assert_eq!(feature.protein, "CP"); // oriented TGC CCA + TG
    assert_eq!(
        feature.frame_skipped.as_ref().map(|x| (x.start, x.end)),
        Some((10, 11))
    );
    assert_eq!(
        feature.trailing_bases.as_ref().map(|x| (x.start, x.end)),
        Some((2, 4))
    );
    assert_eq!(
        feature.codons[0].source,
        SourceInterval {
            start: 7,
            end: 10,
            strand: Strand::Reverse
        }
    );
}
#[test]
fn selected_forward_frames_remainder_and_literal_initiation() {
    let mut request = input("AATGAAAT");
    request.features[0].frame = 1;
    request.remainder = RemainderPolicy::Drop;
    let result = run(&request);
    let feature = &result.translations[0];
    assert_eq!(feature.protein, "MK");
    assert_eq!(feature.codons[0].source.start, 1);
    assert_eq!(feature.trailing_bases.as_ref().unwrap().start, 7);
    request.remainder = RemainderPolicy::Reject;
    assert!(translate_intervals(&request, &AtomicBool::new(false)).is_err());
    assert_eq!(run(&input("TTGCTGGTGATG")).translations[0].protein, "LLVM"); // no start recoding
    let mut request = input("AAATGAAA");
    request.features[0].frame = 2;
    assert_eq!(run(&request).translations[0].protein, "MK");
}
#[test]
fn internal_terminal_and_initial_stops_are_explicit() {
    let mut request = input("ATGTAAGGGTAG");
    assert_eq!(run(&request).translations[0].protein, "M*G*");
    request.stops = StopPolicy::Terminate;
    let result = run(&request);
    let feature = &result.translations[0];
    assert_eq!(feature.protein, "M");
    assert_eq!(feature.codons.len(), 1);
    let stop = feature.termination_stop.as_ref().unwrap();
    assert_eq!((stop.source.start, stop.source.end), (3, 6));
    assert_eq!(
        feature
            .untranslated_after_stop
            .as_ref()
            .map(|x| (x.start, x.end)),
        Some((6, 12))
    );
    request.stops = StopPolicy::Reject;
    assert!(translate_intervals(&request, &AtomicBool::new(false)).is_err());
    let mut initial = input("TAAATG");
    initial.stops = StopPolicy::Terminate;
    assert_eq!(run(&initial).translations[0].protein, "");
}
#[test]
fn iupac_unknown_is_conservative_and_reverse_complements_are_preserved() {
    let mut request = input("GCNTARATH");
    request.ambiguity = AmbiguityPolicy::Unknown;
    let result = run(&request);
    assert_eq!(result.translations[0].protein, "XXX"); // even GCN is X; TAR never silently stop
    request.ambiguity = AmbiguityPolicy::Reject;
    assert!(translate_intervals(&request, &AtomicBool::new(false)).is_err());
    let mut reverse = input("RYSWKMBDHVN");
    reverse.ambiguity = AmbiguityPolicy::Unknown;
    reverse.remainder = RemainderPolicy::Drop;
    reverse.features[0].strand = Strand::Reverse;
    let result = run(&reverse);
    assert_eq!(
        result.translations[0]
            .codons
            .iter()
            .map(|c| c.codon.as_str())
            .collect::<String>(),
        "NBDHVKMWS"
    );
}
#[test]
fn source_and_request_provenance_and_prepared_ownership() {
    let control = AtomicBool::new(false);
    let mut request = input("atgAAA");
    let prepared = Arc::new(PreparedTranslationSource::prepare(&request.source, &control).unwrap());
    let original = run(&request);
    request.source.records[0].sequence = "ATGAAA".into();
    assert_ne!(original.source_sha256, run(&request).source_sha256);
    let shared = prepared.clone();
    let reused = translate_prepared(
        &shared,
        &request.features,
        CODE_ID,
        request.initiation,
        request.remainder,
        request.stops,
        request.ambiguity,
        &control,
    )
    .unwrap();
    assert_eq!(original.source_sha256, reused.source_sha256);
    assert_eq!(original.request_sha256, reused.request_sha256);
    request.features[0].label = "other feature".into();
    assert_ne!(reused.request_sha256, run(&request).request_sha256);
}
#[test]
fn bounded_admission_never_returns_partial_complete_results() {
    let control = AtomicBool::new(false);
    for dna in ["ATU", "ATG\n", "AT-", "🙂"] {
        assert!(translate_intervals(&input(dna), &control).is_err());
    }
    let mut request = input("ATG");
    request.genetic_code = "mitochondrial".into();
    assert!(translate_intervals(&request, &control).is_err());
    request = input("ATG");
    request.features[0].frame = 3;
    assert!(translate_intervals(&request, &control).is_err());
    request = input("ATG");
    request.features[0].end = 4;
    assert!(translate_intervals(&request, &control).is_err());
    request = input("ATG");
    request.features[0].record_index = 1;
    assert!(translate_intervals(&request, &control).is_err());
    request = input(&"ATG".repeat(MAX_CODONS + 1));
    assert!(translate_intervals(&request, &control).is_err());
    assert!(translate_intervals(&input("ATG"), &AtomicBool::new(true)).is_err());
}
