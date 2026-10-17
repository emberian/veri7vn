# Parity board

**Full board: Oracle7 + specialist, release composition, shipped head, in plain words.** 304 specialists were run on their held-out exams; 290 of them have a shipped verdict to compare with. Of the 129 that are not relation readers, **129 got exactly the shipped number of right answers and false yeses**. Together they score 6354 right / 17 false yes / 161 wrong, against 6354 / 17 shipped. The shipped files record a wrong count for 79 of these 129; on those, 5 wrong here against 5 shipped. The 161 relation readers (`rel-*`) could not run on this installation: they score 1796 right / 0 false yes, against 9124 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 15478 right / 14 wrong, splits into 6354 right / 5 wrong for the other specialists (wrong recorded for 79 of 129) and 9124 right / 9 wrong for the relation readers (wrong recorded for 161 of 161). **Reproduced here, without the relation readers: 6354 right / 161 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 50 of them). 14 specialists have no shipped verdict to compare with (anatomy-r2, astronomy-v3-r2, cooking-v3-r2, densities-r2, finance-v2-r2, fluids-r2, greenhouse-r2, labsolutions-r2, medicine-r2, music-v2-r2, optics-v5-r2, physics-r3, soil-r2, units-v3-r2). On 4 questions in rel-museums, rel-philosophers, rel-photographers the answerer process stopped without a message and was restarted; those questions count as declined.

**Control A: Oracle7 + specialist, release composition, shipped head, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **5 got exactly the shipped number of right answers and false yeses**. Together they score 495 right / 0 false yes / 2 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 495 right / 2 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

**Control B: Oracle7 + specialist, exam.py composition, shipped head, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **0 got exactly the shipped number of right answers and false yeses** and 5 did not (acoustics: 57 right / 1 false yes, shipped 69 / 0; cooking-v3: 212 right / 0 false yes, shipped 224 / 0; densities: 50 right / 0 false yes, shipped 51 / 0; units-v3: 48 right / 0 false yes, shipped 75 / 0; units: 43 right / 0 false yes, shipped 76 / 0). Together they score 410 right / 1 false yes / 79 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 410 right / 79 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

**Control C: Oracle7 + specialist, exam.py composition, current head w540, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **1 got exactly the shipped number of right answers and false yeses** and 4 did not (acoustics: 62 right / 2 false yes, shipped 69 / 0; cooking-v3: 212 right / 0 false yes, shipped 224 / 0; units-v3: 48 right / 0 false yes, shipped 75 / 0; units: 47 right / 0 false yes, shipped 76 / 0). Together they score 420 right / 2 false yes / 68 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 420 right / 68 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

Generated by `tools/parity/board.py` on 2026-10-17 23:58 UTC from the run directories named below. Counts are **right / false yes / wrong** in the sense of `upstream/workbench/exam.py`: *right* is the specialist's own scorer saying good (a correct decline of a must-decline item counts as right), *false yes* is an answer to a must-decline item, *wrong* is an answer to a valid item that the scorer rejects. See [README](README.md) for the columns and the control.

## Summary

| Run | Answerer | Head | Specialists | Items | Answerer right / false yes / wrong | Head alone | Shipped composed (same specialists) | Same right and false yes as shipped | Decisions |
|---|---|---|---|---|---|---|---|---|---|
| Full board: Oracle7 + specialist, release composition, shipped head | `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}` | w363, w399, w406, w502, w503, w524, w525, w526, w540 | 304 | 17436 | 9101 / 28 / 497 | 2991 / 93 / 1914 | 15478 / 17 / - on 16454 items | 129 of 290 | ADMIT 128, INCOMPLETE 1, NEGATIVE 175, NO PANEL 1 |
| Control A: Oracle7 + specialist, release composition, shipped head | `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}` | w363, w524, w525 | 6 | 595 | 515 / 0 / 8 | 45 / 1 / 83 | 591 / 0 / - on 595 items | 5 of 6 | ADMIT 5, NEGATIVE 1 |
| Control B: Oracle7 + specialist, exam.py composition, shipped head | `tools/parity/answerers/oracle7.py --tip {shipped_head} --specialist {dir}` | w363, w524, w525 | 6 | 595 | 430 / 1 / 85 | 45 / 1 / 83 | 591 / 0 / - on 595 items | 0 of 6 | ADMIT 1, NEGATIVE 5 |
| Control C: Oracle7 + specialist, exam.py composition, current head w540 | `tools/parity/answerers/oracle7.py --specialist {dir}` | w540 | 6 | 595 | 440 / 2 / 73 | 435 / 2 / 73 | 591 / 0 / - on 595 items | 1 of 6 | NEGATIVE 6 |
| veri7vn packaged, acoustics sample | `tools/parity/answerers/veri7vn_packaged.py deployment-ui-d44-standalone-aae0d7dd/generations/2fd159a8...` | - | 1 | 3 (first 3 items each) | 0 / 0 / 0 | - | - | - | INCOMPLETE 1 |

## Full board: Oracle7 + specialist, release composition, shipped head

