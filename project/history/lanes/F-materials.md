# F Materials — typed uniform scaling operations

Historical F checkpoint, now included in the corrected G packet described in
[G-materials.md](G-materials.md). The following results remain attributed to F.

At that checkpoint, isolated proof, native and panels passed. Staged native was
0aa08153; live E was then unchanged pending root integration/capture release.
The first 50190b7f candidate is held: independent review found that its factor-only
reader lost scale-down direction and relative-percent semantics. Actual wrong
answers remain in var/F-materials/rejected-direction-candidate.json and
operation-rejected-absolute.json. The replacement fixes the operation model.

The shipped organ promises linear length scaling, but the earlier lifted request
only distinguished area from volume. The final request carries length, area,
volume or mass, plus an explicit operation: absolute multiplication, division,
relative increase or relative decrease. Their effective linear factors are s,
1/s, 1+s and 1-s. Signed percentages are exact fractions. The effective factor
must be positive, and supplied physical amounts nonnegative.

Thus a 10 cm length scaled down by a factor of 2 becomes 5 cm; up by 50 percent
becomes 15 cm; down by 25 percent becomes 7.5 cm; down to 25 percent becomes
2.5 cm. An explicit postfix x/× denotes an absolute multiplier, preserving the
shipped 'scaled up by 0.5x' convention. Bare fractional up/down factors remain
ambiguous and withheld. This syntax distinction is explicit, not a question
literal exception.

Original exact quantity spans and units come through shared MeasuredInput.
The requested output cannot relabel a mass as a length or area. Results retain
source units. Uniform geometry gives degree one for length, two for area and
three for volume; mass additionally assumes unchanged density. Explicit density
changes, fixed axes and nonuniform scaling are refused instead of overriding
the supplied conditions with an assumption. Unchanged-density controls pass.

## Checked statements and limits

For every successful ScaleAmount(mode,s,d,b,u), the kind is scale_amount,
scale_valid(mode,s) holds, the effective multiplier is positive, b is nonnegative,
d equals the source unit's dimension, and the result is b times the effective
multiplier to degree one, two or three. Sequential successful operations agree
with one successful absolute scaling by the product of their effective factors.

Independent length laws bind a division answer v by v*s=b, an increase by
v=b*(1+s), and a decrease by v=b*(1-s), with the corresponding positive-effective-
factor domain. Existing absolute length/area/volume/mass laws remain explicit.
The proof concerns exact arithmetic in this named model. English operation
recognition, unit attachment, numeric lexing, native compilation and framing
remain untrusted; declaration metadata is not a proof of the user's intention.

Unsupported unit conversions, nonuniform geometry and changed density remain
capability misses. Mesh existence/count validity is a separate successor packet
in G-materials.md; F does not claim that Euler arithmetic realizes a mesh.

## Measurements

Both isolated and whole-family modes: shipped mapped 440/440, fresh seed20280118
444/444, untouched seed20280219 454/454; all have 0 wrong and 0 false yes. E also
gets 444/444 and 454/454 on those exact fresh panels. The final official scoped
harness gets 347/347; water-r3 has NO PANEL, and its inherited 93 only contribute
to the mapped total. Verdict remains INCOMPLETE because full-head six-criterion
evaluation was not run. Fresh sampling uses shipped generator templates.

131 authored probes: E baseline 104 right, 7 wrong, 4 false yes, 16 valid withheld;
final F 125 right, 0 wrong, 0 false yes, 6 valid withheld. All six separate policy
assertions pass and require a typed underspecified result. The six valid misses
are pounds conversion, an ambiguous fractional direction factor, two density
modifications and two single-axis/nonuniform conditions. They are not counted
as correct capabilities merely because refusal is appropriate for this model.
The held factor-only F candidate scored 118 right, 8 wrong, 1 false yes and
4 valid withheld on these same questions.

Native size 862056 bytes. Five shipped-run startup times:89.41,4.01,3.55,3.88,
3.67 ms; median3.88 ms. The first launch is retained. Fresh/untouched medians are
3.90/3.80 ms. These are local macOS timings, not Linux performance claims.

## Exact binding and consumers

Managed proof persvati `20261018T093044Z-9c62e92136e8`:81 roots,0 oracles,exit0.
The final signed-relative-domain proof needed one case-split tactic repair;
its statement and operative model were retained.
Export SHA256 `fdf1ba3abb219b4fd87c3c3e0f84a494965cadffeed7bb74606d3bf36001891d`.
Native SHA256 `0aa08153d383046f66c60aea32f2348a86e8ba4bd383a7c4ef54743e9a34697d`.
Actual-input receipt:
`var/F-materials/operation-checkout/var/materials/native-attempts/20261018T093437Z-b4393c6e98d6/compile-inputs.json`.
The refreshed shared native helper used the Git-common compiler lock and the
staged family pointer; live E's convenience manifest was not overwritten.
Shared measured-input hash11f70352 and numeric hash2f313c77 remain unchanged.

Changed owned files: Materials.thy, Materials_Export.thy, recognizer.sml,
main.sml, capabilities.json, probes.json, score.py and README.md, staged under
var/F-materials/staged. The exact source hashes are in final-source-hashes.json;
operation-summary.json contains arithmetically summed measurements. Evidence:
operation-selected-shipped.json, operation-selected-fresh.json,
operation-selected-untouched.json, operation-before-E.json and operation-parity/.
Existing scale_amount/scale_factor wire kinds remain unchanged; the new typed
operation and dimension constructors are consumed by the reader and renderer.
Temporary final dispatcher composition passes6/6 with exact native and staged
capabilities: var/C-runtime-consumers/staged-F-materials-final.json. The cases
cover5,15,2.5, two terminal underspecified conditions and unchanged-density80.
Root integration and Linux
capture remain separate; no staged candidate is claimed as production delivery.
