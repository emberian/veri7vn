# Energy and geometry/statistics: next semantic work

The table below is the **historical C baseline audit**, before the D repairs described later in this report. Its negative-mass, mixed-unit and ignored-exclusion counterexamples have now been repaired in the final D packets; they are not current defects. Each identity was examined through its typed kernel, recognizer and shipped cases. Baseline replies are preserved in `var/c-physical-energy-geostats/semantic-next-probes.json`. Current remaining work is complete weighted spelling, paired statistics, and broader explicit physical-unit interpretation; exact current packet receipts and remaining limits appear below.

| Specialist | Examined C baseline behavior | Historical defect or continuing model limit |
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

This audit motivated the D physical-domain, exact-unit and complete-dataset changes now verified below. A green shipped panel alone did not close the observed gaps.

The native family reader and shared runtime contract currently duplicate context regexes. This packet synchronizes the supported W abbreviation and running-cost operation context in both locations, so a missing tariff remains a decisive refusal. The next simplification is generating native family eligibility from the shared capability declaration, rather than maintaining parallel regex strings.

Root's endpoint review improves the adjusted battery model: zero efficiency or zero usable depth means zero deliverable energy and therefore zero runtime at a positive load. The captured C packet conservatively uses `(0,1]`; next D should admit `[0,1]` and return explicit zero hours, while still refusing zero load (division denominator) and invalid constituent inputs. Update the bound theorem and endpoint probes together; do not treat the earlier conservative refusal as mathematical necessity.

## D implementation in progress after Energy C capture

Runtime captured Energy C before this source reopened. Root committed C as `f57ba8d`; C receipt and counts remain in the original lane report. The following preparation history is superseded by the final verified receipt below.

Prepared D changes validate physical constituent domains in Thermo/Hvac/Renewables/Iot, preserve signed temperatures and temperature differences, and admit zero adjusted-runtime factors. A dedicated HVAC invalid-dimensions request prevents two negative room dimensions from becoming a valid positive volume. New candidate consequences state that accepted hydropower is nonnegative, duty-cycle current lies between its two current levels, and accepted adjusted runtime is zero if either production factor is zero. The first proof attempt `20261018T072459Z-560b5971839c` exposed a reserved Isabelle fact name and existing lemmas whose assumptions needed the new guards. Those concrete issues were repaired; second hbox attempt `20261018T073616Z-fa2585ed4024` then reached the new IoT convex bound and found an unavailable lemma name. The bound was refactored to derive its four inequalities from `min_def`/`max_def` and use `mult_right_mono`; third hbox attempt `20261018T075545Z-067b546cfb2f` is pending. No failed export is in use.

Numeric role binding uses the shared `ExactNumeric.scan` byte spans. Every scalar capture, including alternative captures and integer roles, must exactly cover an issued Number token; the value comes from that token. Conventional R13/R-13 labels are explicitly normalized within HVAC; separately signed R-value remains a scalar. Physical scalar and adjusted-runtime grammar candidates now include fractions, scientific notation and Unicode minus; older billing/integer grammars remain narrower. No unit/exponent suffix is allowed to supply a scalar. This adapter remains untrusted.

The D domain/spelling set has 34 same-author probes in `src/extract/energy/domain_probes.json`, tied to the explicit models and shared lexical contract. With corrected capability accounting, captured C scores 10 right / 5 wrong / 17 false yes / 2 withheld. The computable `1×10^3` spelling is valid but deliberately refused by the current lexer; a safe-refusal assertion is a separate policy check, not a capability success. D after-numbers, new frozen fresh seeds and immutable compiler-input manifest are pending. Do not present prepared source or syntax-only checking as completion.

Remaining design work includes full home billing scalar grammar/domain conventions, richer geometry dimensions, and statistics qualifier consumption. A common runtime eligibility declaration should also replace duplicate native/context regexes.

D now also safely declines mentioned-but-unread renewables efficiency or power coefficient, preserving the distinction from an unmentioned ideal/incident-power assumption.

## GeoStats D after immutable capture

