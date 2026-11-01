//! Finite native conversation behavior and the actual authoritative transaction.
//! Manufactured source data establishes these examples, not a specialist score.
use oracle_runtime_core::conversation::{
    ConversationBegin, ConversationCandidate, ConversationInput, ConversationRequest,
};
use oracle_runtime_core::native_conversation::*;
use oracle_runtime_core::session::{NumericOrigin, OracleSessionState, StateCoverage};
use oracle_runtime_core::{
    build_image, Budget, Cancellation, Error, Image, Limits, NativeEntityQuery, RequestDialect,
    Runtime,
};
use serde_json::json;
use std::sync::Arc;
use tempfile::TempDir;

struct Fixture {
    _dir: TempDir,
    image: Arc<Image>,
    store: std::path::PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let dir = tempfile::tempdir().unwrap();
        let source = dir.path().join("source.json");
        let image_path = dir.path().join("image.sqlite");
        std::fs::write(&source,json!({"concepts":{},"entities":{
            "person":{"name":"Ada","instanceOf":[],"attributes":[],"relations":[{"predicate":"place of birth","object":"place","direction":"forward","qualifiers":{}}]},
            "place":{"name":"London","instanceOf":[],"attributes":[],"relations":[]},
            "ambiguous-one":{"name":"Shared","instanceOf":[],"attributes":[],"relations":[]},
            "ambiguous-two":{"name":"Shared","instanceOf":[],"attributes":[],"relations":[]}
        }}).to_string()).unwrap();
        let receipt = build_image(&source, &image_path, 1_000_000, 100_000).unwrap();
        let image = Image::open(&image_path, &receipt.image_sha256, Limits::default()).unwrap();
        Self {
            store: dir.path().join("state.sqlite"),
            _dir: dir,
            image,
        }
    }
    fn runtime(&self) -> Runtime {
        Runtime::open(self.image.clone(), &self.store)
            .unwrap()
            .register_native_owner::<NativeConversationOwner>()
            .unwrap()
    }
    fn budget(&self) -> Budget {
        Budget::new(&self.image.limits, Cancellation::default()).unwrap()
    }
}
fn request(text: &str) -> ConversationRequest {
    ConversationRequest {
        endpoint: "/query".into(),
        operation: "native-v1.query".into(),
        expected_version: None,
        input: ConversationInput::ExactBytes(text.as_bytes().to_vec()),
    }
}
fn begin(rt: &Runtime, id: &str, budget: &Budget) -> ConversationCandidate {
    match rt
        .conversation_begin("tenant", "session", id, &request(id), budget)
        .unwrap()
    {
        ConversationBegin::Fresh(c) => c,
        ConversationBegin::Replay(_) => panic!("fresh expected"),
    }
}
fn initialize(rt: &Runtime, c: &mut ConversationCandidate, budget: &Budget) {
    rt.conversation_native_initialize(c, budget).unwrap()
}
fn commit(rt: &Runtime, c: ConversationCandidate, body: &[u8], budget: &Budget) {
    rt.conversation_commit(c, 200, body, budget).unwrap();
}
fn quantity(number: &str, unit: &str, origin: NumericOrigin) -> NativeQuantity {
    NativeQuantity {
        number: number.into(),
        unit: unit.into(),
        origin,
        role: QuantityRole::Scalar,
    }
}
fn provider() -> ProviderIdentity {
    ProviderIdentity::from_host_delivery("organ:energy", &"1".repeat(64)).unwrap()
}
fn deliver(
    rt: &Runtime,
    c: &mut ConversationCandidate,
    number: &str,
    unit: &str,
    origin: NumericOrigin,
    budget: &Budget,
) -> NativeContextReply {
    rt.conversation_deliver_quantity(
        c,
        ProviderQuantityAnchor::from_host_delivery(provider(), quantity(number, unit, origin))
            .unwrap(),
        budget,
    )
    .unwrap()
}
fn state(rt: &Runtime, c: &ConversationCandidate, budget: &Budget) -> NativeContextState {
    rt.conversation_native_validate(c, budget).unwrap()
}

