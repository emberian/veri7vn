# E-earth: signed S–P distance and whole GR thresholds

Scratch only. Live Earth D remains frozen. Managed scoped proof passed on
persvati: 20261018T091358Z-59a81be22e2e. Base is exact passed Earth D proof
0c7db09e8ddf, with owned overlay hashes in staging.json. No selected binary or
production output changed.

Actual prior D replies interpret Gutenberg–Richter magnitude 10 as 1, producing
100000 yearly events instead of 0.0001 for a=6,b=1. An S–P delay of -1 second is
silently positive, yielding 6 km for P=6 km/s,S=3 km/s. Signed speed is treated as
missing. These concrete replies are retained in baseline.json and d-baseline.json.

The new reader selectively uses shared exact numeric masking for the GR and S–P
branches. It binds unique named a/b/magnitude roles, a unique duration in seconds,
and each unique named wave speed in km/s. It accepts signs, fractions and
scientific notation, rejects malformed/forged marker lookup, and refuses
competing quantities or composite speed dimensions. Other seismology branches
remain unchanged; their signed/multi-digit magnitude parsing is a subsequent gap.

The direct-wave kernel now rejects negative S-minus-P delay as well as invalid
speed ordering or nonpositive S speed. Zero delay is permitted and means zero
distance. Four checked statements bind successful kernel results to:

- nonnegative delay/distance, positive ordered speeds, and the difference of the
  inferred S and P travel times exactly equal to the input delay;
- zero distance exactly when the delay is zero;
- positive GR count with log10(count)=a-bM;
- monotonically nonincreasing successful GR counts as the threshold increases,
  provided the supplied b coefficient is positive.

GR remains an explicit-coefficient empirical model. These laws do not certify a
calibration region, forecast future earthquake occurrence or forbid extrapolation.
No new kind or sidecar is needed: existing seismology accepts impossible and
underspecified.

There are 29 authored policies: 16 modeled answers, 8 impossible input cases,
3 valid unsupported/ambiguous cases and 2 malformed inputs. Prior D passes 7/29.
Candidate now passes all 29 policies: 16/19 modeled capability answers, three
valid unsupported cases withheld, eight impossible and two malformed cases
classified separately.


## Diagnostic candidate evidence

Proof: `20261018T091358Z-59a81be22e2e`, `VERI7VN_EARTH PASS theorems=128 oracles=0`.
Generated SML SHA256: `a54fe253f8fe3666c62551f54168733c5bfa3ee2ea9b84b847ee1f50f86ca65d`.
Actual native: `bae205555bc0975229b0f2f9adce2530fef7c14c5ba95d582931038af079fbb5`, 931864 bytes.
Manifest: `var/earth/e-seismo/stage/var/earth/native-attempts/20261018T091558Z-b11af78b8d36/compile-inputs.json`.

Common helper is unchanged and copied into the isolated stage; its explicit
proof-snapshot mode binds the retained passed export and actual compiler inputs.
All metadata and outputs stay in scratch. Initial diagnostic ded10afd passed
28/29 policies: the old 25-word decline gate discarded a typed two-delay refusal.
The final reader retains recognized SP/GR outcomes without that short-question
gate, while keeping narrative exclusion. This reader-only change is recorded in
reader-after-proof-capture.json and the actual compiler manifest; proof unchanged.

Official scorers on final native:

| Panel | Right | Wrong / false yes | Valid withheld |
|---|---:|---:|---:|
| Shipped all Earth | 554 / 554 | 0 / 0 | 0 |
| Fresh offset 18701 | 354 / 354 | 0 / 0 | 0 |
| Reserved offset 23701 | 360 / 360 | 0 / 0 | 0 |
| Seismology shipped | 68 / 68 | 0 / 0 | 0 |
| Seismology fresh | 68 / 68 | 0 / 0 | 0 |
| Seismology reserved | 68 / 68 | 0 / 0 | 0 |

Separate official seismology parity harness also scores 68/68. Six-criterion
admission remains INCOMPLETE because head/core/self and admission budgets were
not measured. Missing fresh generators remain hydrology and meteorology; they
have shipped evidence only. All 50 prior authored Earth policy probes pass.

Shipped p50 ms: geography 0.102, geology 15.343, seismology 17.765, hydrology 0.141,
ocean 1.846, meteorology 0.118, greenhouse 10.240, greenhouse-r2 10.220; cold 3.345.
No family-wide sub-5ms claim is made.

Independent actual Dispatcher validation passes 7/7 using the seven exact prompts
in runtime-probes.json. Receipt:
`var/C-runtime-consumers/staged-E-earth-rendered-final.json`. Magnitude 10 gives
0.0001, signed magnitude -0.5 gives 3162000 under the existing four-significant-
digit rendering, zero S–P gives zero, and the two impossible plus two ambiguous
or invalid-unit requests retain terminal refusals. The initial generic absolute-
tolerance check for the large GR count is retained; the final check independently
rounds `sqrt(10)*10^6` according to the declared Earth rendering policy. Live Earth D remains unchanged. Root integration release,
source promotion, exact promoted-proof closure validation and immutable capture
remain outstanding.
