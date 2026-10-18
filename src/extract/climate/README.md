# The climate family, end to end

Six shipped Oracle7 specialists (`carboncapture`, `airquality`, `climate`, `carbonmat`,
`coldchain`, `coldchain-v2`) as one verified HOL kernel, exported to SML and compiled with
the MLton inside Isabelle into `var/climate/bin/climate` (620 KB, not committed). It speaks the
[answerer contract](../../../docs/contracts/answerer.md). `--specialist ID` asks one manifest's
organ; without it the family is asked in the order airquality, carbonmat, coldchain-v2,
climate, carboncapture. Handoff with theorem statements and numbers:
[lane S05](../../../project/lanes/S05-climate.md).

| Part | File | Status |
|---|---|---|
| Tables (emission factors, AQI breakpoints, lattice constants, Food Code limits) | `Climate.thy` | HOL constants, checked against the organs by `tables_check.py` (a check, not a proof) |
| Requests, declines, kernel, rounding, reply text | `Climate_Num.thy`, `Climate.thy` | HOL, proved |
| Logarithm, roots, pi, arctan | `HOL-Decision_Procs.Approximation` | Isabelle library, as in lanes D and G |
| Export, self test, oracle check | `Climate_Export.thy` | the build fails if a listed theorem uses an oracle or the self test fails |
| English reading | `../commons/commons.sml`, `recognizer.sml` | **untrusted** hand port of the organs' regexes |
| JSON framing | `main.sml` | **untrusted** |

## Build and run

```sh
tools/dev/remote-build persvati src/extract/climate Veri7vn_Climate -d src/extract/commons \
  --expect 'VERI7VN_CLIMATE PASS'
python3 src/extract/climate/tables_check.py
sh src/extract/climate/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/climate/score.py
python3 tools/parity/harness.py --answerer var/climate/bin/climate \
  --specialist carboncapture,airquality,climate,carbonmat,coldchain,coldchain-v2 --split both --out var/climate/parity
```

## Result

The completed reader accepts measured/read AQI concentrations. Both cold-chain
wrappers recognize decimal durations and the same food vocabulary. See
`project/lanes/C-climate.md` for the measured comparison, build state and limits.

`python3 -B src/extract/climate/beyond.py --seeds 701,1701 --out var/climate/beyond`
runs the shipped panels, fresh numeric samples and 20 authored boundary probes.
Self-tests execute during the checked build, not at binary startup.