#[test]
fn delivered_energy_cost_ack_scale_restart_and_exact_http_retry() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "energy", &b);
    initialize(&rt, &mut c, &b);
    let delivered = deliver(
        &rt,
        &mut c,
        "21600000",
        "J",
        NumericOrigin::DisplayedDecimal,
        &b,
    );
    assert_eq!(delivered.quantity().unwrap().unit, "J");
    commit(&rt, c, b"{ \"answer\":\"21600000 J\" }", &b);
    let mut c = begin(&rt, "cost", &b);
    let cost = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Cost {
                rate: "0.20".into(),
                per_unit: "kWh".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(cost.quantity().unwrap().number, "6/5");
    assert_eq!(cost.quantity().unwrap().unit, "$");
    assert_eq!(
        cost.quantity().unwrap().origin,
        NumericOrigin::DisplayedDecimal
    );
    assert!(matches!(
        cost.delivery.as_ref().unwrap().source,
        AnchorSource::Provider { .. }
    ));
    assert_eq!(
        cost.delivery
            .as_ref()
            .unwrap()
            .derivation
            .as_ref()
            .unwrap()
            .conversion_factor,
        "1/3600000"
    );
    commit(&rt, c, b"{\"answer\":\"$1.20\"}", &b);
    let mut c = begin(&rt, "ack", &b);
    let before = state(&rt, &c, &b);
    rt.conversation_native_command(&mut c, NativeContextCommand::Acknowledge, &b)
        .unwrap();
    assert_eq!(state(&rt, &c, &b), before);
    commit(&rt, c, b"{\"answer\":\"Got it.\"}", &b);
    drop(rt);
    let rt = f.runtime();
    let replay = rt
        .conversation_completion("tenant", "session", "cost", &request("cost"))
        .unwrap()
        .unwrap();
    assert_eq!(replay.body, b"{\"answer\":\"$1.20\"}");
    let mut c = begin(&rt, "twice", &b);
    let scaled = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Scale { factor: "2".into() },
            &b,
        )
        .unwrap();
    assert_eq!(scaled.quantity().unwrap().number, "12/5");
    assert_eq!(
        scaled.quantity().unwrap().origin,
        NumericOrigin::DisplayedDecimal
    );
    assert_eq!(
        scaled
            .delivery
            .as_ref()
            .unwrap()
            .derivation
            .as_ref()
            .unwrap()
            .previous_request,
        "cost"
    );
    assert!(c.envelope.oracle.is_none());
    assert_eq!(c.envelope.coverage, StateCoverage::NativeSelectionOnly);
}

#[test]
fn units_are_case_sensitive_and_semantic_refusals_preserve_delivered_anchor() {
    for (unit, rate_unit) in [("mW", "MW"), ("mJ", "MJ"), ("J", "kwh"), ("kWh", "j")] {
        let f = Fixture::new();
        let rt = f.runtime();
        let b = f.budget();
        let mut c = begin(&rt, "anchor", &b);
        initialize(&rt, &mut c, &b);
        deliver(&rt, &mut c, "10", unit, NumericOrigin::PythonFloat, &b);
        commit(&rt, c, b"{}", &b);
        let mut c = begin(&rt, "bad-unit", &b);
        let before = state(&rt, &c, &b);
        let r = rt
            .conversation_native_command(
                &mut c,
                NativeContextCommand::Cost {
                    rate: "2".into(),
                    per_unit: rate_unit.into(),
                },
                &b,
            )
            .unwrap();
        assert_eq!(r.reason, Some(NativeContextRefusal::IncompatibleRateUnit));
        assert_eq!(state(&rt, &c, &b), before);
        commit(&rt, c, b"{\"status\":\"withheld\"}", &b);
        let mut c = begin(&rt, "zero", &b);
        let r = rt
            .conversation_native_command(
                &mut c,
                NativeContextCommand::Divide {
                    divisor: "0".into(),
                },
                &b,
            )
            .unwrap();
        assert_eq!(r.reason, Some(NativeContextRefusal::UndefinedDivision));
        assert_eq!(state(&rt, &c, &b), before);
    }
}

