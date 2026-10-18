# Space adaptive enclosure — F packet

Production proof, bound native and independent parent consumer review are complete. Source is frozen for root integration and immutable runtime capture. This packet changes numerical evaluation, not recognition or physical assumptions. Root integrated and runtime captured the prior Space D packet before this work reopened production source.

## What runs and what is proved

The existing approximation path now tries 32-bit interval evaluation. It accepts only if the existing checked-decimal predicate accepts the enclosure. Otherwise it evaluates the same expression at the existing 80-bit precision. Exact arithmetic and NASA table answers do not use this wrapper.

`enclose_adaptive_sound` assumes this actual wrapper returns decimal pair d and proves that its difference from the expression’s real interpretation is at most `10^(snd d)/2 + abs(model)/1000000 + 1/1000000000`. The first term is display rounding; the other terms cover enclosure uncertainty. `answer_gen` consumes the wrapper and `answer_approx` uses this theorem, so the existing accepted-kernel bound applies to the emitted branch.

`enclose_adaptive_fallback` assumes the 32-bit enclosure returns None and proves equality with the 80-bit result. `enclose_adaptive_preserves_success` assumes the 80-bit enclosure returns Some d and proves the wrapper is not None. It does not promise the same decimal when the cheaper branch succeeds, nor completeness for every mathematical expression. Existing domain guards and model assumptions remain in force.

The export self test checks a Hohmann transfer from 400 to 400.001 km: 32 bits refuses, the wrapper answers, and its enclosure equals the 80-bit result. The original numerical self tests remain. Actual managed attempt `20261018T100340Z-db555880cbdd` on persvati finished successfully: **111 roots, zero oracles**, 47.499 seconds target time. Export SHA256 `0a3886e79a808c0bfc523c3dbc7dc14c2226a10fca046d461ee782606c58fd93`.

## Shipped completion metric

Both splits combined below; each cell is right / wrong / false yes / withheld-valid. Before is the captured Space D source measurement; after is this new native. Each shipped specialist’s own scorer is used.

| Specialist | Before pinned | After pinned | After family | p50 before → after (ms) |
|---|---:|---:|---:|---:|
| orbits | 70/0/0/0 | 70/0/0/0 | 70/0/0/0 | 8.971 → 1.668 |
| planetary | 36/0/0/0 | 36/0/0/0 | 34/0/2/0 | 0.564 → 0.218 |
| spacecraft | 42/0/0/0 | 42/0/0/0 | 42/0/0/0 | 9.153 → 1.490 |
| spacecomms | 68/0/0/0 | 68/0/0/0 | 68/0/0/0 | 0.166 → 0.136 |
| astronomy | 141/0/0/0 | 141/0/0/0 | 141/0/0/0 | 0.155 → 0.109 |
| astronomy-v2 | 276/0/0/0 | 276/0/0/0 | 276/0/0/0 | 0.156 → 0.122 |
| astronomy-v3 | 276/0/0/0 | 276/0/0/0 | 276/0/0/0 | 0.168 → 0.124 |
| astronomy-v3-r2 | 276/0/0/0 | 276/0/0/0 | 276/0/0/0 | 0.281 → 0.131 |

Pinned remains **1185/1185**, family **1183/1185**, with the same two preexisting scope false-yes results in the planetary panel. No numerical wrong answers or valid withholds on shipped panels. All specialist p50 timings are below 5 ms. The historical before and current after panel measurements were separate runs under shared-machine load; they are not controlled microbenchmarks.

## Independent checks and limits

Untouched seed **20261125** was generated before evaluation and opened only after the production parser/theory/native freeze. Six specialists have shipped generators: planetary 36, spacecraft 42, astronomy 141, astronomy-v2 276, astronomy-v3 276, astronomy-v3-r2 276. Both captured D and adaptive natives score **1047 right / 0 wrong / 0 false yes / 0 withheld-valid**. Orbits and spacecomms have no shipped generators. No tuning followed this evaluation.

