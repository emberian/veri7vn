use oracle_runtime_core::effects::{
    EffectIntent, EffectLimits, EffectOutbox, EffectState, Reconciliation, ReplayPolicy,
};
use oracle_runtime_core::{build_image, Cancellation, Error, HostEffects, Image, Limits, Runtime};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::Arc;
use tempfile::TempDir;

struct Fixture {
    _directory: TempDir,
    image: Arc<Image>,
    store: PathBuf,
}
impl Fixture {
    fn new(limits: Limits) -> Self {
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("kb.json");
        let path = directory.path().join("image.sqlite");
        std::fs::write(
            &source,
            json!({"concepts":{"C":{"name":"Person","instanceOf":[]}},
            "entities":{"Q1":{"name":"Alice","instanceOf":["C"],"relations":[]},
            "Q2":{"name":"Bob","instanceOf":["C"],"relations":[]}}})
            .to_string(),
        )
        .unwrap();
        let receipt = build_image(&source, &path, 100_000, 10_000).unwrap();
        let image = Image::open(&path, &receipt.image_sha256, limits).unwrap();
        let store = directory.path().join("state.sqlite");
        Self {
            _directory: directory,
            image,
            store,
        }
    }
    fn runtime(&self) -> Runtime {
        Runtime::open(Arc::clone(&self.image), &self.store).unwrap()
    }
}
fn outbox() -> EffectOutbox {
    EffectOutbox::new(EffectLimits::default()).unwrap()
}
fn intent(id: &str, request: &str) -> EffectIntent {
    EffectIntent {
        id: id.into(),
        session: "s".into(),
        request: request.into(),
        capability: "lesson_publish".into(),
        replay: ReplayPolicy::AtMostOnce,
        payload: br#"{"snapshot":"immutable_source","checked_recipe":"lesson_1"}"#.to_vec(),
    }
}
fn plan(name: &str) -> String {
    json!({"nodes":[{"op":"find","name":name}],"output":0,"projection":{"kind":"unique_name"}})
        .to_string()
}
fn previous() -> String {
    json!({"nodes":[{"op":"previous"}],"output":0,"projection":{"kind":"unique_name"}}).to_string()
}
fn program() -> String {
    json!([{"function":"Find","dependencies":[],"inputs":["Alice"]},
        {"function":"What","dependencies":[0],"inputs":[]}])
    .to_string()
}

#[test]
fn graph_turn_commits_queued_intents_and_exact_reply_survives_settlement_restart() {
    let fixture = Fixture::new(Limits::default());
    let broker = outbox();
    let runtime = fixture.runtime();
    let intents = [intent("lesson", "r")];
    let reply = runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &intents,
            },
        )
        .unwrap();
    let decoded: Value = serde_json::from_str(&reply).unwrap();
    assert_eq!(decoded["version"], 1);
    assert_eq!(decoded["result"]["value"]["candidate"]["name"], "Alice");
    assert_eq!(
        runtime
            .effect_get(&broker, "t", "lesson")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Pending
    );
    let lease = runtime
        .effect_claim_next(&broker, "t", "lesson_publish", "worker", 100, 10)
        .unwrap()
        .unwrap();
    runtime
        .effect_complete(&broker, &lease.fence, 101, b"checked_artifact_hash")
        .unwrap();
    drop(runtime);
    let runtime = fixture.runtime();
    let cancellation = Cancellation::default();
    cancellation.cancel();
    assert_eq!(
        runtime
            .execute_with_effects(
                "t",
                "s",
                "r",
                0,
                &plan("Alice"),
                cancellation,
                HostEffects {
                    outbox: &broker,
                    intents: &intents
                }
            )
            .unwrap(),
        reply
    );
    assert!(runtime
        .effect_claim(&broker, "t", "lesson", "other", 200, 10)
        .unwrap()
        .is_none());
    assert_eq!(
        runtime
            .effect_get(&broker, "t", "lesson")
            .unwrap()
            .unwrap()
            .result
            .as_deref(),
        Some(&b"checked_artifact_hash"[..])
    );
    let next: Value = serde_json::from_str(
        &runtime
            .execute("t", "s", "r2", 1, &previous(), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(next["version"], 2);
    assert_eq!(next["result"]["value"]["candidate"]["name"], "Alice");
}

#[test]
fn changed_intent_or_actual_limit_profile_cannot_replay_a_committed_request() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let original = [intent("lesson", "r")];
    runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &original,
            },
        )
        .unwrap();
    let mut changed = original.clone();
    changed[0].payload.push(b' ');
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &changed
            }
        ),
        Err(Error::Conflict(_))
    ));
    let different = EffectOutbox::new(EffectLimits {
        entries: 9999,
        ..EffectLimits::default()
    })
    .unwrap();
    assert_ne!(
        broker.limits_digest().unwrap(),
        different.limits_digest().unwrap()
    );
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &different,
                intents: &original
            }
        ),
        Err(Error::Conflict(_))
    ));
    assert!(matches!(
        runtime.execute("t", "s", "r", 0, &plan("Alice"), Cancellation::default()),
        Err(Error::Conflict(_))
    ));
}