#[test]
fn supplied_scalar_is_explicit_and_origin_survives_exact_rational_operations() {
    for origin in [
        NumericOrigin::ExactDecimal,
        NumericOrigin::PythonFloat,
        NumericOrigin::DisplayedDecimal,
    ] {
        let f = Fixture::new();
        let rt = f.runtime();
        let b = f.budget();
        let mut c = begin(&rt, "observe", &b);
        initialize(&rt, &mut c, &b);
        let r = rt
            .conversation_native_command(
                &mut c,
                NativeContextCommand::Observe {
                    quantity: quantity("0.1", "1", origin.clone()),
                },
                &b,
            )
            .unwrap();
        assert!(matches!(r.delivery.unwrap().source, AnchorSource::Supplied));
        commit(&rt, c, b"{}", &b);
        let mut c = begin(&rt, "divide", &b);
        let r = rt
            .conversation_native_command(
                &mut c,
                NativeContextCommand::Divide {
                    divisor: "3".into(),
                },
                &b,
            )
            .unwrap();
        assert_eq!(r.quantity().unwrap().number, "1/30");
        assert_eq!(r.quantity().unwrap().origin, origin);
    }
    assert!(serde_json::from_value::<NativeContextCommand>(json!({"op":"observe","quantity":{"number":"1","unit":"1","origin":"exact_decimal"},"source":{"kind":"provider"}})).is_err());
}

#[test]
fn native_initialization_never_adopts_retained_missing_or_oracle_state() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let c = begin(&rt, "legacy", &b);
    commit(&rt, c, b"{}", &b);
    let mut c = begin(&rt, "adopt", &b);
    assert!(matches!(
        rt.conversation_native_initialize(&mut c, &b),
        Err(Error::Conflict(_))
    ));
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "foreign", &b);
    c.envelope.oracle = Some(OracleSessionState::default());
    c.envelope.coverage = StateCoverage::OracleAdapter {
        adapter_schema: 1,
        source: "other".into(),
    };
    assert!(matches!(
        rt.conversation_native_initialize(&mut c, &b),
        Err(Error::Conflict(_))
    ));
}

#[test]
fn entity_lookup_relation_and_ambiguous_refusal_use_same_source_selection() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "find", &b);
    initialize(&rt, &mut c, &b);
    let r = rt
        .conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Find { name: "Ada".into() },
            &b,
        )
        .unwrap();
    assert_eq!(r.entity.as_ref().unwrap().id, "person");
    assert_eq!(c.envelope.selection.ids.iter().next().unwrap(), "person");
    assert!(matches!(r.context.anchor,NativeAnchor::Entity{ref id} if id=="person"));
    commit(&rt, c, b"{\"answer\":\"Ada\"}", &b);
    // A delivered turn no longer retains its response. Shadowing `r` would
    // keep its live output reservation until the enclosing Rust scope ends.
    assert!(b.memory().snapshot().live > 0);
    drop(r);
    assert_eq!(b.memory().snapshot().live, 0);
    let mut c = begin(&rt, "ambiguous", &b);
    let before = state(&rt, &c, &b);
    let r = rt
        .conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Find {
                name: "Shared".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Withheld);
    assert_eq!(state(&rt, &c, &b), before);
    assert!(c.envelope.selection.ids.contains("person"));
    commit(&rt, c, b"{\"status\":\"withheld\"}", &b);
    assert!(b.memory().snapshot().live > 0);
    drop(r);
    assert_eq!(b.memory().snapshot().live, 0);
    let mut c = begin(&rt, "birthplace", &b);
    let r = rt
        .conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Relation {
                predicate: "place of birth".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.entity.as_ref().unwrap().id, "place");
    assert_eq!(r.entity.as_ref().unwrap().label, "London");
    assert!(c.envelope.selection.ids.contains("place"));
    assert!(r
        .evidence
        .as_ref()
        .unwrap()
        .facts
        .iter()
        .any(|f| f.subject == "person" && f.object == "place"));
    commit(&rt, c, b"{\"answer\":\"London\"}", &b);
    assert!(b.memory().snapshot().live > 0);
    drop(r);
    assert_eq!(b.memory().snapshot().live, 0);
    let mut c = begin(&rt, "no-birthplace", &b);
    let before = state(&rt, &c, &b);
    assert_eq!(
        rt.conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Relation {
                predicate: "place of birth".into()
            },
            &b
        )
        .unwrap()
        .status,
        NativeContextStatus::Withheld
    );
    assert_eq!(state(&rt, &c, &b), before);
    assert!(c.envelope.selection.ids.contains("place"));
}

