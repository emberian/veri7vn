# Mechanics and space: dimensional and domain completion

Owner: Codex physical/mechanics_space. This is a separate packet from
C-physical-mechanics-space.md. Runtime captured the first Mechanics packet
and released its paths; Space was still frozen at that point. The initial source review and
executable counterexamples below use those first-packet final binaries.
Mechanics next packet is complete through local runtime composition; its
final results are below. Space has reopened as a separate packet and its proof
is queued. The original completion report remains unchanged. The completed shipped panels
remain mechanics 1,264/1,264 and space 1,185/1,185 pinned, zero wrong or false
yes. These panels do not establish completeness outside their templates.

## Examination by specialist

Each row was examined against its recognizer, actual kernel formulas and
refusal conditions, and a concrete executable input. The next-packet audit
is author-written diagnostic evidence, not a new completion panel.

| Specialist | Examined behavior and present limit | Next useful capability |
|---|---|---|
| physics | Signed velocity gives correct negative momentum; negative classical mass produces negative kinetic energy. | Preserve directed quantities while rejecting physically invalid mass. |
| physics-r2 | Same underlying formulas; narrowing does not repair negative mass. | Share the same typed physical-domain validation. |
| physics-r3 | Boundary wrapper preserves correct signed momentum but inherits negative-mass answer. | Same domain repair, with boundary regression. |
| mechanisms | Mixed lever lengths lose unit labels: 2 m / 50 cm produces 0.04 rather than 4. A -40 N force produces positive torque. | Normalize geometry in the verified model; retain signs for directed force/torque. |
| mechanisms-v2 | Same mixed-unit and signed-torque errors; wrapper does not repair them. | Shared dimensional parser and domain checking, with its missing-load behavior preserved. |
| bodies-v2 | -400 kg is read as +400 kg; 400 g is withheld. Kernel weight checks gravity, not mass. | Typed mass conversion and explicit nonnegative mass premise. |
| sports | Negative hits lose their sign; fractional hits and hits exceeding at-bats produce batting averages. | Validate count integrality and relevant count relationships, preserving signed passing yardage. |
| fleet | -30 mpg is read as +30 mpg; negative speed is treated as positive. Negative reaction-time wording currently withholds. | Define scalar speed/fuel/time domains; preserve sign before checking. Existing units already normalize through HOL. |
| fluids-r2 | -3 m depth produces positive pressure; 30 cm depth is withheld. | Typed depth and displaced-volume conversion; nonnegative below-surface depth. |
| orbits | -400 km above Earth is read as +400 km; 400000 m is withheld. Missing satellite altitude correctly withholds. | Explicit altitude units and above-surface domain; preserve subject distinction. |
| planetary | Negative SI mass can lose sign and produce positive gravity; negative-radius wording withholds. HOL already requires positive mass/radius. | Deliver exact signed values and units to existing positive-domain checks. |
| spacecraft | Tested negative Isp and negative initial mass withhold. Existing mass/speed/force conversions work; runtime p50 is still above the 5 ms target. | Review all sign placements, and use verified adaptive interval precision if it reduces cost. |
| spacecomms | -300000 km becomes positive light time; metres are unsupported. | Typed path-length normalization with nonnegative distance, adaptive precision for path loss. |
| astronomy | Mercury metal correctly withholds; requested cm/s2 still returns the table's m/s2 value. | Explicit output-unit conversion or an honest refusal; never silently claim a different unit. |
| astronomy-v2 | Same fixed table unit behavior; subject/reference ratio selection now correct. | Shared typed output-unit handling. |
| astronomy-v3 | Same fixed table unit behavior; Earth-year and material boundaries now correct. | Shared typed output-unit handling. |
| astronomy-v3-r2 | Same fixed table unit behavior with narrowing. | Shared typed output-unit handling, retaining boundary guards. |

## Concrete counterexamples

Receipts: `var/c-physical-mechanics-space/next/mechanics-semantic-before.json`
(26 pinned calls) and `space-semantic-before.json` (16 pinned calls). Their
scripts in the same directory record questions, expected interpretation and
full replies. They also include passing controls; totals are not presented
as shipped-panel scores.

- Lever effort arm 2 m and load arm 50 cm gives 0.04; the dimensionless ratio
  should be 4. The same defect appears for mm and mixed feet/inches.
- A -40 N applied force on a 25 cm wrench gives +10 N m. With directed force,
  the current torque formula itself gives -10 N m; the sign is lost before it.
