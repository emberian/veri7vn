mod host_effects;
use crate::query::{encode, evaluate, Selection};
use crate::release::{AdmittedRelease, SchemaVersion};
use crate::session::{SessionBinding, SessionEnvelope, SessionLimits, SessionSelection};
use crate::{digest, Budget, Cancellation, Error, Image, Plan, Program, QueryResult, Result};
pub use host_effects::HostEffects;
use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use serde::{Deserialize, Serialize};
use std::ops::{Deref, DerefMut};
use std::path::Path;
use std::sync::{Arc, Condvar, Mutex, Weak};

const STORE_ID: i64 = 0x4f375331;

// Persistent fences apply even to an already-open older runtime. This is a data
// integrity boundary, not a sandbox against a writer authorized to change DDL.
fn initialize_retention(tx: &rusqlite::Transaction<'_>) -> Result<()> {
    tx.execute_batch(
        "CREATE TABLE retirement_usage(
            singleton INTEGER PRIMARY KEY CHECK(singleton=1),
            entries INTEGER NOT NULL CHECK(entries>=0));
         INSERT INTO retirement_usage VALUES(1,0);
         CREATE TABLE retired_namespaces(
            tenant TEXT PRIMARY KEY NOT NULL CHECK(length(CAST(tenant AS BLOB)) BETWEEN 1 AND 128)
                CHECK(tenant NOT GLOB '*[^A-Za-z0-9_-]*')) WITHOUT ROWID;
         CREATE TRIGGER retirement_duplicate BEFORE INSERT ON retired_namespaces
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=NEW.tenant) BEGIN
            SELECT RAISE(ABORT,'namespace already retired');
         END;
         CREATE TRIGGER retirement_insert_usage AFTER INSERT ON retired_namespaces BEGIN
            UPDATE retirement_usage SET entries=entries+1 WHERE singleton=1;
         END;
         CREATE TRIGGER retirement_effects BEFORE INSERT ON retired_namespaces
            WHEN EXISTS(SELECT 1 FROM effect_intents WHERE tenant=NEW.tenant AND state!='completed') BEGIN
            SELECT RAISE(ABORT,'namespace has unresolved effects');
         END;
         CREATE TRIGGER retirement_immutable_update BEFORE UPDATE ON retired_namespaces BEGIN
            SELECT RAISE(ABORT,'retired namespaces are permanent');
         END;
         CREATE TRIGGER retirement_immutable_delete BEFORE DELETE ON retired_namespaces BEGIN
            SELECT RAISE(ABORT,'retired namespaces are permanent');
         END;
         CREATE TRIGGER retired_session_insert BEFORE INSERT ON sessions
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=NEW.tenant) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER retired_session_update BEFORE UPDATE ON sessions
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant IN (OLD.tenant,NEW.tenant)) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER retired_request_insert BEFORE INSERT ON requests
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=NEW.tenant) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER retired_request_update BEFORE UPDATE ON requests
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant IN (OLD.tenant,NEW.tenant)) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER retired_effect_insert BEFORE INSERT ON effect_intents
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=NEW.tenant) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER retired_effect_update BEFORE UPDATE ON effect_intents
            WHEN EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant IN (OLD.tenant,NEW.tenant)) BEGIN
            SELECT RAISE(ABORT,'namespace retired');
         END;
         CREATE TRIGGER effect_delete_usage AFTER DELETE ON effect_intents BEGIN
            UPDATE effect_usage SET entries=entries-1,
                value_bytes=value_bytes-length(OLD.payload)-coalesce(length(OLD.result),0)-length(OLD.evidence)
                WHERE singleton=1;
         END;",
    )?;
    Ok(())
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Execution {
    pub version: i64,
    pub result: QueryResult,
}

/// A completed bounded reader turn, including semantic refusals. This is not a
/// graph QueryResult or a claim of restoring the upstream dialogue engine.
#[derive(Debug, Serialize, Deserialize)]
pub struct LanguageExecution {
    pub version: i64,
    pub language: crate::reader::ReaderResult,
}

