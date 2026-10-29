use oracle_runtime_core::effects::{
    self, EffectIntent, EffectLimits, EffectOutbox, EffectState, Reconciliation, ReplayPolicy,
};
use oracle_runtime_core::{Error, Result};
use rusqlite::{Connection, Transaction, TransactionBehavior};
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;

fn transaction<T>(db: &mut Connection, f: impl FnOnce(&Transaction<'_>) -> Result<T>) -> Result<T> {
    let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
    let result = f(&tx)?;
    tx.commit()?;
    Ok(result)
}
fn open(path: &Path) -> Connection {
    let db = Connection::open(path).unwrap();
    db.execute_batch(
        "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA trusted_schema=OFF;",
    )
    .unwrap();
    db
}
struct Fixture {
    _directory: TempDir,
    path: PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("state.sqlite");
        let mut db = open(&path);
        transaction(&mut db, |tx| {
            effects::initialize(tx)?;
            tx.execute_batch(
                "CREATE TABLE host_state(version INTEGER); CREATE TABLE host_reply(reply TEXT);",
            )?;
            Ok(())
        })
        .unwrap();
        Self {
            _directory: directory,
            path,
        }
    }
    fn db(&self) -> Connection {
        open(&self.path)
    }
}
fn broker() -> EffectOutbox {
    EffectOutbox::new(EffectLimits::default()).unwrap()
}
fn intent(id: &str, replay: ReplayPolicy) -> EffectIntent {
    EffectIntent {
        id: id.into(),
        session: "s".into(),
        request: "r".into(),
        capability: "lesson_publish".into(),
        replay,
        payload: br#"{"snapshot":"sha256-source","recipe":"checked_steps","target":"artifact_1"}"#
            .to_vec(),
    }
}
fn usage(db: &Connection) -> (u64, u64) {
    db.query_row(
        "SELECT entries,value_bytes FROM effect_usage WHERE singleton=1",
        [],
        |r| Ok((r.get(0)?, r.get(1)?)),
    )
    .unwrap()
}

#[test]
fn reply_state_and_intents_share_the_same_commit_or_rollback() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    let failed: Result<()> = transaction(&mut db, |tx| {
        tx.execute("INSERT INTO host_state VALUES(1)", [])?;
        tx.execute("INSERT INTO host_reply VALUES('accepted')", [])?;
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))?;
        Err(Error::Cancelled)
    });
    assert!(matches!(failed, Err(Error::Cancelled)));
    assert_eq!(usage(&db), (0, 0));
    assert_eq!(
        db.query_row("SELECT count(*) FROM host_state", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        db.query_row("SELECT count(*) FROM host_reply", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    transaction(&mut db, |tx| {
        tx.execute("INSERT INTO host_state VALUES(1)", [])?;
        tx.execute("INSERT INTO host_reply VALUES('accepted')", [])?;
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))?;
        Ok(())
    })
    .unwrap();
    drop(db);
    let mut db = fixture.db();
    assert_eq!(usage(&db).0, 1);
    assert_eq!(
        db.query_row("SELECT reply FROM host_reply", [], |r| r
            .get::<_, String>(0))
            .unwrap(),
        "accepted"
    );
    assert_eq!(
        transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
            .unwrap()
            .unwrap()
            .state,
        EffectState::Pending
    );
}

#[test]
fn immutable_identity_binds_every_origin_policy_and_body_field() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    let original = intent("one", ReplayPolicy::AtMostOnce);
    let first = transaction(&mut db, |tx| outbox.enqueue(tx, "t", &original)).unwrap();
    assert_eq!(
        transaction(&mut db, |tx| outbox.enqueue(tx, "t", &original)).unwrap(),
        first
    );
    let mut variants = Vec::new();
    for field in 0..5 {
        let mut changed = original.clone();
        match field {
            0 => changed.payload.push(b' '),
            1 => changed.session = "another".into(),
            2 => changed.request = "another".into(),
            3 => changed.capability = "another".into(),
            _ => changed.replay = ReplayPolicy::ReceiverDeduplicated,
        }
        variants.push(changed);
    }
    for changed in variants {
        assert!(matches!(
            transaction(&mut db, |tx| outbox.enqueue(tx, "t", &changed)),
            Err(Error::Conflict(_))
        ));
    }
    let other = transaction(&mut db, |tx| outbox.enqueue(tx, "other", &original)).unwrap();
    assert_ne!(first.body_digest, other.body_digest);
    assert_eq!(usage(&db).0, 2);
    assert!(transaction(&mut db, |tx| outbox.get(tx, "absent", "one"))
        .unwrap()
        .is_none());
}

