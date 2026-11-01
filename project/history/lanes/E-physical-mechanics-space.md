# Mechanics mass units and Space adaptive precision

Owner: Codex physical/mechanics_space. Separate work after Mechanics
D (`6d46a9d`, immutable captured native `09823e49…`) and the ready Space D
packet (`d05c210e…`, frozen pending integration/capture). Those packets retain
their own measurements in C-physical-mechanics-space-next.md.

## Mechanics: exact declared mass units

The baseline binary withholds all five examined valid requests: 500 g kinetic
energy, 2 lb directed momentum, 1 tonne force, a 400 g object's weight on Mars,
and a 2 yard / 1 mile lever ratio. Saved full replies are in
`var/c-physical-mechanics-space/next/units/before.json`.

The new model defines exact mass scales for grams, kilograms, metric tonnes,
and international avoirdupois pounds (0.45359237 kg). A typed `mass_kg` function
performs conversion. The same reader feeds every existing mass-bearing physics
request (kinetic/potential energy, momentum, weight, force) and body weight.
The existing nonnegative mass domain sees the converted signed value, so a
negative gram amount cannot become positive. Velocity and acceleration remain
directed fields; their signs are retained. Bare `ton` remains ambiguous and
unsupported; `tonne` and `metric ton` are explicit.

Yards and miles extend the existing positive length-scale datatype with
0.9144 m and 1609.344 m. This automatically covers mechanism torque/geometry
and the existing typed length consumers. The 2 yard / 1 mile request is now
an answerability target, not an invalid-input refusal control.

The proposed output statements are:

- If body weight accepts `mass_kg m u` and emits y, then m and gravity are
  nonnegative and `y = (m * mass_scale u) * gravity`.
- If kinetic energy accepts `mass_kg m u` and velocity v and emits y, then m
  is nonnegative and `y = (m * mass_scale u) * v^2 / 2`.

Proof attempt `20261018T083453Z-97b4beafe5af` passed on persvati, with
72 checked theorem roots, zero oracles, and a 97.752 s target session. Both
output statements above are proved; final numeric results follow below.

Complete numeric literals still come from shared ExactNumeric issued tokens.
MeasuredInput.unitAt binds the whole mass-unit span without doing conversions;
HOL owns the scale. The shared compound-unit repair is frozen at hash
`e185541019df950f64d59c9c86b9763b2e30937e7b7be84d505da6698832f746`,
with 55 focused checks; the final bound native consumes that snapshot.
No local compound-unit regex workaround is retained. In particular g/s,
g per second, squared grams and pound-force must not become a mass.

The untrusted recognizer type-checks with a compile-only signature bridge,
which is never executed and supplies no numeric evidence. There are 21 new
unit/domain probes (75 total); reserved seed 20261119 was generated before tuning and opened only after the
final parser freeze. No parser edit followed its evaluation.
The saved 75-control baseline scores 61/75 in each mode: all 14 failures are
valid requests withheld. A separate valid-but-unsupported spaced negative sign
remains a policy-refusal control, not a capability success. Receipt:
`next/units/probes-before.json` in the lane scratch folder.

Source files currently changed are Mechanics.thy, Mechanics_Export.thy,
recognizer.sml, main.sml, build.sh, README.md and beyond_probes.json under
src/extract/mechanics. No output kind changes are needed.

## Space: checked low precision with fallback

A separate untrusted scratch experiment changes only generated SML, trying
32-bit interval evaluation before the existing 80-bit path. It accepts a
low-precision result only through the existing checked-decimal predicate.
It is not a published export or proof result.

Against the C parser it preserves all 1,185 pinned shipped replies and the
same family result (1,183 right, two scope false yes, zero numeric wrong or
valid withheld). Pinned orbit p50 is 1.673 ms and spacecraft p50 1.513 ms,
versus roughly 9 ms at 80 bits. All pinned/family p50 values fall under 5 ms.
A separate instrumented run records 64 orbit, 16 planetary, 22 spacecraft
and 11 communications low-precision enclosures, with zero fallbacks in those
shipped panels. The panels alone therefore do not exercise fallback.