#[test]
fn every_effect_limit_participates_in_actual_profile_identity() {
    let base = EffectLimits::default();
    let digest = EffectOutbox::new(base.clone())
        .unwrap()
        .limits_digest()
        .unwrap();
    for field in 0..6 {
        let mut changed = base.clone();
        match field {
            0 => changed.entries += 1,
            1 => changed.payload_bytes += 1,
            2 => changed.result_bytes += 1,
            3 => changed.store_value_bytes += 1,
            4 => changed.max_lease_ms += 1,
            _ => changed.recovery_batch += 1,
        }
        assert_ne!(
            EffectOutbox::new(changed).unwrap().limits_digest().unwrap(),
            digest
        );
    }
}

#[test]
fn failed_later_enqueue_rolls_back_earlier_intent_reply_and_next_session_state() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let seed = [intent("existing", "r0")];
    runtime
        .execute_with_effects(
            "t",
            "s",
            "r0",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &seed,
            },
        )
        .unwrap();
    let proposed = [intent("new", "r1"), intent("existing", "r1")];
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r1",
            1,
            &plan("Bob"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposed
            }
        ),
        Err(Error::Conflict(_))
    ));
    assert!(runtime.effect_get(&broker, "t", "new").unwrap().is_none());
    assert_eq!(
        runtime
            .effect_get(&broker, "t", "existing")
            .unwrap()
            .unwrap()
            .intent
            .request,
        "r0"
    );
    // The failed request did not retain a reply or advance state to Bob.
    let recovered: Value = serde_json::from_str(
        &runtime
            .execute("t", "s", "r1", 1, &previous(), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(recovered["version"], 2);
    assert_eq!(recovered["result"]["value"]["candidate"]["name"], "Alice");
}

#[test]
fn outbox_capacity_failure_rolls_back_whole_turn_and_identity_can_be_retried() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let small = EffectOutbox::new(EffectLimits {
        entries: 1,
        ..EffectLimits::default()
    })
    .unwrap();
    let proposals = [intent("first", "r"), intent("second", "r")];
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &small,
                intents: &proposals
            }
        ),
        Err(Error::Limit(_))
    ));
    assert!(runtime.effect_get(&small, "t", "first").unwrap().is_none());
    assert!(runtime.effect_get(&small, "t", "second").unwrap().is_none());
    let adequate = outbox();
    let reply = runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &adequate,
                intents: &proposals,
            },
        )
        .unwrap();
    assert_eq!(serde_json::from_str::<Value>(&reply).unwrap()["version"], 1);
    assert_eq!(
        runtime
            .effect_list(&adequate, "t", EffectState::Pending, None, 2)
            .unwrap()
            .len(),
        2
    );
}

