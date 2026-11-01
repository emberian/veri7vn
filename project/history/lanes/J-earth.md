# J-earth: daily light duration and quantity roles

Status: drained with failed isolated proof; no J native or panel result. The I consumer and immutable package remain unchanged.

The actual I reader answers DLI 54 for 500 umol/m2/s over 30 hours, reads .5 hours
as five hours, and answers negative daily light for negative PPFD. Fractional
and scientific notation also lose quantity meaning. The baseline passes 20/50
authored policy checks across greenhouse and greenhouse-r2; exact replies are in
`var/earth/j-daily-light/i-baseline-policies.json`.

The prepared daily model requires nonnegative PPFD and duration in [0,24] hours.
Inverting a nonnegative DLI target requires a strictly positive duration no
greater than 24 hours. Zero forward light or duration remains valid. New proposed
laws bind actual successful outputs to that physical domain, bound DLI by a
24-hour exposure at the supplied PPFD, and prove that actual PPFD output fed into
the daily-light kernel returns the target.

The reader requires one explicit supported light-rate/target dimension and one
hour duration, using the shared exact numeric lexer. Every supplied numeric
measurement must have one of these roles. Ambiguous quantities and unsupported
units cannot silently become the first matching rate. Other greenhouse models
are unchanged. Minutes and alternate photon-flux units remain valid unsupported
requests in this packet; mixed dimensions and malformed quantities remain
separate from valid capability gaps.

Drain boundary: no further successor work. The already-submitted ordinary proof
is persvati `20261018T102634Z-f965b2da9238` (expected 142 roots, zero oracles),
in `var/earth/j-daily-light/stage`. Collect that terminal receipt; preserve live I.
No J native was built. Resume from `staging.json` and the owned scratch files,
not from any failed export. The current reader has explicit hour and umol/m2/s
source units, with all numeric roles consumed. `run-probes.py` records the 50
checks and baseline. After proof success, use the common native helper with
that exact receipt, then run this policy panel and official greenhouse panels.

Resume consumer commands after a passed receipt, from the repo root:

```sh
mkdir -p var/earth/j-daily-light/stage/tools/dev
cp tools/dev/native-compile tools/dev/native_compile.py var/earth/j-daily-light/stage/tools/dev/
python3 var/earth/j-daily-light/compile-diagnostic.py
python3 var/earth/j-daily-light/run-probes.py var/earth/j-daily-light/j-probes.json var/earth/j-daily-light/stage/var/earth/bin/earth
python3 src/extract/earth/beyond.py --binary var/earth/j-daily-light/stage/var/earth/bin/earth --seeds 68701,73701 --out var/earth/j-daily-light/panels
```

The native recipe refuses failed/unpublished proof receipts. No J live promotion
or package change has occurred.

Terminal outcome: f965b2da9238 failed because `positivity` is not an available
method in this Earth session (Earth_Green.thy lines 228 and 241). No export was
published. Resume by replacing those two nonnegativity tactics with explicit
`mult_nonneg_nonneg` and `divide_nonneg_nonneg` steps, keeping the theorem
statements intact. Restage and run a new managed proof before the guarded native
commands above. No retry will run during this drain. The exact failure log is
`var/earth/j-daily-light/stage/var/earth/remote-attempts/20261018T102634Z-f965b2da9238/results/session.log`.
