# Computing usage: source bases must survive the parse

Owner: Codex computing lane, 2026-10-26.

The immutable appliance completed 6 of 15 ordinary programming tasks correctly,
usefully refused an unsorted binary search, gave 1 wrong answer, and left 7 tasks
incomplete through unnecessary clarifications or unrelated refusals. An 8-turn
follow-up found 4 further wrong base-conversion answers and 4 correct answers.
These are 23 actual usage replies, not a specialist score. **No specialist
panels were run.** No new theorem or verified-kernel claim is made.

The important defect is a source-base binding error. `Convert binary 11111111 to
decimal.` returns `11111111`, with `verified: true` and a claim that two methods
agree. The correct value is 255. Explicitly saying `from base 2` does not help:
the parser stores the source base, but both arithmetic implementations use an
integer parsed as decimal. Agreement therefore checks the wrong question.

## Retained actual tasks

Inputs and independently written expectations are under
`tools/usage/computing/`. Complete responses, exact encoded bytes, paths,
provenance, timing, and adapter logs remain in:

- `var/usage-20261026/computing/run-1/` — 15 tasks, all HTTP 200, finished.
- `var/usage-20261026/computing/run-2/` — 8 follow-ups, all HTTP 200, finished.

| First-run task | Independent expected result | Actual result | Judgment |
| --- | --- | --- | --- |
| Decimal 255 to hex | ff | ff | Correct |
| Binary 11111111 to decimal | 255 | 11111111, marked verified | Wrong |
| Unsigned wrapping 8-bit 255 + 1 | 0 | Asks what “it” means | Unnecessary clarification; antecedent is in the same question |
| 8-bit timer, 16 MHz, prescaler 64 | 1.024 ms overflow period | Asks what “it” means | Unnecessary clarification |
| Shortest A-D path, edges A-B 4, B-D 3, A-C 2, C-D 2 | 4 via A-C-D | Related dictionary passage, withheld | Routing failure |
| Directed A-B-C graph, path C to A | Unreachable | Related dictionary passage, withheld | Routing failure |
| Directed A-B 4, B-C -3, A-C 8 | 1; an explicit negative-weight refusal is acceptable | Related dictionary passage, withheld | Unhelpful refusal, not a negative-weight boundary explanation |
| Minimum spanning tree of first graph | 7 | Withheld after dictionary substitution | Routing failure |
| Binary search for 7 in [2,9,7,12] | Refuse unsorted input | Refuses unsorted input | Useful refusal |
| Binary search for 7 in [2,7,9,12] | Index 1 | Index 1, zero-based | Correct |
| Choose 3 test cases from 8, ignoring order | 56 | Word-problem guard withholds | Incomplete; metadata contains 56 but the answer remains withheld |
| (p -> q) -> (!q -> !p) | Tautology | 4/4 rows true | Correct |
| Worst-case quicksort time | O(n²) | O(n²), average O(n log n) | Correct |
| SQLite count all/non-NULL/distinct over [1,NULL,1] | (3,2,1) | (3,2,1) | Correct |
| SQLite SUM and COUNT over an empty table | (NULL,0) | (NULL,0) | Correct |

The follow-up used new conversation IDs and explicit expectations written before
querying. `11111111 from base 2`, `17 from base 8`, and `0010 from base 2` yielded
11111111, 17 and 10 instead of 255, 15 and 2. Invalid `102 from base 2` yielded
102 rather than declining. All four were wrong. The decimal-to-hex control was
correct. Removing “it” from the timer question, dropping “Find the” from the
shortest-path question, and asking `8 choose 3` yielded the correct 1.024 ms,
4, and 56. Those three are wording workarounds, not engine repairs.

Median observed request latency was 0.193416 seconds (maximum 2.916712) in the
first run, and 0.0548 seconds (maximum 1.048387) in the follow-up. Whole-run times
were 24.010 and 8.823 seconds, respectively; these are single runs, not a load
benchmark. No request failed at the transport layer.

## Concrete repair and caller

