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
| English reading | `regex.sml`, `recognizer.sml` | **untrusted** hand port of the organs' regexes |
| JSON framing | `main.sml` | **untrusted** |

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Climate --session-root src/extract/climate \
  --expect 'VERI7VN_CLIMATE PASS' --timeout 900
python3 src/extract/climate/tables_check.py
sh src/extract/climate/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/climate/score.py
python3 tools/parity/harness.py --answerer var/climate/bin/climate \
  --specialist carboncapture,airquality,climate,carbonmat,coldchain,coldchain-v2 --split both --out var/climate/parity
```

## Result

Every shipped panel item is right or withheld; 0 wrong and 0 false yes anywhere, and every
reply agrees with the shipped organ on all panel questions. See the handoff for the table.
