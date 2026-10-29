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
