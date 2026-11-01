# Mechanics efficiency: preserved unfinished packet, 18 October 2026

**Update:** root subsequently resumed and integrated this packet. The historical
failed-build account below is retained; see the root integration section at the
end for the passed proof, actual native results and current limitations.

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

## Root integration after resumption

Root resumed the retained proof repair under ember's instruction to continue
one bounded implementation at a time. Managed proof
`20261018T114331Z-9170cf0370b1` passed **98 scanned statements, zero oracles**.
The work-balance and source-unit statements above are now passed statements
connected to `McWork`, `qval`, `kernel` and `reply_of`. No statement was weakened
for this resumption. Root added their names to native response provenance.

Managed compile `20261018T114559Z-c4abe7e403d9` binds the current proof closure,
export and actual reader/driver. Current proof/runtime verification matches.
Native SHA256 is
`45a9985223c03c4fc31f098afbfd89b5c94a847f5fbaeec1f6d2fa8e01249eb6`;
it is active at `var/mechanics/bin/mechanics`. The predecessor is retained.
The immutable capture is
`var/C-runtime-package/bound-prepared/20261018T114559Z-c4abe7e403d9/mechanics`.

Measured results:

- Both mechanism IDs: 118/118 own shipped cases each, zero wrong/false yes.
- Fresh generator panels: mechanisms 116/116, mechanisms-v2 119/119.
- Authored challenge: each reader improves to 100 right, zero wrong/false yes,
  one valid withhold out of 101. Those 100 comprise 85 numerical answers and
  15 correct invalid refusals. All 101 expected-behavior assertions pass.
- Root's previously reserved work-balance cases: 37/37 for each reader, and
  37/37 through the actual full dispatcher using the candidate native.
- The six earlier audit questions per reader now all answer correctly. Together
  with the reserved cases, 86 direct observations are recorded in
  `project/audits/evidence/mechanics-efficiency-20261018.json`. Both audit records
  now reference the current immutable native; the old observations are retained.
- The shared nine-ID mechanics family passes 1264/1264 shipped cases in both
  isolated and family modes, zero wrong/false yes/valid withholds. This checks
  the shared request/kernel change against the other family readers.
- Managed Linux receipt
  `var/linux/receipt-mechanics-persvati-mechanics-1792324110-90169.json` records
  1264 freshly scored replies identical to macOS, all correct. Its 46 withheld
  replies are correct invalid refusals, not capability misses.

The remaining challenge miss is output shaft power with supplied efficiency.
Contrary to the draft's anticipated boundary, direct local force-times-arm
wrench torque already answers correctly; the check now requires that answer.
The reader leaves this unrelated efficiency outside the transmission model.
Broader friction, variable geometry and compound transmission semantics remain
unexamined. Fleet's independently recorded unit defects are also unchanged.
The English field assignments and model applicability are untrusted.

Exact integration and local test hashes:
`var/root-mechanics-efficiency/resume/integration.json`. The audit inventory
accepts all nine explicit records; that is partial coverage of 305 IDs, not
system completion.

Scoped portable packaging also passed. The nine-folder macOS/Linux archive is
`var/root-mechanics-efficiency/resume/portability/package/veri7vn-specialists-2026-10-18.tar.gz`,
850,812 bytes, SHA256
`e3b91759a73b88dbb4fd3fbb35ad162c0c29f47866a2657eb9664c6b71407fb6`.
It pins shared consumers to `af9605d`. After relocation outside the checkout,
both platforms again score 1264/1264 shipped cases with identical replies.
All 276 mechanism capability assertions also pass with identical replies:
236 numerical answers, 38 correct invalid refusals and two valid withholds
(the output-shaft-power case for each reader). Those withholds remain gaps.
The capability set combines each reader's 101 authored and 37 reserved cases;
it is separate from the shipped panel score.

Exact package and evidence hashes are in
`var/root-mechanics-efficiency/resume/portability/delivery.json`. The full
144-specialist archive has not been refreshed with this repair. No proof,
compiler, remote test or implementation job remains from this bounded step.
