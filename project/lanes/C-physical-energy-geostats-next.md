# Energy and geometry/statistics: next semantic work

Every identity below was examined through its typed kernel, recognizer and shipped cases. This table distinguishes the current packet from further work. These observations do not change the frozen build inputs. Off-panel examples used the preserved baseline binaries; they are counterexamples to broad correctness claims, not additional scored panel rows. Exact replies are in `var/c-physical-energy-geostats/semantic-next-probes.json`.

| Specialist | Examined behavior and current packet | Current limit and coherent next improvement |
|---|---|---|
| thermo | Temperature, heat, ideal gas, Carnot and radiation guards; existing wave-6 heat reversal law | Negative mass melting returns negative energy; negative ideal-gas volume returns negative pressure. Validate constituent physical domains in the kernel and preserve signed inputs in readers. |
| energy-v2 | Passive bulb-swap error; latest reader adoption; adjusted battery runtime | Constant load and stated one-way efficiency/depth only. No battery aging, voltage sag or nonlinear discharge model. Verify constituent capacity inputs before multiplying Ah and volts. |
| energy-v3 | Same latest reader and explicit factor interpretation | Same battery limits. Mentioned unknown or round-trip efficiency is missing one-way input, not numeric zero. Future breadth should state its model before adding a formula. |
| hvac | Standard-air sensible/latent formulas, ACH and tons/BTU conversion | Negative CFM loses its sign in recognition. Audit signed flow, dimensions and time with typed-domain guards; retain explicit standard-air approximation and full-sizing refusal. |
| renewables | Wind/solar/hydro recognition and efficiency bounds; falling-height recovery | Negative hydro efficiency loses its sign. Add lower bounds and signed parsing consistently across these physical inputs. |
| iot | ADC, duty cycle, battery and radio-energy formula domains | Negative ADC reference is withheld by the reader, but the typed ADC reference has no positive-domain guard. Audit current, duty, reference and duration as a coherent physical-domain change. |
| geometry | Latest shared reader recovers Heron phrasing; signed lengths reach existing guards | Mixed-unit dimensions are raw rationals: rectangle 2 m by 30 cm answers 60. Implement a consistent dimension-unit representation, or decline mixed explicit units until conversion exists. |
| geometry-v3 | Latest reader recovers imperative hypotenuse phrasing | Same mixed-unit limit; right-triangle, polygon and solid dimensions need consistent unit semantics. |
| geometry-v4 | Positive typed dimensions and cross-shape equations reviewed | Same unit limit. A positive-length proof does not validate that English unit extraction preserved magnitude. |
| statistics | Latest reader recovers binomial phrasing; new weighted-mean model | Ordinary mean ignores trailing exclusion: mean of 1,2,3 excluding 3 answers 2. Consume dataset qualifiers or decline unsupported modifiers before interpreting the values. |
| statistics-v2 | Latest reader recovers dataset phrasing; weighted mean | Same qualifier limit. Available fresh generator exercises base statistics templates only. |
| statistics-v3 | Current mean/mode/variance/binomial paths; weighted range and equal-weight consequences | Same qualifier limit. Weighted reader is anchored and validates complete finite decimal lists, but this does not repair the older unweighted reader. |

The next coherent work is domain preservation for energy inputs, dimension units for geometry, and full dataset-expression consumption for statistics. A green shipped panel alone cannot close these observed semantic gaps.

The native family reader and shared runtime contract currently duplicate context regexes. This packet synchronizes the supported W abbreviation and running-cost operation context in both locations, so a missing tariff remains a decisive refusal. The next simplification is generating native family eligibility from the shared capability declaration, rather than maintaining parallel regex strings.

Root's endpoint review improves the adjusted battery model: zero efficiency or zero usable depth means zero deliverable energy and therefore zero runtime at a positive load. The captured C packet conservatively uses `(0,1]`; next D should admit `[0,1]` and return explicit zero hours, while still refusing zero load (division denominator) and invalid constituent inputs. Update the bound theorem and endpoint probes together; do not treat the earlier conservative refusal as mathematical necessity.

