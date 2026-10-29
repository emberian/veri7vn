# algorithms-native: shortest paths and spanning trees, computed and checked natively

This folder is an Oracle7 specialist. It answers the graph half of Oracle7's own
`algorithms` specialist: the shortest path between two nodes of a graph the user
writes out ("Edges: A-B 6, B-C 1, ... What is the shortest path from D to A?"),
and the total weight of the minimum spanning tree of such a graph. The work is
done by two operations in veri7vn's Rust library (`graph.shortest_path`,
`graph.minimum_spanning_forest`), loaded into the Python process as the
`oracle_native` extension. Each reply carries a certificate (the route and its
distance labels, or the set of nodes that can be reached) that a separate Rust
checker accepts before the reply is returned; this folder then checks that the
reply fits the question it sent. None of this is proved in Isabelle.

What it answers: shortest path length and route, "no path" between two named
nodes, minimum spanning tree weight and its edges, and "not connected, so no
spanning tree". What it declines in its own domain (on a short direct question
only): an edge list with no start and end, a start or end that is not in the
edges, and negative weights in a shortest-path question. What it leaves to the
rest of Oracle7: sorting, binary search, complexity questions, decimal weights,
directed edges in a spanning-tree question, questions with extra conditions
("avoiding B", "at most 3 edges", "if ..."), stated node lists, requests to write
code, and story-shaped questions. The question reader in
`organ_algorithms_native.py` is hand-written Python and is not checked by
anything; it is built to say nothing rather than guess.

## Use it

1. Build the extension in a veri7vn checkout:
   `cd native && cargo build -p oracle-runtime-python --features reasoning`.
   The result is `native/target/debug/liboracle_native.dylib` on macOS
   (`liboracle_native.so` on Linux).
2. Copy this folder into `root/specialists/` of an Oracle7 install as
   `algorithms-native/`.
3. Put the extension at `bin/oracle_native.so` inside the folder, or set
   `VERI7VN_NATIVE_EXTENSION=/path/to/oracle_native.so`.
4. Record the extension's SHA-256 for your platform (`darwin-arm64`,
   `linux-x86_64`) in `manifest.json` under `store.native_extension.sha256`.
   The organ refuses to start if the file it finds has a different hash, or if
   no hash is recorded for the platform it runs on.
5. Run Oracle7's exam (`run(folder, "dev", engine)` in `workbench/exam.py`) on
   the practice questions. Only use `heldout` once, for a real admission exam.

## What is in the folder

| File | What it is |
|---|---|
| `manifest.json` | Oracle7's description of the specialist: what it accepts, its budget, the extension's hash |
| `organ_algorithms_native.py` | reads the question, sends the exact request to the extension, words the checked reply |
| `algorithms_panel_v1.json`, `algorithms_scorer.py` | copies of the shipped algorithms questions and scorer (see `NOTICE`) |
| `narrow_v1.py` | copy of Oracle7's shared rule that story-shaped questions belong to the head |
| `bin/oracle_native.so` | not in source control; you put the built extension here |
