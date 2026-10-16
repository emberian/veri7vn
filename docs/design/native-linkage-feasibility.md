# Native linkage and proof transport feasibility

This is a bounded RC1 experiment for D14/D25/D26 and C01–C04, not the
production registry, admission policy, host protocol or complete finite linker.
The sources are `experiments/native-linkage/base/Native_Linkage_Base.thy` and
`transport/Native_Linkage_Probe.thy`. The base session uses bundled warm HOL and performs
the finite linkage checks with ordinary recording. Only the small receiver-definition/transport
child session enables full recording (`record_proofs=2`), with two ML threads.

## Concrete linkage

The executable signature contains three native carriers: `nat`, `bool` and
`bool list`. Its packet datatype has one constructor per carrier. Generated
exhaustive dispatch covers increment, a cross-profile natural-to-Boolean zero
predicate, and a Boolean-list count. Wrong carrier/operation pairs return
`None`. Native meanings outside this finite signature remain unrestricted HOL;
this packet is not a proposed universal HOL value type.

The exact native theorems are:

- `increment_link`: `dispatch Increment (Nat_Value n) =
  Some (Nat_Value (increment n))`, where `increment n = n + 1`.
- `conversion_link`: `dispatch Is_Zero (Nat_Value n) =
  Some (Bool_Value (is_zero n))`, where `is_zero n` means `n = 0`.
- `count_true_refinement`: `length (filter id xs) = count_true xs`, where
  `count_true xs = card {i. i < length xs ∧ xs ! i}`.
- `count_link`: `dispatch Count_True (Flags_Value xs) =
  Some (Nat_Value (count_true xs))`.
- `packing_injective` gives the three constructor injectivity laws.

These are unconditional mathematical statements with schematic arguments, not
source-world assertions. The probe checks zero hypotheses, zero premises and
no oracle dependencies for the three link theorems. Generated SML dispatch and
constructors come from the same Isabelle code antiquotation compilation. It
executes concrete examples through those generated objects, without casts,
arbitrary callback registration, lookup-by-proof-name or a worker code path.

A deliberately narrow fixed-bundle association checks the actual `dispatch`
term, native link theorem proposition, constructor term, and exact theory
identity used for code generation. It rejects swapped theorem/representation, a theorem with the correct visible
proposition but an added hidden `False` hypothesis, and a theory whose dispatch code setup has been changed with
`Code.declare_unimplemented_global`. A separate negative removes the SML Boolean
type serializer through `Code_Target.set_printings`; that altered context is
rejected before invocation. Neither altered configuration is compiled or run.
This is a conservative pinned instance,
not a general native gate: it rejects all different theory identities, including
harmless descendants. Production needs approved object ownership, full C02
policy and a curated code/dependency manifest; testing this instance does not
prove a general manifest extractor or the downstream compiler.

`invoke` checks bundle versus value generation before dispatch. The HOL guard
laws and generated negative example concern invocation compatibility. They do
not discharge or erase conditional source/model premises. Generation numbers
here model equality only; they are not a cryptographic/runtime identity scheme.
No session-value migration is implemented.

## Bounded inert transport

The receiver theory value is captured before worker-only lemmas. Two cases were
actually exercised under child-session `record_proofs=2`:

1. A genuinely new Pure theorem `!!P. PROP P ==> PROP P` is built with
   `Thm.assume`, `Thm.implies_intr` and `Thm.forall_intr`. Its exported theorem
   applies and rebinds the private theorem using Pure quantifier elimination and
   introduction. Both worker theorem names are absent from the receiver. The
   sender expands them, completes omitted annotations and strips unused bodies
   of approved named references. XML/YXML roundtrip and
   `Proof_Checker.thm_of_proof` reconstruct the exact theorem in the earlier
   receiver, with no hypotheses, premises or oracle dependencies. This **passes**.
2. A natural reflexivity alias expands through an unavailable anonymous warm
   parent theorem: header serial `36216`, theory `HOL.Nat`, empty name,
   proposition `OFCLASS(nat,type_class)`, body `MinProof`. The source has no
   unsupported top-level proof shapes; expansion yields one `MinProof`, and
   encoding/decoding preserves it. The checker rejects it as a partial proof.
   This **does not pass** and is not evidence that generic transport is impossible.
   The exact absent worker/private and anonymous headers and body shapes are
   recorded in the observations. A production reconstructor can investigate
   translating appropriate native sort evidence to checked `PClass` nodes or
   rebuilding that family locally. Neither repair is implemented by this probe;
   missing proof bodies must never be accepted as evidence.

An approved named `TrueI` reference separately survives transport. The receiver
rejects an unexpanded private reference, wrong exact target, oversized input,
explicit `Hyp` node and explicit `Oracle` node. It never evaluates worker ML,
methods, Isar commands or serialized theorem handles.