#[test]
fn uncommitted_claim_never_escapes_as_durable_ownership() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    {
        let tx = db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .unwrap();
        let lease = outbox
            .claim(&tx, "t", "one", "worker", 100, 10)
            .unwrap()
            .unwrap();
        assert_eq!(lease.effect.state, EffectState::Leased);
        // The embedding host must not execute anything before this commit.
    }
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "second", 100, 10)
    })
    .unwrap()
    .unwrap();
    assert_eq!(lease.fence.generation(), 1);
}

#[test]
fn independent_store_connections_cannot_both_commit_a_claim() {
    let fixture = Fixture::new();
    let outbox = broker();
    let mut first = fixture.db();
    let mut second = fixture.db();
    second.busy_timeout(std::time::Duration::ZERO).unwrap();
    transaction(&mut first, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    let tx = first
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .unwrap();
    let claimed = outbox
        .claim(&tx, "t", "one", "first", 100, 10)
        .unwrap()
        .unwrap();
    let busy = transaction(&mut second, |tx| {
        outbox.claim(tx, "t", "one", "second", 100, 10)
    });
    assert!(matches!(busy, Err(Error::Busy)));
    tx.commit().unwrap();
    assert!(transaction(&mut second, |tx| outbox
        .claim(tx, "t", "one", "second", 101, 10))
    .unwrap()
    .is_none());
    transaction(&mut second, |tx| {
        outbox.complete(tx, &claimed.fence, 101, b"done")
    })
    .unwrap();
}

#[test]
fn expired_non_idempotent_work_is_uncertain_and_cannot_be_claimed() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    assert!(
        transaction(&mut db, |tx| outbox.claim(tx, "t", "one", "other", 101, 10))
            .unwrap()
            .is_none()
    );
    assert!(
        transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 109, 1))
            .unwrap()
            .is_empty()
    );
    let expired = transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 1)).unwrap();
    assert_eq!(expired.len(), 1);
    assert_eq!(expired[0].state, EffectState::Uncertain);
    assert!(transaction(&mut db, |tx| outbox.claim_next(
        tx,
        "t",
        "lesson_publish",
        "other",
        111,
        10
    ))
    .unwrap()
    .is_none());
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(
            tx,
            &lease.fence,
            111,
            b"late"
        )),
        Err(Error::Conflict(_))
    ));
    assert!(
        transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 1000, 1))
            .unwrap()
            .is_empty()
    );
    let row = transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
        .unwrap()
        .unwrap();
    assert_eq!(row.state, EffectState::Uncertain);
    assert!(row.result.is_none());
}

#[test]
fn receiver_dedup_recovery_changes_generation_and_rejects_late_results() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::ReceiverDeduplicated))
    })
    .unwrap();
    let old = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 1)).unwrap();
    let new = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 110, 10)
    })
    .unwrap()
    .unwrap();
    assert_eq!(old.fence.body_digest(), new.fence.body_digest());
    assert_eq!(new.fence.generation(), old.fence.generation() + 1);
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(tx, &old.fence, 111, b"old")),
        Err(Error::Conflict(_))
    ));
    transaction(&mut db, |tx| {
        outbox.complete(tx, &new.fence, 111, b"receiver_receipt")
    })
    .unwrap();
    // A lost commit acknowledgement can replay the same result after expiry.
    transaction(&mut db, |tx| {
        outbox.complete(tx, &new.fence, 999, b"receiver_receipt")
    })
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(
            tx,
            &new.fence,
            112,
            b"different"
        )),
        Err(Error::Conflict(_))
    ));
    let replay = transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::ReceiverDeduplicated))
    })
    .unwrap();
    assert_eq!(replay.result.as_deref(), Some(&b"receiver_receipt"[..]));
}

