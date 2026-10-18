# Stores: current sensor readings must be timely and agree

Owner: Codex `/root/symbolic/stores`, 18 October 2026. F was integrated as
`55b9d8a` before these production changes. The separate reader-domain repair
was integrated as `36403e7`. Proof, Darwin and scoped consumer checks below pass;
the already-started Linux closure is the remaining platform check.

## Actual counterexamples

With the site's snapshot clock at 2026-09-28 noon, an owned copy containing an
Aisle 1 temperature reading from the next day answered “77 C … read just now.”
The age renderer treated its negative age as recent. The same future value also
appeared in the zone summary.

Two rows at the same latest timestamp, one 20 C and one 40 C, exposed another
fault. Inserting 20 first answered “Yes” to the range question and “all readings
in range” in the zone summary; reversing row order answered “No” and “temperature
out of range.” The snapshot contained the same conflicting evidence. Stable
row order was not evidence for choosing one value.

These were isolated SQLite copies, opened by the binary in immutable mode, with
preview-only state. No shipped database or user's state changed. The actual F
replies are in `var/stores/sensors/baseline.json`.

## Shared finite interpretation

`checked_latest now fresh rs` selects the greatest supplied timestamp and then
classifies it:

* No row: missing data.
* Timestamp after the supplied site clock: future reading.
* Age beyond the freshness bound: stale reading.
* Fresh rows tied at that timestamp with different values: conflicting readings.
* Otherwise: one agreed current value.

Duplicate latest rows with the same value are allowed. Conflicting older rows do
not invalidate an unambiguous newer reading. Exactly the freshness boundary is
included; one second older is stale. Both the standalone sensor/range reply and
the zone's displayed parts and flags consume this same classifier.

New withheld kinds are `sensor_time`, `sensor_conflict` and
`sensor_missing_data`. The latter distinguishes an installed sensor without a
stored reading from a missing sensor. Zone summaries omit unsafe values and
state the specific issue; they do not silently call all readings in range.
The family sidecar declares those refusals and adds bounded sensor-plus-site
context for unpinned ownership. A generic mention of temperature alone is not a
blanket new warehouse claim.

## Exact checked proof statements

The strengthened `sensor_fresh` takes an actual `SO_sensor` output from `sstep`.
It concludes that its value occurs in the supplied sensor rows at the greatest
timestamp, that timestamp is no later than the supplied site clock, its age is
between zero and the freshness bound, and every supplied row at that timestamp
has the same value. It also preserves the original sensor metadata and complete
fetch premise.

The strengthened `zone_parts_fresh` takes an actual displayed `(kind,value,unit)`
in the zone-part list. It concludes there is a supplied matching sensor whose
latest reading has that value, is no later than the site clock, is fresh with
nonnegative age, and agrees with every supplied tied latest row.

`future_latest_refused` assumes complete evidence, a supplied sensor with latest
row `(ts,v)`, and `now < ts`; the actual reading transition returns the typed
future-sensor refusal. `conflicting_latest_refused` assumes complete evidence,
a latest row at or before now within the freshness window, plus another supplied
row at that timestamp with a different value; the reading transition returns
the typed conflict refusal. `checked_latest_live` supplies the common finite
lemma used by the answer and zone theorems.

The old stale-refusal theorem now explicitly assumes the latest timestamp is not
in the future, because a future timestamp has its own earlier refusal branch.
No theorem is being described as a proof of omitted-row coverage. The site clock,
freshness configuration, accuracy of measurements, supplied sensor metadata and
untrusted fetcher's completeness claim remain assumptions. Equality of tied
values is exact equality of the supplied rationalized values, not a sensor-error
model or calibrated uncertainty interval.

## Tests and measured results

`sensors_check.py` works on temporary copies and independently computes timestamp
cases with Python datetime and sensor midpoint/range values with Decimal. It
covers all five sensor kinds under both specialist IDs, with future, conflicting
ties in both orders, identical ties, exact freshness boundary, one-second stale,
exactly now, older conflicting rows with a clear newer reading, and no readings.
Each case checks individual value, range question and zone summary. Preview must
create no state file.

Answered values are counted separately from meaningful questions that must
withhold for lack of unambiguous current evidence. Zone assertions check the
presence/absence and flags of the affected kind; they are not a replacement for
all zone data semantics. Shipped specialist scorers remain the completion metric.

The final native run passed 270/270 observations: 80 answered-correct individual
value/range questions, 100 withheld-valid individual questions, and 90 focused
zone-summary policy checks. There were zero failed assertions and no preview
state files. The independent expected values use Decimal midpoint arithmetic and
Python timestamps; these are authored probes, not unseen specialist panels.
Receipt: `var/stores/sensors/checks.json`.

All six shipped specialist panels retain 2,448 right of 2,476, zero wrong,
zero false yes and 28 withheld-valid. Per split:

| Specialist | Development | Held out |
| --- | ---: | ---: |
| cooking | 200/202 | 214/218 |
| cooking-v2 | 207/210 | 205/210 |
| cooking-v3 | 190/192 | 223/228 |
| cooking-v3-r2 | 190/192 | 223/228 |
| warehouse | 199/199 | 199/199 |
| warehouse-r2 | 199/199 | 199/199 |

Receipt: `var/stores/sensors/shipped.json`. The current verifier also passes its
20 cooking probes, domain-routing/refusal checks and isolated pending/reference,
preview, failed-read and failed-write checks. No new general fresh-seed panel or
performance improvement is claimed. Unrelated code paths were not given another
large authored numeric sweep.