Receipts: `var/c-physical-mechanics-space/next/adaptive/score32.json` and
`counts.json`. The old S02 report records an earlier 53-bit path-loss failure
but also an expression rewrite in the same repair; the present 32-bit success
does not establish what caused that older failure. A verified wrapper must
retain fallback and prove its accepted decimal satisfies the same bound
regardless of which precision succeeds. Space D remains frozen; this change
will be implemented only after its immutable capture is released.

Six near-equal Hohmann altitude controls now exercise fallback explicitly:
five use 80 bits and one succeeds at 32 bits. All six emitted values equal the
80-bit baseline, from 5.657e-11 km/s to 1.455 km/s. This cancellation-sensitive
case supplies evidence that fallback is needed beyond the shipped panels.
Receipt: `next/adaptive/fallback-controls.json` in the lane scratch folder.

## Mechanics E candidate before fluid-condition repair

Final native `var/mechanics/bin/mechanics` is SHA256
`a6ecc4b079b9212a2fcb952f0640d4c1673ff764e697af58a048b3ced76d7233`,
758,616 bytes (D was 741,384). Its immutable actual-input manifest is
`var/mechanics/native-attempts/20261018T084201Z-42eb59039633/compile-inputs.json`.
It binds the final shared MeasuredInput hash above, shared numeric
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`, and passed
proof/export hash `2c87f27c1a9c396d5bd78c7ead7f361221267608e541a30ac296903f75c45a23`.
The helper confirms the current theory dependency closure matches the receipt.
An earlier candidate used the previous helper hash; its results were rerun on
the final binary because recompilation changed the binary hash.

Shipped **1,264/1,264 pinned and family**, with zero wrong, false yes or valid
withheld. Untouched seed **20261119: 1,158/1,158**, also zero in those categories.
Fleet has no generator. Every table entry is right/total; pinned and family
shipped counts are equal.

| Specialist | Development | Held out | Fresh seed total | Pinned p50 ms | Family p50 ms |
|---|---:|---:|---:|---:|---:|
| physics | 123/123 | 123/123 | 246 | 0.148 | 0.804 |
| physics-r2 | 123/123 | 123/123 | 246 | 0.203 | 0.778 |
| physics-r3 | 123/123 | 123/123 | 246 | 0.223 | 0.715 |
| mechanisms | 54/54 | 64/64 | 120 | 0.121 | 0.743 |
| mechanisms-v2 | 63/63 | 55/55 | 118 | 0.145 | 0.673 |
| bodies-v2 | 38/38 | 38/38 | 76 | 2.138 | 2.237 |
| sports | 19/19 | 19/19 | 38 | 0.193 | 0.611 |
| fleet | 54/54 | 54/54 | — | 0.131 | 0.469 |
| fluids-r2 | 34/34 | 34/34 | 68 | 0.157 | 0.165 |

Authored policy controls improve **61/75 to 75/75 in both modes**. All 14
improvements are valid answers formerly withheld. The legacy separated sign
`- 40 N` still withholds, so semantic capability accounting is **74 right,
zero wrong/false yes, one valid withheld**, versus 60 right and 15 valid
withheld before. This does not count refusal of an unsupported valid request
as mathematical correctness. The 21 added controls cover declared mass units,
signed velocity, negative mass, zero mass, compound dimensions and extended
length conversion.

Actual runtime composition passes **20/20 pinned plus 20/20 full physical
fleet**, including retained impossible declines for negative mass. The
stateless check disables dialogue, reader, document and routes; the normal
fusion stage remains available. The initial harness invocation lacked its
fusion binary symlink and failed before any request; that harness wiring was
fixed and the exact final binary completed all 40 calls.

Cold starts: 138.467, 5.204, 4.506, 4.770 and 4.853 ms; median 4.853 ms. The
first launch is disclosed separately, not omitted. All measured request p50
values remain below 5 ms. These are scoped local timings, not a general
performance guarantee.

Receipts under `var/c-physical-mechanics-space/next/units/`:

- `shipped-bound-final.json`
- `probes-before.json` and `probes-bound-final.json`
- `sealed/summary.json`
- `consumer.json`

Files in the preceding candidate: `src/extract/mechanics/Mechanics.thy`,
`Mechanics_Export.thy`, `recognizer.sml`, `main.sml`, `build.sh`, `README.md`,
`beyond_probes.json`, plus this report. The mass-unit portion alone needed no capabilities change. The later fluid
repair adds the model-limit decline declaration. Mechanics E was reopened before integration after a cross-family wrong-answer
case; this candidate is superseded by the fluid-condition repair below. Space adaptive precision remains scratch-only.

Independent parent consumer evaluation also passes 10/10 cases in
`var/c-physical-integration/mechanics-e-consumer.json`. Negative grams retain
a decisive kernel `impossible` refusal. Compound g/s is underspecified through
the fleet; pound-force and pound force fall through to `dispatch>declined`.
Those latter cases are untrusted input-role rejection, not typed kernel
refusal theorems. The saved D binary also scores 1,158/1,158 on the same fresh
seed when evaluated after E's freeze (`units/sealed-before/summary.json`);
the improvement appears in the new unit probes, not these generator templates.

## Fluid-condition repair in progress

Independent composition found the fixed fluids-r2 reader answering default
water pressure when the question supplied gravity in grams or a compound
acceleration rate. The same reader could ignore legitimate supplied density,
gravity or surface pressure. It now produces an explicit model-limit request
for those supplied conditions across hydrostatic pressure, buoyancy and
submerged fractions. The new `unsupported_model` reply states its fixed-property,
standard-gravity/atmospheric-pressure limitation. Quantity owns the richer
model and can answer supported conditions; no formula is duplicated here.

The new theorem states this model-limit request always produces its
named refusal and never an answer. This is a checked refusal path, not proof
that the untrusted English guard interpreted the condition correctly.
The existing missing-depth and body-unreadable messages would have misstated
the actual problem, so they were not reused. The scoped proof passed; final evidence follows below.

Seed 20261119 has already been opened for the previous candidate and cannot be
called untouched for this revised parser. The new reserved fluid seed 20261123 was evaluated only after the guard
was frozen. Earlier results above remain honest
measurements of the previous bound binary, not completion of this repair.

## Mechanics E packet before final shared-parser refresh

This section superseded the earlier candidate. The final shared-parser refresh
below supersedes this native binding; family source remains frozen.
The final proof is `20261018T084945Z-24605471e079`: actual Mechanics target
finished, **73 theorem roots, zero oracles**, 89.245 s target session. The new
`fluid_model_limit_refuses` statement binds the model-limit request to a named
`unsupported_model` refusal and proves it cannot answer. The two mass-unit
output laws remain proved. All English role decisions remain untrusted.

Final binary SHA256:
`865161ab50fcaf3e74ca06f09d300db711b6962a3640ec478c41bb375efdcc9c`,
754,680 bytes. Actual input manifest:
`var/mechanics/native-attempts/20261018T085245Z-ece2e107f390/compile-inputs.json`.
Generated export SHA256:
`b21b68568c739903ea0865439e5c689ba75009f2bf63abcef60ab61104c948ce`.
The final shared numeric and measured-input hashes remain those named above;
the parent independently verified all compiler/proof bindings and the actual
finished target marker.

Shipped panels pass **1,264/1,264 pinned and family**, zero wrong, false yes or
valid withheld, preserving every per-specialist count in the table above.
Authored policy controls pass **89/89 in both modes**: the prior 75 plus 14
supplied-fluid-condition controls. All 14 previously returned a default-model
answer despite the supplied condition. Twelve are valid requests outside this
reader and two provide dimensionally invalid gravity. Thus the 14 refusals
are reported as boundary-policy success, not 14 new numerical capabilities.
The 14 new mass/length answers remain intact. The separated negative-sign
wording still withholds. Combined semantic accounting is 76 right, zero
wrong/false yes, 13 valid withheld.

The prior full seed 20261119 remains **1,158/1,158**, measured before this last
fluid guard edit; it is not relabelled untouched for the final reader. New
reserved seed **20261123**, generated before the final fluid-guard freeze and
unopened until afterward, passes **68/68 fluids-r2** with zero wrong, false
yes or valid withheld. Untouched non-fluid measurements from the prior freeze
remain relevant because those recognizers were not edited by the repair.

Own final consumers pass 10/10 pinned fluid-model refusals and 10/10 physical
fleet checks: supported custom gravity/density/surface pressure wins through
Quantity; unsupported conditions end in a model refusal. The separate mass/
length consumer checks pass 20/20 pinned plus 20/20 physical-fleet on the final
binary. Parent's independent
14/14 combined Quantity/Energy/Mechanics cases pass at
`var/c-physical-integration/quantity-model-final-composed.json`. It confirms
malformed gravity cannot win a default pressure answer. The earlier ten
mass-unit parent checks remain historical evidence, not a second final count.

Final cold starts: 4.368, 4.098, 3.942, 4.090 and 4.213 ms; median 4.098 ms.
The first launch of earlier candidates was slower and remains disclosed above.
Largest measured pinned/family request p50 is 2.193 ms, below the 5 ms target.

Final receipts under `var/c-physical-mechanics-space/next/units/`:

- `shipped-fluid-final.json`, `probes-fluid-final.json`
- `fluid-conditions-before.json`, `fluid-consumer.json`, `consumer.json`
- `fluid-sealed/summary.json`

Final exact files: `src/extract/mechanics/Mechanics.thy`,
`Mechanics_Export.thy`, `recognizer.sml`, `main.sml`, `build.sh`, `README.md`,
`beyond_probes.json`, **`capabilities.json`**, plus this report. The added
capability declaration is only fluids-r2's `unsupported_model` decline;
there is no new answer kind. Do not substitute the earlier a6ecc4 candidate.

## Final shared-parser binding

The final current binary is
`5810f08249fe2f08249d896537ae9e11155f4457dac90bfa5798111787a1e2c2`,
754,680 bytes. Actual immutable compiler inputs are captured in
`var/mechanics/native-attempts/20261018T085742Z-6bd33c350e19/compile-inputs.json`.
This consumes shared MeasuredInput
`11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`
(62 focused shared checks), adding dot and multiplication-sign compound-unit
continuations while preserving sentence periods. Family source and the passed
73-root proof/export are unchanged; no new HOL submission was made.

The binary hash changed from 865161ab…, so focused checks ran on the final
binary: **18/18 mass-unit controls** across pinned/family modes, covering normal
gram mass, a sentence-ending unit, signed pound momentum, and rejected g.min,
g × s, g⋅s, g∙s, g/s and pound-force compounds. Fluid composition again passes
**10/10 pinned plus 10/10 physical-fleet**, retaining richer Quantity answers
and truthful unsupported-condition refusals.

Receipts: `next/units/operator-controls.json` and `next/units/fluid-consumer.json`
under the lane scratch folder. The dispatcher gained a code stage during this
refresh; the scoped physical harness explicitly disables it alongside dialogue,
reader, document and routes. Its initial invocation failed configuration before
requests, then all 20 calls passed with that scoped option.

The 1,264 shipped panels, 89 policy probes and final fresh-fluid seed reported
above belong to the preceding family-source-identical binding. They were not
repeated for this narrow shared operator repair. The final focused checks and
manifest are the additional evidence for this exact binary. Exact ready files
remain those listed above; only this report changed during the refresh.
