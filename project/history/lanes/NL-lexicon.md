# Native lexical resource, 2026-10-28

Owner: Codex Sol lexicon lane. Consumer: root's native language entry point and
`native/oracle-core/src/grammar.rs`. There are **no specialist-panel numbers**
yet. This component is an untrusted recognizer, with no theorem or proof claims.

Changed files:

- `native/oracle-core/src/image.rs`
- `native/oracle-core/src/lexicon.rs`
- `native/oracle-core/tests/lexicon_contract.rs`
- `project/lanes/NL-lexicon.md`

The module builds the vocabulary once while manufacturing a release. It reads
one bounded `nodes.record` JSON record at a time and collects entity/concept
names, string attribute values, attribute keys, relation names, and qualifier
keys. It never loads a Python knowledge graph. Its two `WITHOUT ROWID` tables
are `oracle_lexicon(profile,surface,kind,canonical,alias)` and
`oracle_lexicon_concepts(profile,surface,canonical)`, each indexed by profile and
normalized surface. Distinct typed source spellings remain separate rows.
Metadata key `lexicon_version` binds `oracle-lexicon-v1`.

A query checks bounded phrases against that index. With T question tokens and
W admitted name words, it performs at most T*W exact vocabulary probes and up
to three concept probes for each eligible plural phrase. It copies only the
question, offsets and bounded lexical results. It preserves all overlapping
spans, starts with the longest span at each position, and does not enumerate
combinations. The grammar consumer decides how to combine spans. A tenant
acquires no vocabulary, learned aliases, corpus copy or mutable plural cache.
All tenants use the same release data and existing fixed image worker pool.

## Image interface and remaining root hooks

The image implementation now contains the integration. `build_image(source,
output,max_source_bytes,max_record_bytes)` still produces v2, with its original
serialized receipt shape. V2 images open successfully with absent lexical and
reader capabilities. They can use structured plans and complete program queries;
no metadata claims they have a language vocabulary or learned grammar.

The new API is:

```rust
pub fn build_image_with_reader(
    source: &Path,
    output: &Path,
    max_source_bytes: u64,
    max_record_bytes: usize,
    options: ReaderBuildOptions<'_>,
) -> Result<BuildReceipt>;

pub struct ReaderBuildOptions<'a> {
    pub reader: Option<&'a ReaderExport>,
    pub lexical: LexiconBuildLimits,
    pub grammar_rows: usize,
    pub grammar_bytes: usize,
    pub fuel: u64,
    pub timeout_ms: u64,
}

pub struct ImageCapabilities {
    pub version: u32,
    pub lexicon: Option<String>,
    pub reader: Option<String>,
}

pub fn Image::query_program(
    &self, tenant: &str, program_json: &str, cancellation: Cancellation,
) -> Result<String>;
```

`ReaderBuildOptions::default()` builds vocabulary without grammar. Defaults:
16 MiB source record, 64 KiB label, 20 million lexical rows, 5 million grammar
rows, 1 GiB grammar export, 100 billion fuel and a one-hour cooperative deadline.
The lexical record bound is clamped to the image builder's admitted record bound.
Build-time memory still includes the existing builder's complete JSON source;
these resources replace repeated serving-time construction, not that offline
source parser. SQLite progress checks and native lexical loops use the same
manufacturing budget. Source parsing, filesystem operations and SQL preparation
remain cooperatively bounded, not forcibly interruptible.

V3 builds vocabulary, optionally installs a `ReaderExport`, and then streams
`reader_alias(phrase,kind,canonical)` into the vocabulary inside the same image
transaction. Normalization comes from `reader_meta` provenance; already normalized
aliases are never normalized again. Numeric aliases are preserved directly.
Missing or unknown profiles fail before publication. Every grammar export,
including fixtures, must bind `metadata.kb_sha256` to the exact admitted source
digest. Missing hashes and supplied mismatches are always rejected. Fixtures
in image tests compute that binding from their actual small source file. Metadata
`image_capabilities` declares subformat version 1 with
`lexicon:"oracle-lexicon-v1"` and optional
`reader:"oracle-reader-tables-v1"`. `Image::open` validates these declarations,
lexical metadata/tables, grammar metadata/tables, and normalization for each
worker. Unsupported versions and missing declared resources are rejected at open. The
existing trusted image digest binds every installed table and metadata row.

`Image::query_program` validates host identity and creates one request Budget
before parsing. It parses/compiles the closed Program, leases an existing worker,
evaluates with empty Previous, and encodes its result under that same Budget.
It touches no conversation, journal, callback or external effect. Internal
`Lease<'_>` now borrows `&Image`; existing Arc callers continue to work and a
scoped lease cannot outlive its image. Attribute index and private attribute
scratch changes made by the evaluator lane were preserved.

