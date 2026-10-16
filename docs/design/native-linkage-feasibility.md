# Native linkage and proof transport feasibility

Bounded Isabelle2026-RC1 evidence for D14/D25/D26 and C01–C04. Experiments under
`experiments/native-linkage/` establish specific linkage/transport mechanisms, not
the production gate, host or complete finite linker.

## Concrete linkage

A generated finite packet covers `nat`, `bool`, `bool list`, with exhaustive dispatch
and `None` for wrong carrier/operation pairs. Actual theorem statements include:

```text
increment_link: dispatch Increment (Nat_Value n) = Some (Nat_Value (n+1))
conversion_link: dispatch Is_Zero (Nat_Value n) = Some (Bool_Value (n=0))
count_true_refinement: length (filter id xs) = card {i. i<length xs ∧ xs!i}
count_link: dispatch Count_True (Flags_Value xs) = Some (Nat_Value (count_true xs))
```

`packing_injective` supplies constructor injectivity. Link checks audit zero
hypotheses/premises/oracles and execute generated constructors/dispatch from the
same code antiquotation. The packet is finite execution, not universal HOL.

The fixed attachment checks actual dispatch term, theorem proposition, constructor
and exact generating theory. It rejects swapped representation/theorem, hidden
`False`, changed `Code.declare_unimplemented_global` and removed target serializer.
It conservatively rejects even harmless descendants; production needs a curated
object/code closure. Value-generation checks prevent cross-bundle invocation;
no migration or source-premise discharge is implied.

## Bounded inert transport

The receiver predates worker-private lemmas. Private Pure implication transport
passes after expansion, completion, approved-reference stripping, YXML roundtrip
and `Proof_Checker.thm_of_proof`. Approved `TrueI` references survive. Wrong target,
private unexpanded reference, oversized bytes, explicit `Hyp` and `Oracle` are rejected.

An unavailable warm-parent nat class proof is supported only by a precise checked
normalization: replace an unavailable `PThm` with `PClass(T,c)` when its proposition
is a concrete `Logic.dest_of_class`, instantiations exactly `SOME []`, no variables/
free parameters, and receiver `Sign.of_sort` confirms it. The receiver independently
checks through `Thm.of_class`. Other missing `MinProof` bodies remain unsupported.
No axiom or arbitrary worker source is imported.

The receiver bounds input to 100,000 bytes and an interruptible five seconds, checks
exact target/premises/hypotheses/oracles and approved references. These are experiment
bounds, not a sandbox or proven stack/memory limits. Production also needs nesting/
node/decompression controls, declaration/sort/ancestry policy and process limits.

A registered Boolean-count certificate reconstructs from receiver-owned refinement;
a wrong count fails. A bounded natural-offset recipe constructs typed terms through
`Local_Theory.define`, exports a closed oracle-free definition and proves
`recipe_shift n = n+2` without rebuilding dispatch. Neither is arbitrary proof text
or completed production recipe execution.

## Execution evidence and costs

```sh
python3 tools/dev/check-native --timeout 90 --session Native_Linkage_Probe \
  --session-root experiments/native-linkage \
  --expect 'LINKAGE private_implication_transport PASS'
```

Source-pinned receipts under `experiments/native-linkage/evidence/`:
`private-derivation-receipt.json` and `class-normalized-receipt.json`, with corresponding
observations. Final class-normalized transport checked a 3,237-byte nat proof in
89.341 ms and a 94-byte Pure proof in 61.089 ms; warm child elapsed eight seconds.
These single bounded cases do not establish throughput/scaling. Cached-parent log
re-emission is not a new measurement. All runs use the shared lock/local state,
one build/two ML threads, macOS ARM64 and warm HOL.

## Production integration following the probe

```text
Codegen + SourceSemantics -> Execution_Core -> SourcePlans
SourceImport + SourcePlans -> RowPlans -> RowKernel
GenericAdmission + RowKernel -> SourceAdmission -> Execution
```

RowKernel reuses reflected `source_batch` carriers. Its `acquire_and_query` law connects
raw encoding, wellformedness, qualified observation and requested trace meaning.
Pure kernels cannot construct accepted evidence. SourceAdmission must bind authenticated
attempt and immutable request/reservation; numbers alone are insufficient.

The fixed row instance checks generated operation, staged component law, codec,
projection and positive modeled cost. Metadata canonicalization accepts bounded closed
constructors in public context; private constants/types are rejected. This does not
replace original literal custody. Projection dry-runs the reifier before budgeted
allocation to reject oversized output before term construction; it does not bound
retained trace or bulk acquisition cost.

`Veri7vn_Row_Execution_Fn` consumes actual source admission and one-shot
`Veri7vn_Effect_Tickets`, with no pin-only dispatch. The host must persist whole-plan
charge, validate operation/profile/association and invoke in the same serialized
handoff. Outputs retain consumed execution identity separately from implementation
contract. Tickets are lifecycle/resource authority, not theorems. These production
consumers require their own composed qualification; probe receipts cannot supply it.
