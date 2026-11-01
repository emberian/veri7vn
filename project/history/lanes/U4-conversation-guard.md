# U4 — last-question recall through the private-state guard

Implemented 2026-10-27 in mutable `var/ap1-upstream-slim`. This is a later source
repair, not part of frozen U3-v5 acceptance. No immutable candidate, receipt,
Store or SPK was changed. Root owns integration and commits.

Root checkpoint: private source `692fd57`, based on `58f48b2`. The portable
`deploy/appliance/patches/oracle7-slim-4.9-conversation-guard.patch` carries the
implementation and its tests; apply it after the U3 operations-v3 patch in a
future candidate. Root reran all nine tests successfully. The frozen v5 runtime
does not include this repair yet.

## Observed failure and intended property

The real packaged U3-v2 service record at
`var/u3-service/u3-v2-real/calls.jsonl`, label `head-crossroute-follow`, records:

1. Conversation `u3-head-equivalence-a` asked “What is 6 multiplied by 7?” and
   received 42.
2. `core.query` in that conversation asked “What did I just ask?”
3. The dialogue organ produced the correct stored text, with `[session:turn 1]`.
4. w534 replaced it with `withheld`, path
   `precision_guard:G2_private_state|organ:dialogue>discourse:asked_last`, saying
   that only the user could know. The original correct answer survives in that
   receipt's `provenance.withheld_response`.

The U3-v3 service evidence at `var/u3-service/u3-v3-real/calls.jsonl` separately
shows successful same-conversation authored-work → author-birth follow-up across
`/query` and `core.query`. It did not rerun the G2 example. These records support a
guard failure rather than missing session plumbing.

G2 prevents answers about unprovided personal facts: passwords, account balances,
dreams, and private thoughts. Its broad `what did I …` recognizer also catches
last-question recall. Removing that recognizer, trusting a dialogue path string,
or exempting every sentence containing a history request would weaken the guard.

## Repair

Changed source:
`root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w534.py`
in the mutable checkout.

For a complete supported last-question/last-utterance request, w534 reads the
same session's dialogue answer **before** calling its parent. The existing
`DialogueOrgan.answer` implementation is a pure read of the bounded history; it
adds no turn, opens no stores and invokes no models. No new history copy or second
log is introduced.

The G2 exception requires the returned response, route, turn references and
provenance move/turns to match that captured answer exactly. A path label or
citation on its own cannot grant the exception. Without the history handler or a
matching recorded answer, G2 retains its old behavior. Sign and date-premise
guards still run. The unchanged `private_state` classifier still recognizes the
recall sentence; the new evidence check is what permits it.

The supported result for the recorded arithmetic example is:

```
You asked: "What is 6 multiplied by 7?" [session:turn 1]. I answered: "In steps: 6 x 7 = 42. The answer is 42.".
```

Status is `answered`, path is `organ:dialogue>discourse:asked_last`, and the
reference names turn 1. An empty conversation reports its empty history without
borrowing another conversation's record. If the prior question was withheld,
recall quotes the request and says it was not answered; it does not turn that
private fact into an answer.

## Narrow checks

New tests: `tests/conversation_guard/test_last_question.py` in the mutable source.
They execute the actual w534 class and guard, actual `DialogueOrgan`, and the
unchanged AST-selected w480 envelope builder. The parent harness substitutes for
the expensive head and appends a turn as w480 does. No full Engine was launched.

Command from `var/ap1-upstream-slim`:

```
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/conversation_guard -v
```

Result: **9 tests passed**, 0.001 seconds. `git diff --check` passed.

Checks cover the exact recorded failure, empty history, repeated recall and
supported wording variants, prior withheld requests, unchanged sign/date guards,
and existing quantity computations. Invalid controls stay withheld:

- Password, bank-balance, dream and private-thought questions.
- A recall request followed by a PIN/password question, or scoped to another
  conversation.
- Correct route labels with invented response text or mismatched references.
- Stale replies and replies from a different session.
- A missing history handler.

History-length assertions establish that the extra guard read does not append a
turn. These are scoped semantic regressions, not a full-head packaged replay.
**No specialist panels were scored, and no theorem was added.**

## Consumer and limits

The consumer is the existing serving ancestry through w534, reached by both
whole-head `/query` and discovered `core.query`. Root can include the source in a
later candidate and qualify that candidate separately. This change does not
alter the frozen v5 artifact or its acceptance evidence.

The check trusts the runtime's in-memory session record; it does not prove that
record's authenticity. It recalls the bounded text already stored by the dialogue
organ. First-question and history-list semantics are outside this narrowly
anchored exception; the existing organ has broader substring recognizers and
selects the last non-self-referential turn. Those broader history behaviors were
not silently declared repaired.
