# U5: stop r468 asking what grammatical “it” refers to

27 October 2026. Codex conversation lane. **No specialist panels, full Engine
runs, builds, or theorem checks were run by this lane. No theorem claim is made.**

## Actual remaining failure

The U4-v2 full-engine receipt is
`var/u4-service/u4-v2-real/calls.jsonl`, labels `grammar-seed`,
`grammar-prior-topic`, and `grammar-transfer`. It records:

1. `What is 6 multiplied by 7?` → 42.
2. `that times 2` → 84.
3. `How long does it take to transfer 1GB at100Mbps?` → clarification:
   `Which do you mean by "it": times or multiplied? Name it and I will answer about that.`

The third reply has `act:clarify_specific` and
`provenance.r468_door = {act: asked, phrase: it, offered: [times, multiplied],
named: [long, take]}`. The previous M53 repair prevented the unrelated summary;
this later fallback independently mistook grammatical `it` for a reference.
The same full-engine run retained the genuine Austen birth follow-up. U2's date
fixes are current; the old Shakespeare result is not an active finding here.

## Current-source confirmation and repair

Only the admitted `oracle_release_runtime_w468.py` exists; there is no
wander-train mirror. Its `_r468_bind` and `_r468_door` each used an independent
raw pointer search. The current real obligation compiler derives `multiplied`
and `times` from the two arithmetic questions, so the focused test produces
exactly the same thread subjects before invoking the actual r468 handler.
Before the repair, that test reproduces the wrong specific clarification.

One local selector now supplies the eligible pointer to both paths. It skips
only the `it` token in the same bounded take/cost-infinitive construction used
by AO. It does not disable reference handling for the whole question:

```
How long does it take to charge that?
  binding: How long does it take to charge battery?
  clarification, if needed: asks about "that", not "it"
```

Possessive `its` remains available, as do ordinary location references and
direct-object uses such as `Does it take photos to upload?` and
`Does it take me to London?`. An already answered parent reply remains unchanged.
A parent private-state refusal remains unchanged and causes no scratch-session
redispatch. An empty session cannot offer another session's subjects.

For the original transfer question, r468 now leaves the parent's generic reply
unchanged instead of inventing a referent ambiguity. **This component repair
has not established a full-engine numerical answer.** Root must check the next
candidate; another reader may still decline or misread the question. The new
handler does not supply a transfer formula or assert 80 seconds.

## Scope and shared grammar

The only private source change is:

- `var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w468.py`

The new test is:

- `var/ap1-upstream-slim/tests/conversation_grammar_r468/test_door_dummy_it.py`

This report is the sole o7vn tracked-path change. Root confirmed these exact
paths before editing. AO's existing filter, all prior patches, and all immutable
candidates/packages are untouched. There were no Git operations or subagents.

There was no existing dependency-free grammar helper to reuse: AO is itself a
runtime-chain module; the context module depends on relation lookup; the final
conversation-state helper has a different bookkeeping role. For this bounded
batch, r468 carries the same small regular expression locally. A test reads AO's
assignment through Python's AST and requires exact pattern equality without
importing AO's runtime chain. Consolidating both into a small shared grammar
module is a future cleanup if the consumers or grammar grow; this patch does
not silently diverge their definitions.

The selector is explicitly untrusted Python, not a general English parser. The
accepted construction and its limitations remain those of U4: take/cost followed
by an infinitive, optionally with a numeric duration/currency amount. Other
expletive forms and arbitrary intervening phrases are outside this change.

## Check and exact result

```
.venv/bin/python -B -m unittest discover \
  -s var/ap1-upstream-slim/tests/conversation_grammar_r468 -v
```

**9 tests passed** in the final run (0.073 seconds). The initial run reported
8 assertion failures plus the expected missing-pattern attribute error, before
implementation. Five existing-behavior controls already passed.

Tests load the real r468 module and the real `oracle_program_ir_v1` obligation
compiler. Only the lower runtime is a controlled reply provider. They cover:

- The recorded arithmetic-thread sequence and exact original transfer wording;
  one original parent dispatch, no spurious door annotation or scratch call.
- Matching exclusions in direct binding and clarification for six duration/cost
  forms, including decimal duration/currency and a perfect-tense variant.
- Later genuine `that` and possessive `its` after grammatical `it`.
- A genuine location follow-up, preserved source references, and its expected
  scratch-session redispatch.
- Direct-object and shorter genuinely referential uses of `it`.
- Three parent private-state refusals, including a compound grammatical-it and
  other-conversation request, with no bypass or extra call.
- Separate-session isolation and already answered parent replies.
- Exact equality with the current AO dummy-it pattern without loading AO.

These tests establish local conversion and refusal preservation. The controlled
parent does not test implementation of the privacy guard or a real specialist's
arithmetic, and these results are not Mini acceptance or shipped panel scores.

## Root checkpoint

Root reviewed the complete source change and reran all nine focused tests.
Private-source checkpoint: `1a6962bb78e0208da0bc41519ef51ef110918afe`.
The portable source patch is
`deploy/appliance/patches/oracle7-slim-4.9-conversation-door.patch`, to apply after
the U4 conversation repairs. The fresh combined candidate check remains pending.