/// Input dialect is explicit and participates in durable request identity.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RequestDialect {
    Graph,
    KqaProgram,
    Language,
}
impl RequestDialect {
    fn compile(self, input: &str, limits: &crate::Limits) -> Result<Plan> {
        match self {
            Self::Graph => Plan::parse(input, limits),
            Self::KqaProgram => Program::parse(input, limits)?.compile(limits),
            Self::Language => Err(Error::Invalid("language is not a query plan".into())),
        }
    }
    fn operation(self, transactional: bool) -> &'static str {
        match (self, transactional) {
            (Self::Graph, false) => "graph.query",
            (Self::Graph, true) => "graph.execute",
            (Self::KqaProgram, false) => "kqa.query",
            (Self::KqaProgram, true) => "kqa.execute",
            (Self::Language, _) => "reader.execute",
        }
    }
}

// The connection is owned by a guard outside this short in-memory mutex.
// Admitted workers may wait for state I/O, never for another computation. New
// replay/effect lookups cannot overtake queued workers. No FIFO order is claimed.
struct StateSlot {
    connection: Option<Connection>,
    waiters: usize,
    failed: bool,
}
struct StateStore {
    slot: Arc<Mutex<StateSlot>>,
    ready: Arc<Condvar>,
}
struct StateWake {
    slot: Weak<Mutex<StateSlot>>,
    ready: Weak<Condvar>,
}
impl crate::budget::CancellationWake for StateWake {
    fn wake(&self) {
        if let (Some(slot), Some(ready)) = (self.slot.upgrade(), self.ready.upgrade()) {
            // Pair notification with the wait predicate's mutex: either the
            // waiter sees cancellation before sleeping, or this wakes its wait.
            let _slot = slot.lock().unwrap_or_else(|e| e.into_inner());
            ready.notify_all();
        }
    }
}
struct StateGuard<'a> {
    store: &'a StateStore,
    connection: Option<Connection>,
}
impl StateStore {
    fn new(connection: Connection) -> Self {
        Self {
            slot: Arc::new(Mutex::new(StateSlot {
                connection: Some(connection),
                waiters: 0,
                failed: false,
            })),
            ready: Arc::new(Condvar::new()),
        }
    }
    fn try_acquire(&self) -> Result<StateGuard<'_>> {
        let mut slot = self.slot.try_lock().map_err(|error| match error {
            std::sync::TryLockError::WouldBlock => Error::Busy,
            std::sync::TryLockError::Poisoned(_) => Error::Poisoned,
        })?;
        if slot.failed {
            return Err(Error::Poisoned);
        }
        if slot.waiters != 0 {
            return Err(Error::Busy);
        }
        let connection = slot.connection.take().ok_or(Error::Busy)?;
        Ok(StateGuard {
            store: self,
            connection: Some(connection),
        })
    }
    fn acquire(&self, budget: &Budget) -> Result<StateGuard<'_>> {
        budget.check()?;
        // Only bounded memory bookkeeping runs under this mutex. Database I/O
        // and fsync run under StateGuard and never hold the condition mutex.
        let mut slot = self.slot.lock().map_err(|_| Error::Poisoned)?;
        if slot.failed {
            return Err(Error::Poisoned);
        }
        budget.check()?;
        if slot.waiters == 0 {
            if let Some(connection) = slot.connection.take() {
                return Ok(StateGuard {
                    store: self,
                    connection: Some(connection),
                });
            }
        }
        drop(slot);
        // Register only on contention. No per-turn notification allocation on
        // the uncontended path, and no strong cycle back to the state store.
        let _registration = budget.wake_on_cancel(Arc::new(StateWake {
            slot: Arc::downgrade(&self.slot),
            ready: Arc::downgrade(&self.ready),
        }))?;
        let mut slot = self.slot.lock().map_err(|_| Error::Poisoned)?;
        slot.waiters += 1;
        self.ready.notify_all();
        loop {
            if slot.failed {
                slot.waiters -= 1;
                self.ready.notify_all();
                return Err(Error::Poisoned);
            }
            if let Err(error) = budget.check() {
                slot.waiters -= 1;
                self.ready.notify_all();
                return Err(error);
            }
            if let Some(connection) = slot.connection.take() {
                slot.waiters -= 1;
                return Ok(StateGuard {
                    store: self,
                    connection: Some(connection),
                });
            }
            let remaining = match budget.remaining_time() {
                Ok(remaining) => remaining,
                Err(error) => {
                    slot.waiters -= 1;
                    self.ready.notify_all();
                    return Err(error);
                }
            };
            // Notifications (including spurious wakes) recheck the predicate and
            // the same monotonic deadline; this is not a retry/polling loop.
            let (next, _) = self
                .ready
                .wait_timeout(slot, remaining)
                .map_err(|_| Error::Poisoned)?;
            slot = next;
        }
    }
}
impl Deref for StateGuard<'_> {
    type Target = Connection;
    fn deref(&self) -> &Connection {
        self.connection.as_ref().expect("live state guard")
    }
}
impl DerefMut for StateGuard<'_> {
    fn deref_mut(&mut self) -> &mut Connection {
        self.connection.as_mut().expect("live state guard")
    }
}
impl Drop for StateGuard<'_> {
    fn drop(&mut self) {
        // Preserve poisoning: every future acquisition still fails closed.
        let mut slot = match self.store.slot.lock() {
            Ok(slot) => slot,
            Err(poisoned) => poisoned.into_inner(),
        };
        slot.failed |= std::thread::panicking();
        slot.connection = self.connection.take();
        self.store.ready.notify_all();
    }
}

