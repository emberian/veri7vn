//! Release-built lexical data. This recognizer is untrusted: a lexical match is
//! a possible reading, not evidence that its eventual program or answer is true.
//!
//! Each query probes immutable indexed tables; no corpus scan, Python object
//! graph, learned tenant state, or mutable alias cache is needed. Offsets are
//! bytes in the returned ASCII normalized string, never offsets in raw input.
//! Callers install their SQLite progress hook as for other image queries. The
//! explicit Budget additionally charges input, point probes, and returned rows.
use crate::{Budget, Error, Result};
use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;

pub const VERSION: &str = "oracle-lexicon-v1";
const SCHEMA: &str = "
CREATE TABLE oracle_lexicon(
 profile TEXT NOT NULL,surface TEXT NOT NULL,kind TEXT NOT NULL,
 canonical TEXT NOT NULL,alias INTEGER NOT NULL CHECK(alias IN (0,1)),
 PRIMARY KEY(profile,surface,kind,alias,canonical)) WITHOUT ROWID;
CREATE TABLE oracle_lexicon_concepts(
 profile TEXT NOT NULL,surface TEXT NOT NULL,canonical TEXT NOT NULL,
 PRIMARY KEY(profile,surface,canonical)) WITHOUT ROWID;
";
const FUNC: &str = "a an the of in on at to for by with from is are was were be been being did does do has have had that which who whom whose what when where how this these those it its as and or than";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Normalization {
    Reader4,
    Reader7,
}
impl Normalization {
    fn key(self) -> &'static str {
        match self {
            Self::Reader4 => "reader4",
            Self::Reader7 => "reader7",
        }
    }
}

/// Rank is the original reader's deterministic kind order. Alias set iteration
/// in Python was not deterministic; the native order is explicitly fixed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum LexicalKind {
    E,
    C,
    V,
    A,
    R,
    N,
}
impl LexicalKind {
    pub fn code(self) -> char {
        match self {
            Self::E => 'E',
            Self::C => 'C',
            Self::V => 'V',
            Self::A => 'A',
            Self::R => 'R',
            Self::N => 'N',
        }
    }
    fn key(self) -> &'static str {
        match self {
            Self::E => "E",
            Self::C => "C",
            Self::V => "V",
            Self::A => "A",
            Self::R => "R",
            Self::N => "N",
        }
    }
    fn parse(s: &str) -> Result<Self> {
        match s {
            "E" => Ok(Self::E),
            "C" => Ok(Self::C),
            "V" => Ok(Self::V),
            "A" => Ok(Self::A),
            "R" => Ok(Self::R),
            "N" => Ok(Self::N),
            _ => Err(Error::Format("lexical kind".into())),
        }
    }
}

