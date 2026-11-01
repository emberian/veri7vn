# S3 reader control, 2026-10-29

What this is: upstream Oracle7 and upstream Reader7 were run on the same 116 questions the native
reader was measured on (100 retained KQA validation questions, 16 frozen targeted-composition
questions). It is a control, not a panel score. Receipt:
`native/evidence/2026-10-29-upstream-reader-control.json` (per-question results, hashes, commands).
Working files: `var/s3-reader-control/`.

## What ran

- Engine: `tools/parity/answerers/oracle7.py`, head `oracle_release_runtime_w540`, one process, fresh state
  directory. 224.5 s wall, 443 MB peak RSS, 0 errors.
- Reader7 alone: the pinned `swarm/` snapshot copied to `var/s3-reader-control/swarm/`, built with
  `reader_cache10.build` from `train.json` and `kb.json`, over `steps_kb.KQA`. 334.8 s wall (44 s table
  build, 6 s KB load, each question read by both `read` and `read7`), 1.33 GB peak RSS, 0 errors.
- `train.json` fetched from hbox; SHA-256 `e9fbe4c1...e4510`, matches the pinned value.
- `upstream/` git status was byte-identical before and after.

## Results

Scoring: exact gold text (case-insensitive). "Unknown" means no answer; Reader7 "cascade" is the v6-then-v7 order
used in `reader_v7.py`'s own main.

| 100 KQA questions | correct | refused | unknown/withheld | wrong |
|---|---|---|---|---|
| Native reader | 36 | 4 | 60 | 0 |
| Upstream Engine | 0 | - | 90 (58 clarification, 32 withheld) | 10 (prose, see below) |
| Reader7 alone (`read7`) | 32 | 0 | 68 | 0 |
| Reader7 alone (v6 then v7) | 37 | 1 | 62 | 0 |

| 16 targeted questions | correct (10 positive) | expected declines (6) | not answered | errors |
|---|---|---|---|---|
| Native candidate | 1 | 4 | 7 | 4 |
| Upstream Engine | 0 | 6 | 10 | 0 |
| Reader7 alone (both orders) | 2 | 6 | 8 | 0 |

Reader7 correct on the 16: `nested_human_count_bristol` (6) and `nested_university_count_cardiff` (2). The native
candidate got the first and hit a composition byte error on the second. Reader7 did not answer any of the 8
entity questions, including the single-filter control `baseline_city_website_saskatoon`.

## Engine: 10 answered replies, none exact

The Engine is not a KQA reader; it replied in prose or asked for clarification. All ten are listed with gold
in the receipt (`engine_nonmatching_answers`). Four contain the gold string inside prose (4832 "genre",
9124 "3", 2542 Brandeis University, 8512 The House Bunny); the other six do not (200, 11107 Turkish for
Bulgarian, 2064, 7209, 5821, 9181). None is scored correct. No dataset error was identified.

## Native vs Reader7 on the 100: every disagreement (13)

| source_index | terminal | gold | native | Reader7 `read7` | Reader7 v6 then v7 |
|---|---|---|---|---|---|
| 264 | VerifyYear | yes | correct | unknown | correct |
| 2608 | SelectBetween | Memoirs of a Geisha | correct | unknown | unknown |
| 2431 | QueryRelation | award received | correct | unknown | correct |
| 2136 | QueryAttrQualifier | English | unknown | correct | correct |
| 8905 | QueryRelationQualifier | 1991 | correct | unknown | correct |
| 2542 | SelectBetween | Brandeis University | refused | correct | correct |
| 9151 | VerifyNum | yes | correct | unknown | correct |
| 2064 | QueryAttr | a10450294 | correct | unknown | correct |
| 9514 | QueryRelation | famous people | refused | correct | correct |
| 653 | Count | 3 | refused | unknown | unknown |
| 5821 | QueryRelation | producer | correct | unknown | correct |
| 5659 | SelectAmong | Adirondack Mountains | correct | unknown | unknown |
| 525 | SelectBetween | Deconstructing Harry | refused | correct | refused (two answers: Deconstructing Harry, Made in Dagenham) |

Native answers that upstream does not (`read7`): 8. Upstream answers that native does not: 4 (2136, 2542, 9514,
525; 2542, 9514, 525 are native refusals). Zero wrong answers anywhere, so no gold-versus-reader mismatch
needed a dataset adjudication.

## Reading it

- On the 100, native (36) sits between Reader7's `read7` (32) and v6-then-v7 (37); the three agree on no wrong
  answers. Native does not yet beat the upstream reader it descends from, and upstream's cascade answers
  one more.
- Native refuses four where Reader7 answers three of them; those are candidates for the reader-defect work.
- On the 16, upstream Reader7 also fails 8 of 8 entity cases, so the composition shortfall is not unique to the
  native port; it answers the two count cases.

## What this does not establish

A control on 116 questions, one run each, no panel score. The 16 were built around the native reader's
templates. The Reader7 control uses the pinned source over `steps_kb.KQA`, not whatever the Engine hosts. Gold
is not assumed infallible, though nothing here disputed it.

## What remains

1. The same control after the plural-first retrain (native side only needs rerunning; the upstream numbers hold).
2. A Reader7 control on fresh questions, not the 100 already examined.
3. Per-case native results for the 16 (the evidence file gives only counts).

Consumer: root and `project/DIRECTION-2026-10-29.md`.
