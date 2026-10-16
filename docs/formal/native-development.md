# Receiver-owned expert development

`src/isabelle/admission/development/native_development.ML` reconstructs complete
original `.thy` sources in a private descendant of approved native parents. It
retains the exact original bytes; source equality and the exact host-resolved parent
imports are checked before any declaration is constructed. The supported first
slice is a normal `theory … imports … begin … end` containing native `definition
name :: type where "equation"` and `lemma`/`theorem name: "proposition" by (simp
add: facts)`. Definitions retain the native command’s checked parameter treatment. No separately editable formula recipe is required.

The source parser does not invoke `Outer_Syntax`, `Method`, `Attrib`, or source ML.
It builds each definition with the admission gate’s fixed controlled
`Specification.definition_cmd` constructor and carries its returned successor policy.
This preserves the original exported equation, default code equation and native
Spec_Rules registration; a primitive lambda definition alone would change them. Theorems are proved by a
fixed receiver simplifier and installed with no source attributes. Policies are
advanced only across unchanged axiom tables; they are never reset over an authored
theory. Unsupported syntax fails before declarations execute. Source byte equality
is an integrity check, not proof authority: the approved policy must be supplied by
the trusted resident host, never decoded from worker labels.

Installed implementation inspected: Isabelle2026-RC1
`Contents/Resources/src/Pure/theory.ML` (`add_def`, `add_axiom`),
`src/Pure/Isar/specification.ML` (`gen_def`), and
`src/HOL/Tools/typedef.ML` (`primitive_typedef`, `prepare_typedef`, `add_typedef`).
`typedef` introduces its primitive axiom before the package discharges inhabitedness;
therefore neither a Defs report nor command observation is authority for an
untrusted worker extension. A future controlled typedef constructor must own the
native type declaration, representation set, nonempty witness proof and all package
side conditions. Datatypes, function packages, locales/classes, richer proofs and
code setup likewise need explicit trusted reconstruction constructors or a distinct
privileged native-plugin policy. This first command slice does not close them.

The full build closure remains the packaging inventory's responsibility:
`SessionInventory.inspect` uses actual Isabelle session/dependency analysis. The
inventory is data, not a proof or filesystem sandbox. This source reconstructor
takes explicit host-resolved `(source import locator, approved policy)` parents.
It merges their actual native keyword tables, begins the native theory with those
actual parents and uses the gate’s checked policy join. Source import spelling is
never guessed from the native theory name. It finalizes the resulting native theory
and advances the carried policy across finalization. It does not load arbitrary
session imports, execute a worker build, attest a heap or establish executable code
identity. Resident managed-lifetime/source ownership and recovery publication must
consume the retained source plus approved parent identity before exposing these
objects as durable evidence. No opaque object from this module is by itself an
accepted consequence; callers must use `Native_Admission.admit` in its returned
policy and exact native generation.

The narrow test is `tests/admission/development/Native_Development_Test.thy`.
It exercises an actual complete source file, definition and proved consequence. It compares an independently ordinary-built
source definition’s proposition, code equations and Spec_Rules registration with
the reconstructed result,
plus ML policy-forgery, embedded tactic, false theorem, axiom, exact-source swap
and parent-import swap negatives. A two-parent test proves a theorem consuming both
controlled branch definitions and rejects a wrong source-locator/native-context map.
Build execution is serialized by the shared build steward through `check-native`.

## Owned build inputs

`src/packages/native_build/NativeBuildInputs.scala` consumes the host's registered
`WorkerResources` input lifetime. The empty owner is registered inside the exact
current source read scope before copying any object. A bounded parser-clone envelope
is reserved first; temporary parser copies are cleared, the immutable parsed revision
is retained only by a releasable private root, and file slots are tracked before
writes. The resulting opaque owner exposes checked inventory and release rather
than a raw source snapshot or filesystem resolver. Its inspection uses the actual
`SessionInventory` and checks all discovered files against the captured manifest or
the accepting host's installed-source pins; captured ROOT/ROOTS are reread afterward.

This is a host-internal source operation, not an authorization API. The production
coordinator must consume the generated source/build/reveal grant before invoking it
and before exposing bytes to a worker. Revocation invalidates the registered lifetime;
cleanup stops/join workers, clears buffers, drops private roots and erases only owned
paths. Durable crash ownership intents, the closed authorized coordinator route,
actual worker/build handoff and managed native replay are additional integration
requirements. A JVM payload reservation is not a process memory limit or a sandbox.

