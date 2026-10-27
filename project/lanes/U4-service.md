# U4: specialist inspection through the appliance

The existing service now registers `workbench.specialists.inspect` from the
fixed `ExamInspection` provider. Agents can discover its inputs and invoke it
through the same bounded, journaled operation route as other capabilities.
The implementation inspects retained specialist declarations and exam records;
it does not execute a specialist, run an exam, or grant Mini permission.

Changed files owned by this lane:

- `tools/appliance/operations.py`: add the fixed extension provider.
- `tests/appliance/test_operations.py`: include the fifth optional provider in
  the failure-isolation assertion.
- `tests/appliance/test_exam_integration.py`: exercise the actual inspection
  provider through the production service registry, using a fake head.

Packaging needs `adapter/exam_inspection.py`, copied from
`tools/oracle_workbench/exam_inspection.py`, and the existing pinned runtime's
`workbench/exam.py`. The inspector uses that source's `status` and `files_sha`
functions. It imports no specialist or scorer. Existing candidate directories
and Mini v5 remain unchanged.

## Checks

`.venv/bin/python -B -m unittest discover -s tests/appliance -p test_exam_integration.py -v`
passed **3 tests**. They use the actual pinned Workbench exam module, a captured
fixture specialist whose Python would raise if imported, and the fixed deployed
adapter import location. They check:

- discovery, real inspection, exact replay before and after service restart;
- matching retained file binding remains distinct from measured execution,
  live registration and Mini permission;
- held-out questions and answers are absent, runtime bytes remain unchanged,
  and temporary inspection copies are removed;
- path injection is a 400 validation error; a missing specialist is a completed
  withheld result; missing exam source is discoverable as unavailable and
  invocation returns 409.

`.venv/bin/python -B -m unittest discover -s tests/appliance -p test_operations.py -v`
passed **10 tests**, including optional-provider isolation, shared conversation
handling, durable request identity, schema validation and symbolic evidence.

No specialist panels or new theorems were run or changed. These are service
composition checks, not a full Engine or native Mini admission receipt. The
consumer is the existing Mini operation discovery/call path; full Engine
qualification waits for the combined fresh U4 candidate.
