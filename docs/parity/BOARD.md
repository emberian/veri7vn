# Parity board

**Full board: Oracle7 + specialist, release composition, shipped head, in plain words.** 304 specialists were run on their held-out exams; 290 of them have a shipped verdict to compare with. Of the 129 that are not relation readers, **129 got exactly the shipped number of right answers and false yeses**. Together they score 6354 right / 17 false yes / 161 wrong, against 6354 / 17 shipped. The shipped files record a wrong count for 79 of these 129; on those, 5 wrong here against 5 shipped. The 161 relation readers (`rel-*`) could not run on this installation: they score 1796 right / 0 false yes, against 9124 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 15478 right / 14 wrong, splits into 6354 right / 5 wrong for the other specialists (wrong recorded for 79 of 129) and 9124 right / 9 wrong for the relation readers (wrong recorded for 161 of 161). **Reproduced here, without the relation readers: 6354 right / 161 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 50 of them). 14 specialists have no shipped verdict to compare with (anatomy-r2, astronomy-v3-r2, cooking-v3-r2, densities-r2, finance-v2-r2, fluids-r2, greenhouse-r2, labsolutions-r2, medicine-r2, music-v2-r2, optics-v5-r2, physics-r3, soil-r2, units-v3-r2). On 4 questions in rel-museums, rel-philosophers, rel-photographers the answerer process stopped without a message and was restarted; those questions count as declined.

**Control A: Oracle7 + specialist, release composition, shipped head, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **5 got exactly the shipped number of right answers and false yeses**. Together they score 495 right / 0 false yes / 2 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 495 right / 2 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

**Control B: Oracle7 + specialist, exam.py composition, shipped head, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **0 got exactly the shipped number of right answers and false yeses** and 5 did not (acoustics: 57 right / 1 false yes, shipped 69 / 0; cooking-v3: 212 right / 0 false yes, shipped 224 / 0; densities: 50 right / 0 false yes, shipped 51 / 0; units-v3: 48 right / 0 false yes, shipped 75 / 0; units: 43 right / 0 false yes, shipped 76 / 0). Together they score 410 right / 1 false yes / 79 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 410 right / 79 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

**Control C: Oracle7 + specialist, exam.py composition, current head w540, in plain words.** 6 specialists were run on their held-out exams; 6 of them have a shipped verdict to compare with. Of the 5 that are not relation readers, **1 got exactly the shipped number of right answers and false yeses** and 4 did not (acoustics: 62 right / 2 false yes, shipped 69 / 0; cooking-v3: 212 right / 0 false yes, shipped 224 / 0; units-v3: 48 right / 0 false yes, shipped 75 / 0; units: 47 right / 0 false yes, shipped 76 / 0). Together they score 420 right / 2 false yes / 68 wrong, against 495 / 0 shipped. The shipped files record a wrong count for 1 of these 5; on those, 0 wrong here against 0 shipped. The 1 relation readers (`rel-*`) could not run on this installation: they score 20 right / 0 false yes, against 96 / 0 shipped, and 0 of them match. They need `root/relstore/names_v1.sqlite3` and `root/relstore/relations_v2.sqlite3`, which the release does not include, so each one stays silent and only the core answers. The release's published total over these exams, 591 right / 0 wrong, splits into 495 right / 0 wrong for the other specialists (wrong recorded for 1 of 5) and 96 right / 0 wrong for the relation readers (wrong recorded for 1 of 1). **Reproduced here, without the relation readers: 420 right / 68 wrong** (this run counts wrong for every specialist; the shipped files leave it out for 4 of them).

**Relation readers on the reconstructed linker index, release composition, shipped head, in plain words.** 161 specialists were run on their held-out exams; 161 of them have a shipped verdict to compare with. The 161 relation readers (`rel-*`) ran on a reconstructed linker index (see below): they score 8313 right / 0 false yes, against 9124 / 0 shipped, and 55 of them match.