Run directory `var/parity/full-front-shipped-head`; command `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}`.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 69 | 0 | 3 / 1 / 5 | 69 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 1 / - | 69 / 0 / - (69) | +0 |
| additive-v2 | 20 | 0 | 1 / 0 / 0 | 20 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 1 / 0 / 0 | 20 / 0 / 0 (20) | +0 |
| agriculture-v2 | 17 | 0 | 1 / 1 / 4 | 17 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | ADMIT | w503 | 1 / 1 / 4 | 17 / 0 / 0 (17) | +0 |
| airquality | 38 | 0 | 2 / 1 / 13 | 30 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 1 / 13 | 30 / 0 / 0 (38) | +0 |
| algorithms | 42 | 0 | 1 / 1 / 16 | 42 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 1 / 1 / - | 42 / 0 / - (42) | +0 |
| anatomy-r2 | 11 | 0 | 7 / 1 / 0 | 9 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| anatomy | 11 | 0 | 0 / 1 / 3 | 9 / 1 / 1 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 0 / 1 / 3 | 9 / 1 / 1 (11) | +0 |
| architecture | 10 | 0 | 1 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 0 | 10 / 0 / 0 (10) | +0 |
| arthistory | 11 | 0 | 6 / 0 / 3 | 11 / 0 / 0 | 1 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 6 / 0 / 3 | 11 / 0 / 0 (11) | +0 |
| astronomy-v2 | 138 | 0 | 9 / 0 / 23 | 130 / 0 / 8 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: WRONG: 8 answered wrong, cap 2 | w363 | 9 / 0 / - | 130 / 0 / - (138) | +0 |
| astronomy-v3-r2 | 138 | 0 | 114 / 0 / 23 | 137 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| astronomy-v3 | 138 | 0 | 9 / 0 / 6 | 137 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w363 | 9 / 0 / - | 137 / 0 / - (138) | +0 |
| astronomy | 81 | 0 | 5 / 3 / 44 | 68 / 0 / 13 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 13 answered wrong, cap 1 | w363 | 5 / 3 / - | 68 / 0 / - (81) | +0 |
| biology | 15 | 0 | 1 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 0 | 15 / 0 / 0 (15) | +0 |
| bodies-v2 | 38 | 0 | 2 / 0 / 9 | 38 / 0 / 0 | 0 / 9 | core's | 0.06 / 600 | ADMIT | w526 | 2 / 0 / 9 | 38 / 0 / 0 (38) | +0 |
| botany | 9 | 0 | 1 / 0 / 3 | 7 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 3 | 7 / 0 / 0 (9) | +0 |
| calculus | 62 | 0 | 2 / 0 / 60 | 62 / 0 / 0 | 0 / 9 | core's | 0.0 / 50 | ADMIT | w363 | 2 / 0 / - | 62 / 0 / - (62) | +0 |
| carboncapture | 14 | 0 | 2 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 2 / 0 / 0 | 14 / 0 / 0 (14) | +0 |
| carbonmat | 17 | 0 | 1 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 0 | 17 / 0 / 0 (17) | +0 |
| chemistry-v3 | 281 | 0 | 9 / 4 / 30 | 223 / 0 / 2 | 0 / 9 | core's | 0.08 / 50 | ADMIT | w502 | 9 / 4 / 30 | 223 / 0 / 2 (281) | +0 |
| chemistry | 281 | 0 | 9 / 4 / 43 | 223 / 0 / 15 | 0 / 9 | core's | 0.06 / 50 | NEGATIVE: WRONG: 15 answered wrong, cap 5 | w363 | 9 / 4 / - | 223 / 0 / - (281) | +0 |
| childdev | 9 | 0 | 1 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 0 | 9 / 0 / 0 (9) | +0 |
| climate | 24 | 0 | 3 / 0 / 0 | 24 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 3 / 0 / 0 | 24 / 0 / 0 (24) | +0 |
| coldchain-v2 | 30 | 0 | 2 / 0 / 4 | 29 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 2 / 0 / 4 | 29 / 0 / 0 (30) | +0 |
| coldchain | 30 | 0 | 2 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 2 / 0 / - | 18 / 0 / - (30) | +0 |
| cooking-v2 | 210 | 0 | 3 / 7 / 53 | 155 / 0 / 7 | 0 / 9 | core's | 0.06 / 150 | NEGATIVE: WRONG: 7 answered wrong, cap 4 | w363 | 3 / 7 / - | 155 / 0 / - (210) | +0 |
| cooking-v3-r2 | 228 | 0 | 212 / 0 / 13 | 224 / 0 / 2 | 0 / 9 | core's | 0.06 / 150 | ADMIT | - | - | - | - |
| cooking-v3 | 228 | 0 | 10 / 0 / 12 | 224 / 0 / 2 | 0 / 9 | core's | 0.06 / 150 | ADMIT | w363 | 10 / 0 / - | 224 / 0 / - (228) | +0 |
| cooking | 218 | 0 | 6 / 4 / 97 | 158 / 0 / 0 | 0 / 9 | core's | 0.03 / 150 | ADMIT | w363 | 6 / 4 / - | 158 / 0 / - (218) | +0 |
| crafts | 14 | 0 | 1 / 0 / 1 | 14 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 1 | 14 / 0 / 0 (14) | +0 |
| cyber | 20 | 0 | 1 / 1 / 4 | 16 / 1 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 1 / 4 | 16 / 1 / 0 (20) | +0 |
| dataformats | 93 | 0 | 3 / 0 / 54 | 93 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 93 / 0 / - (93) | +0 |
| decay | 42 | 0 | 2 / 0 / 1 | 34 / 0 / 1 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w524 | 2 / 0 / 1 | 34 / 0 / 1 (42) | +0 |
| densities-r2 | 51 | 0 | 51 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.09 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| densities | 51 | 0 | 3 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.1 / 50 | ADMIT | w524 | 3 / 0 / 0 | 51 / 0 / 0 (51) | +0 |
| ecology | 13 | 0 | 0 / 0 / 1 | 13 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 0 / 0 / 1 | 13 / 0 / 0 (13) | +0 |
| economics | 39 | 0 | 3 / 0 / 3 | 26 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 3 / 0 / 3 | 26 / 0 / 0 (39) | +0 |
| electrical | 24 | 0 | 2 / 0 / 2 | 22 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | w503 | 2 / 0 / 2 | 22 / 0 / 0 (24) | +0 |
| electronics-r2 | 111 | 0 | 3 / 0 / 0 | 111 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 0 / - | 111 / 0 / - (111) | +0 |
| electronics | 111 | 0 | 3 / 0 / 0 | 111 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 0 / - | 111 / 0 / - (111) | +0 |
| embedded | 25 | 0 | 1 / 0 / 3 | 25 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 1 / 0 / 3 | 25 / 0 / 0 (25) | +0 |
| energy-v2 | 74 | 0 | 3 / 1 / 16 | 66 / 1 / 7 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 1 | w363 | 3 / 1 / - | 66 / 1 / - (74) | +0 |
| energy-v3 | 70 | 0 | 3 / 1 / 15 | 69 / 1 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w502 | 3 / 1 / 15 | 69 / 1 / 0 (70) | +0 |
| entomology | 9 | 0 | 1 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 2 | 9 / 0 / 0 (9) | +0 |
| etiquette | 9 | 0 | 1 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 3 | 9 / 0 / 0 (9) | +0 |
| finance-v2-r2 | 64 | 0 | 63 / 1 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| finance-v2 | 64 | 0 | 3 / 1 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 3 / 1 / 0 | 64 / 0 / 0 (64) | +0 |
| finance | 64 | 0 | 3 / 1 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 1 / - | 51 / 0 / - (64) | +0 |
| firesafety-v2 | 10 | 0 | 1 / 0 / 1 | 10 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 1 | 10 / 0 / 0 (10) | +0 |
| firstaid | 9 | 0 | 1 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 3 | 9 / 0 / 0 (9) | +0 |
| fleet | 54 | 0 | 2 / 1 / 7 | 54 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w363 | 2 / 1 / - | 54 / 0 / - (54) | +0 |
| fluids-r2 | 34 | 0 | 18 / 0 / 16 | 34 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| fluids | 34 | 0 | 2 / 0 / 16 | 34 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w524 | 2 / 0 / 16 | 34 / 0 / 0 (34) | +0 |
| forestry | 16 | 0 | 1 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 0 | 14 / 0 / 0 (16) | +0 |
| fuels | 42 | 0 | 2 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w524 | 2 / 0 / 0 | 42 / 0 / 0 (42) | +0 |
| games-v3 | 18 | 0 | 1 / 0 / 3 | 18 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 1 / 0 / 3 | 18 / 0 / 0 (18) | +0 |
| gardening | 15 | 0 | 1 / 1 / 0 | 14 / 1 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 1 / 0 | 14 / 1 / 0 (15) | +0 |
| genetics-v2 | 20 | 0 | 1 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 0 | 15 / 0 / 0 (20) | +0 |
| geography | 9 | 0 | 1 / 0 / 5 | 9 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 1 / 0 / 5 | 9 / 0 / 0 (9) | +0 |
| geology | 18 | 0 | 2 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 2 / 0 / 0 | 18 / 0 / 0 (18) | +0 |
| geometry-v3 | 100 | 0 | 4 / 0 / 37 | 93 / 0 / 0 | 9 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 4 / 0 / - | 93 / 0 / - (100) | +0 |
| geometry-v4 | 93 | 0 | 4 / 0 / 43 | 93 / 0 / 0 | 9 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 4 / 0 / - | 93 / 0 / - (93) | +0 |
| geometry | 97 | 0 | 6 / 0 / 20 | 89 / 0 / 0 | 9 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 6 / 0 / - | 89 / 0 / - (97) | +0 |
| git | 10 | 0 | 1 / 0 / 1 | 7 / 0 / 1 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 1 | 7 / 0 / 1 (10) | +0 |
| government | 14 | 0 | 1 / 1 / 4 | 10 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 1 / 1 / 4 | 10 / 0 / 0 (14) | +0 |
| grammar | 15 | 0 | 1 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 0 | 15 / 0 / 0 (15) | +0 |
| greenhouse-r2 | 45 | 0 | 31 / 0 / 8 | 45 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| greenhouse | 45 | 0 | 3 / 0 / 8 | 45 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 45 / 0 / - (45) | +0 |
| hvac | 42 | 0 | 3 / 0 / 6 | 42 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 42 / 0 / - (42) | +0 |
| hydrology | 52 | 0 | 3 / 0 / 7 | 52 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 52 / 0 / - (52) | +0 |
| iot | 27 | 0 | 2 / 1 / 11 | 27 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 2 / 1 / 11 | 27 / 0 / 0 (27) | +0 |
| javascript | 10 | 0 | 2 / 0 / 1 | 10 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 0 / 1 | 10 / 0 / 0 (10) | +0 |
| labsolutions-r2 | 27 | 0 | 21 / 0 / 0 | 27 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| labsolutions | 27 | 0 | 1 / 1 / 4 | 26 / 1 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 1 / 1 / - | 26 / 1 / - (27) | +0 |
| law | 9 | 0 | 1 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 2 | 9 / 0 / 0 (9) | +0 |
| library | 15 | 0 | 1 / 0 / 2 | 14 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 2 | 14 / 0 / 0 (15) | +0 |
| linguistics | 11 | 0 | 1 / 0 / 1 | 11 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 1 | 11 / 0 / 0 (11) | +0 |
| linux-v2 | 42 | 0 | 3 / 0 / 4 | 42 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 3 / 0 / 4 | 42 / 0 / 0 (42) | +0 |
| literature-v2 | 12 | 0 | 3 / 0 / 3 | 11 / 0 / 0 | 7 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 3 / 0 / 3 | 11 / 0 / 0 (12) | +0 |
| logic-v3 | 12 | 0 | 1 / 0 / 1 | 12 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 1 | 12 / 0 / 0 (12) | +0 |
| marinebio | 9 | 0 | 1 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 0 | 7 / 0 / 0 (9) | +0 |
| materials-v2 | 24 | 0 | 3 / 0 / 3 | 24 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | w503 | 3 / 0 / 3 | 24 / 0 / 0 (24) | +0 |
| mechanisms-v2 | 55 | 0 | 3 / 0 / 18 | 55 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 3 / 0 / 18 | 55 / 0 / 0 (55) | +0 |
| mechanisms | 64 | 0 | 3 / 0 / 11 | 57 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 57 / 0 / - (64) | +0 |
| medicine-r2 | 9 | 0 | 6 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| medicine | 9 | 0 | 2 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 2 / 0 / 3 | 9 / 0 / 0 (9) | +0 |
| meteorology | 46 | 0 | 2 / 1 / 17 | 46 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 2 / 1 / - | 46 / 0 / - (46) | +0 |
| microbiology-v2 | 13 | 0 | 1 / 0 / 2 | 13 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 2 | 13 / 0 / 0 (13) | +0 |
| music-v2-r2 | 64 | 0 | 53 / 0 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| music-v2 | 64 | 0 | 5 / 1 / 8 | 64 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 5 / 1 / 8 | 64 / 0 / 0 (64) | +0 |
| mycelial | 7 | 0 | 2 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 0 / 0 | 7 / 0 / 0 (7) | +0 |
| mycology | 9 | 0 | 2 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 0 / 2 | 9 / 0 / 0 (9) | +0 |
| mythology | 13 | 0 | 1 / 0 / 1 | 13 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 1 | 13 / 0 / 0 (13) | +0 |
| networking | 71 | 0 | 2 / 2 / 14 | 67 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 2 / 2 / 14 | 67 / 1 / 0 (71) | +0 |
| nutrition-label-v2 | 16 | 0 | 2 / 0 / 0 | 16 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | w503 | 2 / 0 / 0 | 16 / 0 / 0 (16) | +0 |
| ocean | 23 | 0 | 2 / 0 / 0 | 23 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 2 / 0 / 0 | 23 / 0 / 0 (23) | +0 |
| optics-v2 | 66 | 0 | 2 / 1 / 9 | 59 / 0 / 7 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 1 | w363 | 2 / 1 / - | 59 / 0 / - (66) | +0 |
| optics-v3 | 67 | 0 | 2 / 1 / 33 | 53 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 2 / 1 / - | 53 / 0 / - (67) | +0 |
| optics-v5-r2 | 65 | 0 | 50 / 1 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| optics-v5 | 65 | 0 | 2 / 1 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | w503 | 2 / 1 / 0 | 51 / 0 / 0 (65) | +0 |
| optics | 61 | 0 | 3 / 0 / 12 | 55 / 0 / 6 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 6 answered wrong, cap 1 | w363 | 3 / 0 / - | 55 / 0 / - (61) | +0 |
| orbits | 35 | 0 | 3 / 0 / 14 | 35 / 0 / 0 | 2 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 3 / 0 / - | 35 / 0 / - (35) | +0 |
| ornithology | 9 | 0 | 1 / 0 / 2 | 7 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 2 | 7 / 0 / 0 (9) | +0 |
| pets | 9 | 0 | 1 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 0 / 0 | 9 / 0 / 0 (9) | +0 |
| physics-r2 | 123 | 0 | 2 / 1 / 21 | 123 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 2 / 1 / - | 123 / 0 / - (123) | +0 |
| physics-r3 | 123 | 0 | 101 / 0 / 1 | 123 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| physics | 123 | 0 | 2 / 1 / 21 | 123 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 2 / 1 / - | 123 / 0 / - (123) | +0 |
| planetary | 18 | 0 | 0 / 2 / 3 | 16 / 2 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 0 / 2 / 3 | 16 / 2 / 0 (18) | +0 |
| poetry | 9 | 0 | 3 / 0 / 3 | 9 / 0 / 0 | 1 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 3 / 0 / 3 | 9 / 0 / 0 (9) | +0 |
| printing-v2 | 37 | 0 | 2 / 1 / 7 | 36 / 1 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 1 / 7 | 36 / 1 / 0 (37) | +0 |
| printing | 36 | 0 | 2 / 1 / 13 | 30 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 2 / 1 / - | 30 / 0 / - (36) | +0 |
| psychology | 9 | 0 | 2 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 0 / 0 | 9 / 0 / 0 (9) | +0 |
| python-r2 | 224 | 0 | 0 / 5 / 95 | 186 / 0 / 33 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 33 answered wrong, cap 4 | w363 | 0 / 5 / - | 186 / 0 / - (224) | +0 |
| python | 224 | 0 | 0 / 5 / 95 | 186 / 0 / 33 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 33 answered wrong, cap 4 | w363 | 0 / 5 / - | 186 / 0 / - (224) | +0 |
| rel-actors | 96 | 0 | 20 / 0 / 6 | 20 / 0 / 6 | 0 / 9 | core's | 0.1 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w525 | 24 / 0 / 6 | 96 / 0 / 0 (96) | -76 |
| rel-aircraft | 24 | 0 | 0 / 0 / 1 | 0 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 1 | 18 / 0 / 0 (24) | -18 |
| rel-airlines | 48 | 0 | 17 / 0 / 14 | 17 / 0 / 14 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 14 answered wrong, cap 1 | w525 | 17 / 0 / 14 | 43 / 0 / 0 (48) | -26 |
| rel-airports | 24 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 9 / 0 / 0 | 20 / 0 / 0 (24) | -11 |
| rel-albums | 36 | 0 | 13 / 0 / 1 | 13 / 0 / 1 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 13 / 0 / 1 | 24 / 0 / 1 (36) | -11 |
| rel-animators | 74 | 0 | 11 / 0 / 1 | 11 / 0 / 1 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 68 / 0 / 2 | 74 / 0 / 0 (74) | -63 |
| rel-anime | 23 | 0 | 1 / 0 / 0 | 1 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 1 / 0 / 0 | 23 / 0 / 0 (23) | -22 |
| rel-architects | 93 | 0 | 17 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 19 / 0 / 0 | 93 / 0 / 0 (93) | -76 |
| rel-asteroids | 24 | 0 | 2 / 0 / 0 | 2 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 2 / 0 / 0 | 24 / 0 / 0 (24) | -22 |
| rel-astronauts | 96 | 0 | 22 / 0 / 5 | 22 / 0 / 5 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 25 / 0 / 5 | 96 / 0 / 0 (96) | -74 |
| rel-astronomers | 96 | 0 | 15 / 0 / 3 | 15 / 0 / 3 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 17 / 0 / 3 | 94 / 0 / 0 (96) | -79 |
| rel-athletes | 108 | 0 | 19 / 0 / 2 | 19 / 0 / 2 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 19 / 0 / 2 | 105 / 0 / 0 (108) | -86 |
| rel-awards | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 10 / 0 / 0 (12) | -10 |
| rel-ballets | 11 | 0 | 4 / 0 / 1 | 4 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 4 / 0 / 1 | 11 / 0 / 0 (11) | -7 |
| rel-bands | 24 | 0 | 8 / 0 / 8 | 8 / 0 / 8 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 8 answered wrong, cap 1 | w525 | 8 / 0 / 8 | 22 / 0 / 0 (24) | -14 |
| rel-baseball | 45 | 0 | 8 / 0 / 2 | 8 / 0 / 2 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 12 / 0 / 2 | 45 / 0 / 0 (45) | -37 |
| rel-basketball | 107 | 0 | 24 / 0 / 1 | 24 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 29 / 0 / 1 | 105 / 0 / 0 (107) | -81 |
| rel-battles | 23 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 15 / 0 / 0 | 21 / 0 / 0 (23) | -6 |
| rel-biathletes | 56 | 0 | 10 / 0 / 1 | 10 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 14 / 0 / 2 | 56 / 0 / 0 (56) | -46 |
| rel-biologists | 96 | 0 | 13 / 0 / 3 | 13 / 0 / 3 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 15 / 0 / 3 | 92 / 0 / 0 (96) | -79 |
| rel-bloggers | 74 | 0 | 17 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 66 / 0 / 0 | 72 / 0 / 0 (74) | -55 |
| rel-boxers | 96 | 0 | 24 / 0 / 1 | 24 / 0 / 1 | 0 / 9 | core's | 0.08 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 26 / 0 / 1 | 93 / 0 / 1 (96) | -69 |
| rel-brands | 48 | 0 | 9 / 0 / 6 | 9 / 0 / 6 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w406 | 27 / 0 / 6 | 44 / 0 / 0 (48) | -35 |
| rel-breeds | 12 | 0 | 5 / 0 / 3 | 5 / 0 / 3 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 5 / 0 / 3 | 12 / 0 / 0 (12) | -7 |
| rel-bridges | 44 | 0 | 9 / 0 / 2 | 9 / 0 / 2 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 9 / 0 / 2 | 39 / 0 / 0 (44) | -30 |
| rel-business | 96 | 0 | 23 / 0 / 1 | 23 / 0 / 1 | 0 / 9 | core's | 0.08 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 27 / 0 / 1 | 95 / 0 / 0 (96) | -72 |
| rel-carbrands | 35 | 0 | 8 / 0 / 8 | 8 / 0 / 8 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 8 answered wrong, cap 1 | w525 | 8 / 0 / 8 | 29 / 0 / 0 (35) | -21 |
| rel-carmodels | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 8 / 0 / 0 (12) | -8 |
| rel-castles | 24 | 0 | 7 / 0 / 1 | 7 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 7 / 0 / 1 | 24 / 0 / 0 (24) | -17 |
| rel-channels | 39 | 0 | 9 / 0 / 4 | 9 / 0 / 4 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 4 answered wrong, cap 1 | w406 | 16 / 0 / 4 | 32 / 0 / 0 (39) | -23 |
| rel-characters | 24 | 0 | 1 / 0 / 1 | 1 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 1 / 0 / 1 | 19 / 0 / 0 (24) | -18 |
| rel-chefs | 15 | 0 | 5 / 0 / 0 | 5 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 6 / 0 / 0 | 15 / 0 / 0 (15) | -10 |
| rel-chemists | 96 | 0 | 17 / 0 / 1 | 17 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 18 / 0 / 1 | 96 / 0 / 0 (96) | -79 |
| rel-chess | 100 | 0 | 14 / 0 / 1 | 14 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 15 / 0 / 1 | 98 / 0 / 0 (100) | -84 |
| rel-churches | 17 | 0 | 4 / 0 / 1 | 4 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 4 / 0 / 1 | 15 / 0 / 1 (17) | -11 |
| rel-comedians | 96 | 0 | 21 / 0 / 3 | 21 / 0 / 3 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 27 / 0 / 3 | 96 / 0 / 0 (96) | -75 |
| rel-comics | 35 | 0 | 13 / 0 / 1 | 13 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 13 / 0 / 1 | 32 / 0 / 0 (35) | -19 |
| rel-companies | 60 | 0 | 19 / 0 / 8 | 19 / 0 / 8 | 0 / 9 | core's | 0.15 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 8 answered wrong, cap 1 | w525 | 19 / 0 / 8 | 52 / 0 / 0 (60) | -33 |
| rel-composers | 108 | 0 | 27 / 0 / 3 | 27 / 0 / 3 | 0 / 9 | core's | 0.16 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 2 | w525 | 29 / 0 / 3 | 107 / 0 / 0 (108) | -80 |
| rel-compounds | 23 | 0 | 1 / 0 / 0 | 1 / 0 / 0 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 1 / 0 / 0 | 22 / 0 / 0 (23) | -21 |
| rel-computerscientists | 92 | 0 | 24 / 0 / 2 | 24 / 0 / 2 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 83 / 0 / 3 | 92 / 0 / 0 (92) | -68 |
| rel-countries-v2 | 84 | 0 | 16 / 0 / 6 | 16 / 0 / 6 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w525 | 16 / 0 / 6 | 72 / 0 / 0 (84) | -56 |
| rel-cricketers | 63 | 0 | 18 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 18 / 0 / 0 | 62 / 0 / 0 (63) | -44 |
| rel-criminals | 60 | 0 | 5 / 0 / 1 | 5 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 9 / 0 / 1 | 60 / 0 / 0 (60) | -55 |
| rel-crosscountry | 70 | 0 | 14 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 21 / 0 / 1 | 70 / 0 / 0 (70) | -56 |
| rel-curlers | 24 | 0 | 2 / 0 / 1 | 2 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 5 / 0 / 4 | 24 / 0 / 0 (24) | -22 |
| rel-cyclists | 107 | 0 | 23 / 0 / 0 | 23 / 0 / 0 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 26 / 0 / 0 | 105 / 0 / 0 (107) | -82 |
| rel-dancers | 96 | 0 | 17 / 0 / 1 | 17 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 22 / 0 / 1 | 96 / 0 / 0 (96) | -79 |
| rel-diplomats | 96 | 0 | 18 / 0 / 4 | 18 / 0 / 4 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 4 answered wrong, cap 1 | w525 | 20 / 0 / 4 | 92 / 0 / 0 (96) | -74 |
| rel-directors | 96 | 0 | 22 / 0 / 2 | 22 / 0 / 2 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 24 / 0 / 2 | 94 / 0 / 0 (96) | -72 |
| rel-diseases | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 12 / 0 / 0 (12) | -12 |
| rel-dishes | 12 | 0 | 1 / 0 / 6 | 1 / 0 / 6 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w525 | 1 / 0 / 6 | 12 / 0 / 0 (12) | -11 |
| rel-drivers | 100 | 0 | 18 / 0 / 2 | 18 / 0 / 2 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 20 / 0 / 2 | 100 / 0 / 0 (100) | -82 |
| rel-economists | 96 | 0 | 17 / 0 / 1 | 17 / 0 / 1 | 0 / 9 | core's | 0.18 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 20 / 0 / 1 | 94 / 0 / 0 (96) | -77 |
| rel-editors | 84 | 0 | 15 / 0 / 1 | 15 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 76 / 0 / 1 | 82 / 0 / 0 (84) | -67 |
| rel-engineers | 96 | 0 | 12 / 0 / 3 | 12 / 0 / 3 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 12 / 0 / 3 | 95 / 0 / 0 (96) | -83 |
| rel-equestrians | 33 | 0 | 11 / 0 / 0 | 11 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 27 / 0 / 0 | 33 / 0 / 0 (33) | -22 |
| rel-explorers | 87 | 0 | 12 / 0 / 1 | 12 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 12 / 0 / 1 | 85 / 0 / 0 (87) | -73 |
| rel-fencers | 94 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 31 / 0 / 2 | 93 / 0 / 0 (94) | -78 |
| rel-fieldhockey | 29 | 0 | 4 / 0 / 3 | 4 / 0 / 3 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w406 | 10 / 0 / 3 | 29 / 0 / 0 (29) | -25 |
| rel-films-v2 | 84 | 0 | 9 / 0 / 5 | 9 / 0 / 5 | 0 / 9 | core's | 0.17 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w399 | 10 / 0 / 6 | 52 / 0 / 0 (84) | -43 |
| rel-footballclubs | 36 | 0 | 5 / 0 / 1 | 5 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 5 / 0 / 1 | 36 / 0 / 0 (36) | -31 |
| rel-footballers | 120 | 0 | 22 / 0 / 0 | 22 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 24 / 0 / 0 | 117 / 0 / 0 (120) | -95 |
| rel-galaxies | 36 | 0 | 19 / 0 / 2 | 19 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 25 / 0 / 2 | 36 / 0 / 0 (36) | -17 |
| rel-genres | 12 | 0 | 1 / 0 / 5 | 1 / 0 / 5 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 1 / 0 / 5 | 12 / 0 / 0 (12) | -11 |
| rel-geologists | 92 | 0 | 15 / 0 / 1 | 15 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 82 / 0 / 2 | 92 / 0 / 0 (92) | -77 |
| rel-golfers | 38 | 0 | 6 / 0 / 1 | 6 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 6 / 0 / 1 | 37 / 0 / 0 (38) | -31 |
| rel-graphicartists | 96 | 0 | 12 / 0 / 3 | 12 / 0 / 3 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w406 | 85 / 0 / 3 | 95 / 0 / 0 (96) | -83 |
| rel-gridiron | 34 | 0 | 9 / 0 / 1 | 9 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 22 / 0 / 2 | 33 / 0 / 0 (34) | -24 |
| rel-gymnasts | 77 | 0 | 10 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 26 / 0 / 0 | 77 / 0 / 0 (77) | -67 |
| rel-handball | 79 | 0 | 20 / 0 / 1 | 20 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 27 / 0 / 3 | 77 / 0 / 0 (79) | -57 |
| rel-historians | 96 | 0 | 16 / 0 / 5 | 16 / 0 / 5 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 19 / 0 / 5 | 94 / 0 / 0 (96) | -78 |
| rel-hotels | 24 | 0 | 2 / 0 / 1 | 2 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 10 / 0 / 1 | 21 / 0 / 0 (24) | -19 |
| rel-icehockey | 101 | 0 | 29 / 0 / 1 | 29 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 31 / 0 / 1 | 98 / 0 / 0 (101) | -69 |
| rel-illustrators | 96 | 0 | 16 / 0 / 2 | 16 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 83 / 0 / 4 | 91 / 0 / 0 (96) | -75 |
| rel-instruments | 19 | 0 | 2 / 0 / 5 | 2 / 0 / 5 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 2 / 0 / 5 | 19 / 0 / 0 (19) | -17 |
| rel-islands | 36 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 15 / 0 / 0 | 30 / 0 / 0 (36) | -15 |
| rel-journalists | 96 | 0 | 11 / 0 / 4 | 11 / 0 / 4 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 4 answered wrong, cap 1 | w525 | 12 / 0 / 4 | 96 / 0 / 0 (96) | -85 |
| rel-lakes | 12 | 0 | 8 / 0 / 0 | 8 / 0 / 0 | 0 / 9 | core's | 0.08 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 8 / 0 / 0 | 12 / 0 / 0 (12) | -4 |
| rel-languages | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 11 / 0 / 0 (12) | -11 |
| rel-lawyers | 96 | 0 | 14 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.09 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 14 / 0 / 0 | 95 / 0 / 0 (96) | -81 |
| rel-leagues | 21 | 0 | 9 / 0 / 5 | 9 / 0 / 5 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w406 | 10 / 0 / 4 | 16 / 0 / 0 (21) | -7 |
| rel-libraries | 22 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 14 / 0 / 0 | 21 / 0 / 0 (22) | -12 |
| rel-linguists | 96 | 0 | 11 / 0 / 2 | 11 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 13 / 0 / 2 | 94 / 0 / 0 (96) | -83 |
| rel-mathematicians | 96 | 0 | 13 / 0 / 1 | 13 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 14 / 0 / 1 | 96 / 0 / 0 (96) | -83 |
| rel-military | 96 | 0 | 16 / 0 / 2 | 16 / 0 / 2 | 0 / 9 | core's | 0.15 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 19 / 0 / 2 | 93 / 0 / 0 (96) | -77 |
| rel-militaryunits | 17 | 0 | 4 / 0 / 1 | 4 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 6 / 0 / 1 | 15 / 0 / 0 (17) | -11 |
| rel-missionaries | 73 | 0 | 11 / 0 / 1 | 11 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 48 / 0 / 1 | 73 / 0 / 0 (73) | -62 |
| rel-models | 96 | 0 | 22 / 0 / 5 | 22 / 0 / 5 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 25 / 0 / 5 | 95 / 0 / 0 (96) | -73 |
| rel-monarchs | 144 | 0 | 12 / 0 / 5 | 12 / 0 / 5 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 2 | w525 | 13 / 0 / 5 | 121 / 0 / 0 (144) | -109 |
| rel-monuments | 29 | 0 | 8 / 0 / 1 | 8 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 13 / 0 / 1 | 26 / 0 / 0 (29) | -18 |
| rel-moons | 36 | 0 | 9 / 0 / 1 | 9 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 9 / 0 / 1 | 36 / 0 / 0 (36) | -27 |
| rel-mountains | 24 | 0 | 12 / 0 / 2 | 12 / 0 / 2 | 0 / 9 | core's | 0.1 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 12 / 0 / 2 | 20 / 0 / 0 (24) | -8 |
| rel-museums | 34 | 1 | - | 11 / 0 / 1 | 0 / 9 | core's | 0.07 / 1000 | INCOMPLETE | w525 | 11 / 0 / 1 | 32 / 0 / 0 (34) | -21 |
| rel-musicians | 120 | 0 | 19 / 0 / 2 | 19 / 0 / 2 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 21 / 0 / 2 | 119 / 0 / 0 (120) | -100 |
| rel-mythology | 36 | 0 | 1 / 0 / 0 | 1 / 0 / 0 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 1 / 0 / 0 | 29 / 0 / 1 (36) | -28 |
| rel-newspapers | 48 | 0 | 13 / 0 / 9 | 13 / 0 / 9 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 9 answered wrong, cap 1 | w525 | 13 / 0 / 9 | 40 / 0 / 0 (48) | -27 |
| rel-novelists | 96 | 0 | 18 / 0 / 1 | 18 / 0 / 1 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 18 / 0 / 2 | 96 / 0 / 0 (96) | -78 |
| rel-novels | 60 | 0 | 10 / 0 / 6 | 10 / 0 / 6 | 0 / 9 | core's | 0.17 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w524 | 10 / 0 / 6 | 50 / 0 / 0 (60) | -40 |
| rel-nurses | 61 | 0 | 20 / 0 / 4 | 20 / 0 / 4 | 0 / 9 | core's | 0.05 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 4 answered wrong, cap 1 | w406 | 42 / 0 / 3 | 61 / 0 / 0 (61) | -41 |
| rel-observatories | 16 | 0 | 4 / 0 / 1 | 4 / 0 / 1 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 6 / 0 / 1 | 15 / 0 / 0 (16) | -11 |
| rel-operas | 24 | 0 | 11 / 0 / 3 | 11 / 0 / 3 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w524 | 11 / 0 / 3 | 23 / 0 / 1 (24) | -12 |
| rel-organisations | 36 | 0 | 12 / 0 / 9 | 12 / 0 / 9 | 0 / 9 | core's | 0.08 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 9 answered wrong, cap 1 | w525 | 12 / 0 / 9 | 32 / 0 / 0 (36) | -20 |
| rel-painters | 96 | 0 | 18 / 0 / 2 | 18 / 0 / 2 | 0 / 9 | core's | 0.19 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 18 / 0 / 2 | 96 / 0 / 0 (96) | -78 |
| rel-paintings | 24 | 0 | 4 / 0 / 0 | 4 / 0 / 0 | 0 / 9 | core's | 0.22 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 4 / 0 / 0 | 17 / 0 / 0 (24) | -13 |
| rel-parks | 12 | 0 | 4 / 0 / 0 | 4 / 0 / 0 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 4 / 0 / 0 | 12 / 0 / 0 (12) | -8 |
| rel-parties | 31 | 0 | 5 / 0 / 11 | 5 / 0 / 11 | 0 / 9 | core's | 0.04 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 11 answered wrong, cap 1 | w525 | 5 / 0 / 11 | 26 / 0 / 0 (31) | -21 |
| rel-pharmacists | 59 | 0 | 8 / 0 / 2 | 8 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 53 / 0 / 0 | 59 / 0 / 0 (59) | -51 |
| rel-philosophers | 96 | 2 | - | 12 / 0 / 4 | 0 / 9 | core's | 0.18 / 1000 | NEGATIVE: WRONG: 4 answered wrong, cap 1 | w525 | 14 / 0 / 4 | 83 / 0 / 0 (96) | -71 |
| rel-photographers | 96 | 1 | - | 19 / 0 / 4 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: WRONG: 4 answered wrong, cap 1 | w525 | 21 / 0 / 4 | 94 / 0 / 0 (96) | -75 |
| rel-physicians | 96 | 0 | 11 / 0 / 1 | 11 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 12 / 0 / 1 | 94 / 0 / 0 (96) | -83 |
| rel-physicists | 96 | 0 | 14 / 0 / 4 | 14 / 0 / 4 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 4 answered wrong, cap 1 | w525 | 15 / 0 / 4 | 95 / 0 / 0 (96) | -81 |
| rel-planets | 24 | 0 | 2 / 0 / 0 | 2 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 2 / 0 / 0 | 24 / 0 / 0 (24) | -22 |
| rel-playwrights | 96 | 0 | 18 / 0 / 5 | 18 / 0 / 5 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 20 / 0 / 5 | 95 / 0 / 0 (96) | -77 |
| rel-poems | 12 | 0 | 4 / 0 / 1 | 4 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 4 / 0 / 1 | 12 / 0 / 0 (12) | -8 |
| rel-poets | 96 | 0 | 13 / 0 / 2 | 13 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w525 | 14 / 0 / 2 | 96 / 0 / 0 (96) | -83 |
| rel-police | 44 | 0 | 8 / 0 / 1 | 8 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 37 / 0 / 1 | 43 / 0 / 1 (44) | -35 |
| rel-politicians | 108 | 0 | 18 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 22 / 0 / 0 | 104 / 0 / 0 (108) | -86 |
| rel-printmakers | 88 | 0 | 15 / 0 / 3 | 15 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w406 | 81 / 0 / 3 | 87 / 0 / 0 (88) | -72 |
| rel-psychologists | 84 | 0 | 18 / 0 / 1 | 18 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 22 / 0 / 1 | 83 / 0 / 0 (84) | -65 |
| rel-racketsports | 58 | 0 | 7 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 17 / 0 / 0 | 58 / 0 / 0 (58) | -51 |
| rel-religions | 21 | 0 | 4 / 0 / 12 | 4 / 0 / 12 | 0 / 9 | core's | 0.01 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 12 answered wrong, cap 1 | w525 | 4 / 0 / 12 | 21 / 0 / 0 (21) | -17 |
| rel-rivers | 24 | 0 | 2 / 0 / 3 | 2 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w525 | 2 / 0 / 3 | 20 / 0 / 0 (24) | -18 |
| rel-rowers | 104 | 0 | 17 / 0 / 2 | 17 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 26 / 0 / 7 | 103 / 0 / 0 (104) | -86 |
| rel-rugby | 42 | 0 | 7 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 7 / 0 / 0 | 42 / 0 / 0 (42) | -35 |
| rel-sculptors | 90 | 0 | 15 / 0 / 1 | 15 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 16 / 0 / 1 | 89 / 0 / 0 (90) | -74 |
| rel-sculptures | 24 | 0 | 4 / 0 / 0 | 4 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 4 / 0 / 0 | 24 / 0 / 0 (24) | -20 |
| rel-ships | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 10 / 0 / 0 (12) | -10 |
| rel-shooters | 45 | 0 | 7 / 0 / 1 | 7 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 13 / 0 / 2 | 44 / 0 / 0 (45) | -37 |
| rel-singers | 120 | 0 | 23 / 0 / 0 | 23 / 0 / 0 | 0 / 9 | core's | 0.09 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 26 / 0 / 0 | 116 / 0 / 0 (120) | -93 |
| rel-skaters | 78 | 0 | 13 / 0 / 0 | 13 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 28 / 0 / 1 | 78 / 0 / 0 (78) | -65 |
| rel-skiers | 91 | 0 | 21 / 0 / 1 | 21 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 33 / 0 / 2 | 89 / 0 / 0 (91) | -68 |
| rel-skyscrapers | 36 | 0 | 5 / 0 / 1 | 5 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 5 / 0 / 1 | 31 / 0 / 0 (36) | -26 |
| rel-snooker | 17 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 1 / 0 / 2 | 17 / 0 / 0 (17) | -17 |
| rel-software | 36 | 0 | 6 / 0 / 0 | 6 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 6 / 0 / 0 | 31 / 0 / 0 (36) | -25 |
| rel-songs | 48 | 0 | 9 / 0 / 2 | 9 / 0 / 2 | 0 / 9 | core's | 0.06 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w524 | 9 / 0 / 2 | 37 / 0 / 1 (48) | -28 |
| rel-spacecraft | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 0 / 0 / 0 | 8 / 0 / 1 (12) | -8 |
| rel-speedskaters | 74 | 0 | 17 / 0 / 1 | 17 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 26 / 0 / 1 | 74 / 0 / 0 (74) | -57 |
| rel-spies | 60 | 0 | 15 / 0 / 1 | 15 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 48 / 0 / 2 | 59 / 0 / 0 (60) | -44 |
| rel-sportsevents | 36 | 0 | 5 / 0 / 0 | 5 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 5 / 0 / 0 | 36 / 0 / 0 (36) | -31 |
| rel-sportsteams | 36 | 0 | 7 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 7 / 0 / 0 | 36 / 0 / 0 (36) | -29 |
| rel-stadiums | 36 | 0 | 12 / 0 / 0 | 12 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 12 / 0 / 0 | 33 / 0 / 0 (36) | -21 |
| rel-stations | 24 | 0 | 3 / 0 / 3 | 3 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w406 | 3 / 0 / 3 | 23 / 0 / 0 (24) | -20 |
| rel-statisticians | 58 | 0 | 14 / 0 / 3 | 14 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w406 | 51 / 0 / 3 | 57 / 0 / 0 (58) | -43 |
| rel-swimmers | 108 | 0 | 21 / 0 / 2 | 21 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 23 / 0 / 2 | 108 / 0 / 0 (108) | -87 |
| rel-temples | 36 | 0 | 5 / 0 / 0 | 5 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 22 / 0 / 2 | 34 / 0 / 0 (36) | -29 |
| rel-tennis | 108 | 0 | 22 / 0 / 1 | 22 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 23 / 0 / 1 | 108 / 0 / 0 (108) | -86 |
| rel-theatres | 25 | 0 | 4 / 0 / 0 | 4 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 7 / 0 / 0 | 23 / 0 / 0 (25) | -19 |
| rel-themeparks | 12 | 0 | 6 / 0 / 2 | 6 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 6 / 0 / 2 | 12 / 0 / 0 (12) | -6 |
| rel-theologians | 100 | 0 | 16 / 0 / 3 | 16 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 2 | w525 | 16 / 0 / 3 | 100 / 0 / 0 (100) | -84 |
| rel-tradeunionists | 75 | 0 | 14 / 0 / 1 | 14 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 72 / 0 / 1 | 75 / 0 / 0 (75) | -61 |
| rel-translators | 96 | 0 | 5 / 0 / 1 | 5 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 79 / 0 / 2 | 95 / 0 / 0 (96) | -90 |
| rel-triathletes | 12 | 0 | 1 / 0 / 0 | 1 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 8 / 0 / 0 | 12 / 0 / 0 (12) | -11 |
| rel-tvproducers | 96 | 0 | 27 / 0 / 1 | 27 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 89 / 0 / 1 | 95 / 0 / 0 (96) | -68 |
| rel-tvseries-v2 | 72 | 0 | 3 / 0 / 6 | 3 / 0 / 6 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w399 | 3 / 0 / 6 | 52 / 0 / 1 (72) | -49 |
| rel-universities | 36 | 0 | 13 / 0 / 10 | 13 / 0 / 10 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 10 answered wrong, cap 1 | w525 | 13 / 0 / 10 | 35 / 0 / 0 (36) | -22 |
| rel-videogames | 36 | 0 | 9 / 0 / 3 | 9 / 0 / 3 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 3 answered wrong, cap 1 | w524 | 9 / 0 / 3 | 31 / 0 / 0 (36) | -22 |
| rel-volleyball | 58 | 0 | 11 / 0 / 0 | 11 / 0 / 0 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 17 / 0 / 3 | 58 / 0 / 0 (58) | -47 |
| rel-wars | 24 | 0 | 2 / 0 / 1 | 2 / 0 / 1 | 0 / 9 | core's | 0.03 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 2 / 0 / 1 | 22 / 0 / 0 (24) | -20 |
| rel-waterpolo | 46 | 0 | 5 / 0 / 2 | 5 / 0 / 2 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 2 answered wrong, cap 1 | w406 | 28 / 0 / 2 | 46 / 0 / 0 (46) | -41 |
| rel-youtubers | 56 | 0 | 7 / 0 / 1 | 7 / 0 / 1 | 0 / 9 | core's | 0.02 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3 | w406 | 51 / 0 / 1 | 54 / 0 / 0 (56) | -47 |
| renewables | 26 | 0 | 1 / 2 / 9 | 23 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 2 / 9 | 23 / 0 / 0 (26) | +0 |
| retail | 51 | 0 | 3 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 0 / - | 51 / 0 / - (51) | +0 |
| robotics-v2 | 23 | 0 | 2 / 0 / 0 | 20 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 2 / 0 / 0 | 20 / 0 / 0 (23) | +0 |
| safety | 45 | 0 | 4 / 0 / 24 | 45 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 4 / 0 / - | 45 / 0 / - (45) | +0 |
| seismology | 34 | 0 | 3 / 0 / 0 | 29 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 3 / 0 / 0 | 29 / 0 / 0 (34) | +0 |
| sociology | 9 | 0 | 1 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w503 | 1 / 0 / 2 | 9 / 0 / 0 (9) | +0 |
| soil-r2 | 36 | 0 | 14 / 2 / 20 | 36 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| soil | 36 | 0 | 1 / 2 / 20 | 36 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 1 / 2 / 20 | 36 / 0 / 0 (36) | +0 |
| spacecomms | 36 | 0 | 0 / 2 / 7 | 36 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 0 / 2 / - | 36 / 0 / - (36) | +0 |
| spacecraft | 21 | 0 | 0 / 1 / 3 | 14 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 0 / 1 / 3 | 14 / 0 / 0 (21) | +0 |
| sports | 19 | 0 | 0 / 1 / 8 | 19 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | w503 | 0 / 1 / 8 | 19 / 0 / 0 (19) | +0 |
| springs | 42 | 0 | 2 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w524 | 2 / 0 / 0 | 42 / 0 / 0 (42) | +0 |
| sql | 61 | 0 | 2 / 0 / 0 | 61 / 0 / 0 | 0 / 9 | core's | 0.0 / 50 | ADMIT | w363 | 2 / 0 / - | 61 / 0 / - (61) | +0 |
| statistics-v2 | 144 | 0 | 45 / 2 / 38 | 132 / 2 / 7 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 2 | w363 | 45 / 2 / - | 132 / 2 / - (144) | +0 |
| statistics-v3 | 144 | 0 | 51 / 2 / 59 | 142 / 2 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | w363 | 51 / 2 / - | 142 / 2 / - (144) | +0 |
| statistics | 142 | 0 | 42 / 2 / 38 | 126 / 2 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 42 / 2 / - | 126 / 2 / - (142) | +0 |
| thermo | 50 | 0 | 3 / 1 / 19 | 50 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 1 / - | 50 / 0 / - (50) | +0 |
| units-v2 | 74 | 0 | 7 / 0 / 26 | 43 / 0 / 18 | 6 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 18 answered wrong, cap 1 | w363 | 7 / 0 / - | 43 / 0 / - (74) | +0 |
| units-v3-r2 | 75 | 0 | 47 / 0 / 26 | 75 / 0 / 0 | 6 / 9 | core's | 0.01 / 50 | ADMIT | - | - | - | - |
| units-v3 | 75 | 0 | 4 / 0 / 27 | 75 / 0 / 0 | 6 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 4 / 0 / - | 75 / 0 / - (75) | +0 |
| units | 76 | 0 | 5 / 0 / 33 | 76 / 0 / 0 | 6 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 5 / 0 / - | 76 / 0 / - (76) | +0 |
| ushistory | 12 | 0 | 0 / 1 / 2 | 11 / 1 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 0 / 1 / 2 | 11 / 1 / 0 (12) | +0 |
| warehouse-r2 | 199 | 0 | 8 / 6 / 3 | 194 / 5 / 0 | 0 / 9 | core's | 0.08 / 50 | ADMIT | w363 | 7 / 1 / - | 193 / 0 / - (193) | +0 |
| warehouse | 199 | 0 | 8 / 6 / 3 | 194 / 5 / 0 | 0 / 9 | core's | 0.08 / 50 | ADMIT | w363 | 7 / 1 / - | 193 / 0 / - (193) | +0 |
| water-r3 | 0 | - | - | - | - | - | - | NO PANEL: no heldout items in the shipped panel | - | - | - | - |
| water | 47 | 0 | 3 / 0 / 15 | 47 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 0 / - | 47 / 0 / - (47) | +0 |
| wildlife | 9 | 0 | 2 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 2 / 0 / 0 | 7 / 0 / 0 (9) | +0 |
| wiring | 45 | 0 | 3 / 0 / 6 | 45 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 0 / - | 45 / 0 / - (45) | +0 |
| woodworking | 36 | 0 | 3 / 0 / 3 | 33 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 3 / 0 / 3 | 33 / 0 / 0 (36) | +0 |
| worldhistory | 11 | 0 | 4 / 0 / 4 | 11 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w503 | 4 / 0 / 4 | 11 / 0 / 0 (11) | +0 |