#[test]
fn explicit_graph_mutation_requires_reconcile_without_importing_new_entity_anchor() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "entity", &b);
    initialize(&rt, &mut c, &b);
    rt.conversation_native_entity_query(&mut c, NativeEntityQuery::Find { name: "Ada".into() }, &b)
        .unwrap();
    commit(&rt, c, b"{}", &b);
    let mut c = begin(&rt, "graph", &b);
    let input=json!({"nodes":[{"op":"find","name":"London"}],"output":0,"projection":{"kind":"unique_name"}}).to_string();
    rt.conversation_execute(&mut c, RequestDialect::Graph, &input, &b)
        .unwrap();
    assert!(rt.conversation_native_validate(&c, &b).is_err());
    // The canonical Entity reference cannot commit against a changed selection.
    assert!(c
        .envelope
        .encode(&oracle_runtime_core::session::SessionLimits {
            native_extension_versions: [(OWNER.into(), 1)].into_iter().collect(),
            ..Default::default()
        })
        .is_err());
    rt.conversation_native_reconcile_selection(&mut c, &b)
        .unwrap();
    assert_eq!(state(&rt, &c, &b).anchor, NativeAnchor::Empty);
    assert!(c.envelope.selection.ids.contains("place"));
    assert!(state(&rt, &c, &b).delivery.is_none());
    commit(&rt, c, b"{\"operation\":\"graph.execute\"}", &b);
}

#[test]
fn topic_reset_clears_native_anchor_and_selection_only_after_delivery() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "entity", &b);
    initialize(&rt, &mut c, &b);
    rt.conversation_native_entity_query(&mut c, NativeEntityQuery::Find { name: "Ada".into() }, &b)
        .unwrap();
    commit(&rt, c, b"{}", &b);
    let mut discarded = begin(&rt, "discard", &b);
    rt.conversation_native_command(&mut discarded, NativeContextCommand::ResetTopic, &b)
        .unwrap();
    drop(discarded);
    let mut c = begin(&rt, "reset", &b);
    assert!(matches!(
        state(&rt, &c, &b).anchor,
        NativeAnchor::Entity { .. }
    ));
    rt.conversation_native_command(&mut c, NativeContextCommand::ResetTopic, &b)
        .unwrap();
    assert_eq!(state(&rt, &c, &b).anchor, NativeAnchor::Empty);
    assert!(c.envelope.selection.ids.is_empty());
    commit(&rt, c, b"{}", &b);
    let mut c = begin(&rt, "scale", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Scale { factor: "2".into() },
            &b,
        )
        .unwrap();
    assert_eq!(
        r.reason,
        Some(NativeContextRefusal::PriorQuantityUnavailable)
    );
    assert_eq!(state(&rt, &c, &b).anchor, NativeAnchor::Empty);
}

