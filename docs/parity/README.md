# The parity board

The parity board answers one question: on the exams Oracle7's own specialists had to pass, how many questions does a
given system get right, how many does it get wrong, and how often does it answer a question it should have refused?
It runs any program that follows the [answerer contract](../contracts/answerer.md) over the exam questions shipped in
`upstream/root/specialists/*/`, and marks each reply with that specialist's own marking script. The rules for passing
are the six rules of Oracle7's exam program, `upstream/workbench/exam.py`. The results are in [BOARD.md](BOARD.md).

The harness only reads `upstream/`. Oracle7's exam program cannot be used directly: it spends a held-out exam (it will
refuse the same exam a second time) and writes result files into the specialist's folder. The harness repeats its
scoring steps instead, and writes everything under `var/parity/`.

## How to run it

```sh
P=$PWD/.venv/bin/python          # the Python that runs Oracle7
# one specialist, Oracle7 with that specialist in front of it, using the Oracle7 core the shipped verdict names
python3 tools/parity/harness.py \
  --answerer "$P tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}" \
  --lane-answerer "$P tools/parity/answerers/oracle7.py --specialist {dir} --alone" \
  --specialist acoustics --split heldout --out var/parity/my-run
# the packaged veri7vn on the first three acoustics questions (about 40 seconds a question)
python3 tools/parity/harness.py \
  --answerer "python3 tools/parity/answerers/veri7vn_packaged.py var/deployment-ui-d44-standalone-aae0d7dd/generations/<generation>" \
  --specialist acoustics --split heldout --limit 3 --out var/parity/veri7vn-sample
# the board
python3 tools/parity/board.py --run "My run=var/parity/my-run" --run "veri7vn=var/parity/veri7vn-sample"
# unit tests (no engine needed)
python3 -m unittest discover -s tests/parity
```

`--specialist` takes one name, several separated by commas, or `all`. In the answerer command, `{dir}` becomes the
specialist's folder, `{id}` its name and `{shipped_head}` the Oracle7 core named in its shipped verdict. A run that is
stopped can be started again with the same command; it continues where it stopped. `--rescore` recomputes the verdicts
from the recorded replies without asking again.

## The answerers that come with it

- `answerers/oracle7.py`: Oracle7's core alone.
- `answerers/oracle7.py --specialist <folder>`: the core first, and the specialist only where the core declined for
  lack of a reading. This is how `exam.py` combines them.
- `answerers/oracle7.py --compose front --specialist <folder>`: the specialist first, and the core only where the
  specialist takes nothing. This is how the release itself combined one specialist with the core when it admitted
  it. The specialist is loaded and asked through the release's own file `_gate/combo_runtime_v1.py`, one reply per
  question.
- `--compose combo` is the same through that file's full combiner, which also splits a question with two parts and
  answers each part. The release added that splitting after most exams were taken; with it, 8 `astronomy-v3`
  questions such as "Taking Mars as 1, how many times as massive is Mercury? (mass of Mercury relative to Mars)" are
  answered twice, the first number is the wrong way round, and the count drops from the shipped 137 to 129. Without
  it the count is 137, as shipped.
- `--tip <name>` builds the core from an earlier version kept in the release (for example
  `oracle_release_runtime_w363`) instead of the current one (`w540`).
- `answerers/oracle7.py --specialist <folder> --alone`: the specialist by itself. The board uses it for the three
  rules that look at the specialist alone.
- `answerers/veri7vn_packaged.py <generation>`: the packaged veri7vn, one `veri7vn launch ... run` per question.

Every Oracle7 reply also reports what the core alone said, so one pass gives both the "core alone" and the "core with
specialist" numbers.

## What the columns mean

Each count is written **right / false yes / wrong**:

- **right**: the specialist's marking script accepts the reply. For a question that must be refused (a false premise,
  something unknowable, something out of scope), refusing it counts as right.
- **false yes**: an answer to a question that must be refused.
- **wrong**: an answer to a proper question that the marking script rejects.

