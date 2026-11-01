# NGC external graph certificate, 29 October 2026

Owner: Codex certificate lane. Consumer: the root lane's native reasoning
adapter, receiving the Rust provider's exact graph and selected input-edge IDs.

## Delivered

A separate `Veri7vn_Discrete_Certificate` export session, a small SML framing
adapter, strict JSONL/process adapter, managed native compile recipe, focused
integration tests and wire documentation under
`src/extract/discrete-certificate/`.

Unlike the existing English-question discrete answerer, this interface checks
the externally supplied candidate and does not call Kruskal. Providers need no
proof of their candidate search. An explicit vertex-list check prevents the
edge-derived original theorem from silently omitting declared vertices.

Changed files, all new:

- `src/extract/discrete-certificate/ROOT`
- `src/extract/discrete-certificate/Mst_Certificate_Export.thy`
- `src/extract/discrete-certificate/main.sml`
- `src/extract/discrete-certificate/check.py`
- `src/extract/discrete-certificate/build.sh`
- `src/extract/discrete-certificate/test_certificate.py`
- `src/extract/discrete-certificate/README.md`
- `project/lanes/NGC-certificate-2026-10-29.md`

No existing discrete files or native provider files were changed by this lane.
No commits were made.

## The theorem boundary

Existing `mst_cert_spans`: `mst_cert es t ==> spans t es`.

Existing `mst_cert_minimal`: assuming `mst_cert es t` and `spans t' es`,
`wt t <= wt t'`.

`spans` means selected triples belong to graph triples, the selected list has
one fewer edge than the edge-derived vertex count, and every graph vertex is
connected to every other through those selected undirected edges. `wt` sums
exact rational weights. The theorem does not quantify over an independently
supplied isolated-vertex universe or establish a disconnected forest result.

New wrapper definition:

```
external_mst_cert vs es t = (distinct vs AND 2 <= length vs
  AND set vs = set (node_list es) AND mst_cert es t)
```

New wrapper theorem statements (submitted source, awaiting root proof build):

```
external_mst_cert vs es t ==> spans t es AND connects t vs
external_mst_cert vs es t ==> spans t' es ==> wt t <= wt t'
```

They directly use the original two theorems. No proof shortcuts or axioms were
added. The final export-theory command scans those four theorem dependencies
for oracles, runs generated-code checks of a supplied valid tree, a nonminimal
tree and an omitted declared vertex, and prints the success marker last.

## Contract and scope

Root's JSONL request:

```json
{"schema":"veri7vn-mst-certificate-request-v1","graph":{"vertices":3,"edges":[[0,1,4],[1,2,1],[0,2,7]]},"edge_ids":[0,1]}
```

Optional `id`: string/integer/null. Results use schema
`veri7vn-mst-certificate-result-v1`; status is `accepted`, `rejected`,
`unsupported` or `error`. Only acceptance attaches
`evidence.kind=extracted_hol_connected_mst`. The result retains exact candidate
IDs, decimal-string weight, component count, canonical input hash and invoked
binary hash. The README defines the hash encoding and trust boundary.

The current supported shape is connected graphs on at least two explicitly
declared vertices. Disconnected graphs, isolated vertices, empty graphs and
singletons return `unsupported`; no global forest theorem is claimed. Native
Rust forest evidence remains separate. The wrapper must not turn unsupported
or process failure into extracted success.

Limits: 64 vertices, 256 edges, at most `vertices-1` candidate IDs, 65,536 bytes
per JSON line, default checker timeout 10 seconds (configurable through 60).
These are deliberate checker bounds, not the larger native provider bounds.
No performance qualification is claimed. Inputs retain signed i64 weights,
parallel/identical edges, stable occurrence IDs, endpoint order and candidate
order. Numeric vertices map injectively to canonical decimal strings. Other
label types require a provider-owned reversible map.

Python and SML adapters explicitly identify themselves as untrusted. Schema
checks, ID projection, framing, component classification, hashes and process
execution are outside HOL. Acceptance still comes only from the extracted
explicit-vertex predicate. The host must bind the binary to its managed build
receipt and provide executable immutability and process containment.

## Verification and exact remaining work

No build, test or remote execution was run, as root explicitly retained all
build/test slots. There is no green build claim and no specialist panel number.
Static reads confirmed the original theorem statements, generated SML's nested
edge-pair representation, existing `mk_rat` interface, session dependency pattern
and native compiler receipt requirements.

Root's next commands:

```sh
python3 tools/dev/remote-build hbox src/extract/discrete-certificate Veri7vn_Discrete_Certificate \
  -d src/extract/discrete -d src/extract/commons \
  --expect 'VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0'
sh src/extract/discrete-certificate/build.sh
python3 -B src/extract/discrete-certificate/test_certificate.py
```

The focused test file covers supplied valid/nonminimal trees, disconnected and
isolated graphs, empty/singleton shapes, forged/repeated IDs, negative weights,
parallel rows, exact i64 extremes and larger sums, cycles, self-loops, bad numeric
types, endpoint/bound violations, duplicate JSON keys and JSONL recovery. One
case bypasses Python to check explicit vertex coverage in the extracted binary.
Root must record actual build/test results and connect the process adapter to
the real native consumer. A wider forest theorem, improved checker scaling and
new specialist panels remain future work; they are not implicit consequences
of this interface.

## Root integration receipt

Root final validation: managed hbox Isabelle session passed the four-theorem, zero-oracle marker. Bundled MLton compiled its published export; all 13 actual-binary adapter tests passed. Three actual Rust candidates (negative/parallel/i64-boundary cases) were accepted; a disconnected forest was unsupported. See native/evidence/2026-10-29-extracted-mst.json. The build script now uses the existing bundled-MLton glob because find did not traverse the installation layout.