Twenty new authored formula controls span eight Hohmann transfers (including altitude differences down to 1e-7 km), four orbital altitudes, four rocket mass ratios and four free-space distances/frequencies. The Hohmann expectations use a separate 70-digit Decimal evaluation of the two vis-viva burns with exact model Earth mu=398600.4418 km³/s² and radius=6378.137 km. An initial test-reference draft used rounded constants; this was corrected and the focused comparison repeated without any production source change. Other expectations independently evaluate the documented existing laws. These are author-written controls, not independent linguistic validation.

Both captured D and adaptive natives score **19 right / 0 wrong / 0 false yes / 1 withheld-valid** on those 20 in pinned and family modes. Every answered value agrees exactly between the two binaries in this sample; that observation is not a general theorem. In particular all eight Hohmann values pass a relative tolerance of 0.001 with absolute tolerance 1e-13, so zero cannot incorrectly pass the tiny nonzero transfers. The 1 GHz / 1 km path-loss case is valid but both binaries return `imprecise`; this is retained as an explicitly failing capability probe, not relabeled a correct refusal.

The full authored set is **77/78 policy assertions** in each mode. Its semantic classification is 62 right / 0 wrong / 0 false yes / 16 withheld-valid: 44 accepted answers, 18 correct domain/scope/underspecification refusals, 15 earlier valid cases outside reader coverage, and the new path-loss precision withhold. The unchanged 80-bit precision is not a guarantee of numerical completeness.

Own dispatch composition is **12/12 pinned and 12/12 physical fleet**, including signed/zero paths, fractional average bit occupancy, payload counts, orbital metre conversion and invalid domains. The scoped dispatcher disables dialogue/code/reader/document/routes. No new answer or decline kinds were added. Independent parent checks add **6/6** new transfers, transfer time and speed against 70-digit Decimal references using exact model constants; the original80 and new adaptive binaries both pass. Receipt: `var/c-physical-integration/space-adaptive-independent.json`. Parent also independently verified six frozen compiler inputs, eight proof dependencies and current source matching.

## Native and performance binding

Actual binary SHA256 `13151f58abbf67da6dd1dfff62bbac35f270285d59fdf89c842926acd60078c1`, **758424 bytes**, versus captured D 775640 bytes. Immutable compiler-input manifest: `/Users/ember/dev/o7vn/var/space/native-attempts/20261018T100614Z-406f8fff31a2/compile-inputs.json`. It binds the actual generated export, family parser/driver and shared ExactNumeric input; current proof closure matches. No shared module changed.

Seven paired-process cold starts on the same ordinary orbit control had median **9.324 ms before / 4.045 ms after**. The after panel cold sample was 179.861, 4.018, 4.120, 5.139, 4.769 ms; the large first sample is kept rather than discarded. These wall times include process startup and concurrent host load. Near-cancellation fallback may cost more than direct 80-bit evaluation because it first tries 32 bits.

## Exact files and receipts

Changed files: `src/extract/space/Space.thy`, `Space_Export.thy`, `main.sml`, `README.md`, `beyond_probes.json`, and this report. Recognizer, build script, ROOT and tables are unchanged.

Evidence under `var/c-physical-mechanics-space/next/adaptive/`: `shipped.json`, `probes.json`, `comparison.json`, `sealed/summary.json`, `sealed-before/summary.json`, and `space-consumer.json`. Proof receipt is `var/space/remote-attempts/20261018T100340Z-db555880cbdd/receipt.json`; its actual session log records the 111-root scan. Preparatory `space32` generated-code experiments are untrusted historical experiments and are not the production binary.

Remaining substantive work: diagnose the inherited small-distance path-loss enclosure refusal; requested astronomy output-unit conversion; continue mechanical models’ supplied-condition and dimensional coverage. These are separate follow-ons and are not claimed complete by the faster wrapper.