Per specialist, the board shows: the number of exam questions; replies that failed because the answerer crashed
(counted as refusals); the core alone; the answerer; the specialist's reach into general questions (lane); whether it
answers "Who are you?"-type questions (self); its median reply time against its budget; the decision under `exam.py`'s
rules; and, from the shipped verdict file, the core it was measured against, that core's count, the shipped combined
count and the difference between ours and the shipped one.

The decision is `ADMIT` when all six rules hold:

1. **Domain**: with the specialist, at least max(3, 2% of n) more questions are right than without it.
2. **No false yes**: no more false yeses than the core alone.
3. **Few wrong**: at most max(1, 2% of n) wrong answers.
4. **Stays in lane**: on the 924 general questions in `upstream/workbench/data/core_panel.json`, it takes at most 9
   of the questions the core declined for lack of a reading.
5. **Self**: it answers none of the five identity questions.
6. **Budget**: its median reply time is within the manifest's budget (200 ms when none is given).

`NEGATIVE` lists the rules that failed, in `exam.py`'s own words. `INCOMPLETE` means some rules could not be measured
(an answerer that does not report the core's own reply cannot be checked against rules 1 and 2; one run without
`--lane-answerer` cannot be checked against rules 4 to 6). An incomplete verdict is never counted as a pass.

## How the control went

Before the board can be trusted it has to reproduce Oracle7's own published exam results. It was run on the held-out
exams of six specialists: `acoustics`, `cooking-v3`, `densities`, `units`, `units-v3` and the relation reader
`rel-actors`, in three ways (all numbers right / false yes; the shipped files mostly do not record "wrong").

| Specialist | n | Shipped: core alone | Ours: core alone | Shipped: combined | A: release's combination, shipped core | B: exam.py's combination, shipped core | C: exam.py's combination, current core w540 |
|---|---|---|---|---|---|---|---|
| acoustics | 69 | 3 / 1 | 3 / 1 | 69 / 0 | **69 / 0** | 57 / 1 | 62 / 2 |
| cooking-v3 | 228 | 10 / 0 | 10 / 0 | 224 / 0 | **224 / 0** | 212 / 0 | 212 / 0 |
| densities | 51 | 3 / 0 | 3 / 0 | 51 / 0 | **51 / 0** | 50 / 0 | 51 / 0 |
| units | 76 | 5 / 0 | 5 / 0 | 76 / 0 | **76 / 0** | 43 / 0 | 47 / 0 |
| units-v3 | 75 | 4 / 0 | 4 / 0 | 75 / 0 | **75 / 0** | 48 / 0 | 48 / 0 |
| rel-actors | 96 | 24 / 0 | 20 / 0 | 96 / 0 | 20 / 0 | 20 / 0 | 20 / 0 |

What this shows:

- **The core alone is reproduced exactly** for all five non-relation specialists, using the core version each
  verdict names (`w363` or `w524`). This checks the question loading, the marking scripts, the counting and the
  rebuilt older cores.
- **Run A reproduces the shipped combined results exactly** for those five. The release admitted its specialists
  with the specialist placed *in front of* the core. `exam.py` places it *behind* the core, consulted only when the
  core declined for lack of a reading. These are different rules, and the shipped numbers came from the first one.
