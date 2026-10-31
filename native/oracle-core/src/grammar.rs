//! Release-built reader tables. Serving reads indexed rows; no pickle, learner,
//! per-tenant table graph, or Python callback belongs on this path.
//!
//! This module supplies whole-template matching and composition primitives. It
//! does not execute programs, search fragment regions, compose segments, perform
//! analogy, or peel clauses. Successful execution and agreement remain required.
use crate::{Budget, Error, Result};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};

pub const READER_FORMAT: &str = "oracle-reader-tables";
pub const READER_VERSION: u32 = 1;
// Explicit release admission bounds; these are not language heuristics.
pub const MAX_SKELETON_BYTES: usize = 1024 * 1024;
pub const MAX_SKELETON_STEPS: usize = 1024;
pub const MAX_STEP_INPUTS: usize = 16;

pub const SCHEMA: &str = "
CREATE TABLE reader_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE reader_template (
 family TEXT NOT NULL, level INTEGER NOT NULL, template TEXT NOT NULL,
 skeleton TEXT NOT NULL, support INTEGER NOT NULL CHECK(support>0),
 PRIMARY KEY(family,level,template,skeleton)) WITHOUT ROWID;
CREATE TABLE reader_shape (
 level INTEGER NOT NULL, template TEXT NOT NULL, roots TEXT NOT NULL,
 support INTEGER NOT NULL CHECK(support>0), PRIMARY KEY(level,template,roots)) WITHOUT ROWID;
CREATE TABLE reader_alias (
 phrase TEXT NOT NULL, kind TEXT NOT NULL, canonical TEXT NOT NULL,
 PRIMARY KEY(phrase,kind)) WITHOUT ROWID;
CREATE TABLE reader_word (
 category TEXT NOT NULL, word TEXT NOT NULL, PRIMARY KEY(category,word)) WITHOUT ROWID;
CREATE TABLE reader_form (
 opening TEXT PRIMARY KEY, kinds TEXT NOT NULL) WITHOUT ROWID;
