# Native runtime for shared Oracle hosting

Owner: root. Ember authorized a Rust serving runtime with PyO3 and Sol deputies,
with shared resources and less work by construction. The destination is the
complete appliance, not a parallel query demo. See the [architecture](../../docs/design/shared-oracle-runtime.md)
and [source-grounded migration map](../../native/docs/MIGRATION.md).

## Current implementation

`native/` is a standalone Rust workspace and Python package. One immutable image
supplies fixed worker capacity to cheap tenant handles. It contains the KQA
records, exact source values, typed memberships, relations, qualifiers, lexical
indexes and optional learned tables. Whole programs compile to native graphs.
Shared subplans retain sharing in bounded scratch rather than expanding during
SQL preparation. Language execution materializes each entity stage once.

The current callable paths are graph queries, all pinned KQA program operations,
whole-template language questions and quantity/acoustics resident transport.
The whole reader checks successful answer forms and agreement among alternatives;
it explicitly reports its coverage. Python does not execute individual native
program steps or load learned table objects per tenant. Offline learning still
uses pinned Python source and emits versioned inert data bound to the source KB.

Native selections and exact replies commit together. Session schema 2 preserves
statement evidence and distinguishes absent Oracle dialogue from an imported
snapshot. An upgrade from schema 1 never invents that dialogue. Pure selection
updates preserve imported pending interpretations and context. The release-bound
constructor checks actual image and resource limits, requires supported schemas,
gates native entrypoints and binds both replay and session state to the release.
The Python factory only admits the implemented pure-query registry.

Rust hosts can propose authorized effect intents alongside a query. State,
reply and intents commit atomically. Claim, renewal, settlement, recovery and
reconciliation use fenced durable transactions; no external action runs inside
the query. Every existing effect also checks its origin's release. Uncertain
non-idempotent work requires reconciliation, not automatic retry. Real effect
executors are still outstanding.

The kernel executor preserves the existing extracted SML implementations. It
copies and hashes an operator-admitted executable, uses fixed resident process
capacity, bounds JSONL work and owns cancellation through process-group cleanup
and joined I/O. It does not establish a theorem, replace dispatcher acceptance,
or add support for stateful family protocols. General route-group arbitration
is implemented and contract-tested, but its W574 consumer is still outstanding.

## Evidence and correctness boundaries

The earlier [288-case relation/concept comparison](../../native/evidence/2026-10-28-linux.json)
and [foundation validation](../../native/evidence/2026-10-28-validation.json)
remain historical evidence for the first source/wheel. The [0.2 serving validation](../../native/evidence/2026-10-28-serving-validation.json)
records 185 passing Rust checks, 17 Python checks and warnings-denied Clippy.
The [233-program sample](../../native/evidence/2026-10-28-programs.json) has
225 correct, zero wrong and eight withheld; it exercises all pinned operations.
The [40-question whole-reader sample](../../native/evidence/2026-10-28-reader.json)
has 17 correct, zero wrong, 23 unknown and zero operational errors. Indexed
prefix search replaced exhaustive span subsets: the same sample previously had
25 combination-limit errors. No limit was raised or alternative hidden.

The whole-reader sample uses about 33.2 MiB PSS after querying. Creating 256
handles adds 12 KiB and no threads; median/p95 query time is 2.4/23.4 ms. These
are bounded warm-cache observations, not full-language or service-load results.
The wheel is built for hbox Linux, not yet the appliance's portable target.

The real source has 16,960 entities, 794 concepts and 435,900 indexed directed
relations after mirroring. Its SHA256 is
`04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c`.
The trained export contains 248,061 template rows and 49,474 shape rows; exporting
fragment/outer/segment rows does not imply that their search algorithms run.

The bounded gold program check exercises every pinned operation. A source audit
found valid years billions of years before the present; the native representation
now covers checked i64 years instead of an arbitrary small calendar range.
Unit comparison is explicit: unrelated labels do not become a false answer.
For example, source gold labels “25 minutes != 2300 seconds” false despite the
physical conversion. Native default comparison withholds without an explicit
conversion policy. Year precision does not become an invented January 1 date.

There are **no new specialist-panel scores or theorem statements** in this
handwritten Rust batch. Independent cases, crash/retry contracts and bounded
real-data questions are useful engineering evidence, not formal certification.

## Remaining work toward the complete appliance

1. **Compositional language.** Port fragment-region search, outer/segment/nested
   assembly, analogy and clause/date wrappers through the same resource and
   execution interfaces. Qualify actual question coverage, including refusals.
2. **Other knowledge and specialist surfaces.** Connect the relation/document
   stores and live Cube/TriTree/obligation readers; the KQA image is not their
   replacement. Complete route ordering, guard and arbitration consumers.
   Extend extracted-family transport only after auditing each protocol/state.
3. **Full dialogue and tools.** Implement the source-grounded Oracle state
   exporters/importers and actual authorized teaching/growth/document/ledger
   executors. The envelope/outbox interfaces alone do not migrate these features.
4. **Serving efficiency.** Profile full reader execution, typed scans, reply
   evidence and resident-kernel scheduling on realistic mixed workloads. Keep
   indexes and learned resources release-owned, search output-sensitive, and
   per-turn state bounded. Avoid tenant copies and per-operation Python calls.
5. **Mini hosting.** Build the wheel against the pinned appliance Linux base,
   package a new declared/signed composition, bind authenticated Mini principals,
   and finish the agent/browser/restart journey. Fair scheduling, process limits
   and complete mixed-tenant qualification remain. Signed v7 still uses Python.
6. **Python boundaries and upstream.** Retain exact CPython plugin compatibility,
   SymPy and other library adapters where necessary until deliberate native
   replacements cover their contracts. Python is useful for offline learning,
   evaluation and research. Propose the shared-resource/batch interfaces upstream
   with evidence; local changes are not an upstream merge.

Central checks use existing hbox `/tank/lanes/o7-native-20261028`, two Cargo jobs,
a dedicated target and scoped contracts. No retired Mini host was recreated.
Source/runtime artifacts are separate from corpora, images, wheels and stores;
these transient artifacts remain outside Git.