- **Run B (exam.py's rule) is lower**, and every lost question is one the core handled itself, so the specialist was
  never asked. In `acoustics`: 6 questions where the core declined with `operator:unparsed` (not a "lack of reading"
  decline in `exam.py`'s list), 5 open-pipe questions the core's algebra module answered wrongly, and 1 must-refuse
  question the core answered from a dictionary. `units` and `units-v3` lose 33 and 27 to the core's own unit and
  algebra modules answering wrongly.
- **Run C (current core w540)**: the current core already calls the admitted specialists itself (fold `w504` and
  later), so "core alone" and "core with specialist" are nearly the same: the gain is 0 for `acoustics`, `cooking-v3`,
  `densities` and `rel-actors`, 1 for `units-v3` and 4 for `units`, and `exam.py`'s first rule (a gain of at least 3)
  fails for five of the six. That is what Oracle7's own exam program would say today; it is not a fault in the
  specialists.
- **rel-actors cannot be reproduced on this installation.** All 161 relation readers (`rel-*`) look names up in
  `root/relstore/names_v1.sqlite3`, and the core's newer relation reader uses `root/relstore/relations_v2.sqlite3`.
  Neither file is in the release (only `relations_v1.sqlite3` is). Without them the relation readers stay silent, so
  the combined count equals the core's. The core alone is 20 here against 24 shipped; the likely cause is the same
  missing files (the `w525` core calls the relation readers itself), but this was not checked question by question,
  because the shipped verdict keeps only 8 of the core's failures.
- **Stays in lane**: our counts are taken on all 924 general questions, as `exam.py` does; the shipped verdicts used
  a 400-question sample, so those two columns are not comparable (`units` and `units-v3` take 6 of 924; the cap is 9).

## Things to know

- Oracle7's core writes a small learning log ("vessels") next to its own program files inside `upstream/`. The
  Oracle7 answerer redirects those writes into its own scratch folder under `var/parity/state/`, which starts empty
  as in the release. Anyone else running the core from `upstream/` writes into `upstream/`.
- `exam.py` cannot load the shipped specialists as they are: their manifests contain the placeholder
  `__ORACLE7_ROOT__`, which `exam.py` does not replace. The answerer replaces it and loads each specialist with its
  folder as the working folder, as the release's own loader does. The rule that decides whether a specialist's reply
  is used is `exam.py`'s, unchanged.
- The packaged veri7vn takes about 40 seconds a question and recognises none of the exam questions tried
  (`Native interpretation requires attention: unrecognized`), so its count is 0 right, 0 false yes, 0 wrong on the
  sample.
- The release admitted its specialists under somewhat different rules from `exam.py`'s. In particular `exam.py`
  allows at most max(1, 2% of n) wrong answers, and the release's exam did not have that rule: `astronomy` was
  admitted with 68 right and 13 wrong, and under `exam.py`'s rules it fails. The board reports `exam.py`'s decision
  next to the shipped one.

## Dialogue mode

Conversation is scored the same way, turn by turn. `--dialogue SCRIPT[=RUN]` feeds every dialogue in a script to the
answerer in order, one session id per dialogue, and marks each turn with the rules from Oracle7's conversation tests
(`tools/parity/dialogue.py`). `--dialogue shipped` takes the four sealed tests that shipped
(`upstream/research/sealed_history/conv_sealed_v1.json`, `v2`, `v4`, `v5`) with their recorded runs. Without
`--answerer`, the recorded replies are scored and nothing runs; with `--answerer`, the answerer is asked and the
recorded run is only the reference to compare with.

```sh
python3 tools/parity/harness.py --dialogue shipped --out var/parity/dialogue-replay           # no head, no answerer
python3 tools/parity/harness.py --dialogue <script.json>=<run.json> --answerer "<cmd>" --out var/parity/dialogue-x
```

The marks are `right`, `wrong`, `missed` (the answerer did not answer), `kept` (a must-refuse turn refused),
`false_yes`, and `handled` (a greeting or thanks that got a real reply). The summary is Oracle7's: turns handled
(right + kept + handled), precision (right over answered), follow-ups right, false yes.

On the recorded runs the rules reproduce 236 of 237 verdicts and the published summaries of tests 2, 4 and 5 exactly.
Test 1 run 3 differs on one turn, `And Phobos?` (dialogue 17, turn 1): Oracle7 answered with a paragraph about Phobos
that never says "Mars", the shipped runner counted it right and the written rule counts it wrong. With it wrong the test
reads handled 70.5%, precision 89.1%, follow-ups right 48.6% against the published 71.6%, 90.9%, 51.4%. The rules are
Python written from a docstring, so they are checked against the recordings and not proved. The scripts are Oracle7's
own and the dialogue replies of one run are not independent of its head: a candidate is compared on the same 237 turns.
`answerers/recorded.py` is a test answerer that replays a recorded run and keeps session state.
