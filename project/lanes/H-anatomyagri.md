# Anatomy/agriculture H: calories for the requested portion

The frozen G binary returned 165 kcal for a 250 g serving when the label listed
10 g protein, 20 g carbohydrate and 5 g fat per 100 g. Those supplied nutrients
provide 165 kcal per reference portion; the requested portion requires 412.5
kcal under the general Atwater model. H carries both portions through the
kernel rather than discarding the label basis.

Reference and requested portions are typed as mass or serving count. Same-unit
quantities scale by their ratio. Crossing grams and servings requires a stated
positive serving mass. The reader converts kilograms and milligrams exactly,
retains signed/fraction/scientific values, and refuses malformed or conflicting
roles. A target in an unsupported unit cannot disappear and leave a plausible
but unscaled answer. Structured labels can state their basis, serving mass and
question in separate sentences; the old blanket sentence cutoff excluded that
useful form before any arithmetic ran.

## Results

The final shipped panels pass 156/156 in both specialist and family dispatch,
with zero wrong answers, false yes answers or withheld-valid requests.
Development offsets 10181001 and 10182003 and untouched offset 10192063 each
pass 156/156. All 158 same-author policy assertions pass; capability is 136
right, zero wrong, zero false yes and 22 withheld-valid. On the same questions,
frozen G has 112 right, 9 wrong, 10 false yes and 27 withheld-valid. The shipped
organ has 34 right, 33 wrong, 39 false yes, 37 withheld-valid and 15 unassessed
answers. Authored model checks are additional coverage, not independent
language coverage; valid unsupported volume scaling remains withheld.

The first hbox attempt `20261018T101455Z-fba6f82a6109` failed because Isabelle
resolved `size` as an existing function rather than the intended parameter.
The parameter was renamed `sz`. Final persvati proof
`20261018T102629Z-99a6453aa4fd` passed 77 scanned theorems with zero oracles and
published the generated SML plus a durable assertion marker. Final native
attempt `20261018T103812Z-8a6d681e7a87` binds the exact proof closure and copied
compiler inputs through the common helper. No failed export was compiled.

## What is proved

The new request's laws connect directly to the executable kernel:

- A successful answer entails nonnegative supplied nutrients and target,
  positive reference extent, valid optional serving mass and compatible units.
- Answer times reference mass equals `(4p + 4c + 9f + 7a)` times target mass.
  Here p, c, f and a are the supplied protein, carbohydrate, fat and alcohol.
- Equal reference and target extents agree with the existing Atwater sum.
- A valid zero target yields zero calories.
- A grams/servings conversion with no serving mass declines as underspecified
  in either direction.

These are algebra and applicability laws for a homogeneous portion with general
4/4/9/7 kcal per gram factors. They do not verify food labels, food-specific
factors, fiber/polyol treatment, label rounding or individual dietary advice.
Unlisted components contribute zero to the supplied-component sum. A reference
and target both in milliliters are mathematically sufficient for linear scaling,
but that valid capability is still withheld here and counted accordingly.
English role assignment, unit recognition, source labels and JSON framing are
untrusted. The other four specialist ledgers remain explicit in semantic-gaps.md.

## Owned files and consumer

The proposed changes are AnatomyAgri.thy, AnatomyAgri_Export.thy,
recognizer.sml, capabilities.json, probes.json, README.md and semantic-gaps.md,
plus this report. The existing `kcal_macros` capability consumes the extended
request; its sidecar states the portion and serving-mass assumptions. Historical
G artifacts remain immutable. The root released G after commit `1d4c4e9`, so H
can be promoted after checked source ancestry and final native validation.


## Exact artifacts

The immutable native binary is `var/anatomyagri/h-delivery/anatomyagri`, SHA
`9770e1dcabc92594e112be817c27f81502dd6bd599f9d21ad4f418ae5fc617ee`.
The proof receipt and actual compiler-input receipt are under
`var/anatomyagri/h-next/checkout/var/anatomyagri/remote-attempts/20261018T102629Z-99a6453aa4fd/receipt.json`
and `var/anatomyagri/h-next/checkout/var/anatomyagri/native-attempts/20261018T103812Z-8a6d681e7a87/compile-inputs.json`.
The shared numeric input remains frozen at
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The shipped, authored and frozen-G comparison receipts are in h-next;
fresh receipts are `var/anatomyagri/c-beyond/h-bound-*.json`.
Eight actual Dispatcher controls are recorded separately, with requested-portion
text assertions as well as numbers. See h-delivery/live-ready.json for the
final current-source and operational publication hashes and consumer receipts.

This is the final drain packet for this lane. Life J is only a documented next
gap: negative Shannon counts and explicit population-versus-sample Simpson
conventions. It has no implementation or proof submission.


Final actual Dispatcher check: all eight controls pass in
`var/C-runtime-consumers/anatomy-H-final.json`, using the exact H binary and
sidecar with other routes disabled. This is staged composition evidence, not
a full-default-dispatcher claim. The same bytes are now atomically published
at `var/anatomyagri/bin/anatomyagri`; the common verifier reports no current
proof or runtime source differences. Family dispatch of these exact bytes passed the
156-item shipped panel above. Root's whole-system gate remains separate.
The unchanged build.sh retains tracked mode 100644 and is invoked through sh.
No Life/Anatomy build or evaluation process remains active.