## D implementation in progress after Energy C capture

Runtime captured Energy C before this source reopened. Root committed C as `f57ba8d`; C receipt and counts remain in the original lane report. D is not yet a verified packet.

Prepared D changes validate physical constituent domains in Thermo/Hvac/Renewables/Iot, preserve signed temperatures and temperature differences, and admit zero adjusted-runtime factors. A dedicated HVAC invalid-dimensions request prevents two negative room dimensions from becoming a valid positive volume. New candidate consequences state that accepted hydropower is nonnegative, duty-cycle current lies between its two current levels, and accepted adjusted runtime is zero if either production factor is zero. The first proof attempt `20261018T072459Z-560b5971839c` exposed a reserved Isabelle fact name and existing lemmas whose assumptions needed the new guards. Those concrete issues were repaired; second hbox attempt `20261018T073616Z-fa2585ed4024` then reached the new IoT convex bound and found an unavailable lemma name. The bound was refactored to derive its four inequalities from `min_def`/`max_def` and use `mult_right_mono`; third hbox attempt `20261018T075545Z-067b546cfb2f` is pending. No failed export is in use.

Numeric role binding uses the shared `ExactNumeric.scan` byte spans. Every scalar capture, including alternative captures and integer roles, must exactly cover an issued Number token; the value comes from that token. Conventional R13/R-13 labels are explicitly normalized within HVAC; separately signed R-value remains a scalar. Physical scalar and adjusted-runtime grammar candidates now include fractions, scientific notation and Unicode minus; older billing/integer grammars remain narrower. No unit/exponent suffix is allowed to supply a scalar. This adapter remains untrusted.

The D domain/spelling set has 34 same-author probes in `src/extract/energy/domain_probes.json`, tied to the explicit models and shared lexical contract. On captured C it scores 3 right / 8 wrong / 18 false yes / 5 withheld (required-kind mismatches are included in the latter bucket by the small probe checker). D after-numbers, new frozen fresh seeds and immutable compiler-input manifest are pending. Do not present prepared source or syntax-only checking as completion.

Remaining design work includes full home billing scalar grammar/domain conventions, richer geometry dimensions, and statistics qualifier consumption. A common runtime eligibility declaration should also replace duplicate native/context regexes.

D now also safely declines mentioned-but-unread renewables efficiency or power coefficient, preserving the distinction from an unmentioned ideal/incident-power assumption.

## GeoStats D after immutable capture

Root committed C as `a2ac5f1`. Runtime captured final bound native `3d0589cca0ab55b75bd5d952b346c39b1fb021f9299a9e5525fa16502e62aeea` at `var/C-runtime-package/bound-prepared/20261018T073840Z-33ca2d511191/geostats` before releasing these sources.

