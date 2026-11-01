# U4: preserve grammatical “it” in time and cost questions

27 October 2026. Codex conversation lane. **No specialist panels, full Engine
runs, builds, or theorem checks were run. No theorem claim is made.**

## Confirmed current defect

The current mutable source in `var/ap1-upstream-slim` still contained M53's
unconditional substitution of the first deictic word. The wander-train source
and its admitted mirror were byte-identical before editing.

The regression loads the actual `OracleReleaseRuntimeAO` handler and actual AN
transition recorder, with a controlled AM lower reader. It starts with the
previous topic `that times 2`, declines the transfer-duration question and its
incorrect rewrite, and makes a summary of the old topic available. Before the
repair, the actual handler returns that unrelated summary as an answered turn:

```
How long does it take to transfer 1GB at100Mbps?
  -> How long does that times 2 take to transfer 1GB at100Mbps?
  -> Summarize that times 2.
```

This confirms the source-level defect remains; it does not assume the full
Engine's other readers still produce precisely the same final output. The
initial focused suite ran seven tests and failed eight assertions across three
tests (including six grammar variants), while four control tests passed.

## Repair and useful behavior

M53 now excludes grammatical `it` in the bounded construction
`does/did/will/would/can/could/should/has/had it take/taken/cost ... to <action>`.
The intervening phrase may be a numeric duration or currency amount. It does not
consume an arbitrary direct object: `Does it take photos to upload?` and
`Does it take me to London?` still use the existing referential conversion.

Only the matched `it` token is excluded. Other references in the same question
remain eligible. With the battery as the topic:

```
How long does it take to charge that?
  -> How long does it take to charge the battery?
```

When there is no other reference, the original question reaches the unchanged
handler. In the controlled transfer example, its original withholding remains a
withholding, with one transition recording the original question and no invented
conversion. If the original question already has an answer, that answer remains
unchanged. Existing person/thing references, repairs, ellipses, continuation
handling, and separation between sessions are retained by the focused controls.

This is an explicitly untrusted grammar filter. It prevents an unjustified
rewrite; it does not supply a transfer formula, compute 80 seconds, or prove an
English parse. It intentionally does not cover all grammatical `it` forms
(e.g. `is it possible to ...`), all verbal variants, or nonnumeric duration
phrases. Ambiguous take/cost-infinitive wording is left for the original reader
instead of assuming the earlier topic is its subject. M53's summary fallback for
other genuinely referential but unsupported predicates remains unchanged.

## Changed files

Only these private source and test paths changed:

- `var/ap1-upstream-slim/root/wander-train/oracle_release_runtime_ao.py`
- `var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_ao.py`
- `var/ap1-upstream-slim/tests/conversation_grammar/test_m53_dummy_it.py`

The two source copies still match byte-for-byte; the test enforces that. This
report is the only o7vn tracked-path change in this lane. No candidate/package
file was edited. No Git operation, subordinate agent, or additional source
ownership was used. Root owns review, checkpoint, and separate patch export.

## Check and exact result

```
.venv/bin/python -B -m unittest discover \
  -s var/ap1-upstream-slim/tests/conversation_grammar -v
```

**7 tests passed** in the final run (0.028 seconds). These exercise:

- The original transfer failure through real AO `chat` and AN recording: no
  old-topic summary, exact original question preserved, exactly one transition.
- Seven duration/cost variants, including a different task, auxiliary verbs,
  uppercase wording, a decimal duration, and a decimal currency amount.
- Existing referential `it`, `there`, direct-object uses of `take`, and a short
  referential question without an infinitive.
- A later genuine reference after grammatical `it`, including successful
  redispatch through the real handler and one recorded transition.
- An already answered original question, explicit topic repair, ellipsis, and
  continuation controls.
- Missing topic and different-session isolation.
- Equality of the admitted and wander-train source copies.

The real full Engine and next candidate still need root's scoped integration
check. These component results are not a shipped panel score or Mini acceptance.

## Root checkpoint

Root reran the seven checks successfully and saved private-source commit
`a92896c`. The portable patch is
`deploy/appliance/patches/oracle7-slim-4.9-conversation-grammar.patch`, for the next
candidate after the separately retained conversation-guard repair. Frozen v5
does not contain either U4 repair.
