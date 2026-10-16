# Shared contracts

C03/C04 semantic revision 2; C01/C02/C05 revision 1. Descriptor format remains
`veri7vn.package/0`. These contracts specify obligations, not completion claims;
[validation](../../project/VALIDATION.md) identifies actual consumers and checks.
The [architecture](../ARCHITECTURE_PROPOSAL.md) selects their implementation.

| ID | Boundary | Required consumer evidence |
|---|---|---|
| C01 | [Package](package.md) | Source ownership, native export resolution, qualification and reproducible deployment |
| C02 | [Admission](native-admission.md) | Exact native objects, adversarial checks and actual implementation association |
| C03 | [Request/result](request-result.md) | Literal fidelity, interpretation, scope, partial outcomes and diagnostics |
| C04 | [Environment](environment.md) | Generation isolation, observation dependencies, lifecycle and recovery |
| C05 | [Strategy/effects](strategy.md) | Proposal isolation, budgets, dispatch, cancellation and durable commit |

## Vocabulary

A **package** is editable source with declared dependencies/exports. A **capability**
connects native specification, contracts and implementation; it need not use a
universal value type. A **generation** resolves immutable artifacts. A **proposal**
may be a reading, plan, proof, program or effect; it confers no publication authority.
An **accepted result** is the exact licensed claim with assurance and dependencies.

Claim scope (source report, model prediction, test observation, mathematical
consequence) is separate from assurance, artifact delivery and activation. Native
`typ`, `term`, `cterm`, `thm` and contexts remain native. Names, hashes and portable
receipts locate/replay objects; they do not serialize native proof authority.

## Compatibility discipline

Contract IDs are stable, not a public ABI guarantee. Unknown descriptor fields and
result tags are rejected. Shape validation establishes only shape. Human package
versions are not exact byte identities or semantic substitutability promises.
Published identities retain meaning; current access/retention is separate.
Authentication, integrity and proof are distinct; no global signing scheme is
mandated here.

Changes to consumed contracts require a coordinated decision, migration and
producer/consumer fixtures. Do not create independent copies of shared types
without generation or conformance checks. Qualification thresholds, retention,
codec policies, sample ingestion and retry semantics have explicit owners.

C03/C04 revision 2 separates `NoExecution` from `ExecutableGeneration g` and semantic
target equality from execution requirements (D30). Operational authority, admission,
registry, language/rendering, plans and host must migrate together, including the
finite metadata codec/schema seal. Reject old numeric-only images or use an
explicit admitted migration. Required cases: proof-only kernel fact in a normal
bundle request; absent/swapped provenance rejected for executable-specific requests;
unknown bundle rejected at registry ingress. Descriptor format is unchanged.

[Preimplementation G01–G08](../review/PREIMPLEMENTATION.md) supplies adversarial
requirements across scope, qualification, lifecycle and effects; passing schema
fixtures does not discharge them.
