# Anatomy and agriculture: complete questions and rectangular planting grids

Owner: Codex natural/life_anatomy. Ready for integration: the hbox proof
receipt passed and the binary from that exact export passed the shipped
panels, three fresh seeds and all targeted probes.

Anatomy now reads both ordinary and inverted superlative phrasing across its
six supported facts. Both anatomy versions reject animal questions unless they
also explicitly identify humans; their table describes human anatomy.

Gardening gains rectangular row/plant spacing. The question names the side along which rows run; when a nonsquare bed has
unequal spacings and no orientation, the kernel receives an explicit request
to decline. The result is floor(row length*12/plant spacing) times
floor(width*12/row spacing), reserving one complete spacing cell per plant.
The response states this convention. Zero spacings decline; negative
dimensions are not silently made positive. The answer uses the existing
`plants_grid` kind.

## Baseline

Each cell is right / wrong / false yes / valid withheld; correct declines are
right. The kernel and current shipped organ agree on all these panels.

| Specialist | Shipped dev | Shipped heldout |
|---|---|---|
| anatomy | 11 / 0 / 0 / 0 | 10 / 0 / 0 / 1 |
| anatomy-r2 | 11 / 0 / 0 / 0 | 10 / 0 / 0 / 1 |
| agriculture-v2 | 17 / 0 / 0 / 0 | 17 / 0 / 0 / 0 |
| gardening | 15 / 0 / 0 / 0 | 15 / 0 / 0 / 0 |
| nutrition-label-v2 | 32 / 0 / 0 / 0 | 16 / 0 / 0 / 0 |

Fresh generator offsets 10181001 and 10182003 give the same counts in both
splits. Offset 10183007 is reserved until tuning ends. The seeds change sample
selection; they do not provide independently authored templates or formulas.
Receipts: `var/anatomyagri/c-baseline.json` and
`var/anatomyagri/c-beyond/before-*.json`.

The 23 committed hand probes name their assumptions and expected values.
The old kernel and organ each get 8 right, 1 false yes and 14 valid withheld.
The false yes applies the human skin fact to cats. These are same-author probes,
not independent evidence. The final binary gets all 23 right, with no wrong answers or false yes.

## Binding statements

- A seeds-needed request declines for germination exactly when the percentage
  is outside (0,100].
- If a square-grid request returns v and its physical dimensions are
  nonnegative, then v*s^2 <= (length*12)*(width*12).
- If a rectangular-grid request returns v, its spacings are positive, its
  dimensions are nonnegative and v*plantSpacing*rowSpacing is at most the
  bed's area in square inches.
- The returned acre-inch volume differs from inches*acres*3630*7.48052 by at
  most inches*acres/2 for nonnegative inches*acres. This connects the rounded
  27154 gallon constant to cubic feet and gallons per cubic foot.

All existing table checks still pass. The binary was 405112 bytes; baseline
startup was 5–10 ms after the first cold filesystem load (129 ms). Consumer
and packaging use the same existing answer kinds. The build script requires `VERI7VN_GENERATED` to name the ML file from a
successful immutable build attempt. It has no stale canonical-export fallback.

## Build progress

Attempt `20261018T063748Z-3ff5ecfc4d22` on persvati proved the grid-fit and
germination statements but failed the final absolute-value arithmetic step in
`acre_inch_derived_error`. Its algebraic conversion factor identity passed.
The bound is repaired using `abs_le_iff` without expanding the nonnegative
product into unrelated absolute values. The retry waited for the build owner’s queue clearance. The successful
receipt and completed post-build tests below supersede that checkpoint.

## Final evidence

The final hbox attempt `20261018T071715Z-05740f647bba` passed with
`VERI7VN_ANATOMYAGRI PASS theorems=54 oracles=0`. The first retry failed
because of an invalid proof-method name; replacing it with `intro conjI`
completed the two required linear bounds. No statement was weakened.

| Specialist | Final shipped dev | Final shipped heldout | Previous heldout right |
|---|---:|---:|---:|
| anatomy | 11/11 | 11/11 | 10/11 |
| anatomy-r2 | 11/11 | 11/11 | 10/11 |
| agriculture-v2 | 17/17 | 17/17 | 17/17 |
| gardening | 15/15 | 15/15 | 15/15 |
| nutrition-label-v2 | 32/32 | 16/16 | 16/16 |

Pinned-specialist and whole-family dispatch both score 156/156, wrong 0,
false yes 0, valid withheld 0, against the re-evaluated organ's 154/156.
Older upstream recorded verdicts are different and are not the comparison
claimed here. Two development offsets 10181001/10182003 and the untouched
offset 10183007 each score 156/156 with zero errors. The untouched set was
first generated after tuning ended. These are new samples of the author's
templates. Hand probes score 23/23 versus the organ's 8/23, 1 false yes and
14 withheld; these are explicitly same-author probes.

The binary is 427800 bytes, SHA-256
`ed9e62f0d90f3b5097459f7b5ab5cdba08ba9b789620f9759a7bd669cdb1851a`.
The successful generated ML SHA-256 is
`0e2a9fec96ac3131ad2cb7a6e593b3abaa8fc3d4f0109ba3054f28261036153c`.
Five fresh-process starts took 189.6, 5.8, 4.3, 6.4, 5.8 ms; the first
filesystem-cold launch remains visible. All specialist medians are below 1 ms.
Receipts are `var/anatomyagri/c-after.json` and the three after/untouched
files plus `probes-after.json` under `var/anatomyagri/c-beyond/`. Frozen
artifacts and exact source hashes are in `var/anatomyagri/c-delivery/ready.json`.

The model is bounded: rectangular full spacing cells do not answer arbitrary
edge planting or staggered layouts, and the anatomy table does not establish
individual anatomy or other species. The semantic gap ledger for subsequent
work is `var/life/d-next/semantic-gaps.md`.
