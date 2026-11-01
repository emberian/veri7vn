# Life I: explicit translation frames

I selects a stated positive reading frame inside the checked kernel, after
normalizing coding/template role and strand direction. DNA AATGAAA in frame 2
and CCATGAAA in frame 3 both yield MK. RNA and reversed/template declarations
follow the same normalized sequence. Protein length uses the selected suffix
and counts amino acids before the first stop; a stop at the selected start is
reported as an empty protein. The previous frame-2/frame-3 refusals are saved
in var/life/i-next/counterexamples.json.

The official shipped score is 179/179 in both specialist and family modes,
with zero wrong, false yes or withheld-valid. Development 10181001/10182003
and untouched 10191057 each score 179/179. All 13 source-table checks pass.
All 195 authored policy assertions pass. Capability is 180 right, 0 wrong,
0 false yes, 15 withheld-valid and 0 errors. The frozen H binary on the same
195 cases has 166 right and 29 withheld-valid, with no wrong or false yes.
The shipped organ has 62 right, 42 wrong, 37 false yes, 51 withheld-valid,
2 errors and 1 unassessed answer on this supplemental authored set.

The passed proof 20261018T100144Z-4ad2467d99a5 scans 138 statements with no
oracles. Five new laws bind the actual frame kernel:

- Frame 1 agrees with the prior translation/protein-length kernel.
- Equal selected suffixes give equal results when original inputs are not
  mixed DNA/RNA and the selected frame is in range.
- Reversing the displayed sequence and reversing its declared orientation
  leaves the selected translation unchanged.
- A successful result has frame in 1..3 and no mixed T/U original input.
- A translated protein uses the selected complete-codon suffix, contains no
  stop symbol, and cannot exceed its complete-codon count.

The kernel checks the original bases before dropping a prefix, so a mixed
DNA/RNA prefix cannot disappear into a seemingly valid suffix. These laws do
not infer a biologically used start site. Missing frame retains the existing
frame-1 convention. Only positive frames 1..3 and complete remaining codons
are supported; negative/six-frame search, alternate codes, ORF discovery and
partial terminal codons still require other models.

The final bound native is 825224 bytes, SHA-256
ace611e373885b77928a289e70368616d922c396dd97354903f1dd1515401b9a.
The common helper binds generated code, recognizer, main, commons and frozen
numeric 2f313c77…046d; native receipt is
var/life/i-next/checkout/var/life/native-attempts/20261018T100506Z-2c46c4ee1c09/compile-inputs.json.
Median of five isolated process starts is 3.198 ms. The concurrent panel run
recorded 9.466 ms; both timing receipts are retained. The first proof attempt
needed a conjunction-normalization fix; the initial passing native was
superseded only to make an empty protein explicit in response text. All prior
attempts remain retained.

Changed candidates relative to H: Biology.thy, Life_Export.thy, gen/part1.sml,
generated recognizer.sml, capabilities.json, probes.json, README.md and
semantic-gaps.md, plus this report. The exact transfer is
var/life/i-next/transfer.json and ready packet var/life/i-delivery/ready.json.
The specialist/family CLI and sidecar-aware Dispatcher consume the new frame
selection. Final actual Dispatcher checks are tracked with the packet; no
selected package promotion is implied by a staged candidate.

Actual staged Dispatcher checks pass 7/7, including exact MK strings, protein
length 2, empty protein, invalid-frame and mixed-base terminal refusals.
Receipt var/C-runtime-consumers/staged-I-life.json binds the final native,
declarations and runtime sources.

Root released the E predecessor after integration/capture. The full F→G→H→I
chain is now promoted to the canonical family after every ancestor/candidate
hash check. Generated code and the matching native manifest were published
before the final canonical executable. The common verifier confirms exact
current proof/runtime source agreement with the retained final I receipt.
Promotion and runtime-publication receipts are in var/life/i-delivery; no
proof/native rebuild was performed solely for path promotion. The final
live named-file packet is var/life/i-delivery/live-ready.json.

Canonical full-default runtime checks pass 3/3: frame-2 MK translation,
protein length 2 and terminal invalid-frame refusal. Receipt
var/runtime-default/live-I-life.json binds the operational canonical binary
and sidecar hashes. The canonical build.sh retains tracked executable mode
0755; ready metadata also records binary/generated/manifest modes and hashes.
