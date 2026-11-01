# F computing: complete Python reference batches

Owner: Codex computing deputy. **READY / source frozen**; root integration and package capture pending.
E integrated `2cf1b55`, exact binary `220348be` captured before these edits.

The actual E binary answers only the first matching API when a question names
multiple APIs. It also applies one globally chosen role to a mixed-role request:
"What is the signature of len and the module of os.remove in Python?" returns
only the signature of os.remove. "Describe os.remove and os.mkdir" silently
omits the missing entry. Five exact replies are recorded in
`var/computing-next/python-batch/before.json`.

F adds typed jobs `(role, name candidate)` and a bounded whole-request grammar
for comma/and/semicolon name lists and explicit role clauses. Each job resolves
independently through the existing reference kernel, retaining request order.
A complete answer requires every job's reference entry and requested field.
Partial coverage retains named known/unknown results with `status: withheld`,
kind `reference_incomplete`; unsupported residual clauses use `reference_scope`.
A valid request with any unsupported part remains valid-withheld, even when the
partial-result policy assertions pass. No new status value is introduced.

The proved theorem connects every job of a successful batch to its own
resolved source row and requested signature/module/description field. A separate
coverage iff requires all jobs, not merely one successful lookup. The reference
remains partial and untrusted data; neither API execution nor English parsing is
proved. Other computing-family capabilities and E history are unchanged.


## Initial evidence

`f_probes.py` supplies gold role/name jobs independently of the recognizer and
reads expected fields from the original reference plus the D extension. Both
Python IDs receive the same cases independently. Seed 821533 has 60 whole
requests; E baseline is **0 correct, 36 incomplete/wrong for the request, 24
valid withheld**, with **0/60 policy assertions**. All requests here are
meaningful, including unsupported residual clauses and missing-reference cases;
no false-yes count is manufactured by relabeling those as invalid.
`var/computing-next/python-batch/F-before.json` retains every reply.
Evaluation seed 936719 was reserved until the implementation froze. Only 12
randomized role/name pairs per ID vary; fixed semantic cases repeat.

Managed hbox proof attempt `20261018T101734Z-225391f1fb36` failed after 1m32s: the coverage proof needed an explicit six-field tuple witness, and the local fact name `value` collided with reserved syntax. The proof now decomposes the row with `prod_cases6` and names the field fact `field_result`; the statement is unchanged. Retry `20261018T102807Z-36efc3084e2f` passed in 2m33s with `VERI7VN_COMPUTING PASS theorems=133 oracles=0`. The parser
has received source-only refinements for final "do" in description lists and
plural module/signature phrasing; the native manifest will capture those exact
untrusted inputs separately from the proof snapshot.

## Exact proof obligations

For a typed job `(q,c)`, coverage means that `py_resolve [c] = PyFound nm`,
`py_lookup nm = Some e`, and a requested signature is nonempty. The batch
completeness theorem states:

`answered (py_batch_reply jobs) iff jobs ≠ [] and every job in jobs is covered`.

For every `PyJob q c` in an answered batch, the source correspondence theorem
provides a row `e` in `py_entries`, with `pe_name e = nm`, that same independent
resolution and lookup, and
`stated (py_job_reply (PyJob q c)) = Some (py_field q e)`. Thus a signature job
cannot borrow a neighboring job's module or source row. The emitted per-job
text retains each job's role and candidate name. Mapping the jobs to text
preserves their length and indexed order; this structural fact accompanies the
source and coverage results, rather than substituting for them.

The parser consumes an optional comma with the trailing `in Python` qualifier
before testing list delimiters. This matters for 55 original single-name panel
questions of the form "Which module is X in, in Python?". Source inspection
found and repaired this boundary before F native compilation; the shipped
panel verifies it on the actual F binary.

## Current changed files