Root granted the lane ownership of only
`var/ap1-upstream-slim/root/wander-train/oracle_operator_specs_v1.py` among the
shared source modules. Before editing, its bytes matched the immutable candidate:
SHA-256 `d508db1412b63f2de918b6bb34c162963ed4577e1b82a3b554ef26b4c6018330`.
The repaired file SHA-256 is
`94a8f66d9c70cf405d2b2d97eb8d402a06ead952f987b0fac3022d48743d70e9`.
The tracked `tools/usage/computing/source-base.patch` retains the exact repair.
Neither immutable candidate nor original upstream was edited.

The parser now retains the original digits, source base, target base and decoded
integer. It reads common named binary/hex forms and `0b`/`0o`/`0x` prefixes,
rejects invalid digits and conflicting sources, and refuses to take a numeric
suffix from a malformed or multi-question request. Its narrow grammar accepts
non-negative integers only, with up to 128 digits. The main function decodes
source digits with `int` and divides repeatedly for output; the reference expands
source digits positionally and uses output powers. It no longer validates a
single mistaken decimal input twice. Both still trust the same parser; the
provenance description states that limit.

`base_workflow.py` also supplies a reusable caller. It keeps caller source digits
and base explicit, emits runner-compatible input, computes a separately labelled
local expectation and inspects actual replies. It distinguishes input-binding
errors from wrong output values, retains the whole original record, checks the
request matches, and never turns a withheld reply into an answer. Applied to the
actual explicit-binary failure, it returned `wrong_input_binding`; evidence is in
`var/usage-20261026/computing/source-binding-inspection.json`.

Changed owned files:

- `tools/usage/computing/cases.json`, `expectations.json` — original 15 tasks.
- `tools/usage/computing/base-cases.json`, `base-expectations.json` — 8 follow-ups.
- `tools/usage/computing/base_workflow.py`, `README.md` — reusable explicit-base caller/checker.
- `tools/usage/computing/source-base.patch` — actual shared-source repair.
- `tests/usage/computing/test_base_conversion.py` — narrow regression checks.
- `project/lanes/U1-computing.md` — this report.

Check: `.venv/bin/python -B -m unittest discover -s tests/usage/computing -v`.
Exact result: **11 tests passed**, including 6,125 source-base/target-base/known-
value combinations, original counterexamples, hex/prefix forms, invalid digits,
negative/malformed signs, source conflicts, zero/leading zeros, and refusal
preservation. This imports only the repaired operator and caller; it is not a
full-engine check. Root owns combined provisioning and rerunning these task packs
against the repaired appliance. No specialist panel numbers are claimed.

## Why an agent would call it

For integer conversion, Python's `int(digits, base)` is simpler and substantially
cheaper than an Oracle engine request. Oracle's potential value here is a common
natural-language interface across logic, SQL NULL semantics, algorithm facts and
physical timer calculations, with explicit refusal and retained route evidence.
The actual SQL and logic tasks show that breadth working. The routing failures
and incorrect verified conversion show why an agent should not treat the word
“verified” as proof of faithful interpretation. The caller serves integrations
that already use Oracle and need to inspect that boundary; it does not make
Oracle a better calculator than Python.

Remaining work: provision and exercise the repaired source through the real
engine, fix same-turn antecedent handling and graph dispatch, and investigate
negative-edge parsing when the graph specialist is actually reached. Those are
separate from this source-base repair. The discovered graph organ regex cannot
consume signed weights, so the initial head refusal must not be called evidence
that negative edges are handled correctly.

## First combined-appliance check: repair not active yet

The real shared runner reran both original packs against
`var/usage-20261026/candidate-first`, with fresh workspaces under
`var/usage-20261026/computing/integrated-1/` and `integrated-2/`. All 23 requests
completed over HTTP 200. The outcomes were unchanged: 10 correct answers,
1 useful refusal, 5 wrong source-base answers and 7 incomplete responses.
In particular, binary 11111111 still became decimal 11111111, and invalid binary
102 still produced an answer marked as checked. These are retained failures.

