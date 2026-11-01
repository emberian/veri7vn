# AP1 runtime guards — 2026-10-26

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

Implemented in the private slim checkout `var/ap1-upstream-slim`, on root's
`codex/swarm-quantity-admission` branch. Root owns commits and integration.

A kernel disagreement now survives the later coverage fallbacks instead of
becoming an answer again. An ordinary missing record still permits a composed
calculation or a relation-store answer. A newly computed answer does not inherit
the old answer's `proved`, `kernel_check`, `value`, `kind`, or re-entry fields.

## Changed source

Under `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/`:

- New `runtime_refusal_guard.py`: recognizes an explicit terminal `kernel_check`
  or `refusal` receipt, plus delimited legacy disagreement/deliberate-verdict
  path tokens. It also constructs local terminal composed refusals. This is an
  untrusted Python policy, not a theorem.
- `oracle_release_runtime_w554.py`, `w562.py`, `w563.py`, `w564.py`, `w565.py`,
  `w566.py`, and `w434.py`: stop before replacing a terminal refusal. Ordinary
  replacement sites use the outcome lane's `replacement_reply` helper to clear
  stale answer fields.
- `w565.py`: replaces first-answer list selection with a census of the accepted
  composed computations, using the existing combiner's manifest acceptance and
  isolated organ calls. Exactly one accepted computation must remain, and each
  unquoted numeric input must move its comparable answer under a probe. Two
  candidates, including two with identical output, are not a unique reading.
  Ambiguity, unused inputs, out-of-domain responses, and failure while validating
  an identified candidate produce terminal local refusals. Failure to load an
  otherwise absent family still permits ordinary relation-store coverage.

The existing combiner's numerical probe includes program constants when it reads
an output number. That made valid zodiac and weekday replies appear independent
of their inputs. The w565 probe now checks only the answer before the composed
program receipt, leaving the full displayed receipt intact. It also compares
output numbers directly: the combiner used to suppress an output equal to an
input, so the constant answer 2 incorrectly appeared to move when input 1 was
perturbed to 2. Numeric comparisons now require unchanged labels and units;
changed reading kinds, refused probes and missing probes are inconclusive. A second unit nudge
handles the period alias in day 100 → 107, which preserves the weekday. Admission
checks all unquoted numbers rather than the combiner's general six-number cap.

`runtime_final_outcome.py` is owned by the outcome lane. That lane also guards
w558's pronoun re-entry and w568's title route, two additional refusal erasers
found in the ancestry review. The pre-parent worker routes were inspected as
well; they do not consume and replace a prior refusal.

## Checks

New `tests/runtime_guards/test_runtime_guards.py` loads actual fold classes with
controlled parents and optional routers, and uses actual combiner acceptance and perturbation methods.
It does not import the full runtime or load relation corpora.

Command from the private slim checkout:

```
python3 -W ignore::ResourceWarning -m unittest discover -s tests/runtime_guards -v
```

Result: **19 tests passed**. Existing composed organs open their small spec files
without closing them explicitly, so this invocation suppresses their unrelated
ResourceWarnings. The first run with warnings enabled also passed.

Coverage includes explicit and legacy terminal contradictions, ordinary fallback
gains, both candidate orders, equal-output ambiguity, ignored numbers (including
a seventh input), failed candidate validation, and unavailable-family recovery.
Replacement tests check that the former answer's kernel/proof/value fields are
absent. Terminal paths and receipts remain unchanged. Additional regressions
cover constant output/input coincidence, identity output that legitimately
equals its input, numeric-format-only changes, changed units, and missing or
refused counterfactual replies.

Four bounded source-data probes use the actual shipped composed folders:

- Celsius 20 → 293.15 K (`cmp3-l10`), answered.
- Zodiac year 2024 → dragon (`cmp3-k6`), answered.
- Day 100 of the shipped 2025 calendar → Thursday (`cmp3-l7`), answered.
- Celsius −300, withheld as outside the absolute-zero domain.

**No shipped specialist panels scored in this lane. No new theorem statements.**
These checks establish the repaired policy on controlled cases and preserve three
real fallback examples; they do not establish whole-runtime correctness or a
panel-score gain. Counterfactual dependence remains a heuristic. A specialist
can still misread a question while depending on its numbers, and a probe can
miss dependence that appears only outside the two sampled perturbations.

## Consumer and remaining integration

The latest slim runtime reaches these folds through its existing ancestry. The
producer-side w551 change is in the separate GitHub snapshot owned by
`upstream_proved_fix`; root must transfer it to the slim checkout before claiming
the structured kernel receipt works in the packaged runtime. The legacy path
also remains supported for the current slim w551.

Root must integrate the outcome helper with these changes and exercise the
combined serving ancestry. No corpus downloads, Isabelle builds, full suites,
commits, or pushes were performed by this lane.
