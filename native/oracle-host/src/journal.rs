//! Durable opaque-Engine request admission. Unlike the native core transaction,
//! a Python effect cannot be rolled back: dispatch is persisted before calling it.
use crate::{wire, Failure};
use nix::fcntl::{Flock, FlockArg};
use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};
use std::{
    collections::HashSet,
    fs::{File, OpenOptions},
    path::Path,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
};

pub struct Journal {
    db: Mutex<Connection>,
    _owner: Flock<File>,
    busy: Arc<Mutex<HashSet<(String, String)>>>,
    failed: AtomicBool,
    retained: u64,
    conversations: u64,
}
pub struct ConversationLease {
    busy: Arc<Mutex<HashSet<(String, String)>>>,
    key: (String, String),
}
impl Drop for ConversationLease {
    fn drop(&mut self) {
        lock(&self.busy).remove(&self.key);
    }
}
pub(crate) enum EncodedLookup {
    Fresh,
    Replay(wire::EncodedReply),
}

pub enum Lookup {
    Fresh,
    Replay(u16, Value),
}
pub fn status_of(result: &Value) -> u16 {
    if result["outcome"] == "completed" {
        200
    } else if let Some(n) = result["http_status"].as_u64() {
        n as u16
    } else if result["error"] == "query_timeout" {
        504
    } else {
        502
    }
}
fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}
fn storage(changed: bool) -> Failure {
    Failure::new(
        507,
        "journal_error",
        json!({"state_may_have_changed":changed,"exact_retry_required":changed}),
    )
}
impl Journal {
    pub fn open(
        path: &Path,
        retained: u64,
        conversations: u64,
        identity: &str,
    ) -> Result<Self, String> {
        use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
        let parent = path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or(Path::new("."));
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        let parent = parent.canonicalize().map_err(|e| e.to_string())?;
        let name = path.file_name().ok_or("journal requires a file name")?;
        let path = parent.join(name);
        let regular_private_inode = |path: &Path| -> Result<(), String> {
            match std::fs::symlink_metadata(path) {
                Ok(metadata) if !metadata.file_type().is_file() || metadata.nlink()!=1 =>
                    Err(format!("journal and ownership files must be regular files with one link; aliases are unsupported: {}",path.display())),
                Ok(_) => Ok(()),
                Err(e) if e.kind()==std::io::ErrorKind::NotFound => Ok(()),
                Err(e) => Err(e.to_string()),
            }
        };
        regular_private_inode(&path)?;
        let mut owner_name = path.as_os_str().to_os_string();
        owner_name.push(".owner");
        let owner_path = std::path::PathBuf::from(owner_name);
        regular_private_inode(&owner_path)?;
        // A persistent sibling avoids flock/fcntl conflicts on SQLite's inode
        // on macOS. Never unlink it: every owner must lock the same inode.
        // Canonical parent paths share this lock; database symlinks/hardlinks
        // are refused. State and sidecar custody belong to the operator.
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .mode(0o600)
            .open(&owner_path)
            .map_err(|e| e.to_string())?;
        let owner = Flock::lock(file, FlockArg::LockExclusiveNonblock)
            .map_err(|(_, e)| format!("journal already owned: {e}"))?;
        regular_private_inode(&path)?;
        let mut db = Connection::open(&path).map_err(|e| e.to_string())?;
        (|| -> rusqlite::Result<()> {
            db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
                CREATE TABLE IF NOT EXISTS requests(tenant TEXT NOT NULL,id TEXT NOT NULL,body BLOB NOT NULL,result BLOB,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
                CREATE TABLE IF NOT EXISTS conversations(tenant TEXT NOT NULL,id TEXT NOT NULL,worker INTEGER NOT NULL,generation TEXT NOT NULL,PRIMARY KEY(tenant,id)) WITHOUT ROWID;
                CREATE TABLE IF NOT EXISTS deployment(identity TEXT NOT NULL);")?;
            Ok(())
        })().map_err(|e| e.to_string())?;
        let previous: Option<String> = db
            .query_row("SELECT identity FROM deployment", [], |r| r.get(0))
            .optional()
            .map_err(|e| e.to_string())?;
        let count: i64 = db
            .query_row(
                "SELECT (SELECT count(*) FROM requests)+(SELECT count(*) FROM conversations)",
                [],
                |r| r.get(0),
            )
            .map_err(|e| e.to_string())?;
        match &previous {
            Some(previous) if previous != identity && count != 0 => return Err("journal deployment mismatch; retained history requires its admitted deployment".into()),
            None if count != 0 => return Err("legacy journal has no deployment identity; explicit migration required; history retained".into()),
            _ => {}
        }
        let columns: Vec<String> = db
            .prepare("PRAGMA table_info(requests)")
            .map_err(|e| e.to_string())?
            .query_map([], |r| r.get(1))
            .map_err(|e| e.to_string())?
            .collect::<rusqlite::Result<_>>()
            .map_err(|e| e.to_string())?;
        if !columns.iter().any(|n| n == "phase") {
            db.execute_batch(
                "ALTER TABLE requests ADD COLUMN phase TEXT NOT NULL DEFAULT 'admitted'",
            )
            .map_err(|e| e.to_string())?;
        }
        let conversation_columns: Vec<String> = db
            .prepare("PRAGMA table_info(conversations)")
            .map_err(|e| e.to_string())?
            .query_map([], |r| r.get(1))
            .map_err(|e| e.to_string())?
            .collect::<rusqlite::Result<_>>()
            .map_err(|e| e.to_string())?;
        if !conversation_columns.iter().any(|n| n == "poisoned") {
            db.execute_batch(
                "ALTER TABLE conversations ADD COLUMN poisoned INTEGER NOT NULL DEFAULT 0",
            )
            .map_err(|e| e.to_string())?;
        }
        if !conversation_columns.iter().any(|n| n == "poisoned_by") {
            db.execute_batch("ALTER TABLE conversations ADD COLUMN poisoned_by TEXT")
                .map_err(|e| e.to_string())?;
        }
        let tx = db.transaction().map_err(|e| e.to_string())?;
        if previous.is_none() {
            tx.execute("INSERT INTO deployment VALUES(?1)", [identity])
                .map_err(|e| e.to_string())?;
        } else if previous.as_deref() != Some(identity) {
            // A failed first admission may have created metadata but no history.
            // Under exclusive ownership, only a provably empty journal may rebind.
            tx.execute("UPDATE deployment SET identity=?1", [identity])
                .map_err(|e| e.to_string())?;
        }
        // Defer classification until retry: covered core completion is the
        // authority, and may have committed immediately before this host died.
        tx.execute("UPDATE requests SET phase='recovered_' || phase WHERE result IS NULL AND phase IN ('admitted','dispatched')", [])
            .map_err(|e| e.to_string())?;
        tx.commit().map_err(|e| e.to_string())?;
        Ok(Self {
            db: Mutex::new(db),
            _owner: owner,
            busy: Arc::new(Mutex::new(HashSet::new())),
            failed: AtomicBool::new(false),
            retained,
            conversations,
        })
    }
    fn error(&self, changed: bool) -> Failure {
        self.failed.store(true, Ordering::Release);
        storage(changed)
    }
    pub fn lease(&self, tenant: &str, id: &str) -> Result<ConversationLease, Failure> {
        let key = (tenant.to_owned(), id.to_owned());
        if !lock(&self.busy).insert(key.clone()) {
            return Err(Failure::new(429, "busy", json!({"retryable":true})));
        }
        Ok(ConversationLease {
            busy: self.busy.clone(),
            key,
        })
    }
    pub fn begin(
        &self,
        tenant: &str,
        id: &str,
        body: &[u8],
        reply_bytes: usize,
    ) -> Result<Lookup, Failure> {
        match self.begin_encoded(tenant, id, body, reply_bytes)? {
            EncodedLookup::Fresh => Ok(Lookup::Fresh),
            EncodedLookup::Replay(reply) => {
                let (status, value) = reply.into_value();
                Ok(Lookup::Replay(status, value))
            }
        }
    }

    pub(crate) fn begin_encoded(
        &self,
        tenant: &str,
        id: &str,
        body: &[u8],
        reply_bytes: usize,
    ) -> Result<EncodedLookup, Failure> {
        let db = lock(&self.db);
        let row: Option<(Vec<u8>, Option<Vec<u8>>, String)> = db
            .query_row(
                "SELECT body,result,phase FROM requests WHERE tenant=?1 AND id=?2",
                params![tenant, id],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()
            .map_err(|_| self.error(true))?;
        if let Some((previous, mut result, phase)) = row {
            if previous != body {
                return Err(Failure::plain(409, "request_id_conflict"));
            }
            if result.is_none() && phase.starts_with("recovered_") {
                let dispatched = phase == "recovered_dispatched";
                let mut interrupted = crate::failure(
                    "interrupted",
                    json!({"state_may_have_changed":dispatched,"exact_retry_required":true}),
                );
                if !dispatched {
                    interrupted["executed"] = json!(false);
                }
                let bytes = wire::encode(&interrupted);
                db.execute(
                    "UPDATE requests SET result=?3,phase='uncertain' WHERE tenant=?1 AND id=?2",
                    params![tenant, id, &bytes],
                )
                .map_err(|_| self.error(dispatched))?;
                result = Some(bytes);
            }
            let Some(result) = result else {
                return Err(if self.failed.load(Ordering::Acquire) {
                    storage(true)
                } else {
                    Failure::new(429, "busy", json!({"retryable":true}))
                });
            };
            if result.len() > reply_bytes {
                return Err(Failure::new(
                    502,
                    "reply_too_large",
                    json!({"execution_completed":true,"retained_in_journal":true,"state_may_have_changed":true}),
                ));
            }
            let value = wire::parse(&result).map_err(|_| self.error(true))?;
            return Ok(EncodedLookup::Replay(wire::EncodedReply::retained(
                status_of(&value),
                result,
            )));
        }
        if self.failed.load(Ordering::Acquire) {
            return Err(storage(false));
        }
        let count: u64 = db
            .query_row("SELECT count(*) FROM requests", [], |r| r.get(0))
            .map_err(|_| self.error(false))?;
        if count >= self.retained {
            return Err(Failure::plain(507, "request_journal_full"));
        }
        db.execute(
            "INSERT INTO requests(tenant,id,body,phase) VALUES(?1,?2,?3,'admitted')",
            params![tenant, id, body],
        )
        .map_err(|_| self.error(false))?;
        Ok(EncodedLookup::Fresh)
    }
    /// Read collision/recovery information without classifying an unfinished
    /// dispatch. Covered callers consult core completion before legacy recovery.
    pub(crate) fn retained_request(
        &self,
        tenant: &str,
        id: &str,
    ) -> Result<Option<(Vec<u8>, Option<Vec<u8>>, String)>, Failure> {
        lock(&self.db)
            .query_row(
                "SELECT body,result,phase FROM requests WHERE tenant=?1 AND id=?2",
                params![tenant, id],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()
            .map_err(|_| self.error(false))
    }

    /// Core has durably committed the exact reply and checked state. This ledger
    /// acknowledges dispatch only; it never creates a second successful reply.
    pub(crate) fn acknowledge_core(
        &self,
        tenant: &str,
        id: &str,
        conversation: &str,
    ) -> Result<(), Failure> {
        let mut db = lock(&self.db);
        let tx = db.transaction().map_err(|_| self.error(true))?;
        tx.execute(
            "UPDATE requests SET phase='core_completed' WHERE tenant=?1 AND id=?2",
            params![tenant, id],
        )
        .map_err(|_| self.error(true))?;
        tx.execute(
            "UPDATE conversations SET poisoned=0,poisoned_by=NULL WHERE tenant=?1 AND id=?2 AND poisoned_by=?3",
            params![tenant, conversation, id],
        )
        .map_err(|_| self.error(true))?;
        tx.commit().map_err(|_| self.error(true))
    }

    pub fn dispatch(&self, tenant: &str, id: &str, conversation: &str) -> Result<(), Failure> {
        let mut db = lock(&self.db);
        let tx = db.transaction().map_err(|_| self.error(false))?;
        let known: bool = tx
            .query_row(
                "SELECT EXISTS(SELECT 1 FROM conversations WHERE tenant=?1 AND id=?2)",
                params![tenant, conversation],
                |r| r.get(0),
            )
            .map_err(|_| self.error(false))?;
        let count: u64 = tx
            .query_row("SELECT count(*) FROM conversations", [], |r| r.get(0))
            .map_err(|_| self.error(false))?;
        if !known && count >= self.conversations {
            return Err(Failure::new(
                507,
                "conversation_registry_full",
                json!({"executed":false}),
            ));
        }
        tx.execute(
            "INSERT OR IGNORE INTO conversations(tenant,id,worker,generation) VALUES(?1,?2,-1,?3)",
            params![tenant, conversation, format!("pending:{id}")],
        )
        .map_err(|_| self.error(false))?;
        // Opaque Python may mutate context before returning or raising. Poison
        // before dispatch; only the atomic reply commit below may clear it.
        tx.execute(
            "UPDATE conversations SET poisoned=1,poisoned_by=?3 WHERE tenant=?1 AND id=?2",
            params![tenant, conversation, id],
        )
        .map_err(|_| self.error(false))?;
        tx.execute(
            "UPDATE requests SET phase='dispatched' WHERE tenant=?1 AND id=?2",
            params![tenant, id],
        )
        .map_err(|_| self.error(false))?;
        tx.commit().map_err(|_| self.error(false))?;
        Ok(())
    }
    pub fn finish(
        &self,
        tenant: &str,
        id: &str,
        conversation: &str,
        result: &Value,
    ) -> Result<(), Failure> {
        self.finish_bytes(
            tenant,
            id,
            conversation,
            &wire::encode(result),
            result["outcome"] == "completed",
        )
    }

    /// The bytes and completed predicate must describe the SAME final response.
    /// In particular a size/error replacement must recompute its predicate, so
    /// retaining that refusal cannot clear an uncertain conversation's poison.
    pub(crate) fn finish_bytes(
        &self,
        tenant: &str,
        id: &str,
        conversation: &str,
        bytes: &[u8],
        completed: bool,
    ) -> Result<(), Failure> {
        let mut db = lock(&self.db);
        let tx = db.transaction().map_err(|_| self.error(true))?;
        tx.execute(
            "UPDATE requests SET result=?3,phase='completed' WHERE tenant=?1 AND id=?2",
            params![tenant, id, bytes],
        )
        .map_err(|_| self.error(true))?;
        if completed {
            tx.execute(
                "UPDATE conversations SET poisoned=0,poisoned_by=NULL WHERE tenant=?1 AND id=?2 AND poisoned_by=?3",
                params![tenant, conversation, id],
            )
            .map_err(|_| self.error(true))?;
        }
        tx.commit().map_err(|_| self.error(true))
    }
    /// Only call with positive evidence that the opaque Engine never received work.
    pub fn forget(&self, tenant: &str, id: &str, conversation: &str) -> Result<(), Failure> {
        let mut db = lock(&self.db);
        let tx = db.transaction().map_err(|_| self.error(false))?;
        let dispatched: bool=tx.query_row("SELECT EXISTS(SELECT 1 FROM requests WHERE tenant=?1 AND id=?2 AND phase='dispatched')",
            params![tenant,id],|r|r.get(0)).map_err(|_|self.error(false))?;
        // Only the owner of a dispatched admission can undo its poison after
        // an explicit preexecution refusal. A racing admitted request cannot.
        if dispatched {
            tx.execute(
                "UPDATE conversations SET poisoned=0,poisoned_by=NULL WHERE tenant=?1 AND id=?2 AND poisoned_by=?3",
                params![tenant, conversation, id],
            )
            .map_err(|_| self.error(false))?;
        }
        tx.execute(
            "DELETE FROM requests WHERE tenant=?1 AND id=?2 AND result IS NULL",
            params![tenant, id],
        )
        .map_err(|_| self.error(false))?;
        tx.execute(
            "DELETE FROM conversations WHERE tenant=?1 AND id=?2 AND generation=?3",
            params![tenant, conversation, format!("pending:{id}")],
        )
        .map_err(|_| self.error(false))?;
        tx.commit().map_err(|_| self.error(false))
    }
    pub fn conversation(&self, tenant: &str, id: &str) -> Result<Option<(usize, String)>, Failure> {
        lock(&self.db)
            .query_row(
                "SELECT worker,CASE WHEN poisoned=0 THEN generation ELSE 'poisoned' END FROM conversations WHERE tenant=?1 AND id=?2",
                params![tenant, id],
                |r| Ok((r.get::<_, i64>(0)? as usize, r.get(1)?)),
            )
            .optional()
            .map_err(|_| self.error(false))
    }
    pub fn bind(
        &self,
        tenant: &str,
        id: &str,
        worker: usize,
        generation: &str,
    ) -> Result<(), Failure> {
        lock(&self.db)
            .execute(
                "UPDATE conversations SET worker=?3,generation=?4 WHERE tenant=?1 AND id=?2",
                params![tenant, id, worker as i64, generation],
            )
            .map(|_| ())
            .map_err(|_| self.error(true))
    }
}

#[cfg(test)]
mod conversation_recovery_tests {
    use super::*;

    #[test]
    fn restart_keeps_dispatch_unclassified_until_authority_is_consulted() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("journal.sqlite3");
        let journal = Journal::open(&path, 8, 8, "deployment").unwrap();
        let raw = br#"{"conversation_id":"c","request_id":"r","text":"hello"}"#;
        assert!(matches!(
            journal.begin_encoded("t", "r", raw, 4096).unwrap(),
            EncodedLookup::Fresh
        ));
        journal.dispatch("t", "r", "c").unwrap();
        drop(journal);
        let journal = Journal::open(&path, 8, 8, "deployment").unwrap();
        let (body, result, phase) = journal.retained_request("t", "r").unwrap().unwrap();
        assert_eq!(body, raw);
        assert!(
            result.is_none(),
            "startup must not override a committed core reply"
        );
        assert_eq!(phase, "recovered_dispatched");
        journal.acknowledge_core("t", "r", "c").unwrap();
        let (_, result, phase) = journal.retained_request("t", "r").unwrap().unwrap();
        assert!(result.is_none(), "only core owns successful reply bytes");
        assert_eq!(phase, "core_completed");
        assert_ne!(
            journal.conversation("t", "c").unwrap().unwrap().1,
            "poisoned"
        );
    }

    #[test]
    fn lease_survives_transfer_and_blocks_other_endpoint_until_worker_cleanup() {
        let directory = tempfile::tempdir().unwrap();
        let journal = Journal::open(&directory.path().join("journal"), 8, 8, "deployment").unwrap();
        let lease = journal.lease("tenant", "conversation").unwrap();
        assert!(journal.lease("tenant", "conversation").is_err());
        let (release, wait) = std::sync::mpsc::channel();
        let worker = std::thread::spawn(move || {
            let _lease = lease;
            wait.recv().unwrap();
        });
        assert!(journal.lease("tenant", "conversation").is_err());
        assert!(journal.lease("other-tenant", "conversation").is_ok());
        release.send(()).unwrap();
        worker.join().unwrap();
        assert!(journal.lease("tenant", "conversation").is_ok());
    }

    #[test]
    fn old_core_replay_cannot_clear_a_later_uncertain_turn() {
        let directory = tempfile::tempdir().unwrap();
        let journal = Journal::open(&directory.path().join("journal"), 8, 8, "deployment").unwrap();
        journal.begin_encoded("t", "a", b"a", 4096).unwrap();
        journal.dispatch("t", "a", "c").unwrap();
        journal.acknowledge_core("t", "a", "c").unwrap();
        journal.begin_encoded("t", "b", b"b", 4096).unwrap();
        journal.dispatch("t", "b", "c").unwrap();
        journal.acknowledge_core("t", "a", "c").unwrap();
        assert_eq!(
            journal.conversation("t", "c").unwrap().unwrap().1,
            "poisoned"
        );
        journal.acknowledge_core("t", "b", "c").unwrap();
        assert_ne!(
            journal.conversation("t", "c").unwrap().unwrap().1,
            "poisoned"
        );
    }

    #[test]
    fn legacy_completed_reply_survives_restart_byte_for_byte() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("journal");
        let journal = Journal::open(&path, 8, 8, "deployment").unwrap();
        let raw = b"query identity";
        journal.begin_encoded("t", "r", raw, 4096).unwrap();
        let bytes = br#"{ "outcome":"completed", "reply":{"response":"old reply"} }"#;
        journal.finish_bytes("t", "r", "c", bytes, true).unwrap();
        drop(journal);
        let journal = Journal::open(&path, 8, 8, "deployment").unwrap();
        match journal.begin_encoded("t", "r", raw, 4096).unwrap() {
            EncodedLookup::Replay(reply) => assert_eq!(reply.body(), bytes),
            EncodedLookup::Fresh => panic!("completed legacy request was lost"),
        }
        assert!(journal
            .begin_encoded("t", "r", b"invoke identity", 4096)
            .is_err());
    }
}
