# C01 — Specialist package

Semantic revision 1; descriptor `veri7vn.package/0`, defined by
[package.schema.json](../../schemas/package.schema.json). Schema validity is shape,
not native admission, execution authority or import safety.

## Authoring model

Canonical editable sources own meaning. Descriptors index files, exact release
dependencies, optional native session/theories and capability locators; they do not
duplicate types, formulas or theorem statements as editable JSON. Generated native
artifacts retain their recipe/inputs and are not a second semantic source.

Exports may be empty: support theories, data and unfinished developments need no
dummy capabilities. `native` is required for exports, optional otherwise. A locator
`{theory,name}` selects an exported context and fully qualified native lookup name.
Resolve/check its kind and canonical name there; imported objects retain original
names. Session-qualified theories and logical names are different namespaces.

Portable capability identity is `(package_id, package_version, capability_id)`;
resolved generations additionally distinguish exact contents. IDs use lowercase
ASCII letters, digits, underscores/hyphens and dotted package names. Do not flatten
the tuple using a delimiter allowed inside an ID.

## Native loading obligations

1. Resolve paths inside the root, including symlink containment; reject duplicate
   paths/export/dependency IDs and nonportable casing.
2. Verify files/session/theories and resolve the actual build closure: transitive
   imports, included ML, selected code setup, libraries and generated inputs.
   Descriptor source files alone are not that closure.
3. Resolve specifications as native terms/constants, contracts as theorems and
   executable locators as candidate attachments subject to C02.
4. Build under controlled declaration policy. Arbitrary theories can execute ML
   or introduce axioms; ordinary declarative extensions and privileged plugins
   require different policies.
5. Retain replayable sources/build records. Heaps are derivatives, not author source.

## Compatibility and author feedback

Adding an export can change routing, overlap, defaults, effects or code setup.
Replacement preserves the established observation/refinement relation or publishes
an explicitly changed generation. Bug repair and upstream parity are separate claims.
Diagnostics link source, obligation, counterexample and affected consumers; distinguish
restricting a domain from changing intended meaning.

## Qualification, activation and transfer

Semantic admission, empirical qualification and active publication are independent.
Qualification binds exact candidate/baseline, routing/learned policy, source/state
observations, scorer, dataset/split, exposure and resource environment. Include
must-decline/interference cases. Tests do not replace proof; proof does not waive
product qualification. Repeated regression remains useful without pretending to
be fresh held-out evidence.

D36 separates exposure eligibility from outcome. Reserve/consume eligibility
durably before byte access/execution; abort, crash or log deletion never refunds
freshness. Unknown imported exposure is not fresh. Publication atomically checks
candidate, measured scope, separately admitted capabilities, policy and expected
previous active version. Failed qualification leaves the previous policy active.

Feedback identifies the actual request/result and whether it corrects interpretation,
facts or routing. It proposes a versioned policy, with evaluation, undo and retention;
a “right” mark is not a proof. Gap examples retain unknown expectations until supplied.

Export selects classified transitive contents, excluding private transcripts,
feedback, caches, learned forms and credentials by default. Credentials remain host
references. Preview omitted dependencies and resulting rebuild/runtime limits.
Hashes, attribution and exam receipts are not semantic proof. Public registry scope
is a separate decision. [C04](environment.md) governs retention and omitted material.

Required integration: create/build/repair without duplicate semantic edits; exact
export resolution and useful failures; clean pinned installation; adapters visibly
separate from formal lifts. [G05/G07/G08](../review/PREIMPLEMENTATION.md) supplies
adversarial cases. Current implementation evidence belongs in the tracker.