#[test]
fn origin_mismatch_is_refused_before_a_turn_or_any_effect_commits() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    for field in 0..2 {
        let mut proposal = intent("lesson", "r");
        if field == 0 {
            proposal.session = "another".into();
        } else {
            proposal.request = "another".into();
        }
        assert!(runtime
            .execute_with_effects(
                "t",
                "s",
                "r",
                0,
                &plan("Alice"),
                Cancellation::default(),
                HostEffects {
                    outbox: &broker,
                    intents: &[proposal]
                }
            )
            .is_err());
    }
    assert!(runtime
        .effect_get(&broker, "t", "lesson")
        .unwrap()
        .is_none());
    let corrected = [intent("lesson", "r")];
    let reply = runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &corrected,
            },
        )
        .unwrap();
    assert_eq!(serde_json::from_str::<Value>(&reply).unwrap()["version"], 1);
}

#[test]
fn intent_count_and_encoded_byte_budget_fail_without_partial_turns() {
    let fixture = Fixture::new(Limits {
        plan_nodes: 1,
        request_bytes: 1024,
        ..Limits::default()
    });
    let runtime = fixture.runtime();
    let broker = outbox();
    let many = [intent("one", "r"), intent("two", "r")];
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &many
            }
        ),
        Err(Error::Limit(_))
    ));
    let mut large = intent("one", "r");
    large.payload = vec![b'X'; 2048];
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &[large]
            }
        ),
        Err(Error::Limit(_))
    ));
    assert!(runtime
        .effect_list(&broker, "t", EffectState::Pending, None, 10)
        .unwrap()
        .is_empty());
    let plain: Value = serde_json::from_str(
        &runtime
            .execute("t", "s", "r", 0, &plan("Alice"), Cancellation::default())
            .unwrap(),
    )
    .unwrap();
    assert_eq!(plain["version"], 1);
}

#[test]
fn program_execution_and_invalid_program_do_not_turn_payloads_into_opcodes() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let proposals = [intent("lesson", "r")];
    let reply = runtime
        .execute_program_with_effects(
            "t",
            "s",
            "r",
            0,
            &program(),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals,
            },
        )
        .unwrap();
    assert_eq!(serde_json::from_str::<Value>(&reply).unwrap()["version"], 1);
    assert_eq!(
        runtime
            .effect_get(&broker, "t", "lesson")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Pending
    );
    let bad = json!([{"function":"run_shell","dependencies":[],"inputs":["echo no"]}]).to_string();
    let next = [intent("uncommitted", "r2")];
    assert!(runtime
        .execute_program_with_effects(
            "t",
            "s",
            "r2",
            1,
            &bad,
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &next
            }
        )
        .is_err());
    assert!(runtime
        .effect_get(&broker, "t", "uncommitted")
        .unwrap()
        .is_none());
    assert!(runtime
        .execute("t", "s", "r2", 1, &previous(), Cancellation::default())
        .is_ok());
}

#[test]
fn cancelled_evaluation_never_queues_an_effect_or_consumes_the_request() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let proposals = [intent("lesson", "r")];
    let cancellation = Cancellation::default();
    cancellation.cancel();
    assert!(matches!(
        runtime.execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            cancellation,
            HostEffects {
                outbox: &broker,
                intents: &proposals
            }
        ),
        Err(Error::Cancelled)
    ));
    assert!(runtime
        .effect_get(&broker, "t", "lesson")
        .unwrap()
        .is_none());
    assert!(runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals
            }
        )
        .is_ok());
}

