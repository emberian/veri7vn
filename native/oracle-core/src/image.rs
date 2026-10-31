use crate::grammar::{self, ReaderExport};
use crate::lexicon::{self, LexiconBuildLimits};
use crate::query::{encode, evaluate, Selection};
use crate::{digest, lock, Budget, Cancellation, Error, Limits, Program, Result};
use rusqlite::{params, Connection, OpenFlags, OptionalExtension};
use serde::{Deserialize, Serialize};
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
CREATE INDEX attribute_key ON attributes(key,subject,position);
";

/// Resource subformats actually present in the image, not engine feature claims.
#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ImageCapabilities {
    pub version: u32,
    pub lexicon: Option<String>,
    pub reader: Option<String>,
}
impl ImageCapabilities {
    fn legacy() -> Self {
        Self {
            version: 1,
            lexicon: None,
            reader: None,
        }
    }
    fn is_legacy(&self) -> bool {
        self.lexicon.is_none() && self.reader.is_none()
    }
}

/// Offline release bounds. Manufacturing has its own finite budget; serving
/// deadlines are not used to build the shared vocabulary and learned tables.
pub struct ReaderBuildOptions<'a> {
    pub reader: Option<&'a ReaderExport>,
    pub lexical: LexiconBuildLimits,
    pub grammar_rows: usize,
    pub grammar_bytes: usize,
    pub fuel: u64,
    pub timeout_ms: u64,
}
impl Default for ReaderBuildOptions<'_> {
    fn default() -> Self {
        Self {
            reader: None,
            lexical: LexiconBuildLimits::default(),
            grammar_rows: 5_000_000,
            grammar_bytes: 1024 * 1024 * 1024,
            fuel: 100_000_000_000,
            timeout_ms: 3_600_000,
        }
    }
}

#[derive(Serialize)]
pub struct BuildReceipt {
    pub schema: &'static str,
    pub image_sha256: String,
    pub source_sha256: String,
    pub nodes: u64,
    pub edges: u64,
    pub bytes: u64,
    #[serde(skip_serializing_if = "ImageCapabilities::is_legacy")]
    pub capabilities: ImageCapabilities,
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
    build_image_internal(source, output, max_source_bytes, max_record_bytes, None)
}

/// Build a v3 image with lexical indexes and optional shared learned resources.
/// The old build_image API still emits v2 without claiming these capabilities.
/// Grammar aliases are imported only after both vocabulary and grammar exist.
pub fn build_image_with_reader(
    source: &Path,
    output: &Path,
    max_source_bytes: u64,
    max_record_bytes: usize,
    options: ReaderBuildOptions<'_>,
) -> Result<BuildReceipt> {
    build_image_internal(
        source,
        output,
        max_source_bytes,
        max_record_bytes,
        Some(options),
    )
}

