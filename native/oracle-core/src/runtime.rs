mod host_effects;
use crate::query::{encode, evaluate, Selection};
use crate::release::{AdmittedRelease, SchemaVersion};
use crate::session::{SessionBinding, SessionEnvelope, SessionLimits, SessionSelection};
use crate::{digest, lock, Budget, Cancellation, Error, Image, Plan, Program, QueryResult, Result};
pub use host_effects::HostEffects;
use rusqlite::{params, Connection, OptionalExtension, TransactionBehavior};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::{Arc, Mutex};

const STORE_ID: i64 = 0x4f375331;

#[derive(Debug, Serialize, Deserialize)]
pub struct Execution {
    pub version: i64,
    pub result: QueryResult,
}

/// Input dialect is explicit and participates in durable request identity.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RequestDialect {
    Graph,
    KqaProgram,
}
impl RequestDialect {
    fn compile(self, input: &str, limits: &crate::Limits) -> Result<Plan> {
        match self {
            Self::Graph => Plan::parse(input, limits),
            Self::KqaProgram => Program::parse(input, limits)?.compile(limits),
        }
    }
    fn operation(self, transactional: bool) -> &'static str {
        match (self, transactional) {
            (Self::Graph, false) => "graph.query",
            (Self::Graph, true) => "graph.execute",
            (Self::KqaProgram, false) => "kqa.query",
            (Self::KqaProgram, true) => "kqa.execute",
        }
    }
}

/// Host-internal pure-query runtime. No Python callbacks or external effects run
/// between snapshot and commit. It is therefore safe to reevaluate an uncommitted
/// request after a crash. Completed replies and state commit in one transaction.
pub struct Runtime {
    pub image: Arc<Image>,
    state: Mutex<Connection>,
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
            tx.pragma_update(None, "user_version", 2)?;
            tx.commit()?;
        } else if app == STORE_ID && version == 1 {
            let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
            crate::effects::initialize(&tx)?;
            tx.pragma_update(None, "user_version", 2)?;
            tx.commit()?;
        } else if app != STORE_ID || version != 2 {
            return Err(Error::Format("state schema".into()));
        }
        db.execute_batch(
            "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA trusted_schema=OFF;",
        )?;
        db.pragma_update(None, "cache_size", -(image.limits.sqlite_cache_kib as i64))?;
        Ok(Self {
            image,
            state: Mutex::new(db),
            release,
        })
    }

    fn replay(
        db: &Connection,
        tenant: &str,
        request: &str,
        expected_digest: &str,
        max_bytes: usize,
    ) -> Result<Option<String>> {
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
            let db = lock(&self.state)?;
            if let Some(reply) =
                Self::replay(&db, tenant, request, &request_digest, limits.result_bytes)?
            {
                return Ok(reply);
            }
        }
        let budget = Budget::new(limits, cancellation)?;
        budget.check()?;
        let plan = dialect.compile(plan_json, limits)?;
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
            let db = lock(&self.state)?;
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
        let evaluation = evaluate(
            &worker,
            &self.image.identity,
            &plan,
            &previous,
            limits,
            &budget,
        );
        // An SQLite interrupt caused by the budget must retain the actual reason.
        budget.check()?;
        let (result, selection) = evaluation?;
        let reply = encode(
            &Execution {
                version: expected_version + 1,
                result,
            },
            limits.result_bytes,
        )?;
        // Pure data queries do not consume pending conversational interpretations.
        envelope.selection = SessionSelection {
            ids: selection.ids,
            facts: selection.facts,
            attributes: selection.attributes,
        };
        envelope.revision = expected_version + 1;
        let state = envelope.encode(&session_policy)?;
        budget.check()?;
        let mut db = lock(&self.state)?;
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
