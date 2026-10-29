use crate::{digest, lock, Budget, Error, Limits, Result};
use rusqlite::{params, Connection, OpenFlags};
use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use tempfile::NamedTempFile;

const APPLICATION_ID: i64 = 0x4f375631;
const SCHEMA: &str = "
PRAGMA user_version=2;
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE nodes(id TEXT PRIMARY KEY,kind TEXT NOT NULL,name TEXT NOT NULL,record TEXT NOT NULL) WITHOUT ROWID;
CREATE INDEX node_name ON nodes(name,kind,id);
CREATE INDEX node_kind ON nodes(kind,id);
CREATE TABLE parents(child TEXT NOT NULL,parent TEXT NOT NULL,kind TEXT NOT NULL,PRIMARY KEY(parent,kind,child)) WITHOUT ROWID;
CREATE INDEX parent_child ON parents(child,parent,kind);
CREATE TABLE edges(subject TEXT NOT NULL,predicate TEXT NOT NULL,direction TEXT NOT NULL,object TEXT NOT NULL,qualifiers TEXT NOT NULL,
 PRIMARY KEY(subject,predicate,direction,object,qualifiers)) WITHOUT ROWID;
CREATE TABLE attributes(subject TEXT NOT NULL,position INTEGER NOT NULL,key TEXT NOT NULL,value TEXT NOT NULL,qualifiers TEXT NOT NULL,
 PRIMARY KEY(subject,key,position)) WITHOUT ROWID;
";

#[derive(Serialize)]
pub struct BuildReceipt {
    pub schema: &'static str,
    pub image_sha256: String,
    pub source_sha256: String,
    pub nodes: u64,
    pub edges: u64,
    pub bytes: u64,
}

fn text<'a>(v: &'a Value, key: &str) -> Result<&'a str> {
    v.get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| Error::Invalid(format!("missing string {key}")))
}
fn list<'a>(v: &'a Value, key: &str) -> Result<&'a [Value]> {
    match v.get(key) {
        None | Some(Value::Null) => Ok(&[]),
        Some(Value::Array(a)) => Ok(a),
        _ => Err(Error::Invalid(format!("invalid list {key}"))),
    }
}
fn hash_file(path: &Path) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 65536];
    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