The receiver has a 100,000-byte cap before XML parsing and a five-second
interruptible deadline. It checks the exact expected proposition, no hidden
hypotheses, explicitly expected top-level premises and no oracle dependencies.
Named references resolve only in the approved receiving context; Isabelle checks
their proposition too. These are experiment bounds, not a security sandbox or
proven memory/stack limits. Production framing must bound allocation before
parsing, add nesting/node limits and use process resource controls. Allowed
sorts, axioms/definitions, ancestry, pending derivations and full dependency
policy remain C02 production admission obligations.

A fixed registered alternative accepts only a bounded Boolean list and claimed
natural count. It constructs the exact native target and invokes a fixed
receiver-owned simplification reconstruction from `count_true_refinement`.
Correct data yields a kernel theorem; a wrong count fails. Worker-selected proof
names, tactics and source text are absent. This is a concrete useful fallback
for this family, not a general proof language or acceptance of arbitrary programs.

A separate controlled elaboration recipe accepts a bounded natural offset and
constructs a typed lambda using native term constructors, then calls
`Local_Theory.define`. Its local intermediate theorem can retain its local
defining assumption. The probe checks the exported `recipe_shift_def` for a
closed sequent and no oracle and proves `recipe_shift n = n + 2`. An ordinary
worker does not supply definition commands or code setup. This recipe runs in the child after loading the already compiled base bundle:
it adds a native definition without invoking code generation for dispatch.
It does not yet reify or execute that recipe through a production plan interpreter.

## Execution evidence and costs

The final serialized driver exited **0**, `status=passed`, `inputs_stable=true`.
The independent preserved receipt is
`experiments/native-linkage/evidence/private-derivation-receipt.json`; the compact
observations are `private-derivation-observations.txt`. The prior alias-only
receipt is retained separately, with its unsupported result explicitly labeled.
These are run records, not serialized native authority. Native source/theorem
objects and the receiving checker provide the stated evidence.

```
python3 tools/dev/check-native --timeout 90 --session Native_Linkage_Probe \
  --session-root experiments/native-linkage \
  --expect 'LINKAGE private_implication_transport PASS'
```

| Measured path | Actual observation | Limit |
|---|---|---|
| Initial finite Base session | 8 s session elapsed; 2.775 s theory process elapsed | Includes proof, generation, compilation and heap output; not isolated compiler timing |
| Final transport child | 7 s session elapsed; 0.789 s theory process elapsed | Base reused from its pinned checked heap |
| Final driver | 21.375 s total; build command 16.209 s | Includes version/settings/build-log processes |
| Fixed native attachment | 10 repetitions, 320.921 ms elapsed / 165.158 ms CPU | Exact object/identity plus repeated transitive oracle audit; not complete C02 admission |
| Generated count on 100 flags | 10,000 repetitions, 48.538 ms elapsed / 18.100 ms CPU | Includes input/result construction and comparison; no application throughput claim |
| Successful private Pure proof | 94 bytes, 154.382 ms total expansion/reconstruction | One tiny proof, no scaling conclusion |
| Rejected natural alias | 7-byte `MinProof`, 0.399 ms expansion / 125.226 ms receiver | **Failure cost, not a successful certificate or proof latency** |

The shared driver uses one build job, two ML threads, workspace-local Isabelle
state and the shared build lock. macOS ARM64 / Isabelle2026-RC1 is the only
measured target. The installed Isabelle's `sysctl` inspection requires the
established elevated execution context on this machine; the sandboxed attempts
failed before theory compilation. No global Isabelle settings or parent heap
were changed, and no Analysis theory is imported.

Early attempts found and repaired source-symbol syntax, the RC1 simplifier API,
local-definition versus exported-theorem distinction, and anonymous proof
references. The partial-proof failure was isolated to the anonymous warm-parent sort proof
above. A genuine new private derivation subsequently passed; the alias remains
rejected. An overlong run combined full recording with 10,000 repeated native
dependency audits; it was interrupted, audit repetition reduced to ten and
recording isolated to the small child. That interrupted run is no performance
result.

The parent session saves its checked observations and measurement timestamp in
its heap. The transport child explicitly re-emits them with a
`BASE_HEAP_REPLAY` timestamp so the selected-session log retains the evidence.
A cached parent reuses those original measurements; re-emission is not a new
benchmark. Isabelle session dependency checking pins the parent sources/heap.

The invocation workload is intentionally tiny. It measures generated count on
100 flags, including packet/list construction, result construction and equality
check; it is not a bulk API or application speedup. Fixed attachment timing uses ten repetitions and covers
only native object/identity checks for this pinned instance. It excludes full
admission, dependency audit, compilation and host publication. Driver build time
includes process startup/session inspection/proving/code generation/heap output;
it is not isolated compiler latency. Proof-transfer size and receiver time apply
to the stated Pure implication proof only and cannot establish scaling for substantial
search theorems or private semantic developments.

## Remaining consumers