- `src/extract/computing/Pyref_Batch.thy`: typed reference jobs and complete batch consumer.
- `src/extract/computing/ROOT` and `Computing_Export.thy`: session, export and proof audit wiring.
- `src/extract/computing/recognizer.sml`: bounded complete list/role grammar.
- `src/extract/computing/capabilities.json`: existing status vocabulary, new batch/refusal kinds.
- `src/extract/computing/f_probes.py`: independent explicit-job consumer checks.
- `src/extract/computing/README.md`: capability and boundary documentation.
- `project/lanes/F-symbolic-computing.md`: this report.

## Final receipts and results

- Proof: `var/computing/remote-attempts/20261018T102807Z-36efc3084e2f/receipt.json`, passed; session log marker **133 theorems, 0 oracles**. Both new semantic claims and source correspondence are on the audited export path.
- Native: `var/computing/native-attempts/20261018T103818Z-666b768a9413/compile-inputs.json`, compile passed, current proof dependencies match, exact four-input compilation graph frozen.
- Binary SHA-256: `c29f829132bfd83c55c390e65e426d342e28bbea890b1c8226647462d5160725`.
- `gen_pyref.py --check`: 857 rows; `tables_check.py`: **18/18**.
- Tuning seed 821533: **60/60 policy assertions; 46 correct, 0 wrong, 14 valid withheld**.
- Reserved evaluation seed 936719, first used after native/parser freeze: **60/60 policy assertions; 46 correct, 0 wrong, 14 valid withheld**. Only randomized pairs differ; fixed cases repeat.
- Actual computing-scoped dispatcher: **60/60**, same capability counts, with code/reader/document/routes disabled explicitly.
- Existing C probes **40/40**, D policy assertions **63/63**, E policy assertions **50/50**. D/E withheld requests retain their original capability labels; their policy passes are not new answered capabilities.

All nine shipped panels, using their own scorers: **1364/1364 right, 0 wrong,
0 false yes, 0 valid withheld**. Dev/heldout counts:

| Specialist | Dev | Heldout |
|---|---:|---:|
| networking | 74/74 | 71/71 |
| embedded | 25/25 | 25/25 |
| cyber | 20/20 | 20/20 |
| linux-v2 | 42/42 | 42/42 |
| git | 10/10 | 10/10 |
| sql | 61/61 | 61/61 |
| python | 198/198 | 224/224 |
| python-r2 | 198/198 | 224/224 |
| robotics-v2 | 36/36 | 23/23 |

Both `score.py` and the scoped parity harness agree. Harness state is still
INCOMPLETE because this check does not provide head/core/LANE/SELF/full-budget
admission artifacts; it is not a new global ADMIT declaration.

Exact outputs are under `var/computing-next/python-batch/`: `F-tune.json`,
`F-eval.json`, `F-shipped.json`, `F-parity/`, `F-C-regression.json`,
`F-D-regression.json`, `F-E-regression.json`, and `F-composition-scoped.json`.

The first actual dispatcher run, retained in `F-composition.json`, had **58/60
policy assertions**: for both Python IDs, "Describe os.remove and write a
recursive function in Python" was intercepted by the independent code front
stage and withheld as `code_program_refusal`, before computing. It was not a
wrong answer, but it did not expose computing's `reference_scope` explanation.
The explicit computing-only consumer test adds `--no-code` alongside the other
already disabled roles and passes 60/60. This distinction is retained, not
relabeled as an all-stage 60/60 result; no global routing change belongs to F.

## Limits and drain state

The bounded grammar handles comma/and/semicolon lists and explicit role clauses,
not arbitrary Python questions or program execution. Parsed roles and names,
reference transcription, and JSON/English rendering remain untrusted. Missing
coverage does not establish runtime nonexistence. Incomplete batches remain
valid withheld even when known items are useful. F proves row/field coverage,
not the completeness or truth of the external reference.

The current packet is finished and frozen pending root's ordinary integration
and immutable package capture. No proof collector or native compiler remains
running. No successor scope is open. Historical C/D/E reports and immutable
artifacts are unchanged.
