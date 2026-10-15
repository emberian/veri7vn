# Shared contracts, semantic revision 1

These are the **early integration baseline**, not claims of implemented admission
or verified execution. Changes are expected as the first real specialist crosses
the boundaries. Lanes may implement behind these interfaces independently; changes
that affect another lane's producer or consumer must update this baseline and its
fixtures together. **Current design hold:** implementation waits on
`design-convergence`. [Architecture revision 2](../ARCHITECTURE_PROPOSAL.md)
proposes the concrete generated-core, native linkage and host/lifecycle mechanisms
behind these boundaries. It is pending agreement; descriptor format and executable
interfaces are not silently changed by the proposal.

Revision-0 integration adjustments: requests distinguish immutable build/source
environments from mutable-state and time observations; package descriptors permit
support/data/unfinished developments with no capability exports or native session.

## Revision 1 changes and consumers

This semantic revision incorporates the source-backed [preimplementation audit,
G01–G08](../review/PREIMPLEMENTATION.md). Descriptor format `veri7vn.package/0`, its
schema, and the existing executable probes are unchanged. The new obligations are
requirements for future implementation, not features those probes already verify.

| Clarification | Contracts | Implementing consumers |
|---|---|---|
| Claim scope/modality, candidate artifacts, literal-preserving views, extensible codecs, per-subgoal completeness and scoped routing blockers | C02/C03 | Interpretation, operational model, domain families, composition, synthesis and clients |
| Semantic admission versus operational qualification/activation; feedback/exam provenance and selected private-safe exports | C01/C02 | Registry, authoring, package lifecycle, qualification, deployment |
| Retention/retirement/current authority; state restoration; event versus receipt time and acquisition configuration | C04 | Source ingestion, dependency updates, dialogue, lifecycle, runtime |
| Discovery/onboarding/testing/background effects; final arbitration before context commit; cached-handle retirement and uncertain external outcomes | C05 | Scheduler, state/effects, connectors, runtime and qualification |

Exact retention periods, qualification thresholds/holdout policy, codec signatures,
ingestion duplicate/late-sample policies and external-action retry semantics remain
owned design decisions. They cannot be filled in independently by each consumer.

## Contract index

| ID | Boundary | Owner role | Acceptance evidence |
|---|---|---|---|
| C01 | [Editable specialist package](package.md) | Authoring / packaging | Schema fixtures; native export resolution; clean reproducible build |
| C02 | [Native capability and evidence admission](native-admission.md) | Admission / metatheory | Positive and adversarial native tests; implementation connection |
| C03 | [Requests, interpretations, results, diagnostics](request-result.md) | Interpretation / execution / client | Ambiguity, timeout, conditional and source-dependent result integration tests |
| C04 | [Environment pins and dependencies](environment.md) | Registry / source store / deployment | Generation isolation and invalidation tests, including negative observations |
| C05 | [Strategies, execution and effects](strategy.md) | Search / scheduler / execution | Proposal/commit isolation, cancellation and resource tests |

**Implemented here:** one strict JSON Schema and executable fixture suite for
package descriptor structure. **Not implemented here:** package loading, formal
meaning resolution, admission, a network protocol, caching, or effect enforcement.
The baseline specifies obligations for those implementations. Schema validation
only establishes descriptor shape.

## Shared vocabulary

- **Package:** editable development sources plus declared exports and dependencies.
- **Capability:** a named native specification with contracts and implementation
  attachments; its native types need not belong to a universal value datatype.
- **Generation:** an immutable resolved environment for running work.
- **Proposal:** a candidate reading, plan, result, definition, proof or effect.
  Producing a proposal confers no authority to activate it as a capability or commit
  an effect; it may be presented to an ordinary user as a candidate artifact.
- **Accepted result:** a licensed claim/result with a specific assurance route and
  dependencies, issued by the corresponding acceptance boundary.

Claim scope describes what a claim concerns—a mathematical consequence, observed
test run, finite model, source report or bounded candidate set—independently of how
it is supported. Artifact delivery and conversational speech acts do not themselves
assert universal correctness.

Native `typ`, `term`, `cterm`, `thm`, `Proof.context` and theory identities stay
native. A portable locator or receipt lets a runtime resolve or replay an object;
it is **not a serialized theorem or a proof of the locator's assertions**.

## Compatibility discipline

Contract IDs are stable. Semantic revision `1` is an integration baseline, not a promised
public ABI. Package format `veri7vn.package/0` rejects unknown fields so a misspelled
or invented assurance field cannot be silently ignored. Adding a field changes
the schema and fixture suite; changing meaning also changes the contract revision.
Future negotiation/migration must be explicit. No client may reinterpret an
unknown result tag as success.

Human package versions communicate author releases; they do not identify exact
bytes or guarantee semantic substitutability. Published generation identities never change their meaning; retention and current
authority are managed separately under C04.
Digests can identify artifacts under a declared hash convention; cryptographic
authentication and proof are separate concerns. No global signing or hashing
scheme is mandated by this baseline.

The integration coordinator owns cross-contract decisions. Each implementing lane
owns its producer and consumer obligations, while the contract lane owns these
shared definitions and fixtures. Avoid parallel copies of these types in independent
subsystems without a shared generated definition or conformance check.