/// Offline builder. Input is a complete KQA-shaped release, never a tenant request.
/// Limits bound source and individual records; no destination is overwritten.
pub fn build_image(
    source: &Path,
    output: &Path,
    max_source_bytes: u64,
    max_record_bytes: usize,
) -> Result<BuildReceipt> {
    if max_source_bytes == u64::MAX || max_record_bytes == 0 {
        return Err(Error::Invalid("invalid builder limits".into()));
    }
    let mut bytes = Vec::new();
    File::open(source)?
        .take(max_source_bytes + 1)
        .read_to_end(&mut bytes)?;
    if bytes.len() as u64 > max_source_bytes {
        return Err(Error::Limit("source bytes"));
    }
    let source_sha256 = digest(&bytes);
    let kb: Value = serde_json::from_slice(&bytes)?;
    let parent = output
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let mut temporary = NamedTempFile::new_in(parent)?;
    let mut db = Connection::open(temporary.path())?;
    db.execute_batch(SCHEMA)?;
    // Explicitly set the numeric constant too: format checks never infer identity from a filename.
    db.pragma_update(None, "application_id", APPLICATION_ID)?;
    let tx = db.transaction()?;
    for (collection, kind) in [("entities", "entity"), ("concepts", "concept")] {
        let objects = kb
            .get(collection)
            .and_then(Value::as_object)
            .ok_or_else(|| Error::Invalid(format!("missing object {collection}")))?;
        for (id, record) in objects {
            if id.is_empty() {
                return Err(Error::Invalid("empty node ID".into()));
            }
            let encoded = serde_json::to_string(record)?;
            if encoded.len() > max_record_bytes {
                return Err(Error::Limit("source record bytes"));
            }
            tx.prepare_cached("INSERT INTO nodes VALUES (?1,?2,?3,?4)")?
                .execute(params![id, kind, text(record, "name")?, encoded])?;
            let mut parents = list(record, "instanceOf")?;
            if kind == "concept" && parents.is_empty() {
                parents = list(record, "subclassOf")?;
            }
            for p in parents {
                let p = p
                    .as_str()
                    .ok_or_else(|| Error::Invalid("invalid parent".into()))?;
                tx.prepare_cached("INSERT OR IGNORE INTO parents VALUES (?1,?2,?3)")?
                    .execute(params![id, p, kind])?;
            }
            for (position, attribute) in list(record, "attributes")?.iter().enumerate() {
                let value = attribute
                    .get("value")
                    .ok_or_else(|| Error::Invalid("missing value".into()))?;
                let q = attribute
                    .get("qualifiers")
                    .cloned()
                    .unwrap_or_else(|| serde_json::json!({}));
                if !q.is_object() {
                    return Err(Error::Invalid("qualifiers must be an object".into()));
                }
                tx.prepare_cached("INSERT INTO attributes VALUES (?1,?2,?3,?4,?5)")?
                    .execute(params![
                        id,
                        position as i64,
                        text(attribute, "key")?,
                        serde_json::to_string(value)?,
                        serde_json::to_string(&q)?
                    ])?;
            }
            if kind == "entity" {
                for edge in list(record, "relations")? {
                    let direction = text(edge, "direction")?;
                    let reverse = match direction {
                        "forward" => "backward",
                        "backward" => "forward",
                        _ => return Err(Error::Invalid("invalid relation direction".into())),
                    };
                    let predicate = text(edge, "predicate")?;
                    let object = text(edge, "object")?;
                    let q = edge
                        .get("qualifiers")
                        .cloned()
                        .unwrap_or_else(|| serde_json::json!({}));
                    if !q.is_object() {
                        return Err(Error::Invalid("qualifiers must be an object".into()));
                    }
                    let q = serde_json::to_string(&q)?;
                    for (a, d, b) in [
                        (id.as_str(), direction, object),
                        (object, reverse, id.as_str()),
                    ] {
                        tx.prepare_cached("INSERT OR IGNORE INTO edges VALUES (?1,?2,?3,?4,?5)")?
                            .execute(params![a, predicate, d, b, q])?;
                    }
                }
            }
        }
    }
    let dangling: bool = tx.query_row("SELECT EXISTS(SELECT 1 FROM edges e WHERE NOT EXISTS(SELECT 1 FROM nodes WHERE id=e.subject) OR NOT EXISTS(SELECT 1 FROM nodes WHERE id=e.object)) OR EXISTS(SELECT 1 FROM parents p WHERE NOT EXISTS(SELECT 1 FROM nodes WHERE id=p.parent AND kind='concept'))", [], |r| r.get(0))?;
    if dangling {
        return Err(Error::Invalid(
            "dangling relation or concept reference".into(),
        ));
    }
    tx.execute(
        "INSERT INTO metadata VALUES ('source_sha256',?1)",
        [&source_sha256],
    )?;
    tx.execute(
        "INSERT INTO metadata VALUES ('max_record_bytes',?1)",
        [max_record_bytes.to_string()],
    )?;
    let nodes = tx.query_row("SELECT count(*) FROM nodes", [], |r| r.get(0))?;
    let edges = tx.query_row("SELECT count(*) FROM edges", [], |r| r.get(0))?;
    tx.commit()?;
    db.execute_batch("ANALYZE; VACUUM;")?;
    db.close().map_err(|(_, e)| e)?;
    temporary.flush()?;
    temporary.as_file().sync_all()?;
    let image_sha256 = hash_file(temporary.path())?;
    let bytes = temporary.as_file().metadata()?.len();
    temporary
        .persist_noclobber(output)
        .map_err(|e| Error::Io(e.error))?;
    File::open(parent)?.sync_all()?;
    Ok(BuildReceipt {
        schema: "oracle-image-v2",
        image_sha256,
        source_sha256,
        nodes,
        edges,
        bytes,
    })
}

pub struct Image {
    pub identity: String,
    pub limits: Limits,
    connections: Mutex<Pool>,
    active: AtomicUsize,
}

struct Pool {
    idle: Vec<Connection>,
    active_tenants: BTreeSet<String>,
    poisoned: bool,
}