D adds an exact length-unit model (mm/cm/m/km/international in/ft/yd) feeding the existing shape kernel. Requested result units take precedence over the first explicit input unit. Bare dimensions can inherit one common input unit; mixed explicit units plus bare dimensions are refused. The new rectangle consequence connects the returned area to the two original physical lengths, in addition to conversion composition and sign preservation. Source for exact factors: [NIST length definitions](https://www.nist.gov/pml/owm/si-units-length).

Dataset exclusion means remove every occurrence equal to any explicitly excluded value, preserving the order and multiplicities of all retained observations. The HOL filter feeds the existing mean/median/mode/range/variance/deviation request. Its sum-partition law connects the filtered mean to the original total. Complete list consumption rejects unread modifiers; weighted exclusions are deliberately refused because removing values without paired weights changes their meaning.

First D proof attempt `20261018T074623Z-ee747e6394ce` proved the conversion and rectangle consequences, then exposed a reply-pattern binder colliding with an existing selector. The binder was renamed; second persvati attempt `20261018T075210Z-7a65e01f5273` passed the actual target and published a fresh export. The completed receipt is below.


### GeoStats D ready packet (independent consumer passed)

The final source is frozen. Proof `20261018T075210Z-7a65e01f5273` passed, with no oracles. Its new statements are: conversion preserves physical length and composes; converted lengths preserve sign; accepted converted rectangle area times the target unit squared equals the product of the two original physical lengths; exclusion preserves precisely the nonexcluded observations; retained and excluded sums partition the original sum; the actual filtered mean kernel satisfies that same partition. Unit-labelled replies retain the kernel's stated value.

Actual compiler inputs are bound by `var/geostats/build/compile-inputs.json`, native attempt `20261018T080146Z-851a91327e8c`. `compile_ok` and `current_proofs_match` are true. Generated SML is `82039ce482ab4d3bed5d7eae5c3cea2c71c284a5a020288f8ae334e61dc6dc22`; consumed shared numeric is `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`. Final native is `c999d910b242f9c190e24d05251fd8f84e9bd82e68499a6359c22a320b2e7c2d`, 595,784 bytes.

The final 36 semantic probes score **36 right / 0 wrong / 0 false yes / 0 withheld**, versus captured C **5 / 16 / 6 / 9**. This includes 30 same-author unit/dataset cases, three z-score scalar cases, and three independent-parent domain-ownership counterexamples. The z-score reader now binds whole signed tokens, so a negative standard deviation reaches the existing positive-SD guard. Unit cases check the actual output unit as well as the number. Speed and batting-average questions remain untaken, rather than receiving a misleading statistical dataset refusal. Existing C probes remain 20/20. Receipts: `var/c-physical-energy-geostats/geostats-domain-{before,after}.json` and `geostats-D-Cprobes.json`.

All own-scorer shipped rows, both pinned and family mode, remain:

| Specialist | Dev right | Held right | Wrong / false yes / withheld valid |
|---|---:|---:|---|
| geometry | 106 | 97 | 0 / 0 / 0 |
| geometry-v3 | 100 | 100 | 0 / 0 / 0 |
| geometry-v4 | 100 | 93 | 0 / 0 / 0 |
| statistics | 142 | 142 | 0 / 0 / 0 |
| statistics-v2 | 144 | 144 | 0 / 0 / 0 |
| statistics-v3 | 144 | 144 | 0 / 0 / 0 |

Fresh offsets 39118 and 49118 each score 142 dev / 142 held, zero wrong/false yes/withheld, for all three statistics identities before and after. Offset 49118 was generated only after the final source froze. These are base-statistics generators, not newer-template generators; no geometry generator exists in the upstream snapshot. Receipts are `var/c-physical-energy-geostats/geostats-D-fresh-{39118,49118}-{before,after}/receipt.json`.

Final score/performance receipt: `var/c-physical-energy-geostats/geostats-D-after.json`. Five cold starts were 6.47, 6.63, 6.15, 6.56, 6.33 ms. Pinned in-binary p50 is 2.95–2.96 ms for geometry and 0.10–0.11 ms for statistics. These are scoped live-host measurements, not isolated benchmark claims. C's source-identical bound native was 539,736 bytes; D adds 56,048 bytes.

Exact GeoStats D files: `GeoStats_Extensions.thy` (new), `GeoStats_Export.thy`, `ROOT`, `recognizer.sml`, `build.sh`, `capabilities.json`, `README.md`, `domain_probes.json` (new), and `check_probes.py`, all under `src/extract/geostats/`; this report. The checker adds optional semantic unit and taken-status assertions used by the new probes. No shared tools or upstream files changed. New refusal kinds `unsupported_units` and `unsupported_modifier` are declared for their respective specialists. Independent composition passed 10/10 at `var/c-physical-integration/geostats-d-consumer.json`, including requested output units, exclusions, negative z-score SD and outside-domain questions. Empty filtering now remains a decisive `statistics-v3>underspecified` refusal through the sidecar’s existing-kind addition and dataset context. Parent also independently checked the actual compiler inputs, current binary, successful 102-root/0-oracle target and all ten current theory-closure hashes. Runtime immutable capture remains the final consumer.
