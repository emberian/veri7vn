# Fleet economy, output volume and price units

Fleet used to return US gallons even when Imperial gallons were requested.
Its price boolean could represent only US gallon or litre, so a suffix such
as `gallon (Imperial)` was silently priced as US. Prefix-qualified prices and
three-sentence trip descriptions often withheld. The original 39-case audit
had 12 right, three wrong amounts, three wrong output units and 21 valid
withholds. Its evidence remains in `project/audits/evidence/fleet-units-20261018.json`.

## Implementation and the statements it proves

`fuel_unit` has US liquid gallon, Imperial gallon and litre, with exact positive
litre scales. `FvVolume` replaces two output constructors and carries the
requested unit. `FvCost` replaces the price boolean with the independently
specified price unit. Existing `E_mpg` still distinguishes US/Imperial economy;
`E_lpk` expresses litres per 100 km. These three roles are not inferred from
one another. Shared `fuel_amount` converts the canonical volume once for either
output or pricing, and reply text names the requested volume system.

The source-balance predicate is independent of the output function:

- MPG economy: `litres * economy = miles * litres_per_economy_gallon`.
- Metric economy: `litres * 100 = kilometres * litres_per_100_km`.

`trip_volume_source_units` derives nonnegative distance and a valid economy
from actual kernel acceptance and proves that the source balance holds for
`answer * fuel_scale(requested_unit)`. `trip_price_source_units` additionally
derives nonnegative price and proves that a source-balanced litres quantity
satisfies `cost * fuel_scale(price_unit) = litres * price`. Existing exact-reply
and stated-rounding results connect those rational results to `reply_of`.
No new axiom or admitted proof was introduced. English interpretation is still
untrusted; the statements apply to the typed request actually constructed.

The reader handles prefix and parenthetical gallon qualifiers, including UK,
and keeps economy matches out of the output-unit search. It requires one trip
distance, one economy and at most one price, accounts for the numeric tokens,
and refuses inconsistent labels. A scoped direct-trip path accepts up to three
sentences without relaxing the other readers' narrative guard. Unknown adjacent
output qualifiers, dry gallons and unknown single-word parenthetical labels
are withheld. Broader natural-language qualification remains unexamined.

## Proof, native and measured results

The first proof attempt `20261018T115349Z-e53ddaf1d016` failed in the new
nonzero-scale lemma. Root replaced that proof step with direct cases over the
three exact scales. Managed proof `20261018T115616Z-53e322301edf` passed
**99 scanned statements, zero oracles**. No statement was weakened.

Managed native compile `20261018T120137Z-bac35ad2035c` binds that export, the
current proof closure and actual reader/driver. The narrow verifier reports
zero proof/runtime source differences. Active native SHA256:
`97bbd48bf0e38c189f43ba20f9738ef6762cdc008109892e46293c7c690d59c3`.
The preceding efficiency native is retained, and its correction remains present.
The current immutable capture is
`var/C-runtime-package/bound-prepared/20261018T120137Z-bac35ad2035c/mechanics`.

- Fleet own shipped panels: **108/108**, zero wrong or false yes.
- All nine family shipped panels: **1264/1264** in both isolated and family modes,
  zero wrong/false yes/valid withholds.
- Original independent unit-role panel: **39/39**, zero wrong or valid withholds.
- Expanded 107-case baseline: old native 29 right, 16 wrong amounts/units,
  five false yes and 57 valid withholds; corrected native **107 right**.
- Three additional unsupported-unit probes remain valid withholds. The full
  expanded 110 cases comprise **97 numerical answers, ten correct invalid
  refusals and three valid withholds**, with no wrong or false yes. All 110
  expected-behavior assertions pass. The actual full dispatcher gives those
  same counts using the candidate native.

The last three probes exposed two initial reader substitutions after the
107-case pass; root corrected the reader and broadened the qualification check.
All final measurements above use the final native. No fresh shipped Fleet
panel generator was found; the additional numeric/role cases are independent
checks, not claimed as fresh original-generator panels.

Tracked current observations: `project/audits/evidence/fleet-units-fixed-20261018.json`.
The Fleet audit record binds the immutable new native and retains its historical
receipt reference. Local checks, predecessor and integration index are under
`var/root-fleet-units/`. The exact integration index is
`var/root-fleet-units/integration.json`.

Linux and scoped portable packaging also passed. Managed Linux receipt
`var/linux/receipt-mechanics-persvati-mechanics-1792325003-97113.json` records
1264 freshly scored replies identical to macOS, all correct. Linux native SHA256:
`1639907a67c967e7bda630f95714db179a3e00ba578060094a0d5229986f1f70`.

The nine-folder macOS/Linux package at
`var/root-fleet-units/portability/package/veri7vn-specialists-2026-10-18.tar.gz`
pins shared consumers to `382a7cf`. It is 866,560 bytes, SHA256
`95b7f8dae5e976ab6ff3126d5068d54a1f5631fb5b818a8c1669d7edaf459968`.
Both relocated platforms again score 1264/1264 with identical replies, including
46 correct invalid refusals. Their 110 Fleet unit-role checks also match exactly:
97 numerical answers, ten correct invalid refusals and three valid withholds.
All expected-behavior assertions pass; the withholds remain capability gaps.
Exact bindings and evidence: `var/root-fleet-units/portability/delivery.json`.
All nine explicit specialist audit records validate, but remain partial coverage
of the full system. No proof, compiler, remote test or implementation job remains.

## Remaining surface

US dry gallons and unsupported named gallon systems remain capability gaps.
Compound trips, multiple prices, variable economy and richer unit vocabulary
need further model/reader work. Braking slopes, varying traction and emissions
assumptions remain unaudited. The separately tracked efficiency-aware shaft-power
request also remains unsupported. The complete 144-specialist archive has not
been refreshed with this repair.