**These relation readers ran on a RECONSTRUCTED linker index, not the one the release used.** The release did not ship `root/relstore/names_v1.sqlite3`, the table the 161 `rel-*` readers use to find which entity a name in a question means. `tools/linker/build_names.py` and `tools/linker/make_overlay.py` rebuild one from the shipped `relations_v1.sqlite3` (12,059,027 rows, built 2026-10-17; its provenance is in its `meta` table: labels from the store's own entities, aliases only from article-title variants because no real Wikidata aliases ship, and a degree-based stand-in for the "links" fame score). The readers were run with `ORACLE7_ROOT=var/linker/o7root`, which is the shipped root plus that index. So the numbers below measure the readers on a stand-in index and the shipped fact store `relations_v1`, never on the original two stores. **A silence that comes from a property with no rows in `relations_v1` is a gap in the store, not a reader failure.** 30 properties have no rows at all; across both splits they cost 1,814 of 18,976 relation exam items, 903 of them on the held-out split this run uses (903 of 9,510, 9.5%). No reader over the shipped store can answer those. Every number in this run is a held-out count by the specialist's own scorer. Read the run's row against the shipped 9,124 right / 9 wrong with that in mind.

**This is the release composition with the verified organs in front of the w540 head, not the shipped-head composition of the other runs.** Each of the 125 rows is one generated veri7vn organ folder from the W5-10 package (`<id>-veri7vn`, answered by the family's proved program) placed in front of the current Oracle7 head (w540): the organ takes the question if it recognises it, and the head answers only what the organ leaves alone. Both splits, over the organ's own copy of the shipped panel and marking script. Because these folders are new, they have no shipped verdict: the "shipped" columns are empty and the head-alone column is w540's own, which already contains the standing specialists, so it is not the head each original was admitted against. Read each row against the organ's own family-lane numbers (organ alone) in `project/lanes/`: where the two differ it is because the organ declined a question and the head then answered it, never because the organ answered differently (see `project/lanes/W5-11-front-board.md`). LANE, SELF and BUDGET are measured with the organ alone.

Generated by `tools/parity/board.py` on 2026-10-18 03:54 UTC from the run directories named below. Counts are **right / false yes / wrong** in the sense of `upstream/workbench/exam.py`: *right* is the specialist's own scorer saying good (a correct decline of a must-decline item counts as right), *false yes* is an answer to a must-decline item, *wrong* is an answer to a valid item that the scorer rejects. See [README](README.md) for the columns and the control.

## Summary

| Run | Answerer | Head | Specialists | Items | Answerer right / false yes / wrong | Head alone | Shipped composed (same specialists) | Same right and false yes as shipped | Decisions |
|---|---|---|---|---|---|---|---|---|---|
| Full board: Oracle7 + specialist, release composition, shipped head | `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}` | w363, w399, w406, w502, w503, w524, w525, w526, w540 | 304 | 17436 | 9101 / 28 / 497 | 2991 / 93 / 1914 | 15478 / 17 / - on 16454 items | 129 of 290 | ADMIT 128, INCOMPLETE 1, NEGATIVE 175, NO PANEL 1 |
| Control A: Oracle7 + specialist, release composition, shipped head | `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}` | w363, w524, w525 | 6 | 595 | 515 / 0 / 8 | 45 / 1 / 83 | 591 / 0 / - on 595 items | 5 of 6 | ADMIT 5, NEGATIVE 1 |
| Control B: Oracle7 + specialist, exam.py composition, shipped head | `tools/parity/answerers/oracle7.py --tip {shipped_head} --specialist {dir}` | w363, w524, w525 | 6 | 595 | 430 / 1 / 85 | 45 / 1 / 83 | 591 / 0 / - on 595 items | 0 of 6 | ADMIT 1, NEGATIVE 5 |
| Control C: Oracle7 + specialist, exam.py composition, current head w540 | `tools/parity/answerers/oracle7.py --specialist {dir}` | w540 | 6 | 595 | 440 / 2 / 73 | 435 / 2 / 73 | 591 / 0 / - on 595 items | 1 of 6 | NEGATIVE 6 |
| veri7vn packaged, acoustics sample | `tools/parity/answerers/veri7vn_packaged.py deployment-ui-d44-standalone-aae0d7dd/generations/2fd159a8...` | - | 1 | 3 (first 3 items each) | 0 / 0 / 0 | - | - | - | INCOMPLETE 1 |
| Relation readers on the reconstructed linker index, release composition, shipped head | `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}` | w399, w406, w524, w525 | 161 | 9510 | 8313 / 0 / 16 | 3052 / 0 / 356 | 9124 / 0 / 9 on 9510 items | 55 of 161 | INCOMPLETE 149, NEGATIVE 12 |
| veri7vn organs in front of the w540 head (W5-11) | `tools/parity/answerers/oracle7.py --compose front --specialist {dir}` | w540 | 250 | 12247 | 11844 / 14 / 71 | 8770 / 64 / 1570 | - | - | ADMIT 73, NEGATIVE 52, WOULD FAIL 28, WOULD PASS 97 |

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

## Relation readers on the reconstructed linker index, release composition, shipped head

Run directory `var/parity/rel-linker-board`; command `tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}`.

**These relation readers ran on a RECONSTRUCTED linker index, not the one the release used.** The release did not ship `root/relstore/names_v1.sqlite3`, the table the 161 `rel-*` readers use to find which entity a name in a question means. `tools/linker/build_names.py` and `tools/linker/make_overlay.py` rebuild one from the shipped `relations_v1.sqlite3` (12,059,027 rows, built 2026-10-17; its provenance is in its `meta` table: labels from the store's own entities, aliases only from article-title variants because no real Wikidata aliases ship, and a degree-based stand-in for the "links" fame score). The readers were run with `ORACLE7_ROOT=var/linker/o7root`, which is the shipped root plus that index. So the numbers below measure the readers on a stand-in index and the shipped fact store `relations_v1`, never on the original two stores. **A silence that comes from a property with no rows in `relations_v1` is a gap in the store, not a reader failure.** 30 properties have no rows at all; across both splits they cost 1,814 of 18,976 relation exam items, 903 of them on the held-out split this run uses (903 of 9,510, 9.5%). No reader over the shipped store can answer those. Every number in this run is a held-out count by the specialist's own scorer. Read the run's row against the shipped 9,124 right / 9 wrong with that in mind.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rel-actors | 96 | 0 | 24 / 0 / 6 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 24 / 0 / 6 | 96 / 0 / 0 (96) | +0 |
| rel-aircraft | 24 | 0 | 0 / 0 / 1 | 6 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 0 / 0 / 1 | 18 / 0 / 0 (24) | -12 |
| rel-airlines | 48 | 0 | 17 / 0 / 14 | 45 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 17 / 0 / 14 | 43 / 0 / 0 (48) | +2 |
| rel-airports | 24 | 0 | 9 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 9 / 0 / 0 | 20 / 0 / 0 (24) | -8 |
| rel-albums | 36 | 0 | 13 / 0 / 1 | 20 / 0 / 5 | - | - | - | NEGATIVE: WRONG: 5 answered wrong, cap 1 | w524 | 13 / 0 / 1 | 24 / 0 / 1 (36) | -4 |
| rel-animators | 74 | 0 | 67 / 0 / 2 | 74 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 68 / 0 / 2 | 74 / 0 / 0 (74) | +0 |
| rel-anime | 23 | 0 | 1 / 0 / 0 | 23 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 1 / 0 / 0 | 23 / 0 / 0 (23) | +0 |
| rel-architects | 93 | 0 | 19 / 0 / 0 | 92 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 19 / 0 / 0 | 93 / 0 / 0 (93) | -1 |
| rel-asteroids | 24 | 0 | 2 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 2 / 0 / 0 | 24 / 0 / 0 (24) | -12 |
| rel-astronauts | 96 | 0 | 25 / 0 / 5 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 25 / 0 / 5 | 96 / 0 / 0 (96) | +0 |
| rel-astronomers | 96 | 0 | 17 / 0 / 3 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 17 / 0 / 3 | 94 / 0 / 0 (96) | -1 |
| rel-athletes | 108 | 0 | 19 / 0 / 2 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 19 / 0 / 2 | 105 / 0 / 0 (108) | -12 |
| rel-awards | 12 | 0 | 0 / 0 / 0 | 10 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 0 / 0 / 0 | 10 / 0 / 0 (12) | +0 |
| rel-ballets | 11 | 0 | 4 / 0 / 1 | 10 / 0 / 0 | - | - | - | INCOMPLETE | w524 | 4 / 0 / 1 | 11 / 0 / 0 (11) | -1 |
| rel-bands | 24 | 0 | 8 / 0 / 8 | 23 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 8 / 0 / 8 | 22 / 0 / 0 (24) | +1 |
| rel-baseball | 45 | 0 | 12 / 0 / 2 | 43 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 2 | 45 / 0 / 0 (45) | -2 |
| rel-basketball | 107 | 0 | 29 / 0 / 1 | 94 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 29 / 0 / 1 | 105 / 0 / 0 (107) | -11 |
| rel-battles | 23 | 0 | 15 / 0 / 0 | 19 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 15 / 0 / 0 | 21 / 0 / 0 (23) | -2 |
| rel-biathletes | 56 | 0 | 14 / 0 / 1 | 43 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 14 / 0 / 2 | 56 / 0 / 0 (56) | -13 |
| rel-biologists | 96 | 0 | 15 / 0 / 3 | 92 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 15 / 0 / 3 | 92 / 0 / 0 (96) | +0 |
| rel-bloggers | 74 | 0 | 67 / 0 / 0 | 73 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 66 / 0 / 0 | 72 / 0 / 0 (74) | +1 |
| rel-boxers | 96 | 0 | 26 / 0 / 1 | 93 / 0 / 1 | - | - | - | INCOMPLETE | w525 | 26 / 0 / 1 | 93 / 0 / 1 (96) | +0 |
| rel-brands | 48 | 0 | 28 / 0 / 6 | 45 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 27 / 0 / 6 | 44 / 0 / 0 (48) | +1 |
| rel-breeds | 12 | 0 | 5 / 0 / 3 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 5 / 0 / 3 | 12 / 0 / 0 (12) | +0 |
| rel-bridges | 44 | 0 | 9 / 0 / 2 | 18 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 9 / 0 / 2 | 39 / 0 / 0 (44) | -21 |
| rel-business | 96 | 0 | 27 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 27 / 0 / 1 | 95 / 0 / 0 (96) | +1 |
| rel-carbrands | 35 | 0 | 8 / 0 / 8 | 33 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 8 / 0 / 8 | 29 / 0 / 0 (35) | +4 |
| rel-carmodels | 12 | 0 | 0 / 0 / 0 | 8 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 0 / 0 / 0 | 8 / 0 / 0 (12) | +0 |
| rel-castles | 24 | 0 | 7 / 0 / 1 | 24 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 7 / 0 / 1 | 24 / 0 / 0 (24) | +0 |
| rel-channels | 39 | 0 | 16 / 0 / 4 | 32 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 16 / 0 / 4 | 32 / 0 / 0 (39) | +0 |
| rel-characters | 24 | 0 | 1 / 0 / 1 | 11 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 1 / 0 / 1 | 19 / 0 / 0 (24) | -8 |
| rel-chefs | 15 | 0 | 6 / 0 / 0 | 15 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 6 / 0 / 0 | 15 / 0 / 0 (15) | +0 |
| rel-chemists | 96 | 0 | 17 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 18 / 0 / 1 | 96 / 0 / 0 (96) | +0 |
| rel-chess | 100 | 0 | 15 / 0 / 1 | 86 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 15 / 0 / 1 | 98 / 0 / 0 (100) | -12 |
| rel-churches | 17 | 0 | 4 / 0 / 1 | 15 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 4 / 0 / 1 | 15 / 0 / 1 (17) | +0 |
| rel-comedians | 96 | 0 | 26 / 0 / 3 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 27 / 0 / 3 | 96 / 0 / 0 (96) | +0 |
| rel-comics | 35 | 0 | 13 / 0 / 1 | 33 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 13 / 0 / 1 | 32 / 0 / 0 (35) | +1 |
| rel-companies | 60 | 0 | 19 / 0 / 8 | 54 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 19 / 0 / 8 | 52 / 0 / 0 (60) | +2 |
| rel-composers | 108 | 0 | 29 / 0 / 3 | 108 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 29 / 0 / 3 | 107 / 0 / 0 (108) | +1 |
| rel-compounds | 23 | 0 | 1 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 1 / 0 / 0 | 22 / 0 / 0 (23) | -10 |
| rel-computerscientists | 92 | 0 | 83 / 0 / 2 | 92 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 83 / 0 / 3 | 92 / 0 / 0 (92) | +0 |
| rel-countries-v2 | 84 | 0 | 16 / 0 / 6 | 60 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 16 / 0 / 6 | 72 / 0 / 0 (84) | -12 |
| rel-cricketers | 63 | 0 | 18 / 0 / 0 | 50 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 18 / 0 / 0 | 62 / 0 / 0 (63) | -12 |
| rel-criminals | 60 | 0 | 9 / 0 / 1 | 60 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 9 / 0 / 1 | 60 / 0 / 0 (60) | +0 |
| rel-crosscountry | 70 | 0 | 18 / 0 / 0 | 58 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 21 / 0 / 1 | 70 / 0 / 0 (70) | -12 |
| rel-curlers | 24 | 0 | 4 / 0 / 5 | 15 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 5 / 0 / 4 | 24 / 0 / 0 (24) | -9 |
| rel-cyclists | 107 | 0 | 26 / 0 / 0 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 26 / 0 / 0 | 105 / 0 / 0 (107) | -12 |
| rel-dancers | 96 | 0 | 22 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 22 / 0 / 1 | 96 / 0 / 0 (96) | +0 |
| rel-diplomats | 96 | 0 | 20 / 0 / 4 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 20 / 0 / 4 | 92 / 0 / 0 (96) | +1 |
| rel-directors | 96 | 0 | 24 / 0 / 2 | 95 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 24 / 0 / 2 | 94 / 0 / 0 (96) | +1 |
| rel-diseases | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 12 / 0 / 0 (12) | -12 |
| rel-dishes | 12 | 0 | 1 / 0 / 6 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 1 / 0 / 6 | 12 / 0 / 0 (12) | +0 |
| rel-drivers | 100 | 0 | 20 / 0 / 2 | 87 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 20 / 0 / 2 | 100 / 0 / 0 (100) | -13 |
| rel-economists | 96 | 0 | 20 / 0 / 1 | 95 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 20 / 0 / 1 | 94 / 0 / 0 (96) | +1 |
| rel-editors | 84 | 0 | 77 / 0 / 1 | 82 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 76 / 0 / 1 | 82 / 0 / 0 (84) | +0 |
| rel-engineers | 96 | 0 | 12 / 0 / 3 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 3 | 95 / 0 / 0 (96) | -2 |
| rel-equestrians | 33 | 0 | 25 / 0 / 0 | 28 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 27 / 0 / 0 | 33 / 0 / 0 (33) | -5 |
| rel-explorers | 87 | 0 | 12 / 0 / 1 | 86 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 1 | 85 / 0 / 0 (87) | +1 |
| rel-fencers | 94 | 0 | 29 / 0 / 2 | 81 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 31 / 0 / 2 | 93 / 0 / 0 (94) | -12 |
| rel-fieldhockey | 29 | 0 | 9 / 0 / 3 | 17 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 10 / 0 / 3 | 29 / 0 / 0 (29) | -12 |
| rel-films-v2 | 84 | 0 | 10 / 0 / 7 | 52 / 0 / 1 | - | - | - | INCOMPLETE | w399 | 10 / 0 / 6 | 52 / 0 / 0 (84) | +0 |
| rel-footballclubs | 36 | 0 | 5 / 0 / 1 | 24 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 5 / 0 / 1 | 36 / 0 / 0 (36) | -12 |
| rel-footballers | 120 | 0 | 24 / 0 / 0 | 92 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 24 / 0 / 0 | 117 / 0 / 0 (120) | -25 |
| rel-galaxies | 36 | 0 | 19 / 0 / 2 | 12 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain -7, needs 3 | w406 | 25 / 0 / 2 | 36 / 0 / 0 (36) | -24 |
| rel-genres | 12 | 0 | 1 / 0 / 5 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 1 / 0 / 5 | 12 / 0 / 0 (12) | +0 |
| rel-geologists | 92 | 0 | 81 / 0 / 2 | 92 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 82 / 0 / 2 | 92 / 0 / 0 (92) | +0 |
| rel-golfers | 38 | 0 | 6 / 0 / 1 | 25 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 6 / 0 / 1 | 37 / 0 / 0 (38) | -12 |
| rel-graphicartists | 96 | 0 | 86 / 0 / 3 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 85 / 0 / 3 | 95 / 0 / 0 (96) | +1 |
| rel-gridiron | 34 | 0 | 21 / 0 / 1 | 27 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 22 / 0 / 2 | 33 / 0 / 0 (34) | -6 |
| rel-gymnasts | 77 | 0 | 23 / 0 / 0 | 65 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 26 / 0 / 0 | 77 / 0 / 0 (77) | -12 |
| rel-handball | 79 | 0 | 23 / 0 / 2 | 65 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 27 / 0 / 3 | 77 / 0 / 0 (79) | -12 |
| rel-historians | 96 | 0 | 19 / 0 / 5 | 95 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 19 / 0 / 5 | 94 / 0 / 0 (96) | +1 |
| rel-hotels | 24 | 0 | 6 / 0 / 1 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 10 / 0 / 1 | 21 / 0 / 0 (24) | -9 |
| rel-icehockey | 101 | 0 | 31 / 0 / 1 | 88 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 31 / 0 / 1 | 98 / 0 / 0 (101) | -10 |
| rel-illustrators | 96 | 0 | 86 / 0 / 4 | 95 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 83 / 0 / 4 | 91 / 0 / 0 (96) | +4 |
| rel-instruments | 19 | 0 | 2 / 0 / 5 | 19 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 2 / 0 / 5 | 19 / 0 / 0 (19) | +0 |
| rel-islands | 36 | 0 | 15 / 0 / 0 | 19 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 15 / 0 / 0 | 30 / 0 / 0 (36) | -11 |
| rel-journalists | 96 | 0 | 12 / 0 / 4 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 4 | 96 / 0 / 0 (96) | +0 |
| rel-lakes | 12 | 0 | 8 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 8 / 0 / 0 | 12 / 0 / 0 (12) | +0 |
| rel-languages | 12 | 0 | 0 / 0 / 0 | 0 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain 0, needs 3 | w525 | 0 / 0 / 0 | 11 / 0 / 0 (12) | -11 |
| rel-lawyers | 96 | 0 | 14 / 0 / 0 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 14 / 0 / 0 | 95 / 0 / 0 (96) | -2 |
| rel-leagues | 21 | 0 | 11 / 0 / 4 | 17 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 10 / 0 / 4 | 16 / 0 / 0 (21) | +1 |
| rel-libraries | 22 | 0 | 14 / 0 / 0 | 21 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 14 / 0 / 0 | 21 / 0 / 0 (22) | +0 |
| rel-linguists | 96 | 0 | 13 / 0 / 2 | 94 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 13 / 0 / 2 | 94 / 0 / 0 (96) | +0 |
| rel-mathematicians | 96 | 0 | 14 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 14 / 0 / 1 | 96 / 0 / 0 (96) | +0 |
| rel-military | 96 | 0 | 19 / 0 / 2 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 19 / 0 / 2 | 93 / 0 / 0 (96) | +0 |
| rel-militaryunits | 17 | 0 | 6 / 0 / 1 | 15 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 6 / 0 / 1 | 15 / 0 / 0 (17) | +0 |
| rel-missionaries | 73 | 0 | 48 / 0 / 1 | 73 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 48 / 0 / 1 | 73 / 0 / 0 (73) | +0 |
| rel-models | 96 | 0 | 25 / 0 / 5 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 25 / 0 / 5 | 95 / 0 / 0 (96) | +1 |
| rel-monarchs | 144 | 0 | 13 / 0 / 5 | 86 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 13 / 0 / 5 | 121 / 0 / 0 (144) | -35 |
| rel-monuments | 29 | 0 | 13 / 0 / 1 | 27 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 13 / 0 / 1 | 26 / 0 / 0 (29) | +1 |
| rel-moons | 36 | 0 | 9 / 0 / 1 | 11 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain 2, needs 3 | w525 | 9 / 0 / 1 | 36 / 0 / 0 (36) | -25 |
| rel-mountains | 24 | 0 | 12 / 0 / 2 | 10 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain -2, needs 3 | w525 | 12 / 0 / 2 | 20 / 0 / 0 (24) | -10 |
| rel-museums | 34 | 0 | 11 / 0 / 1 | 32 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 11 / 0 / 1 | 32 / 0 / 0 (34) | +0 |
| rel-musicians | 120 | 0 | 21 / 0 / 2 | 119 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 21 / 0 / 2 | 119 / 0 / 0 (120) | +0 |
| rel-mythology | 36 | 0 | 1 / 0 / 0 | 29 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 1 / 0 / 0 | 29 / 0 / 1 (36) | +0 |
| rel-newspapers | 48 | 0 | 13 / 0 / 9 | 33 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 13 / 0 / 9 | 40 / 0 / 0 (48) | -7 |
| rel-novelists | 96 | 0 | 18 / 0 / 2 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 18 / 0 / 2 | 96 / 0 / 0 (96) | +0 |
| rel-novels | 60 | 0 | 10 / 0 / 6 | 42 / 0 / 1 | - | - | - | INCOMPLETE | w524 | 10 / 0 / 6 | 50 / 0 / 0 (60) | -8 |
| rel-nurses | 61 | 0 | 43 / 0 / 2 | 61 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 42 / 0 / 3 | 61 / 0 / 0 (61) | +0 |
| rel-observatories | 16 | 0 | 6 / 0 / 1 | 15 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 6 / 0 / 1 | 15 / 0 / 0 (16) | +0 |
| rel-operas | 24 | 0 | 11 / 0 / 3 | 11 / 0 / 1 | - | - | - | NEGATIVE: DOMAIN: gain 0, needs 3 | w524 | 11 / 0 / 3 | 23 / 0 / 1 (24) | -12 |
| rel-organisations | 36 | 0 | 12 / 0 / 9 | 31 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 9 | 32 / 0 / 0 (36) | -1 |
| rel-painters | 96 | 0 | 18 / 0 / 2 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 18 / 0 / 2 | 96 / 0 / 0 (96) | +0 |
| rel-paintings | 24 | 0 | 4 / 0 / 0 | 6 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain 2, needs 3 | w524 | 4 / 0 / 0 | 17 / 0 / 0 (24) | -11 |
| rel-parks | 12 | 0 | 4 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 4 / 0 / 0 | 12 / 0 / 0 (12) | +0 |
| rel-parties | 31 | 0 | 5 / 0 / 11 | 26 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 5 / 0 / 11 | 26 / 0 / 0 (31) | +0 |
| rel-pharmacists | 59 | 0 | 52 / 0 / 0 | 59 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 53 / 0 / 0 | 59 / 0 / 0 (59) | +0 |
| rel-philosophers | 96 | 0 | 14 / 0 / 4 | 83 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 14 / 0 / 4 | 83 / 0 / 0 (96) | +0 |
| rel-photographers | 96 | 0 | 21 / 0 / 4 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 21 / 0 / 4 | 94 / 0 / 0 (96) | +2 |
| rel-physicians | 96 | 0 | 12 / 0 / 1 | 93 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 1 | 94 / 0 / 0 (96) | -1 |
| rel-physicists | 96 | 0 | 15 / 0 / 4 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 15 / 0 / 4 | 95 / 0 / 0 (96) | +1 |
| rel-planets | 24 | 0 | 2 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 2 / 0 / 0 | 24 / 0 / 0 (24) | -12 |
| rel-playwrights | 96 | 0 | 19 / 0 / 5 | 95 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 20 / 0 / 5 | 95 / 0 / 0 (96) | +0 |
| rel-poems | 12 | 0 | 4 / 0 / 1 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w524 | 4 / 0 / 1 | 12 / 0 / 0 (12) | +0 |
| rel-poets | 96 | 0 | 14 / 0 / 2 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 14 / 0 / 2 | 96 / 0 / 0 (96) | +0 |
| rel-police | 44 | 0 | 35 / 0 / 1 | 43 / 0 / 1 | - | - | - | INCOMPLETE | w406 | 37 / 0 / 1 | 43 / 0 / 1 (44) | +0 |
| rel-politicians | 108 | 0 | 22 / 0 / 0 | 91 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 22 / 0 / 0 | 104 / 0 / 0 (108) | -13 |
| rel-printmakers | 88 | 0 | 81 / 0 / 4 | 87 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 81 / 0 / 3 | 87 / 0 / 0 (88) | +0 |
| rel-psychologists | 84 | 0 | 22 / 0 / 1 | 83 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 22 / 0 / 1 | 83 / 0 / 0 (84) | +0 |
| rel-racketsports | 58 | 0 | 16 / 0 / 0 | 46 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 17 / 0 / 0 | 58 / 0 / 0 (58) | -12 |
| rel-religions | 21 | 0 | 4 / 0 / 12 | 21 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 4 / 0 / 12 | 21 / 0 / 0 (21) | +0 |
| rel-rivers | 24 | 0 | 2 / 0 / 3 | 0 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain -2, needs 3 | w525 | 2 / 0 / 3 | 20 / 0 / 0 (24) | -20 |
| rel-rowers | 104 | 0 | 26 / 0 / 5 | 90 / 0 / 1 | - | - | - | INCOMPLETE | w406 | 26 / 0 / 7 | 103 / 0 / 0 (104) | -13 |
| rel-rugby | 42 | 0 | 7 / 0 / 0 | 32 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 7 / 0 / 0 | 42 / 0 / 0 (42) | -10 |
| rel-sculptors | 90 | 0 | 16 / 0 / 1 | 89 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 16 / 0 / 1 | 89 / 0 / 0 (90) | +0 |
| rel-sculptures | 24 | 0 | 4 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w524 | 4 / 0 / 0 | 24 / 0 / 0 (24) | -12 |
| rel-ships | 12 | 0 | 0 / 0 / 0 | 9 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 0 / 0 / 0 | 10 / 0 / 0 (12) | -1 |
| rel-shooters | 45 | 0 | 10 / 0 / 2 | 32 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 13 / 0 / 2 | 44 / 0 / 0 (45) | -12 |
| rel-singers | 120 | 0 | 27 / 0 / 0 | 117 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 26 / 0 / 0 | 116 / 0 / 0 (120) | +1 |
| rel-skaters | 78 | 0 | 28 / 0 / 2 | 66 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 28 / 0 / 1 | 78 / 0 / 0 (78) | -12 |
| rel-skiers | 91 | 0 | 34 / 0 / 1 | 76 / 0 / 1 | - | - | - | INCOMPLETE | w406 | 33 / 0 / 2 | 89 / 0 / 0 (91) | -13 |
| rel-skyscrapers | 36 | 0 | 5 / 0 / 1 | 21 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 5 / 0 / 1 | 31 / 0 / 0 (36) | -10 |
| rel-snooker | 17 | 0 | 1 / 0 / 0 | 5 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 1 / 0 / 2 | 17 / 0 / 0 (17) | -12 |
| rel-software | 36 | 0 | 6 / 0 / 0 | 22 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 6 / 0 / 0 | 31 / 0 / 0 (36) | -9 |
| rel-songs | 48 | 0 | 9 / 0 / 2 | 34 / 0 / 3 | - | - | - | NEGATIVE: WRONG: 3 answered wrong, cap 1 | w524 | 9 / 0 / 2 | 37 / 0 / 1 (48) | -3 |
| rel-spacecraft | 12 | 0 | 0 / 0 / 0 | 9 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 0 / 0 / 0 | 8 / 0 / 1 (12) | +1 |
| rel-speedskaters | 74 | 0 | 25 / 0 / 2 | 62 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 26 / 0 / 1 | 74 / 0 / 0 (74) | -12 |
| rel-spies | 60 | 0 | 46 / 0 / 2 | 59 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 48 / 0 / 2 | 59 / 0 / 0 (60) | +0 |
| rel-sportsevents | 36 | 0 | 5 / 0 / 0 | 24 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 5 / 0 / 0 | 36 / 0 / 0 (36) | -12 |
| rel-sportsteams | 36 | 0 | 7 / 0 / 0 | 24 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 7 / 0 / 0 | 36 / 0 / 0 (36) | -12 |
| rel-stadiums | 36 | 0 | 12 / 0 / 0 | 23 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 12 / 0 / 0 | 33 / 0 / 0 (36) | -10 |
| rel-stations | 24 | 0 | 3 / 0 / 3 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 3 / 0 / 3 | 23 / 0 / 0 (24) | -11 |
| rel-statisticians | 58 | 0 | 50 / 0 / 4 | 57 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 51 / 0 / 3 | 57 / 0 / 0 (58) | +0 |
| rel-swimmers | 108 | 0 | 24 / 0 / 2 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 23 / 0 / 2 | 108 / 0 / 0 (108) | -12 |
| rel-temples | 36 | 0 | 22 / 0 / 1 | 34 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 22 / 0 / 2 | 34 / 0 / 0 (36) | +0 |
| rel-tennis | 108 | 0 | 23 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 23 / 0 / 1 | 108 / 0 / 0 (108) | -12 |
| rel-theatres | 25 | 0 | 7 / 0 / 0 | 12 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 7 / 0 / 0 | 23 / 0 / 0 (25) | -11 |
| rel-themeparks | 12 | 0 | 6 / 0 / 2 | 0 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain -6, needs 3 | w406 | 6 / 0 / 2 | 12 / 0 / 0 (12) | -12 |
| rel-theologians | 100 | 0 | 16 / 0 / 3 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 16 / 0 / 3 | 100 / 0 / 0 (100) | -4 |
| rel-tradeunionists | 75 | 0 | 68 / 0 / 1 | 75 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 72 / 0 / 1 | 75 / 0 / 0 (75) | +0 |
| rel-translators | 96 | 0 | 79 / 0 / 2 | 94 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 79 / 0 / 2 | 95 / 0 / 0 (96) | -1 |
| rel-triathletes | 12 | 0 | 2 / 0 / 0 | 5 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 8 / 0 / 0 | 12 / 0 / 0 (12) | -7 |
| rel-tvproducers | 96 | 0 | 89 / 0 / 1 | 96 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 89 / 0 / 1 | 95 / 0 / 0 (96) | +1 |
| rel-tvseries-v2 | 72 | 0 | 3 / 0 / 6 | 33 / 0 / 1 | - | - | - | INCOMPLETE | w399 | 3 / 0 / 6 | 52 / 0 / 1 (72) | -19 |
| rel-universities | 36 | 0 | 13 / 0 / 10 | 36 / 0 / 0 | - | - | - | INCOMPLETE | w525 | 13 / 0 / 10 | 35 / 0 / 0 (36) | +1 |
| rel-videogames | 36 | 0 | 9 / 0 / 3 | 29 / 0 / 0 | - | - | - | INCOMPLETE | w524 | 9 / 0 / 3 | 31 / 0 / 0 (36) | -2 |
| rel-volleyball | 58 | 0 | 16 / 0 / 1 | 46 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 17 / 0 / 3 | 58 / 0 / 0 (58) | -12 |
| rel-wars | 24 | 0 | 2 / 0 / 1 | 0 / 0 / 0 | - | - | - | NEGATIVE: DOMAIN: gain -2, needs 3 | w525 | 2 / 0 / 1 | 22 / 0 / 0 (24) | -22 |
| rel-waterpolo | 46 | 0 | 20 / 0 / 2 | 34 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 28 / 0 / 2 | 46 / 0 / 0 (46) | -12 |
| rel-youtubers | 56 | 0 | 52 / 0 / 1 | 55 / 0 / 0 | - | - | - | INCOMPLETE | w406 | 51 / 0 / 1 | 54 / 0 / 0 (56) | +1 |

## veri7vn organs in front of the w540 head (W5-11)

Run directory `var/w511/front`; command `tools/parity/answerers/oracle7.py --compose front --specialist {dir}`.

**This is the release composition with the verified organs in front of the w540 head, not the shipped-head composition of the other runs.** Each of the 125 rows is one generated veri7vn organ folder from the W5-10 package (`<id>-veri7vn`, answered by the family's proved program) placed in front of the current Oracle7 head (w540): the organ takes the question if it recognises it, and the head answers only what the organ leaves alone. Both splits, over the organ's own copy of the shipped panel and marking script. Because these folders are new, they have no shipped verdict: the "shipped" columns are empty and the head-alone column is w540's own, which already contains the standing specialists, so it is not the head each original was admitted against. Read each row against the organ's own family-lane numbers (organ alone) in `project/lanes/`: where the two differ it is because the organ declined a question and the head then answered it, never because the organ answered differently (see `project/lanes/W5-11-front-board.md`). LANE, SELF and BUDGET are measured with the organ alone.

| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acoustics-veri7vn | 70 | 0 | 46 / 0 / 0 | 70 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| acoustics-veri7vn | 69 | 0 | 62 / 2 / 0 | 68 / 1 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| additive-v2-veri7vn | 32 | 0 | 31 / 0 / 0 | 32 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| additive-v2-veri7vn | 20 | 0 | 20 / 0 / 0 | 20 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| agriculture-v2-veri7vn | 17 | 0 | 15 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| agriculture-v2-veri7vn | 17 | 0 | 13 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| airquality-veri7vn | 38 | 0 | 14 / 1 / 4 | 38 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| airquality-veri7vn | 38 | 0 | 16 / 1 / 9 | 30 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| algorithms-veri7vn | 42 | 0 | 21 / 0 / 16 | 42 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| algorithms-veri7vn | 42 | 0 | 5 / 1 / 32 | 42 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| anatomy-r2-veri7vn | 11 | 0 | 6 / 0 / 1 | 11 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| anatomy-r2-veri7vn | 11 | 0 | 7 / 1 / 0 | 9 / 1 / 0 | 0 / 9 | core's | 0.06 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| anatomy-veri7vn | 11 | 0 | 6 / 0 / 1 | 11 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| anatomy-veri7vn | 11 | 0 | 7 / 1 / 0 | 9 / 1 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| architecture-veri7vn | 10 | 0 | 10 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| architecture-veri7vn | 10 | 0 | 10 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| arthistory-veri7vn | 11 | 0 | 8 / 0 / 2 | 11 / 0 / 0 | 1 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| arthistory-veri7vn | 11 | 0 | 9 / 0 / 0 | 11 / 0 / 0 | 1 / 9 | core's | 0.06 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| astronomy-v2-veri7vn | 138 | 0 | 67 / 0 / 13 | 138 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| astronomy-v2-veri7vn | 138 | 0 | 106 / 0 / 32 | 130 / 0 / 8 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: WRONG: 8 answered wrong, cap 2 | - | - | - | - |
| astronomy-v3-r2-veri7vn | 138 | 0 | 102 / 0 / 36 | 138 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| astronomy-v3-r2-veri7vn | 138 | 0 | 114 / 0 / 23 | 137 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | ADMIT | - | - | - | - |
| astronomy-v3-veri7vn | 138 | 0 | 102 / 0 / 36 | 138 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| astronomy-v3-veri7vn | 138 | 0 | 114 / 0 / 23 | 137 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | ADMIT | - | - | - | - |
| astronomy-veri7vn | 60 | 0 | 29 / 0 / 5 | 60 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| astronomy-veri7vn | 81 | 0 | 28 / 3 / 49 | 68 / 0 / 13 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: WRONG: 13 answered wrong, cap 1 | - | - | - | - |
| biology-veri7vn | 15 | 0 | 11 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| biology-veri7vn | 15 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| bodies-v2-veri7vn | 38 | 0 | 38 / 0 / 0 | 38 / 0 / 0 | 0 / 9 | core's | 0.12 / 600 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| bodies-v2-veri7vn | 38 | 0 | 37 / 0 / 1 | 38 / 0 / 0 | 0 / 9 | core's | 0.11 / 600 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| botany-veri7vn | 9 | 0 | 8 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| botany-veri7vn | 9 | 0 | 4 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | ADMIT | - | - | - | - |
| calculus-veri7vn | 62 | 0 | 1 / 1 / 56 | 62 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| calculus-veri7vn | 62 | 0 | 2 / 0 / 50 | 62 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| carboncapture-veri7vn | 14 | 0 | 14 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| carboncapture-veri7vn | 14 | 0 | 12 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| carbonmat-veri7vn | 17 | 0 | 12 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| carbonmat-veri7vn | 17 | 0 | 17 / 0 / 0 | 17 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| chemistry-v3-veri7vn | 225 | 0 | 160 / 0 / 4 | 225 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| chemistry-v3-veri7vn | 281 | 0 | 189 / 4 / 32 | 223 / 0 / 2 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| chemistry-veri7vn | 225 | 0 | 160 / 0 / 4 | 225 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| chemistry-veri7vn | 281 | 0 | 189 / 4 / 32 | 223 / 0 / 2 | 0 / 9 | core's | 0.06 / 50 | ADMIT | - | - | - | - |
| childdev-veri7vn | 9 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| childdev-veri7vn | 9 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| climate-veri7vn | 24 | 0 | 18 / 0 / 0 | 24 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| climate-veri7vn | 24 | 0 | 24 / 0 / 0 | 24 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| coldchain-v2-veri7vn | 30 | 0 | 30 / 0 / 0 | 30 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| coldchain-v2-veri7vn | 30 | 0 | 25 / 0 / 0 | 29 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| coldchain-veri7vn | 30 | 0 | 26 / 0 / 0 | 30 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| coldchain-veri7vn | 30 | 0 | 30 / 0 / 0 | 30 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| crafts-veri7vn | 14 | 0 | 10 / 0 / 2 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| crafts-veri7vn | 14 | 0 | 13 / 0 / 1 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| cyber-veri7vn | 20 | 0 | 16 / 0 / 1 | 20 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| cyber-veri7vn | 20 | 0 | 12 / 1 / 2 | 16 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| dataformats-veri7vn | 93 | 0 | 33 / 0 / 48 | 93 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| dataformats-veri7vn | 93 | 0 | 23 / 0 / 56 | 93 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| decay-veri7vn | 42 | 0 | 37 / 1 / 4 | 41 / 1 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| decay-veri7vn | 42 | 0 | 34 / 0 / 1 | 34 / 0 / 1 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| densities-r2-veri7vn | 51 | 0 | 50 / 0 / 1 | 51 / 0 / 0 | 0 / 9 | core's | 0.13 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| densities-r2-veri7vn | 51 | 0 | 51 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.13 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| densities-veri7vn | 51 | 0 | 50 / 0 / 1 | 51 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| densities-veri7vn | 51 | 0 | 51 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| ecology-veri7vn | 13 | 0 | 7 / 0 / 0 | 13 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| ecology-veri7vn | 13 | 0 | 12 / 0 / 1 | 13 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| electrical-veri7vn | 24 | 0 | 22 / 0 / 0 | 24 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| electrical-veri7vn | 24 | 0 | 20 / 0 / 2 | 22 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| electronics-r2-veri7vn | 111 | 0 | 103 / 0 / 8 | 111 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| electronics-r2-veri7vn | 111 | 0 | 111 / 0 / 0 | 111 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| electronics-veri7vn | 111 | 0 | 103 / 0 / 8 | 111 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| electronics-veri7vn | 111 | 0 | 111 / 0 / 0 | 111 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| embedded-veri7vn | 25 | 0 | 17 / 0 / 0 | 25 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| embedded-veri7vn | 25 | 0 | 22 / 0 / 3 | 25 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| energy-v2-veri7vn | 68 | 0 | 38 / 0 / 25 | 68 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| energy-v2-veri7vn | 74 | 0 | 33 / 1 / 25 | 66 / 1 / 7 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 1 | - | - | - | - |
| energy-v3-veri7vn | 74 | 0 | 42 / 0 / 25 | 74 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| energy-v3-veri7vn | 70 | 0 | 32 / 1 / 24 | 69 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| entomology-veri7vn | 9 | 0 | 7 / 1 / 0 | 8 / 1 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| entomology-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| etiquette-veri7vn | 9 | 0 | 5 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| etiquette-veri7vn | 9 | 0 | 6 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| firesafety-v2-veri7vn | 18 | 0 | 14 / 0 / 2 | 18 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| firesafety-v2-veri7vn | 10 | 0 | 9 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| firstaid-veri7vn | 9 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| firstaid-veri7vn | 9 | 0 | 6 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| fleet-veri7vn | 54 | 0 | 40 / 0 / 0 | 54 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| fleet-veri7vn | 54 | 0 | 46 / 1 / 7 | 54 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| fluids-r2-veri7vn | 34 | 0 | 34 / 0 / 0 | 34 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| fluids-r2-veri7vn | 34 | 0 | 18 / 0 / 16 | 34 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| fluids-veri7vn | 34 | 0 | 34 / 0 / 0 | 34 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| fluids-veri7vn | 34 | 0 | 18 / 0 / 16 | 34 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| forestry-veri7vn | 16 | 0 | 15 / 0 / 0 | 16 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| forestry-veri7vn | 16 | 0 | 14 / 0 / 0 | 14 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| fuels-veri7vn | 42 | 0 | 42 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| fuels-veri7vn | 42 | 0 | 42 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| games-v3-veri7vn | 51 | 0 | 45 / 0 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| games-v3-veri7vn | 18 | 0 | 15 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| gardening-veri7vn | 15 | 0 | 12 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| gardening-veri7vn | 15 | 0 | 12 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| genetics-v2-veri7vn | 20 | 0 | 20 / 0 / 0 | 20 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| genetics-v2-veri7vn | 20 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| geometry-v3-veri7vn | 100 | 0 | 92 / 0 / 6 | 100 / 0 / 0 | 9 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| geometry-v3-veri7vn | 100 | 0 | 61 / 0 / 20 | 100 / 0 / 0 | 9 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| geometry-v4-veri7vn | 100 | 0 | 73 / 0 / 6 | 100 / 0 / 0 | 9 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| geometry-v4-veri7vn | 93 | 0 | 50 / 0 / 43 | 93 / 0 / 0 | 9 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| geometry-veri7vn | 106 | 0 | 74 / 0 / 0 | 106 / 0 / 0 | 9 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| geometry-veri7vn | 97 | 0 | 75 / 0 / 20 | 89 / 0 / 0 | 9 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| git-veri7vn | 10 | 0 | 3 / 0 / 7 | 10 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| git-veri7vn | 10 | 0 | 6 / 0 / 2 | 7 / 0 / 1 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| government-veri7vn | 14 | 0 | 10 / 0 / 1 | 14 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| government-veri7vn | 14 | 0 | 6 / 0 / 0 | 10 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | ADMIT | - | - | - | - |
| grammar-veri7vn | 15 | 0 | 1 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| grammar-veri7vn | 15 | 0 | 15 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| hvac-veri7vn | 41 | 0 | 22 / 0 / 6 | 41 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| hvac-veri7vn | 42 | 0 | 36 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| iot-veri7vn | 27 | 0 | 19 / 0 / 0 | 27 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| iot-veri7vn | 27 | 0 | 16 / 0 / 8 | 27 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| javascript-veri7vn | 10 | 0 | 5 / 0 / 2 | 10 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| javascript-veri7vn | 10 | 0 | 9 / 0 / 1 | 10 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| labsolutions-r2-veri7vn | 28 | 0 | 25 / 0 / 0 | 28 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| labsolutions-r2-veri7vn | 27 | 0 | 21 / 0 / 0 | 27 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| labsolutions-veri7vn | 28 | 0 | 25 / 0 / 0 | 28 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| labsolutions-veri7vn | 27 | 0 | 21 / 0 / 0 | 27 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| law-veri7vn | 9 | 0 | 6 / 0 / 2 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| law-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| library-veri7vn | 15 | 0 | 7 / 0 / 0 | 15 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| library-veri7vn | 15 | 0 | 8 / 0 / 2 | 14 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| linguistics-veri7vn | 11 | 0 | 8 / 0 / 0 | 11 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| linguistics-veri7vn | 11 | 0 | 9 / 0 / 1 | 11 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| linux-v2-veri7vn | 42 | 0 | 38 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| linux-v2-veri7vn | 42 | 0 | 38 / 0 / 4 | 42 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| literature-v2-veri7vn | 18 | 0 | 12 / 0 / 2 | 18 / 0 / 0 | 7 / 9 | core's | 0.08 / 50 | WOULD PASS | - | - | - | - |
| literature-v2-veri7vn | 12 | 0 | 8 / 0 / 1 | 11 / 0 / 0 | 7 / 9 | core's | 0.08 / 50 | ADMIT | - | - | - | - |
| logic-v3-veri7vn | 33 | 0 | 23 / 1 / 9 | 32 / 1 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| logic-v3-veri7vn | 12 | 0 | 11 / 0 / 0 | 12 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| marinebio-veri7vn | 9 | 0 | 4 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| marinebio-veri7vn | 9 | 0 | 7 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| materials-v2-veri7vn | 34 | 0 | 18 / 2 / 6 | 34 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| materials-v2-veri7vn | 24 | 0 | 18 / 0 / 3 | 24 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| mechanisms-v2-veri7vn | 63 | 0 | 59 / 0 / 0 | 63 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| mechanisms-v2-veri7vn | 55 | 0 | 37 / 0 / 6 | 55 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| mechanisms-veri7vn | 54 | 0 | 51 / 0 / 0 | 54 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| mechanisms-veri7vn | 64 | 0 | 53 / 0 / 11 | 57 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| medicine-r2-veri7vn | 9 | 0 | 6 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| medicine-r2-veri7vn | 9 | 0 | 6 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | ADMIT | - | - | - | - |
| medicine-veri7vn | 9 | 0 | 6 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | WOULD PASS | - | - | - | - |
| medicine-veri7vn | 9 | 0 | 6 / 0 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | ADMIT | - | - | - | - |
| microbiology-v2-veri7vn | 20 | 0 | 12 / 1 / 5 | 20 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| microbiology-v2-veri7vn | 13 | 0 | 9 / 0 / 0 | 13 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| music-v2-r2-veri7vn | 64 | 0 | 56 / 1 / 3 | 64 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| music-v2-r2-veri7vn | 64 | 0 | 53 / 0 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| music-v2-veri7vn | 64 | 0 | 56 / 1 / 3 | 64 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| music-v2-veri7vn | 64 | 0 | 53 / 0 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| mycelial-veri7vn | 7 | 0 | 4 / 0 / 1 | 7 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| mycelial-veri7vn | 7 | 0 | 6 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| mycology-veri7vn | 9 | 0 | 6 / 0 / 1 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| mycology-veri7vn | 9 | 0 | 7 / 0 / 1 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| mythology-veri7vn | 13 | 0 | 1 / 1 / 0 | 12 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| mythology-veri7vn | 13 | 0 | 8 / 0 / 1 | 13 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| networking-veri7vn | 74 | 0 | 37 / 1 / 20 | 74 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| networking-veri7vn | 71 | 0 | 53 / 1 / 10 | 68 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| nutrition-label-v2-veri7vn | 32 | 0 | 21 / 0 / 6 | 32 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD PASS | - | - | - | - |
| nutrition-label-v2-veri7vn | 16 | 0 | 16 / 0 / 0 | 16 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| optics-v2-veri7vn | 68 | 0 | 66 / 0 / 0 | 68 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| optics-v2-veri7vn | 66 | 0 | 56 / 1 / 9 | 59 / 0 / 7 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 1 | - | - | - | - |
| optics-v3-veri7vn | 64 | 0 | 64 / 0 / 0 | 64 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| optics-v3-veri7vn | 67 | 0 | 33 / 1 / 9 | 53 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| optics-v5-r2-veri7vn | 74 | 0 | 67 / 0 / 0 | 74 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| optics-v5-r2-veri7vn | 65 | 0 | 50 / 1 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| optics-v5-veri7vn | 74 | 0 | 67 / 0 / 0 | 74 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| optics-v5-veri7vn | 65 | 0 | 50 / 1 / 0 | 51 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| optics-veri7vn | 70 | 0 | 60 / 0 / 0 | 70 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| optics-veri7vn | 61 | 0 | 49 / 0 / 12 | 55 / 0 / 6 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: WRONG: 6 answered wrong, cap 1 | - | - | - | - |
| orbits-veri7vn | 35 | 0 | 1 / 2 / 16 | 35 / 0 / 0 | 2 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| orbits-veri7vn | 35 | 0 | 3 / 1 / 23 | 35 / 0 / 0 | 2 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| ornithology-veri7vn | 9 | 0 | 5 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD PASS | - | - | - | - |
| ornithology-veri7vn | 9 | 0 | 5 / 0 / 1 | 7 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| pets-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.06 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| pets-veri7vn | 9 | 0 | 9 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| physics-r2-veri7vn | 123 | 0 | 53 / 0 / 0 | 123 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| physics-r2-veri7vn | 123 | 0 | 101 / 0 / 1 | 123 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| physics-r3-veri7vn | 123 | 0 | 53 / 0 / 0 | 123 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| physics-r3-veri7vn | 123 | 0 | 101 / 0 / 1 | 123 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| physics-veri7vn | 123 | 0 | 53 / 0 / 0 | 123 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| physics-veri7vn | 123 | 0 | 101 / 0 / 1 | 123 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| planetary-veri7vn | 18 | 0 | 16 / 0 / 0 | 18 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| planetary-veri7vn | 18 | 0 | 14 / 1 / 3 | 17 / 1 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| poetry-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 1 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| poetry-veri7vn | 9 | 0 | 5 / 0 / 0 | 9 / 0 / 0 | 1 / 9 | core's | 0.09 / 50 | ADMIT | - | - | - | - |
| printing-v2-veri7vn | 36 | 0 | 36 / 0 / 0 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| printing-v2-veri7vn | 37 | 0 | 30 / 0 / 0 | 37 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| printing-veri7vn | 39 | 0 | 32 / 0 / 0 | 39 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| printing-veri7vn | 36 | 0 | 23 / 0 / 0 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| psychology-veri7vn | 9 | 0 | 7 / 1 / 0 | 8 / 1 / 0 | 0 / 9 | core's | 0.07 / 50 | WOULD FAIL: DOMAIN: gain 1, needs 3 | - | - | - | - |
| psychology-veri7vn | 9 | 0 | 8 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.07 / 50 | NEGATIVE: DOMAIN: gain 1, needs 3 | - | - | - | - |
| python-r2-veri7vn | 198 | 0 | 174 / 0 / 11 | 198 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| python-r2-veri7vn | 224 | 0 | 161 / 3 / 23 | 186 / 0 / 2 | 0 / 9 | core's | 0.02 / 50 | ADMIT | - | - | - | - |
| python-veri7vn | 198 | 0 | 174 / 0 / 11 | 198 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| python-veri7vn | 224 | 0 | 161 / 3 / 23 | 186 / 0 / 2 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| renewables-veri7vn | 26 | 0 | 17 / 0 / 0 | 26 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| renewables-veri7vn | 26 | 0 | 12 / 2 / 9 | 23 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| robotics-v2-veri7vn | 36 | 0 | 26 / 0 / 2 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| robotics-v2-veri7vn | 23 | 0 | 20 / 0 / 0 | 20 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| safety-veri7vn | 44 | 0 | 44 / 0 / 0 | 44 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| safety-veri7vn | 45 | 0 | 21 / 0 / 16 | 45 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| sociology-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | WOULD FAIL: DOMAIN: gain 2, needs 3 | - | - | - | - |
| sociology-veri7vn | 9 | 0 | 7 / 0 / 0 | 9 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | NEGATIVE: DOMAIN: gain 2, needs 3 | - | - | - | - |
| soil-r2-veri7vn | 36 | 0 | 21 / 0 / 0 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| soil-r2-veri7vn | 36 | 0 | 14 / 2 / 20 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| soil-veri7vn | 36 | 0 | 21 / 0 / 0 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| soil-veri7vn | 36 | 0 | 14 / 2 / 20 | 36 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| spacecomms-veri7vn | 32 | 0 | 24 / 0 / 0 | 32 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| spacecomms-veri7vn | 36 | 0 | 28 / 1 / 0 | 36 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| spacecraft-veri7vn | 21 | 0 | 8 / 0 / 0 | 21 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| spacecraft-veri7vn | 21 | 0 | 10 / 1 / 3 | 14 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| sports-veri7vn | 19 | 0 | 6 / 0 / 2 | 19 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| sports-veri7vn | 19 | 0 | 11 / 0 / 2 | 19 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| springs-veri7vn | 42 | 0 | 34 / 0 / 8 | 42 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| springs-veri7vn | 42 | 0 | 42 / 0 / 0 | 42 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| sql-veri7vn | 61 | 0 | 56 / 0 / 0 | 61 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| sql-veri7vn | 61 | 0 | 61 / 0 / 0 | 61 / 0 / 0 | 0 / 9 | core's | 0.02 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| statistics-v2-veri7vn | 144 | 0 | 82 / 2 / 46 | 143 / 1 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| statistics-v2-veri7vn | 144 | 0 | 90 / 0 / 10 | 137 / 0 / 7 | 0 / 9 | core's | 0.04 / 50 | NEGATIVE: WRONG: 7 answered wrong, cap 2 | - | - | - | - |
| statistics-v3-veri7vn | 144 | 0 | 113 / 1 / 30 | 144 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| statistics-v3-veri7vn | 144 | 0 | 77 / 0 / 17 | 144 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| statistics-veri7vn | 142 | 0 | 113 / 0 / 27 | 142 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| statistics-veri7vn | 142 | 0 | 104 / 0 / 24 | 142 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| thermo-veri7vn | 44 | 0 | 44 / 0 / 0 | 44 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD FAIL: DOMAIN: gain 0, needs 3 | - | - | - | - |
| thermo-veri7vn | 50 | 0 | 27 / 1 / 19 | 50 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| units-v2-veri7vn | 75 | 0 | 54 / 0 / 21 | 75 / 0 / 0 | 6 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| units-v2-veri7vn | 74 | 0 | 43 / 0 / 21 | 51 / 0 / 13 | 6 / 9 | core's | 0.04 / 50 | NEGATIVE: WRONG: 13 answered wrong, cap 1 | - | - | - | - |
| units-v3-r2-veri7vn | 76 | 0 | 45 / 0 / 18 | 76 / 0 / 0 | 6 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| units-v3-r2-veri7vn | 75 | 0 | 47 / 0 / 26 | 75 / 0 / 0 | 6 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| units-v3-veri7vn | 76 | 0 | 45 / 0 / 18 | 76 / 0 / 0 | 6 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| units-v3-veri7vn | 75 | 0 | 47 / 0 / 26 | 75 / 0 / 0 | 6 / 9 | core's | 0.05 / 50 | ADMIT | - | - | - | - |
| units-veri7vn | 76 | 0 | 39 / 0 / 14 | 76 / 0 / 0 | 6 / 9 | core's | 0.02 / 50 | WOULD PASS | - | - | - | - |
| units-veri7vn | 76 | 0 | 43 / 0 / 29 | 76 / 0 / 0 | 6 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| ushistory-veri7vn | 12 | 0 | 7 / 0 / 1 | 12 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| ushistory-veri7vn | 12 | 0 | 6 / 1 / 4 | 11 / 1 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| water-r3-veri7vn | 46 | 0 | 31 / 0 / 0 | 46 / 0 / 0 | 0 / 9 | core's | 0.04 / 200 | WOULD PASS | - | - | - | - |
| water-r3-veri7vn | 47 | 0 | 32 / 0 / 4 | 47 / 0 / 0 | 0 / 9 | core's | 0.04 / 200 | ADMIT | - | - | - | - |
| water-veri7vn | 46 | 0 | 31 / 0 / 0 | 46 / 0 / 0 | 0 / 9 | core's | 0.05 / 50 | WOULD PASS | - | - | - | - |
| water-veri7vn | 47 | 0 | 32 / 0 / 4 | 47 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | ADMIT | - | - | - | - |
| wildlife-veri7vn | 9 | 0 | 4 / 2 / 3 | 9 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| wildlife-veri7vn | 9 | 0 | 7 / 0 / 0 | 7 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | NEGATIVE: DOMAIN: gain 0, needs 3 | - | - | - | - |
| wiring-veri7vn | 42 | 0 | 34 / 0 / 3 | 42 / 0 / 0 | 0 / 9 | core's | 0.03 / 50 | WOULD PASS | - | - | - | - |
| wiring-veri7vn | 45 | 0 | 39 / 0 / 0 | 45 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| woodworking-veri7vn | 36 | 0 | 31 / 0 / 3 | 36 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | WOULD PASS | - | - | - | - |
| woodworking-veri7vn | 36 | 0 | 30 / 0 / 3 | 33 / 0 / 0 | 0 / 9 | core's | 0.04 / 50 | ADMIT | - | - | - | - |
| worldhistory-veri7vn | 11 | 0 | 5 / 0 / 3 | 11 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | WOULD PASS | - | - | - | - |
| worldhistory-veri7vn | 11 | 0 | 7 / 0 / 2 | 11 / 0 / 0 | 0 / 9 | core's | 0.08 / 50 | ADMIT | - | - | - | - |

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
| finance | 0 | no lane run recorded | - | - |
| geostats | 0 | no lane run recorded | - | - |
| humanities | 0 | no lane run recorded | - | - |
| life | 0 | no lane run recorded | - | - |
| materials | 0 | no lane run recorded | - | - |
| mechanics | 9 | 55 | 0 | `network` 18, `specialist_call` 18, `precision_guard:*` 12, `network3` 6, `weight:m_g` 1 |
| quantity | 6 | 109 | 6 | `specialist_call` 61, `precision_guard:*` 19, `organ:math` 12, `network3` 6, `network` 6, `op:*` 5 |
| rel-novels | 0 | no lane run recorded | - | - |
| relations | 0 | no lane run recorded | - | - |
| space | 0 | no lane run recorded | - | - |
| stores | 0 | no lane run recorded | - | - |
| trades | 0 | no lane run recorded | - | - |
| variants | 0 | no lane run recorded | - | - |