- A -7 kg object's kinetic energy at 11 m/s is -423.5 J. Here the sign reaches
  HOL, but the classical physical-domain premise is absent. This differs
  from the parser defect and requires a kernel-domain decision.
- A 7 kg object's momentum at -11 m/s correctly gives -77 kg m/s. This is a
  control against a global ban on negative numerals.
- Negative crate mass, below-surface depth and mpg are converted to positive
  values before the kernel. Explicit grams and centimetres are also missed.
- Baseball hit counts -5, 2.5 and 25 with 20 at-bats all produce answers.
- Space orbit altitude, SI planet mass and light-path distance can lose a
  leading minus. Planetary positive-domain checks cannot help when the input
  value has already changed.
- “Surface gravity of Mars in cm/s2” returns 3.7 with a response labelled
  m/s2. The checked NASA snapshot has 3.7 m/s2, so its conversion would be
  370 cm/s2. This is a requested-unit gap, not evidence that the table cell
  is numerically wrong.

## Model conventions and repair design

The scalar geometry fields represent lengths, radii, depths, arm lengths,
volumes and path lengths. They must be nonnegative, with a strictly positive
denominator where the formula divides. Classical mass, elapsed time and
consumption are nonnegative; economy denominators are positive. Counts
represent nonnegative integers, with sport-specific relationships where the
statistic requires them. Signed passing yards are not a count. Displacements,
velocities, accelerations, force components and torque components retain
sign in the one-dimensional model. A speed request is a magnitude; it must
not acquire a sign convention silently from a regex.

Unit interpretation should map exact decimal text to a dimensioned rational
and retain the declared unit until a verified conversion constructs the
request. Root's shared ExactNumeric work in commons/numeric.sml is the
single numerical parsing foundation; this lane will coordinate adoption
through quantity_sound, not invent a competing local decimal parser.

The first implementation slice will cover mechanism geometry coherently:
lever arms, pulley diameters and incline lengths use a shared length-unit
reader and verified scale factors. Metres, centimetres, millimetres, feet
and inches have exact rational scales. Absent units may share a dimensionless
common scale only when neither field declares a unit; one explicit unit must
not silently supply an unrelated physical dimension. Decline ambiguous mixed
unitless/unitful requests unless the grammar explicitly shares the unit.

Existing `lever_ma_def` proves: if `kernel (McLeverMA e l) = Exact c y`, then
`c = K_lever_ma`, `l != 0`, and `y*l=e`. `lever_effort_def` proves from the
corresponding exact kernel result that `e != 0` and
`y*e=load_n(ld)*l`. These are useful identities but currently apply to naked
rational inputs, not the lengths written in the question. The next binding
must prove the same result with `e*scale(eu)` and `l*scale(lu)`, and that
request acceptance enforces the declared physical domains. New theorem names
without this output binding would not fix the defect.

The domain repair must preserve existing useful algebraic theorems while
strengthening acceptance. It should use one typed predicate consumed by the
kernel and corresponding reason selection; duplicating only an untrusted
regex rejection would leave direct typed callers unsound under the stated
physical interpretation. Numeric lexical rules must consume or reject a
complete signed numeral, not recover a positive suffix after a failed match.

No new answer kind is needed for this slice. Downstream runtime consumers
still receive lever_ma, lever_effort, belt_speed, incline_ma and torque. Any
new refusal reason must be checked against their existing status contract.

## Evaluation and resource plan

Keep the existing packet's source, binary and proof receipts frozen through
runtime capture. Work in scratch until root releases the paths. Develop with
these counterexamples and unit-rescaling metamorphic checks, then run each
affected shipped scorer and an untouched fresh seed after the final parser
freeze. Reserve additional counterexamples rather than calling these known
failures heldout. Test family routing and runtime composition after typed
interface changes. Record theorem statements, assumptions, actual output
bindings and remaining misses. No proof submission until the shared hold is
lifted and the build owner coordinates it.

For Space performance, a later independent slice can attempt 53-bit
interval enclosure first and retry at the existing 80-bit precision only
when needed. Each branch must use the existing enclosure soundness theorem.
Global reduction to 53 bits is unsuitable: the earlier 32 GHz path-loss case
already needed the higher precision. Measure the fallback rate and p50 before
claiming improvement; preserve the final decimal-error guarantee.

## Runtime refusal context

Dispatch independently found four taken fluids-r2 missing-depth/volume
refusals dropped by inherited context matching. Source inspection found the
precise cause: its JSON `context_regex` begins and ends with literal U+0008
backspace characters, not regex word boundaries. It does not actually require
numeric givens. The source upstream remains read-only.