#[derive(Clone, Debug)]
pub struct LexiconBuildLimits {
    pub record_bytes: usize,
    pub label_bytes: usize,
    pub entries: u64,
}
impl Default for LexiconBuildLimits {
    fn default() -> Self {
        Self {
            record_bytes: 16 * 1024 * 1024,
            label_bytes: 65536,
            entries: 20_000_000,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct LexiconLimits {
    pub question_bytes: usize,
    pub question_tokens: usize,
    pub max_name_words: usize,
    pub spans: usize,
    pub readings: usize,
    pub materialized_bytes: usize,
}
impl Default for LexiconLimits {
    fn default() -> Self {
        Self {
            question_bytes: 65536,
            question_tokens: 1024,
            max_name_words: 32,
            spans: 8192,
            readings: 16384,
            materialized_bytes: 2 * 1024 * 1024,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct CandidateOptions {
    pub normalization: Normalization,
    /// Reader7.found rules; whole-question Reader6.candidates leaves this false
    /// even when its text uses Reader7 possessive normalization.
    pub compositional: bool,
    pub level2: bool,
    pub outer: bool,
    pub plural: bool,
    pub max_words: usize,
}
impl Default for CandidateOptions {
    fn default() -> Self {
        Self {
            normalization: Normalization::Reader7,
            compositional: false,
            level2: false,
            outer: false,
            plural: true,
            max_words: 8,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LexicalReading {
    pub kind: LexicalKind,
    pub canonical: String,
    pub via_alias: bool,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CandidateSpan {
    pub start: usize,
    pub end: usize,
    pub readings: Vec<LexicalReading>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CandidateSet {
    pub normalized: String,
    pub spans: Vec<CandidateSpan>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Alias {
    pub surface: String,
    pub kind: LexicalKind,
    pub canonical: String,
}

/// Equivalent to Reader4's `[a-z0-9]+(?:[.'][a-z0-9]+)*` after Unicode
/// lowercase, followed optionally by Reader7's ASCII apostrophe-s split.
/// No Unicode casefold, accent folding, smart-quote replacement or NFC is used.
/// Rust's Unicode lowercase tables are versioned by the build toolchain.
pub fn normalize(text: &str, profile: Normalization) -> String {
    let lower: String = text.chars().flat_map(char::to_lowercase).collect();
    let bytes = lower.as_bytes();
    let mut words = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        if !bytes[i].is_ascii_alphanumeric() {
            i += 1;
            continue;
        }
        let start = i;
        i += 1;
        while i < bytes.len() {
            if bytes[i].is_ascii_alphanumeric() {
                i += 1;
            } else if (bytes[i] == b'.' || bytes[i] == b'\'')
                && i + 1 < bytes.len()
                && bytes[i + 1].is_ascii_alphanumeric()
            {
                i += 2;
            } else {
                break;
            }
        }
        let word = &lower[start..i]; // Both boundaries are ASCII bytes.
        if profile == Normalization::Reader7 && word.len() > 2 && word.ends_with("'s") {
            words.push(&word[..word.len() - 2]);
            words.push("'s");
        } else {
            words.push(word);
        }
    }
    words.join(" ")
}

struct Builder<'a> {
    db: &'a Connection,
    budget: &'a Budget,
    limits: &'a LexiconBuildLimits,
    entries: u64,
}
impl Builder<'_> {
    fn label(&mut self, raw: &str, kinds: &[LexicalKind], concept: bool) -> Result<()> {
        if raw.len() > self.limits.label_bytes {
            return Err(Error::Limit("lexical label bytes"));
        }
        self.budget.spend(raw.len() as u64 + 1)?;
        for profile in [Normalization::Reader4, Normalization::Reader7] {
            let surface = normalize(raw, profile);
            if surface.is_empty() {
                continue;
            }
            for kind in kinds {
                let changed = self
                    .db
                    .prepare_cached("INSERT OR IGNORE INTO oracle_lexicon VALUES (?1,?2,?3,?4,0)")?
                    .execute(params![profile.key(), surface, kind.key(), raw])?;
                self.entries += changed as u64;
                if self.entries > self.limits.entries {
                    return Err(Error::Limit("lexical entries"));
                }
            }
            if concept {
                let changed = self
                    .db
                    .prepare_cached(
                        "INSERT OR IGNORE INTO oracle_lexicon_concepts VALUES (?1,?2,?3)",
                    )?
                    .execute(params![profile.key(), surface, raw])?;
                self.entries += changed as u64;
                if self.entries > self.limits.entries {
                    return Err(Error::Limit("lexical entries"));
                }
            }
        }
        Ok(())
    }
    fn qualifiers(&mut self, record: &Value) -> Result<()> {
        if let Some(qualifiers) = record.get("qualifiers") {
            let qualifiers = qualifiers
                .as_object()
                .ok_or_else(|| Error::Invalid("lexical qualifiers".into()))?;
            for key in qualifiers.keys() {
                self.label(key, &[LexicalKind::A], false)?;
            }
        }
        Ok(())
    }
}
fn array<'a>(record: &'a Value, field: &str) -> Result<&'a [Value]> {
    match record.get(field) {
        None | Some(Value::Null) => Ok(&[]),
        Some(Value::Array(values)) => Ok(values),
        _ => Err(Error::Invalid(format!("lexical list {field}"))),
    }
}
fn string<'a>(record: &'a Value, field: &str) -> Result<&'a str> {
    record
        .get(field)
        .and_then(Value::as_str)
        .ok_or_else(|| Error::Invalid(format!("lexical string {field}")))
}

/// Offline only, inside the caller's image transaction after nodes are inserted.
/// `nodes` and `metadata` are the image tables. Reads one bounded record at a
/// time; source order cannot select a spelling. Every distinct typed spelling
/// survives normalization collisions. Does not read aliases from source records:
/// learned aliases must be admitted separately using `install_aliases`.
/// An error requires rolling back the caller's transaction, never publication.
pub fn build_from_nodes(
    db: &Connection,
    budget: &Budget,
    limits: &LexiconBuildLimits,
) -> Result<u64> {
    if limits.record_bytes == 0 || limits.label_bytes == 0 || limits.entries == 0 {
        return Err(Error::Invalid("lexicon build limits".into()));
    }
    budget.check()?;
    db.execute_batch(SCHEMA)?;
    let mut builder = Builder {
        db,
        budget,
        limits,
        entries: 0,
    };
    let mut statement =
        db.prepare("SELECT kind,length(CAST(record AS BLOB)),record FROM nodes ORDER BY id")?;
    let mut rows = statement.query([])?;
    while let Some(row) = rows.next()? {
        budget.spend(1)?;
        let bytes: i64 = row.get(1)?;
        if bytes < 0 || bytes as u64 > limits.record_bytes as u64 {
            return Err(Error::Limit("lexical source record bytes"));
        }
        let kind: String = row.get(0)?;
        let encoded: String = row.get(2)?;
        budget.spend(encoded.len() as u64)?;
        let record: Value = serde_json::from_str(&encoded)?;
        // The original reader deliberately tries E and C for either name kind.
        builder.label(
            string(&record, "name")?,
            &[LexicalKind::E, LexicalKind::C],
            kind == "concept",
        )?;
        if kind != "entity" {
            continue;
        }
        for attribute in array(&record, "attributes")? {
            builder.label(string(attribute, "key")?, &[LexicalKind::A], false)?;
            builder.qualifiers(attribute)?;
            if let Some(value) = attribute.get("value") {
                if value.get("type").and_then(Value::as_str) == Some("string") {
                    builder.label(string(value, "value")?, &[LexicalKind::V], false)?;
                }
            }
        }
        for relation in array(&record, "relations")? {
            builder.label(string(relation, "predicate")?, &[LexicalKind::R], false)?;
            builder.qualifiers(relation)?;
        }
    }
    db.execute(
        "INSERT INTO metadata(key,value) VALUES ('lexicon_version',?1)",
        [VERSION],
    )?;
    Ok(builder.entries)
}

/// Release-time import, never per tenant. Canonical names are resolved through
/// typed source spellings; all collisions survive. Multiple aliases for the
/// same surface and kind stay ambiguous. Aliases override base readings of that
/// kind, matching Reader6/7 alias_canon behavior. Call inside image transaction.
pub fn install_aliases(
    db: &Connection,
    aliases: &[Alias],
    limits: &LexiconBuildLimits,
    budget: &Budget,
) -> Result<u64> {
    install_alias_rows(db, aliases.iter().cloned().map(Ok), None, limits, budget)
}

/// Stream the native grammar's admitted release aliases into the vocabulary.
/// The grammar schema must already be built in this same transaction. These
/// are already normalized cache rows, so their profile is read from grammar
/// provenance. They are not normalized a second time: `hall 's` is not
/// idempotent under the Python normalizer. Raw aliases use install_aliases.
pub fn install_grammar_aliases(
    db: &Connection,
    limits: &LexiconBuildLimits,
    budget: &Budget,
) -> Result<u64> {
    let profile = grammar_normalization(db)?;
    let mut statement = db
        .prepare("SELECT phrase,kind,canonical FROM reader_alias ORDER BY phrase,kind,canonical")?;
    let rows = statement.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    })?;
    let aliases = rows.map(|row| {
        let (surface, kind, canonical) = row?;
        Ok(Alias {
            surface,
            kind: LexicalKind::parse(&kind)?,
            canonical,
        })
    });
    install_alias_rows(db, aliases, Some(profile), limits, budget)
}

/// The grammar artifact binds normalization independently of candidate mode.
pub fn grammar_normalization(db: &Connection) -> Result<Normalization> {
    let encoded: String = db.query_row(
        "SELECT value FROM reader_meta WHERE key='provenance'",
        [],
        |r| r.get(0),
    )?;
    let provenance: Value = serde_json::from_str(&encoded)?;
    match provenance.get("normalization").and_then(Value::as_str) {
        Some("reader7_possessive") => Ok(Normalization::Reader7),
        Some("reader4") => Ok(Normalization::Reader4),
        _ => Err(Error::Format("grammar lexical normalization".into())),
    }
}

fn normalized_phrase(phrase: &str, profile: Normalization) -> bool {
    !phrase.is_empty()
        && phrase.split(' ').all(|word| {
            !word.is_empty()
                && ((profile == Normalization::Reader7 && word == "'s")
                    || normalize(word, Normalization::Reader4) == word)
        })
}

fn install_alias_rows(
    db: &Connection,
    aliases: impl Iterator<Item = Result<Alias>>,
    normalized_profile: Option<Normalization>,
    limits: &LexiconBuildLimits,
    budget: &Budget,
) -> Result<u64> {
    if limits.label_bytes == 0 || limits.entries == 0 {
        return Err(Error::Invalid("lexicon build limits".into()));
    }
    budget.check()?;
    let mut entries: u64 = db.query_row("SELECT (SELECT count(*) FROM oracle_lexicon)+(SELECT count(*) FROM oracle_lexicon_concepts)", [], |r| r.get(0))?;
    let before = entries;
    if entries > limits.entries {
        return Err(Error::Limit("lexical entries"));
    }
    for alias in aliases {
        let alias = alias?;
        if alias.surface.len() > limits.label_bytes || alias.canonical.len() > limits.label_bytes {
            return Err(Error::Limit("lexical label bytes"));
        }
        budget.spend(alias.surface.len() as u64 + alias.canonical.len() as u64 + 1)?;
        for profile in [Normalization::Reader4, Normalization::Reader7] {
            if normalized_profile.is_some_and(|p| p != profile) {
                continue;
            }
            let (surface, target) = if normalized_profile.is_some() {
                if !normalized_phrase(&alias.surface, profile)
                    || !normalized_phrase(&alias.canonical, profile)
                {
                    return Err(Error::Invalid(
                        "grammar alias must already be normalized".into(),
                    ));
                }
                (alias.surface.clone(), alias.canonical.clone())
            } else {
                (
                    normalize(&alias.surface, profile),
                    normalize(&alias.canonical, profile),
                )
            };
            if surface.is_empty() || target.is_empty() {
                return Err(Error::Invalid("empty normalized alias".into()));
            }
            let mut statement = db.prepare_cached("SELECT canonical FROM oracle_lexicon WHERE profile=?1 AND surface=?2 AND kind=?3 AND alias=0 ORDER BY canonical")?;
            let mut rows = statement.query(params![profile.key(), target, alias.kind.key()])?;
            let mut found = false;
            while let Some(row) = rows.next()? {
                budget.spend(1)?;
                let canonical: String = row.get(0)?;
                entries += db
                    .prepare_cached("INSERT OR IGNORE INTO oracle_lexicon VALUES (?1,?2,?3,?4,1)")?
                    .execute(params![profile.key(), surface, alias.kind.key(), canonical])?
                    as u64;
                if entries > limits.entries {
                    return Err(Error::Limit("lexical entries"));
                }
                found = true;
            }
            if !found {
                entries += db
                    .prepare_cached("INSERT OR IGNORE INTO oracle_lexicon VALUES (?1,?2,?3,?4,1)")?
                    .execute(params![
                        profile.key(),
                        surface,
                        alias.kind.key(),
                        if alias.kind == LexicalKind::N {
                            &target
                        } else {
                            &alias.canonical
                        }
                    ])? as u64;
                if entries > limits.entries {
                    return Err(Error::Limit("lexical entries"));
                }
            }
        }
    }
    Ok(entries - before)
}

/// Cheap open-time format check; release digest and image schema bind data.
pub fn validate(db: &Connection) -> Result<()> {
    let version: Option<String> = db
        .query_row(
            "SELECT value FROM metadata WHERE key='lexicon_version'",
            [],
            |r| r.get(0),
        )
        .optional()?;
    if version.as_deref() != Some(VERSION) {
        return Err(Error::Format("lexicon version".into()));
    }
    db.prepare("SELECT profile,surface,kind,canonical,alias FROM oracle_lexicon LIMIT 0")?;
    db.prepare("SELECT profile,surface,canonical FROM oracle_lexicon_concepts LIMIT 0")?;
    Ok(())
}

fn singulars(surface: &str) -> Vec<String> {
    let (head, word) = surface
        .rsplit_once(' ')
        .map_or(("", surface), |(h, w)| (h, w));
    let mut out = Vec::new();
    let mut add = |word: String| {
        out.push(if head.is_empty() {
            word
        } else {
            format!("{head} {word}")
        });
    };
    if word.ends_with("ies") && word.len() > 4 {
        add(format!("{}y", &word[..word.len() - 3]));
    }
    if word.ends_with("es") && word.len() > 3 {
        add(word[..word.len() - 2].into());
    }
    if word.ends_with('s') && !word.ends_with("ss") && word.len() > 2 {
        add(word[..word.len() - 1].into());
    }
    out
}
fn number(surface: &str) -> bool {
    surface.as_bytes().first().is_some_and(u8::is_ascii_digit)
        && surface.bytes().all(|b| b.is_ascii_digit() || b == b'.')
}
struct Scratch<'a> {
    limits: &'a LexiconLimits,
    budget: &'a Budget,
    rows: usize,
    bytes: usize,
}
impl Scratch<'_> {
    fn reading(
        &mut self,
        readings: &mut Vec<LexicalReading>,
        kind: LexicalKind,
        canonical: &str,
        via_alias: bool,
    ) -> Result<()> {
        self.budget.spend(canonical.len() as u64 + 1)?;
        self.rows = self
            .rows
            .checked_add(1)
            .ok_or(Error::Limit("lexical readings"))?;
        self.bytes = self
            .bytes
            .checked_add(canonical.len() + std::mem::size_of::<LexicalReading>())
            .ok_or(Error::Limit("lexical materialized bytes"))?;
        if self.rows > self.limits.readings {
            return Err(Error::Limit("lexical readings"));
        }
        if self.bytes > self.limits.materialized_bytes {
            return Err(Error::Limit("lexical materialized bytes"));
        }
        readings.push(LexicalReading {
            kind,
            canonical: canonical.into(),
            via_alias,
        });
        Ok(())
    }
}

/// All lexical spans in start/longest-first order, retaining overlaps and every
/// canonical ambiguity. No combinatorial span selection is done here. Unlike
/// Python's silent first-400 reading cap, bounds fail the entire request.
/// Reader7 plural aliases are query-local and cannot contaminate other tenants.
pub fn candidates(
    db: &Connection,
    raw: &str,
    options: &CandidateOptions,
    limits: &LexiconLimits,
    budget: &Budget,
) -> Result<CandidateSet> {
    budget.check()?;
    if options.max_words == 0 || options.max_words > limits.max_name_words {
        return Err(Error::Invalid("lexical max words".into()));
    }
    if raw.len() > limits.question_bytes {
        return Err(Error::Limit("lexical question bytes"));
    }
    budget.spend(raw.len() as u64 + 1)?;
    let normalized = normalize(raw, options.normalization);
    if normalized.len() > limits.question_bytes || normalized.len() > limits.materialized_bytes {
        return Err(Error::Limit("lexical normalized bytes"));
    }
    let mut words = Vec::new();
    let mut offset = 0;
    for word in normalized.split_whitespace() {
        if words.len() >= limits.question_tokens {
            return Err(Error::Limit("lexical question tokens"));
        }
        words.push((offset, offset + word.len()));
        offset += word.len() + 1;
    }
    let mut scratch = Scratch {
        limits,
        budget,
        rows: 0,
        bytes: normalized.len() + words.len() * std::mem::size_of::<(usize, usize)>(),
    };
    if scratch.bytes > limits.materialized_bytes {
        return Err(Error::Limit("lexical materialized bytes"));
    }
    let mut spans = Vec::new();
    let mut statement = db.prepare_cached("SELECT kind,canonical,alias,length(CAST(canonical AS BLOB)) FROM oracle_lexicon WHERE profile=?1 AND surface=?2 ORDER BY kind,alias DESC,canonical")?;
    let mut concepts = db.prepare_cached("SELECT canonical,length(CAST(canonical AS BLOB)) FROM oracle_lexicon_concepts WHERE profile=?1 AND surface=?2 ORDER BY canonical")?;
    for i in 0..words.len() {
        for j in (i + 1..=words.len().min(i.saturating_add(options.max_words))).rev() {
            budget.spend(1)?;
            let start = words[i].0;
            let end = words[j - 1].1;
            let surface = &normalized[start..end];
            let reader7 = options.compositional;
            let fw = reader7 && FUNC.split_whitespace().any(|w| w == surface);
            let mut readings = Vec::new();
            let mut aliases = BTreeSet::new();
            let mut names = false;
            let mut rows = statement.query(params![options.normalization.key(), surface])?;
            while let Some(row) = rows.next()? {
                budget.spend(1)?;
                let kind = LexicalKind::parse(&row.get::<_, String>(0)?)?;
                let alias: bool = row.get(2)?;
                let size: i64 = row.get(3)?;
                if size < 0 || size as u64 > limits.materialized_bytes as u64 {
                    return Err(Error::Limit("lexical canonical bytes"));
                }
                if matches!(kind, LexicalKind::E | LexicalKind::C) && !alias {
                    names = true;
                }
                if (matches!(kind, LexicalKind::A | LexicalKind::R) && !options.level2)
                    || (reader7 && options.outer && matches!(kind, LexicalKind::E | LexicalKind::C))
                    || (fw
                        && !alias
                        && matches!(kind, LexicalKind::E | LexicalKind::C | LexicalKind::V))
                {
                    continue;
                }
                if alias {
                    aliases.insert(kind);
                }
                if !alias && aliases.contains(&kind) {
                    continue;
                }
                let canonical: String = row.get(1)?;
                scratch.reading(&mut readings, kind, &canonical, alias)?;
            }
            if reader7 && options.plural && !options.outer && !fw && !names {
                for singular in singulars(surface) {
                    budget.spend(1)?;
                    let mut rows =
                        concepts.query(params![options.normalization.key(), singular])?;
                    let mut any = false;
                    while let Some(row) = rows.next()? {
                        let size: i64 = row.get(1)?;
                        if size < 0 || size as u64 > limits.materialized_bytes as u64 {
                            return Err(Error::Limit("lexical canonical bytes"));
                        }
                        let canonical: String = row.get(0)?;
                        // Reader7's inferred singular replaces an existing C
                        // alias for this phrase. Keep that precedence locally.
                        if !any {
                            readings.retain(|r| r.kind != LexicalKind::C);
                        }
                        scratch.reading(&mut readings, LexicalKind::C, &canonical, true)?;
                        any = true;
                    }
                    if any {
                        break;
                    } // Preserve Reader7's first matching singular rule.
                }
            }
            if j == i + 1 && number(surface) && !aliases.contains(&LexicalKind::N) {
                scratch.reading(&mut readings, LexicalKind::N, surface, false)?;
            }
            if !readings.is_empty() {
                if spans.len() >= limits.spans {
                    return Err(Error::Limit("lexical spans"));
                }
                scratch.bytes = scratch
                    .bytes
                    .checked_add(std::mem::size_of::<CandidateSpan>())
                    .ok_or(Error::Limit("lexical materialized bytes"))?;
                if scratch.bytes > limits.materialized_bytes {
                    return Err(Error::Limit("lexical materialized bytes"));
                }
                readings.sort_by(|a, b| {
                    (a.kind, &a.canonical, a.via_alias).cmp(&(b.kind, &b.canonical, b.via_alias))
                });
                spans.push(CandidateSpan {
                    start,
                    end,
                    readings,
                });
            }
        }
    }
    budget.check()?;
    Ok(CandidateSet { normalized, spans })
}