Registry/admission/staged-execution must jointly review and implement the actual
production accepted-object constructor, exact code setup/runtime artifact binding,
codec/representation policy and growth behavior. Authority consumes only an opaque
accepted handle whose native bridge is separately justified; metadata IDs alone
are insufficient. Host must own framing, process/resource control and durable
publication; no proof probe establishes those contracts. Sources/interpretation
must preserve native carriers, literal semantics and conditional scope rather
than adopting this probe's three-case packet as a global universe.

## Production integration following the probe

The staged execution implementation is a separate, currently unqualified consumer
of this evidence. Its dependency graph keeps semantic layers independent of
admission:

```
Codegen + SourceSemantics -> Execution_Core -> SourcePlans
SourceImport + SourcePlans -> RowPlans -> RowKernel
GenericAdmission + RowKernel -> SourceAdmission -> Execution
```

`RowKernel` owns the generated acquisition/query entry points and explicit finite
carrier mappings. It reuses the importer's reflected `source_batch` rather than
creating an ABI conversion. The combined native law states that successful
`acquire_and_query` preserves exact raw encoding, wellformedness, the manifest's
qualified observation, and the same requested query's native trace meaning.
The pure kernel has no accepted constructor. SourceAdmission must bind the
actual authenticated attempt and immutable requirements; generic Admission stays
family independent. Execution owns managed result lifetime and fixed callable
consumption. A declared snapshot or generation number does not replace that
association. These new interfaces require composed native checks before they
are qualified; the successful probe receipts above do not certify them.

The fixed row operation instance separately qualifies its actual generated
operation, staged component law, codec, metadata construction, projection and
positive modeled cost. Its pre-answer recipe accepts only bounded closed native
constructor metadata. The input certificate is checked against its declared
generation, then the unchanged term is certified and decoded in the public
kernel context. Private constants/types are rejected rather than unfolded or
discarded, and the recipe retains no arbitrary private input theory. This is
data canonicalization, not source authority: the original language/source
literal ownership and its exact request/reservation association must remain in
the admission/request owner. That composed provenance binding is still open.

The separate bounded projection primitive uses the generated reifier first in a
thread-local dry scope and then under an allocation budget. Oversized projections
must fail before constructing output term nodes. This addresses a concrete
allocation-order problem; it does not establish a bound on the native interpreter's
retained trace or qualify bulk acquisition performance. Bulk rows stay native
reflected carriers, rather than one certified term per row.

## Receiver-known class evidence: successful follow-up

The previous anonymous warm-parent obstruction is now repaired for a precise
supported case. The final source-pinned run is preserved in
`experiments/native-linkage/evidence/class-normalized-receipt.json` and
`class-normalized-observations.txt`. The unmodified expansion still diagnoses
`MinProof`; the additional normalization then transports the original private nat
alias successfully. This supersedes a general reading of the earlier failure:
it was an unavailable class proof body, not evidence that native private proof
transport generally cannot work.

Before expanding unavailable references, the sender replaces an unavailable
`PThm` only when its proposition is a concrete `Logic.dest_of_class` proposition,
its type instantiations are exactly `SOME []`, it has no term/type variables or
free parameters, and the earlier receiver's `Sign.of_sort` confirms that exact
class instance. The replacement is `Proofterm.PClass (T,c)`. The native proof
checker independently applies its `PClass` rule using receiver sort checking and
`Thm.of_class`; this does not add an axiom or accept an unavailable theorem name.
Approved receiver references remain unchanged. Other unavailable bodies are
reconstructed and traversed before ordinary private expansion/completion.

The repaired node was exactly serial 36216, theory `HOL.Nat`, empty name,
proposition `OFCLASS(nat,type_class)`. After normalization, private expansion,
completion, named-body stripping and inert YXML transport, the earlier receiver's
native `Proof_Checker.thm_of_proof` checked the original nat theorem. The proof
was 3,237 bytes; combined normalization/expansion/serialization/checking took
89.341 ms. The genuine private Pure implication also passed again at 94 bytes
and 61.089 ms. These are single bounded probe observations, not throughput or
large-search scaling measurements. The child session finished in eight seconds
with warm HOL; no parent heap rebuild or recording-policy change was needed.

The production admission sender must independently integrate and check this
normalization under its framing, policy, exact-target, hypothesis, ancestry and
oracle checks. Unsupported non-class `MinProof` bodies remain unsupported;
registered reconstruction still supplies a useful explicit alternative.

The final execution assembly is now explicitly a static functor consumer rather
than a globally installed executor. `Veri7vn_Row_Execution_Fn` receives the real
source-admission implementation and the restricted `Veri7vn_Effect_Tickets`
consume view. Its execute entry accepts a one-shot typed ticket carrying the
actual native association and executable pin; it has no pin-only dispatch entry.
The sole host state owner must persist the generated whole-plan charge and check
the actual operation/profile/association before issuing that ticket, then invoke
the fixed consumer in the same serialized handoff. Tickets are resource/lifecycle
capabilities, not theorems. The output retains the actual consumed execution
identity and the native implementation contract separately. This source is still
awaiting composed qualification with the source-specific admission and host
assembly; the independent projection and proof-transport checks do not prove
that integration.
