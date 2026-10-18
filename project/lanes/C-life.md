# Life: wider Mendelian inputs and faithful field measurements

Owner: Codex natural/life_anatomy. Ready for integration: the final hbox
receipt passed, and the binary built from that exact export passed every
shipped item, three fresh seeds and the 20 targeted probes.

The six specialists already share an extracted kernel. The remaining shipped
misses are English interpretation failures: inverted crossing wording, a
population adjective in Hardy-Weinberg questions, plural inches before DBH,
and mark-recapture/survival role assignment. The kernel can compute all nine.

The coherent extension accepts one through six distinct independent loci for
genotype probabilities and phenotype ratios. It refuses explicit linkage,
incomplete dominance, codominance and epistasis. Repeated letters do not become
independent loci. The biology model is complete dominance and independent
assortment; the result does not establish that real genes satisfy that model.
No new answered kind is introduced.

## Baseline

Each cell is right / wrong / false yes / valid withheld. Correct declines count
as right. The kernel and the shipped organ agree on these panels.

| Specialist | Shipped dev | Shipped heldout |
|---|---|---|
| genetics-v2 | 20 / 0 / 0 / 0 | 15 / 0 / 0 / 5 |
| biology | 15 / 0 / 0 / 0 | 15 / 0 / 0 / 0 |
| ecology | 13 / 0 / 0 / 0 | 13 / 0 / 0 / 0 |
| forestry | 16 / 0 / 0 / 0 | 14 / 0 / 0 / 2 |
| wildlife | 9 / 0 / 0 / 0 | 7 / 0 / 0 / 2 |
| microbiology-v2 | 20 / 0 / 0 / 0 | 13 / 0 / 0 / 0 |

Fresh generator seed offsets 10181001 and 10182003 reproduce the same counts
for both splits and both answerers. Offset 10183007 is reserved until tuning
ends. These alter the author's random samples, not the templates or model.
Receipts: `var/life/c-baseline.json`, `var/life/c-beyond/before-*.json`.

Twenty hand probes were written with their expected model calculations in
`src/extract/life/probes.json`. The same author is editing the recognizer;
these probes are not independent evidence. The old kernel and organ each get
3 right, 4 false yes and 13 valid withheld. Their false yes cases are repeated
loci, explicit linkage, incomplete dominance, and an impossible survival count
read backwards. The new code addresses those defects as well as missing answers.

## Binding statements and efficiency changes

`genotype_independent_composition` states that if the two kernel requests give
exact probabilities a and b, the concatenated independent-locus request gives
exactly a*b. Existing Punnett enumeration and total probability theorems remain.
`unsupported_model_declines` connects the new model-refusal request to a real
kernel decline. Interpretation of English and applicability of the model remain
untrusted.

The 33 self-test constants remain checked during the Isabelle build, but are
removed from the public export roots so the program does not execute them at
startup. Baseline cold start was 233–370 ms. Reply construction now shares its
kernel result. Interval evaluation uses 40 bits, or 64 for Shannon and evenness, instead of
72 for every kind. It retains the
same proved error bound and refusing a value when the enclosure cannot certify
four significant digits. The final ecology median is 3.44 ms; the old median was 27 ms against a
50 ms manifest budget.

The previous wave's Shannon/Gibbs and explicit-decline assurance changes are
already present and are not claimed as new work. The table checker still passes
all 13 checks.

Consumers: life binary, explicit registry dispatch and specialist package.
The family build script requires `VERI7VN_GENERATED` to name the ML file from
a successful immutable remote build attempt. It has no old-database or stale
canonical-export fallback.

## Build progress

The first attempt `20261018T063123Z-b1bfb468a5b6` on persvati proved every
theorem but failed self-test 19: 40-bit Shannon evaluation could not certify
the four digits for counts [12,8,6,3,1]. The failed export was not published.
A local scratch diagnostic tried several precisions; 64 was sufficient for
Shannon/evenness, and 40 for the other shipped cases. The mixed diagnostic
gets 179/179 shipped items and 20/20 probes, with ecology median about 3.4 ms,
but this is explicitly unverified diagnostic evidence. The actual final
source passed on hbox as `20261018T064654Z-b1339ba44f15`; final evidence is
recorded below.

## Final evidence

The successful hbox attempt is `20261018T064654Z-b1339ba44f15`; its
`results/session.log` reports `VERI7VN_LIFE PASS theorems=105 oracles=0`.
All 33 build-time self-tests passed. The generated ML SHA-256 is
`6615f8586899a1d09f4af0324a3f013059cfd534a445d5ad5b1f14421e9dd222`.
The macOS binary is 757560 bytes, SHA-256
`a153703883ee2d2df16c11dbfdb933e4bb36e6d3733c10b31e82ee2d357d92b5`.

| Specialist | Final shipped dev | Final shipped heldout | Previous heldout right |
|---|---:|---:|---:|
| genetics-v2 | 20/20 | 20/20 | 15/20 |
| biology | 15/15 | 15/15 | 15/15 |
| ecology | 13/13 | 13/13 | 13/13 |
| forestry | 16/16 | 16/16 | 14/16 |
| wildlife | 9/9 | 9/9 | 7/9 |
| microbiology-v2 | 20/20 | 13/13 | 13/13 |

Both pinned-specialist and whole-family dispatch score 179/179: wrong 0,
false yes 0, valid withheld 0, versus the organ's 170/179. Two development
fresh offsets 10181001/10182003 and the untouched offset 10183007 each
score 179/179 with all three error counts zero. The untouched panel was first
generated after source tuning ended. These are fresh samples of the author's
existing templates, not independent new language. Targeted probes score 20/20
versus the organ's 3/20, 4 false yes and 13 withheld. Table checks pass 13/13.

Five fresh-process starts took 86.4, 4.7, 4.5, 3.7 and 5.7 ms (median 4.7 ms);
the first filesystem-cold launch remains visible. Ecology's pinned median
is 3.44 ms and whole-family median 3.77 ms. Receipts: `var/life/c-after.json`,
`var/life/c-beyond/{after-10181001,after-10182003,untouched-10183007}.json`,
and `var/life/c-beyond/probes-after.json`. Frozen artifacts and a named-file
integration manifest are in `var/life/c-delivery/`.

## Known next semantic work

These panels do not establish arbitrary biological correctness. Direct
counterexamples found while preparing D show that explicit 3′→5′ DNA template
orientation is not preserved in transcription/translation, an explicitly
nonstandard genetic code can receive a standard-code answer, and microbiology
can invent an absent plated volume or discard a colony count's minus sign.
The next repair starts from these concrete gaps. The per-specialist semantic
ledger is `var/life/d-next/semantic-gaps.md`. C keeps its bounded improvements
and performance win while that work proceeds separately.
