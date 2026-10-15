# Shared contracts, revision 0

These are the **early integration baseline**, not claims of implemented admission
or verified execution. Changes are expected as the first real specialist crosses
the boundaries. Lanes may implement behind these interfaces independently; changes
that affect another lane's producer or consumer must update this baseline and its
fixtures together.

Revision-0 integration adjustments: requests distinguish immutable build/source
environments from mutable-state and time observations; package descriptors permit
support/data/unfinished developments with no capability exports or native session.

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
  Producing a proposal confers no authority to publish it.
- **Accepted result:** a licensed claim/result with a specific assurance route and
  dependencies, issued by the corresponding acceptance boundary.

Native `typ`, `term`, `cterm`, `thm`, `Proof.context` and theory identities stay
native. A portable locator or receipt lets a runtime resolve or replay an object;
it is **not a serialized theorem or a proof of the locator's assertions**.

## Compatibility discipline

Contract IDs are stable. Revision `0` is an integration baseline, not a promised
public ABI. Package format `veri7vn.package/0` rejects unknown fields so a misspelled
or invented assurance field cannot be silently ignored. Adding a field changes
the schema and fixture suite; changing meaning also changes the contract revision.
Future negotiation/migration must be explicit. No client may reinterpret an
unknown result tag as success.

Human package versions communicate author releases; they do not identify exact
bytes or guarantee semantic substitutability. Published generations never mutate.
Digests can identify artifacts under a declared hash convention; cryptographic
authentication and proof are separate concerns. No global signing or hashing
scheme is mandated by this baseline.

The integration coordinator owns cross-contract decisions. Each implementing lane
owns its producer and consumer obligations, while the contract lane owns these
shared definitions and fixtures. Avoid parallel copies of these types in independent
subsystems without a shared generated definition or conformance check.
