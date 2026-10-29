# Pull-based integer query experiment

Compiled, linted and its authored fixture and ten tests pass on macOS
([receipt](../../evidence/2026-10-29-experiments-execution.json)); not benchmarked, no panel numbers, not registered in the
service. This package is isolated from the native workspace, uses only std, and
changes no production path. `src/main.rs` and `tests/fixture.rs` assert
hand-traced expectations, not measurements.

The current query engine already pushes operations into SQLite and materializes
shared graph nodes. `query.rs::compile` counts consumers to avoid repeated DAG
expansion, and language mode deliberately evaluates every stage to preserve its
empty-intermediate guard. This experiment does not claim to invent either idea.
A concrete remaining cost is `evaluate_with_mode`: it fetches all output IDs,
facts and attributes into string-owning BTreeSets before projection, then clones
those collections into QueryResult. Count cannot currently avoid that reply and
selection contract. The language workspace additionally copies selected stages
to temp tables; it already caches parsed typed columns and string equality.

This alternative shares immutable sorted integer posting arrays and indexed
edge bags through Arc. Each request owns tiny independent cursors, fuel,
deadline, cancellation, and a cumulative scratch allowance. Intersection and
union pull rows with constant cursor storage. Count streams; uniqueness can
refute early after two distinct IDs, but Empty/One require exhaustion. Errors
never masquerade as exhaustion. A failed context remains failed. Source edge
statements preserve multiplicity and evidence IDs; entity outputs are sets.

Relation expansion streams source statements in subject order. Projecting their
objects destroys order, so the code makes that materialization explicit and
keeps witnesses separately. It uses cancellable insertion sort rather than
hiding an unbounded noninterruptible std sort. Its quadratic cost is a deliberate
bad scaling boundary: a real implementation needs destination-ordered indexes,
a bounded sort/merge implementation, or a bitmap plus evidence sidecar.
Materialized sets provide explicit independent cursors for DAG reuse. Scan
partitioning shares the image, and ordered disjoint fan-in has no result buffer;
there are no tenant pools, actual worker threads or scheduler here.

Hand traces (now asserted by `tests/fixture.rs`; see the [receipt](../../evidence/2026-10-29-experiments-execution.json)):

- `{1,2,4,9} ∩ {2,3,4}` advances 1, matches 2, advances 3, matches 4: `{2,4}`.
- Their union is `{1,2,3,4,9}`; equal heads advance both exactly once.
- Edges `2→9[s0],2→9[s1],4→3[s2]` give three witnesses and objects `{3,9}`.
- Boundaries 2,4,8 split the first posting into `{1}`, `{2}`, `{4}`, `{9}`.
  Empty partitions are legal; concatenation validates ascending disjoint output.
- Empty input yields count 0 relative to the supplied image. Cancellation on
  even an empty scan returns Cancelled. Fuel exhaustion cannot mint a count.

Likely useful speedups are fewer string copies and temp-table inserts, shared
indexes across workers, and avoiding output/evidence materialization when the
consumer only needs a scalar. These are architectural hypotheses, not timings.
Sorted arrays are attractive for sparse postings and shared mmap layouts; dense
sets invite roaring or bitsets, but a bitmap does not retain evidence bags.
No roaring/fst dependency or mmap format is introduced here. Globally interning
IDs needs stable release dictionaries and an image-versioned cache key.

Scope checks now bind every cursor and derived result to one constructed image
through a private Arc identity. Merge, relation lookup and partition fan-in reject
mixed scopes before pulling, even when two separately built images have the same
numeric release label. Materialization and scalar reducers inherit scope from
their source; callers supply no final release stamp. SetPull is sealed so external
code cannot manufacture an incorrectly scoped stream. Empty fan-in without any
image scope is refused; an empty image scan represents a scoped empty result.
The fixture asserts mixed-image intersection, union, join and fan-in refusals;
they pass on macOS ([receipt](../../evidence/2026-10-29-experiments-execution.json)).

This identity establishes compatibility within the prototype, not authenticity,
source provenance, release admission or real-world completeness. Separately
opened copies of the same data conservatively do not combine; an eventual image
registry would need to admit and share one scope. Completeness remains relative
to the authored image and implemented plan, not a proof token.
Constructors are authored/offline, not admission-bounded import paths. Scratch
metering covers logical backing-array allocation conservatively, not allocator
metadata, Arc headers, stack or BTreeMap/image overhead. Allocation can still
abort on host OOM. Posting partition search uses std binary search; image index
lookup uses BTreeMap. Neither has per-comparison cancellation. Request fuel is
shared sequentially; parallel workers need a shared atomic allowance or fixed
sub-budgets, plus a host cancellation/fairness policy. The fan-in API is ready
for partition results, but does not execute in parallel. Source coverage,
qualifier propagation, typed literals, reverse edges, overlays, and production
language guards are not implemented. There are no theorem statements here.

Do not integrate as a replacement executor. The useful seam is an optional
integer-ID image adapter and scalar-only query output mode, retaining the
existing executor as reference. Language admission must still visit dead stages
and refuse empty intermediates except Count; a pull-only live-root compiler
would silently change that contract. Evidence/Selection needed for Previous
must be requested explicitly, and relation qualifiers need witness-preserving
operators before use. Repeated consumers should materialize once rather than
clone/recompute pipelines; blind streaming loses DAG reuse.

Next decisive experiment: after review, add a narrow
adapter for Find/And/Or/Relate/Count over the same admitted image. Compare with
SQLite on independently checked empty, overlapping, fanout and shared-DAG plans,
including duplicate edge statements. Measure allocations, scanned rows, temp
writes and latency separately for scalar-only output and full evidence output.
Keep image-build cost and shared-index resident memory in the comparison. If
Count only wins by omitting required previous-selection state, reject that win.
