# Efficient backend portfolio

Use generated Standard ML first. `src/backends/Ordered_Index.thy` specifies RBT lookup as list filtering, preserving order, duplicates and absent keys. Multi-key indexing deduplicates a record's keys, not source rows; an undirected self-loop appears once and parallel rows stay distinct. `Graph_Indexed.thy` connects that representation to graph queries. Proof/consumer qualification and measurements determine adoption.

## Foundation placement

The optional ordered-index child reuses pinned `Veri7vn_Effects_RBT`; graph indexing imports it without changing the warm service parent. Moving RBT into a neutral backend foundation requires a coordinated rebuild and checks of effects and graphs. Do not duplicate its namespace or change global set code equations.

## Portfolio decision

| Backend | Decision and gate |
|---|---|
| Generated SML / PolyML | Primary implementation; qualify exact representation, callable association and runtime entry |
| [Sepref / Imperative HOL](https://isa-afp.org/entries/Refine_Imperative_HOL.html) | Focused compatibility/value probe after functional indexing; absent from the inspected RC1 inventory |
| [Isabelle-LLVM](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2019.22) | Disabled research candidate; RC1 compatibility and ABI/artifact evidence required |

MLton's LLVM documentation is not an Isabelle-LLVM installation or verified machine-code route. Compiler/runtime trust remains TB-02; representation/lowering correctness remains PO-07/C02.

## Correctness and measurement protocol

Compare identical pinned graphs, orientation, source order, multiplicity and bounds. Test isolates, absent keys, self-loops, parallel rows and reverse traversal with independent path checking. Steward-run sparse/dense/high-degree workloads separate index construction, repeated lookup, proposal and checker costs, memory and startup. Include one-shot queries where indexing may lose. No operation-count argument substitutes for measured benefit.