fn build_image_internal(
    source: &Path,
    output: &Path,
    max_source_bytes: u64,
    max_record_bytes: usize,
    options: Option<ReaderBuildOptions<'_>>,
) -> Result<BuildReceipt> {
    if max_source_bytes == u64::MAX || max_record_bytes == 0 {
        return Err(Error::Invalid("invalid builder limits".into()));
    }
    let build_budget = match options.as_ref() {
        Some(options) => {
            if options.fuel == 0
                || options.timeout_ms == 0
                || options.grammar_rows == 0
                || options.grammar_bytes == 0
            {
                return Err(Error::Invalid("invalid reader builder limits".into()));
            }
            Some(Budget::new(
                &Limits {
                    fuel: options.fuel,
                    timeout_ms: options.timeout_ms,
                    ..Limits::default()
                },
                Cancellation::default(),
            )?)
        }
        None => None,
    };
    let mut bytes = Vec::new();
    File::open(source)?
        .take(max_source_bytes + 1)
        .read_to_end(&mut bytes)?;
    if bytes.len() as u64 > max_source_bytes {
        return Err(Error::Limit("source bytes"));
    }
    if let Some(budget) = &build_budget {
        budget.spend(bytes.len() as u64 + 1)?;
    }
    let source_sha256 = digest(&bytes);
    if let Some(reader) = options.as_ref().and_then(|options| options.reader) {
        match reader.metadata.get("kb_sha256") {
            Some(Value::String(expected)) if expected == &source_sha256 => {}
            Some(_) => return Err(Error::Format("reader knowledge source mismatch".into())),
            None => {
                return Err(Error::Format(
                    "reader knowledge source binding missing".into(),
                ))
            }
        }
    }
    let kb: Value = serde_json::from_slice(&bytes)?;
    if let Some(budget) = &build_budget {
        budget.check()?;
    }
    let parent = output
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let mut temporary = NamedTempFile::new_in(parent)?;
    let mut db = Connection::open(temporary.path())?;
    db.execute_batch(SCHEMA)?;
    if let Some(budget) = &build_budget {
        let progress = budget.clone();
        db.progress_handler(1000, Some(move || progress.spend(1000).is_err()));
    }
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
            if let Some(budget) = &build_budget {
                budget.spend(encoded.len() as u64 + 1)?;
            }
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
    let mut capabilities = ImageCapabilities::legacy();
    if let Some(options) = &options {
        let budget = build_budget.as_ref().expect("reader build owns budget");
        let mut lexical_limits = options.lexical.clone();
        lexical_limits.record_bytes = lexical_limits.record_bytes.min(max_record_bytes);
        lexicon::build_from_nodes(&tx, budget, &lexical_limits)?;
        capabilities.lexicon = Some(lexicon::VERSION.into());
        if let Some(reader) = options.reader {
            budget.check()?;
            grammar::install_tables(&tx, reader, options.grammar_rows, options.grammar_bytes)?;
            budget.check()?;
            lexicon::install_grammar_aliases(&tx, &lexical_limits, budget)?;
            capabilities.reader = Some(format!(
                "{}-v{}",
                grammar::READER_FORMAT,
                grammar::READER_VERSION
            ));
        }
        tx.execute(
            "INSERT INTO metadata(key,value) VALUES ('image_capabilities',?1)",
            [serde_json::to_string(&capabilities)?],
        )?;
        tx.pragma_update(None, "user_version", 3)?;
        budget.check()?;
    }
    let nodes = tx.query_row("SELECT count(*) FROM nodes", [], |r| r.get(0))?;
    let edges = tx.query_row("SELECT count(*) FROM edges", [], |r| r.get(0))?;
    tx.commit()?;
    db.execute_batch("ANALYZE; VACUUM;")?;
    if let Some(budget) = &build_budget {
        budget.check()?;
    }
    db.progress_handler(0, None::<fn() -> bool>);
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
        schema: if options.is_some() {
            "oracle-image-v3"
        } else {
            "oracle-image-v2"
        },
        image_sha256,
        source_sha256,
        nodes,
        edges,
        bytes,
        capabilities,
    })
}

fn image_capabilities(db: &Connection, schema: i64) -> Result<ImageCapabilities> {
    let size: Option<i64> = db
        .query_row(
            "SELECT length(CAST(value AS BLOB)) FROM metadata WHERE key='image_capabilities'",
            [],
            |r| r.get(0),
        )
        .optional()?;
    if schema == 2 {
        if size.is_some() {
            return Err(Error::Format(
                "v2 image declares unsupported resources".into(),
            ));
        }
        return Ok(ImageCapabilities::legacy());
    }
    if schema != 3 || !size.is_some_and(|n| (1..=4096).contains(&n)) {
        return Err(Error::Format("image capabilities".into()));
    }
    let encoded: String = db.query_row(
        "SELECT value FROM metadata WHERE key='image_capabilities'",
        [],
        |r| r.get(0),
    )?;
    let capabilities: ImageCapabilities = serde_json::from_str(&encoded)?;
    if capabilities.version != 1 || capabilities.lexicon.as_deref() != Some(lexicon::VERSION) {
        return Err(Error::Format("image lexical capability".into()));
    }
    lexicon::validate(db)?;
    if let Some(reader) = &capabilities.reader {
        if *reader != format!("{}-v{}", grammar::READER_FORMAT, grammar::READER_VERSION) {
            return Err(Error::Format("image reader capability".into()));
        }
        grammar::read_policy(db)?;
        lexicon::grammar_normalization(db)?;
        for sql in [
            "SELECT family,level,template,skeleton,support FROM reader_template LIMIT 0",
            "SELECT level,template,roots,support FROM reader_shape LIMIT 0",
            "SELECT phrase,kind,canonical FROM reader_alias LIMIT 0",
            "SELECT category,word FROM reader_word LIMIT 0",
            "SELECT opening,kinds FROM reader_form LIMIT 0",
        ] {
            db.prepare(sql)?;
        }
    }
    Ok(capabilities)
}