#[test]
fn host_lifecycle_survives_restart_holds_uncertainty_and_requires_fresh_fences() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let mut second = intent("dedup", "r");
    second.replay = ReplayPolicy::ReceiverDeduplicated;
    let proposals = [intent("once", "r"), second];
    runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals,
            },
        )
        .unwrap();
    let once = runtime
        .effect_claim(&broker, "t", "once", "worker", 100, 10)
        .unwrap()
        .unwrap();
    let dedup = runtime
        .effect_claim(&broker, "t", "dedup", "worker", 100, 10)
        .unwrap()
        .unwrap();
    assert!(runtime
        .effect_get(&broker, "other", "once")
        .unwrap()
        .is_none());
    assert!(runtime
        .effect_claim_next(&broker, "other", "lesson_publish", "worker", 100, 10)
        .unwrap()
        .is_none());
    drop(runtime);
    let runtime = fixture.runtime();
    assert_eq!(
        runtime
            .effect_recover_expired(&broker, "t", 110, 1)
            .unwrap()
            .len(),
        1
    );
    assert_eq!(
        runtime
            .effect_recover_expired(&broker, "t", 110, 1)
            .unwrap()
            .len(),
        1
    );
    assert!(runtime
        .effect_claim(&broker, "t", "once", "new_worker", 111, 10)
        .unwrap()
        .is_none());
    assert!(matches!(
        runtime.effect_complete(&broker, &once.fence, 111, b"late"),
        Err(Error::Conflict(_))
    ));
    let fresh = runtime
        .effect_claim(&broker, "t", "dedup", "new_worker", 111, 10)
        .unwrap()
        .unwrap();
    assert!(matches!(
        runtime.effect_complete(&broker, &dedup.fence, 112, b"old"),
        Err(Error::Conflict(_))
    ));
    let renewed = runtime
        .effect_renew(&broker, &fresh.fence, 112, 20)
        .unwrap();
    assert!(matches!(
        runtime.effect_complete(&broker, &fresh.fence, 113, b"stale"),
        Err(Error::Conflict(_))
    ));
    runtime
        .effect_complete(&broker, &renewed, 113, b"deduplicated_receipt")
        .unwrap();
    runtime
        .effect_reconcile(
            &broker,
            "t",
            "once",
            once.fence.generation(),
            Reconciliation::Applied(b"verified_external_receipt"),
            b"receiver_queried_no_repeat",
        )
        .unwrap();
    assert_eq!(
        runtime
            .effect_get(&broker, "t", "once")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Completed
    );
    assert!(runtime
        .effect_list(&broker, "t", EffectState::Uncertain, None, 10)
        .unwrap()
        .is_empty());
}

#[test]
fn explicit_unknown_outcome_can_be_reconciled_without_automatic_reexecution() {
    let fixture = Fixture::new(Limits::default());
    let runtime = fixture.runtime();
    let broker = outbox();
    let proposals = [intent("lesson", "r")];
    runtime
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals,
            },
        )
        .unwrap();
    let first = runtime
        .effect_claim(&broker, "t", "lesson", "worker", 100, 10)
        .unwrap()
        .unwrap();
    runtime
        .effect_mark_uncertain(&broker, &first.fence, 101, b"lost_connection")
        .unwrap();
    assert!(runtime
        .effect_claim(&broker, "t", "lesson", "new_worker", 102, 10)
        .unwrap()
        .is_none());
    assert!(runtime
        .effect_reconcile(
            &broker,
            "t",
            "lesson",
            0,
            Reconciliation::NotApplied,
            b"no_action"
        )
        .is_err());
    runtime
        .effect_reconcile(
            &broker,
            "t",
            "lesson",
            1,
            Reconciliation::NotApplied,
            b"worker_stopped_receiver_absent",
        )
        .unwrap();
    let next = runtime
        .effect_claim(&broker, "t", "lesson", "new_worker", 102, 10)
        .unwrap()
        .unwrap();
    assert_eq!(next.fence.generation(), 3);
    assert!(runtime
        .effect_complete(&broker, &first.fence, 103, b"obsolete")
        .is_err());
    runtime
        .effect_complete(&broker, &next.fence, 103, b"checked_output_hash")
        .unwrap();
}

