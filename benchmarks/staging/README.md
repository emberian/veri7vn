# Bounded native projection

`evidence/projection-receipt.json` pins the stable passing `Veri7vn_Projection_Tests` run. The generated bool-list-list reifier matches the native HOL term; oversized output refuses before construction, and exceptions restore thread-local scope.

With a 1000-node budget, N-element lists shared across P references produce:

| N | P=1 | P=8 | P=32 |
|---|---|---|---|
| 16 | materialized | materialized | refused |
| 128 | materialized | refused | refused |
| 512 | refused | refused | refused |

All nine preflights left output `Term` constructor counts unchanged. This measures construction order, not total allocation, latency or native-trace memory.

Conditions: Isabelle2026-RC1, Poly/ML 5.9.2, Darwin arm64, warm HOL, one job/two ML threads. Driver 68.816s and build 51.018s include two authority targets and cached dependencies; neither isolates projection cost.

`Veri7vn_Row_Kernel_Tests` (`tests/execution/kernel`) composes acquired batches, reflected query and recipient projection. Count scope is selected rows with ordered-bag semantics and declared materialization. Unclassified windows retain policy/dependency blockers; projections omit observation payloads. Numeric fixture IDs confer no host authority.

Operation/worker qualification requires native qualification, pre-answer recipe, confirmed inputs, charged one-shot execution and revocable ownership. Cancellation joins outside the authority lock; modeled cost and a five-second timeout establish neither memory nor CPU bounds.

`Veri7vn_Source_Relation_Consumer_Tests` queries entity1/property2 → object3 through the fixed callable and private test-image ticket. It checks independent result release and alias denial after source invalidation. Manifest-v2 raw reference is absent. Results describe the decoded snapshot; interpretation, world coverage, retention permission and durable production authorization require their own gates.
