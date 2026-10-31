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
        Mutex,
    },
};

pub struct Journal {
    db: Mutex<Connection>,
    _owner: Flock<File>,
    busy: Mutex<HashSet<(String, String)>>,
    failed: AtomicBool,
    retained: u64,
    conversations: u64,
}
pub struct ConversationLease<'a> {
    journal: &'a Journal,
    key: (String, String),
}
impl Drop for ConversationLease<'_> {
    fn drop(&mut self) {
        lock(&self.journal.busy).remove(&self.key);
    }
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
        // Persist a final interrupted response even for admitted requests. Never
        // silently rerun a retained ID after a crash.
        tx.execute(
            "UPDATE requests SET result=?1,phase='uncertain' WHERE result IS NULL AND phase='dispatched'",
            [wire::encode(&crate::failure(
                "interrupted",
                json!({"state_may_have_changed":true,"exact_retry_required":true}),
            ))],
        )
        .map_err(|e| e.to_string())?;
        tx.execute(
            "UPDATE requests SET result=?1,phase='completed' WHERE result IS NULL AND phase='admitted'",
            [wire::encode(&crate::failure("interrupted",json!({"state_may_have_changed":false,"executed":false,"exact_retry_required":true})))],
        ).map_err(|e| e.to_string())?;
        tx.commit().map_err(|e| e.to_string())?;
        Ok(Self {
            db: Mutex::new(db),
            _owner: owner,
            busy: Mutex::new(HashSet::new()),
            failed: AtomicBool::new(false),
            retained,
            conversations,
        })
    }
    fn error(&self, changed: bool) -> Failure {
        self.failed.store(true, Ordering::Release);
        storage(changed)
    }
    pub fn lease(&self, tenant: &str, id: &str) -> Result<ConversationLease<'_>, Failure> {
        let key = (tenant.to_owned(), id.to_owned());
        if !lock(&self.busy).insert(key.clone()) {
            return Err(Failure::new(429, "busy", json!({"retryable":true})));
        }
        Ok(ConversationLease { journal: self, key })
    }
    pub fn begin(
        &self,
        tenant: &str,
        id: &str,
        body: &[u8],
        reply_bytes: usize,
    ) -> Result<Lookup, Failure> {
        let db = lock(&self.db);
        let row: Option<(Vec<u8>, Option<Vec<u8>>)> = db
            .query_row(
                "SELECT body,result FROM requests WHERE tenant=?1 AND id=?2",
                params![tenant, id],
                |r| Ok((r.get(0)?, r.get(1)?)),
            )
            .optional()
            .map_err(|_| self.error(true))?;
        if let Some((previous, result)) = row {
            if previous != body {
                return Err(Failure::plain(409, "request_id_conflict"));
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
            return Ok(Lookup::Replay(status_of(&value), value));
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
        Ok(Lookup::Fresh)
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
            "UPDATE conversations SET poisoned=1 WHERE tenant=?1 AND id=?2",
            params![tenant, conversation],
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
        let mut db = lock(&self.db);
        let tx = db.transaction().map_err(|_| self.error(true))?;
        tx.execute(
            "UPDATE requests SET result=?3,phase='completed' WHERE tenant=?1 AND id=?2",
            params![tenant, id, wire::encode(result)],
        )
        .map_err(|_| self.error(true))?;
        if result["outcome"] == "completed" {
            tx.execute(
                "UPDATE conversations SET poisoned=0 WHERE tenant=?1 AND id=?2",
                params![tenant, conversation],
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
                "UPDATE conversations SET poisoned=0 WHERE tenant=?1 AND id=?2",
                params![tenant, conversation],
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