#[test]
fn admitted_query_release_does_not_grant_any_host_effect_operation() {
    use oracle_runtime_core::release::{
        runtime_profile_sha256, Availability, OperationRegistration, ReleaseBindings,
        ReleaseManifest,
    };
    let fixture = Fixture::new(Limits::default());
    let broker = outbox();
    let declaration=ReleaseManifest::from_json(&serde_json::to_vec(&json!({
        "schema":"oracle-native-release-v1","runtime_artifact_sha256":"1".repeat(64),
        "data_image_sha256":fixture.image.identity,
        "resource_profile_sha256":runtime_profile_sha256(&fixture.image.limits).unwrap(),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"session","version":3},{"id":"graph","version":1},{"id":"kqa_program","version":1}],
        "resources":[],"operations":[{"id":"graph.execute","version":1,"summary":"Synthetic graph execution",
            "availability":"implemented","input_schema":{},"output_schema":{},"resources":[],"limitations":[]}]
    })).unwrap()).unwrap();
    let expected = declaration.identity().unwrap();
    let measurements = ReleaseBindings {
        runtime_artifact_sha256: declaration.runtime_artifact_sha256.clone(),
        data_image_sha256: declaration.data_image_sha256.clone(),
        resource_profile_sha256: declaration.resource_profile_sha256.clone(),
        resources: vec![],
    };
    let admitted = declaration
        .admit(
            &expected,
            &measurements,
            &[OperationRegistration {
                id: "graph.execute".into(),
                availability: Availability::Implemented,
            }],
        )
        .unwrap();
    let runtime =
        Runtime::open_release(Arc::clone(&fixture.image), &fixture.store, admitted).unwrap();
    // Obtain a legitimate opaque fence in a separate host store. It confers no
    // authority on this release, which must reject before consulting its rows.
    let separate = Fixture::new(Limits::default());
    let other = separate.runtime();
    let proposed = [intent("lesson", "r")];
    other
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposed,
            },
        )
        .unwrap();
    let lease = other
        .effect_claim(&broker, "t", "lesson", "worker", 100, 10)
        .unwrap()
        .unwrap();
    let denied = vec![
        runtime
            .execute_with_effects(
                "t",
                "s",
                "r",
                0,
                &plan("Alice"),
                Cancellation::default(),
                HostEffects {
                    outbox: &broker,
                    intents: &proposed,
                },
            )
            .map(|_| ()),
        runtime.effect_get(&broker, "t", "lesson").map(|_| ()),
        runtime
            .effect_list(&broker, "t", EffectState::Pending, None, 1)
            .map(|_| ()),
        runtime
            .effect_claim(&broker, "t", "lesson", "worker", 100, 10)
            .map(|_| ()),
        runtime
            .effect_claim_next(&broker, "t", "lesson_publish", "worker", 100, 10)
            .map(|_| ()),
        runtime
            .effect_renew(&broker, &lease.fence, 101, 20)
            .map(|_| ()),
        runtime.effect_complete(&broker, &lease.fence, 101, b"receipt"),
        runtime.effect_mark_uncertain(&broker, &lease.fence, 101, b"unknown"),
        runtime
            .effect_recover_expired(&broker, "t", 110, 1)
            .map(|_| ()),
        runtime.effect_reconcile(
            &broker,
            "t",
            "lesson",
            1,
            Reconciliation::NotApplied,
            b"evidence",
        ),
    ];
    for result in denied {
        assert!(matches!(result,Err(Error::Invalid(ref why)) if why.starts_with("release:")));
    }
    // A refused effect proposal did not consume the graph request or session.
    assert!(runtime
        .execute("t", "s", "r", 0, &plan("Alice"), Cancellation::default())
        .is_ok());
}

fn effect_release(
    fixture: &Fixture,
    artifact: char,
) -> oracle_runtime_core::release::AdmittedRelease {
    use oracle_runtime_core::release::{
        runtime_profile_sha256, OperationRegistration, ReleaseBindings, ReleaseManifest,
    };
    let operations: Vec<_> = [
        "graph.execute",
        "host.effects.enqueue",
        "host.effects.inspect",
        "host.effects.claim",
        "host.effects.settle",
        "host.effects.recover",
        "host.effects.reconcile",
    ]
    .iter()
    .map(|id| {
        json!({"id":id,"version":1,"summary":id,"availability":"implemented",
            "input_schema":{},"output_schema":{},"resources":[],"limitations":[]})
    })
    .collect();
    let manifest=ReleaseManifest::from_json(&serde_json::to_vec(&json!({
        "schema":"oracle-native-release-v1","runtime_artifact_sha256":artifact.to_string().repeat(64),
        "data_image_sha256":fixture.image.identity,
        "resource_profile_sha256":runtime_profile_sha256(&fixture.image.limits).unwrap(),
        "appliance_receipt_sha256":null,
        "schemas":[{"id":"session","version":3},{"id":"graph","version":1},{"id":"kqa_program","version":1}],
        "resources":[],"operations":operations
    })).unwrap()).unwrap();
    let expected = manifest.identity().unwrap();
    let measurements = ReleaseBindings {
        runtime_artifact_sha256: manifest.runtime_artifact_sha256.clone(),
        data_image_sha256: manifest.data_image_sha256.clone(),
        resource_profile_sha256: manifest.resource_profile_sha256.clone(),
        resources: vec![],
    };
    let registrations: Vec<_> = manifest
        .operations
        .iter()
        .map(|op| OperationRegistration {
            id: op.id.clone(),
            availability: op.availability,
        })
        .collect();
    manifest
        .admit(&expected, &measurements, &registrations)
        .unwrap()
}

