# Graph and symbolic reasoning providers

Experimental Rust library, JSONL CLI and optional PyO3 feature for Oracle7.
Results have independent Rust checks; no Isabelle theorem or specialist-panel
completion is claimed. See the [integration program](../docs/INTEGRATIONS.md).

```sh
cargo run --locked --release -p oracle-reasoning -- --catalog
cargo run --locked --release -p oracle-reasoning
```

Send one JSON object per line:

```json
{"operation":"graph.minimum_spanning_forest","arguments":{"vertices":3,"edges":[[0,1,4],[1,2,-2],[0,2,9]]}}
{"operation":"algebra.optimize_polynomial","arguments":{"expression":"(+ (* x y) (* x z))"}}
{"operation":"algebra.optimize_dimensional_polynomial","arguments":{"expression":"(+ (* m a) (* m b))","variables":[{"name":"m","dimension":[0,1,0,0,0,0,0]},{"name":"a","dimension":[1,0,-2,0,0,0,0]},{"name":"b","dimension":[1,0,-2,0,0,0,0]}]}}
```

The graph is undirected. Vertex IDs are integers from zero through `vertices-1`;
edge IDs are positions in the input list. Loops are ignored by forest selection,
parallel edges remain distinct, isolated vertices count as components, and a
disconnected graph returns a forest rather than pretending to be a spanning tree.
Weights are exact i64 values and their sum is a decimal string. JSON clients
must preserve integers before transmission; JavaScript rounding cannot be undone.

The checker uses forest traversal and binary-lifted maximum path edges, separate
from petgraph's Kruskal candidate generator. It checks component coverage and
that no edge admits a cheaper cycle replacement. The checked-in contracts compare
it against exhaustive subsets, including deliberately bad candidates.

The polynomial domain is exact commutative arithmetic with integer coefficients:
i64 input literals, owned ASCII variable names and binary `+`, `-`, `*` in prefix
notation. The independent checker expands bounded sparse polynomials using
arbitrary-precision integers. Division, fractional exponents and floating-point
evaluation are outside this operation. The selected form has a declared tree
cost; a lower cost is not itself a measured numerical speedup.

Dimensional input supplies exactly one annotation per variable in order
`[length, mass, time, electric_current, temperature, amount, luminous_intensity]`.
Dimensions are exact bounded integer exponents. Values must already use coherent
linear SI quantities: scale conversion and affine temperatures happen elsewhere.
The original expression is checked before rewriting. Numerical zero can inhabit
a contextual dimension, while cancellation involving variables cannot conceal an
invalid original addition. If a valid rewrite loses dimensional admission, the
provider retains the original and explicitly reports the fallback.

`--catalog` reports the actual default resource limits. The Rust `Limits` value
is host-owned; JSON requests cannot raise it. Input, graph, polynomial degree,
coefficient and work bounds are explicit. Egg's iteration/node/time limits are
cooperative and can be exceeded within an iteration; parsing, extraction and
checking have separate costs. This is not a hard CPU/RSS sandbox or a hosted
tenant scheduler. Use globally bounded contained workers before exposing it to
untrusted service traffic.

Build the Python package with feature `reasoning` to expose
`oracle_native.reasoning_catalog()` and `reasoning_call(request_json)`.
These functions release the GIL. They do not register operations in the native
admitted runtime or automatically enable the Mini appliance.

`graph.shortest_path` answers an exact directed walk question:

```json
{"operation":"graph.shortest_path","arguments":{"vertices":3,"edges":[[0,1,4],[1,2,-2],[0,2,9]],"source":0,"target":2}}
```

The result is `finite`, `unreachable`, or `unbounded` below. A finite result
contains an attaining edge-ID path and feasible distance labels; unreachable
contains an outgoing-edge-closed set containing the source and excluding the
target; unbounded contains a source prefix, a closed negative cycle and a target
suffix. The independent Rust checker replays these certificates. A negative cycle
outside the source-to-target corridor does not spoil a finite answer. Source equal
to target admits the empty walk unless a relevant negative cycle makes weights
unbounded below. This concerns the complete supplied graph, not completeness of
real-world knowledge. The forest operation above remains undirected.

Distances and labels are decimal strings, using checked i128 arithmetic over i64
weights. Nonnegative corridors use an integer heap; signed corridors use bounded
Bellman-Ford. Vertex/edge ceilings come from the caller's `Limits`; `graph_work`
and `search_ms` cover validation, search, checking and serialization together.
`graph_reply_bytes` caps encoded certificates while they are being written,
without first building an unbounded JSON value. Its default is 256 KiB; appliance
request and reply envelope limits still apply. These settings are operator-owned,
not request arguments. The pure library also accepts cooperative cancellation;
the generic Python/HTTP interface does not expose a cancellation handle.

`native/tests/qualify_shortest_path.py --extension <built-library> --output <receipt>`
exercises the actual PyO3 feature and private NativeService/NativePool HTTP operation handler,
including all outcomes, irrelevant negative cycles and exact large totals.
Repeated pure calls recompute; request IDs provide correlation, not durable replay.
It is a component qualification, not a specialist-panel score or a full Engine
or Mini authentication test.

The [29 October graph/pure receipt](../evidence/2026-10-29-graph-pure-validation.json)
records 39 Rust checks (including seven shortest-path contracts with 6,561
independent Floyd-Warshall comparisons), warnings-denied Clippy and formatting,
27 adapter checks, and five actual PyO3/NativeService HTTP graph cases with two
invalid-binding refusals. HTTP qualification also passed the near-cap certificate:
248,837 compact bytes, versus 265,041 with default spacing. One resident worker
was reused, and changed arguments under the same request ID recomputed the result.
R3 repaired only the qualifier's HTTP import shadowing and reused the R2 release
artifact; it did not change native code. These are component results, with no HOL
proof or specialist-panel completion claim.
