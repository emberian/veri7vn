# Demand-maintained views: exploration only

Status: **uncompiled, unexecuted, unmeasured**. No specialist panel numbers.
No theorem statements or verification claims. This separate, dependency-free
workspace changes no production provider. Its authored scenario is an example
program, not a passing test receipt.

## What is actually retained

One immutable `Arc<Public>` per host-admitted release contains identified source
supports, distinct edges and forward/reverse adjacency. Every tenant actor shares
that object, keeps only its own additive source supports and adjacency, and caches
only requested `(root, direction)` views. No public graph or operator graph is
copied per tenant; no all-pairs closure is constructed. Traversal reads the two
adjacency rows at each visited node rather than materializing their graph union.
Private IDs live in a separate namespace and cannot remove public supports.

`Tenant::apply` accepts a replayable, expected-version delta, stages a private
copy, finds **net distinct edge changes**, maintains retained demands and publishes
only after completion and a final cancellation check. Duplicate support removal
changes no distinct edge until its last private support disappears, and even that
has no effect if the public graph independently supplies the edge. Failed
updates leave both version and views untouched. Retrying the same failed delta
is possible; successful deltas cannot be applied twice because expected-version
checking rejects them. No replay log or crash durability is implemented.

Pure insertions expand from destinations of changed edges whose source was
already reachable (or was the demand root), then visit only newly reached nodes.
A newly reached node's adjacency includes all staged edges, so atomic chains
of additions work even when their order is reversed. Unaffected demands keep the
same result Arc; duplicate support changes avoid any traversal.

Deletion of an edge with a formerly reachable source **recomputes that demanded
root from extensional edges**. This is scoped invalidation/rederivation, not an
incremental deletion algorithm, dominator repair or differential fixed point.
The conservative source test may recompute after removing a redundant edge.
It deliberately does not use path reference counts: a disconnected directed
cycle cannot keep itself alive through circular derived support. If a removed
edge's source was unreachable, removing it cannot affect that view. Mixed
insert/delete transactions with an affected removal take the fresh path.

Cache identity includes the whole host release identity, host tenant namespace,
and the typed demand (root plus direction). Version is attached to every result;
the actor's retained views are current only after the whole transition settles.
Old snapshots stay immutable through Arc ownership. Consumers must compare the
full `(key, version)` for answer reuse. A release change creates a new shared
public index and tenant actor; public-support updates within one release and
cross-release private-overlay migration are not implemented. The constructor's
strings are not authentication or a cryptographic binding.

Idle eviction removes demand memoization without losing authoritative private
facts. A hard view count evicts the least recently touched demand on a cache miss;
node-per-view and live private-support bounds refuse excess state. Empty private
adjacency rows are removed on last-support withdrawal. Caller-held historical
snapshots are outside cache bounds. There is no global tenant registry limit,
byte-accurate memory admission, public-index input admission, hard CPU limit or
wire parser here. Cloning overlays and reached sets, map/set operations, mutation
batch allocation and cache eviction scans are not individually preemptible or
fully charged by the cooperative budget. The work allowance charges mutations,
changed-edge/view inspection and graph traversal, not every machine operation.

## Authored traces, hand-simulated

`examples/transitions.rs` describes these intended transitions; it was not run:

- Public `1→2`; tenant A adds two supports for `2→3` plus `3→2`.
  A's root-1 result becomes `{2,3}`; B's stays `{2}`. Remove the first
  `2→3` support: no edge change. Remove the last: rederive `{2}`.
- Add `2→20`, `20→21`, `21→20`. Root 1 gains `{20,21}`. Remove
  `2→20`: rederivation loses both even though their cycle edges remain.
- A two-insertion delta with allowance one stages its first source then refuses
  at the second charge. Published version remains 3; replay with a larger
  allowance is intended to settle version 4. A cancellation callback fires after
  the next staged retraction and before publication, retaining version 4.
- An old version-1 snapshot retains `{2,3}` after version 3 retraction. Idle
  eviction drops the memoized root; the next demand recomputes from actor state.

Self reachability is nonempty-path semantics: root is not pre-seeded as reached.
Both directions use the same algorithm with swapped adjacency and changed edges.
A production review should independently check upstream demands, root self-cycle
withdrawal, all insertion orders, mutations replacing a support within a delta,
zero/near-limit budgets and differential comparison against independent BFS.

## Adoption seam and decision

`oracle-incremental::rooted` currently admits roots before a finite batch and
creates/destroys its timely graph in each call. This experiment introduces a real
long-lived owner and dynamic demands rather than renaming that batch wrapper.
It retains reusable public adjacency and warm result sets across calls. It does
not reuse the existing differential engine or require its dependencies.

The runtime already uses host-selected tenants and `Runtime::identity()` chooses
an admitted whole-release identity when present. A possible adapter owns one
public Arc per that identity and a bounded registry of tenant actors, derives
deltas from committed tenant source transactions, and publishes/cache-reads only
under the runtime's snapshot/version contract. Actor mutation cannot precede a
SQLite transaction commit unless rollback/rebuild is guaranteed. The easiest
safe first adapter treats these views as disposable derived caches: when the
actor's version differs from durable state, rebuild/replay before returning an
answer. Namespace retirement must remove the corresponding actor. Do not expose
actor-selected scope strings as authorization. This seam is described, not wired.

My recommendation is to keep this as a candidate cache policy pending compilation,
independent semantic checks and measured workload fit. The prior 48-node all-pairs
experiment lost about 10× to fresh traversal. The later 4096-node rooted result
(about 90 versus 1109 ms) was one positive trial, not evidence that this distinct
algorithm wins. Public adjacency reuse and cheap unrelated/duplicate revisions
are plausible advantages; deletion-heavy or broad-root workloads still perform
fresh traversal and clone reached sets during insert expansion. Neither existing
measurement measures this implementation. No universal speedup or memory claim
follows from its shape.
