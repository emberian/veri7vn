# The space family, end to end

Eight shipped Oracle7 specialists as one program: `orbits`, `planetary`, `spacecraft`, `spacecomms`, `astronomy`, `astronomy-v2`, `astronomy-v3`, `astronomy-v3-r2`. Same recipe as `src/extract/quantity/`: a HOL kernel over typed requests (`Space.thy`), tables transcribed from the organs (`Space_Tables.thy`, checked by `tables_check.py`), an untrusted SML recognizer (`../commons/commons.sml`, `recognizer.sml`) and driver (`main.sml`), compiled by the MLton inside Isabelle into `var/space/bin/space`. `--specialist ID` asks one manifest's organ; with no argument the family first recognizes explicit planetary and spacecraft calculations, then distinguishes satellite and communications requests from NASA table properties. A satellite question lacking altitude stays a refusal.

Proved: each kind's value satisfies its defining equation (Kepler's third law, vis-viva, Tsiolkovsky, escape speed squared times radius = 2GM, mean density, free-space path loss as a power of ten, light time, transfer time, bits in flight, weight scales with surface gravity, ratio times reference = subject). Declines are exactly the organs' underspecified, no-synchronous-orbit, impossible, unknown-body and unknown-value predicates. Each kind's decline condition is also written out over the question's own numbers (`declines_exact_kinds`, `declines_enclosed_kinds`: a radius plus altitude that is not positive, a final mass above the initial, the Sun and Venus for synchronous orbits, the five cells NASA marks Unknown). The Hohmann delta-v is the two burns from vis-viva, and the stated decimal is within the enclosure and rounding bound of them (`hohmann_dv_vis_viva`, `hohmann_dv_stated`); the exhaust velocity the kernel states is the one its mass flow divides by (`exhaust_mass_flow_agree`). Decimals from square roots, pi, exp, ln and a cube root come from Isabelle's interval arithmetic, with a proved error bound (`kernel_approx_sound`). Untrusted: the recognizer, JSON framing, number layout (`render_*`, checked by self test and panels), and the transcription of tables (checked by `tables_check.py`, not a proof).

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
eager runtime constant. No new formulas or accepted answer kinds were added.
The existing 80-bit interval precision is unchanged.

Measured panels, authored probes and limitations are recorded in
[the continuation report](../../../project/lanes/C-physical-mechanics-space.md).