#[test]
fn growth_invalid_sources_and_cancelled_native_work_cannot_install_an_anchor() {
    assert!(ProviderIdentity::from_host_delivery("organ:energy", "unmeasured").is_err());
    for number in ["NaN", "inf", "1e129", "1/0"] {
        assert!(quantity(number, "J", NumericOrigin::ExactDecimal)
            .validate()
            .is_err());
    }
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "huge", &b);
    initialize(&rt, &mut c, &b);
    deliver(
        &rt,
        &mut c,
        &"9".repeat(128),
        "1",
        NumericOrigin::ExactDecimal,
        &b,
    );
    commit(&rt, c, b"{}", &b);
    let mut c = begin(&rt, "growth", &b);
    let before = state(&rt, &c, &b);
    assert!(rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Scale {
                factor: "9".repeat(128)
            },
            &b
        )
        .is_err());
    assert_eq!(state(&rt, &c, &b), before);
    assert!(matches!(
        rt.conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Find {
                name: "x".repeat(f.image.limits.request_bytes + 1)
            },
            &b
        ),
        Err(Error::Limit(_))
    ));
    assert_eq!(state(&rt, &c, &b), before);
    let cancellation = Cancellation::default();
    let cancelled = Budget::new(&f.image.limits, cancellation.clone()).unwrap();
    cancellation.cancel();
    assert!(matches!(
        rt.conversation_native_command(&mut c, NativeContextCommand::Inspect, &cancelled),
        Err(Error::Cancelled)
    ));
}

#[test]
fn acknowledgement_and_inspection_preserve_selection_as_well_as_quantity() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "anchor", &b);
    initialize(&rt, &mut c, &b);
    deliver(&rt, &mut c, "6", "kWh", NumericOrigin::DisplayedDecimal, &b);
    commit(&rt, c, b"{}", &b);
    let mut c = begin(&rt, "graph", &b);
    let input =
        json!({"nodes":[{"op":"find","name":"Ada"}],"output":0,"projection":{"kind":"entities"}})
            .to_string();
    rt.conversation_execute(&mut c, RequestDialect::Graph, &input, &b)
        .unwrap();
    rt.conversation_native_reconcile_selection(&mut c, &b)
        .unwrap();
    commit(&rt, c, b"{}", &b);
    for (id, command) in [
        ("ack", NativeContextCommand::Acknowledge),
        ("inspect", NativeContextCommand::Inspect),
    ] {
        let mut c = begin(&rt, id, &b);
        let before = state(&rt, &c, &b);
        assert!(c.envelope.selection.ids.contains("person"));
        rt.conversation_native_command(&mut c, command, &b).unwrap();
        assert_eq!(state(&rt, &c, &b), before);
        assert!(c.envelope.selection.ids.contains("person"));
        commit(&rt, c, b"{}", &b);
    }
}

#[test]
fn explicit_empty_and_ambiguous_graph_results_clear_stale_entity_only_on_reconcile() {
    for (name, selected) in [("Missing", 0), ("Shared", 2)] {
        let f = Fixture::new();
        let rt = f.runtime();
        let b = f.budget();
        let mut c = begin(&rt, "anchor", &b);
        initialize(&rt, &mut c, &b);
        rt.conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::Find { name: "Ada".into() },
            &b,
        )
        .unwrap();
        commit(&rt, c, b"{}", &b);
        let mut c = begin(&rt, "explicit-graph", &b);
        let graph=json!({"nodes":[{"op":"find","name":name}],"output":0,"projection":{"kind":"unique_name"}}).to_string();
        rt.conversation_execute(&mut c, RequestDialect::Graph, &graph, &b)
            .unwrap();
        assert_eq!(c.envelope.selection.ids.len(), selected);
        assert!(rt.conversation_native_validate(&c, &b).is_err());
        rt.conversation_native_reconcile_selection(&mut c, &b)
            .unwrap();
        assert_eq!(state(&rt, &c, &b).anchor, NativeAnchor::Empty);
        assert_eq!(c.envelope.selection.ids.len(), selected);
        commit(&rt, c, b"{\"operation\":\"graph.execute\"}", &b);
    }
}