## Control A: Oracle7 + specialist, release composition, shipped head

Run directory `var/parity/control-front-shipped-head`; command `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}`.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 69 | 0 | 3 / 1 / 5 | 69 / 0 / 0 | 0 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 3 / 1 / - | 69 / 0 / - (69) | +0 |
| cooking-v3 | 228 | 0 | 10 / 0 / 12 | 224 / 0 / 2 | 0 / 9 | core's | 0.08 / 150 | ADMIT | w363 | 10 / 0 / - | 224 / 0 / - (228) | +0 |
| densities | 51 | 0 | 3 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | w524 | 3 / 0 / 0 | 51 / 0 / 0 (51) | +0 |
| rel-actors | 96 | 0 | 20 / 0 / 6 | 20 / 0 / 6 | 0 / 9 | core's | 0.18 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w525 | 24 / 0 / 6 | 96 / 0 / 0 (96) | -76 |
| units-v3 | 75 | 0 | 4 / 0 / 27 | 75 / 0 / 0 | 6 / 9 | core's | 0.04 / 50 | ADMIT | w363 | 4 / 0 / - | 75 / 0 / - (75) | +0 |
| units | 76 | 0 | 5 / 0 / 33 | 76 / 0 / 0 | 6 / 9 | core's | 0.01 / 50 | ADMIT | w363 | 5 / 0 / - | 76 / 0 / - (76) | +0 |

