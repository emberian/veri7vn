# Acoustics: independently moving source and listener

Producer ready and frozen for integration. The current native answers independently moving source/listener questions with one verified Doppler expression, preserves all 139 shipped acoustic answers, and refuses supplied motion conditions that it cannot bind. Root integration, immutable package capture and the final full-default runtime gate are still pending. No successor work is running during the requested drain.

## Model and actual-return laws

`DopplerBoth f us ds ul dl s` keeps emitted frequency, source speed/direction, listener speed/direction and medium separate. Speeds are relative to a stationary medium, along the source-to-listener propagation line. Toward for the source means toward the listener; toward for the listener means toward the source. An away magnitude contributes the opposite sign:

`heard = emitted × (c + listenerTowardSpeed) / (c - sourceTowardSpeed)`

The kernel evaluates one combined expression and rounds once. Existing constructors remain available to captured consumers. Supplied Celsius temperature reaches the dry-air square-root model; explicit sound speed is kept separate from actor velocities.

The source must be subsonic. A listener receding exactly at sound speed returns zero crest-crossing frequency; a receding listener faster than sound and a source at or above sound speed are outside this model. Those limits are not assertions of physical impossibility. Explicit wind or moving medium requires a frame transformation not implemented here and produces a typed `unsupported_model` refusal. Negative speed magnitudes, nonpositive emitted frequency and invalid medium remain invalid inputs.

The eight additional exported proof roots state:

- `speed_squared_correct`: for a valid medium, the exact rational sound-speed square equals the square of the real model speed.
- `at_sound_iff`: for a valid medium, the exact rational sonic-equality test holds exactly when the magnitude equals real sound speed.
- `outside_model_declined`: every explicit outside-model request returns its typed model refusal.
- `doppler_both_returned`: an actual returned value has Doppler kind and differs from the joint real expression by at most its absolute value divided by 1000, plus 10^-9.
- `doppler_both_source_returned` and `doppler_both_listener_returned`: an actual joint return with the other actor stationary obeys that same error bound against the existing one-mover model, for a known direction.
- `doppler_both_stationary_returned`: an actual return with both actors stationary is within the bound of the emitted frequency itself.
- `doppler_both_denominator`: an actual joint return implies a strictly positive source denominator.

The reductions concern model equations; they do not claim the older constructor's sonic decline policy equals the new zero-frequency boundary policy. The stationary-medium and one-dimensional motion interpretation remains a model assumption, not an empirical proof about arbitrary sound propagation.

## Reader and consumer

The untrusted reader uses the shared exact numeric lexer and measured-unit spans. Each source/listener clause binds its own velocity and direction; clause order can reverse. Frequency, temperature and explicit medium speed are separate roles. Every supplied numeric measurement must be accounted for, including the legacy single-mover fallback. This closes real cases where a second speed or frequency was silently ignored after joint parsing failed.

The new sidecar declares `unsupported_model` as an accepted in-domain decline. No new answer kind is needed. JSON framing and English interpretation remain untrusted. The finite reader supports Hz, m/s and Celsius in this joint model; kHz output/input conversions, other speed units, wind/frame conversion, and unresolved actor roles remain capability limits. Some unrecognized English falls through instead of producing a consumed refusal; the report does not claim universal sentence coverage.

## Scores and independent checks

Only the shipped panel is the project completion metric. There is no upstream acoustic panel generator, so no fresh upstream-generated panel is claimed.

| Evidence | Before right / wrong / false yes / valid withheld | Final right / wrong / false yes / valid withheld |
|---|---|---|
| Shipped acoustic practice + held-out panel | 139 / 0 / 0 / 0 | 139 / 0 / 0 / 0 |
| Final untouched motion challenge, seed 2026102529, 123 cases | 10 / 3 / 0 / 110 | 109 / 0 / 0 / 14 |
| 45 cited probes | 44 / 0 / 0 / 1 | 45 / 0 / 0 / 0 |
| Existing independent numerical regression, seed 2026102521 | not rerun for this comparison | 180 / 0 / 0 / 0 |

