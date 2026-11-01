# Supplied modeling: direct capability, failed composed admission

The original Workbench examiner returned **NEGATIVE** on the modeling heldout
panel. This is a failed delivery through its core-first composition, not a newly
admitted specialist. The lane also supplied inappropriate composed-control gold;
that flaw must remain explicit rather than be blamed on the examiner.

The [committed receipt](../../native/evidence/2026-10-31-native-route-validation.json)
retains the complete verdict. Raw evidence is in
`var/native-route-20261031/modeling-admission/receipt.json`. It binds the original
exam SHA256 `86d8a4b1b1c649854e44785d9c1451dd39462ed1c9e4c7d3c070b5ae3c43fb18`,
the 924-question general-panel SHA256
`ce5e2a62783b7a87ac2084933f634774cb2123ec94ad61bcc1e1cfca375478f6`, and separate
actual core evidence digests. The prepared U8 materialization receipt is
`ba58f621eae7795bfa7a2799a9797b54c7ecf758130c7db6985fb3cb3bf61b9d`.
The original 30-second cold timeout remains separate evidence; the central runner
reports all 28 subsequent prepared baseline requests completed with HTTP200.

| Original examiner result | Dev | Heldout |
| --- | --- | --- |
| Decision | WOULD FAIL | NEGATIVE |
| Head / composition scored right | 6 / 6 of 14 | 5 / 5 of 14 |
| Domain gain, required gain | 0, 3 | 0, 3 |
| Valid answered wrong, allowed maximum | 2, 1 | 2, 1 |
| Reported false yes, head / composition | 2 / 2 | 3 / 3 |
| General questions taken, cap | 0, 9 | 0, 9 |
| Self criterion | passes | passes |

These are the retained examiner numbers, including the control-gold defect below.
They are not a corrected retrospective score. No production/scorer changes or
re-examination were made for this diagnosis.

## Two different problems

The generic language cascade claims structured modeling requests before the new
specialist can own them. In the dev examples, the core answers calibration JSON
with an unrelated arithmetic mean, `19/8` or `19/7`. Heldout similarly returns
`17/8` and `15/8`. Those computations do not answer the declared calibration
operation, even if their own arithmetic agrees by another method. The pointwise
calibration case instead gets a generic word-problem refusal. GLM requests get
“Python 3.12.3's statistics has no events_exposure,” a documentation reading of an
operation identifier rather than execution of the supplied statistical model.
All these failed answers are attributed to the core in the actual verdict.

The original exam deliberately preserves an answered core reply. It invokes an
extension only after a nonanswered reply whose path its `fillable` rule admits.
The core-first design therefore cannot replace the mistaken mean answers. The
source's word-problem refusal path is `operator:unparsed|vessel:receipt`, which
that original Workbench rule does not admit; generic specialist documentation
paths are likewise not automatically fillable. Renaming identifiers or changing
serialization to dodge those routes would hide the missing ownership boundary.
Direct hosted numerical success does not establish composed delivery.

Separately, the lane used a standalone routing test as composed answer gold.
`scorer.py` treats every `lane_control` as correct only when no answer is asserted;
the panel also marks those items `valid:false`. That is appropriate for the new
organ alone returning `None`, but wrong for the whole system. “Who are you?”
should retain the core's identity answer, and “What is the mean of 1, 2, 3?” should
retain its correct answer 2. The unchanged original exam consequently counts
those legitimate core answers as false yeses in both head and composition.
The two false yeses shared by each split include these control errors; heldout
also contains an asserted mean on a malformed calibration request. Do not call
all the reported false yeses modeling faults or treat equal counts as evidence
that the composed gold is sound. This was an authored panel/scorer design error.

The verdict display says `(decline)` whenever an item lacks an `a` display field;
modeling's analytic gold lives in its values/interval fields. That display is
unhelpful but does not explain away the negative result. Likewise the reported
0.0 ms median includes 924 fast out-of-lane checks and does not measure useful
model-call latency.

## Next delivery design

Give explicit structured requests an owner **before** the generic language
cascade. An admitted exact prefix/envelope selects the existing declared
`statistics.calibration` or `statistics.events_exposure` operation. That owner
checks complete supplied rows, units, grouping/exposure and assumptions; invokes
the actual Rust host; and retains its numerical status, diagnostics, exact
certificates and independently replayed evidence. Invalid owned input is refused
by that owner. Transport or resource failure remains execution failure, not a
successful semantic refusal and not permission to feed the JSON to a mean or
Python-documentation recognizer. The existing direct `/invoke` operations already
provide the computation boundary; a conversational adapter must deliberately
connect to it. Unprefixed ordinary questions keep their ordinary owners.

Keep standalone routing controls separate from composed answer gold. Test that
the new organ returns `None` on identity/general questions, then independently
judge the composed system's identity provenance and its numerical answer 2 on
the ordinary mean question. Add independent exact supplied-model results,
malformed owned input, absent required assumptions, model refusals, unavailable
host, unsupported operations and outside-prefix controls. Do not merely compare
the system to its own prior prose or count every abstention as correct.

That ownership policy is a design change, not a repair to this already-used
heldout set. Preserve the present raw verdict and its declared flaw. Write fresh,
independent dev/heldout cases and truthful composed gold before a future admission
run; measure the actual new composition as well as the original gate where
applicable. This lane has not implemented or qualified that next ownership layer.