## Control B: Oracle7 + specialist, exam.py composition, shipped head

Run directory `var/parity/control-shipped-head`; command `tools/parity/answerers/oracle7.py --tip {shipped_head} --specialist {dir}`.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 69 | 0 | 3 / 1 / 5 | 57 / 1 / 5 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 5 answered wrong, cap 1 | w363 | 3 / 1 / - | 69 / 0 / - (69) | -12 |
| cooking-v3 | 228 | 0 | 10 / 0 / 12 | 212 / 0 / 14 | 0 / 9 | core's | 0.06 / 150 | NEGATIVE: WRONG: 14 answered wrong, cap 4 | w363 | 10 / 0 / - | 224 / 0 / - (228) | -12 |
| densities | 51 | 0 | 3 / 0 / 0 | 50 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | w524 | 3 / 0 / 0 | 51 / 0 / 0 (51) | -1 |
| rel-actors | 96 | 0 | 20 / 0 / 6 | 20 / 0 / 6 | 0 / 9 | core's | 0.1 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 6 answered wrong, cap 1 | w525 | 24 / 0 / 6 | 96 / 0 / 0 (96) | -76 |
| units-v3 | 75 | 0 | 4 / 0 / 27 | 48 / 0 / 27 | 6 / 9 | core's | 0.03 / 50 | NEGATIVE: WRONG: 27 answered wrong, cap 1 | w363 | 4 / 0 / - | 75 / 0 / - (75) | -27 |
| units | 76 | 0 | 5 / 0 / 33 | 43 / 0 / 33 | 6 / 9 | core's | 0.01 / 50 | NEGATIVE: WRONG: 33 answered wrong, cap 1 | w363 | 5 / 0 / - | 76 / 0 / - (76) | -33 |

