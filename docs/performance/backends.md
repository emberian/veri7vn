# Efficient backend portfolio

The first backend is Isabelle-generated Standard ML over the pinned balanced-tree
implementation already present in `Veri7vn_Effects_RBT`. It serves actual graph
adjacency and vertex queries. `src/backends/Ordered_Index.thy` specifies lookup as
an ordinary list filter, retaining source order, duplicate records and absent-key
behavior. Its multi-key operation deduplicates a record's keys, not source rows:
an undirected self-loop appears once while parallel rows remain distinct.

Status: candidate proofs await the coordinated native check. The graph adapter now follows the graph owner's directed/undirected path migration;
its indexed proposer and validation require native checking and selected-source linkage. No measured speedup,
implementation admission or production linkage is claimed by this source alone.

## Foundation placement

For the current build, `Veri7vn_Ordered_Index` extends the existing pinned RBT
session without altering its parent or installed sources. `Veri7vn_Graph_Index`
is an optional child of the light `Veri7vn_Graph_Core` session importing the ordered-index session.
This leaves the warm native service prefix intact. After integration, a coordinated
migration should move the pinned RBT session to a dependency-neutral backend
foundation, with effects and graphs as consumers. Do not copy RBT into another
theory namespace or change global set code equations. A session-parent migration
requires one explicit rebuild window and checks of both consumers.

## Portfolio decision

| Backend | Current disposition | Evidence and remaining gate |
| --- | --- | --- |
| Generated Standard ML / resident PolyML | Implement first | Installed RC1 toolchain and existing generated consumers; prove exact representation and connect the actual graph entry point before admission |
| Sepref / Imperative HOL | Worth a focused compatibility probe after functional indexing | [AFP's IRF entry](https://isa-afp.org/entries/Refine_Imperative_HOL.html) supplies imperative collections, graph algorithms and refinement synthesis; it does not establish compatibility with this installed RC1 image |
| Isabelle-LLVM | Research candidate, disabled | [Primary paper](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2019.22) describes the LLVM refinement route. Existing project research records mixed version prerequisites; no RC1 build or ABI/artifact qualification exists here |

Inspection of the installed `/Applications/Isabelle2026-RC1.app/Contents/Resources`
source inventory on 2026-10-15 found no Sepref or Isabelle-LLVM theories. Bundled
MLton LLVM backend documentation is compiler documentation, not installation of
Isabelle-LLVM or a verified machine-code path. Absence from that inventory is not
a proof that no compatible external distribution exists. Native compiler/runtime
execution remains TB-02, with C02 implementation attachment and PO-07 obligations.

## Correctness and measurement protocol

The graph comparison must use the same pinned snapshot, original edge records,
orientation, source order and bound outcomes. Include isolated vertices, absent
keys, parallel edges, mixed endpoint roles, self-loops and reverse traversal.
Independent path checking remains mandatory. Enumeration equality includes order
and multiplicity; one-path search may have its separately stated observable scope.

After correctness, the sole build/runtime steward runs generated code on sparse,
dense and high-degree graphs, separating index construction, repeated adjacency
queries, proposal execution and independent checker costs. Report graph sizes,
query counts, startup, allocation/memory and full end-to-end timing. Include
one-shot workloads where index construction may dominate. Source acquisition and
native admission timings stay separate. An operation-count argument or synthetic
Python implementation is not an end-user speedup measurement.
