# A2: tooling follow-ups for Oracle7 slim 10.1

29 October 2026. Lane A2-TOOLING-10.1. Root commits.

## What changed, in plain words

1. **Parity answerer starts on repaired runtimes.** `tools/parity/answerers/oracle7.py`
   `redirect_self_loop` used to move the vessel files out of `upstream/` and refuse to
   start when it found none to move. It now also counts the vessel paths that already
   resolve under `ORACLE7_STATE` (the 10.0+ repair). Paths inside the runtime root are
   still redirected as before (old `upstream/`, head w540). It refuses only when it finds
   neither kind. If a runtime has some of each, the ones inside the runtime are moved.
   `A1`'s wrapper `var/appliance-20261029/tools/answerer_statefix.py` is no longer needed.
2. **`[ev:derived]` tag.** The 10.1 head (w573) strips every `[ev:...]` tag.
   - `tools/runtime_contract.py`: new `_untag` removes one leading `[ev:derived] `; the three
     displayed-result comparisons (affine unique, affine non-unique, closed expression)
     compare the untagged text. The rest of the text must still match exactly.
   - `tools/usage/reliability/check_pairs.py`: the first pattern is now
     `^(?:\[ev:derived\]\s+)?(NUMBER)(?=\s|\.)`. The number is read the same way both ways.
     One consequence: an untagged answer that starts with a number is now read as that
     number (the tagged form already was). Text starting with a word is still unparsed.
   - `tools/reader/answerer.py`: **no change.** It does not match the tag. It writes
     `[ev:direct] ` on its own replies (line 107); nothing there reads `[ev:derived]`.
     No test added. If the brief meant something else, tell me.

Not changed, outside the brief: `tools/usage/conversation/runtime_conversation_state.py`
(and `deploy/appliance/patches/oracle7-slim-4.9-usage.patch`) hold `_SCALAR`, which also
needs the tag. In 10.1 this is upstream code, so leaving it. Root decides.

## Tests and exact results

- Answerer, old `upstream/`, `.venv/bin/python`, `PARITY_UPSTREAM=upstream`, question
  "Who wrote Leaves of Grass?": started, head w540, "self_loop writes redirected:
  oracle_release_runtime_w175.VESSELS, ...EVENTS, ...REQUESTS, oracle_release_runtime_w480.VESSEL_DB",
  answered "[ev:direct] Walt Whitman. ...". Log `var/a2-tooling/run-old.log`.
- Answerer, `var/appliance-20261029/candidate-u8` (runtime root is that directory),
  same question: started, head w574, "none needed, the runtime already writes under
  ORACLE7_STATE: (the same four paths)", answered "Walt Whitman. Leaves of Grass is a
  collection of poetry by American writer Walt Whitman (1819-1892)." Log `var/a2-tooling/run-u8.log`.
  Nothing written into `upstream/` or the candidate (state went to `var/a2-tooling/state-u8`).
  The first attempt used system python3 and failed on missing numpy; the project venv is needed.
- `cd tools; python3 -B -m unittest test_closed_evidence`: 7 tests OK (new
  `test_reply_with_or_without_evidence_tag`: tagged and untagged accepted; `6.`,
  tagged `6.`, `[ev:direct] 5.`, `5` without the full stop rejected).
- `test_affine_evidence`: 9 OK. `test_runtime_contract`: 13 OK (existing, unchanged).
- `RELIABILITY_WORD_MODULE=var/appliance-20261029/candidate-u8/root/wander-train/word_problems_v1.py
  python3 -B -m unittest tests.usage.reliability.test_reliability.PairCheckerTests`: 6 OK
  (new `test_tagged_and_untagged_reply_read_the_same`: both give number 12.0, a wrong
  provenance value on the untagged reply is `inconsistent_reply`).
- Not run: `GeometryTests` (needs the geometry module, not touched), and re-scoring U8's
  ten pairs with the fixed checker (A1 expects 7 of 10; I did not rerun it).

## What remains

- Re-score U8 with the fixed `check_pairs.py` to confirm 7 of 10.
- Decide on `runtime_conversation_state.py` `_SCALAR`.

## Changed files

- tools/parity/answerers/oracle7.py
- tools/runtime_contract.py
- tools/usage/reliability/check_pairs.py
- tools/test_closed_evidence.py
- tests/usage/reliability/test_reliability.py
- project/lanes/A2-TOOLING-10.1-2026-10-29.md
- (scratch, untracked: var/a2-tooling/)