#[test]
fn renewal_invalidates_the_old_fence_and_expiry_is_strict() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    let renewed = transaction(&mut db, |tx| outbox.renew(tx, &lease.fence, 105, 20)).unwrap();
    assert_eq!(renewed.lease_until_ms(), 125);
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(tx, &lease.fence, 106, b"old")),
        Err(Error::Conflict(_))
    ));
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(tx, &renewed, 125, b"late")),
        Err(Error::Conflict(_))
    ));
    assert!(matches!(
        transaction(&mut db, |tx| outbox.renew(tx, &renewed, 125, 20)),
        Err(Error::Conflict(_))
    ));
    transaction(&mut db, |tx| outbox.complete(tx, &renewed, 124, b"timely")).unwrap();
}

#[test]
fn explicit_uncertainty_requires_authoritative_reconciliation_and_fresh_generation() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    transaction(&mut db, |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    transaction(&mut db, |tx| {
        outbox.mark_uncertain(tx, &lease.fence, 101, b"connection_lost")
    })
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| outbox.reconcile(
            tx,
            "t",
            "one",
            1,
            Reconciliation::NotApplied,
            b""
        )),
        Err(Error::Invalid(_))
    ));
    assert!(matches!(
        transaction(&mut db, |tx| outbox.reconcile(
            tx,
            "t",
            "one",
            0,
            Reconciliation::NotApplied,
            b"authoritative_absence"
        )),
        Err(Error::Conflict(_))
    ));
    transaction(&mut db, |tx| {
        outbox.reconcile(
            tx,
            "t",
            "one",
            1,
            Reconciliation::NotApplied,
            b"worker_stopped_receiver_absent",
        )
    })
    .unwrap();
    let fresh = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 102, 10)
    })
    .unwrap()
    .unwrap();
    assert_eq!(fresh.fence.generation(), 3);
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(
            tx,
            &lease.fence,
            103,
            b"late"
        )),
        Err(Error::Conflict(_))
    ));
    transaction(&mut db, |tx| {
        outbox.mark_uncertain(tx, &fresh.fence, 103, b"timeout")
    })
    .unwrap();
    transaction(&mut db, |tx| {
        outbox.reconcile(
            tx,
            "t",
            "one",
            3,
            Reconciliation::Applied(b"artifact_hash"),
            b"verified_receiver_receipt",
        )
    })
    .unwrap();
    let row = transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
        .unwrap()
        .unwrap();
    assert_eq!(row.state, EffectState::Completed);
    assert_eq!(row.generation, 4);
    assert_eq!(row.result.as_deref(), Some(&b"artifact_hash"[..]));
    assert_eq!(row.evidence, b"verified_receiver_receipt");
    assert!(
        transaction(&mut db, |tx| outbox.claim(tx, "t", "one", "other", 200, 10))
            .unwrap()
            .is_none()
    );
    assert_eq!(
        usage(&db).1,
        (row.intent.payload.len() + row.result.unwrap().len() + row.evidence.len()) as u64
    );
}

#[test]
fn recovery_and_inspection_are_tenant_scoped_bounded_and_page_by_key() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    for (tenant, id) in [("t", "a"), ("t", "b"), ("t", "c"), ("other", "a")] {
        transaction(&mut db, |tx| {
            outbox.enqueue(tx, tenant, &intent(id, ReplayPolicy::AtMostOnce))
        })
        .unwrap();
        transaction(&mut db, |tx| {
            outbox.claim(tx, tenant, id, "worker", 100, 10)
        })
        .unwrap();
    }
    assert_eq!(
        transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 2))
            .unwrap()
            .len(),
        2
    );
    assert_eq!(
        transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 2))
            .unwrap()
            .len(),
        1
    );
    let first = transaction(&mut db, |tx| {
        outbox.list(tx, "t", EffectState::Uncertain, None, 2)
    })
    .unwrap();
    assert_eq!(
        first.iter().map(|r| r.id.as_str()).collect::<Vec<_>>(),
        vec!["a", "b"]
    );
    let second = transaction(&mut db, |tx| {
        outbox.list(tx, "t", EffectState::Uncertain, Some("b"), 2)
    })
    .unwrap();
    assert_eq!(second[0].id, "c");
    assert_eq!(
        transaction(&mut db, |tx| outbox.get(tx, "other", "a"))
            .unwrap()
            .unwrap()
            .state,
        EffectState::Leased
    );
    assert!(matches!(
        transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 0)),
        Err(Error::Invalid(_))
    ));
    assert!(matches!(
        transaction(&mut db, |tx| outbox.list(
            tx,
            "t",
            EffectState::Pending,
            None,
            257
        )),
        Err(Error::Invalid(_))
    ));
}

