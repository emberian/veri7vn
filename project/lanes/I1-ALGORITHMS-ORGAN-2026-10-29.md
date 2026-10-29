# I1: the first native specialist folder (algorithms-native) — 29 October 2026

Until now nothing in `native/` was reachable from a question asked through
`oracle7.py`. This lane wraps the two native graph operations
(`graph.shortest_path`, `graph.minimum_spanning_forest`) as an Oracle7
specialist folder, the same seam the extracted SML organs use, and scores it on
the shipped `algorithms` panel with the shipped scorer.

## What it does

`src/extract/graph-native/oracle7-organ/` is a drop-in folder for
`root/specialists/algorithms-native/`. Its organ reads a question that writes
out a weighted graph ("Edges: A-B 6, B-C 1, ..."), builds the exact native
request, calls `reasoning_call` in-process through the `oracle_native`
extension, checks that the reply fits the request, and words it the way the
shipped organ does, naming its rule.

- **Answers**: shortest path length and route ("The shortest path length is
  11, via D → C → B → A (Dijkstra on the stated graph, ...)"), "no path"
  between two named nodes, minimum spanning tree weight and its edges ("The
  minimum spanning tree weight is 11, using A-B 6, B-C 1, C-D 4 (Kruskal on the
  5 edges you gave, ...)"), and "not connected, so no spanning tree".
- **Declines in its domain** (only on a short direct question, Oracle7's
  `narrow_v1` rule): edges given but no start and end (`underspecified`), a
  start or end not in the edges (`no_node`), a negative weight in a
  shortest-path question (`negative`).
- **Leaves to the head** (returns nothing): sorting, binary search, complexity;
  no edge list at all (so "shortest path from London to Paris" and "Who was the
  father of Sjoukje Dijkstra?" go to the head); decimal weights (the native
  operations take integers); arrows in a spanning-tree question; extra
  conditions ("avoiding B", "at most", "if", "via", "longest", "how many");
  stated node or vertex lists (they could name isolated nodes); code-writing
  requests; story-shaped turns.
- **What is checked and by whom.** The Rust side computes and then checks its
  own certificate with separate code (path plus distance labels, or a reachable
  set closed under the edges; forest coverage and cycle optimality). The organ
  then checks transport only: the path walks the edges it sent and sums to the
  distance, the forest's edges exist and sum to the total. The question reader
  is hand-written Python, untrusted, and says so. Nothing here is proved in
  Isabelle.
- **Extension identity.** The organ loads `bin/oracle_native.so` beside itself,
  else `$VERI7VN_NATIVE_EXTENSION`, and refuses to start unless the file's
  SHA-256 equals `manifest.json` → `store.native_extension.sha256[<os>-<arch>]`.
  It does not place the module in `sys.modules`, so a host's own
  `oracle_native` import is untouched.

## Counts

Scorer: the shipped `algorithms_scorer.ok` (copied verbatim), criteria of
`upstream/workbench/exam.py`, through `tools/parity/harness.py`. Counts are
right / false yes / wrong; a must-decline item correctly left alone counts as
right. Each split has 42 items: 8 shortest path, 8 spanning tree, 24
sort/binary-search items, 2 must-decline items.

| Run | dev | held-out |
|---|---|---|
| algorithms-native alone (`--alone`) | 18 / 0 / 0 | 18 / 0 / 0 |
| algorithms-native in front of shipped head w363 (`--compose front --tip oracle_release_runtime_w363`) | 18 / 0 / 8 | 18 / 0 / 0 (ADMIT) |
| w363 head alone, same pass | 2 / 0 / 8 | 1 / 1 / 16 |
| shipped `algorithms` organ in front of w363 (`docs/parity/BOARD.md`, full board) | - | 42 / 0 / 0 (ADMIT) |

- **Kinds the organ answered**, per split: 8 `shortest_path`, 8 `mst`, 1
  `underspecified` decline. 16 of the 42 items are graph items it can answer;
  it answered all 16 right. It left the other 26 alone: 24
  sort/binary-search items and the binary-search must-decline.
- **Zero wrong by the organ.** All 8 wrong answers in the composed dev run are
  the w363 head's, on "Sort these numbers in ascending order: ..." items the organ
  left alone. The head answered each with a dictionary sense of "order" (path
  `arb:explain_simply->capability:explain_simply`). Example: "Sort these
  numbers in ascending order: 29, -14, 59, 23, 36", expected `[-14, 23, 29, 36,
  59]`, reply "[ev:direct] In simple terms: May mean lawfulness, but more often
  means class structure. ...". The full list with both texts is in the
  evidence file. On held-out, the head's 16 wrong answers were all on graph
  items, which the organ now takes, so the composed run has zero wrong.
- **Core panel lane**: the organ alone took 0 of the 924 core items (cap 9);
  self check passes.
- The dev split's WOULD FAIL is the head's wrong answers on sort items. It is
  not a finding about this organ. In a real install the shipped `algorithms`
  folder sits beside this one and takes those items. The harness scores one
  folder at a time, so that pairing was not measured.

Evidence: `native/evidence/2026-10-29-algorithms-native-panel.json` (artifact
hash, commands, run directories, counts per split, every wrong answer). Run
directories: `var/i1-organ/parity/alone-2`, `var/i1-organ/parity/front-w363-2`
(final folder). `alone-1` and `front-w363-1` got the same counts and were
run before `README.md` was added.

Extension used: `var/i1-organ/bin/oracle_native.so`, a debug build of
`native/target/debug/liboracle_native.dylib` at `4dea4f8`, darwin-arm64,
SHA-256 `2037b0b6cf87ebbf39ceeb3b8d251a08babc05d9e59b685110168b4eb59728ce`
(recorded in the manifest). Not committed.

Unit check: `VERI7VN_NATIVE_EXTENSION=var/i1-organ/bin/oracle_native.so
.venv/bin/python -B -m unittest tests.organs.test_algorithms_native`: 8 tests,
OK. They cover the recognizer on ten panel items including both kinds of
decline, ten near misses that must go to the head, the three in-domain
declines, the reply shape and the scorer's regex, transport-check rejection of
ill-fitting replies, and hash refusal (wrong bytes, no hash for the platform,
constructor refuses).

## Other panels with graph items

`grep -il "shortest\|spanning\|dijkstra\|kruskal"` over all 329
`upstream/root/specialists/*/*panel*.json`: only `algorithms` has graph
questions. Four relation panels match only on people's names
(`rel-statisticians`, `rel-computerscientists`, `rel-mathematicians`: Joseph and
William Kruskal; `rel-skaters`: Sjoukje Dijkstra). The organ leaves those to
the head because they contain no edge list, and a test covers this. The
`networking` panel has no graph items; `project/DIRECTION-2026-10-29.md` pairs
it with the graph operations, but its items are IPv4 arithmetic. The core panel
has none either.

## Appliance and package shape

**Provisioner.** The `specialists` map in `deploy/appliance` (kernel overlay
`manifest.json`, merged into `root/specialists/_proved/PROVED.json`) does not
install or replace specialist folders. It maps a shipped specialist id to a
Linux executable kernel, `{"binary", "flag", "family", "session"}`, with the
executable's SHA-256 under `binaries`. The release's proved-check fold
(`oracle7-slim-4.9-correctness.patch`) then runs that executable over the
answerer contract, after a reply already came from `specialist:<id>`, to mark
or withhold it. This folder fits none of that: `oracle_native.so` is a Python
extension, not an executable, it speaks no line protocol, and `session` means
an Isabelle session it does not have. The entry that would pass
`apply_kernel_overlay`'s syntax checks,

```json
"binaries": {"graph-native": "<sha256 of an executable>"},
"specialists": {"algorithms": {"binary": "graph-native", "flag": false,
                "family": "graph-native", "session": "none (Rust-checked, not Isabelle)"}},
"provenance": {"graph-native": {"source_revision": "<rev>", "build_receipt": "<receipt>"}}
```

would only be right once two things exist: a small executable that wraps this
recognizer and the native call behind the answerer contract, and a fold that
does not present a Rust check as a theorem. I recommend against it. The
folder belongs in the install as a specialist folder,
`root/specialists/algorithms-native/`, delivered by a component bundle or
patch that adds the folder's files by hash, the way bundles pin providers
(`deploy/appliance/component-bundles.md`).

**Package.** `tools/organs/package.py` packages only families registered in
`src/extract/families.json`, with executables under
`_veri7vn/bin/<os>-<arch>/<slug>`. To ship this folder, the package needs
the folder's six source files, plus `oracle_native.so` built on Linux x86-64
(`cargo build -p oracle-runtime-python --features reasoning` on hbox under
`swarm-build`; abi3-py312, Linux needs no link flags) with its SHA-256 written
into `store.native_extension.sha256["linux-x86_64"]`, plus the darwin-arm64
build and hash if macOS is wanted. Two changes would be needed first:
(a) a lookup of `../_veri7vn/bin/<os>-<arch>/oracle_native.so`, the package's
shared layout, which the organ does not look in today; (b) a registry or
package entry for a family whose artifact is an extension module, not an
executable. I did not register in `families.json`: every entry there names an
Isabelle session, an executable and a `build.sh`, and `make_organ.py` would
then try to generate a `<id>-veri7vn` folder for it.

## What remains

1. A Linux x86-64 `oracle_native.so` built on hbox, its hash added to the
   manifest, and the folder scored on Linux.
2. A packaging route: a component bundle or patch, plus the `_veri7vn/bin`
   lookup if it goes into the organ package.
3. Upstream PR text, along these lines: "algorithms-native answers the 16
   graph items of each split of the algorithms panel (32 of 84 items) with
   zero wrong, by Dijkstra and Kruskal on the stated graph, each result checked
   by a separate certificate checker. It leaves sorting, binary search and
   complexity to the existing organ."
   The honest pitch is "checked computation", not a gain: the shipped organ
   already scores 42 / 0 / 0 on held-out.
4. Next candidate: a statistics organ on `statistics.linear_regression`
   (statistics-v2 has 7 wrong in the shipped composition, which is real
   headroom).

## Questions for the reviewer

1. Should this folder replace the graph half of the shipped `algorithms` organ
   or sit beside it? Beside it, the release's combo arbitration decides which
   one answers a graph item. Neither pairing was measured, because the harness
   scores one folder.
2. Is it right to answer spanning-tree questions with negative weights?
   Kruskal and the native check handle them. The manifest declares `negative`
   only for shortest paths, following the shipped organ's Dijkstra rule.
3. The hash is checked when the organ is built, and the same path is loaded
   right after. Someone could swap the file between the check and the load.
   Is that acceptable for a trusted install directory, or should the organ
   copy the file to a private temporary file first?
4. The recognizer's "leave it to the head" word list (`OTHER`) is broad, on
   purpose ("not", "or", "only", "time", "nodes"). It costs recall on
   rephrasings the panel does not contain. Is that the right trade before a
   wider probe set exists?
5. Should native-extension organs get their own registry, apart from
   `families.json`?
