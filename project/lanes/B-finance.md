# Lane B-finance (beyond parity, 2026-10-18)

Family: finance, finance-v2, finance-v2-r2, economics, retail (`src/extract/finance/`).

## Step 1: fresh panels

Generators: `finance_panel_v1.py` (finance), `finance_panel_v2.py` (finance-v2, -r2), `economics_panel_v1.py`
(economics) from the shipped folders, run with new seeds by `src/extract/finance/fresh/make.sh` (it copies each
generator into `var/finance/fresh/gen/` with the seed tuple replaced; nothing under `upstream/` is written, nothing
under `var/` is committed). Retail ships no generator (only `retail_panel_v1.json`), so it has no fresh panel.

| set | finance v1 gen (dev, heldout) | v2 gen | economics gen |
|---|---|---|---|
| F1 | 7101, 7102 | 71011, 71021 | 7101, 7102 |
| F2 | 9301, 9302 | 93011, 93021 | 9301, 9302 |

Scoring: `tools/parity/harness.py --specialists-dir var/finance/fresh/<F>/specialists` (symlinked organs, manifests
rewritten to the fresh panel), shipped organ through `tools/parity/answerers/oracle7.py --specialist {dir} --alone`,
kernel as `var/finance/bin/finance --specialist {id}`. `src/extract/finance/fresh/tab.py <tag>` tabulates.
Blind spot, said once: the generators draw from small value pools and fixed templates, so a fresh seed mostly
re-shuffles the same sentence shapes; the dev/heldout template split is the real novelty.

Right / wrong / withheld on valid items (dev+heldout summed; fresh = F1+F2):

| specialist | shipped panel organ | shipped panel kernel | fresh organ | fresh kernel (before) |
|---|---|---|---|---|
| finance | 116 / 0 / 13 of 129 | 116 / 0 / 13 | 232 / 0 / 27 of 259 | 232 / 0 / 27 |
| finance-v2 | 128 / 0 / 0 | 128 / 0 / 0 | 246 / 0 / 0 | 246 / 0 / 0 |
| finance-v2-r2 | 128 / 0 / 0 | 128 / 0 / 0 | 246 / 0 / 0 | 246 / 0 / 0 |
| economics | 65 / 0 / 13 of 78 | 65 / 0 / 13 | 130 / 0 / 26 of 156 | 130 / 0 / 26 |
| retail | 96 / 0 / 0 | 96 / 0 / 0 | no generator | no generator |

The kernel and the organ agree item for item on every fresh panel. Every miss is in a held-out phrasing:
finance v1 (mortgage "interest paid in total", "years until an investment doubles"; v2 and r2 already answer
them) and economics (percentage-cut elasticity, "In Y the CPI stood at ..", "Express $X from Y0 in Y1 dollars,
given CPI ..", "Employed: .. Unemployed: ..", "What share of the working-age population (..) is in the labor
force (..)").

## Step 2: reachable misses (recognizer only; the kernel and its theorems are unchanged)

Every miss above is a recognizer limit, not a kind the kernel lacks (all kinds exist: `E_ElasticityPct`,
`E_Inflation`, `E_RealValue`, `E_Unemployment`, `E_Participation`, `F_LoanInterest`, `F_Doubling`). Changes to
`recognizer.sml` (untrusted; this is a pure SML change, rebuilt with the MLton step against the unchanged generated
kernel):

- `finance` (v1) now takes the finance-v2-r2 recognizer (`byId "finance" = finance 3`): the v1 organ declines
  "total interest over the life of a mortgage" and "years until an investment doubles", which v2 and r2 already
  answer with the same kernel kinds. Its must-decline items (advice, missing inputs) are unchanged.
- elasticity from percentages: "A 5% price cut raises quantity demanded by 2%" (noun form of the price change,
  verb-first quantity change; sign from cut/drop/decrease/reduction/lower vs the rest).
- CPI inflation, year-first: "In 2022 the CPI stood at 260; in 2021 it was 250" (used only when the existing
  "N in YEAR" form finds fewer than two values; earlier year is still the base).
- real value: "Express $X from Y0 in Y1 dollars, given CPI .. in Y0 and CPI .. in Y1" (`from YEAR` accepted next to
  `in YEAR` after the amount; before, the target year was read as the amount's year and the item declined).
- participation: parentheses, "working-age population (64 million) ... labor force (40 million)".
- unemployment: the exact whole-text form "Employed: X. Unemployed: Y. What's the unemployment rate?" skips the
  organ's three-sentence narrative test (nothing else does).

Right / wrong / withheld on valid items, harness, `fresh/run.sh b2 ...`:

| specialist | shipped panel (organ -> kernel now) | fresh F1+F2 (organ -> kernel now) |
|---|---|---|
| finance | 116 -> 129 of 129, wrong 0 | 232 -> 259 of 259, wrong 0 |
| finance-v2 | 128 -> 128 | 246 -> 246 |
| finance-v2-r2 | 128 -> 128 | 246 -> 246 |
| economics | 65 -> 78 of 78, wrong 0 | 130 -> 156 of 156, wrong 0 |
| retail | 96 -> 96 | no generator |

`score.py` against the organs: finance-v2, -r2, retail 0 disagreements; finance 16 and economics 13, every one an
item the organ withholds and the kernel answers correctly (the scorer counts them right).
Caution: these fixes were read off the generators' held-out templates, so the fresh numbers reaching 100% say the
phrasings are covered, not that other phrasings are; step 3 probes test sentences the generators never write.
