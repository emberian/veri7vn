use crate::query::{encode, evaluate, Selection};
use crate::{digest, lock, Budget, Cancellation, Error, Image, Plan, QueryResult, Result};
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

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct State {
    schema: u32,
    selection: Selection,
}

/// Host-internal pure-query runtime. No Python callbacks or external effects run
/// between snapshot and commit. It is therefore safe to reevaluate an uncommitted
/// request after a crash. Completed replies and state commit in one transaction.
pub struct Runtime {
    pub image: Arc<Image>,
    state: Mutex<Connection>,
}

fn identifier(s: &str) -> Result<()> {
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
        self.image.query(tenant, plan_json, cancellation)
    }
    pub fn open(image: Arc<Image>, store: &Path) -> Result<Self> {
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
            tx.pragma_update(None, "user_version", 1)?;
            tx.commit()?;
        } else if app != STORE_ID || version != 1 {
            return Err(Error::Format("state schema".into()));
        }
        db.execute_batch(
            "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA trusted_schema=OFF;",
        )?;
        db.pragma_update(None, "cache_size", -(image.limits.sqlite_cache_kib as i64))?;
        Ok(Self {
            image,
            state: Mutex::new(db),
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
        let binding = serde_json::to_vec(&(
            self.image.identity.as_str(),
            session,
            expected_version,
            plan_json,
        ))?;
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
        let plan = Plan::parse(plan_json, limits)?;
        let budget = Budget::new(limits, cancellation)?;
        let worker = self.image.acquire(tenant, &budget)?;
        let previous = {
            let db = lock(&self.state)?;
            let stored: Option<(String, i64, Option<String>)> = db
                .query_row(
                    "SELECT image,version,CASE WHEN length(CAST(state AS BLOB))<=?3 THEN state ELSE NULL END FROM sessions WHERE tenant=?1 AND id=?2",
                    params![tenant, session, limits.state_bytes],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )
                .optional()?;
            match stored {
                Some((image, _, _)) if image != self.image.identity => {
                    return Err(Error::Conflict("session requires image migration"))
                }
                Some((_, version, _)) if version != expected_version => {
                    return Err(Error::Conflict("state version changed"))
                }
                Some((_, _, None)) => return Err(Error::Limit("retained state bytes")),
                Some((_, _, Some(text))) => {
                    let state: State = serde_json::from_str(&text)?;
                    if state.schema != 1 {
                        return Err(Error::Format("session state version".into()));
                    }
                    state.selection
                }
                None if expected_version != 0 => return Err(Error::Conflict("session absent")),
                None => Selection::default(),
            }
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
        let state = encode(
            &State {
                schema: 1,
                selection,
            },
            limits.state_bytes,
        )?;
        budget.check()?;
        let mut db = lock(&self.state)?;
        let tx = db.transaction_with_behavior(TransactionBehavior::Immediate)?;
        if let Some(reply) =
            Self::replay(&tx, tenant, request, &request_digest, limits.result_bytes)?
        {
            return Ok(reply);
        }
        let current: Option<(String, i64)> = tx
            .query_row(
                "SELECT image,version FROM sessions WHERE tenant=?1 AND id=?2",
                params![tenant, session],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()?;
        if current.as_ref().is_some_and(|(image, version)| {
            image != &self.image.identity || *version != expected_version
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
        tx.execute("INSERT INTO sessions VALUES (?1,?2,?3,?4,?5) ON CONFLICT(tenant,id) DO UPDATE SET version=excluded.version,state=excluded.state",
            params![tenant,session,self.image.identity,expected_version+1,state])?;
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
