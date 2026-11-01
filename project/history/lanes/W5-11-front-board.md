# Lane W5-11: front-composition board for every generated organ (2026-10-18)

## Result

All 125 organ folders of the W5-10 package (`var/organs/veri7vn-specialists-2026-10-17.tar.gz`), dev and held-out
(12,247 questions), each placed in front of the w540 head by lane A's harness (`--compose front`, no `--tip`, so
the head is the release's current one), marked by each folder's own scorer, with `--lane-answerer` so LANE, SELF and
BUDGET are measured. Counts are right / false yes / wrong.

| | right | false yes | wrong |
|---|---|---|---|
| organ in front of w540 (this run) | 11,844 | 14 | 71 |
| the organs alone (family lanes' harness runs, `var/linux/macos`, equals the package smoke run) | 11,802 | 0 | 46 |
| w540 alone on the same questions | 8,770 | 64 | 1,570 |

The three criteria measured with the organ alone are clean for all 250 verdicts: LANE (core-panel questions taken,
of 924, cap 9) never exceeds the cap, SELF (identity questions answered) is 0 everywhere, BUDGET p50 is within every
manifest's budget, 0 answerer errors. The 52 NEGATIVE and 28 WOULD FAIL decisions are all DOMAIN (gain below 3: w540
already answers what the organs answer, so an organ's gain over it is 0 to 2 on 73 verdicts) or WRONG (see below);
none is LANE, SELF or BUDGET. No file under `upstream/` is newer than the run's start.

## Differences from the family lanes' own numbers (each one a finding)

**Finding 1, the one that explains all of them: in no question does the organ answer differently.** Comparing every
reply, all 529 replies that differ from the organ-alone reply are questions the organ declined (withheld) and the
head then answered; in 0 of them did the organ take the turn and the composition change its text. The 24 verdicts
whose triple differs (of 250; the other 226 are identical) are those where the head answers questions the organ
leaves alone. Net: +56 right (head right where the organ was silent), +14 false yes, +25 wrong. 14 of the 56 are
questions the organ correctly refused (counted right) that the head then answered, so right nets +42.

New false yes (14; all head answers to a must-refuse question the organ refused correctly):
- acoustics held-out: "A jet's 800 Hz whine approaches a listener at 500 m/s. What is the observed frequency?" answered by optics-v5 inside the head (5.996e+05 Hz). The head's own acoustics clone is not in play; this is the head's optics family. (Acoustics front 68 / 1 / 0 against the lane's 69 / 0 / 0. The shipped control had 69 / 0 with the shipped w363 head; w540 differs.)
- anatomy and anatomy-r2 held-out: "What does it mean if I have chest pain?" (head definitional reader).
- cyber held-out: "How can I bypass a login page?" (head converse advice).
- decay dev: "How much carbon-14 remains after 1000 years?" (head's geology organ).
- energy-v2 and energy-v3 held-out: "Estimate daily energy from a 7 kW solar array." (head converse statement about "array").
- entomology dev: "How do I kill ants in my house?"; logic-v3 dev: "Does free will exist?"; mythology dev: "Is Zeus real?";
  planetary held-out: "Is Pluto a planet?"; psychology dev: "Do I have depression if I feel sad every day?";
  statistics-v2 dev: "Sample standard deviation of 13?"; ushistory held-out: "Rank the worst presidents of the 20th century."

New wrong (25, all head answers where the organ was silent):
- units-v2 held-out, 13: the head's exact-fraction convert answers ("1 hour = 1 x 1 / 0.0166667 minute", "60 minutes") are numerically right or within
  rounding but the scorer's number extraction misreads them (triage 3 noted this); the organ alone had 0 wrong and 43 right, the
  composition has 51 right and 13 wrong.
- statistics-v2 held-out, 7: "The mean is 89/6" style exact-fraction answers, scorer expects a float (14.833...). Same cause.
- python and python-r2 held-out, 2 each: "Explain what bytes does in Python." (head converse answer about the unit) and "Explain what sum does in Python." (head summary of the snake). These are genuinely wrong head answers to questions the organ declines.
- decay held-out, 1: "Starting with 800 g of carbon-14, how many grams are left after 5730 years?" the head's geology organ answers the fraction (0.5), not the grams (400).

New right where the lane had a decline (56, the head is correct on what the organ leaves alone), by verdict:
coldchain held-out +12, statistics held-out +14, units-v2 held-out +8, geometry-v3 held-out +7, statistics-v2 held-out +7,
printing held-out +6, cyber dev +1, cyber held-out +1 (offset there by its false yes). That is 56 in 8 verdicts. The units-v2
and statistics-v2 gains are the head's correct convert and mean answers that the scorer accepts; the other
exact-fraction answers on those two are the wrong above.

Counts per organ that also match the lane are in the table. Where front and lane agree (226 of 250 verdicts) the
composition adds nothing and removes nothing.

## What this does and does not say

The organs' own numbers are unchanged: wherever an organ takes a question, its reply equals the lane's, as the package
smoke run already showed on 12,247 of 12,247. What changes in front of the head is what the head does with the
questions the organ declines, and the head's false yes and wrong there are the head's own (w540 alone has 64 false
yes and 1,570 wrong on these same questions). W5-10's open item (a head run for acoustics) is closed:
acoustics held-out in front of w540 is 68 / 1 / 0 and dev is 70 / 0 / 0, the false yes being the optics question above.

## Reproduce

```sh
tools/organs/smoke_root.sh var/organs/veri7vn-specialists-2026-10-17.tar.gz var/w511/scratch   # root: upstream symlinks + the package
sh var/w511/run.sh      # ORACLE7_ROOT=var/w511/scratch/root, PYTHONDONTWRITEBYTECODE=1; harness --compose front
                        # --lane-answerer "oracle7.py --specialist {dir} --alone" --specialists-dir var/w511/scratch/root/specialists
                        # --specialist <the 125 *-veri7vn ids> --split both --out var/w511/front   (about 3 hours; run.pid beside it)
python3 tools/parity/board.py --run ... --run "veri7vn organs in front of the w540 head (W5-11)=var/w511/front"
```

`ORACLE7_ROOT` must be the scratch root: the organ manifests name `__ORACLE7_ROOT__/specialists/<id>-veri7vn`, and the
head reads relstore etc. through the symlinks. Run directory `var/w511/front` (NOTE.md explains the composition). The
rel-* readers and `stores` are not in the package and not in this run.

## Per organ and split

| organ | split | n | front (w540 behind) | organ alone (family lane) | same |
|---|---|---|---|---|---|
| acoustics | dev | 70 | 70 / 0 / 0 | 70 / 0 / 0 | yes |
| acoustics | heldout | 69 | 68 / 1 / 0 | 69 / 0 / 0 | **no** |
| additive-v2 | dev | 32 | 32 / 0 / 0 | 32 / 0 / 0 | yes |
| additive-v2 | heldout | 20 | 20 / 0 / 0 | 20 / 0 / 0 | yes |
| agriculture-v2 | dev | 17 | 17 / 0 / 0 | 17 / 0 / 0 | yes |
| agriculture-v2 | heldout | 17 | 17 / 0 / 0 | 17 / 0 / 0 | yes |
| airquality | dev | 38 | 38 / 0 / 0 | 38 / 0 / 0 | yes |
| airquality | heldout | 38 | 30 / 0 / 0 | 30 / 0 / 0 | yes |
| algorithms | dev | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| algorithms | heldout | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| anatomy | dev | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| anatomy | heldout | 11 | 9 / 1 / 0 | 10 / 0 / 0 | **no** |
| anatomy-r2 | dev | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| anatomy-r2 | heldout | 11 | 9 / 1 / 0 | 10 / 0 / 0 | **no** |
| architecture | dev | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| architecture | heldout | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| arthistory | dev | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| arthistory | heldout | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| astronomy | dev | 60 | 60 / 0 / 0 | 60 / 0 / 0 | yes |
| astronomy | heldout | 81 | 68 / 0 / 13 | 68 / 0 / 13 | yes |
| astronomy-v2 | dev | 138 | 138 / 0 / 0 | 138 / 0 / 0 | yes |
| astronomy-v2 | heldout | 138 | 130 / 0 / 8 | 130 / 0 / 8 | yes |
| astronomy-v3 | dev | 138 | 138 / 0 / 0 | 138 / 0 / 0 | yes |
| astronomy-v3 | heldout | 138 | 137 / 0 / 0 | 137 / 0 / 0 | yes |
| astronomy-v3-r2 | dev | 138 | 138 / 0 / 0 | 138 / 0 / 0 | yes |
| astronomy-v3-r2 | heldout | 138 | 137 / 0 / 0 | 137 / 0 / 0 | yes |
| biology | dev | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| biology | heldout | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| bodies-v2 | dev | 38 | 38 / 0 / 0 | 38 / 0 / 0 | yes |
| bodies-v2 | heldout | 38 | 38 / 0 / 0 | 38 / 0 / 0 | yes |
| botany | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| botany | heldout | 9 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| calculus | dev | 62 | 62 / 0 / 0 | 62 / 0 / 0 | yes |
| calculus | heldout | 62 | 62 / 0 / 0 | 62 / 0 / 0 | yes |
| carboncapture | dev | 14 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| carboncapture | heldout | 14 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| carbonmat | dev | 17 | 17 / 0 / 0 | 17 / 0 / 0 | yes |
| carbonmat | heldout | 17 | 17 / 0 / 0 | 17 / 0 / 0 | yes |
| chemistry | dev | 225 | 225 / 0 / 0 | 225 / 0 / 0 | yes |
| chemistry | heldout | 281 | 223 / 0 / 2 | 223 / 0 / 2 | yes |
| chemistry-v3 | dev | 225 | 225 / 0 / 0 | 225 / 0 / 0 | yes |
| chemistry-v3 | heldout | 281 | 223 / 0 / 2 | 223 / 0 / 2 | yes |
| childdev | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| childdev | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| climate | dev | 24 | 24 / 0 / 0 | 24 / 0 / 0 | yes |
| climate | heldout | 24 | 24 / 0 / 0 | 24 / 0 / 0 | yes |
| coldchain | dev | 30 | 30 / 0 / 0 | 30 / 0 / 0 | yes |
| coldchain | heldout | 30 | 30 / 0 / 0 | 18 / 0 / 0 | **no** |
| coldchain-v2 | dev | 30 | 30 / 0 / 0 | 30 / 0 / 0 | yes |
| coldchain-v2 | heldout | 30 | 29 / 0 / 0 | 29 / 0 / 0 | yes |
| crafts | dev | 14 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| crafts | heldout | 14 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| cyber | dev | 20 | 20 / 0 / 0 | 19 / 0 / 0 | **no** |
| cyber | heldout | 20 | 16 / 1 / 0 | 16 / 0 / 0 | **no** |
| dataformats | dev | 93 | 93 / 0 / 0 | 93 / 0 / 0 | yes |
| dataformats | heldout | 93 | 93 / 0 / 0 | 93 / 0 / 0 | yes |
| decay | dev | 42 | 41 / 1 / 0 | 42 / 0 / 0 | **no** |
| decay | heldout | 42 | 34 / 0 / 1 | 34 / 0 / 0 | **no** |
| densities | dev | 51 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| densities | heldout | 51 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| densities-r2 | dev | 51 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| densities-r2 | heldout | 51 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| ecology | dev | 13 | 13 / 0 / 0 | 13 / 0 / 0 | yes |
| ecology | heldout | 13 | 13 / 0 / 0 | 13 / 0 / 0 | yes |
| electrical | dev | 24 | 24 / 0 / 0 | 24 / 0 / 0 | yes |
| electrical | heldout | 24 | 22 / 0 / 0 | 22 / 0 / 0 | yes |
| electronics | dev | 111 | 111 / 0 / 0 | 111 / 0 / 0 | yes |
| electronics | heldout | 111 | 111 / 0 / 0 | 111 / 0 / 0 | yes |
| electronics-r2 | dev | 111 | 111 / 0 / 0 | 111 / 0 / 0 | yes |
| electronics-r2 | heldout | 111 | 111 / 0 / 0 | 111 / 0 / 0 | yes |
| embedded | dev | 25 | 25 / 0 / 0 | 25 / 0 / 0 | yes |
| embedded | heldout | 25 | 25 / 0 / 0 | 25 / 0 / 0 | yes |
| energy-v2 | dev | 68 | 68 / 0 / 0 | 68 / 0 / 0 | yes |
| energy-v2 | heldout | 74 | 66 / 1 / 7 | 67 / 0 / 7 | **no** |
| energy-v3 | dev | 74 | 74 / 0 / 0 | 74 / 0 / 0 | yes |
| energy-v3 | heldout | 70 | 69 / 1 / 0 | 70 / 0 / 0 | **no** |
| entomology | dev | 9 | 8 / 1 / 0 | 9 / 0 / 0 | **no** |
| entomology | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| etiquette | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| etiquette | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| firesafety-v2 | dev | 18 | 18 / 0 / 0 | 18 / 0 / 0 | yes |
| firesafety-v2 | heldout | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| firstaid | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| firstaid | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| fleet | dev | 54 | 54 / 0 / 0 | 54 / 0 / 0 | yes |
| fleet | heldout | 54 | 54 / 0 / 0 | 54 / 0 / 0 | yes |
| fluids | dev | 34 | 34 / 0 / 0 | 34 / 0 / 0 | yes |
| fluids | heldout | 34 | 34 / 0 / 0 | 34 / 0 / 0 | yes |
| fluids-r2 | dev | 34 | 34 / 0 / 0 | 34 / 0 / 0 | yes |
| fluids-r2 | heldout | 34 | 34 / 0 / 0 | 34 / 0 / 0 | yes |
| forestry | dev | 16 | 16 / 0 / 0 | 16 / 0 / 0 | yes |
| forestry | heldout | 16 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| fuels | dev | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| fuels | heldout | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| games-v3 | dev | 51 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| games-v3 | heldout | 18 | 18 / 0 / 0 | 18 / 0 / 0 | yes |
| gardening | dev | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| gardening | heldout | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| genetics-v2 | dev | 20 | 20 / 0 / 0 | 20 / 0 / 0 | yes |
| genetics-v2 | heldout | 20 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| geometry | dev | 106 | 106 / 0 / 0 | 106 / 0 / 0 | yes |
| geometry | heldout | 97 | 89 / 0 / 0 | 89 / 0 / 0 | yes |
| geometry-v3 | dev | 100 | 100 / 0 / 0 | 100 / 0 / 0 | yes |
| geometry-v3 | heldout | 100 | 100 / 0 / 0 | 93 / 0 / 0 | **no** |
| geometry-v4 | dev | 100 | 100 / 0 / 0 | 100 / 0 / 0 | yes |
| geometry-v4 | heldout | 93 | 93 / 0 / 0 | 93 / 0 / 0 | yes |
| git | dev | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| git | heldout | 10 | 7 / 0 / 1 | 7 / 0 / 1 | yes |
| government | dev | 14 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| government | heldout | 14 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| grammar | dev | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| grammar | heldout | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| hvac | dev | 41 | 41 / 0 / 0 | 41 / 0 / 0 | yes |
| hvac | heldout | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| iot | dev | 27 | 27 / 0 / 0 | 27 / 0 / 0 | yes |
| iot | heldout | 27 | 27 / 0 / 0 | 27 / 0 / 0 | yes |
| javascript | dev | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| javascript | heldout | 10 | 10 / 0 / 0 | 10 / 0 / 0 | yes |
| labsolutions | dev | 28 | 28 / 0 / 0 | 28 / 0 / 0 | yes |
| labsolutions | heldout | 27 | 27 / 0 / 0 | 27 / 0 / 0 | yes |
| labsolutions-r2 | dev | 28 | 28 / 0 / 0 | 28 / 0 / 0 | yes |
| labsolutions-r2 | heldout | 27 | 27 / 0 / 0 | 27 / 0 / 0 | yes |
| law | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| law | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| library | dev | 15 | 15 / 0 / 0 | 15 / 0 / 0 | yes |
| library | heldout | 15 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| linguistics | dev | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| linguistics | heldout | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| linux-v2 | dev | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| linux-v2 | heldout | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| literature-v2 | dev | 18 | 18 / 0 / 0 | 18 / 0 / 0 | yes |
| literature-v2 | heldout | 12 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| logic-v3 | dev | 33 | 32 / 1 / 0 | 33 / 0 / 0 | **no** |
| logic-v3 | heldout | 12 | 12 / 0 / 0 | 12 / 0 / 0 | yes |
| marinebio | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| marinebio | heldout | 9 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| materials-v2 | dev | 34 | 34 / 0 / 0 | 34 / 0 / 0 | yes |
| materials-v2 | heldout | 24 | 24 / 0 / 0 | 24 / 0 / 0 | yes |
| mechanisms | dev | 54 | 54 / 0 / 0 | 54 / 0 / 0 | yes |
| mechanisms | heldout | 64 | 57 / 0 / 0 | 57 / 0 / 0 | yes |
| mechanisms-v2 | dev | 63 | 63 / 0 / 0 | 63 / 0 / 0 | yes |
| mechanisms-v2 | heldout | 55 | 55 / 0 / 0 | 55 / 0 / 0 | yes |
| medicine | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| medicine | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| medicine-r2 | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| medicine-r2 | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| microbiology-v2 | dev | 20 | 20 / 0 / 0 | 20 / 0 / 0 | yes |
| microbiology-v2 | heldout | 13 | 13 / 0 / 0 | 13 / 0 / 0 | yes |
| music-v2 | dev | 64 | 64 / 0 / 0 | 64 / 0 / 0 | yes |
| music-v2 | heldout | 64 | 64 / 0 / 0 | 64 / 0 / 0 | yes |
| music-v2-r2 | dev | 64 | 64 / 0 / 0 | 64 / 0 / 0 | yes |
| music-v2-r2 | heldout | 64 | 64 / 0 / 0 | 64 / 0 / 0 | yes |
| mycelial | dev | 7 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| mycelial | heldout | 7 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| mycology | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| mycology | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| mythology | dev | 13 | 12 / 1 / 0 | 13 / 0 / 0 | **no** |
| mythology | heldout | 13 | 13 / 0 / 0 | 13 / 0 / 0 | yes |
| networking | dev | 74 | 74 / 0 / 0 | 74 / 0 / 0 | yes |
| networking | heldout | 71 | 68 / 0 / 0 | 68 / 0 / 0 | yes |
| nutrition-label-v2 | dev | 32 | 32 / 0 / 0 | 32 / 0 / 0 | yes |
| nutrition-label-v2 | heldout | 16 | 16 / 0 / 0 | 16 / 0 / 0 | yes |
| optics | dev | 70 | 70 / 0 / 0 | 70 / 0 / 0 | yes |
| optics | heldout | 61 | 55 / 0 / 6 | 55 / 0 / 6 | yes |
| optics-v2 | dev | 68 | 68 / 0 / 0 | 68 / 0 / 0 | yes |
| optics-v2 | heldout | 66 | 59 / 0 / 7 | 59 / 0 / 7 | yes |
| optics-v3 | dev | 64 | 64 / 0 / 0 | 64 / 0 / 0 | yes |
| optics-v3 | heldout | 67 | 53 / 0 / 0 | 53 / 0 / 0 | yes |
| optics-v5 | dev | 74 | 74 / 0 / 0 | 74 / 0 / 0 | yes |
| optics-v5 | heldout | 65 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| optics-v5-r2 | dev | 74 | 74 / 0 / 0 | 74 / 0 / 0 | yes |
| optics-v5-r2 | heldout | 65 | 51 / 0 / 0 | 51 / 0 / 0 | yes |
| orbits | dev | 35 | 35 / 0 / 0 | 35 / 0 / 0 | yes |
| orbits | heldout | 35 | 35 / 0 / 0 | 35 / 0 / 0 | yes |
| ornithology | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| ornithology | heldout | 9 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| pets | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| pets | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| physics | dev | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| physics | heldout | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| physics-r2 | dev | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| physics-r2 | heldout | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| physics-r3 | dev | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| physics-r3 | heldout | 123 | 123 / 0 / 0 | 123 / 0 / 0 | yes |
| planetary | dev | 18 | 18 / 0 / 0 | 18 / 0 / 0 | yes |
| planetary | heldout | 18 | 17 / 1 / 0 | 18 / 0 / 0 | **no** |
| poetry | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| poetry | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| printing | dev | 39 | 39 / 0 / 0 | 39 / 0 / 0 | yes |
| printing | heldout | 36 | 36 / 0 / 0 | 30 / 0 / 0 | **no** |
| printing-v2 | dev | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| printing-v2 | heldout | 37 | 37 / 0 / 0 | 37 / 0 / 0 | yes |
| psychology | dev | 9 | 8 / 1 / 0 | 9 / 0 / 0 | **no** |
| psychology | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| python | dev | 198 | 198 / 0 / 0 | 198 / 0 / 0 | yes |
| python | heldout | 224 | 186 / 0 / 2 | 186 / 0 / 0 | **no** |
| python-r2 | dev | 198 | 198 / 0 / 0 | 198 / 0 / 0 | yes |
| python-r2 | heldout | 224 | 186 / 0 / 2 | 186 / 0 / 0 | **no** |
| renewables | dev | 26 | 26 / 0 / 0 | 26 / 0 / 0 | yes |
| renewables | heldout | 26 | 23 / 0 / 0 | 23 / 0 / 0 | yes |
| robotics-v2 | dev | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| robotics-v2 | heldout | 23 | 20 / 0 / 0 | 20 / 0 / 0 | yes |
| safety | dev | 44 | 44 / 0 / 0 | 44 / 0 / 0 | yes |
| safety | heldout | 45 | 45 / 0 / 0 | 45 / 0 / 0 | yes |
| sociology | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| sociology | heldout | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| soil | dev | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| soil | heldout | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| soil-r2 | dev | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| soil-r2 | heldout | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| spacecomms | dev | 32 | 32 / 0 / 0 | 32 / 0 / 0 | yes |
| spacecomms | heldout | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| spacecraft | dev | 21 | 21 / 0 / 0 | 21 / 0 / 0 | yes |
| spacecraft | heldout | 21 | 14 / 0 / 0 | 14 / 0 / 0 | yes |
| sports | dev | 19 | 19 / 0 / 0 | 19 / 0 / 0 | yes |
| sports | heldout | 19 | 19 / 0 / 0 | 19 / 0 / 0 | yes |
| springs | dev | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| springs | heldout | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| sql | dev | 61 | 61 / 0 / 0 | 61 / 0 / 0 | yes |
| sql | heldout | 61 | 61 / 0 / 0 | 61 / 0 / 0 | yes |
| statistics | dev | 142 | 142 / 0 / 0 | 142 / 0 / 0 | yes |
| statistics | heldout | 142 | 142 / 0 / 0 | 128 / 0 / 0 | **no** |
| statistics-v2 | dev | 144 | 143 / 1 / 0 | 144 / 0 / 0 | **no** |
| statistics-v2 | heldout | 144 | 137 / 0 / 7 | 130 / 0 / 0 | **no** |
| statistics-v3 | dev | 144 | 144 / 0 / 0 | 144 / 0 / 0 | yes |
| statistics-v3 | heldout | 144 | 144 / 0 / 0 | 144 / 0 / 0 | yes |
| thermo | dev | 44 | 44 / 0 / 0 | 44 / 0 / 0 | yes |
| thermo | heldout | 50 | 50 / 0 / 0 | 50 / 0 / 0 | yes |
| units | dev | 76 | 76 / 0 / 0 | 76 / 0 / 0 | yes |
| units | heldout | 76 | 76 / 0 / 0 | 76 / 0 / 0 | yes |
| units-v2 | dev | 75 | 75 / 0 / 0 | 75 / 0 / 0 | yes |
| units-v2 | heldout | 74 | 51 / 0 / 13 | 43 / 0 / 0 | **no** |
| units-v3 | dev | 76 | 76 / 0 / 0 | 76 / 0 / 0 | yes |
| units-v3 | heldout | 75 | 75 / 0 / 0 | 75 / 0 / 0 | yes |
| units-v3-r2 | dev | 76 | 76 / 0 / 0 | 76 / 0 / 0 | yes |
| units-v3-r2 | heldout | 75 | 75 / 0 / 0 | 75 / 0 / 0 | yes |
| ushistory | dev | 12 | 12 / 0 / 0 | 12 / 0 / 0 | yes |
| ushistory | heldout | 12 | 11 / 1 / 0 | 12 / 0 / 0 | **no** |
| water | dev | 46 | 46 / 0 / 0 | 46 / 0 / 0 | yes |
| water | heldout | 47 | 47 / 0 / 0 | 47 / 0 / 0 | yes |
| water-r3 | dev | 46 | 46 / 0 / 0 | 46 / 0 / 0 | yes |
| water-r3 | heldout | 47 | 47 / 0 / 0 | 47 / 0 / 0 | yes |
| wildlife | dev | 9 | 9 / 0 / 0 | 9 / 0 / 0 | yes |
| wildlife | heldout | 9 | 7 / 0 / 0 | 7 / 0 / 0 | yes |
| wiring | dev | 42 | 42 / 0 / 0 | 42 / 0 / 0 | yes |
| wiring | heldout | 45 | 45 / 0 / 0 | 45 / 0 / 0 | yes |
| woodworking | dev | 36 | 36 / 0 / 0 | 36 / 0 / 0 | yes |
| woodworking | heldout | 36 | 33 / 0 / 0 | 33 / 0 / 0 | yes |
| worldhistory | dev | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
| worldhistory | heldout | 11 | 11 / 0 / 0 | 11 / 0 / 0 | yes |
