# W5-08 Conversation on the board

Lane W5-08, sonnet. Dialogue mode added to the parity harness from the conversation scout's rules check.

## What changed

- `tools/parity/dialogue.py`: the conversation scoring rules, run joining and summary (moved from
  `scout/conversation` `src/extract/converse/score.py` part 1).
- `tools/parity/harness.py`: `--dialogue SCRIPT[=RUN]` (repeatable; `shipped` = the four sealed tests).
  `--answerer` is now optional only when `--dialogue` is given; every earlier invocation is unchanged.
- `tools/parity/answerers/recorded.py`: a session-keeping test answerer that replays a recorded run (untrusted
  fixture).
- `tests/parity/test_dialogue.py`: 15 tests. The parity suite is 38 tests, all passing.
- `docs/parity/README.md`: a Dialogue mode section.

## Numbers (from the recorded replies, no head run)

Turn marks, 237 turns: **236 of 237 recorded verdicts reproduced**, through both the replay path and the live path
(the replay answerer fed over the answerer contract, one session per dialogue).

| Test | Run on | Turns | Handled | Precision | Follow-ups right | False yes | vs published |
|---|---|---:|---:|---:|---:|---:|---|
| 1, run 3 | w533 | 88 | 70.5% | 89.1% | 48.6% | 0 | differs (published 71.6 / 90.9 / 51.4) |
| 2 | w533 | 51 | 62.7% | 83.9% | 52.4% | 0 | exact |
| 4 | w536 | 49 | 67.3% | 77.8% | 70.0% | 0 | exact |
| 5 | w538 | 49 | 77.6% | 94.4% | 90.0% | 0 | exact |

"Exact" means every summary field equals the recording (right, wrong, missed, kept, handled, answered, rates).

The summary that does not reproduce is test 1, run 3, and only through one turn: dialogue 17 turn 1, `And Phobos?`
(after "Which planet does Io orbit?"). Oracle7 replied with a `capability:summarize` paragraph about Phobos that never
contains "Mars". The shipped runner marked it right; the written rule (the reply must contain an alias of the answer)
marks it wrong. That moves right 50 to 49, wrong 5 to 6, and the four rates above. Kept as is: the harness follows the
written rule, and the turn is the "reach is not an answer" kind the later gate called a false yes. The README's table
also lists test 3 (arm A); no script-and-run pair for it was in the task, so it is not on the board.

## What it cannot do yet

- The rules are Python from a docstring (the shipped runner `run_conv_v1.py` is not in the release). They are checked
  against 237 recorded verdicts, not proved.
- A live candidate is scored on the same 237 turns, but only the recorded Oracle7 replies exist for the head; nobody
  has run a candidate answerer yet. Its first number will be low on follow-ups unless it keeps session state.
- `recorded.py` replays one run per process; for a four-test live pass start it once per test (the `=RUN` form of
  `--dialogue` names each pair).

## Reproduce

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --dialogue shipped --out var/parity/dialogue-replay
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/parity
```
