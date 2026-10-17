# The anatomy and agriculture family

Five shipped Oracle7 specialists as one program: `anatomy`, `anatomy-r2` (stable human
anatomy counts, superlatives, which organ makes a substance), `agriculture-v2` (fertilizer grade,
seeding rate, bushels to kg/ha, acre-inches), `gardening` (bed volume, bags, plant grid,
fertilizer per area, water) and `nutrition-label-v2` (BMI and category, calories from
macronutrients, percent Daily Value, percent calories from fat).

The facts, formulas and decisions to decline are in Isabelle/HOL (`AnatomyAgri.thy`) with proofs.
All arithmetic is exact rational arithmetic; nothing needs a square root. Isabelle generates
Standard ML, and the MLton compiler inside Isabelle builds one binary that speaks the
[answerer contract](../../../docs/contracts/answerer.md). `--specialist ID` reads questions the way
that manifest's organ does; with none, the family is asked in a fixed order.

| Part | File | Status |
|---|---|---|
| Tables, requests, kernel, rounding, reply text | `AnatomyAgri.thy` | HOL, proved, exported |
| Export, self test, oracle check | `AnatomyAgri_Export.thy` | build fails on an oracle or a failed self test |
| Table transcription check | `tables_check.py` | Python check against the organ files, not a proof |
| Reading English | `regex.sml`, `recognizer.sml` | **untrusted**, hand port of the organs' regexes |
| JSON framing | `main.sml` | **untrusted** |

Build and run:
```sh
python3 tools/dev/check-native --session Veri7vn_AnatomyAgri --session-root src/extract/anatomyagri --expect 'VERI7VN_ANATOMYAGRI PASS' --timeout 600
python3 src/extract/anatomyagri/tables_check.py
sh src/extract/anatomyagri/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/anatomyagri/score.py     # has an RSS guard
```
The binary is under `var/anatomyagri/bin/` and is not committed. Results and statements:
[lane handoff](../../../project/lanes/S10-anatomy-agri.md).