## Control C: Oracle7 + specialist, exam.py composition, current head w540

Run directory `var/parity/control-w540`; command `tools/parity/answerers/oracle7.py --specialist {dir}`.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 69 | 0 | 62 / 2 / 0 | 62 / 2 / 0 | 0 / 9 | core's | 0.01 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | w363 | 3 / 1 / - | 69 / 0 / - (69) | -7 |
| cooking-v3 | 228 | 0 | 212 / 0 / 13 | 212 / 0 / 13 | 0 / 9 | core's | 0.05 / 150 | NEGATIVE: DOMAIN: gain 0, needs 5; WRONG: 13 answered wrong, cap 4 | w363 | 10 / 0 / - | 224 / 0 / - (228) | -12 |
| densities | 51 | 0 | 51 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 3 / 0 / 0 | 51 / 0 / 0 (51) | +0 |
| rel-actors | 96 | 0 | 20 / 0 / 5 | 20 / 0 / 5 | 0 / 9 | core's | 0.07 / 1000 | NEGATIVE: DOMAIN: gain 0, needs 3; WRONG: 5 answered wrong, cap 1 | w525 | 24 / 0 / 6 | 96 / 0 / 0 (96) | -76 |
| units-v3 | 75 | 0 | 47 / 0 / 26 | 48 / 0 / 26 | 6 / 9 | core's | 0.01 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3; WRONG: 26 answered wrong, cap 1 | w363 | 4 / 0 / - | 75 / 0 / - (75) | -27 |
| units | 76 | 0 | 43 / 0 / 29 | 47 / 0 / 29 | 6 / 9 | core's | 0.0 / 50 | NEGATIVE: WRONG: 29 answered wrong, cap 1 | w363 | 5 / 0 / - | 76 / 0 / - (76) | -29 |