The actual dispatcher passed 24/24 scoped checks using the bound G binary and
hashed wrappers that explicitly supply owned SQLite fixtures. Future, both
conflicting-tie row orders and missing readings were checked as individual,
range and zone questions, both pinned and unpinned. All three new refusal kinds
survive acceptance; unsafe temperature values are absent from zone summaries.
Every evaluation preserves existing state bytes, and unpinned turns create no
state file. Only the normal code precheck, Stores selection and permitted pinned
commit stages run; no later answering route supplies a replacement. Dialogue and
other routes are disabled, so this is not a new full-fleet claim. Reproduction:
`python3 -B var/stores/sensors/consumer.py`; receipt
`var/stores/sensors/consumer.json` records binary, sidecar, fixture and wrapper
hashes. The separate F reader fix has the actual full-default consumer gate.

## Bound artifacts

The passed managed proof is
`var/stores/remote-attempts/20261018T102011Z-91679b8b9c9d/receipt.json`:
48 theorems, zero oracles. The two preceding attempts exposed a non-executable
unbounded rational quantifier and then a missing explicit finite witness; both
were repaired in source. Neither failed attempt supplies the final export.

Darwin `var/stores/sensors/bound` is 653,000 bytes, SHA256
`aec3c8e002c9311f13cf36c79e68115e8c0b02021e2f002e159b2a5d32c1db31`.
Its actual compiler-input receipt is
`var/stores/native-attempts/20261018T103115Z-aaa9b955fde8/compile-inputs.json`.
The helper bound the current proof dependencies and every consumed SML input
before compiling. The shared numeric input is unchanged at `2f313c77…`.

| Input | SHA256 |
| --- | --- |
| Stores.thy | `3ca416ebb7f7836a2eb7fd60ed677928e14b3913401306f71ec38107707d9cfa` |
| Stores_Export.thy | `8b14d01a832f7fcf9619b67de7a028abb02655149faf36591fe0142681f3db33` |
| Generated SML | `c8b78245076d508a22ac0bf01675c08eb2b42d2b104cf2c1284b23961b7dc9c6` |
| main.sml | `808aeeb16dbf8592031a1f4df437b488d837a6a94edfdbb8c21d6f3542de2371` |
| capabilities.json | `6225f02ff86515fcb5aac99e2a873b89781ca827ff530685f671b52c2b209daa` |
| sensors_check.py | `695595e4b57252f859a2dfecc19741955120ec4a0a02159e441f3d0cbdf371b9` |

## Remaining stock-time boundary

G does not change stock-event aggregation. In another owned copy, adding a
999-valve event dated tomorrow makes the current stock reply rise from 107 to
1,106. Receipt: `var/stores/sensors/future-stock.json`. Existing `stock_value`
proves the sum of supplied deltas; it does not prove all timestamps are past.
Likewise `used7` currently has a lower time bound but no upper bound. Fixing this
coherently requires a snapshot cutoff for stock, runout, low-stock, neighbour and
proposal counts, including timestamp-bearing evidence where the current fetch
shape discards timestamps. A fetch-only filter would leave the kernel's omission
premise implicit and is not claimed implemented here.

## Domain routing repair from the actual consumer

The full dispatcher exposed a separate F error: `Solve 3x - 4 = 11.` entered
Cooking's numeric masker before its nutrient/request check and returned an
error. G establishes that domain first. Unrelated algebra returns notTaken;
recognized nutrition with malformed amounts still withholds. This is a producer
boundary fix, not an exception-swallowing change in the dispatcher. The native
checks exercise four unrelated queries under family and all four cooking modes,
plus malformed cooking amounts under each mode. Root separated this repair from the queued sensor work and committed it as
`36403e7`. Its exact retained-F native artifact is `dc4c756b…`; the actual
dispatcher passed named 10/10 and independent 19/20, with only an unrelated Facts
metadata follow-up failing. The F report records its full source/proof closure
and unchanged 2,448/2,476 shipped score. G will inherit the committed repair but
must still establish its own sensor/native results.

## Per-specialist frontier

| Exact ID | Concrete behavior reviewed in G | Remaining boundary |
| --- | --- | --- |
| cooking | Domain-first numeric parsing, including malformed unrelated algebra under this version's normalization | Nutrient/food text recognition remains untrusted; numeric quantities must occupy one issued role |
| cooking-v2 | Same domain check after this version's narrative boundary and normalization | No new narrative or food-attribute coverage claimed |
| cooking-v3 | Same numeric-domain interaction; existing explicit mass/count model retained | Ambiguous alternatives and missing nutrient data continue to withhold |
| cooking-v3-r2 | Domain check after this version's NOT_MINE/MINE boundary | Conservative ownership may decline valid nutrition; no blanket routing expansion |
| warehouse | Current/latest sensor algorithm used by value, range and zone replies; future and contradictory supplied rows tested | Sensor metadata uniqueness, external row coverage and stock-event time cutoff remain assumptions/gaps |
| warehouse-r2 | Same sensor algorithm behind this version's narrower recognition and declared refusal kinds | Unrecognized site phrasing may fall through; G does not infer arbitrary zone aliases |

## Changed files and consumers

The packet owns `Stores.thy`, `Stores_Export.thy`, `capabilities.json`, new
`sensors_check.py`, the Stores README, main driver theorem provenance list and
this report. The recognizer domain boundary and verify checks were separately
committed in `36403e7`; they are not part of G's remaining named diff. Order
parsing, shared numeric parser and fetch shim remain unchanged. Consumers are
the standalone sensor/range API, zone summaries, native dispatcher and relocated
package. Current F captures remain immutable historical artifacts.
