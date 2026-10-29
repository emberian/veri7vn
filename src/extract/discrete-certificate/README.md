# External minimum spanning tree certificates

This consumer checks a tree supplied by another program. It never calls the
existing Kruskal candidate producer. A Rust, Python or other graph provider can
supply stable input-edge IDs without a proof of its own search algorithm.

The extracted predicate establishes a minimum spanning **tree** of a supplied
connected graph with at least two vertices. This version deliberately returns
`unsupported` for disconnected graphs, isolated vertices, empty graphs and
singletons. The native Rust provider still has its independent forest checker
for those cases. There is no extracted forest theorem in this interface.

## Build and run

Root owns the build slots. The reproducible managed proof build is:

```sh
python3 tools/dev/remote-build hbox src/extract/discrete-certificate Veri7vn_Discrete_Certificate \
  -d src/extract/discrete -d src/extract/commons \
  --expect 'VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0'
sh src/extract/discrete-certificate/build.sh
python3 -B src/extract/discrete-certificate/test_certificate.py
```

The new session inherits `Veri7vn_Discrete`, so it reuses that checked heap when
warm. A cold build also checks the existing discrete session. This avoids
copying proof definitions or leaving their source out of the build receipt.
The only new proof work is the explicit-vertex wrapper and its two consequences.
`remote-build` applies the project's queue, build limits and immutable receipt
controls. `build.sh` does not start Isabelle. It consumes the published export
through `native-compile`, which verifies that proof inputs and the export match
a passed managed receipt and holds the native compiler lock. The compiled
binary and full build evidence live under `var/discrete-certificate/`.

For a root-controlled local proof diagnostic, use the shared native lock:

```sh
python3 tools/dev/check-native --session Veri7vn_Discrete_Certificate \
  --session-root src/extract/discrete-certificate \
  --session-root src/extract/discrete --session-root src/extract/commons \
  --expect 'VERI7VN_DISCRETE_CERTIFICATE PASS theorems=4 oracles=0'
```

The compile recipe requires a managed remote receipt; it does not silently use
an older local session database. No builds or tests were run by the authoring
lane; root must record the actual results before claiming qualification.

```sh
printf '%s\n' '{"schema":"veri7vn-mst-certificate-request-v1","graph":{"vertices":3,"edges":[[0,1,4],[1,2,1],[0,2,7]]},"edge_ids":[0,1]}' |
  python3 -B src/extract/discrete-certificate/check.py
```

## Root consumer wire contract

One request and one response per JSON line. Blank lines are ignored. Optional
`id` is a string, integer or null. Graph vertices are precisely the integer
labels `0 .. vertices-1`; the adapter maps each injectively to its canonical
decimal string. It does not case-fold, merge or rename those labels. A provider
with other labels must retain its own reversible label-to-index mapping.

Request fields are exactly:

```json
{"schema":"veri7vn-mst-certificate-request-v1","id":"optional","graph":{"vertices":3,"edges":[[0,1,-9],[1,2,-3],[0,2,0]]},"edge_ids":[0,1]}
```

Each edge is an undirected triple `[u,v,weight]`. Its ID is its zero-based list
position. The adapter preserves list order, endpoint order, parallel edges,
identical edge rows, candidate ID order, self-loops in the graph and exact signed
64-bit integer weights. Candidate IDs must be in range and distinct; repeated
IDs and forged IDs are errors. The selected tree is projected from those exact
rows. The theorem compares lists of edge triples, so identical parallel rows
have the same mathematical edge value; their external occurrence IDs remain
available in the response. Either equal-weight parallel occurrence may pass.

Limits: at most 64 vertices, 256 input edges, `max(vertices-1,0)` candidate edges
and 65,536 bytes per line. These deliberately small limits bound the existing
extracted closure/counting checker; they are independent of larger Rust search
limits and make no performance claim. The wrapper supports `--timeout` in
`(0,60]` seconds, default 10. The host must provide memory/CPU containment and
keep the executable immutable during use. `--checker /absolute/path` selects a
compiled checker explicitly. The default is the repository's generated binary.

Every well-formed request produces a result with schema
`veri7vn-mst-certificate-result-v1`, status, graph sizes, component count,
`edge_ids`, exact decimal-string `total_weight`, and `input_sha256` binding the
canonical JSON of `{"graph":...,"edge_ids":...}` (sorted object keys, compact
separators, ASCII JSON). `total_weight` is merely the supplied candidate's sum
unless accepted. Reordered edge rows change their IDs and the binding.

- `accepted`: extracted `external_mst_cert` returned true. `evidence.kind` is
  `extracted_hol_connected_mst`, with predicate, session, two theorem names and
  the invoked binary's SHA-256. This adds the connected-tree evidence only.
- `rejected`: the supported graph's supplied candidate failed the extracted
  predicate. It does not establish that a minimum tree does not exist.
- `unsupported`: graph has fewer than two vertices or is disconnected. No
  extracted check ran and `evidence.kind` is `none`.
- `error`: malformed input, input bound, absent/broken checker or timeout.
  No theorem evidence. Malformed input may have no recoverable request ID.

The root consumer should retain the original Rust forest evidence, attach this
result separately, and add extracted evidence only for `accepted`. Never map
`unsupported` or `error` into success, or transfer the connected theorem to a
disconnected forest. Tie this process result to a managed binary build receipt
at deployment; a JSON field or hash by itself is not an attestation.

## What is proved and where trust remains

`external_mst_cert vs es t` means `vs` is distinct, has at least two vertices,
its set equals the edge-derived vertex set, and the existing `mst_cert es t`
passes. Its theorems state:

- `external_mst_cert vs es t ==> spans t es AND connects t vs`.
- `external_mst_cert vs es t ==> spans t' es ==> wt t <= wt t'`.

Here `spans t es` means every selected triple belongs to the supplied graph,
there is one fewer selected edge than graph vertices, and the selected edges
connect those vertices in either direction. `wt` sums exact rational weights.
These consequences use the existing `mst_cert_spans` and `mst_cert_minimal`
proofs; no theorem about the Rust producer or real-world network is assumed.
The export's final command scans all four theorem dependencies for oracles and
prints its marker only after direct generated-code smoke checks.

`check.py`, the SML framing adapter, JSON parsing, edge-ID projection, deployment
and compiler are outside the HOL proof. The SML adapter supplies the complete
explicit vertex list to the extracted predicate, so a missing isolated vertex
cannot silently inherit the edge-only theorem. The Python preclassification is
only a scope/error distinction and never establishes acceptance. The focused
integration tests bypass Python once to exercise that vertex-coverage check.

The internal SML protocol is one finite invocation: header
`mst-cert-v1 V E K`, then exactly E lines `u v signed_weight`, then exactly K
one-ID lines, then EOF. It returns exactly `accept\n`, `reject\n` or `invalid\n`.
This protocol is private to the JSON adapter; no candidate is reconstructed by
search. Negative weights become exact denominator-one rationals.

No new specialist panel numbers are available. This is a new checking consumer,
not a specialist answerer or a whole-head performance result.