This is an integration failure, not evidence that the revised arithmetic works
in the running product. All 11 narrow tests pass when pointed at the combined
candidate's `root/wander-train/oracle_operator_specs_v1.py`; however, the adapter
loads `oracle7.py`, whose lines 55–56 put the `self_loop/admitted` directory ahead
of `wander-train` in Python's import path. Its admitted copy of the same module
still has the original SHA-256
`d508db1412b63f2de918b6bb34c162963ed4577e1b82a3b554ef26b4c6018330`.
The engine therefore imports the unrepaired copy. Root was notified to synchronize
the admitted source and refresh its admission metadata through packaging. The
lane did not edit the immutable candidate or admission hashes. The repair remains
unproven end to end until a rebuilt candidate uses it and these cases pass.

Root then authorized the exact private Slim admitted module. Its bytes matched
the original wander source exactly, so the lane synchronized the complete repair
without losing admitted differences. Both repaired source locations now have
SHA-256 `94a8f66d9c70cf405d2b2d97eb8d402a06ead952f987b0fac3022d48743d70e9`.
The tracked patch covers both paths. All 11 checks pass against the admitted
module, and the test defaults now target that imported copy. Admission metadata
was not rewritten. Root will rebuild and supply the next immutable candidate.

## Final combined-appliance result: original defect repaired end to end

Both unchanged task packs were replayed through the shared runner against
`/Users/ember/dev/o7vn/var/usage-20261026/candidate`. Identity at execution:

- `APPLIANCE.json` SHA-256: `e3628455a546219ad1505cd04b548a4282bff7647cc10a8c78fb30ae548b66d8`.
- `PACK_MANIFEST.json` SHA-256: `207bfc32650d914dac43ede0edfc797b312739e338fdd37da113b41d0ffaec15`.
- Both working/admitted converter module SHA-256: `94a8f66d9c70cf405d2b2d97eb8d402a06ead952f987b0fac3022d48743d70e9`.

Complete retained evidence is in `var/usage-20261026/computing/final-1/` (original
15 tasks) and `final-2/` (8 follow-ups). Each run completed with all requests
HTTP 200. Evaluation uses the original independently written expectations.

| Pack | Correct answers | Useful refusals | Wrong answers | Incomplete/unhelpful |
| --- | ---: | ---: | ---: | ---: |
| Original 15, initial appliance | 6 | 1 | 1 | 7 |
| Original 15, final appliance | 7 | 1 | 0 | 7 |
| Follow-up 8, initial appliance | 4 | 0 | 4 | 0 |
| Follow-up 8, final appliance | 7 | 1 | 0 | 0 |
| Combined final usage cases | 14 | 2 | 0 | 7 |

All five original wrong answers are resolved: ordinary `binary 11111111` and
explicit `11111111 from base 2` now yield 255; octal 17 yields 15; binary 0010
yields 2; invalid binary 102 is withheld with `verified: false` and the specific
reason that valid source-base digits are required. The source-base answers use
`op:base_convert`, and their provenance now explicitly says both arithmetic
methods still depend on the same untrusted parse. The caller applied to the
actual final explicit-binary record reports `matches_local_check`; its unchanged
full record and local expectation are retained in
`var/usage-20261026/computing/final-source-binding-inspection.json`.

Every previously correct answer and the useful unsorted-search refusal remains
correct. In the original 15-case pack, only the binary conversion's answer/path/
status comparison changed; the other 14 result triples are unchanged. Thus the
same-turn “it” clarifications, graph routing failures, minimum-spanning-tree
refusal, and ordinary-wording combination refusal remain open. The clearer timer,
short graph, and `8 choose 3` workarounds still succeed. The quicksort answer is
correct, but its inherited provenance still describes a weaker definition
retrieval; the result's correctness does not repair that evidence mismatch.

Median observed latency was 0.151401 seconds (maximum 2.592892) for the original
pack and 0.071287 seconds (maximum 3.091428) for the follow-ups. Whole-run times
were 13.459 and 9.184 seconds. These are single-run observations, not a performance
claim. No further source change was needed. This establishes the base repair in
the real combined appliance on these cases; it does not establish universal
parser correctness. **No specialist panels were run and no new theorem is claimed.**
