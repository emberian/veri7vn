# Native proof consumer closure

## AC-01 — Contextual hypotheses survive managed proof production

Status: in progress; native child submitted to the shared execution steward.
Obligations: PO-04, PO-08/09 (retained recipe association), PO-10 (producer
lifetime); C02. This is a conformance fixture, not establishment of those complete
formal obligations or qualification of TB-01–05.

Replay: session `Veri7vn_Assurance_Consumer_Tests`, directory
`tests/integration/assurance`, through `python3 tools/dev/check-native` and the
shared build coordinator. No independent Isabelle build is authorized here.

The fixture uses the actual `Proof_Transport.export` producer. Its principal
candidate is `Thm.assume True`: proposition `True`, contextual hypothesis
`True`, no explicit premises. This is a valid *conditional* native consequence;
its proof uses a local hypothesis and therefore must retain that condition. The second candidate is
`False ==> False`, whose explicit premise must separately survive transport.
No new axioms, oracles, proof skipping or callback validators are introduced.

The authoritative native path tested is:

1. `Proof_Transport.receive` reconstructs a theorem using Isabelle's proof checker
   and invokes `Native_Admission.admit` under the pinned receiver policy. Admission
   compares the complete target, hypotheses, premises, sorts, flex-flex constraints,
   ancestry and transitive oracle dependencies. Missing hypotheses, missing
   explicit premises and a changed target reject.
2. `Managed_Provenance.prove_from_slice_sequent_owned` parses the exact retained
   source slice, takes the requested conditions from the complete snapshot,
   reconstructs the transported theorem, compares the complete sequent, admits
   again and publishes an owned native consequence. The default unconditional
   producer rejects the contextual hypothesis. A snapshot of unconditional True
   also rejects the same conditional wire.
3. `Native_Descriptor.register_produced` consumes that opaque consequence and
   projects `conditional`, premise identities and actual source dependencies.
   The fixture resolves the native contextual premise identity back to True; projection
   booleans alone are insufficient evidence. A plain admitted descriptor explicitly
   lacks managed source provenance.
4. The actual producer's retained `proof_recipe` stores the wire and full native
   sequent. The stored comparator accepts the retained theorem and rejects TrueI,
   despite the identical conclusion. Releasing the actual development makes the
   produced descriptor non-live and prevents native target resolution.

Existing coverage overlap is deliberate and bounded: `tests/admission` tests
isolated admission/transport errors; `Registry_Tests` tests sequent serialization;
`Expert_Recovery_Tests` already carries a theorem with an explicit premise through
qualify, committed material, replay and recheck. AC-01 adds the *contextual
hypothesis* negative/positive producer path and its live descriptor association.
It does not claim a new durable-restoration test or duplicate that broader suite.

No domain algorithm correctness theorem is used here. Native HOL `TrueI`,
assumption and implication introduction produce the test sequents; the real kernel
checks their reconstructed proof terms. The admission and managed-source ML gates
are implementation components being tested, not proved HOL refinements. The
conditional preservation theorem in `Veri7vn_Authority_Proofs` does not by itself
verify this ML path. TB-01 native attachment, TB-02 proof-term/compiler/runtime,
and the pinned image remain assumptions; this fixture neither verifies the OS nor
licenses a world-truth rendering. It does not exercise resident authority commit,
durable acknowledgement, external effects or final emitted bytes.

Consumers invalidated by changes: proof transport, admission request comparison,
managed proof producer/recipe format, native sequent serialization/comparison,
native descriptor condition/provenance projection and managed lifetime semantics.
D43/D53 request authority migrations are intentionally not instantiated by this
independent child; their integrated resident consumers remain separate work.
