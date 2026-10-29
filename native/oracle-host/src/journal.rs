//! Durable `/query` journal: exact retry by (tenant, request_id), as the
//! reference `serve.py` Service does per workspace, plus the registry that
//! pins a conversation to the Engine worker generation holding its context.

use crate::wire;
use crate::Failure;
use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Mutex;

pub struct Journal {
    db: Mutex<Connection>,
    retained: u64,
    conversations: u64,
}

pub enum Lookup {
    Fresh,
    Replay(u16, Value),
}

pub fn status_of(result: &Value) -> u16 {
    if result["outcome"] == "completed" {
        return 200;
    }
    if let Some(status) = result.get("http_status").and_then(Value::as_u64) {
        return status as u16;
    }
    if result["error"] == "query_timeout" {
        504
    } else {
        502
    }
}

fn lock(db: &Mutex<Connection>) -> std::sync::MutexGuard<'_, Connection> {
    db.lock().unwrap_or_else(|e| e.into_inner())
}

fn journal_error() -> Failure {
    Failure::new(
        507,
        "journal_error",
        json!({"state_may_have_changed": false}),
    )
}

impl Journal {
    pub fn open(path: &Path, retained: u64, conversations: u64) -> rusqlite::Result<Self> {
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let db = Connection::open(path)?;
        db.execute_batch(
            "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
             CREATE TABLE IF NOT EXISTS requests(tenant TEXT NOT NULL, id TEXT NOT NULL, body BLOB NOT NULL,
                 result BLOB, PRIMARY KEY(tenant,id)) WITHOUT ROWID;
             CREATE TABLE IF NOT EXISTS conversations(tenant TEXT NOT NULL, id TEXT NOT NULL,
                 worker INTEGER NOT NULL, generation TEXT NOT NULL, PRIMARY KEY(tenant,id)) WITHOUT ROWID;",
        )?;
        // A crash may have changed a conversation before its result was stored.
        let interrupted = wire::encode(&crate::failure(
            "interrupted",
            json!({"state_may_have_changed": true}),
        ));
        db.execute(
            "UPDATE requests SET result=?1 WHERE result IS NULL",
            [interrupted],
        )?;
        Ok(Self {
            db: Mutex::new(db),
            retained,
            conversations,
        })
    }

    /// Exact identity: same tenant and request_id must carry the same bytes.
    pub fn begin(
        &self,
        tenant: &str,
        request_id: &str,
        body: &[u8],
        reply_bytes: usize,
    ) -> Result<Lookup, Failure> {
        let db = lock(&self.db);
        let row: Option<(Vec<u8>, Option<Vec<u8>>)> = db
            .query_row(
                "SELECT body,result FROM requests WHERE tenant=?1 AND id=?2",
                params![tenant, request_id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(|_| journal_error())?;
        if let Some((previous, result)) = row {
            if previous != body {
                return Err(Failure::plain(409, "request_id_conflict"));
            }
            let Some(result) = result else {
                return Err(Failure::new(429, "busy", json!({"retryable": true})));
            };
            if result.len() > reply_bytes {
                return Err(Failure::new(
                    502,
                    "reply_too_large",
                    json!({"execution_completed": true,
                    "retained_in_journal": true, "state_may_have_changed": true}),
                ));
            }
            let value = wire::parse(&result).map_err(|_| journal_error())?;
            return Ok(Lookup::Replay(status_of(&value), value));
        }
        let count: u64 = db
            .query_row("SELECT count(*) FROM requests", [], |r| r.get(0))
            .map_err(|_| journal_error())?;
        if count >= self.retained {
            return Err(Failure::plain(507, "request_journal_full"));
        }
        db.execute(
            "INSERT INTO requests(tenant,id,body,result) VALUES(?1,?2,?3,NULL)",
            params![tenant, request_id, body],
        )
        .map_err(|_| journal_error())?;
        Ok(Lookup::Fresh)
    }

    pub fn finish(&self, tenant: &str, request_id: &str, result: &Value) -> Result<(), Failure> {
        lock(&self.db)
            .execute(
                "UPDATE requests SET result=?3 WHERE tenant=?1 AND id=?2",
                params![tenant, request_id, wire::encode(result)],
            )
            .map(|_| ())
            .map_err(|_| journal_error())
    }

    /// A refused-before-work turn (busy) leaves no record, so a retry runs.
    pub fn forget(&self, tenant: &str, request_id: &str) {
        let _ = lock(&self.db).execute(
            "DELETE FROM requests WHERE tenant=?1 AND id=?2 AND result IS NULL",
            params![tenant, request_id],
        );
    }

    pub fn conversation(&self, tenant: &str, id: &str) -> Result<Option<(usize, String)>, Failure> {
        lock(&self.db)
            .query_row(
                "SELECT worker,generation FROM conversations WHERE tenant=?1 AND id=?2",
                params![tenant, id],
                |r| Ok((r.get::<_, i64>(0)? as usize, r.get(1)?)),
            )
            .optional()
            .map_err(|_| journal_error())
    }

    pub fn bind(
        &self,
        tenant: &str,
        id: &str,
        worker: usize,
        generation: &str,
    ) -> Result<(), Failure> {
        let db = lock(&self.db);
        let count: u64 = db
            .query_row("SELECT count(*) FROM conversations", [], |r| r.get(0))
            .map_err(|_| journal_error())?;
        let known: bool = db
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM conversations WHERE tenant=?1 AND id=?2)",
                params![tenant, id],
                |r| r.get(0),
            )
            .map_err(|_| journal_error())?;
        if !known && count >= self.conversations {
            return Err(Failure::new(
                507,
                "conversation_registry_full",
                json!({"executed": false}),
            ));
        }
        db.execute(
            "INSERT OR REPLACE INTO conversations(tenant,id,worker,generation) VALUES(?1,?2,?3,?4)",
            params![tenant, id, worker as i64, generation],
        )
        .map(|_| ())
        .map_err(|_| journal_error())
    }
}