A mechanics-owned capabilities declaration was drafted under
`var/c-physical-mechanics-space/next/capabilities.json`, initially pending runtime
capture. It adds correctly escaped operation-and-supported-material context
and preserves the existing underspecified decline kind. It adds no accepted
answer kinds. All four reported refusals plus four fresh material/operation
variants match; four unrelated controls do not. Receipt:
`capability-context-check.json` in that directory. The context only retains a
refusal already taken by the kernel recognizer; it is not permission to
answer a question or bypass proper-name/material guards. Runtime dispatch
has been notified of the broader malformed-JSON-boundary possibility.

Runtime dispatch subsequently took ownership of the actual U+0008 repair across
the five affected legacy manifests. After capture I briefly installed and
validated the draft, then removed my own new file when runtime confirmed the
shared correction covers these four cases. The shared fix is simpler; no
redundant mechanics sidecar is needed. The draft and checks remain scratch
evidence only. No producer proof or binary changes are needed for this fix.

## Mechanics implementation and evaluation history

The following paragraphs are historical development snapshots. Their pending
builds, unscored source and unopened seeds describe that stage only; the
current passed proof, native build and evaluations are in “Mechanics final
packet” below.

Runtime captured the first Mechanics packet and released its paths. Space
remains unchanged. Mechanics now has a central `physical_domain` predicate
consumed by `impossible` and `reason_of`. The original refusal reason takes
precedence, preserving useful zero-denominator diagnostics. The intended new
assurance statement is `answered (reply_of r) ==> physical_domain r`.
Classical mass and elapsed time are nonnegative, directed momentum and torque
remain signed, counts are nonnegative integers, and baseball hit totals obey
at-bat limits. Lever and belt lengths use positive geometry; torque radius
may be zero. The old algebraic laws remain connected to the same kernel.

`length_m` uses exact rational metric, foot and inch scales. The recognizer
uses it for lever arms, incline geometry, belt diameters and fluid depth;
torque already carries a typed length unit, now extended to feet/inches.
The proposed unit-binding lemmas assert that an accepted lever result times
the normalized denominator equals the normalized numerator, and that an
accepted effort times its normalized effort arm equals load times the
normalized load arm. Both also expose positive arm magnitudes.

Every arithmetic role now resolves through shared `ExactNumeric.mask` tokens.
It cannot re-read a numeric suffix from unit notation. Structured baseball
innings, win/loss records, and the literal L/100 km unit are protected before
masking and restored for their separate grammar. The scoped token table is
restored before `recognize` returns; no returned typed request depends on
mutable table state. The shared owner fixed case-folded marker collisions.
The adapter uses that final shared module, not a local numerical parser.

Nine lexical controls compile and pass against the actual shared modules,
covering malformed spaced signs, malformed comma groups, spaced fractions,
unit m3, L/100 km, innings, score records and uppercase marker-shaped input.
The full recognizer passes MLton type checking against a compile-only bridge
for the prior signature. That bridge is explicitly not a numeric
implementation, is never executed, and supports no correctness claims.

The probe set now has 44 sourced cases, including the original 20. The first
packet binary scores 26/44 in both pinned and family mode on these development
probes. At that snapshot the new source had not been numerically scored. Reserved
generator seed 20261115 was generated before the parser freeze and remained
unopened until the final evaluation described below.

The first hbox proof attempt, `20261018T071801Z-d52dea6b06f1`, failed on the
new generic length-scale positivity lemma; it published no export. The
batched repair uses explicit order reasoning and preserves legacy refusal
reason priority. The second attempt, `20261018T072542Z-de428e1ac0e7`, failed on the
lever-effort domain conjunction and the legacy submerged-sinks proof after
reason selection changed. It published no export. The third attempt,
`20261018T073841Z-22e7331c1a05`, batched those repairs with the three valid-edge
repairs below and subsequently passed, as recorded in the final packet.

The next `capabilities.json` has a different, necessary purpose from the
removed context draft: it allows the existing `impossible` refusal kind for
physics/r2/r3, bodies-v2 and fluids-r2, whose legacy contracts omitted it.
It adds no answer kinds or context patterns. Mechanisms, sports and fleet
already accept that refusal kind. Runtime must test these contextual refusals
alongside legitimate signed momentum and torque before integration.

Final native compilation subsequently used the build deputy's immutable
MLton input capture, including the exact consumed numeric.sml. Hashing current
files after compilation is insufficient. The proof queue continued
independently; the local input-capture change required no extra HOL build.