#[test]
fn capacity_preserves_identity_and_exact_replay_while_refusing_new_work() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = EffectOutbox::new(EffectLimits {
        entries: 1,
        ..EffectLimits::default()
    })
    .unwrap();
    let original = intent("one", ReplayPolicy::AtMostOnce);
    transaction(&mut db, |tx| outbox.enqueue(tx, "t", &original)).unwrap();
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    transaction(&mut db, |tx| {
        outbox.complete(tx, &lease.fence, 101, b"done")
    })
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| outbox.enqueue(
            tx,
            "t",
            &intent("two", ReplayPolicy::AtMostOnce)
        )),
        Err(Error::Limit(_))
    ));
    assert_eq!(
        transaction(&mut db, |tx| outbox.enqueue(tx, "t", &original))
            .unwrap()
            .state,
        EffectState::Completed
    );
    assert_eq!(usage(&db), (1, (original.payload.len() + 4) as u64));
}

#[test]
fn payload_result_and_aggregate_byte_limits_leave_no_partial_outcomes() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = EffectOutbox::new(EffectLimits {
        payload_bytes: 8,
        result_bytes: 4,
        store_value_bytes: 10,
        ..EffectLimits::default()
    })
    .unwrap();
    let mut original = intent("one", ReplayPolicy::AtMostOnce);
    original.payload = b"12345678".to_vec();
    let mut too_large = original.clone();
    too_large.payload.push(b'9');
    assert!(matches!(
        transaction(&mut db, |tx| outbox.enqueue(tx, "t", &too_large)),
        Err(Error::Limit(_))
    ));
    assert_eq!(usage(&db), (0, 0));
    transaction(&mut db, |tx| outbox.enqueue(tx, "t", &original)).unwrap();
    let lease = transaction(&mut db, |tx| {
        outbox.claim(tx, "t", "one", "worker", 100, 10)
    })
    .unwrap()
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(
            tx,
            &lease.fence,
            101,
            b"large"
        )),
        Err(Error::Limit(_))
    ));
    assert!(matches!(
        transaction(&mut db, |tx| outbox.complete(tx, &lease.fence, 101, b"123")),
        Err(Error::Limit(_))
    ));
    assert_eq!(
        transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
            .unwrap()
            .unwrap()
            .state,
        EffectState::Leased
    );
    transaction(&mut db, |tx| outbox.complete(tx, &lease.fence, 101, b"ok")).unwrap();
    assert_eq!(usage(&db), (1, 10));
    let tighter = EffectOutbox::new(EffectLimits {
        payload_bytes: 7,
        ..EffectLimits::default()
    })
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| tighter.get(tx, "t", "one")),
        Err(Error::Limit(_))
    ));
    let tighter = EffectOutbox::new(EffectLimits {
        result_bytes: 1,
        ..EffectLimits::default()
    })
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| tighter.get(tx, "t", "one")),
        Err(Error::Limit(_))
    ));
}

#[test]
fn invalid_clocks_ids_and_overflow_do_not_claim_or_corrupt_work() {
    let fixture = Fixture::new();
    let mut db = fixture.db();
    let outbox = broker();
    let mut invalid = intent("../escape", ReplayPolicy::AtMostOnce);
    assert!(matches!(
        transaction(&mut db, |tx| outbox.enqueue(tx, "t", &invalid)),
        Err(Error::Invalid(_))
    ));
    invalid.id = "one".into();
    transaction(&mut db, |tx| outbox.enqueue(tx, "t", &invalid)).unwrap();
    for (now, duration) in [(-1, 10), (1, 0), (1, 300_001), (i64::MAX, 1)] {
        assert!(matches!(
            transaction(&mut db, |tx| outbox
                .claim(tx, "t", "one", "worker", now, duration)),
            Err(Error::Invalid(_))
        ));
    }
    assert_eq!(
        transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
            .unwrap()
            .unwrap()
            .state,
        EffectState::Pending
    );
    db.execute(
        "UPDATE effect_intents SET generation=?1 WHERE tenant='t' AND id='one'",
        [i64::MAX],
    )
    .unwrap();
    assert!(matches!(
        transaction(&mut db, |tx| outbox
            .claim(tx, "t", "one", "worker", 100, 10)),
        Err(Error::Limit(_))
    ));
}

