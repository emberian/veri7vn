use oracle_runtime_core::context_delta::{
    propose, ContextCommand, ContextState, ScalarOrigin, ScalarValue,
};
use oracle_runtime_core::session::SessionBinding;

fn binding() -> SessionBinding {
    SessionBinding {
        tenant: "tenant_a".into(),
        session: "same_session".into(),
        image: "image_a".into(),
    }
}
fn observe(number: &str, origin: ScalarOrigin) -> ContextCommand {
    ContextCommand::Observe {
        value: ScalarValue {
            number: number.into(),
            origin,
        },
    }
}

#[test]
fn successive_delivered_scalars_survive_owner_serialization() {
    let binding = binding();
    let empty = ContextState::default();
    let first = propose(
        &binding,
        0,
        "turn_1",
        &empty,
        &observe("2.5", ScalarOrigin::ExactDecimal),
    )
    .unwrap();
    let committed = first.commit(&binding, 0, &empty).unwrap();
    let recovered: ContextState =
        serde_json::from_str(&serde_json::to_string(&committed).unwrap()).unwrap();
    let second = propose(
        &binding,
        1,
        "turn_2",
        &recovered,
        &ContextCommand::Scale { factor: "3".into() },
    )
    .unwrap();
    assert_eq!(second.reply.scalar.as_ref().unwrap().value.number, "15/2");
    assert_eq!(second.reply.scalar.as_ref().unwrap().revision, 2);
    let committed = second.commit(&binding, 1, &recovered).unwrap();
    let third = propose(
        &binding,
        2,
        "turn_3",
        &committed,
        &ContextCommand::Scale {
            factor: "2/3".into(),
        },
    )
    .unwrap();
    assert_eq!(third.reply.scalar.unwrap().value.number, "5/1");
}

#[test]
fn losing_candidate_cannot_replace_prior_and_clear_is_explicit() {
    let binding = binding();
    let empty = ContextState::default();
    let committed = propose(
        &binding,
        0,
        "first",
        &empty,
        &observe("7", ScalarOrigin::ExactDecimal),
    )
    .unwrap()
    .commit(&binding, 0, &empty)
    .unwrap();
    let speculative = propose(
        &binding,
        1,
        "loser",
        &committed,
        &observe("999", ScalarOrigin::ExactDecimal),
    )
    .unwrap();
    drop(speculative);
    let inspect = propose(&binding, 1, "inspect", &committed, &ContextCommand::Inspect).unwrap();
    assert_eq!(inspect.reply.scalar.unwrap().value.number, "7");
    let cleared = propose(
        &binding,
        1,
        "correction",
        &committed,
        &ContextCommand::Clear,
    )
    .unwrap()
    .commit(&binding, 1, &committed)
    .unwrap();
    let missing = propose(
        &binding,
        2,
        "followup",
        &cleared,
        &ContextCommand::Scale { factor: "2".into() },
    )
    .unwrap();
    assert_eq!(missing.reply.status, "withheld");
    assert!(missing.reply.scalar.is_none());
}

#[test]
fn stale_identity_revision_and_owner_rejected() {
    let binding = binding();
    let current = ContextState::default();
    let proposal = propose(
        &binding,
        0,
        "first",
        &current,
        &observe("1", ScalarOrigin::ExactDecimal),
    )
    .unwrap();
    let mut other = binding.clone();
    other.tenant = "tenant_b".into();
    assert!(proposal.clone().commit(&other, 0, &current).is_err());
    other = binding.clone();
    other.image = "image_b".into();
    assert!(proposal.clone().commit(&other, 0, &current).is_err());
    assert!(proposal.clone().commit(&binding, 1, &current).is_err());
    let mut changed = current.clone();
    changed.version = 2;
    assert!(proposal.clone().commit(&binding, 0, &changed).is_err());
    assert!(propose(&binding, 0, "bad", &changed, &ContextCommand::Inspect).is_err());
    // Even an unchanged revision does not authorize overwriting another base.
    let different = propose(
        &binding,
        0,
        "other",
        &current,
        &observe("9", ScalarOrigin::ExactDecimal),
    )
    .unwrap()
    .commit(&binding, 0, &current)
    .unwrap();
    assert!(proposal.commit(&binding, 0, &different).is_err());
}

#[test]
fn imported_float_keeps_rounded_origin_and_inputs_are_bounded() {
    let binding = binding();
    let empty = ContextState::default();
    let state = propose(
        &binding,
        0,
        "legacy",
        &empty,
        &observe("0.1", ScalarOrigin::PythonFloat),
    )
    .unwrap()
    .commit(&binding, 0, &empty)
    .unwrap();
    let next = propose(
        &binding,
        1,
        "native",
        &state,
        &ContextCommand::Scale { factor: "3".into() },
    )
    .unwrap();
    assert_eq!(
        next.reply.scalar.unwrap().value.origin,
        ScalarOrigin::PythonFloat
    );
    for bad in ["NaN", "1e100000", "1/0", "1 m"] {
        assert!(propose(
            &binding,
            1,
            "bad",
            &state,
            &ContextCommand::Scale { factor: bad.into() }
        )
        .is_err());
    }
}