#[test]
fn temperature_point_and_difference_roles_distinguish_affine_and_linear_operations() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "obs-temp", &b);
    initialize(&rt, &mut c, &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Observe {
                quantity: NativeQuantity {
                    number: "20".into(),
                    unit: "degC".into(),
                    origin: NumericOrigin::ExactDecimal,
                    role: QuantityRole::TemperaturePoint,
                },
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    commit(&rt, c, b"{}", &b);

    // Scaling an affine temperature point is refused and preserves the point.
    let mut c = begin(&rt, "scale-point", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Scale { factor: "2".into() },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Withheld);
    assert_eq!(
        r.reason,
        Some(NativeContextRefusal::IncompatibleTemperatureRole)
    );
    commit(&rt, c, b"{}", &b);

    // Affine conversion to K: 20 degC -> 293.15 K (5863/20 K).
    let mut c = begin(&rt, "to-k", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::ConvertTemperature {
                target_unit: "K".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    assert_eq!(r.quantity().unwrap().number, "5863/20");
    assert_eq!(r.quantity().unwrap().unit, "K");
    assert_eq!(r.quantity().unwrap().role, QuantityRole::TemperaturePoint);
    commit(&rt, c, b"{}", &b);

    // Subtracting baseline 273.15 K produces a TemperatureDifference of 20 K (20/1 K), which CAN be scaled.
    let mut c = begin(&rt, "diff-from", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::TemperatureDifferenceFrom {
                baseline: "273.15".into(),
                baseline_unit: "K".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    assert_eq!(r.quantity().unwrap().number, "20/1");
    assert_eq!(
        r.quantity().unwrap().role,
        QuantityRole::TemperatureDifference
    );
    commit(&rt, c, b"{}", &b);

    let mut c = begin(&rt, "scale-diff", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::Scale { factor: "3".into() },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    assert_eq!(r.quantity().unwrap().number, "60/1");
    assert_eq!(
        r.quantity().unwrap().role,
        QuantityRole::TemperatureDifference
    );
    commit(&rt, c, b"{}", &b);
}

#[test]
fn direct_entity_id_selection_and_retained_fitted_model_evaluation() {
    let f = Fixture::new();
    let rt = f.runtime();
    let b = f.budget();
    let mut c = begin(&rt, "by-id", &b);
    initialize(&rt, &mut c, &b);
    let entity = rt
        .conversation_native_entity_query(
            &mut c,
            NativeEntityQuery::ById {
                id: "person".into(),
            },
            &b,
        )
        .unwrap();
    assert_eq!(entity.status, NativeContextStatus::Answered);
    assert_eq!(entity.entity.as_ref().unwrap().label, "Ada");
    commit(&rt, c, b"{}", &b);

    // Installing a fitted calibration model clears the entity anchor while retaining the model.
    let mut c = begin(&rt, "install-model", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::InstallModel {
                model: RetainedFittedModel::Calibration {
                    request: "install-model".into(),
                    revision: 2,
                    intercept: "1".into(),
                    slope: "2".into(),
                    x_unit: "m".into(),
                    response_unit: "N".into(),
                    direction: "forward_mean".into(),
                },
            },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    assert_eq!(r.anchor, NativeAnchor::Empty);
    assert!(r.fitted_model.is_some());
    commit(&rt, c, b"{}", &b);

    // Evaluating the retained model at x = 5 m produces 1 + 2*5 = 11 N as the quantity anchor.
    let mut c = begin(&rt, "eval-model", &b);
    let r = rt
        .conversation_native_command(
            &mut c,
            NativeContextCommand::EvaluateModel { value: "5".into() },
            &b,
        )
        .unwrap();
    assert_eq!(r.status, NativeContextStatus::Answered);
    assert_eq!(r.quantity().unwrap().number, "11/1");
    assert_eq!(r.quantity().unwrap().unit, "N");
    assert!(r.fitted_model.is_some());
    commit(&rt, c, b"{}", &b);
}