`literal_spans.ML` provides a shared storage-only token/span adapter.
Isabelle's `Token.source_of` is compact inner input with deletion padding rather
than raw lexical source; concatenating it loses quote/comment delimiters. The
adapter maps actual native token position ranges back to the retained original
bytes using the installed symbol scanner. It accounts for native CR/CRLF and legacy
encoded-control normalization while retaining the original bytes, then requires
contiguous complete token coverage. It neither unparses tokens nor authorizes a
source. Quoted strings, comments, UTF-8, named symbols, cartouches and CRLF are
included in the native fixture. The helper lives in the shared admission base before managed provenance; recipe
consumers use the same API. No second source parser is introduced. The first leaf
pass is archived with its exact pre-relocation body; the context-sensitive legacy
control/UTF-8 edge correction has its own pending regression.

The owned-input consumer passed in the canonical 29-source runtime check on
2026-10-15 (25.532 s, all nine groups). Exact source bodies and logs are archived at
`var/runtime-host/canonical29-20261015T230218Z`. The native-build checks exercise
actual session dependency inventory, missing installed-source pins, swapped source
hashes and post-analysis ROOT changes, followed by registered source capture,
materialization, Forget invalidation, rejected use after release and owned directory
cleanup. This qualifies that component; it does not establish the fixed native
replay service handoff, the complete transitive private package build graph or a
successful deployed build.

The full controlled development session passed on 2026-10-15 in 5 s. The exact
production gate/helper/replay and ordinary source/test bodies are archived at
`tests/admission/development/evidence/native-development-20261015`, verified against
immutable attempt `c9cef8ad8ec3ce76/2e7c3e46336b4ad99290c991d7b46363`. The overall
batched receipt failed in an unrelated service-frame module; no service pass is
claimed. Actual assertions compare the independently built source and receiver
reconstruction, admit the consequence through C02 and exercise the two-parent and
adversarial cases above. Managed-provenance integration and a fixed authorized
service operation remain required consumers.

## Managed specialist producer consumer

The generic admission image now loads the checked development core before managed
provenance. `Managed_Provenance.replay_source` consumes actual approved managed
parents, an installed source owner and an exact original slice. It owns the new
context and source leases, retains the ordered replay construction trace and exposes
canonical `named_theorem` production through C02. The producer is not a service
operation or execution grant.

`tests/admission/development/Provenance_Specialist.thy` is the first specialist
consumer: it selects observations whose origins are classified and proves that
selection excludes unknown origins and respects input batching. This is a theorem
about that filter, not a source-population coverage claim. The managed fixture uses
this same authored file in a nonzero retained-source slice, produces a native
descriptor, checks exact target/source dependencies and exercises wrong owner,
short alias, parent release and source Forget. This new composition is pending its
first native check; the earlier standalone replay pass does not establish it.

A candidate specialist artifact is nonassertional and may have no theorem exports.
D43 gives it a typed artifact requirement/output instead of a dummy claim. The
service-owned charged ticket must bind the original source revision, actual parent
closure, export intent, fixed builder pin and positive bounded resource profile.
The native builder pin identifies Isabelle/PolyML replay code and supported command
policy; it is not refined-execution assurance. Selected theorem exports separately
undergo C02. A plain descriptor ingress is not the charged candidate-build route.

Managed callers allocate `P.construction_scope` before invoking
`P.replay_source_owned`. The fresh context is registered in that scope inside the
producer's bounded publication transition, closing the deferred-interrupt gap
before the caller receives its return value. The caller restores interruptibility
around replay and proof checks, then records descriptor/development roots before
committing the scope. Exceptions abort the scope and release only its fresh
products. The managed fixture covers a failed named export after replay while a
preexisting descriptor and shared parent remain live. This composition awaits its
queued native check; source-level review does not replace that result.

The managed producer composition passed in the actual native development session
(4 s, managed theory 0.632 s cumulative time), immutable attempt
`fe9f8d5b32b933ac/0bdc71ea70dc40e9b752245c6353eefb`. Exact production and fixture
bodies are archived with verified attempt hashes in
`tests/admission/development/evidence/managed-development-20261016`. The mixed batch
failed only in a separate recovery test API call; no whole-batch pass is asserted.
This supersedes the pending managed-fixture status above. It establishes the finite
managed full-source producer/native descriptor consumer and its tested rollback and
lifetime behavior. The D43 charged artifact service, persistent candidate/restart
consumer and full dependency build graph remain open.