Root still exports `build_image_with_reader`, `ReaderBuildOptions` and
`ImageCapabilities` from `lib.rs` and exposes chosen APIs in the Python binding.
No new dependencies are required. The grammar lane owns `reader.rs`, which
consumes `Image.capabilities.reader` before using shared learned resources.

The lower-level lexical query remains
`lexicon::candidates(&db, raw, &CandidateOptions, &LexiconLimits, &budget)`. It
returns `CandidateSet { normalized, spans }`. Each span has start/end byte
offsets into normalized ASCII and typed canonical readings. Convert a reading
to the grammar's `GrammarSpan { start, end, kind: reading.kind.code(), canonical }`.
Pass normalized text directly, without normalizing twice. Set normalization
using `grammar_normalization(&db)`. Whole-question matching uses
`compositional:false` (default); Reader7 fragment/outer matching uses true.
Possessive normalization alone never enables inferred plurals or function-word
suppression in the original whole reader.

Root's language entry point must clamp lexical bounds to admitted runtime
Limits. Defaults: 64 KiB question, 1,024 tokens, maximum allowed name span 32
words (query default 8), 8,192 spans, 16,384 readings and 2 MiB copied data.
These are copied-payload bounds, not allocator or process RSS limits. Keep the
worker's SQLite progress hook installed. Reader7's unreadable-writing veto
belongs on raw input before normalization; the grammar lane supplies
`unreadable(raw)`. A check on the resulting ASCII string cannot detect erased
writing.

## Source behavior retained and deliberate differences

Reader4 lowercases Unicode first, then extracts only ASCII matches of
`[a-z0-9]+(?:[.'][a-z0-9]+)*`. No accent folding, NFC, smart quote conversion,
Unicode word recognition or casefold is added. Turkish dotted I can become
`i` followed by a separator, Kelvin sign becomes `k`, accented letters can
vanish, minus signs vanish, and `1.2.3` is still lexically a number. These are
source behaviors, not validation of numbers. Rust Unicode lowercase tables come
from the pinned Rust toolchain; exhaustive equivalence against the pinned
Python Unicode database has not been established.

Reader7 optionally splits ASCII possessive `'s`. Independently, its
compositional `found` rules suppress bare function-word names and values,
gate entity/concept candidates for outer composition, gate
keys/relations at level 2, and tries the original ordered plural rules only
against actual concept names. Either known entity or known concept name still
offers both E and C, as the source does. Inferred singular C aliases override
an existing C alias locally, as Reader7 does, without its cross-query mutation.
`hall's` normalizes to `hall 's`; normalizing that result again yields `hall s`.
The normalized alias import and grammar handoff account for this trap.

The Python spelling dictionary picks the first source spelling globally, even
across literal kinds. Native results retain all distinct typed spellings and
all supplied alias targets instead; an ambiguity is exposed to the grammar,
never silently selected by map iteration or source order. Alias kind ordering
is deterministic E/C/V/A/R/N rather than Python set order. Ordinary alias
canonical replacement remains per kind. Exhausting any request limit fails
instead of hiding ambiguity through the source's first-400 combinations cap.

This lane does not implement Clause101's date wrapper (whole normalized
YYYY MM DD spans mapped back to YYYY-MM-DD), parser fragments, template learning,
language-reading agreement or release policy admission. It does not claim to replace the full reader.
The grammar/compiler and runtime consumers must finish those connections.

## Evidence and remaining work

Checks performed: `rustfmt --edition 2021` on the three Rust files and
`git diff --check` on lane files, both exit status 0.
No builds, tests, corpus runs, specialist panels, commits or pushes were run by
this lane, as root instructed. There are seventeen written contract tests covering
Unicode/possessive normalization, overlap and offsets, spelling collisions,
alias overrides and ambiguity including numeric aliases, normalization-profile
selection, normalized grammar alias import, lexical kinds
and qualifiers, local plural behavior and function words, bounded failures and
cancellation, primary-key query plans, and release transaction rollback.
The added image contracts cover v2 compatibility, pure program querying,
v3 vocabulary/grammar capabilities and alias import, malformed declarations,
source digest bindings, and failed manufacturing without publication. Root should run the scoped
`lexicon_contract` target after exporting the image API, then composition tests
with grammar and the real pinned corpus before reporting reader compatibility
or performance numbers. No theorem statements were added.
