# Life H: wildlife observations and requested units

H fixes signed animal counts becoming positive, discarded conflicting
recapture observations, annual rates inferred from multi-year totals, and
ignored requested density units. Frozen G counterexamples are preserved in
var/life/h-next/counterexamples.json.

Density now converts between hectares, acres, square kilometers and square
miles. 50 deer across 2 hectares means 2500 per square kilometer. Whole count
roles support exact scientific notation and reject negative/fractional
animals. For a closed cohort 100→75→60, mortality during the second period is
20%; cumulative mortality is 40%. First/second endpoint identity survives
reordered statements. An annual/monthly request with an incompatible observed
period declines without an assumed time model.

The official shipped score is 179/179 in both specialist and family modes,
with 0 wrong, 0 false yes and 0 withheld-valid. Development 10181001/10182003
and untouched 10190047 each score 179/179. All 13 source-table checks pass.
All 174 same-author policy assertions pass. Capability counts are 161 right,
0 wrong, 0 false yes, 13 withheld-valid, 0 errors. The frozen G binary on the
same 174 cases has 132 right, 12 wrong, 15 false yes, 15 withheld-valid. The organ
has 57 right, 42 wrong, 37 false yes, 35 withheld-valid, 2 errors and 1 unassessed
answer. These authored probes supplement the independent shipped scorer.

The final binary is 823528 bytes; median of five process starts is 3.761 ms.
Native 6a0fc44e8c9264188edc524d59a192820f76c76f4a5c65ab945c772647636e3d
is bound by the shared helper to the actual generated code, recognizer, main,
commons and frozen numeric 2f313c77…046d inputs. Successful native receipt:
var/life/h-next/checkout/var/life/native-attempts/20261018T095420Z-73232404eb8a/compile-inputs.json.

The passed proof 20261018T095249Z-e51c4d23d013 scans 133 statements with zero
oracles. Five added laws state:

- A successful converted density is positive-area and satisfies
  q × area × input-unit-square-metres = count × output-unit-square-metres.
- Equal input/output units agree with the prior density kernel.
- A successful two-endpoint rate requires nonincreasing survivors, a positive
  original cohort and a nonempty conditional denominator.
- A survival percentage times its selected denominator equals 100 times the
  surviving endpoint count.
- First-period survival percentage times second-period conditional survival
  percentage equals 100 times cumulative survival percentage.

Proof source is in Wildlife.thy; the scanned statements bind the functions
consumed by the native reply. Exact unit factors use international feet/miles
and acres. The English reader and observation completeness remain untrusted.
The prior completed Isabelle build lacked its log marker; its failed receipt
is preserved. The final theory exports a durable veri7vn/assertions/life marker
using the same pattern as Earth, and the final receipt validates that export.

Limits: the cohort model excludes entrants/replacements; more than two capture
occasions require another estimator. Annualizing an aggregate requires another
time model. Requested square-meter density remains valid but unsupported.
The inherited Chapman kernel still requires positive overlap even though the
zero-overlap algebraic formula is finite; its old shared refusal names
Lincoln-Petersen. H does not claim to solve that coverage limit or establish
sampling assumptions such as closure/equal catchability.

Changed candidates relative to G: Wildlife.thy, Life_Core.thy, Life_Export.thy,
gen/part2.sml, generated recognizer.sml, capabilities.json, probes.json,
README.md and semantic-gaps.md, plus this report. Exact mappings/baselines are
var/life/h-next/transfer.json; ready packet is var/life/h-delivery/ready.json.
The specialist/family CLI and sidecar-aware Dispatcher are the consumers.
Actual Dispatcher evidence is recorded below; no live source or selected
package promotion is implied by this staged packet.

Actual staged Dispatcher checks pass 7/7, including requested area-unit text,
20% conditional versus 40% cumulative mortality, and terminal negative-count,
conflicting-observation and period-mismatch refusals. Receipt:
var/C-runtime-consumers/staged-H-life.json. It binds the frozen native,
declarations and runtime sources without promoting live or selected versions.