## veri7vn packaged, acoustics sample

Run directory `var/parity/veri7vn-sample`; command `tools/parity/answerers/veri7vn_packaged.py deployment-ui-d44-standalone-aae0d7dd/generations/2fd159a8...`.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 3 | 0 | - | 0 / 0 / 0 | - | - | - | INCOMPLETE | w363 | 3 / 1 / - | 69 / 0 / - (69) | - |

## Routes

Which part of Oracle7 the head used for each of the 924 general questions in `core_panel.json`, read from the `path` the release recorded for each (nothing was run for this table; `tools/parity/routes.py`). The route is the text before the first `>` in the path; `|` joins a guard or clarification to the organ it stood in front of, and the table counts the first part. Use it to see, before building a lift, whether the family you would replace is on a route that any core question takes.

| Route | Items | Answered | Withheld | Clarification | Share |
|---|---|---|---|---|---|
| `organ:relation` | 204 | 204 | 0 | 0 | 22.1% |
| `specialist_call` | 186 | 142 | 44 | 0 | 20.1% |
| `precision_guard:*` | 114 | 0 | 114 | 0 | 12.3% |
| `network` | 96 | 84 | 12 | 0 | 10.4% |
| `act:clarify` | 94 | 0 | 0 | 94 | 10.2% |
| `unverified:*` | 37 | 0 | 37 | 0 | 4.0% |
| `arb:*` | 30 | 4 | 26 | 0 | 3.2% |
| `organ:math` | 24 | 24 | 0 | 0 | 2.6% |
| `corpus_query:property_of` | 23 | 0 | 23 | 0 | 2.5% |
| `network3` | 18 | 18 | 0 | 0 | 1.9% |
| `op:*` | 17 | 17 | 0 | 0 | 1.8% |
| `compose:bridge` | 12 | 12 | 0 | 0 | 1.3% |
| `exact_router` | 11 | 11 | 0 | 0 | 1.2% |
| `act:clarify_specific` | 10 | 0 | 0 | 10 | 1.1% |
| `family_precedence` | 10 | 10 | 0 | 0 | 1.1% |
| `organ:converse` | 10 | 10 | 0 | 0 | 1.1% |
| `algebra:solved` | 6 | 6 | 0 | 0 | 0.6% |
| `capability:summarize` | 5 | 0 | 5 | 0 | 0.5% |
| `verified:cube` | 5 | 5 | 0 | 0 | 0.5% |
| `family_precedence:low_credit` | 4 | 0 | 4 | 0 | 0.4% |
| `specialist_precedence` | 3 | 3 | 0 | 0 | 0.3% |
| `factoid:page` | 2 | 2 | 0 | 0 | 0.2% |
| `cube:read` | 1 | 1 | 0 | 0 | 0.1% |
| `factoid:withheld` | 1 | 0 | 1 | 0 | 0.1% |
| `weight:m_g` | 1 | 1 | 0 | 0 | 0.1% |
| **total** | 924 | 554 | 266 | 104 | 100% |

