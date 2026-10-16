# Specialist gate checker

Oracle7 admits a specialist only after an exam with six tests (written in
`upstream/workbench/exam.py`): it must add enough right answers, add no false
"yes", give few wrong answers, stay out of general questions, leave "who are
you?" questions to the core, and answer fast enough. veri7vn writes that rule
down as a mathematical definition in Isabelle
(`src/isabelle/specialists/Exam_Gate.thy`), proves facts about it, and has
Isabelle turn the definition into a Standard ML program.

`check_verdicts.py` takes that program and asks it, for every exam result that
Oracle7 shipped (`upstream/root/specialists/*/verdict_*.json`), "would you have
admitted this specialist?". It then compares the answer with the decision
written in the file.

## Running it

From the repository root, after the session has been built with
`python3 tools/dev/check-native --session Veri7vn_Specialists --session-root src/isabelle/specialists --expect 'VERI7VN_SPECIALISTS PASS'`:

```sh
python3 tools/gate/check_verdicts.py --extract   # copy the generated ML out of the build (uses the build lock)
python3 tools/gate/check_verdicts.py --compile   # compile it with the MLton that ships inside Isabelle
python3 tools/gate/check_verdicts.py             # check every shipped verdict file; --json for details
python3 tools/gate/check_verdicts.py --float-check  # Python's 2% rounding equals the exact rounding used in HOL
```

Everything it writes goes under `var/gate/`. It never writes under `upstream/`.

## What the counts mean

- **checked**: files that carry every number the decision needs.
- **agree**: the program gives the same decision (and the same failure reasons) as the file.
- **disagree**: listed one by one with the numbers that caused it.
- **insufficient**: files missing a number the decision needs (most often the
  count of wrong answers, which older files did not record).

The shipped files were written by Oracle7's release gate "v2", whose source is
not in the release. Its fields are mapped onto exam.py's: `domain.head` and
`domain.spec` give the right / false-yes / wrong counts, `core.taken_by_specialist`
gives the general questions taken, `self[].same == false` counts identity
answers, `domain.spec.p50_ms` is the median time, and the budget comes from the
specialist's `manifest.json`. A disagreement therefore means "exam.py's rule,
applied to v2's numbers, decides differently", not necessarily an error in either.
