# I-climate: microscopic graphene mass, drained unfinished

Status: final isolated proof attempt failed. No I export was published, no I
native was compiled, and no I official panel result exists. Integrated Climate
H (`9b1f1be`) remains the current usable source and binary. Earth I (`a2add49`)
is also unchanged. This packet stops here under the drain instruction.

The current consumer answers “0 mg (0 m2 …)” for a single-layer sheet of area
1 um2; the stated atomic-cell model gives about 7.611275e-13 mg. Exact baseline
replies and an independent 70-digit Decimal model are in
`var/climate/i-small-mass/`. H passes 8/22 new policies; these are new precision
policies, not a rescore of H's shipped panels.

Prepared changes are isolated in `var/climate/i-small-mass/stage`:
`Climate_Num.thy`, `Climate.thy`, and `Climate_Export.thy`. The proposed small-mass
path applies to positive area below 0.01 m2. It requires a positive verified
interval with width bounded relative to its lower endpoint, then rounds to four
significant digits. The intended actual-output theorem gives positive stated
mass and relative error at most 1/1000, while retaining the absolute bound used
by the mass-additivity law. Ordinary-size values retain their former policy.
The explanatory area prints an exact rational in m2 rather than rounded zero.
The continuum model is not a claim that a fractional atom is a physical sheet.

Attempts and exact outcomes:

- `20261018T102152Z-b2602a7e9ac9` failed the relative arithmetic tactic,
  option-case unit-equivalence proof and consumer not_taken proof. The same
  statements were repaired, without weakening their bounds.
- `20261018T103049Z-b7fc7c5cd6e8` accidentally captured the main H checkout.
  The build owner cancelled that exact job while queued, before any proof ran.
  It published no export.
- Final permitted retry `20261018T103226Z-95decb8e8219` failed at
  Climate_Num.thy line 102. The only reported remaining error is the tactic
  deriving `abs(mid-x) <= lo/2000000` from `abs(mid-x) <= (hi-lo)/2` and
  `hi-lo <= lo/1000000`. This is not a successful proof or consumer result.

The exact final failure log is
`var/climate/i-small-mass/stage/var/climate/remote-attempts/20261018T103226Z-95decb8e8219/results/session.log`.
`drain-state.json` binds all attempt IDs and the prepared source hashes;
`staging.json` records the passed H source base and owned overlay. No failed
export has been consumed.

Concrete resume: replace that single linear tactic with explicit
`divide_right_mono` using positive divisor 2, simplify the nested division, then
compose with the midpoint bound using `order_trans`. Restage and run a new
ordinary managed proof only after a future resume. Preserve the theorem statement.
The script `compile-diagnostic.py` refuses an unpassed or unpublished receipt;
update it to the future successful receipt before running it. Then run:

```sh
python3 var/climate/i-small-mass/run-probes.py var/climate/i-small-mass/i-probes.json var/climate/i-small-mass/stage/var/climate/bin/climate
python3 src/extract/climate/beyond.py --binary var/climate/i-small-mass/stage/var/climate/bin/climate --seeds 78701,83701 --out var/climate/i-small-mass/panels
```

The authored checker measures both numeric value and sentence mass with relative
error for tiny positive quantities. The retained staged-dispatcher helper
`run-consumer.py` also uses relative error for those probes. Neither has been
run on an I binary because no such binary exists. Do not promote this scratch
source or claim its intended bound until the managed proof and consumers pass.