#[test]
fn new_release_cannot_inherit_effects_even_with_every_host_operation_allowed() {
    let fixture = Fixture::new(Limits::default());
    let broker = outbox();
    let original = Runtime::open_release(
        Arc::clone(&fixture.image),
        &fixture.store,
        effect_release(&fixture, '1'),
    )
    .unwrap();
    let mut dedup = intent("e_dedup", "r");
    dedup.replay = ReplayPolicy::ReceiverDeduplicated;
    let proposals = [
        intent("a_pending", "r"),
        intent("b_leased", "r"),
        intent("c_uncertain", "r"),
        intent("d_completed", "r"),
        dedup,
    ];
    original
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals,
            },
        )
        .unwrap();
    let leased = original
        .effect_claim(&broker, "t", "b_leased", "worker", 100, 50)
        .unwrap()
        .unwrap();
    let uncertain = original
        .effect_claim(&broker, "t", "c_uncertain", "worker", 100, 50)
        .unwrap()
        .unwrap();
    let completed = original
        .effect_claim(&broker, "t", "d_completed", "worker", 100, 50)
        .unwrap()
        .unwrap();
    original
        .effect_claim(&broker, "t", "e_dedup", "worker", 100, 10)
        .unwrap()
        .unwrap();
    original
        .effect_mark_uncertain(&broker, &uncertain.fence, 101, b"unknown")
        .unwrap();
    original
        .effect_complete(&broker, &completed.fence, 101, b"recorded_receipt")
        .unwrap();
    let replacement = Runtime::open_release(
        Arc::clone(&fixture.image),
        &fixture.store,
        effect_release(&fixture, '2'),
    )
    .unwrap();
    assert_ne!(replacement.identity(), original.identity());
    for (id, state) in [
        ("a_pending", EffectState::Pending),
        ("b_leased", EffectState::Leased),
        ("c_uncertain", EffectState::Uncertain),
        ("d_completed", EffectState::Completed),
    ] {
        assert!(matches!(
            replacement.effect_get(&broker, "t", id),
            Err(Error::Conflict(_))
        ));
        assert!(matches!(
            replacement.effect_list(&broker, "t", state, None, 10),
            Err(Error::Conflict(_))
        ));
    }
    let denied = vec![
        replacement
            .effect_claim(&broker, "t", "a_pending", "new_worker", 102, 10)
            .map(|_| ()),
        replacement
            .effect_claim(&broker, "t", "d_completed", "new_worker", 102, 10)
            .map(|_| ()),
        replacement
            .effect_claim_next(&broker, "t", "lesson_publish", "new_worker", 102, 10)
            .map(|_| ()),
        replacement
            .effect_renew(&broker, &leased.fence, 103, 60)
            .map(|_| ()),
        replacement.effect_complete(&broker, &leased.fence, 104, b"new_release_result"),
        replacement.effect_complete(&broker, &completed.fence, 104, b"recorded_receipt"),
        replacement.effect_mark_uncertain(&broker, &leased.fence, 105, b"new_release_unknown"),
        replacement.effect_reconcile(
            &broker,
            "t",
            "c_uncertain",
            1,
            Reconciliation::Applied(b"new_receipt"),
            b"new_evidence",
        ),
        replacement
            .effect_recover_expired(&broker, "t", 150, 10)
            .map(|_| ()),
    ];
    for result in denied {
        assert!(
            matches!(result,Err(Error::Conflict(why)) if why=="effect origin requires release migration")
        );
    }
    // Failed claim-next and recovery mutated rows only inside rolled-back
    // transactions. The originating release retains the exact prior state.
    let pending = original
        .effect_get(&broker, "t", "a_pending")
        .unwrap()
        .unwrap();
    assert_eq!(pending.state, EffectState::Pending);
    assert_eq!(pending.generation, 0);
    let old = original
        .effect_get(&broker, "t", "b_leased")
        .unwrap()
        .unwrap();
    assert_eq!(old.state, EffectState::Leased);
    assert_eq!(old.lease_until_ms, Some(150));
    assert_eq!(
        original
            .effect_get(&broker, "t", "e_dedup")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Leased
    );
    original
        .effect_reconcile(
            &broker,
            "t",
            "c_uncertain",
            1,
            Reconciliation::Applied(b"original_receipt"),
            b"original_evidence",
        )
        .unwrap();
    assert_eq!(
        original
            .effect_recover_expired(&broker, "t", 150, 10)
            .unwrap()
            .len(),
        2
    );
    original
        .effect_reconcile(
            &broker,
            "t",
            "b_leased",
            1,
            Reconciliation::Applied(b"verified_original"),
            b"receiver_confirmation",
        )
        .unwrap();
    for id in ["a_pending", "e_dedup"] {
        let lease = original
            .effect_claim(&broker, "t", id, "original_worker", 151, 10)
            .unwrap()
            .unwrap();
        original
            .effect_complete(&broker, &lease.fence, 152, b"original_result")
            .unwrap();
    }
    assert_eq!(
        original
            .effect_list(&broker, "t", EffectState::Completed, None, 10)
            .unwrap()
            .len(),
        5
    );
}