// A separate test process exits with live SQLite transactions, so no Rust
// destructor can simulate a tidy rollback. It writes only this fixture's files.
#[test]
fn effect_crash_child() {
    let Some(path) = std::env::var_os("O7_NATIVE_EFFECT_TEST_CRASH_DB") else {
        return;
    };
    let mut db = open(Path::new(&path));
    let outbox = broker();
    match std::env::var("O7_NATIVE_EFFECT_TEST_CRASH_MODE")
        .unwrap()
        .as_str()
    {
        "origin" => {
            let tx = db
                .transaction_with_behavior(TransactionBehavior::Immediate)
                .unwrap();
            tx.execute("INSERT INTO host_state VALUES(1)", []).unwrap();
            tx.execute("INSERT INTO host_reply VALUES('accepted')", [])
                .unwrap();
            outbox
                .enqueue(&tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
                .unwrap();
            std::process::exit(23);
        }
        "completion" => {
            let lease = transaction(&mut db, |tx| {
                outbox.claim(tx, "t", "one", "worker", 100, 10)
            })
            .unwrap()
            .unwrap();
            // This scoped marker stands in for an external action that DID run.
            std::fs::write(Path::new(&path).with_extension("action"), b"ran_once").unwrap();
            let tx = db
                .transaction_with_behavior(TransactionBehavior::Immediate)
                .unwrap();
            outbox
                .complete(&tx, &lease.fence, 101, b"acknowledged")
                .unwrap();
            std::process::exit(23);
        }
        other => panic!("unexpected crash mode: {other}"),
    }
}
fn crash(fixture: &Fixture, mode: &str) {
    let output = Command::new(std::env::current_exe().unwrap())
        .args(["--exact", "effect_crash_child", "--nocapture"])
        .env("O7_NATIVE_EFFECT_TEST_CRASH_DB", &fixture.path)
        .env("O7_NATIVE_EFFECT_TEST_CRASH_MODE", mode)
        .output()
        .unwrap();
    assert_eq!(
        output.status.code(),
        Some(23),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn process_exit_before_origin_commit_leaves_no_reply_state_or_effect() {
    let fixture = Fixture::new();
    crash(&fixture, "origin");
    let mut db = fixture.db();
    let outbox = broker();
    assert_eq!(usage(&db), (0, 0));
    assert_eq!(
        db.query_row("SELECT count(*) FROM host_reply", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        db.query_row("SELECT count(*) FROM host_state", [], |r| r
            .get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert!(transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
        .unwrap()
        .is_none());
}

#[test]
fn process_exit_after_external_action_before_result_commit_is_never_auto_retried() {
    let fixture = Fixture::new();
    let outbox = broker();
    transaction(&mut fixture.db(), |tx| {
        outbox.enqueue(tx, "t", &intent("one", ReplayPolicy::AtMostOnce))
    })
    .unwrap();
    crash(&fixture, "completion");
    let mut db = fixture.db();
    assert_eq!(
        std::fs::read(fixture.path.with_extension("action")).unwrap(),
        b"ran_once"
    );
    let row = transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
        .unwrap()
        .unwrap();
    assert_eq!(row.state, EffectState::Leased);
    assert!(row.result.is_none());
    transaction(&mut db, |tx| outbox.recover_expired(tx, "t", 110, 1)).unwrap();
    assert!(transaction(&mut db, |tx| outbox.claim(
        tx,
        "t",
        "one",
        "new_worker",
        111,
        10
    ))
    .unwrap()
    .is_none());
    assert_eq!(
        transaction(&mut db, |tx| outbox.get(tx, "t", "one"))
            .unwrap()
            .unwrap()
            .state,
        EffectState::Uncertain
    );
    assert_eq!(usage(&db).0, 1);
}
