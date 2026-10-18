# Space logarithm range reduction — G packet

Stopped at the final drain boundary. The prior adaptive packet was committed
as `52de506` and its immutable native capture completed before production
work reopened. This G packet has no passing proof/native and no new shipped
panel numbers. It is an unfinished source checkpoint, not an integration-ready
capability packet. No successor or fifth proof attempt was launched.
The released F baseline remains 1185/1185 pinned, 1183/1185 family, and is
preserved at `var/space/native-attempts/20261018T100614Z-406f8fff31a2/binary`.

## Actual numerical obstruction

The valid free-space path-loss question at 1 GHz over 1 km was refused as
`imprecise` by both original 80-bit and adaptive 32/80 evaluation. The typed
model uses distance in km, frequency in MHz, and constant 32.4478; its
logarithm argument is 1000, not 1. An untrusted diagnostic copy of generated
code measured Ln(1000) bounds 6.90762510285..6.90787783106 at 80 bits. The resulting
path-loss interval 92.4466693045..92.4488644739 is wider than the existing
checked-decimal criterion allows. 160 bits succeeds, but a global precision
increase would preserve the inefficient expression.

The library's large-argument logarithm branch reduces by a power of two and
then evaluates a series directly on mantissa minus one. For 1000 the residual
mantissa is 1.953125, near the slow end of that series. A smaller-argument
branch has an additional reduction. Exposing the small argument explicitly
lets that existing verified branch run.

## Intended production change and proof obligations

`Space_Log.thy` imports existing `Commons_Num` arithmetic. For positive exact
rational q=n/d, its exponent k is `bitlen n - bitlen d`; bit length is the
library's terminating computation. The normalized rational is
`m=q/(2^k)`, with signed exponents represented exactly as rational powers or
reciprocals. There is no arbitrary search fuel.

The new statements assert:

- `q = m * 2^k`, using the exact rational definition of the power.
- Positive q implies `1/2 < m < 2`, using the bit-length/floor-log facts.
- Positive q implies `ln(q) = ln(m) + k*ln(2)` over the real interpretation.
- Interpreting the generated expression yields `ln(q)` for every rational q;
  the nonpositive branch retains the original logarithm expression.

The production free-space path-loss expression uses the reduction for its
positive distance-frequency product and denominator ln(10). The ideal rocket
expression uses it for initial/final mass ratio. The existing path-loss and
rocket physical laws remain independent equations; they must still prove
against these changed expressions. The existing adaptive enclosure theorem
then binds the actual returned decimal to the original function. No
recognizer, domain guard or accepted kind changes.

## Checks prepared

Twenty authored probes use 70-digit Decimal references with the exact model
constants. They cover reciprocal extremes 1e±12, unit mantissa, values around
1.5/2, and rocket ratios near 1 and as large as 1e9. The tiny-distance path-loss
probes exercise the stated mathematical model; they do not certify physical
far-field applicability, which this model does not guard.

The captured F baseline scores 17 right / 0 wrong / 0 false yes / 3 withheld-valid in
both pinned and family modes. The three valid withholds are path-loss
products 0.001 and 1000, and rocket mass ratio 1000. Fresh seed 20261127 was
generated and remains unopened until final production freeze. Orbits and
spacecomms still have no shipped generators.

Current managed proof: first attempt 20261018T101632Z-13a4f71794b5 failed on
rat-to-real coercion and logarithm quotient rewrite obligations. Follow-up
20261018T101854Z-ddd80c993b7c still exposed the same two arithmetic rewrite
obligations. The batched repair 20261018T102230Z-35f64f092024 discharged those
obligations, then rejected an extra terminal tactic after simplification
had already solved the goal ("No subgoals!"). That proof-script sequence
was repaired in the final attempt 20261018T103318Z-6ca1a90c52fa. That
attempt finished with a single reported proof failure at Space_Log.thy:64:
real bounds `1 < rl(m)*2` and `rl(m)<2` were not transported to the
corresponding rational bounds. The exact final goal is in its
`results/build.log`. The whole session failed; its Space theory timing was
35.277 seconds, but that is not a passing dependency closure. No failed
export was published and no G native was compiled.
No passing theorem claim is made for G. The untrusted generated-code
prototype answers 20/20 focused model probes; this is preparation evidence,
not a replacement for the production proof/native.

Scratch evidence: `var/c-physical-mechanics-space/next/fspl-diagnosis/` and
`var/c-physical-mechanics-space/next/logarithms/before.json`. Production
probe data and checker are `src/extract/space/log_probes.json` and
`check_log_probes.py`; the checker counts a valid refusal as withheld-valid.


## Exact stopped state and resumption

Owned unfinished source files are `src/extract/space/ROOT`, `Space_Log.thy`,
`Space.thy`, `Space_Export.thy`, `main.sml`, `log_probes.json`,
`check_log_probes.py`, and this report. The recognizer, tables, shared modules,
README and F report are unchanged. The production candidate source is left
at the exact failed attempt; no unverified proof repair was applied afterward.

The final failed receipt is
`var/space/remote-attempts/20261018T103318Z-6ca1a90c52fa/receipt.json`.
`var/c-physical-mechanics-space/next/logarithms/resume-state.json` records
source hashes, preserved native identity and the remaining commands.
`range-coercion-next.txt` in that directory proposes explicit endpoint
coercions followed by the forward `of_rat_less` equivalence; it is untested.
A later resumed task should inspect/apply that narrow repair, run the managed
Space proof, and only then compile through the immutable native helper.
The exact managed command is recorded in that file. Current drain explicitly
allows no further retry, so none is running.

Seed 20261127 remains unopened. After a successful future source/native freeze,
score the shipped panels, both authored probe sets, that reserved seed, and
actual family/dispatcher consumers. Reconcile all source and compiler-input
hashes before asking root to integrate. The untrusted numerical prototype
20/20 remains diagnostic evidence only; the measured production baseline is
17/20 for these new logarithm probes, with three valid withholds.