**Code organ: 0 of 924 core questions reach it** (no route or pipeline step starts with `code` or `organ:code`). A lift of the code organ cannot change any number on this panel; it can only matter on exams that ask code questions.

### What each landed family takes of the core panel

From `var/<family>/parity/*.lane.jsonl` (heldout, else dev): a core question counts when any of the family's specialists replied to it (`provenance.taken`, else a non-empty path), the same reading the harness uses. *Counted by the lane rule* keeps only the questions where the head withheld for lack of a reading, which are the ones `exam.py` charges against the cap of 9. A family with no lane run was scored without `--lane-answerer`, so its reach is not recorded.

| Family | Specialists with a lane run | Core items its binary takes | Of those, counted by the lane rule | Routes taken |
|---|---|---|---|---|
| acoustics | 1 | 0 | 0 | - |
| anatomyagri | 0 | no lane run recorded | - | - |
| chemistry | 0 | no lane run recorded | - | - |
| climate | 0 | no lane run recorded | - | - |
| computing | 0 | no lane run recorded | - | - |
| discrete | 0 | no lane run recorded | - | - |
| emoptics | 0 | no lane run recorded | - | - |
| energy | 0 | no lane run recorded | - | - |
| facts | 22 | 28 | 9 | `organ:relation` 9, `unverified:*` 8, `precision_guard:*` 7, `specialist_call` 3, `family_precedence` 1 |
| geostats | 0 | no lane run recorded | - | - |
| humanities | 0 | no lane run recorded | - | - |
| life | 0 | no lane run recorded | - | - |
| materials | 0 | no lane run recorded | - | - |
| mechanics | 9 | 55 | 0 | `network` 18, `specialist_call` 18, `precision_guard:*` 12, `network3` 6, `weight:m_g` 1 |
| quantity | 6 | 109 | 6 | `specialist_call` 61, `precision_guard:*` 19, `organ:math` 12, `network3` 6, `network` 6, `op:*` 5 |
| space | 0 | no lane run recorded | - | - |
| stores | 0 | no lane run recorded | - | - |
| trades | 0 | no lane run recorded | - | - |
| variants | 0 | no lane run recorded | - | - |