Rotational rates and transmitted torques retain the existing scalar formula's
coordinate convention; this model does not infer clockwise/counterclockwise
orientation through a gear mesh. Potential-energy height is relative to a
chosen reference and may be negative. The domain guard is not a general
vector mechanics model. Grams in the bodies reader, output-unit conversion
for astronomy tables, and the Space sign/distance gaps above remain separate
concrete work; this Mechanics slice does not claim to resolve them.

Review of the inherited base guards also found valid requests they reject.
These repairs were included in the third proof attempt and later passed:

- OBP with zero hits, zero at-bats and one walk has numerator and denominator
  both one. The old parser shortcuts zero AB to batting average, and
  the old kernel guard/theorem also incorrectly require positive AB. The repair
  uses positive `AB+BB+HBP+SF`, with a result-times-denominator law.
- A zero-distance fuel-cost calculation has zero fuel times price, with no
  division by distance. Its inherited positive-distance guard is unnecessary.
- Weight with explicitly zero gravity is zero. Only weight can relax the
  gravity guard to nonnegative; fall-time and pendulum models still require
  positive gravity. The parser must retain the explicit zero instead of
  treating it as absent.

The development probes now total 47, adding these three valid edge cases.
The 26/44 baseline above precedes those additions. An actual compiled mask check found that the previous shared lexer rejected
the ordinary price spelling `$3.19/gallon`. The shared owner repaired that
unit-slash boundary; root released final hash
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`
after 88 owner and eight root checks. Final native compilation consumed
that exact shared input through `tools/dev/native-compile`. No local lexer
fork is being introduced.

The final pre-evaluation parser audit also tightened structured score
protection: `-50-30` and `50-30.5` cannot be shortened to the integer record
`50-30`. This changes no HOL source. The development set now contains 50
probes: the three valid edges, the shared price-slash regression, and these
two malformed structured records augment the original 44. A 12-case compiled
lexical check passes against the final shared module, including all three
new lexical boundaries. Seed 20261115 remained unopened at that stage.

## Mechanics final packet

The third scoped proof passed on hbox, attempt
`20261018T073841Z-22e7331c1a05`: `VERI7VN_MECHANICS PASS theorems=70 oracles=0`.
The session took 76.970 seconds after waiting for the host. The generated SML
SHA256 is `9224f425c623e2d56b1e6ba5c7152fc6c5f35e54acc34a33a2a8eddb6c2e5fb8`.
No proof holes or new axioms were introduced.

The actual new statements are:

- `answered (reply_of r)` implies `physical_domain r`. This checks the typed
  mass, geometry, time, economy and event-count conventions stated above;
  it does not establish that the English question was interpreted correctly.
- If `kernel (McLeverMA (length_m e eu) (length_m l lu)) = Exact c y`, then
  `c = K_lever_ma`, `0 < e`, `0 < l`, and
  `y * (l * len_scale lu) = e * len_scale eu`.
- If the corresponding lever-effort request returns `Exact c y`, then
  `c = K_lever_effort`, both original arm magnitudes are positive,
  `0 <= fst ld`, and
  `y * (e * len_scale eu) = load_n ld * (l * len_scale lu)`.
- Accepted on-base percentage uses positive `ab + bb + hbp + sf` and binds
  `y * (ab + bb + hbp + sf) = h + bb + hbp`. It does not require positive AB.
- Accepted body weight binds `y = m * g_of g` with nonnegative mass and gravity.
  Accepted trip cost permits zero distance and retains its fuel-times-price law.

The first actual native score exposed two WHIP misses: uppercase `IP` was not
protected before number masking. The span protector now matches lowercase
text while preserving the original span. This also handles uppercase `L/100
km`. It changed no HOL source. The untouched seed remained closed during this
repair and was opened only after the final parser freeze.

Final binary: `var/mechanics/bin/mechanics`, SHA256
`09823e492ba380e2d03d5a20cd17ed02be5b29e48c128eb8f3c8801be6729a4b`,
741,384 bytes (first packet: 639,480). Immutable native attempt
`20261018T075816Z-4eda2cb20c36` captured the exact consumed compiler inputs in
`var/mechanics/build/compile-inputs.json`; it binds shared numeric hash
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

Both pinned and family shipped scores are **1,264/1,264**, with zero wrong,
false yes or valid withheld. Every row below is right/total; each has zero in
those other categories in both modes.

| Specialist | Development | Held out | Pinned p50 ms | Family p50 ms |
|---|---:|---:|---:|---:|
| physics | 123/123 | 123/123 | 0.161 | 0.736 |
| physics-r2 | 123/123 | 123/123 | 0.196 | 0.712 |
| physics-r3 | 123/123 | 123/123 | 0.203 | 0.801 |
| mechanisms | 54/54 | 64/64 | 0.119 | 0.735 |
| mechanisms-v2 | 63/63 | 55/55 | 0.141 | 0.709 |
| bodies-v2 | 38/38 | 38/38 | 2.200 | 2.327 |
| sports | 19/19 | 19/19 | 0.212 | 0.589 |
| fleet | 54/54 | 54/54 | 0.145 | 0.475 |
| fluids-r2 | 34/34 | 34/34 | 0.174 | 0.172 |

Final authored probes: **54/54 in both modes**, covering supported mixed
lengths, genuinely unitless ratios, unsupported explicit units, directed
signs, invalid magnitudes and counts, complete numeric tokens, structured
sports records, price slashes, and the three valid zero cases. The original
first-packet binary scored 26/44 before the final ten probes were added;
that narrower baseline is not presented as a 54-case measurement.

Untouched seed **20261115**: **1,159/1,159**, zero wrong, false yes or valid
withheld across all eight available generators; the shipped organs score
1,153 right and six withheld on those same panels. Fleet has no generator.
The seed was generated before tuning and neither read nor scored until the
final parser freeze. Own runtime checks pass **12/12 pinned and 12/12 across
the physical fleet**, including retention of the `impossible` refusal kind.

Final five cold starts were 4.803, 4.622, 4.592, 5.136 and 4.647 ms; median
4.647 ms versus the first packet's 4.14 ms. The first launch of the earlier
candidate was 97.9 ms and is not hidden in the repeated-launch number.
Every measured pinned and family p50 is under the 5 ms beyond-parity target.

Receipts:

- `var/c-physical-mechanics-space/next/shipped-final.json`
- `var/c-physical-mechanics-space/next/probes-final.json`
- `var/c-physical-mechanics-space/next/sealed-mechanics/summary.json`
- `var/c-physical-mechanics-space/next/consumer.json`
- `var/mechanics/remote-attempts/20261018T073841Z-22e7331c1a05/receipt.json`
- `var/mechanics/native-attempts/20261018T075816Z-4eda2cb20c36/compile-inputs.json`

Mechanics files for integration: `Mechanics.thy`, `Mechanics_Export.thy`,
`recognizer.sml`, `main.sml`, `build.sh`, `README.md`, `beyond_probes.json`,
`capabilities.json`, all under `src/extract/mechanics/`, plus this report.
No Space source belongs in this completed Mechanics packet.

Remaining Mechanics limits include grams in the bodies reader, unsupported
geometry units such as yards/miles (now safely withheld), broader quantity
role assignment, and the existing scalar projectile model's angle conventions.
The physical-domain theorem is a guarantee of its stated typed predicate,
not a universal validation of every physical scenario.

## Space follow-up in progress

The earlier Space packet was captured, and the parent released its source.
A separate scope now consumes shared exact numeric tokens, preserves signs,
and uses typed distance conversion for metres as well as kilometres/miles/AU.
Scientific `mantissa x 10^exponent` syntax is a validated complete expression:
the mantissa comes from the shared lexer, the whole integer exponent uses
shared parse with the same bounded exponent limit, and malformed expressions
cannot retry a numeric suffix as a planetary mass. No competing numeral lexer
or shared-module edit is introduced.

The new domain separates nonnegative light-path distance and throughput from
positive frequency/distance required by logarithmic path loss. Zero path and
zero payload are valid. Bits in flight remains a rational average occupancy;
file payload must contain a whole nonnegative number of bits after prefix and
byte scaling. Rocket thrust, exhaust speed, propellant and delta-v here are
magnitudes. Orbital radius must stay positive; altitude is not given a blanket
nonnegative restriction in the central point-mass model.

The previously unconditional light-time and bits-in-flight acceptance laws
have explicit domain premises. New proposed accepted-output consequences bind
nonnegative time to `time*c = path` (or twice the path for round trips),
nonnegative transfer time to `time*rate = payload_bits`, and nonnegative
in-flight occupancy to `bits*c = rate*path`. None is claimed proved yet.

Space proof attempt `20261018T075720Z-869604bca375` is queued on persvati.
The recognizer type-checks using a compile-only signature bridge that is not
executed and provides no numerical evidence. Development probes currently
number 56; the first packet scores 42/56 in both modes. Reserved seed
20261117 is generated and unopened (orbits and spacecomms have no generators).
Table output-unit conversion and adaptive interval precision remain separate
work; this packet does not claim them.
