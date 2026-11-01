# Native typed predicates, 28 October 2026

No specialist panel numbers yet. This lane changes native structured data access;
it does not establish an Oracle or specialist score. It adds no theorem and
makes no Isabelle proof claim. The comparisons and execution rules below are
handwritten Rust contracts.

## Changed files and consumer

- `native/oracle-core/src/query.rs`: typed attribute and qualifier filters,
  separate attribute evidence, exact unique-value and verification projections,
  relation/qualifier queries, and value-based entity selection.
- `native/oracle-core/tests/predicate_contract.rs`: thirteen independent semantic
  tests. They cover numbers beyond binary floating-point precision, units,
  string comparison and SQL literals, date precision, source statement identity,
  mixed evidence, ambiguity, missing values, replay, scratch cleanup and invalid
  requests.
- This report.

The consumers are native `Image.query`, transactional `Runtime.execute`, their
Python bindings, and the native KQA program compiler. No row enters Python during
execution. Root owns the shared image index and worker scratch-table changes.

## Admitted requests

A `filter_attribute` node has `input`, `key`, and `predicate`. A
`filter_qualifier` node has the same shape and reads the evidence that selected
its input entities. A predicate has `literal` text, an optional `kind` (`string`,
`quantity`, `year`, `date`), and an optional `comparison` (default `=`; also `!=`,
`<`, `<=`, `>`, `>=`). An omitted kind interprets the literal like the source
value, needed by KQA's conditional attribute queries. Literals are cached per
encountered kind during bulk checking.

Quantities compare exact rationals, with identical case-sensitive unit labels.
Strings compare without case for equality and inequality; ordering is unknown.
A year filter explicitly compares calendar years, including a stored date's
year. A date filter preserves the distinction between a year and a day. A day
inside a requested whole year overlaps it and does not become an invented
January 1 or a verified equality. Unknown comparisons cannot yield a positive
filter match or a verification answer.

Added projections:

- `unique_attribute {key, condition?}`; condition has `key` and `predicate`.
- `attribute_qualifier {key, predicate, qualifier}`.
- `relation {target, direction?}`.
- `relation_qualifier {target, predicate, direction?, qualifier}`.
- `verify {source, predicate}` over one of the typed value projections.
- `select {key, order}` and `select_between {target, key, order}`, with order
  `smallest` or `largest`. Each between-operand must select exactly one entity.

Unique value projections return `status`, original typed `candidate`, exact
`display`, and all supporting `evidence`. Repeated equal typed values agree;
different or incomparable values return `ambiguous`, with all distinct values.
Verification returns `verified` with a Boolean `answer`, or preserves absence,
ambiguity or incomparability. It never turns an incompatible unit into `no`.
Relation queries examine all admitted edges, optionally in one explicit
direction, instead of preferring an arbitrary first edge. Selection requires
one agreed value for every participating entity, comparable units and precision,
and one strict winner; ties and missing or conflicting values refuse. The final
winner is checked against every candidate, so an intermediate precision overlap
does not hide a later value that can be proved greatest or smallest.

## Evidence and bounds

`Fact` continues to mean a relation statement. `AttributeFact` stores `subject`,
`key`, source `position`, `value_json`, and the original `qualifiers_json`.
Matching attribute statements and relation statements travel in separate CTEs
and separate private scratch tables. Qualifier filters retain the whole matching
statement and qualifier map. `and` and `or` retain each evidence kind only for
its associated selected entity. `filter_concept` clears evidence, as the shipped
KQA interpreter already does.

Attribute candidates use the indexed key and input selection, then native exact
checking. Other attribute projections use indexed subject/key probes. All SQL
literals are parameters; qualifier names are object keys, never SQL JSON paths.
Shared subplans materialize once across the entity, relation and attribute
streams, preserving the existing protection against exponential CTE expansion.
Native scans, copies and comparisons are charged to the existing row, byte,
fuel, deadline and cancellation budgets. Source/literal bytes and qualifier
parsing are charged as well. A bound failure returns an error; it never turns a
partial result into complete coverage. Worker cleanup owns all scratch tables,
including the new attribute table, before returning capacity.

## Compatibility and limits

The existing graph dialect and projection shapes remain supported. Existing
replies without attribute evidence omit the new `attributes` field; existing
stored selections deserialize it as empty. New attribute-evidence sessions are
an additive state extension: an old binary's strict decoder cannot read those
new sessions. Upgrade requires no existing-state rewrite; rollback after using
new evidence needs an explicit compatibility policy. The graph parser continues
to accept graph objects only; KQA programs use the separately declared program
dialect and retain their original request bytes for replay identity.

Coverage is complete relative to the admitted image and known true predicate
matches. It is not knowledge of the world. There is no implicit physical unit
conversion, arbitrary type coercion, default-first value, string ordering,
Python callback, source repair or truncation. Unknown or unsupported scalar
syntax is refused. Per-scalar exact-value limits currently use the bounded
`ValueLimits` defaults from the value module.

## Checks

`rustfmt --edition 2021` completed for both Rust files. `git diff --check` was
clean for the lane's paths. No build, test, panel or benchmark execution was run
by this lane: root centralized the scoped hbox checks. The thirteen tests are
written checks awaiting that result, not passing-test claims.
