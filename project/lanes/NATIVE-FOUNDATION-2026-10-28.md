# Native foundation for shared Oracle hosting

Owner: root. Ember authorized building the Rust foundation with PyO3 for a
production service, rather than adding isolated fast paths. This continues the
[architecture proposal](../../docs/design/shared-oracle-runtime.md).

## Implemented checkpoint

`native/` contains a standalone Rust workspace and PyO3 package. Immutable images
contain indexed KQA records, typed memberships, relations and qualifiers. A
single Image supplies a fixed worker pool to cheap tenant handles. Query graphs
compile as a whole; shared subplans retain sharing through explicitly metered
scratch. Session selections and byte-exact retry results commit together.
Cancellation keeps ownership of work until it stops and its scratch is cleared.

The consumer is the Python appliance host and, next, upstream reader execution.
It is currently callable as a library; signed v7 and Mini's HTTP bridge still
use the existing Engine adapter. No broad capability substitution happened.

The real 10.1 KQA input has SHA256
`04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c`,
16,960 entities and 794 concepts. The admitted native image has 435,900 indexed
directed edges, including reverse edges and distinct qualifier sets. The
[receipt](../../native/evidence/2026-10-28-linux.json) reports 288/288 matching
relation/concept cases and fixed-capacity creation of 256 tenant sessions.
There are **no new specialist-panel numbers and no new theorem statements**.

The native contract checks cover qualifier preservation, cycles, ambiguous
names, exact source decimals, byte-bound retry identity, cancellation, storage
limits, concurrent version checks and set algebra across shared query graphs.
Binding checks exercise actual PyO3 concurrency and killing an owned process
with an uncertain turn, followed by exact replay and continued state versions.
These tests are not a formal isolation or crash-consistency proof.

Final installed-wheel check: 14 Rust contract tests and six Python checks passed;
Clippy passed with warnings denied. The installed wheel also passed all 288
real-data comparisons. [Validation metadata](../../native/evidence/2026-10-28-validation.json)
binds the checked source and wheel. The wheel is a Linux host build, not yet a
portable appliance release. The local artifact is under ignored
`var/native-foundation-20261028/`.

## Remaining work toward the complete appliance

1. **Reader construction and learned tables.** Move release-derived vocabulary,
   aliases, operators and learned grammar tables into the image build. Upstream
   Reader4 currently scans `kq.ents.values()` repeatedly; simply replacing that
   object with a lazy dictionary would retain repeated work and per-edge calls.
   Introduce explicit release resources and a batch program-execution interface.
2. **Full operation semantics.** Add typed attribute/qualifier predicates,
   precision-aware dates and numeric operations, and the remaining program
   operations. Keep ambiguity, coverage and unit compatibility explicit. Connect
   existing Isabelle-extracted kernels through the same request/state contract;
   do not casually replace their verified implementation with handwritten Rust.
3. **Complete conversational state.** This checkpoint persists native selections
   and their relation facts. It does not export/import the full Oracle dialogue,
   transitions, mood, previous physics inputs, private corpus and lesson state.
   Those must be explicit before workers can safely share the full runtime.
4. **Controlled effects.** Add durable effect intents and recovery for teaching,
   growth, places, packets, sensors, ledgers and external tools. Pure-query retry
   semantics cannot be extended to these by wrapping a Python callback.
5. **Hosting and release.** Build the wheel against the appliance's pinned Linux
   base, include it in a new declared/signed composition, bind Mini identities to
   scoped handles, and finish the real agent/browser/restart journey. Qualify
   mixed concurrent tenants, hard resource containment, shutdown and recovery.
6. **Upstream integration.** Propose the resource-injection/build/serve and batch
   execution seams with evidence. The local Rust implementation is not an
   upstream merge or a reason to drop capabilities that remain in Python.

Build and qualification work used the existing hbox under
`/tank/lanes/o7-native-20261028`, two Cargo jobs, with a dedicated target and
source directory. No retired Mini build host was recreated. Generated images,
dependencies and transient state stay outside Git. The architecture is broader
than this first executable slice; the entries above remain actual project work.
