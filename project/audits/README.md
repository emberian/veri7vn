# Reviewed specialist evidence

Each `*.audit.json` records concrete requests, actual observations, independently
justified expectations, the examined model, and remaining limits for one exact
specialist ID. The default coverage command reads this tracked directory:

```sh
python3 tools/dev/specialist-coverage.py --json-out var/coverage/inventory.json \
  --markdown-out var/coverage/inventory.md
```

`--audit-dir` can select a separate working directory. A record's presence is
not a completed audit. The tool checks shape, referenced files and optional
native hashes; it does not validate the author's semantic judgment. Local
native/proof receipts under `var/` are required to recheck those bindings. Their
absence on another checkout is missing evidence, not evidence of correctness.
The compact observations under `evidence/` remain readable without those assets.
Historical observations bind the immutable native-attempt binary, not a mutable
production alias. A later source change is reported as drift and does not erase
the earlier observation.
Do not commit corpora, generated heaps or native binaries here.

## Current reviewed surface

Nine of 305 IDs have **partial** explicit records: `physics`, `physics-r2`,
`physics-r3`, `bodies-v2`, `mechanisms`, `mechanisms-v2`, `sports`, `fleet`, and
`fluids-r2`. The other 296 have no explicit record here yet. This does not mean
those IDs have never been worked on; older lane reports remain evidence leads.
None of these nine records claims exhaustive semantic coverage.

The initial review ran 22 hand-authored questions directly through the final
Mechanics native `bd4012b9…`. These are pinned-reader observations, not fresh
shipped-panel scores or tests of the selected portable package. Review found:

| Result | Observations | Interpretation |
|---|---:|---|
| Right | 14 | Includes the correctly refused impossible batting line |
| Wrong numerical answer | 2 | Same efficiency defect in the two mechanism readers |
| Requested output unit ignored | 1 | Fleet gives equivalent US volume instead of requested Imperial volume |
| Valid request withheld | 5 | Four potential-energy requests mentioning drag, plus supplied-gravity pressure |

Two initial probe expectations were corrected during review, with the initial
expectations preserved in the receipt. Sports' displayed winning-percentage
formula reports a fraction, so 0.639 correctly represents 23/36. Drag does not
prevent computing a gravitational potential-energy difference from its
endpoints under constant gravity; the four refusals therefore remain capability
misses. A checked refusal theorem does not establish that refusing was useful.

A further eight efficiency probes distinguish the requested quantity: both
mechanism readers ignore efficiency in gear torque, lever effort and **actual**
pulley advantage (six wrong observations). Both correctly answer the **ideal**
pulley advantage with the same efficiency supplied. Thus the shared fix needs
request-specific work balance, not a blanket efficiency refusal or one factor
applied to every result. The records now contain 30 observations: 16 right,
eight wrong numerical answers, one ignored output unit and five valid withholds.

## Actionable work from this review

1. **Mechanisms efficiency:** both `mechanisms` and `mechanisms-v2` return
   100 N for four supporting strands, a 400 N load and 50% efficiency. The
   work balance requires 200 N. The reader discards efficiency; its existing
   theorem proves only the ideal request. Add efficiency to the request and
   prove the corresponding work balance, and cover the now-confirmed gear/lever defects in the same model. Inspect
   belts and other condition-dependent requests for the same missing-input class. Do not merely widen a parser keyword
   or treat the response's “ideal” qualifier as permission to ignore a given.
2. **Fleet output volume:** an explicit Imperial-gallon output request returns
   4.804 US gallons for 100 miles at 25 Imperial mpg. Preserve output units
   independently of the input economy unit and return 4 Imperial gallons.
   Review trip-price volume units through the same model.
3. **Quantity-dependent physical conditions:** all four gravity wrappers
   withhold a potential-energy request just because it mentions drag. Keep the
   drag restriction on fall-time and impact-speed models, but allow quantities
   whose stated governing equation does not depend on that condition. Avoid
   removing the guard wholesale.
4. **Pressure with supplied gravity:** the fixed-property reader safely
   withholds a computable 4000 Pa request. A richer typed pressure request is
   needed before claiming this capability.

No production source, proof or package changed during this audit. It ran after
all deputies drained, without restarting them or submitting a build. The six
focused coverage-tool tests pass; the actual record ingestion result is in the
continuation ledger. Remaining coverage spans every unexamined request class,
all other specialist IDs and all relation readers; there is no completion claim.

The later bounded efficiency implementation is preserved but unproved:
[attempt and exact resume state](../lanes/G-mechanics-efficiency.md). Both proof
attempts failed, the final source-only repair is unbuilt, and the observed old
native remains active. The efficiency findings above therefore remain open.