";

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ReaderExport {
    pub format: String,
    pub version: u32,
    pub metadata: BTreeMap<String, Value>,
    pub policy: ReaderPolicy,
    pub templates: Vec<TemplateRow>,
    pub shapes: Vec<ShapeRow>,
    pub aliases: Vec<AliasRow>,
    pub words: Vec<WordRow>,
    pub forms: Vec<FormRow>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ReaderPolicy {
    pub min_skeleton: u64,
    pub dominance: f64,
    pub all_replicated: bool,
    pub outer_replicated: bool,
    pub form_check: bool,
    pub asking_check: bool,
}
impl Default for ReaderPolicy {
    fn default() -> Self {
        Self {
            min_skeleton: 2,
            dominance: 0.5,
            all_replicated: false,
            outer_replicated: true,
            form_check: true,
            asking_check: true,
        }
    }
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct TemplateRow {
    /// whole, fragment, outer, or segment. A leading ~ is a learned fallback key.
    pub family: String,
    pub level: u8,
    pub template: String,
    pub skeleton: Value,
    pub support: u64,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct ShapeRow {
    pub level: u8,
    pub template: String,
    pub roots: Vec<String>,
    pub support: u64,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct AliasRow {
    pub phrase: String,
    pub kind: char,
    pub canonical: String,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct WordRow {
    pub category: String,
    pub word: String,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FormRow {
    pub opening: String,
    pub kinds: Vec<String>,
}

/// Offline import. Call once while building the image, before publication. All
/// inserts are atomic, including schema creation. Duplicate keys are errors.
/// `max_bytes` bounds the admitted serialized export, not SQLite overhead.
pub fn install_tables(
    db: &Connection,
    export: &ReaderExport,
    max_rows: usize,
    max_bytes: usize,
) -> Result<()> {
    if export.format != READER_FORMAT || export.version != READER_VERSION {
        return Err(Error::Format("reader tables version".into()));
    }
    if !export.policy.dominance.is_finite()
        || !(0.0..=1.0).contains(&export.policy.dominance)
        || export.policy.min_skeleton == 0
    {
        return Err(Error::Invalid("reader trust policy".into()));
    }
    let rows = export
        .templates
        .len()
        .checked_add(export.shapes.len())
        .and_then(|n| n.checked_add(export.aliases.len()))
        .and_then(|n| n.checked_add(export.words.len()))
        .and_then(|n| n.checked_add(export.forms.len()))
        .ok_or(Error::Limit("reader rows"))?;
    if rows > max_rows {
        return Err(Error::Limit("reader rows"));
    }
    if serde_json::to_vec(export)?.len() > max_bytes {
        return Err(Error::Limit("reader export bytes"));
    }
    // SAVEPOINT composes with the image builder's surrounding transaction.
    db.execute_batch("SAVEPOINT import_reader_tables")?;
    let result = (|| -> Result<()> {
        db.execute_batch(SCHEMA)?;
        for (key, value) in [
            ("version", Value::from(export.version)),
            ("format", Value::from(export.format.clone())),
            ("policy", serde_json::to_value(&export.policy)?),
            ("provenance", serde_json::to_value(&export.metadata)?),
        ] {
            db.execute(
                "INSERT INTO reader_meta VALUES (?1,?2)",
                params![key, serde_json::to_string(&value)?],
            )?;
        }
        for row in &export.templates {
            validate_family(&row.family, row.level)?;
            positive_support(row.support)?;
            validate_skeleton(&row.family, &row.skeleton)?;
            db.execute(
                "INSERT INTO reader_template VALUES (?1,?2,?3,?4,?5)",
                params![
                    row.family,
                    row.level,
                    row.template,
                    serde_json::to_string(&row.skeleton)?,
                    row.support as i64
                ],
            )?;
        }
        for row in &export.shapes {
            validate_family("outer", row.level)?;
            positive_support(row.support)?;
            if row.roots.iter().any(|s| s != "E" && s != "A") {
                return Err(Error::Invalid("reader root shape".into()));
            }
            db.execute(
                "INSERT INTO reader_shape VALUES (?1,?2,?3,?4)",
                params![
                    row.level,
                    row.template,
                    serde_json::to_string(&row.roots)?,
                    row.support as i64
                ],
            )?;
        }
        for row in &export.aliases {
            if !"ECVANR".contains(row.kind) || row.phrase.is_empty() || row.canonical.is_empty() {
                return Err(Error::Invalid("reader alias".into()));
            }
            db.execute(
                "INSERT INTO reader_alias VALUES (?1,?2,?3)",
                params![row.phrase, row.kind.to_string(), row.canonical],
            )?;
        }
        for row in &export.words {
            if !["operator", "keep", "glue"].contains(&row.category.as_str()) || row.word.is_empty()
            {
                return Err(Error::Invalid("reader word category".into()));
            }
            db.execute(
                "INSERT INTO reader_word VALUES (?1,?2)",
                params![row.category, row.word],
            )?;
        }
        for row in &export.forms {
            db.execute(
                "INSERT INTO reader_form VALUES (?1,?2)",
                params![row.opening, serde_json::to_string(&row.kinds)?],
            )?;
        }
        Ok(())
    })();
    if result.is_ok() {
        db.execute_batch("RELEASE import_reader_tables")?;
    } else {
        db.execute_batch("ROLLBACK TO import_reader_tables; RELEASE import_reader_tables")?;
    }
    result
}
fn positive_support(n: u64) -> Result<()> {
    if n == 0 || n > i64::MAX as u64 {
        Err(Error::Invalid("reader support count".into()))
    } else {
        Ok(())
    }
}
fn validate_family(family: &str, level: u8) -> Result<()> {
    if level > 1 || !["whole", "fragment", "outer", "segment"].contains(&family) {
        Err(Error::Invalid("reader family or level".into()))
    } else {
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Step {
    pub function: String,
    #[serde(default)]
    pub dependencies: Vec<usize>,
    pub inputs: Vec<Value>,
}
pub type Program = Vec<Step>;
pub type Bindings = BTreeMap<(char, usize), String>;
fn steps_of(family: &str, skeleton: &Value) -> Result<Program> {
    let steps = if family == "segment" {
        skeleton
            .get("steps")
            .ok_or_else(|| Error::Invalid("segment steps".into()))?
    } else {
        skeleton
    };
    Ok(serde_json::from_value(steps.clone())?)
}
fn validate_skeleton(family: &str, skeleton: &Value) -> Result<()> {
    if family == "segment"
        && !matches!(
            skeleton.get("role").and_then(Value::as_str),
            Some("source" | "filter")
        )
    {
        return Err(Error::Invalid("segment role".into()));
    }
    if serde_json::to_vec(skeleton)?.len() > MAX_SKELETON_BYTES {
        return Err(Error::Limit("reader skeleton bytes"));
    }
    let steps = steps_of(family, skeleton)?;
    if steps.len() > MAX_SKELETON_STEPS {
        return Err(Error::Limit("reader skeleton steps"));
    }
    if steps.is_empty() {
        return Err(Error::Invalid("empty reader skeleton".into()));
    }
    for (i, step) in steps.iter().enumerate() {
        if step.inputs.len() > MAX_STEP_INPUTS || step.dependencies.len() > MAX_SKELETON_STEPS {
            return Err(Error::Limit("reader step arity"));
        }
        if step.function.is_empty() || step.dependencies.iter().any(|&d| d >= i) {
            return Err(Error::Invalid("reader skeleton dependency".into()));
        }
        if step.function == "@X" {
            if step.inputs.len() != 1 || !matches!(step.inputs[0].as_u64(), Some(n) if n > 0) {
                return Err(Error::Invalid("reader X reference".into()));
            }
        } else {
            for input in &step.inputs {
                if input.is_array() {
                    slot(input)?;
                } else if !input.is_string() {
                    return Err(Error::Invalid("reader literal".into()));
                }
            }
        }
    }
    Ok(())
}
fn slot(value: &Value) -> Result<(char, usize, &str)> {
    let bad = || Error::Invalid("reader slot".into());
    let a = value.as_array().ok_or_else(bad)?;
    if a.len() != 4 || a[0] != "@" {
        return Err(bad());
    }
    let kind = a[1].as_str().ok_or_else(bad)?;
    let mut chars = kind.chars();
    let kd = chars.next().ok_or_else(bad)?;
    if chars.next().is_some() || !"ECVANR".contains(kd) {
        return Err(bad());
    }
    let ordinal = a[2]
        .as_u64()
        .and_then(|n| usize::try_from(n).ok())
        .filter(|&n| n > 0)
        .ok_or_else(bad)?;
    Ok((kd, ordinal, a[3].as_str().ok_or_else(bad)?))
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Fallback {
    None,
    Content,
    Strip,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct LearnedCandidate {
    pub skeleton: Value,
    pub support: u64,
    pub rejection: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Lookup {
    pub family: String,
    pub level: u8,
    pub matched_key: String,
    pub exact: bool,
    pub total_support: u64,
    pub candidates: Vec<LearnedCandidate>,
}

/// Exact presence prevents fallback even if every exact skeleton is rejected.
/// All alternatives remain visible: support never elects a winning program.
#[allow(clippy::too_many_arguments)] // Indexed key, release policy and host bounds are separate inputs.
pub fn lookup(
    db: &Connection,
    family: &str,
    level: u8,
    template: &str,
    fallback: Fallback,
    policy: &ReaderPolicy,
    max_hits: usize,
    budget: &Budget,
) -> Result<Option<Lookup>> {
    validate_family(family, level)?;
    budget.spend(1)?;
    let exact = lookup_rows(db, family, level, template, max_hits, budget)?;
    let (key, rows, is_exact) = if exact.is_empty() {
        if fallback == Fallback::None {
            return Ok(None);
        }
        let key = fallback_key(db, template, fallback, budget)?;
        let rows = lookup_rows(db, family, level, &key, max_hits, budget)?;
        if rows.is_empty() {
            return Ok(None);
        }
        (key, rows, false)
    } else {
        (template.to_owned(), exact, true)
    };
    let total = rows.iter().try_fold(0u64, |a, (_, n)| {
        a.checked_add(*n).ok_or(Error::Limit("reader support"))
    })?;
    let mut candidates = Vec::new();
    for (skeleton, n) in rows {
        let sk = steps_of(family, &skeleton)?;
        let hidden = hidden_literal(&sk);
        let rejection = if family == "whole" {
            (hidden && n < policy.min_skeleton).then(|| "hidden_literal_support".into())
        } else if (policy.all_replicated || (family == "outer" && policy.outer_replicated))
            && n < policy.min_skeleton
        {
            Some("replication".into())
        } else if hidden
            && (n < policy.min_skeleton || (n as f64) < policy.dominance * total as f64)
        {
            Some("hidden_literal_dominance".into())
        } else {
            None
        };
        candidates.push(LearnedCandidate {
            skeleton,
            support: n,
            rejection,
        });
    }
    Ok(Some(Lookup {
        family: family.into(),
        level,
        matched_key: key,
        exact: is_exact,
        total_support: total,
        candidates,
    }))
}
fn lookup_rows(
    db: &Connection,
    family: &str,
    level: u8,
    template: &str,
    max_hits: usize,
    budget: &Budget,
) -> Result<Vec<(Value, u64)>> {
    let mut statement = db.prepare_cached("SELECT skeleton,support FROM reader_template WHERE family=?1 AND level=?2 AND template=?3 ORDER BY skeleton")?;
    let mut cursor = statement.query(params![family, level, template])?;
    let mut rows = Vec::new();
    while let Some(row) = cursor.next()? {
        budget.spend(1)?;
        if rows.len() >= max_hits {
            return Err(Error::Limit("reader matches"));
        }
        let skeleton: String = row.get(0)?;
        if skeleton.len() > MAX_SKELETON_BYTES {
            return Err(Error::Limit("reader skeleton bytes"));
        }
        budget.spend(skeleton.len() as u64)?;
        let support: i64 = row.get(1)?;
        if support <= 0 {
            return Err(Error::Format("reader support".into()));
        }
        rows.push((serde_json::from_str(&skeleton)?, support as u64));
    }
    Ok(rows)
}
fn is_glue(db: &Connection, word: &str) -> Result<bool> {
    Ok(db.query_row("SELECT EXISTS(SELECT 1 FROM reader_word WHERE category='glue' AND word=?1) AND NOT EXISTS(SELECT 1 FROM reader_word WHERE category='keep' AND word=?1)", [word], |r| r.get(0))?)
}
pub fn fallback_key(
    db: &Connection,
    template: &str,
    fallback: Fallback,
    budget: &Budget,
) -> Result<String> {
    let mut words = Vec::new();
    let mut leading = true;
    let all: Vec<_> = template.split_whitespace().collect();
    for (i, word) in all.iter().enumerate() {
        budget.spend(1)?;
        let drop = match fallback {
            Fallback::None => false,
            Fallback::Content => is_glue(db, word)?,
            Fallback::Strip => leading && i + 1 < all.len() && is_glue(db, word)?,
        };
        if !drop {
            leading = false;
            words.push(*word);
        }
    }
    Ok(format!("~{}", words.join(" ")))
}
pub fn hidden_literal(steps: &[Step]) -> bool {
    const CONSTANTS: &[&str] = &[
        "<", ">", "=", "!=", "largest", "smallest", "greater", "less", "forward", "backward",
    ];
    steps
        .iter()
        .flat_map(|s| &s.inputs)
        .filter_map(Value::as_str)
        .any(|v| {
            let digits = v.replace('.', "");
            let digits = digits.trim_start_matches('-');
            !v.is_empty()
                && !CONSTANTS.contains(&v)
                && (digits.is_empty() || !digits.chars().all(|c| c.is_ascii_digit()))
        })
}

/// Bind one learned syntax recipe without expanding child programs. X labels
/// are redirected to chart holes; @NOP removal/dependency mapping matches the
/// former singleton-placeholder expansion, with no child flattening.
pub(crate) fn bind_recipe(
    skeleton: &[Step],
    texts: &Bindings,
    holes: &BTreeMap<usize, usize>,
    max_steps: usize,
) -> Result<Option<Program>> {
    if skeleton.len() > max_steps {
        return Err(Error::Limit("reader skeleton steps"));
    }
    let mut output = Vec::with_capacity(skeleton.len());
    let mut indices = BTreeMap::new();
    for (index, step) in skeleton.iter().enumerate() {
        if step.function == "@NOP" {
            continue;
        }
        if step.function == "@X" {
            let ordinal = step
                .inputs
                .first()
                .and_then(Value::as_u64)
                .and_then(|n| usize::try_from(n).ok())
                .ok_or_else(|| Error::Format("X input".into()))?;
            let Some(hole) = holes.get(&ordinal) else {
                return Ok(None);
            };
            output.push(Step {
                function: "@X".into(),
                dependencies: vec![],
                inputs: vec![Value::from(*hole as u64)],
            });
        } else {
            let mut dependencies = Vec::with_capacity(step.dependencies.len());
            for d in &step.dependencies {
                let Some(mapped) = indices.get(d) else {
                    return Ok(None);
                };
                dependencies.push(*mapped);
            }
            let mut inputs = Vec::with_capacity(step.inputs.len());
            for input in &step.inputs {
                if input.is_array() {
                    let (kind, ordinal, unit) = slot(input)?;
                    let Some(text) = texts.get(&(kind, ordinal)) else {
                        return Ok(None);
                    };
                    inputs.push(Value::String(if kind == 'N' && !unit.is_empty() {
                        format!("{text} {unit}")
                    } else {
                        text.clone()
                    }));
                } else {
                    inputs.push(input.clone());
                }
            }
            output.push(Step {
                function: step.function.clone(),
                dependencies,
                inputs,
            });
        }
        if output.len() > max_steps {
            return Err(Error::Limit("reader program steps"));
        }
        indices.insert(index, output.len() - 1);
    }
    Ok(Some(output))
}

/// Fill ordinary slots and splice X programs while rebasing all dependencies.
/// Missing bindings return None; malformed release rows return a format error.
pub fn expand(
    skeleton: &[Step],
    texts: &Bindings,
    xprograms: &BTreeMap<usize, Program>,
    max_steps: usize,
) -> Result<Option<Program>> {
    if skeleton.len() > max_steps {
        return Err(Error::Limit("reader skeleton steps"));
    }
    let mut program = Vec::<Step>::new();
    let mut indices = BTreeMap::new();
    for (i, step) in skeleton.iter().enumerate() {
        if step.function == "@NOP" {
            continue;
        }
        if step.function == "@X" {
            let Some(x) = step
                .inputs
                .first()
                .and_then(Value::as_u64)
                .and_then(|n| usize::try_from(n).ok())
            else {
                return Err(Error::Format("X input".into()));
            };
            let Some(p) = xprograms.get(&x).filter(|p| !p.is_empty()) else {
                return Ok(None);
            };
            let base = program.len();
            if p.len() > max_steps.saturating_sub(base) {
                return Err(Error::Limit("reader program steps"));
            }
            for (j, st) in p.iter().enumerate() {
                if st.dependencies.iter().any(|&d| d >= j) {
                    return Err(Error::Invalid("X program dependency".into()));
                }
                program.push(Step {
                    function: st.function.clone(),
                    dependencies: st.dependencies.iter().map(|d| d + base).collect(),
                    inputs: st.inputs.clone(),
                });
            }
        } else {
            let mut dependencies = Vec::new();
            for d in &step.dependencies {
                let Some(mapped) = indices.get(d) else {
                    return Ok(None);
                };
                dependencies.push(*mapped);
            }
            let mut inputs = Vec::new();
            for input in &step.inputs {
                if input.is_array() {
                    let (kind, ordinal, unit) = slot(input)?;
                    let Some(text) = texts.get(&(kind, ordinal)) else {
                        return Ok(None);
                    };
                    inputs.push(Value::String(if kind == 'N' && !unit.is_empty() {
                        format!("{text} {unit}")
                    } else {
                        text.clone()
                    }));
                } else {
                    inputs.push(input.clone());
                }
            }
            if program.len() >= max_steps {
                return Err(Error::Limit("reader program steps"));
            }
            program.push(Step {
                function: step.function.clone(),
                dependencies,
                inputs,
            });
        }
        indices.insert(i, program.len() - 1);
    }
    Ok(Some(program))
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct GrammarSpan {
    pub start: usize,
    pub end: usize,
    pub kind: char,
    pub canonical: String,
}
/// Input is already normalized by the lexicon's selected Reader4/Reader7 mode.
/// Byte offsets must cover complete words; overlapping spans are rejected.
pub fn delex(question: &str, spans: &[GrammarSpan]) -> Result<(String, Bindings)> {
    let mut sorted = spans.to_vec();
    sorted.sort();
    let mut last = 0;
    let mut output = String::new();
    let mut counters = BTreeMap::<char, usize>::new();
    let mut bindings = BTreeMap::new();
    for span in sorted {
        if span.start < last
            || span.start >= span.end
            || span.end > question.len()
            || !question.is_char_boundary(span.start)
            || !question.is_char_boundary(span.end)
            || (span.start > 0 && question.as_bytes()[span.start - 1] != b' ')
            || (span.end < question.len() && question.as_bytes()[span.end] != b' ')
            || !"ECVANRX".contains(span.kind)
        {
            return Err(Error::Invalid("reader span".into()));
        }
        output.push_str(&question[last..span.start]);
        let count = counters.entry(span.kind).or_default();
        *count += 1;
        output.push_str(&format!(" {}{} ", span.kind, count));
        bindings.insert((span.kind, *count), span.canonical);
        last = span.end;
    }
    output.push_str(&question[last..]);
    Ok((
        output.split_whitespace().collect::<Vec<_>>().join(" "),
        bindings,
    ))
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct MatchedProgram {
    pub template: String,
    pub level: u8,
    pub support: u64,
    pub program: Program,
}
#[derive(Clone, Copy, Debug)]
pub struct MatchLimits {
    pub combinations: usize,
    pub matches: usize,
    pub steps: usize,
    pub materialized_bytes: usize,
}
impl Default for MatchLimits {
    fn default() -> Self {
        Self {
            combinations: 400,
            matches: 4000,
            steps: 128,
            materialized_bytes: 2 * 1024 * 1024,
        }
    }
}

/// Walk question words and lexical spans against learned whole-template prefixes.
/// The existing immutable B-tree is the automaton's prefix index: paths with no
/// learned continuation are discarded before enumerating their remaining spans.
/// Every exact complete binding still participates, with all guards unchanged.
/// Bounds count reachable exact-template bindings, never impossible subsets.
pub fn match_whole(
    db: &Connection,
    normalized: &str,
    spans: &[GrammarSpan],
    level: u8,
    policy: &ReaderPolicy,
    limits: MatchLimits,
    budget: &Budget,
) -> Result<Vec<MatchedProgram>> {
    validate_family("whole", level)?;
    if normalized
        .chars()
        .any(|c| c.is_alphanumeric() && !c.is_ascii())
    {
        return Err(Error::Invalid("unreadable reader script".into()));
    }
    if normalized.split_whitespace().collect::<Vec<_>>().join(" ") != normalized {
        return Err(Error::Invalid("reader question is not normalized".into()));
    }
    let input_bytes = spans.iter().try_fold(normalized.len(), |n, span| {
        n.checked_add(span.canonical.len())
            .and_then(|n| n.checked_add(std::mem::size_of::<GrammarSpan>()))
            .ok_or(Error::Limit("reader input bytes"))
    })?;
    if input_bytes > limits.materialized_bytes {
        return Err(Error::Limit("reader input bytes"));
    }
    budget.spend(input_bytes as u64)?;
    let mut sorted = spans.to_vec();
    sorted.sort();
    sorted.dedup();
    for span in &sorted {
        delex(normalized, std::slice::from_ref(span))?;
    }
    let words: Vec<&str> = normalized.split_whitespace().collect();
    let mut starts = BTreeMap::new();
    let mut ends = BTreeMap::new();
    let mut offset = 0usize;
    for (i, word) in words.iter().enumerate() {
        starts.insert(offset, i);
        offset += word.len();
        ends.insert(offset, i + 1);
        offset += 1;
    }
    let mut at = vec![Vec::<(usize, usize)>::new(); words.len()];
    for (i, span) in sorted.iter().enumerate() {
        let start = starts
            .get(&span.start)
            .ok_or_else(|| Error::Invalid("reader span start".into()))?;
        let end = ends
            .get(&span.end)
            .ok_or_else(|| Error::Invalid("reader span end".into()))?;
        at[*start].push((i, *end));
    }
    // One mutable path, not cloned frontiers. A frame remembers only the input
    // position and how to undo its emitted token/binding during backtracking.
    struct Frame {
        position: usize,
        next: usize,
        prefix_len: usize,
        binding: Option<(char, usize)>,
    }
    let workspace_bytes = words
        .len()
        .checked_mul(192)
        .and_then(|n| n.checked_add(sorted.len().saturating_mul(32)))
        .and_then(|n| n.checked_add(input_bytes))
        .ok_or(Error::Limit("reader matching workspace"))?;
    if workspace_bytes > limits.materialized_bytes {
        return Err(Error::Limit("reader matching workspace"));
    }
    let mut stack = vec![Frame {
        position: 0,
        next: 0,
        prefix_len: 0,
        binding: None,
    }];
    let mut prefix = String::new();
    let mut texts = Bindings::new();
    let mut counters = BTreeMap::<char, usize>::new();
    let mut cache = BTreeMap::<String, bool>::new();
    let mut cache_bytes = 0usize;
    let mut prefix_query = db.prepare_cached("SELECT EXISTS(SELECT 1 FROM reader_template WHERE family='whole' AND level=?1 AND template>=?2 AND template<?3)")?;
    let mut count = 0usize;
    let mut out = Vec::new();
    let mut output_bytes = 0usize;
    while !stack.is_empty() {
        budget.spend(1)?;
        let top = stack.len() - 1;
        let position = stack[top].position;
        if position == words.len() {
            if let Some(hit) = lookup(
                db,
                "whole",
                level,
                &prefix,
                Fallback::None,
                policy,
                limits.matches,
                budget,
            )? {
                count += 1;
                if count > limits.combinations {
                    return Err(Error::Limit("reader combinations"));
                }
                for candidate in hit.candidates.into_iter().filter(|r| r.rejection.is_none()) {
                    if let Some(program) = expand(
                        &steps_of("whole", &candidate.skeleton)?,
                        &texts,
                        &BTreeMap::new(),
                        limits.steps,
                    )? {
                        if out.len() >= limits.matches {
                            return Err(Error::Limit("reader matches"));
                        }
                        let matched = MatchedProgram {
                            template: prefix.clone(),
                            level,
                            support: candidate.support,
                            program,
                        };
                        let bytes = serde_json::to_vec(&matched)?.len();
                        budget.spend(bytes as u64)?;
                        output_bytes = output_bytes
                            .checked_add(bytes)
                            .ok_or(Error::Limit("reader output bytes"))?;
                        if workspace_bytes
                            .saturating_add(cache_bytes)
                            .saturating_add(output_bytes)
                            > limits.materialized_bytes
                        {
                            return Err(Error::Limit("reader output bytes"));
                        }
                        out.push(matched);
                    }
                }
            }
        } else {
            let transition = stack[top].next;
            stack[top].next += 1;
            if transition <= at[position].len() {
                let (token, end, binding) = if transition == 0 {
                    (words[position].to_owned(), position + 1, None)
                } else {
                    let (span_index, end) = at[position][transition - 1];
                    let span = &sorted[span_index];
                    let ordinal = counters.get(&span.kind).copied().unwrap_or(0) + 1;
                    (
                        format!("{}{ordinal}", span.kind),
                        end,
                        Some((span_index, ordinal)),
                    )
                };
                let old_len = prefix.len();
                if !prefix.is_empty() {
                    prefix.push(' ');
                }
                prefix.push_str(&token);
                budget.spend(token.len() as u64 + 1)?;
                let feasible = if end == words.len() {
                    true
                } else if let Some(present) = cache.get(&prefix) {
                    *present
                } else {
                    // BINARY [prefix+' ', prefix+'!') admits exactly longer
                    // token-boundary continuations, excluding E10 for E1 etc.
                    let lower = format!("{prefix} ");
                    let upper = format!("{prefix}!");
                    budget.spend(prefix.len() as u64 + 1)?;
                    let present: bool =
                        prefix_query.query_row(params![level, lower, upper], |r| r.get(0))?;
                    let bytes = prefix.len().saturating_add(128);
                    // Cache admission is optional. On saturation, continue
                    // indexed probes under fuel rather than lose a reading.
                    if cache_bytes.saturating_add(bytes) <= limits.materialized_bytes / 4
                        && workspace_bytes
                            .saturating_add(output_bytes)
                            .saturating_add(cache_bytes)
                            .saturating_add(bytes)
                            <= limits.materialized_bytes
                    {
                        cache_bytes += bytes;
                        cache.insert(prefix.clone(), present);
                    }
                    present
                };
                if feasible {
                    let undo = binding.map(|(span_index, ordinal)| {
                        let span = &sorted[span_index];
                        counters.insert(span.kind, ordinal);
                        texts.insert((span.kind, ordinal), span.canonical.clone());
                        (span.kind, ordinal)
                    });
                    stack.push(Frame {
                        position: end,
                        next: 0,
                        prefix_len: old_len,
                        binding: undo,
                    });
                    continue;
                }
                prefix.truncate(old_len);
                continue;
            }
        }
        let frame = stack.pop().expect("nonempty matching path");
        prefix.truncate(frame.prefix_len);
        if let Some((kind, ordinal)) = frame.binding {
            texts.remove(&(kind, ordinal));
            counters.insert(kind, ordinal - 1);
        }
    }
    Ok(out)
}

/// The raw-input veto must run before normalization can discard written values.
pub fn unreadable(raw_question: &str) -> bool {
    raw_question
        .chars()
        .any(|c| c.is_alphanumeric() && !c.is_ascii())
}

pub fn answer_kind(program: &[Step]) -> &'static str {
    match program.last().map(|s| s.function.as_str()).unwrap_or("") {
        "VerifyStr" | "VerifyNum" | "VerifyYear" | "VerifyDate" => "yesno",
        "Count" => "count",
        "QueryRelation" => "relation",
        "QueryAttr" | "QueryAttrUnderCondition" => "value",
        "QueryAttrQualifier" | "QueryRelationQualifier" => "qualifier",
        "What" | "SelectBetween" | "SelectAmong" => "entity",
        _ => "other",
    }
}
/// Call only with successfully EXECUTED readings. One forbidden form vetoes all
/// readings; removing a disagreeing reading could otherwise admit an answer.
pub fn forms_allow(
    db: &Connection,
    normalized: &str,
    successful: &[Program],
    policy: &ReaderPolicy,
    budget: &Budget,
) -> Result<bool> {
    if !policy.form_check {
        return Ok(true);
    }
    let words: Vec<_> = normalized.split_whitespace().collect();
    let openings = [
        words.iter().take(2).copied().collect::<Vec<_>>().join(" "),
        words.first().copied().unwrap_or("").to_owned(),
    ];
    let mut rules = Vec::<BTreeSet<String>>::new();
    let get = |opening: &str| -> Result<Option<BTreeSet<String>>> {
        budget.spend(1)?;
        let mut statement = db.prepare_cached("SELECT kinds FROM reader_form WHERE opening=?1")?;
        let mut cursor = statement.query([opening])?;
        let Some(row) = cursor.next()? else {
            return Ok(None);
        };
        Ok(Some(serde_json::from_str(&row.get::<_, String>(0)?)?))
    };
    for opening in openings {
        if let Some(kinds) = get(&opening)? {
            rules.push(kinds);
            break;
        }
    }
    if policy.asking_check {
        for word in words
            .iter()
            .filter(|w| {
                [
                    "what", "when", "where", "which", "who", "whom", "whose", "how",
                ]
                .contains(w)
            })
            .collect::<BTreeSet<_>>()
        {
            if let Some(kinds) = get(&format!("has:{word}"))? {
                rules.push(kinds);
            }
        }
    }
    Ok(successful
        .iter()
        .all(|p| rules.iter().all(|r| r.contains(answer_kind(p)))))
}

/// Release policy is shared image data, never tenant training state. This also
/// checks the reader subformat before a consumer starts reading its tables.
pub fn read_policy(db: &Connection) -> Result<ReaderPolicy> {
    let format: String = db.query_row(
        "SELECT value FROM reader_meta WHERE key='format'",
        [],
        |r| r.get(0),
    )?;
    let version: String = db.query_row(
        "SELECT value FROM reader_meta WHERE key='version'",
        [],
        |r| r.get(0),
    )?;
    if serde_json::from_str::<String>(&format)? != READER_FORMAT
        || serde_json::from_str::<u32>(&version)? != READER_VERSION
    {
        return Err(Error::Format("reader tables version".into()));
    }
    let policy: String = db.query_row(
        "SELECT value FROM reader_meta WHERE key='policy'",
        [],
        |r| r.get(0),
    )?;
    Ok(serde_json::from_str(&policy)?)
}

/// All learned outer X-root shapes, with counts; no majority shape is elected.
pub fn outer_shapes(
    db: &Connection,
    level: u8,
    template: &str,
    max_hits: usize,
    budget: &Budget,
) -> Result<Vec<ShapeRow>> {
    validate_family("outer", level)?;
    let mut statement = db.prepare_cached(
        "SELECT roots,support FROM reader_shape WHERE level=?1 AND template=?2 ORDER BY roots",
    )?;
    let mut cursor = statement.query(params![level, template])?;
    let mut out = Vec::new();
    while let Some(row) = cursor.next()? {
        budget.spend(1)?;
        if out.len() >= max_hits {
            return Err(Error::Limit("reader shapes"));
        }
        let roots: String = row.get(0)?;
        let support: i64 = row.get(1)?;
        if support <= 0 {
            return Err(Error::Format("reader shape support".into()));
        }
        out.push(ShapeRow {
            level,
            template: template.into(),
            roots: serde_json::from_str(&roots)?,
            support: support as u64,
        });
    }
    Ok(out)
}
