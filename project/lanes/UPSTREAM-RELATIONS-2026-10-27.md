# Upstream relation findings — 27 October 2026

Published two actionable issues after checking current Hugging Face main, the
pending PR, and all existing slim discussions. No duplicate report was found.
Both published bodies were retrieved and verified byte-for-byte.

| Issue | Published UTC | Body SHA256 |
|---|---|---|
| [#6: inverse target selection precedes uniqueness](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/6) | 2026-10-27 18:42:48 | `eff43089b479ba688c90a0f540702dbb9f8679c1d4aa4ed07f6db0012a711bc7` |
| [#7: title words defeat requested-kind constraints](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/7) | 2026-10-27 18:42:48 | `b0a91e33ae298ff7b93afe043114a28fb4b2461dd7d6a0a237b471ede1ec9290` |

Both are open discussions, not merged fixes or release qualification. The issue
bodies are retained under `tools/usage/upstream-relations/`. Root owns their
commit together with this report.

## Current-source checks

Fresh official Hub API reads still identify main as
`0e0e858238cb028b751a85a23f4690a0b0d48483` and PR #2 as
`f5b73e079668af60ceea3e191fcd9e252e68b514`. Those refs were checked again
immediately before publication. The four reader files were freshly downloaded
at their immutable revisions, rather than inferred from an old survey checkout.

| Source | File | SHA256 |
|---|---|---|
| main | relation_spec_v1.py | `08f905b8f87cfb8d85256836dfff96a4f69b0d1299f017a0c559ef0c5fee7985` |
| main and PR #2 | relation_spec_v2.py | `8c712b9af41aafb3945ca72ddbcd22b019ba4340cb212787b085789b0a3596ac` |
| PR #2 | relation_spec_v1.py | `585da9452b15c223322da194de616f07b7956e68704f9c9b8b5d5c1520f743aa` |

Reproducer:

```sh
python3 -B tools/usage/upstream-relations/reproduce.py \
  --source var/upstream-relations-20261027/main \
  --composer-source var/upstream-relations-20261027/pr2/relation_spec_v1.py
```

It runs actual upstream reader functions with explicitly controlled linker,
type and row fixtures; it does not import the full Engine, acquire a corpus or
claim a natural-language end-to-end failure. All witness assertions passed:

- Two equally ranked target IDs each have a different unique spouse. The inverse
  reader queries only the first ID; reversing their order changes subject 102
  to subject 103 instead of reporting ambiguity.
- For “Who composed the film Song of Dawn?”, current main's real kind guard
  admits both film and song domains. The actual `answer` function returns the
  fixture film composer and fixture song composer through the respective readers.
  Removing “Song” from the title restores the intended songs-domain rejection.
- The explicit composer path proposed in **our own PR #2** has the same failure.
  The issue distinguishes that proposed path from the generic reader on main.

The literal Python blocks embedded in both published issues were also executed
against these fresh source files and produced the stated observations.

## Proposed patches and limits

The issues link the audit patches/tests/reports at immutable veri7vn commit
`463727e2c350aabc57252ef7d854e26d99155702`.

`inverse-target-appliance.patch` passed a fresh `git apply --check` against exact
current-main blobs for **all 163 affected files**. Its earlier six consumer tests
remain scoped evidence from the audit; this lane did not relabel them as a new
full-Engine run. The proposed patch needs the specific ambiguity refusal to
survive all relevant consumers, including routes that may answer before Family
runs. It does not settle unknown type membership, source completeness, present
truth or a capped linker's identity coverage.

`composer-guard.patch` applied to the freshly downloaded PR #2 reader and all
**four existing composer fixtures passed** (0.032 seconds). It binds the explicit
film qualifier and declines when a year-filtered eligible candidate lacks a
parseable date. It does not repair the generic main-branch kind guard or prove
complete publication-year coverage. The issue also links the audit's prior
actual-store film/song example, explicitly identified as reader/store evidence
from the 4.9-based candidate rather than a full 10.0 Engine result.

No new PR was opened: these patches still need consumer integration and relevant
panel/Engine qualification, and the general type-guard issue exceeds the narrow
composer patch. The reports make the missing work concrete without presenting a
partial guard as a proof of interpretation.

## Owned changes and retained evidence

- `tools/usage/upstream-relations/reproduce.py`
- `tools/usage/upstream-relations/inverse-issue.md`
- `tools/usage/upstream-relations/film-issue.md`
- this report.

Fresh source snapshots, pins, replay JSON, patch-check output and publication
receipts are retained under `var/upstream-relations-20261027/`. No mutable
runtime, candidate, original `upstream/`, proof kernel or large data file was
edited. No theorem, shipped-panel, complete-Engine or world-truth claim was made.
No additional subagent or external message beyond these two authorized issues
was sent.
