# Proof consumer conformance

AC-01 targets C02, PO-04, retained-recipe association under PO-08/09, and producer lifetime under PO-10. [Veri7vn_Assurance_Consumer_Tests](../../tests/integration/assurance) is submitted to the shared steward; no native pass is recorded here.

The actual chain is `Proof_Transport.export/receive` → `Native_Admission.admit` → `Managed_Provenance.prove_from_slice_sequent_owned` → `Native_Descriptor.register_produced`. `Thm.assume True` tests a used contextual hypothesis; `False ==> False` tests an explicit premise. Erasing either condition or changing the target rejects. The managed producer parses the original slice and compares the complete sequent; its unconditional convenience API rejects the conditional wire.

The fixture resolves projected premise IDs to native terms, checks source dependencies, and compares the producer's stored `proof_recipe` sequent. Unconditional `TrueI` cannot replace conditional True despite the equal conclusion. Releasing the development revokes descriptor access; plain admission does not supply managed provenance.

Admission tests cover isolated gate errors; Registry tests cover serialization; `Expert_Recovery_Tests` already checks explicit-premise durable reconstruction. AC-01 adds contextual-hypothesis producer/lifetime composition. It does not prove the ML gates, qualify TB-01 or TB-02, verify resident acknowledgement or emitted bytes, or establish full PO closure. Changes to transport, sequent format, producer, descriptor or lifetime semantics invalidate this fixture's evidence.

The fixture remains independent of D43/D53 authority migration; it does not qualify their resident consumers.
