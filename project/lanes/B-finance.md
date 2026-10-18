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