Root committed C as `a2ac5f1`. Runtime captured final bound native `3d0589cca0ab55b75bd5d952b346c39b1fb021f9299a9e5525fa16502e62aeea` at `var/C-runtime-package/bound-prepared/20261018T073840Z-33ca2d511191/geostats` before releasing these sources.

D adds an exact length-unit model (mm/cm/m/km/international in/ft/yd) feeding the existing shape kernel. Requested result units take precedence over the first explicit input unit. Bare dimensions can inherit one common input unit; mixed explicit units plus bare dimensions are refused. The new rectangle consequence connects the returned area to the two original physical lengths, in addition to conversion composition and sign preservation. Source for exact factors: [NIST length definitions](https://www.nist.gov/pml/owm/si-units-length).

Dataset exclusion means remove every occurrence equal to any explicitly excluded value, preserving the order and multiplicities of all retained observations. The HOL filter feeds the existing mean/median/mode/range/variance/deviation request. Its sum-partition law connects the filtered mean to the original total. Complete list consumption rejects unread modifiers; weighted exclusions are deliberately refused because removing values without paired weights changes their meaning.

First D proof attempt `20261018T074623Z-ee747e6394ce` proved the conversion and rectangle consequences, then exposed a reply-pattern binder colliding with an existing selector. The binder was renamed; second persvati attempt `20261018T075210Z-7a65e01f5273` passed the actual target and published a fresh export. The completed receipt is below.


### GeoStats D initial packet (committed, delivery held for unit repair)

The final source is frozen. Proof `20261018T075210Z-7a65e01f5273` passed, with no oracles. Its new statements are: conversion preserves physical length and composes; converted lengths preserve sign; accepted converted rectangle area times the target unit squared equals the product of the two original physical lengths; exclusion preserves precisely the nonexcluded observations; retained and excluded sums partition the original sum; the actual filtered mean kernel satisfies that same partition. Unit-labelled replies retain the kernel's stated value.

Actual compiler inputs are bound by `var/geostats/build/compile-inputs.json`, native attempt `20261018T080146Z-851a91327e8c`. `compile_ok` and `current_proofs_match` are true. Generated SML is `82039ce482ab4d3bed5d7eae5c3cea2c71c284a5a020288f8ae334e61dc6dc22`; consumed shared numeric is `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`. Final native is `c999d910b242f9c190e24d05251fd8f84e9bd82e68499a6359c22a320b2e7c2d`, 595,784 bytes.

The initial 36 semantic probes passed all 36 policy assertions. Corrected capability accounting is **33 right / 0 wrong / 0 false yes / 3 withheld-valid**, versus captured C **6 / 18 / 4 / 8**. The three valid unsupported requests were scientific-product spelling, exclusion by position, and paired weighted exclusion; safe refusal did not complete those capabilities. This includes 30 same-author unit/dataset cases, three z-score scalar cases, and three independent-parent domain-ownership counterexamples. The z-score reader now binds whole signed tokens, so a negative standard deviation reaches the existing positive-SD guard. Unit cases check the actual output unit as well as the number. Speed and batting-average questions remain untaken, rather than receiving a misleading statistical dataset refusal. Existing C probes remain 20/20. Receipts: `var/c-physical-energy-geostats/geostats-domain-{before,after}.json` and `geostats-D-Cprobes.json`.

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


### GeoStats D unit-convention repair history

Root committed the preceding D packet as `223516e`, but delivery is held after
independent parent review found a core convention error: explicit lengths were
converted to the requested output unit while bare lengths stayed unchanged.
For example 2 m and bare width 3, requested in cm², answered 600 instead of
60000; 20 cm and bare width 30, requested in m², answered 6 instead of 0.06.
The shared preprocessing path now binds every bare length to the common explicit
SOURCE unit before conversion. Polygon side counts remain dimensionless, and
asking for an angle sum in a length unit is refused rather than ignored.

README, capability assumptions and theory text now state the source-unit
convention. The mathematical statements are unchanged; exact source binding
still requires a refreshed theory receipt, queued on persvati as
`20261018T080751Z-04cafcbc6f29`; this refresh and the final native/evaluation have now passed (receipt below). The expanded 44-case set includes seven parent counterexamples and
equivalence/count controls, plus an executed postfix-weighted modifier bypass.
Captured c999 scores 35 right / 5 wrong / 1 false yes / 3 withheld-valid;
38/44 policy assertions pass. Four computable-but-unsupported requests in the
final repair are expected to remain withheld-valid, not to be counted as
correct answers. Do not deliver the earlier c999 binary as final.

Energy's third attempt `067b546cfb2f` exposed the last IoT proof-closing step's
unavailable `nlinarith` method. That closing step now explicitly applies
`add_mono` and `algebra_simps` to the four already-proved convex bounds. Fourth
hbox attempt `20261018T080629Z-73db2feb985b` passed; no failed export is used.


Probe accounting correction: `check_probes.py` now reports mathematical/input
capability counts separately from optional refusal/kind/unit/taken policy
assertions. Existing shipped-scorer numbers never used this custom checker and
are unchanged. Earlier authored-probe receipts conflated required refusals with
capability success; the corrected current receipts supersede that interpretation.
For the complete 44-case GeoStats set, captured C scores 7 right / 23 wrong / 5
false yes / 9 withheld-valid (`geostats-D-before-corrected.json`).


## Final Energy D packet

Fresh proof `var/energy/remote-attempts/20261018T080629Z-73db2feb985b/receipt.json`
passed the actual Energy target, 105 roots / 0 oracles. Physical-domain guards
validate constituent inputs before products, preserve signed temperatures and
temperature differences, and admit zero production factors. The additional
consequences say accepted hydropower is nonnegative, accepted duty-cycle current
lies between its two current levels, and accepted adjusted runtime is zero when
efficiency or usable depth is zero. Existing heat reversal and conversion laws
were updated to carry the stronger domain assumptions without weakening their
conclusions.

Actual native inputs: `var/energy/build/compile-inputs.json`, attempt
`20261018T081454Z-76be3d79551d`, with `compile_ok` and
`current_proofs_match` true. Generated SML hash
`756add891fcba8d98639a3a3060f5b4856ad35f9e5dbed3b57e80bbac9546813`;
final native hash
`4f6ad21e6027d493462410c52f5afb76441fa4457cd35502ce6c5bfd2cc0e79b`.
The manifest binds the actual final shared numeric module consumed by MLton.

Domain capability counts are **33 right / 0 wrong / 0 false yes / 1 withheld-valid**,
versus captured C **10 / 5 / 17 / 2**. All 34 policy assertions pass; the valid
unsupported product spelling `1×10^3` remains a withheld capability, not a correct
answer. Existing runtime probes pass 22/22, including meaningful zero efficiency
and zero usable depth. Some inherited Energy reply variants have no numeric
`value` field; those probes explicitly extract the result after `is` in reply
text, following their own scorers' convention with signed numbers retained.
They do not read an operand from the formula. Receipts:
`energy-domain-{before,after}.json` and `energy-D-Cprobes.json` under
`var/c-physical-energy-geostats/`.

| Specialist | Dev right | Held right | Wrong / false yes / withheld valid |
|---|---:|---:|---|
| thermo | 44 | 50 | 0 / 0 / 0 |
| energy-v2 | 68 | 74 | 0 / 0 / 0 |
| energy-v3 | 74 | 70 | 0 / 0 / 0 |
| hvac | 41 | 42 | 0 / 0 / 0 |
| renewables | 26 | 26 | 0 / 0 / 0 |
| iot | 27 | 27 | 0 / 0 / 0 |

Both pinned and family modes have these same own-scorer rows. Fresh offsets
39118 and 49118 preserve renewables 26/26 and IoT 27/27 before/after, with zero
wrong/false yes/withheld-valid. The other four identities have no generator in
the upstream snapshot. Offset 49118 was generated only after native/source
freeze. See `energy-D-fresh-{39118,49118}-{before,after}/receipt.json`.

Final size 779,096 bytes (C: 776,712); cold starts 6.74, 3.94, 11.47, 11.64,
3.91 ms; pinned in-binary p50 0.087–0.178 ms. Live-host results remain below
all budgets; they are not isolated speedup claims. Full receipt
`energy-D-after.json`.

Exact Energy files: `Energy_Export.thy`, `Energy_Family.thy`, `Home.thy`,
`Hvac.thy`, `Iot.thy`, `Renewables.thy`, `Thermo.thy`, `recognizer.sml`,
`build.sh`, `capabilities.json`, `README.md`, `probes.json`, `domain_probes.json`,
all under `src/extract/energy/`; this report, plus the shared lane-owned
`src/extract/geostats/check_probes.py` accounting change. No upstream/shared
runtime source changed. Independent semantic consumer checks pass 10/10; root
integrated `fc35ef2` and runtime captured immutable NEXT, as detailed below.

## Final GeoStats source-unit repair packet

Proof refresh `20261018T080751Z-04cafcbc6f29` passed, 102 roots / 0 oracles.
The mathematical statements are unchanged; the refreshed receipt binds the
clarified theory text. Actual native attempt `20261018T081448Z-9953f06acfcd`
and `var/geostats/build/compile-inputs.json` bind this receipt, final numeric
module and reader. Both success/matching flags are true. Generated SML remains
`82039ce482ab4d3bed5d7eae5c3cea2c71c284a5a020288f8ae334e61dc6dc22`;
final native is
`0b34301084dcee43852253631c4e134853f202c763dee294020befeee81890fc`.

The expanded 44-case set scores **40 right / 0 wrong / 0 false yes / 4 withheld-valid**,
with 44/44 separate policy assertions passing. Relative to held c999, this
repairs five wrong answers and one false yes; one repaired question now safely
withholds rather than answers wrongly. The four unsupported valid requests are
product-form scientific notation, exclusion by observation position, paired
weighted exclusion, and postfix-weighted spelling. The latter is the next
small request-binding completion using the existing weighted kernel, after
capture. All 20 earlier probes still pass.

All six own-scorer shipped rows (both pinned and family) remain those in the
preceding table, with no wrong/false yes/withheld-valid. Final fresh offset39118
passes; new untouched offset59118 was generated only after this repair froze
and passes 142/142 for every statistics identity, before and after. There is
still no geometry generator. Receipts: `geostats-unit-{before,after}.json`,
`geostats-unit-Cprobes.json`, `geostats-unit-score.json`, and
`geostats-unit-fresh-{39118,59118}-after/receipt.json`; baseline39118 is the
existing D-before receipt, baseline59118 is `geostats-unit-fresh-59118-before`.

Final native size 595,032 bytes; cold starts 6.30, 6.11, 6.02, 6.21, 6.16 ms;
pinned in-binary p50 geometry 2.87–2.92 ms and statistics 0.09–0.10 ms.
Repair files: `GeoStats_Extensions.thy` (text only), `recognizer.sml`,
`capabilities.json`, `README.md`, `domain_probes.json`, `check_probes.py` under
`src/extract/geostats/`; this report. Independent consumer checks pass 15/15;
root integrated `e658418` and runtime captured immutable NEXT. Held c999 must
not be packaged as the corrected build.

Final composed-consumer audit found HVAC’s inherited manifest accepted only underspecified and sizing refusals. The new physical guards correctly returned `hvac>impossible`, but dispatch dropped it. The Energy sidecar now explicitly admits this newly reachable domain refusal; the existing HVAC context already covers CFM and air changes. The native/proof inputs are unchanged. Other physical Energy identities already admitted impossible. Parent consumer rerun pending.

Physical deputy independently audited both final proof targets and actual compiler manifests. The corrected GeoStats binary passes all 15 composed physical-consumer checks in `var/c-physical-integration/geostats-d-repaired-consumer.json`, including source-unit inheritance and incompatible angle/output-unit refusal. Immutable capture remains pending.

Runtime captured corrected GeoStats as NEXT only at `var/C-runtime-package/bound-prepared/20261018T081448Z-9953f06acfcd/geostats`, verifying all five actual compiler inputs. The selected C packet is unchanged. Root integration confirmation is the remaining source-reopening gate before weighted grammar completion.

Root integrated the corrected GeoStats packet as `e658418` and released the source after runtime capture. The weighted grammar follow-up now reuses the complete exact-list parser for both values and weights; it does not change HOL arithmetic or geometry unit handling.

## Weighted grammar completion after corrected D capture

The complete finite-list parser now binds both prefix and postfix weighted mean
forms, including “with weights” and “using weights”. Values and weights share
exact fraction/scientific/signed scalar parsing and matched optional brackets.
The same existing HOL `weighted_reply` checks length equality, nonnegative
weights and a positive total. Unsupported suffixes cannot fall back to an
ordinary mean; unsupported statistical operations remain decisive refusals only
after actual dataset recognition. Geometry and all HOL sources are unchanged.

Final native `099f430bc4cb26405742fcb67f900e4829c8a0db28977f7f248c775496ce6489`
comes from immutable helper attempt `20261018T083115Z-4e072dd2b1bc`, manifest
`var/geostats/native-attempts/20261018T083115Z-4e072dd2b1bc/compile-inputs.json`.
It consumes the existing current 04caf proof/export (102 roots, no oracles).
No new Isabelle build was needed for this reader-only change.

The 28 weighted probes improve from **12 right / 0 wrong / 0 false yes / 16
withheld-valid** to **26 / 0 / 0 / 2**; all 28 policy checks pass. The two valid
unsupported cases are paired exclusion and a trimmed weighted mean. Existing
44 domain probes now score **41 / 0 / 0 / 3**, with all 44 policy checks passing;
the earlier 20 probes remain 20 right. Receipts are `weighted-grammar-{before,
after}.json`, `weighted-domain-after.json` and `weighted-Cprobes.json` in this
lane's scratch directory. Ordinary average-speed and batting-average controls
remain untaken; unread weighted tails and unmatched brackets are refused.

All six shipped specialist rows, both pinned and family, remain equal to the
final D table above, with no wrong/false-yes/withheld-valid cases. New fresh
offsets 69118 and 79118 score 142 dev / 142 held for each statistics identity,
before and after, all errors zero. Offset 79118 was first generated after final
reader/native freeze. There is still no geometry generator. Receipts are
`weighted-fresh-{69118,79118}-{before,after}/receipt.json`.

Native size is 594,232 bytes, 800 bytes smaller than corrected D. Cold starts
were 9.93, 10.57, 9.26, 9.17 and 10.26 ms; pinned in-binary p50 was 3.03–3.52 ms
for geometry and 0.10–0.14 ms for statistics on the shared live host. These are
observations, not isolated performance improvement claims. Full own-scorer and
performance receipt: `weighted-score.json`.

Exact files: `src/extract/geostats/recognizer.sml`, `domain_probes.json`,
`weighted_probes.json` (new), `README.md`, and this report. Independent composed
consumer checks pass 7/7. Root integration and immutable NEXT capture are pending
before paired-data statistics work reopens these sources.

Energy D is integrated as `fc35ef2`. The final independent composed receipt is `var/c-physical-integration/energy-d-consumer.json`; where inherited Energy replies omit a scalar value field, the consumer records explicit extraction from the stated result text. The sidecar retains decisive HVAC invalid-dimensions refusal. All ten semantic checks pass; capture is complete as recorded next.

Runtime captured Energy D as NEXT at `var/C-runtime-package/bound-prepared/20261018T081454Z-76be3d79551d/energy`, verifying five actual compiler inputs and the committed sidecar. Both integration and capture gates are complete. Current selected delivery remains the earlier Energy C packet.

Weighted grammar independent composition passes all seven checks in `var/c-physical-integration/weighted-next-consumer.json`, using different observations and weights, quarter fractions, zero/negative/mismatched weight cases, and paired-exclusion refusal. Physical deputy also verified current reader/helper/proof input hashes against native `099f430b…`. Runtime NEXT capture is complete at `var/C-runtime-package/bound-prepared/20261018T083115Z-4e072dd2b1bc/geostats`; root integration remains before paired-statistics source reopening.
