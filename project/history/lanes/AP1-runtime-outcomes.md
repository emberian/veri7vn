# AP1: record the reply actually delivered

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

26 October 2026. Source: Oracle7 slim `083e3a6c`, private contribution checkout
`var/ap1-upstream-slim`. Owner: Codex `runtime_outcome_fix`. Root owns Git and
upstream submission. No specialist panel score or theorem claim is made.

## Behavior and consumer

The previous w558 remembered a lower reader's answer before w568/w571 could
replace or withhold it. The residue ledger and AN transition history likewise
recorded that intermediate result. A withheld Beethoven answer could therefore
supply the next turn's pronoun referent. Replacement replies also copied the old
answer's `proved`, `kernel_check`, `value`, and `kind` fields.

The w557 class now wraps descendant `chat` implementations at class creation.
Only the outermost call for the same runtime instance and session commits state.
This includes w435/w436 routes that return without calling their parent and new
future tip subclasses. Inherited methods stay wrapped once; method metadata is
preserved. Context-local frames distinguish nested sessions and are cleared even
when a call raises. The Engine already serializes runtime calls; this patch does
not make the runtime's mutable stores generally safe for concurrent callers.

The final boundary reconciles exactly four known in-memory stores: `dialogue`,
`transitions`, `_pending_conversion`, and `_paths`. AN's existing transition
recorder was extracted into `_record_turn` and reused, so final output terms,
continuity measurements and path history come from the delivered reply. A changed
or withheld answer cannot keep the speculative topic. A final refusal still has
a record for explanation. Supported unchanged answers and acts retain their
useful state; an unsupported answer remains a ledger-only discourse record.
This is not rollback of arbitrary fold attributes, databases, files or side effects.

w558 now commits its pronoun record only from the final reply. Re-entry requires
a supported answer to the rewritten question and preserves two distinct receipts:
`reentry.referent_evidence` identifies the prior delivered answer establishing the
referent; `reentry.source_reply` is the result of the new rewritten question.
Retained referent evidence is deep-copied and limited to 64 KiB encoded. An
oversized record is omitted instead of retaining truncated evidence. Immediate
answer sources are retained without recursive ancestry of older re-entries.

w558 re-entry and w568 title replacement preserve terminal refusals using the
shared guard. All w568/w571 replacement branches use `replacement_reply`, which
removes stale answer attribution/value fields. The runtime-guards lane adopted
that helper for its own replacement paths as well.

## Changed files

Within `var/ap1-upstream-slim`:

- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w557.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w558.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w568.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w571.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/runtime_final_outcome.py` (new)
- `root/wander-train/oracle_release_runtime_an.py`
- `tests/runtime_outcomes/test_final_outcome.py` (new)

`runtime_refusal_guard.py` is the other lane's dependency. No changes were made
to its files. The only main-checkout change from this lane is this report.

## Checks

From the private checkout:

```
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/runtime_outcomes -v
```

**18 tests passed**, 26 October. These load the real w557/w558/w568/w571/w435/w436
folds and real AN recorder, with explicitly controlled lower readers, stores,
relation routers and premise predicates. They test:

- Withheld Beethoven never enters pronoun/history state.
- Valid Jane Austen re-entry and Jane → George → birth multi-turn composition.
- Exactly one final record for ordinary, direct-tip and nested same-session turns;
  separate records for nested different sessions.
- Supported acts retain the previous answer; unsupported answers do not become state.
- Exception cleanup and a successful following turn; inherited method metadata.
- Terminal pronoun/title refusals are preserved.
- All reading replacements and premise withholding remove stale answer evidence.
- Prior-answer and rewritten-answer receipts are distinct, mutation-isolated and bounded.
- Standalone w557 and w558 retain their instrumentation.

`git diff --check` passed. These are component/composition checks, not natural
language panel scores or a full installed-runtime qualification. No Isabelle,
MLton, proof suite or large store was used. Full-runtime smoke and contribution
submission remain root integration work.
