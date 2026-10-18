# Mechanics efficiency: preserved unfinished packet, 18 October 2026

This packet is **not integration-ready**. It adds a typed work-balance model and
connects both mechanism readers, but both permitted proof builds failed. No new
native was compiled, no operational alias was replaced, and no corrected
capability is claimed. Root retained the two-build limit and requested a source
checkpoint. The reserved independent root cases remain unopened by this owner.

## Candidate and consumer

Changed files are `src/extract/mechanics/Mechanics.thy`,
`Mechanics_Export.thy`, `recognizer.sml`, and the new `check_efficiency.py`.
The exact source copies, file modes and SHA256 inventory are in
`var/mechanics-efficiency/checkpoint/manifest.json`. No shared runtime, audit
record, other lane draft, upstream file or capability sidecar was changed.

The proposed `McWork work_request eta` retains efficiency with the requested
quantity. Both `mechanisms` and `mechanisms-v2` call `efficientMechanism`, which
constructs it after binding one labelled efficiency and requiring the expected
number of remaining numeric roles. Percent conversion is exported HOL arithmetic.
It supports actual pulley/lever advantage and effort, gear output torque, and
actual incline advantage. Explicitly ideal advantage and fixed gear/belt speed
ratios retain efficiency as context without applying it to geometry. Efficiency
must be between zero and one; effort division additionally needs positive
efficiency. Zero efficiency is accepted for determinable output quantities.

The reader requires an efficiency/eta label bound to its number, rejects leftover
or duplicate numeric roles, and distinguishes requested ideal/actual advantage.
It does not treat an unrelated percentage as efficiency or `non-ideal` as ideal.
It normalizes lifting verbs for both versions. Actual advantage without a supplied
efficiency is withheld. Direct force/arm torque and shaft/transmission power with
explicit efficiency remain a scoped missing-model boundary; they are counted as
valid withholds in the challenge, not expanded capability. No power-model
expansion was attempted.

## Proposed theorem statements, not a passed proof

The independent balance predicate is
`output * output_travel = eta * (input * input_travel)`.
The candidate accepted-output theorems connect it to:

- Pulley effort: `load_N * h = eta * (effort * (strands * h))`, with positive
  whole supporting-strand count, nonnegative source load and positive efficiency.
- Lever effort: `load_N * (load_arm * theta) = eta * (effort * (effort_arm * theta))`,
  with positive arms, nonnegative source load and positive efficiency.
- Gear torque/power: `output_torque * (driver_teeth * omega) =
  eta * (input_torque * (driven_teeth * omega))`, with positive whole tooth counts.
- Actual advantage: pulley `MA = eta * strands`, lever `MA * load_arm = eta * effort_arm`,
  incline `MA * height = eta * length`, with their geometry domains.
- The lever source-unit theorem connects original length magnitudes and scale
  factors, N versus kg load conversion through standard gravity, percent/100,
  source domain bounds and the accepted effort balance.
- At efficiency one, all six actual formulas equal the existing ideal request's
  rational value. Separate statements preserve ideal advantage and gear/belt
  kinematics independently of efficiency.

Exports name these constructors and theorem roots and include representative
self-tests. These declarations are source drafts until the whole session passes.
There are no new axioms or admitted proofs.

## Exact checks and failures

1. `20261018T110439Z-be799715d943`: normal managed persvati build,
   `Veri7vn_Mechanics`, exit 1. Isar syntax used `have f =` rather than `note f =`
   in the source-unit theorem. Receipt and complete build log:
   `var/mechanics/remote-attempts/20261018T110439Z-be799715d943/receipt.json`
   and `results/build.log`.
2. `20261018T110656Z-669cfce54162`: one bounded repair build, exit 1.
   `accepted_efficiency_domain` supplied the universally quantified
   `exact_facts` theorem as a premise without instantiating it; four domain
   subgoals remained. The asynchronous failure was reported at export.
   Receipt and complete build log:
   `var/mechanics/remote-attempts/20261018T110656Z-669cfce54162/receipt.json`
   and `results/build.log`.

The source-only final repair changes that proof and the analogous actual-advantage
proof to `auto dest: exact_facts`. It has **not been rebuilt**. The second snapshot
also included the operation-specific zero-efficiency domain and repaired Isar
syntax. Reader-only changes after its snapshot are covered by a static Poly/ML
check: 202 reader invocations, zero unexpected refusals among supported valid
cases. Its work constructors are stubbed; this is not native arithmetic evidence.
`git diff --check` passes for the owned source.

The old operational binary remains
`bd4012b913766a9fcd25c918fabb47f819353321a67cf2091691d6220e4fb672`.
Its proof receipt remains `20261018T103739Z-4f76d5174bac`, marker
`VERI7VN_MECHANICS PASS theorems=78 oracles=0`; its compile manifest remains
`var/mechanics/native-attempts/20261018T104545Z-f11dc9553f17/compile-inputs.json`.
`operational-aliases.json` confirms unchanged binary, canonical generated export,
proof receipt and canonical compile receipt identities. The actual narrow native
verifier accepts that immutable historical binding and correctly reports current
proof/runtime source differences in `baseline-binding-current.json`.
There is no matching new proof/native binding and no new actual consumer check.
Both submitted jobs are terminal; no owner job remains running.

## Scoreboard: old native only

The explicit two-ID run uses each specialist's own shipped scorer:

| ID / panel | Right | Wrong | False yes | Valid withheld |
| --- | ---: | ---: | ---: | ---: |
| mechanisms shipped (54 dev + 64 heldout) | 118 | 0 | 0 | 0 |
| mechanisms-v2 shipped (63 dev + 55 heldout) | 118 | 0 | 0 | 0 |
| mechanisms fresh original generator, new seed offset | 116 | 0 | 0 | 0 |
| mechanisms-v2 fresh original generator, new seed offset | 119 | 0 | 0 | 0 |
| mechanisms authored challenge, 101 requests | 38 | 49 | 14 | 0 |
| mechanisms-v2 authored challenge, 101 requests | 39 | 48 | 14 | 0 |

The fresh source generator offset is 20261018031. The old binary passes 38/101
and 39/101 challenge policy assertions respectively; those assertion counts are
separate from capability counts. Raw cases, replies, scorer details and fresh
panels are in `var/mechanics-efficiency/baseline-final-checks.json` and adjacent
files. These numbers do not evaluate the proposed correction.

## Resume boundary

`var/mechanics-efficiency/ready.json` records `ready_for_integration: false`, the
source-only repair and the failed receipts. A future authorized proof attempt
would run:

```sh
python3 tools/dev/remote-build persvati src/extract/mechanics Veri7vn_Mechanics \
  -d src/extract/commons --expect 'VERI7VN_MECHANICS PASS'
```

Do not compile against the old export while these new reader constructors are
present. After a passed proof, the remaining gate is the actual narrow current
source/native verifier, the two shipped scorers plus fresh/authored/root cases,
and a scoped real consumer. Immutable capture and Linux/package follow-through
belong to root. This packet has stopped with a recoverable draft; it has no
successor and no commit or push from this owner.
