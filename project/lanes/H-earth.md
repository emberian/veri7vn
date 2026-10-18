# H-earth: runoff fraction, source units and conservation

Status: checked successor over Earth G, now included in live Earth I. The
138-law proof and native checks pass. Official panels were measured on the
I superset; no separate H-only official panel result is claimed.

The actual G reader turns C=1.5 into C=1, answering 0.5556 m3/s for 10 mm/h on
20 hectares. It loses a negative intensity's sign, reads a half coefficient as
one, and takes first matches from ambiguous multiple quantities. Baseline replies
are retained in `var/earth/h-runoff/g-baseline.json`; G passes 8/32 new policies.

The rational-method branch now uses the shared exact numeric lexer for a unique
runoff coefficient, rainfall intensity and drainage area. The rest of hydrology
is unchanged. Percent coefficients use a finite kernel-owned unit and conversion;
50% and 1/2 have the same coefficient. Negative values reach the kernel. Compound
rate/area dimensions, duplicate quantities and unsupported unit systems produce
underspecified rather than a plausible number from the first match.

The explicit model is a simple runoff fraction in [0,1], with nonnegative
rainfall intensity and drainage area. A zero coefficient, intensity or area is
valid. The SI formula normalizes acres/km2/hectares to hectares and divides
C*i*A by 360 for m3/s. Inch/hour with acres retains the conventional CiA cfs
approximation. Inch/hour with other area units remains unsupported. This packet
does not claim exact physical unit conversion for the conventional US shortcut,
or applicability to adjusted design coefficients that can exceed one.

Four new scan roots state actual successful-output physical constraints, flow
between zero and the declared zero-loss model capacity, actual percent/fraction
request equivalence, and actual km2/hectare request equivalence including guards.
The capacity bound uses the stated model and its units, not a claim of global
hydrological applicability.

The 32 authored cases include 14 model answers, 8 impossible inputs, 8 valid
unsupported/ambiguous requests, and 2 malformed inputs. Policy counts do not
turn valid withheld requests into capabilities; the valid answer slice is 14/22.
Source ancestry and hashes are recorded in `var/earth/h-runoff/staging.json`.

First managed attempt 3138b15b147a failed only the final rational-to-real order
lifting in the capacity proof. Adding explicit `of_rat_less_eq` retains the exact
statement. Sequential retry `20261018T100241Z-86c88f8ac79b` passed with
`VERI7VN_EARTH PASS theorems=138 oracles=0`. No failed export was consumed.


The standalone H native SHA256 is
`254581e1d10022eb0ad6ded42570ccd06692142285bb86ee15f209f8a3ff29e1`.
Its actual-input manifest is
`var/earth/h-runoff/stage/var/earth/native-attempts/20261018T100656Z-e86b4d2ebe40/compile-inputs.json`.
All 32 H policies pass, versus 8/32 on G. Generated SML SHA256 is
`827fef6eaff03224df96f26a95cf91f64340267a064a969e272083212b910843`.

The reader-only I successor preserves this kernel and runoff reader exactly.
Its official panels score 554/554 shipped, 360/360 at offset 58701, and 356/356
at offset 63701, with zero wrong, false yes or withheld. Hydrology contributes
102/102 shipped; no fresh hydrology generator exists. The separate hydrology
parity harness scores 102/102 but remains INCOMPLETE on the full six criteria.
Hydrology p50 is 0.121 ms; family cold median is 3.688 ms. See
`var/earth/i-pressure/panels/report.json`, `parity/`, and the successor report
`project/lanes/I-earth.md` for promoted consumer and integration evidence.
