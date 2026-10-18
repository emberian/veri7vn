# The space family, end to end

Eight shipped Oracle7 specialists as one program: `orbits`, `planetary`, `spacecraft`, `spacecomms`, `astronomy`, `astronomy-v2`, `astronomy-v3`, `astronomy-v3-r2`. Same recipe as `src/extract/quantity/`: a HOL kernel over typed requests (`Space.thy`), tables transcribed from the organs (`Space_Tables.thy`, checked by `tables_check.py`), an untrusted SML recognizer (`../commons/commons.sml`, `../commons/numeric.sml`, `recognizer.sml`) and driver (`main.sml`), compiled by the MLton inside Isabelle into `var/space/bin/space`. `--specialist ID` asks one manifest's organ; with no argument the family first recognizes explicit planetary and spacecraft calculations, then distinguishes satellite and communications requests from NASA table properties. A satellite question lacking altitude stays a refusal.

Proved: each kind's value satisfies its defining equation (Kepler's third law, vis-viva, Tsiolkovsky, escape speed squared times radius = 2GM, mean density, free-space path loss as a power of ten, light time, transfer time, bits in flight, weight scales with surface gravity, ratio times reference = subject). Declines cover missing inputs, unavailable synchronous orbits, explicit numeric domain failures, unknown bodies and unknown table values. Each kind's decline condition is also written out over the question's own numbers (`declines_exact_kinds`, `declines_enclosed_kinds`: a radius plus altitude that is not positive, a final mass above the initial, the Sun and Venus for synchronous orbits, the five cells NASA marks Unknown). The Hohmann delta-v is the two burns from vis-viva, and the stated decimal is within the enclosure and rounding bound of them (`hohmann_dv_vis_viva`, `hohmann_dv_stated`); the exhaust velocity the kernel states is the one its mass flow divides by (`exhaust_mass_flow_agree`). Decimals from square roots, pi, exp, ln and a cube root come from Isabelle's interval arithmetic, with a proved error bound (`kernel_approx_sound`). Untrusted: the recognizer, JSON framing, number layout (`render_*`, checked by self test and panels), and the transcription of tables (checked by `tables_check.py`, not a proof).

Build and score: see `project/lanes/S02-space.md`.


## Beyond the original recognizers

All astronomy version IDs now use the grammatical subject and reference body,
so “relative to Jupiter, how massive is Venus” means Venus divided by Jupiter.
“Earth years” is a unit; “Earth’s year” still identifies Earth. Spacecraft
questions accept an initial amount before “total mass”, explicit conversions
from specific impulse, and burn times for an engine with a stated force.
The family distinguishes a table property from a calculation at a specified
orbital altitude. It also keeps force in newtons separate from NASA’s
Earth-equivalent weight in kilograms, and liquid mercury from the planet.

The recognizer remains untrusted. It passes the exact checked reply used by
its narrowing decision to the driver, so interval arithmetic runs once for
that request. Build-time self tests remain enabled; they no longer become an
eager runtime constant. That first continuation added no formulas or accepted answer kinds.
That continuation retained the existing 80-bit interval precision.

Measured panels, authored probes and limitations are recorded in
[the continuation report](../../../project/lanes/C-physical-mechanics-space.md).

## Signs, dimensions and physical domains

The separate domain follow-up reads complete numeric tokens from shared
`ExactNumeric`, including signs, exact fractions and scientific notation.
The existing multiplication spelling `1.5 x 10^24` is handled as a complete
validated expression. The parser never recovers a shorter numeral from a
malformed exponent or a digit inside unit notation.

Orbit altitude and signal path lengths use the same exact typed distance
conversion. Metres, kilometres, miles and astronomical units are converted
inside the checked model where applicable. A speed in m/s cannot fill a
missing length. Orbital formulas require positive radius in the central
point-mass model; this is distinct from imposing a sign rule on altitude.

Light paths and average bits in flight use nonnegative magnitudes. Zero path
length and zero transmitted data are valid. File size must represent a whole
number of bits after prefix and byte conversion, while average bits in flight
may be fractional. Rocket thrust, exhaust speed, propellant and delta-v are
magnitudes in these models. The accepted communications laws bind nonnegative
results to time times rate, time times light speed, and in-flight content.
English role assignment remains untrusted.

The [domain report](../../../project/lanes/C-physical-mechanics-space-next.md)
records proof status, actual measurements and remaining limits. Build scripts
use immutable compiler-input capture. Requested astronomy output-unit
conversion remains outstanding. Interval evaluation now tries 32-bit precision
and retries at 80 bits if the same checked-decimal predicate rejects the first
enclosure. Either accepted branch satisfies the original error bound, and every
successful 80-bit enclosure remains answerable. Near-equal Hohmann transfers
exercise the fallback in the build-time self test.

The [adaptive report](../../../project/lanes/F-physical-space-adaptive.md) records
the actual native timings and comparisons. The decimal need not be identical
to the 80-bit answer: both satisfy the proved numerical bound. An existing
valid refusal for free-space path loss at 1 GHz over 1 km motivated the
logarithm reduction below; increasing precision alone is not a completeness
guarantee.

## Logarithms with smaller arguments

Path-loss and ideal rocket calculations now reduce a positive rational input
to a mantissa between one half and two and an integer power of two. The checked
identity `ln(q) = ln(mantissa) + exponent * ln(2)` lets the existing interval
arithmetic evaluate the smaller argument. The physical equations and accepted
error bound are unchanged; the exponent comes from terminating bit-length
arithmetic rather than a bounded search.

All 20 focused model cases now answer correctly in isolated and family modes,
recovering three numerical withholds. Twelve independent numeric cases also
pass through full dispatch. The reserved generator seed passes 1,047 cases;
Orbits and Spacecomms have no generator in the supplied tree. Shipped isolated
panels remain 1,185/1,185; family mode retains its two disclosed Planetary
off-domain scores for useful Astronomy answers. The broader authored set has
63 right and 15 valid withholds in each mode.

These checks establish the stated mathematical models. In particular, positive
distance/frequency alone does not establish real antenna far-field applicability;
the tiny-distance probes do not claim it. Source, theorem and native bindings
are in `project/lanes/G-physical-space-log.md`.