#[test]
fn mixed_release_recovery_rolls_back_own_rows_too_and_does_not_skip_old_pending() {
    let fixture = Fixture::new(Limits::default());
    let broker = outbox();
    let original = Runtime::open_release(
        Arc::clone(&fixture.image),
        &fixture.store,
        effect_release(&fixture, '1'),
    )
    .unwrap();
    let proposals = [intent("a_old_pending", "r"), intent("b_old_lease", "r")];
    original
        .execute_with_effects(
            "t",
            "s",
            "r",
            0,
            &plan("Alice"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &proposals,
            },
        )
        .unwrap();
    original
        .effect_claim(&broker, "t", "b_old_lease", "old_worker", 100, 10)
        .unwrap()
        .unwrap();
    let replacement = Runtime::open_release(
        Arc::clone(&fixture.image),
        &fixture.store,
        effect_release(&fixture, '2'),
    )
    .unwrap();
    let mut own = intent("z_new_lease", "new_request");
    own.session = "new_session".into();
    replacement
        .execute_with_effects(
            "t",
            "new_session",
            "new_request",
            0,
            &plan("Bob"),
            Cancellation::default(),
            HostEffects {
                outbox: &broker,
                intents: &[own],
            },
        )
        .unwrap();
    assert!(matches!(
        replacement.effect_claim_next(&broker, "t", "lesson_publish", "new_worker", 101, 10),
        Err(Error::Conflict(_))
    ));
    let own = replacement
        .effect_claim(&broker, "t", "z_new_lease", "new_worker", 102, 5)
        .unwrap()
        .unwrap();
    assert_eq!(own.fence.lease_until_ms(), 107);
    // The new release's own row expires first and passes validation. Encountering
    // the old row afterwards must roll back BOTH recovery transitions.
    assert!(matches!(
        replacement.effect_recover_expired(&broker, "t", 110, 10),
        Err(Error::Conflict(_))
    ));
    assert_eq!(
        replacement
            .effect_get(&broker, "t", "z_new_lease")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Leased
    );
    assert_eq!(
        original
            .effect_get(&broker, "t", "b_old_lease")
            .unwrap()
            .unwrap()
            .state,
        EffectState::Leased
    );
    assert_eq!(
        original
            .effect_get(&broker, "t", "a_old_pending")
            .unwrap()
            .unwrap()
            .generation,
        0
    );
}