All 123 authored motion assertions pass. The 14 valid withheld cases remain withheld capability, even when refusal is the intended safe behavior. The baseline's three wrong results concern ignored extra givens. The former both-moving cited probe was incorrectly classified as invalid in the older corpus; it is now a valid joint-motion answer. This correction is explicit rather than treating an old expected refusal as capability.

Receipts under `var/c-physical-quantity-sound/`:

- `acoustic-motion-panels-before/report.json`, `acoustic-motion-panels-final/report.json`.
- `acoustic-motion-final-untouched-before.json`, `acoustic-motion-final-untouched.json`.
- `acoustic-motion-probes-before.json`, `acoustic-motion-probes-final.json`.
- `acoustic-motion-existing-regression.json` and `acoustic-motion-timing.json`.
- Tuning history remains in `acoustic-motion-tuning.json`, `acoustic-motion-role-tuning.json`, `acoustic-motion-complete-tuning.json` and `acoustic-motion-sonic-tuning.json`; the final seed above was unused until the reader froze.

Parent's independent five questions pass in `var/c-physical-integration/acoustics-next-independent.json`: opposite direction pairs, exact sonic-listener zero, wind and unbound extra speed. Parent checked the actual native manifest's seven runtime and seven proof closure entries. Full-default composition is the remaining runtime gate, with planned receipt `var/c-physical-integration/acoustic-motion-composition.json`.

The final binary is 517,768 bytes. Five-process cold median is 3.510 ms; warm 50-question median after one warmup is 0.399 ms. The broader 180-case numerical regression has median 8.602 ms and maximum 43.446 ms. These measurements are different workloads, not interchangeable latency claims.

## Proof and actual compiler inputs

Passed proof: `var/acoustics/remote-attempts/20261018T101849Z-f06b963d12d1/receipt.json`. The actual target finished in 23 seconds; its session log contains 40 roots / 0 oracles and `VERI7VN_ACOUSTICS PASS`, with build exit 0. Export SHA256: `23591bdf4e66a32a7a64486e6e32917509b57cdb8d4335e1a5f3880e8b2ae50f`.

Actual native manifest: `var/acoustics/native-attempts/20261018T102422Z-aae552c5c782/compile-inputs.json`.

- Native SHA256: `804b6488d6c193e5a2cd7edad0501e90adb0726c1b4a2499bf0a6e92f11be2b4`.
- Consumed recognizer SHA256: `5247150f9592e58bc77ecb119bc6ae646c1b96f619fd828f5fe1ea8dfe5a82a3`.
- Consumed ExactNumeric SHA256: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
- Consumed MeasuredInput SHA256: `11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`.

Failed proof attempts `20261018T101140Z-0511909a0f3f` and `20261018T101522Z-9f91bf2d5df4` are retained. Algebra and simplifier failures were repaired through explicit nonnegative square-equality implications, an exact stationary identity, and direction cases. No theorem was weakened and no axiom or proof escape was added.

## Exact integration files and resume state

`src/extract/acoustics/`: `Acoustics.thy`, `Acoustics_Export.thy`, `recognizer.sml`, `build.sh`, `capabilities.json`, `motion_check.py`, `beyond_probes.json`, `README.md`; plus this report. The ready receipt records each file hash. No shared source is edited in this packet.

Quantity/Variants energy units are already committed as `02befee` and captured. Their full-default dialogue chain now converts 6 kWh to 6000 Wh and 21.6 MJ; receipt `var/dispatch/successor/20261018T102017Z/receipt.json`. The separate conditions-report accounting edits remain root-owned auxiliary integration work.

No active job remains in this lane. After the current drain, possible future work is explicit moving-medium frames, wider joint-motion units, and custom supplied fuel heating values; none is implemented or promised by this packet. Resume from the committed/captured acoustic hash, inspect the remaining model limits, and obtain a new source release before further edits.