pub struct Image {
    /// Legacy display identity. New coverage authority uses verified_identity().
    pub identity: String,
    verified_identity: String,
    pub limits: Limits,
    pub capabilities: ImageCapabilities,
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
        let mut capabilities = None;
        for _ in 0..limits.workers {
            let db = Connection::open_with_flags(
                path,
                OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
            )?;
            let app: i64 = db.pragma_query_value(None, "application_id", |r| r.get(0))?;
            let version: i64 = db.pragma_query_value(None, "user_version", |r| r.get(0))?;
            if app != APPLICATION_ID || !matches!(version, 2 | 3) {
                return Err(Error::Format("image schema".into()));
            }
            let worker_capabilities = image_capabilities(&db, version)?;
            if capabilities
                .as_ref()
                .is_some_and(|previous| previous != &worker_capabilities)
            {
                return Err(Error::Format(
                    "image capabilities changed during open".into(),
                ));
            }
            capabilities = Some(worker_capabilities);
            db.busy_timeout(std::time::Duration::ZERO)?;
            // Main is opened SQLITE_OPEN_READ_ONLY. Private TEMP tables hold
            // explicitly metered shared subplans; no tenant data enters main.
            db.execute_batch("PRAGMA trusted_schema=OFF; PRAGMA temp_store=MEMORY;
                CREATE TEMP TABLE oracle_sets(node INTEGER NOT NULL,id TEXT NOT NULL,PRIMARY KEY(node,id)) WITHOUT ROWID;
                CREATE TEMP TABLE oracle_facts(node INTEGER NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,direction TEXT NOT NULL,object TEXT NOT NULL,qualifiers TEXT NOT NULL,PRIMARY KEY(node,subject,predicate,direction,object,qualifiers)) WITHOUT ROWID;
                CREATE INDEX temp.oracle_fact_object ON oracle_facts(node,object);
                CREATE TEMP TABLE oracle_attributes(node INTEGER NOT NULL,subject TEXT NOT NULL,key TEXT NOT NULL,position INTEGER NOT NULL,value TEXT NOT NULL,qualifiers TEXT NOT NULL,PRIMARY KEY(node,subject,key,position)) WITHOUT ROWID;")?;
            db.pragma_update(None, "cache_size", -(limits.sqlite_cache_kib as i64))?;
            db.pragma_update(None, "mmap_size", limits.mmap_bytes as i64)?;
            db.set_prepared_statement_cache_capacity(16);
            connections.push(db);
        }
        Ok(Arc::new(Self {
            verified_identity: identity.clone(),
            identity,
            limits,
            capabilities: capabilities.expect("validated nonzero worker count"),
            connections: Mutex::new(Pool {
                idle: connections,
                active_tenants: BTreeSet::new(),
                poisoned: false,
            }),
            active: AtomicUsize::new(0),
        }))
    }
    pub(crate) fn acquire(&self, tenant: &str, budget: &Budget) -> Result<Lease<'_>> {
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
            image: self,
            db: Some(db),
            tenant: tenant.to_owned(),
        })
    }
    /// Immutable identity calculated from the opened image bytes, rather than
    /// the legacy publicly mutable display field. Artifact custody remains the
    /// host premise: this does not protect against modifying the file in place.
    pub fn verified_identity(&self) -> &str {
        &self.verified_identity
    }

    pub fn active_workers(&self) -> usize {
        self.active.load(Ordering::Acquire)
    }

    /// Pure complete-program query over the same evaluator and worker pool.
    /// Parsing, compilation, SQL and encoding share one request budget. No
    /// session or journal is touched, and Previous has an empty selection.
    pub fn query_program(
        &self,
        tenant: &str,
        program_json: &str,
        cancellation: Cancellation,
    ) -> Result<String> {
        let budget = Budget::new(&self.limits, cancellation)?;
        self.query_program_with_budget(tenant, program_json, &budget)
    }
    pub fn query_program_with_budget(
        &self,
        tenant: &str,
        program_json: &str,
        budget: &Budget,
    ) -> Result<String> {
        crate::runtime::identifier(tenant)?;
        let limits = &self.limits;
        let budget = budget.restricted_to(limits)?;
        budget.spend(program_json.len() as u64 + 1)?;
        let program = Program::parse(program_json, limits)?;
        budget.check()?;
        let plan = program.compile(limits)?;
        budget.spend(plan.nodes.len() as u64 + 1)?;
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

pub(crate) struct Lease<'a> {
    image: &'a Image,
    db: Option<Connection>,
    tenant: String,
}
impl std::ops::Deref for Lease<'_> {
    type Target = Connection;
    fn deref(&self) -> &Connection {
        self.db.as_ref().expect("live lease owns connection")
    }
}
impl Drop for Lease<'_> {
    fn drop(&mut self) {
        if let Some(db) = self.db.take() {
            db.progress_handler(0, None::<fn() -> bool>);
            // Cleanup is part of owning the slot. Cancellation cannot abandon
            // private scratch for the next tenant, and cleanup failure poisons
            // the image rather than returning a questionable connection.
            let clean = db
                .execute_batch("DELETE FROM temp.oracle_sets; DELETE FROM temp.oracle_facts; DELETE FROM temp.oracle_attributes;")
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
