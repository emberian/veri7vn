# Compare related source queries

An agent comparing related people, works or institutions can prepare checked
programs once, then obtain full statement evidence, distinct entity counts and
existence results together on one image worker. Related predicates reuse the
existing live query stages and parsed source columns. Each item reports an answer,
failure or explicit not-run status. No previous turn is read
or updated. A count describes this supplied source, not everything in the world.

`python3 tools/usage/query_batch.py Alice Bob` emits arguments for `graph.batch`.
Add `--url http://127.0.0.1:8765` to run them against an admitted native host.
Each named source entity requests full evidence, source entity count and source
existence. The host accepts structured `batch.items`, with typed `input` programs, a
`kqa` or `graph` dialect and `full`, `count` or `exists` demand. It prepares all
programs against its admitted image under one request budget, then calls
`batch::execute` once. Preparation failure rejects the request; execution failure
explicitly stops the remaining items. Complete report size exhaustion rejects
the report rather than returning a partial success.

Central validation should run `batch_contract` after native surface integration. Compare single public program calls with batches for repeated source
columns and qualifier-bearing relations; final-DAG liveness, literal validation and projection semantics must agree. Record end-to-end p50/p95,
retained peak memory, cancellation delay and SQL work as well as actual stage/column cache hits, decoded source rows, lease,
attempted-node and output-byte counters. No speedup is claimed yet.

No specialist-panel numbers exist yet. No theorem is added: these Rust checks
are implementation contracts, not formal proofs. A useful shipped specialist
still needs measured host validation, a panel and scorer.
