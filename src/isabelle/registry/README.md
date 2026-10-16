# Native registry boundary (in progress)

`Veri7vn_Native_Registry` owns persistent non-rebinding tables containing actual
`cterm`, `thm`, and `Proof.context` objects. A fresh opaque generation captures an
immutable proof context and exact dependency record. Handles cannot be decoded
from strings or rebound; lookup requires the owning generation and store snapshot.
Interning retains theorem hypotheses and context assumptions verbatim. It is not
an admission decision: a theorem of an assumed false statement can be stored as a
candidate. No registry operation activates a capability, issues evidence, or grants
current access. The generated authority machine remains the invocation/publication
and lifecycle authority; consumers must use its native gate rather than exposing
raw object lookup as a public operation.

The registry/admission dependency is acyclic. Admission imports the object store
and owns opaque accepted consequence/implementation records. Those records retain
the handles and full audited native objects, and the gate alone translates them
into privileged generated authority events. This store neither imports admission
nor accepts an acceptance callback. Context lineage checks establish object
availability, not C02 ancestry/axiom/hypothesis policy.

`Veri7vn_Native_Profiles` keeps open native carrier types, actual certified shape,
scope and representation vocabulary, exact/approximate numeric conventions,
original bytes/codepoints and their explicit literal conventions. A declaration
is vocabulary/proposal data, with no implied codec law, refinement or admission.
Proof-only profiles can omit both executable representation and display projection.
Partial scope retains separate certified covered/missing descriptions. Native
types distinguish NULL/blob/rowsets, rational/symbolic values and point/delta/frame
families; there is no closed universal value type. The shared profile design is
under operational/interpretation/source co-review and is not frozen.

The typed bulk signature describes owned family batches and bounded byte decode;
it does not materialize a native term or JSON object per element. It cannot be
registered as arbitrary callback execution. Concrete generated bundle modules must
supply exact codec laws and native representation association, preserve literal
and shape/scope semantics, enforce bounds before allocation, and bind code setup
and compiler/serializer dependencies. Such modules, finite exhaustive dispatch,
opaque accepted operation attachment and session migration are still outstanding.
The feasibility packet is not promoted into a universal production value type.

Native lineage and executable bundle identities must stay separate: adding facts,
recipes or data can reuse the compiled bundle. Typed values and continuations are
bound to the latter, and cross-bundle migration requires admission and atomic
session revision. Matching native type names never justify a cast.

Initial standalone session: `Veri7vn_Registry` in this directory, imports only Main.
It checks actual theorem retention, persistent snapshots, rebinding rejection and
cross-generation handle rejection. A passing check does not close native-registry,
C02 admission, finite linking, current authority, bulk codec or migration gates.

Source co-review (sources61): `Complete` is declared extent only; it cannot replace
native population/coverage premises. A row-family shape must distinguish SQL NULL,
ordered duplicate-preserving rows, immutable blob bytes and prefix/truncation.
The batch family must retain schema, snapshot/import recipe, origin/configuration,
event/receipt/evaluation clocks, sequence IDs and rejection/missingness conventions.
Source semantics carries the actual coverage theorem; declaration is not evidence.
Dependency handles in declarations are references only; admission resolves them
under their exact owning generation and audits the resulting native objects.

Interpretation co-review (language61): literal ownership now has a separate opaque
`Veri7vn_Native_Literals.input` and checked half-open byte slices. Construction
checks bounds and exact original substring; source identity stays distinct even
for equal byte contents. Encoding is declared, not validated: decoding errors and
byte-to-codepoint/Isabelle-symbol maps remain explicit family obligations. Language
normalization must preserve deleted/expanded segments in its own checked source
map. Display projection must retain mandatory source/model/modality/premise and
coverage scope; merely supplying a cterm is not a rendering theorem. Profile
cterm typing against its carrier and dependency handle resolution remain admission
obligations; `declare` checks lineage/materialization bounds only.

`Veri7vn_Executable_Identity` supplies a separate opaque build pin capturing the
actual frozen code theory and compiler/target/artifact/serializer/foreign/settings
manifest. Manifest strings are diagnostic dependency declarations, not a proof or
accepted association. Exact code context uses native theory identity, so changes
to code setup cannot masquerade as the same pinned build. Native generations may
reuse the same pin; creating a fresh native context does not require a new ABI.
There is no executable callback, accepted-operation minting or dynamic value cast
in this API. Qualification and generated consumer linkage remain outstanding.

Executed initial evidence, 2026-10-15 macOS ARM64 / Isabelle2026-RC1:
`python3 tools/dev/check-native --session Veri7vn_Registry --session-root
src/isabelle/registry --timeout 90 --expect 'REGISTRY native_objects PASS'
--expect 'REGISTRY generation_guard PASS' --input src/isabelle/registry` passed.
Receipt: `var/native-scaffold/sessions/76ddf458c506624c/receipt.json`. Build uses
warm HOL, one job/two ML threads, serialized workspace-local state. Initial compile
caught reserved SML keyword `handle`; public type is now `object_handle`.
The passing build took 16 seconds including Isabelle session startup/build output;
this is not a runtime performance claim. Native object/literal guards are actual
ML implementation tests, not HOL proofs of the ML implementation or admission.

`Veri7vn_Typed_Runtime_Store` is a generative, bundle-private storage helper. The
bundle supplies concrete typed value/continuation carriers and one fixed executable
pin. Persistent tables retain actual typed values (including owned bulk vectors)
and continuations; opaque handle types cannot be interchanged or reconstructed
from wire names. Lookup checks the fixed executable pin and object presence in
that snapshot. The functor accepts no evaluator/conversion/evidence callback and
has no migration operation. A generated bundle must seal the instantiation and
keep accepted invocation under its gate; storage construction alone grants no
execution/current access authority. A new table instantiated with the same ML
carrier does not coerce old handles or establish a migration bridge.

The first composed admission build compiled the checked-slice profile change and
registry tests successfully, then failed in an admission certificate test. That is
registry consumer compilation evidence, not a passing complete admission suite.
Typed-runtime-store tests and profile `same_declaration` were added subsequently;
their next composed check is pending. They do not inherit the earlier PASS.

Subsequent composed checks exercised native trimmed certificates. Registry now
checks theorem lineage using `Context.subthy_id (Thm.theory_id th, ...)`, and cterm
availability through checked `Thm.transfer_cterm` feasibility; this supports
Isabelle's trimmed native certificates without relying on display names or
requiring an attached theory body. The stored actual object is retained unchanged.
Explicit trimmed theorem/cterm tests passed in the composed admission check.
Typed runtime bulk/continuation/generation/snapshot tests also passed there.

Per-handle `remove_value`/`remove_continuation` were then added at the production
staging consumer's request. They return a new table with only the selected handle
removed; old snapshots retain their own references. A sealed wrapper implementing
forget must remove every managed reference and cancel dependent work under current
authority. Release tests are awaiting the next composed Admission_Metadata check;
the earlier PASS does not verify these later methods.
