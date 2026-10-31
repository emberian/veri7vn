use oracle_runtime_core::{build_image, Cancellation, Image, Limits};
use oracle_runtime_core::coverage::{CoverageRequest, Traversal, UniqueRelation};
use serde_json::json;
fn fixture() -> (tempfile::TempDir, std::sync::Arc<Image>) {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source.json");
    let target = dir.path().join("image.sqlite");
    std::fs::write(&source, json!({"concepts":{},"entities":{
        "A":{"name":"Alias","instanceOf":[],"attributes":[],"relations":[
            {"predicate":"knows","direction":"forward","object":"B","qualifiers":{}},
            {"predicate":"knows","direction":"forward","object":"C","qualifiers":{"time":"past"}}]},
        "B":{"name":"Duplicate","instanceOf":[],"attributes":[],"relations":[]},
        "C":{"name":"Duplicate","instanceOf":[],"attributes":[],"relations":[]}
    }}).to_string()).unwrap();
    let built = build_image(&source,&target,1_000_000,100_000).unwrap();
    let image = Image::open(&target,&built.image_sha256,Limits::default()).unwrap();
    (dir,image)
}
fn domain() -> CoverageRequest {
    CoverageRequest { subjects: ["A".into()].into_iter().collect(), predicate:"knows".into(),
        direction:"forward".into(), qualifiers:None, traversal_limit:10 }
}
#[test]
fn skipped_final_page_cannot_authorize_count_or_uniqueness() {
    let (_dir,image)=fixture(); let mut d=domain(); d.traversal_limit=1;
    let c=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert_ne!(c.receipt().traversal,Traversal::CompleteDeclaredSnapshotDomain);
    assert!(c.count(&image.identity,&d).is_err());
    assert!(c.unique(&image.identity,&d).is_err());
}
#[test]
fn duplicate_aliases_are_distinct_targets_and_filters_bind() {
    let (_dir,image)=fixture(); let d=domain();
    let c=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert_eq!(c.unique(&image.identity,&d).unwrap(),UniqueRelation::Multiple(2));
    let mut filtered=d.clone(); filtered.qualifiers=Some(json!({}));
    assert!(c.count(&image.identity,&filtered).is_err());
    let f=image.relation_coverage("coverage",filtered.clone(),Cancellation::default()).unwrap();
    assert_eq!(f.unique(&image.identity,&filtered).unwrap(),UniqueRelation::Unique("B".into()));
    assert!(!c.compatible(&f));
    assert!(f.count("stale-source-revision",&filtered).is_err());
}
#[test]
fn missing_property_is_only_snapshot_absence_missing_subject_is_incomplete() {
    let (_dir,image)=fixture(); let mut d=domain(); d.predicate="unrecorded-property".into();
    let c=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert!(c.absent(&image.identity,&d).unwrap());
    d.subjects.insert("unknown-ID".into());
    let missing=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert!(missing.absent(&image.identity,&d).is_err());
}
#[test]
fn exact_limit_eof_is_complete_and_retraction_changes_domain() {
    let (_dir,image)=fixture(); let mut d=domain(); d.traversal_limit=2;
    let c=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert_eq!(c.count(&image.identity,&d).unwrap(),2);
    d.subjects=["B".into()].into_iter().collect();
    assert!(c.absent(&image.identity,&d).is_err());
}
#[test]
fn mutable_display_identity_cannot_rebind_coverage_authority() {
    let (_dir,mut image)=fixture();
    let verified=image.verified_identity().to_owned();
    std::sync::Arc::get_mut(&mut image).unwrap().identity="forged-display-digest".into();
    let d=domain();
    let c=image.relation_coverage("coverage",d.clone(),Cancellation::default()).unwrap();
    assert_eq!(c.receipt().source_revision,verified);
    assert!(c.count(&image.identity,&d).is_err());
    assert_eq!(c.count(image.verified_identity(),&d).unwrap(),2);
}
#[test]
fn many_short_missing_ids_obey_retained_memory_and_release_charges() {
    use oracle_runtime_core::{Budget, Error};
    let (_dir,image)=fixture();
    let mut d=domain();
    d.subjects=(0..120).map(|n| format!("x{n:03}")).collect();
    let mut limits=Limits::default();
    limits.request_memory_bytes=24_000;
    let budget=Budget::new(&limits,Cancellation::default()).unwrap();
    let outcome=image.relation_coverage_with_budget("coverage",d.clone(),&budget);
    assert!(matches!(outcome,Err(Error::Limit("retained request memory"))));
    // Domain admission succeeds; retained missing-ID reasons eventually exhaust
    // the ledger. Refusal must release all earlier successful reservations.
    assert!(budget.memory().snapshot().peak > 0);
    assert_eq!(budget.memory().snapshot().live,0);
    let budget=Budget::new(&Limits::default(),Cancellation::default()).unwrap();
    let token=image.relation_coverage_with_budget("coverage",d,&budget).unwrap();
    assert!(budget.memory().snapshot().live > 24_000);
    drop(token);
    assert_eq!(budget.memory().snapshot().live,0);
}
#[test]
fn typed_coverage_input_enforces_request_wire_limit_without_encoding_copy() {
    use oracle_runtime_core::{Budget, Error};
    let (dir,_image)=fixture();
    let mut limits=Limits::default(); limits.request_bytes=128;
    let image=Image::open(&dir.path().join("image.sqlite"),_image.verified_identity(),limits.clone()).unwrap();
    let mut d=domain(); d.predicate="long predicate ".repeat(100);
    let budget=Budget::new(&limits,Cancellation::default()).unwrap();
    assert!(matches!(image.relation_coverage_with_budget("coverage",d,&budget),
        Err(Error::Limit("encoded bytes"))));
    assert_eq!(budget.memory().snapshot().live,0);
}
