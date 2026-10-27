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

## Full packaged U4-v2 qualification

Runtime: `var/usage-20261027/candidate-u4-v2`.
APPLIANCE receipt SHA256:
`d727536c17c2f73243d63aabfac2d2850caf5d342141a84853d0d9eddcac1654`.
Final inspection provider SHA256:
`8f5235a0fb0da786f38d032a88671ad909e5bfa0912bf260e5ff16e82d7efdfa`.
Registry SHA256:
`8dce33b5ffc879a132f0a8125cb140714654da65483f14092925d65356258ba7`.

The combined full Engine run made 40 requests and their exact retries. Three
companion requests were rejected before invocation because the harness copied
dots from operation IDs into request/conversation IDs. The failed records remain
intact. Root authorized a three-request corrective run with valid fixed IDs;
weather, table and Artist then all answered correctly. No product patch or
immutable candidate edit was needed for that harness mistake.

Evidence and runners:

- `var/u4-service/u4-v2-real/{receipt.json,calls.jsonl,runtime-before.json}`
- `var/u4-service/u4-v2-real/reliability-analysis.json`
- `var/u4-service/u4-v2-corrective/{receipt.json,calls.jsonl,runtime-before.json}`
- `var/u4-service/u4-v2-analysis.json`: per-request classification and receipt hashes.
- `var/u4-service/probe-u4-v2.py` and `probe-u4-corrective.py`.

Both Engine processes used the shared engine lock and were stopped by their
recorded ownership: PID 73940 and corrective PID 76389 exited normally, code 0.
Both before/after inventories report zero new, missing, or changed size/mtime
files; receipt hashes stayed unchanged. Every one of the 43 recorded exact
retries returned the identical complete response. The two processes were
sequential. Neither remains running.

The catalog contains **350 live direct operations, one text-only declaration,
and nine unavailable operations**. The new inspector is discovered and invoked
through the actual packaged service. Meteorology-v2 inspection reports the
publisher-retained ADMIT claim separately from upstream `changed` status and
`missing_files_sha`; its explanatory field explicitly says missing digest is
not evidence that files changed. The 52 dev and 58 held-out rows are declared
counts, not freshly measured scores. No specialist code or exam ran, live
registration remains unknown to this inspector, and Mini permission is not
assessed. A missing specialist returns a completed withheld result.

The actual full-head recall case now works across `/query` to `core.query`:
“What did I just ask?” returns the earlier arithmetic question and answer with
turn 1's reference. A separate empty session reports no prior question.
Password, compound recall/password and other-conversation requests remain
withheld; a private-thought question clarifies without inventing a private fact.
The established Austen author-to-birth reference still returns 16 December 1775.

The original 15 reliability tasks give **9 correct scalar results, four safe
refusals/clarifications, two needless refusals, and no wrong numerical answers**;
7 of 10 paired expectations pass. Room area, incidental apartment number,
perimeter and conflicting dimensions now reach the intended real geometry
consumer. Spelled “five degrees below zero” and the valid 150 km/3 h speed task
remain unanswered. The three extended scope tasks (two rooms, two requested
measures, explicit square-centimeter output) receive capability explanations;
those valid calculations are still incomplete. Apartment 16 is not confused
with a dimension. Rounding 3.12 × 4 to a tenth yields 12.5; ordinary “in this
diagram” wording yields 12. Geometry still says “square units” or omits the
perimeter unit, so numeric correctness is recorded separately from a complete
dimensional answer.

The grammatical-it request after arithmetic context no longer returns the old
topic summary, but it is **still incomplete**. The full head asks whether “it”
means “times” or “multiplied,” at `act:clarify_specific`, with
`provenance.r468_door`. This remaining dialogue-reference defect was sent to
root and the conversation lane; no frozen source was changed.

Selected existing consumers remain useful: the dated Pride and Prejudice query
returns Jane Austen with Q170583/P50 references; direct Fahrenheit conversion
returns 0 °C for 32 °F; direct heat index returns 83.29043364000009 °F; the supplied
CSV lookup returns 8 with row 2's source; Artist renders the supplied two-cat
scene and passes its pixel/layout check. These local Python probes use the same
project dependency environment plus bundled Pillow 12.3 as U3. They do not
qualify Linux Pillow 11.3 or native Mini admission.

Across all 43 records, strict task classification is **18 completed, nine
appropriate refusals/clarifications, six valid tasks incomplete, seven
numerically correct with incomplete units, and three rejected harness inputs**.
No wrong answer was observed. Safe refusal and mere numeric agreement are not
silently counted as fully completed tasks. This is bounded task evidence, not a
specialist panel score or whole-system correctness claim.
