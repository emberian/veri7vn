# Bounded native projection

`evidence/projection-receipt.json` is the source-pinned, stable passing native
integration receipt for `Veri7vn_Projection_Tests` in a three-target serialized
build. It is test provenance, not native theorem transport or admission evidence.
The actual test invokes a generated concrete bool-list-list reifier under the
curated Eval serializers. A small output exactly matches its native HOL term.
Preflight leaves the output-term constructor counter unchanged; oversized output
refuses before materialization. An exception restores the thread-local scope.

The paired fixture shares one N-element list across P native list references,
while reification must visit all logical occurrences. Under a 1000-node
conservative projection budget:

| N | P=1 | P=8 | P=32 |
|---|---|---|---|
| 16 | materialized | materialized | refused |
| 128 | materialized | refused | refused |
| 512 | refused | refused | refused |

All nine preflights left the output-term allocation counter unchanged. This
counter covers the helper's output `Term` constructors, not heap allocation,
type construction, garbage collection, or the already computed native trace.
The fixture establishes allocation order and bounded refusal. It is not a
throughput, latency, memory, or bulk query benchmark.

Toolchain: Isabelle2026-RC1, Poly/ML 5.9.2, Darwin arm64; workspace-local warm
HOL, one build job, two ML threads. The receipt's 68.816-second driver and
51.018-second build times include two authority targets and cached dependencies;
neither is isolated projection cost. The projection parent compiled in the prior
run; this passing run tested the corrected monomorphic reifier wrapper.

The next composed target, `Veri7vn_Row_Kernel_Tests` under
`tests/execution/kernel`, exercises the actual reflected acquisition/query
function and final result extractor with a source batch. It is currently pending
upstream native checks. Its numeric request/snapshot values are fixture data,
not authenticated host attempts or accepted output associations. A passing pure
kernel fixture will establish carrier/callable composition, not host admission
or end-to-end answer publication.

The same pending target checks recipient projection from that actual query:
the count carries selected-source-row scope, ordered bag semantics, declared
snapshot materialization and explicit absence of world coverage. A window with
an unclassified event clock under `RequireClassifiedWindow` must preserve the
upstream policy blocker and all dependent blockers in its stopped summary.
Projection contains no original observation or row payload. This is a fixed
native projector; recipient retention permission remains the source gate's
responsibility.

The operation instance and protected row worker are not covered by the checked
projection receipt. Their pending composition must establish actual native
qualification, the immutable pre-answer recipe, confirmed acquisition inputs,
one-shot charged invocation and revocable output ownership. The worker commits
a tracked job before launching the fixed query future; collection is nonblocking
and cancellation joins outside the authority lock. Its positive modeled cost
and five-second timeout do not establish a memory bound or a CPU-cost theorem.

`Veri7vn_Source_Relation_Consumer_Tests` is the pending concrete relation
consumer target. It uses the same acquired batch and original body/manifest
owners, captures the family-owned `SnapshotRelationQuery` before acquisition,
and invokes the fixed callable through a consumed private test-image ticket.
Its fixture expects entity 1/property 2 to yield entity object 3, checks individual
result release without releasing the association, then checks that source
invalidation denies a retained result alias. The tiny manifest fixture preserves
the shared manifest-v2 fields with its optional raw reference explicitly absent;
it does not reuse another body's hash as a reference.

The native result describes the exact decoded snapshot, including declared
materialization. It grants no NL reader/domain interpretation or external-world
coverage. Those remain separate admission premises. Test-image ticket issuance
exercises typed consumer/lifetime composition; it does not validate durable host
command persistence or prove current production authorization.