impl Image {
    /// The host must hold this artifact under immutable custody throughout use.
    /// One hash verification per Image; handles/page caches are bounded by workers.
    pub fn open(path: &Path, expected_sha256: &str, limits: Limits) -> Result<Arc<Self>> {
        limits.validate()?;
        let identity = hash_file(path)?;
        if identity != expected_sha256 {
            return Err(Error::Format("image hash mismatch".into()));
        }
        let mut connections = Vec::new();
        for _ in 0..limits.workers {
            let db = Connection::open_with_flags(
                path,
                OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
            )?;
            let app: i64 = db.pragma_query_value(None, "application_id", |r| r.get(0))?;
            let version: i64 = db.pragma_query_value(None, "user_version", |r| r.get(0))?;
            if app != APPLICATION_ID || version != 2 {
                return Err(Error::Format("image schema".into()));
            }
            db.busy_timeout(std::time::Duration::ZERO)?;
            // Main is opened SQLITE_OPEN_READ_ONLY. Private TEMP tables hold
            // explicitly metered shared subplans; no tenant data enters main.
            db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA temp_store=MEMORY;
                CREATE TEMP TABLE oracle_sets(node INTEGER NOT NULL,id TEXT NOT NULL,PRIMARY KEY(node,id)) WITHOUT ROWID;
                CREATE TEMP TABLE oracle_facts(node INTEGER NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,direction TEXT NOT NULL,object TEXT NOT NULL,qualifiers TEXT NOT NULL,PRIMARY KEY(node,subject,predicate,direction,object,qualifiers)) WITHOUT ROWID;
                CREATE INDEX temp.oracle_fact_object ON oracle_facts(node,object);")?;
            db.pragma_update(None, "cache_size", -(limits.sqlite_cache_kib as i64))?;
            db.pragma_update(None, "mmap_size", limits.mmap_bytes as i64)?;
            db.set_prepared_statement_cache_capacity(16);
            connections.push(db);
        }
        Ok(Arc::new(Self {
            identity,
            limits,
            connections: Mutex::new(Pool {
                idle: connections,
                active_tenants: BTreeSet::new(),
                poisoned: false,
            }),
            active: AtomicUsize::new(0),
        }))
    }
    pub(crate) fn acquire(self: &Arc<Self>, tenant: &str, budget: &Budget) -> Result<Lease> {
        budget.check()?;
        let mut pool = lock(&self.connections)?;
        if pool.poisoned {
            return Err(Error::Poisoned);
        }
        if pool.active_tenants.contains(tenant) {
            return Err(Error::Busy);
        }
        let db = pool.idle.pop().ok_or(Error::Busy)?;
        pool.active_tenants.insert(tenant.to_owned());
        self.active.fetch_add(1, Ordering::Release);
        drop(pool);
        let progress = budget.clone();
        db.progress_handler(1000, Some(move || progress.spend(1000).is_err()));
        Ok(Lease {
            image: self.clone(),
            db: Some(db),
            tenant: tenant.to_owned(),
        })
    }
    pub fn active_workers(&self) -> usize {
        self.active.load(Ordering::Acquire)
    }
}

pub(crate) struct Lease {
    image: Arc<Image>,
    db: Option<Connection>,
    tenant: String,
}
impl std::ops::Deref for Lease {
    type Target = Connection;
    fn deref(&self) -> &Connection {
        self.db.as_ref().expect("live lease owns connection")
    }
}
impl Drop for Lease {
    fn drop(&mut self) {
        if let Some(db) = self.db.take() {
            db.progress_handler(0, None::<fn() -> bool>);
            // Cleanup is part of owning the slot. Cancellation cannot abandon
            // private scratch for the next tenant, and cleanup failure poisons
            // the image rather than returning a questionable connection.
            let clean = db
                .execute_batch("DELETE FROM temp.oracle_sets; DELETE FROM temp.oracle_facts;")
                .is_ok();
            // Returning capacity cannot fail because a brief concurrent checkout holds the lock.
            // Poison is recovered only here; future admissions still fail closed.
            let mut pool = self
                .image
                .connections
                .lock()
                .unwrap_or_else(|p| p.into_inner());
            pool.active_tenants.remove(&self.tenant);
            if clean {
                pool.idle.push(db);
            } else {
                pool.poisoned = true;
            }
            self.image.active.fetch_sub(1, Ordering::Release);
        }
    }
}