/// Host-internal pure-query runtime. No Python callbacks or external effects run
/// between snapshot and commit. It is therefore safe to reevaluate an uncommitted
/// request after a crash. Completed replies and state commit in one transaction.
pub struct Runtime {
    pub image: Arc<Image>,
    state: StateStore,
    release: Option<AdmittedRelease>,
}

pub(crate) fn identifier(s: &str) -> Result<()> {
    if s.is_empty()
        || s.len() > 128
        || !s
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))
    {
        return Err(Error::Invalid("invalid host identity or request ID".into()));
    }
    Ok(())
}

impl Runtime {
    pub fn query(
        &self,
        tenant: &str,
        plan_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.require_operation(RequestDialect::Graph.operation(false))?;
        self.image.query(tenant, plan_json, cancellation)
    }
    pub fn query_program(
        &self,
        tenant: &str,
        program_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.require_operation(RequestDialect::KqaProgram.operation(false))?;
        self.image.query_program(tenant, program_json, cancellation)
    }
    pub fn identity(&self) -> &str {
        self.release
            .as_ref()
            .map_or(&self.image.identity, |r| r.identity())
    }
    pub fn release(&self) -> Option<&AdmittedRelease> {
        self.release.as_ref()
    }
    pub fn read_whole(
        &self,
        tenant: &str,
        question: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.require_operation("reader.whole")?;
        self.image.read_whole(tenant, question, cancellation)
    }
    pub(crate) fn require_operation(&self, name: &str) -> Result<()> {
        if let Some(release) = &self.release {
            if release.require_implemented(name)?.version != 1 {
                return Err(Error::Format(
                    "unsupported operation contract version".into(),
                ));
            }
        }
        Ok(())
    }
    /// Development compatibility constructor: identity covers data, not code/profile.
    pub fn open(image: Arc<Image>, store: &Path) -> Result<Self> {
        Self::open_inner(image, store, None)
    }
    /// Host must admit measured runtime bytes and resources before this call.
    pub fn open_release(image: Arc<Image>, store: &Path, release: AdmittedRelease) -> Result<Self> {
        release.check_runtime(
            &image.identity,
            &image.limits,
            &[
                SchemaVersion {
                    id: "session".into(),
                    version: 2,
                },
                SchemaVersion {
                    id: "graph".into(),
                    version: 1,
                },
                SchemaVersion {
                    id: "kqa_program".into(),
                    version: 1,
                },
            ],
        )?;
        Self::open_inner(image, store, Some(release))
    }
    fn open_inner(
        image: Arc<Image>,
        store: &Path,
        release: Option<AdmittedRelease>,
    ) -> Result<Self> {
        let mut db = Connection::open(store)?;
        db.busy_timeout(std::time::Duration::ZERO)?;
        let app: i64 = db.pragma_query_value(None, "application_id", |r| r.get(0))?;
        let version: i64 = db.pragma_query_value(None, "user_version", |r| r.get(0))?;
        if app == 0 && version == 0 {
            let count: i64 =
                db.query_row("SELECT count(*) FROM sqlite_master", [], |r| r.get(0))?;
            if count != 0 {
                return Err(Error::Format("refusing foreign state database".into()));
            }
            let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
            tx.execute_batch("CREATE TABLE sessions(tenant TEXT NOT NULL,id TEXT NOT NULL,image TEXT NOT NULL,version INTEGER NOT NULL,state TEXT NOT NULL,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
                CREATE TABLE requests(tenant TEXT NOT NULL,id TEXT NOT NULL,digest TEXT NOT NULL,reply TEXT NOT NULL,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
                CREATE TABLE counts(id INTEGER PRIMARY KEY CHECK(id=1),sessions INTEGER NOT NULL,requests INTEGER NOT NULL);
                INSERT INTO counts VALUES(1,0,0);")?;
            tx.pragma_update(None, "application_id", STORE_ID)?;
            crate::effects::initialize(&tx)?;
            initialize_retention(&tx)?;
            tx.pragma_update(None, "user_version", 3)?;
            tx.commit()?;
        } else if app == STORE_ID && (version == 1 || version == 2) {
            let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
            if version == 1 {
                crate::effects::initialize(&tx)?;
            }
            initialize_retention(&tx)?;
            tx.pragma_update(None, "user_version", 3)?;
            tx.commit()?;
        } else if app != STORE_ID || version != 3 {
            return Err(Error::Format("state schema".into()));
        }
        db.execute_batch(
            "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA trusted_schema=OFF;",
        )?;
        db.pragma_update(None, "cache_size", -(image.limits.sqlite_cache_kib as i64))?;
        Ok(Self {
            image,
            state: StateStore::new(db),
            release,
        })
    }

    fn require_active_namespace(db: &Connection, tenant: &str) -> Result<()> {
        let retired: bool = db.query_row(
            "SELECT EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=?1)",
            [tenant],
            |r| r.get(0),
        )?;
        if retired {
            return Err(Error::Conflict("namespace retired"));
        }
        Ok(())
    }

    /// Authenticated-host maintenance only; never a tenant operation. This
    /// permanently closes a namespace and discards its replay, conversation and
    /// completed-effect audit payloads. The host must mint a fresh namespace for
    /// future work. Unresolved effects refuse retirement. Cancellation before
    /// commit rolls everything back; cancellation during commit may be too late.
    pub fn retire_namespace(&self, tenant: &str, cancellation: Cancellation) -> Result<()> {
        self.require_operation("host.retention.retire")?;
        identifier(tenant)?;
        let budget = Budget::new(&self.image.limits, cancellation)?;
        let mut db = self.state.acquire(&budget)?;
        let progress = budget.clone();
        db.progress_handler(1000, Some(move || progress.check().is_err()));
        let outcome = (|| -> Result<()> {
            let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
            let retired: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=?1)",
                [tenant],
                |r| r.get(0),
            )?;
            if retired {
                // Idempotence does not consume capacity or recreate any payload.
                budget.check()?;
                return Ok(());
            }
            let unresolved: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM effect_intents WHERE tenant=?1 AND state!='completed')",
                [tenant],
                |r| r.get(0),
            )?;
            if unresolved {
                return Err(Error::Conflict("namespace has unresolved effects"));
            }
            let retired_count: u64 = tx.query_row(
                "SELECT entries FROM retirement_usage WHERE singleton=1",
                [],
                |r| r.get(0),
            )?;
            if retired_count >= self.image.limits.retired_namespaces {
                return Err(Error::Limit("retired namespace capacity"));
            }
            budget.check()?;
            tx.execute("INSERT INTO retired_namespaces VALUES(?1)", [tenant])?;
            // The tombstone and all deletes share the IMMEDIATE write transaction.
            // The SQL fences remain after deletion, including on stale connections.
            tx.execute("DELETE FROM effect_intents WHERE tenant=?1", [tenant])?;
            let sessions = tx.execute("DELETE FROM sessions WHERE tenant=?1", [tenant])?;
            let requests = tx.execute("DELETE FROM requests WHERE tenant=?1", [tenant])?;
            let updated = tx.execute(
                "UPDATE counts SET sessions=sessions-?1,requests=requests-?2
                 WHERE id=1 AND sessions>=?1 AND requests>=?2",
                params![sessions as u64, requests as u64],
            )?;
            if updated != 1 {
                return Err(Error::Format("state counts inconsistent".into()));
            }
            budget.check()?;
            tx.commit()?;
            Ok(())
        })();
        db.progress_handler(0, None::<fn() -> bool>);
        match outcome {
            // Preserve the commit boundary: cancellation during a successful
            // fsync does not turn a durable retirement into a reported failure.
            Ok(()) => Ok(()),
            Err(error) => {
                budget.check()?;
                Err(error)
            }
        }
    }

    /// Host inspection only. This checks the durable fence, not a process cache.
    pub fn namespace_is_retired(&self, tenant: &str) -> Result<bool> {
        self.require_operation("host.retention.inspect")?;
        identifier(tenant)?;
        let db = self.state.try_acquire()?;
        db.query_row(
            "SELECT EXISTS(SELECT 1 FROM retired_namespaces WHERE tenant=?1)",
            [tenant],
            |r| r.get(0),
        )
        .map_err(Into::into)
    }

    fn replay(
        db: &Connection,
        tenant: &str,
        request: &str,
        expected_digest: &str,
        max_bytes: usize,
    ) -> Result<Option<String>> {
        Self::require_active_namespace(db, tenant)?;
        let found: Option<(String, Option<String>)> = db
            .query_row(
                "SELECT digest,CASE WHEN length(CAST(reply AS BLOB))<=?3 THEN reply ELSE NULL END FROM requests WHERE tenant=?1 AND id=?2",
                params![tenant, request, max_bytes],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?;
        match found {
            Some((d, _)) if d != expected_digest => {
                Err(Error::Conflict("request ID reused with changed input"))
            }
            Some((_, None)) => Err(Error::Limit("retained reply exceeds configured bytes")),
            Some((_, Some(reply))) => Ok(Some(reply)),
            None => Ok(None),
        }
    }

    /// Exact input bytes, image, session and expected version all bind request identity.
    /// Caller-supplied IDs are not authentication. The embedding host chooses tenant.
    pub fn execute(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        plan_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.execute_dialect(
            tenant,
            session,
            request,
            expected_version,
            plan_json,
            cancellation,
            RequestDialect::Graph,
            None,
        )
    }
    pub fn execute_program(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        program_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.execute_dialect(
            tenant,
            session,
            request,
            expected_version,
            program_json,
            cancellation,
            RequestDialect::KqaProgram,
            None,
        )
    }
    /// Commit an agreed native selection and reader reply with the same journal
    /// and concurrency contract as graph/program turns. No effects are proposed.
    pub fn execute_language(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        question: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        self.execute_dialect(
            tenant,
            session,
            request,
            expected_version,
            question,
            cancellation,
            RequestDialect::Language,
            None,
        )
    }
    #[allow(clippy::too_many_arguments)]
    fn execute_dialect(
        &self,
        tenant: &str,
        session: &str,
        request: &str,
        expected_version: i64,
        plan_json: &str,
        cancellation: Cancellation,
        dialect: RequestDialect,
        effects: Option<HostEffects<'_>>,
    ) -> Result<String> {
        self.require_operation(dialect.operation(true))?;
        if matches!(dialect, RequestDialect::Language) && self.image.capabilities.reader.is_none() {
            return Err(Error::Format("image has no learned reader tables".into()));
        }
        identifier(tenant)?;
        identifier(session)?;
        identifier(request)?;
        if expected_version < 0 || expected_version == i64::MAX {
            return Err(Error::Invalid("state version".into()));
        }
        let limits = &self.image.limits;
        if plan_json.len() > limits.request_bytes {
            return Err(Error::Limit("request bytes"));
        }
        // Preserve v1 graph retry identity; explicit program domain cannot collide.
        let mut binding = match dialect {
            RequestDialect::Graph => {
                serde_json::to_vec(&(self.identity(), session, expected_version, plan_json))?
            }
            RequestDialect::Language => serde_json::to_vec(&(
                "oracle_language_turn_v1",
                self.identity(),
                session,
                expected_version,
                plan_json,
            ))?,
            RequestDialect::KqaProgram => serde_json::to_vec(&(
                "oracle_kqa_program_v1",
                self.identity(),
                session,
                expected_version,
                plan_json,
            ))?,
        };
        if let Some(batch) = &effects {
            self.require_operation("host.effects.enqueue")?;
            if batch.intents.len() > limits.plan_nodes {
                return Err(Error::Limit("effect intents per turn"));
            }
            let mut ids = std::collections::BTreeSet::new();
            for intent in batch.intents {
                if intent.session != session || intent.request != request || !ids.insert(&intent.id)
                {
                    return Err(Error::Invalid("effect origin or duplicate intent".into()));
                }
            }
            let intent_bytes = encode(&batch.intents, limits.request_bytes)?;
            binding = serde_json::to_vec(&(
                "oracle_host_effects_v1",
                digest(&binding),
                batch.outbox.limits_digest()?,
                intent_bytes,
            ))?;
        }
        let request_digest = digest(&binding);
        // Completed retry consumes no execution slot and performs no evaluation.
        {
            let db = self.state.try_acquire()?;
            if let Some(reply) =
                Self::replay(&db, tenant, request, &request_digest, limits.result_bytes)?
            {
                return Ok(reply);
            }
        }
        let budget = Budget::new(limits, cancellation)?;
        budget.check()?;
        let plan = if matches!(dialect, RequestDialect::Language) {
            None
        } else {
            Some(dialect.compile(plan_json, limits)?)
        };
        let worker = self.image.acquire(tenant, &budget)?;
        let session_policy = SessionLimits {
            max_bytes: limits.state_bytes,
            ..Default::default()
        };
        let session_binding = SessionBinding {
            tenant: tenant.into(),
            session: session.into(),
            image: self.identity().into(),
        };
        let (mut envelope, previous_text) = {
            let db = self.state.acquire(&budget)?;
            Self::require_active_namespace(&db, tenant)?;
            let stored: Option<(String, i64, Option<String>)> = db
                .query_row(
                    "SELECT image,version,CASE WHEN length(CAST(state AS BLOB))<=?3 THEN state ELSE NULL END FROM sessions WHERE tenant=?1 AND id=?2",
                    params![tenant, session, limits.state_bytes],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )
                .optional()?;
            match stored {
                Some((image, _, _)) if image != self.identity() => {
                    return Err(Error::Conflict("session requires image migration"))
                }
                Some((_, version, _)) if version != expected_version => {
                    return Err(Error::Conflict("state version changed"))
                }
                Some((_, _, None)) => return Err(Error::Limit("retained state bytes")),
                Some((_, _, Some(text))) => {
                    let schema = serde_json::from_str::<serde_json::Value>(&text)?
                        .get("schema")
                        .and_then(|v| v.as_u64());
                    let envelope = match schema {
                        Some(1) => SessionEnvelope::migrate_relation_v1(
                            &text,
                            session_binding.clone(),
                            expected_version,
                            &session_policy,
                        )?,
                        Some(2) => SessionEnvelope::recover(
                            Some(&text),
                            &session_binding,
                            expected_version,
                            &session_policy,
                        )?,
                        _ => return Err(Error::Format("session state version".into())),
                    };
                    (envelope, Some(text))
                }
                None if expected_version != 0 => return Err(Error::Conflict("session absent")),
                None => (SessionEnvelope::new(session_binding)?, None),
            }
        };
        let previous = Selection {
            ids: envelope.selection.ids.clone(),
            facts: envelope.selection.facts.clone(),
            attributes: envelope.selection.attributes.clone(),
        };
        let (reply, selection) = if let Some(plan) = plan {
            let evaluation = evaluate(
                &worker,
                &self.image.identity,
                &plan,
                &previous,
                limits,
                &budget,
            );
            // SQLite interruption must retain the underlying budget reason.
            budget.check()?;
            let (result, selection) = evaluation?;
            (
                encode(
                    &Execution {
                        version: expected_version + 1,
                        result,
                    },
                    limits.result_bytes,
                )?,
                Some(selection),
            )
        } else {
            let evaluation = crate::reader::evaluate_whole(
                &worker,
                &self.image.identity,
                plan_json,
                &previous,
                limits,
                &crate::reader::ReaderLimits::default(),
                &budget,
            );
            budget.check()?;
            let (language, selection) = evaluation?;
            (
                encode(
                    &LanguageExecution {
                        version: expected_version + 1,
                        language,
                    },
                    limits.result_bytes,
                )?,
                selection,
            )
        };
        // Refusals and disagreements preserve selection. Every dialect leaves
        // pending interpretations and adapter-owned conversation data intact.
        if let Some(selection) = selection {
            envelope.selection = SessionSelection {
                ids: selection.ids,
                facts: selection.facts,
                attributes: selection.attributes,
            };
        }
        envelope.revision = expected_version + 1;
        let state = envelope.encode(&session_policy)?;
        budget.check()?;
        let mut db = self.state.acquire(&budget)?;
        let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
        if let Some(reply) =
            Self::replay(&tx, tenant, request, &request_digest, limits.result_bytes)?
        {
            return Ok(reply);
        }
        let current: Option<(String, i64, bool)> = tx
            .query_row(
                "SELECT image,version,state IS ?3 FROM sessions WHERE tenant=?1 AND id=?2",
                params![tenant, session, previous_text],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()?;
        if current.as_ref().is_some_and(|(image, version, unchanged)| {
            image != self.identity() || *version != expected_version || !unchanged
        }) || (current.is_none() && expected_version != 0)
        {
            return Err(Error::Conflict("state changed during evaluation"));
        }
        let (sessions, requests): (u64, u64) =
            tx.query_row("SELECT sessions,requests FROM counts WHERE id=1", [], |r| {
                Ok((r.get(0)?, r.get(1)?))
            })?;
        if requests >= limits.journal_entries {
            return Err(Error::Limit("request journal capacity"));
        }
        if current.is_none() && sessions >= limits.sessions {
            return Err(Error::Limit("session capacity"));
        }
        if let Some(batch) = &effects {
            for intent in batch.intents {
                budget.spend(1)?;
                batch.outbox.enqueue(&tx, tenant, intent)?;
            }
        }
        tx.execute("INSERT INTO sessions VALUES (?1,?2,?3,?4,?5) ON CONFLICT(tenant,id) DO UPDATE SET version=excluded.version,state=excluded.state",
            params![tenant,session,self.identity(),expected_version+1,state])?;
        tx.execute(
            "INSERT INTO requests VALUES (?1,?2,?3,?4)",
            params![tenant, request, request_digest, reply],
        )?;
        tx.execute(
            "UPDATE counts SET sessions=sessions+?1,requests=requests+1 WHERE id=1",
            [i64::from(current.is_none())],
        )?;
        // Cancellation before this boundary rolls back both writes. After commit,
        // return the durable reply even if the deadline expires during fsync.
        budget.check()?;
        tx.commit()?;
        Ok(reply)
    }
}

impl Image {
    /// Pure query API over the same image/evaluator/budget as transactional turns.
    /// No session, journal, effects, or background work; Previous is empty here.
    pub fn query(
        self: &Arc<Self>,
        tenant: &str,
        plan_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        identifier(tenant)?;
        let limits = &self.limits;
        let plan = Plan::parse(plan_json, limits)?;
        let budget = Budget::new(limits, cancellation)?;
        let worker = self.acquire(tenant, &budget)?;
        let outcome = evaluate(
            &worker,
            &self.identity,
            &plan,
            &Selection::default(),
            limits,
            &budget,
        );
        budget.check()?;
        let (result, _) = outcome?;
        let encoded = encode(&result, limits.result_bytes)?;
        budget.check()?;
        Ok(encoded)
    }
}

#[cfg(test)]
mod state_admission_tests {
    use super::*;
    use std::sync::mpsc;

    fn store() -> Arc<StateStore> {
        Arc::new(StateStore::new(Connection::open_in_memory().unwrap()))
    }
    fn wait_for_admission(store: &StateStore) {
        let mut slot = store.slot.lock().unwrap();
        while slot.waiters == 0 {
            slot = store.ready.wait(slot).unwrap();
        }
    }
    #[test]
    fn admitted_worker_waits_for_replay_and_release_notifies_it() {
        let store = store();
        let replay = store.try_acquire().unwrap();
        let (sent, received) = mpsc::channel();
        let waiting = store.clone();
        let thread = std::thread::spawn(move || {
            let budget = Budget::new(&crate::Limits::default(), Cancellation::default()).unwrap();
            let guard = waiting.acquire(&budget).unwrap();
            sent.send(
                guard
                    .query_row("SELECT 1", [], |r| r.get::<_, i64>(0))
                    .unwrap(),
            )
            .unwrap();
        });
        wait_for_admission(&store);
        assert!(matches!(store.try_acquire(), Err(Error::Busy)));
        drop(replay);
        assert_eq!(
            received
                .recv_timeout(std::time::Duration::from_secs(5))
                .unwrap(),
            1
        );
        thread.join().unwrap();
        assert!(store.try_acquire().is_ok());
    }
    #[test]
    fn waiting_worker_obeys_original_deadline_and_cancel_on_notification() {
        let store = store();
        let replay = store.try_acquire().unwrap();
        let waiting = store.clone();
        let thread = std::thread::spawn(move || {
            let limits = crate::Limits {
                timeout_ms: 25,
                ..Default::default()
            };
            let budget = Budget::new(&limits, Cancellation::default()).unwrap();
            assert!(matches!(waiting.acquire(&budget), Err(Error::Deadline)));
        });
        thread.join().unwrap();
        assert_eq!(store.slot.lock().unwrap().waiters, 0);
        let directory = tempfile::tempdir().unwrap();
        let source = directory.path().join("source.json");
        let output = directory.path().join("image.sqlite");
        std::fs::write(&source, r#"{"concepts":{},"entities":{}}"#).unwrap();
        let receipt = crate::build_image(&source, &output, 100_000, 10_000).unwrap();
        let image = Image::open(&output, &receipt.image_sha256, crate::Limits::default()).unwrap();
        let leased_image = image.clone();
        let cancellation = Cancellation::default();
        let cancel = cancellation.clone();
        let waiting = store.clone();
        let (sent, received) = mpsc::channel();
        let thread = std::thread::spawn(move || {
            let limits = crate::Limits {
                timeout_ms: 30_000,
                ..Default::default()
            };
            let budget = Budget::new(&limits, cancel).unwrap();
            let worker = leased_image.acquire("cancelled_waiter", &budget).unwrap();
            assert!(matches!(waiting.acquire(&budget), Err(Error::Cancelled)));
            drop(worker);
            sent.send(()).unwrap();
        });
        wait_for_admission(&store);
        assert_eq!(image.active_workers(), 1);
        cancellation.cancel();
        // The database owner is still held. A 30s deadline must not postpone
        // cancellation; notification must remove admission bookkeeping now.
        received
            .recv_timeout(std::time::Duration::from_secs(2))
            .unwrap();
        assert_eq!(store.slot.lock().unwrap().waiters, 0);
        assert_eq!(image.active_workers(), 0);
        assert!(store.slot.lock().unwrap().connection.is_none());
        thread.join().unwrap();
        drop(replay);
        assert!(store.try_acquire().is_ok());
    }
    #[test]
    fn panic_while_holding_state_fails_closed() {
        let store = store();
        let panicking = store.clone();
        assert!(std::thread::spawn(move || {
            let _guard = panicking.try_acquire().unwrap();
            panic!("manufactured state-owner failure");
        })
        .join()
        .is_err());
        assert!(matches!(store.try_acquire(), Err(Error::Poisoned)));
        let budget = Budget::new(&crate::Limits::default(), Cancellation::default()).unwrap();
        assert!(matches!(store.acquire(&budget), Err(Error::Poisoned)));
    }
}
