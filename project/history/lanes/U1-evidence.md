# U1 evidence: what the answer actually supports

Twelve real questions ran against the immutable passing appliance through the
shared runner. All twelve received HTTP 200; eight were `answered`, two
`clarification`, two `withheld`. Six answers completed their intended task
correctly. One selected an ambiguous person without clarification; one returned
an undefined mathematical marker as a checked answer. The other four did not
complete the requested task, including two safe refusals to unsupported or
malformed input. These are usage outcomes, not specialist scores.

**No shipped specialist panels were run. No theorem was added or established.**

## Real use and evidence

Questions and expectations were written before running. Complete responses,
exact bytes, timings and engine logs remain in
`var/usage-20261026/evidence/run-1/`; the offline inspection of all twelve is
`var/usage-20261026/evidence/inspection.json`. Consumer latency median was
0.365 seconds, range 0.010–2.667 seconds, excluding startup. Engine `latency_ms`
is not end-to-end latency: Einstein took 2.117 seconds despite reporting 0.2 ms.

| Case | Actual answer/outcome | Evidence finding |
| --- | --- | --- |
| Who wrote Leaves of Grass? | Walt Whitman, correct | `wd:Q132042 P50 wd:Q81438` plus SimpleWiki identifier. `verified_reach` is a route claim, not a theorem. |
| When was Albert Einstein born? | 14 March 1879, correct | Q937/P569 are embedded in answer prose; structured `references` is empty. |
| What is the capital of France? | Paris, correct | Q142/P36/Q90 plus SimpleWiki identifier. Extra claims about the city's nickname/size require source reading; the relation alone supports only capital. |
| What is 17 * 23? | 391, correct | `computation`, `verified: true`, steps and evaluator name. No theorem metadata. |
| Convert 10 meters to feet. | 12500/381 feet, correct | Exact rational in prose and “NIST exact factors”; no source document locator or native comparison. |
| Kinetic energy of 2 kg at 3 m/s? | 9 J, correct under the displayed classical formula | Formula in prose; no native comparison or theorem metadata. |
| When was John Smith born? | 6 January 1580, Q228024 | The explorer is selected without establishing which John Smith the user meant. The citation supports that person's date, not the identity choice. |
| Who wrote The Unfindable Purple Almanac of 2099? | Clarification | Safely invents no author, but attributes failure to parsing rather than stating a known source limitation. |
| What is 2 + * 3? | Withheld | Safe refusal; retained weak answer/canonical surface reveals a detour toward a definition of Three. It is not a calculation failure explanation. |
| What is 1 / 0? | `zoo`, “Checked: recomputed numerically”, answered | Invalid admission: later math organ replaces parent `compute:refused` withholding. |
| Is every answer you give mathematically proved? | Withheld | Does not explain assurance scope; a precision guard rejects a conversational reply. |
| List all books written by Walt Whitman. | Clarification | No list or coverage evidence, so no unsupported completeness claim is made. Task remains incomplete. |

All twelve lacked `kernel_check`, theorem statements and kernel identifiers.
The packaged w551 source limits native execution to Linux x86-64; this run was
on macOS. Missing metadata itself does not establish the cause for an individual
reply. No response's `proved` label was promoted to proof. The native-comparison
view is exercised by synthetic tests, not misrepresented as a real native result.

## Consumer improvement

`tools/usage/evidence/inspect.py` is an untrusted offline CLI that reads runner
JSONL, reply JSON or arrays. It prints complete active answers and separates
seven categories: source citation, computed value, native kernel cross-check,
proof scope, clarification/withholding, unsupported claim, unavailable metadata.
JSON mode retains the entire input unchanged; text `--raw` also prints it.
Unknown fields and historical answers survive. Historical replacement text is
not used as support for the active answer. The tool does not claim to assess the
truth of arbitrary prose or repair ambiguous person recognition.

A host/UI author or person reviewing an answer can now see what the response
actually supplies without treating a source ID, `verified`, or a theorem name as
an independently established proof. `README.md` describes these limits and use.

## Engine repair (authorized source, now frozen)

Root granted exactly
`var/ap1-upstream-slim/root/wander-train/math_organ_v1.py` for the repair.
Its base SHA256 matched the immutable appliance:
`83949940cb3a2ce8fd8597b801a69632d229fe2fa99f71cce2dceeca1b09d77a`.
Patched SHA256:
`62ad8bdc8ab0c198824c2c03c3f23625c48f365bfff53e38064d5fcae183bf11`.
A source diff is retained at
`var/usage-20261026/evidence/math-organ-finite.patch`.

The failure is a NaN comparison: SymPy evaluates `1/0` to `zoo`; complex
conversion yields non-finite components, and `NaN > tolerance` is false. The
old code consequently accepted the comparison. `equiv` had the same numeric
pattern. Both now use `finite_numeric_agreement`, which rejects non-finite real
or imaginary components and non-finite difference/bound before testing tolerance.
Finite complex values remain supported. The numerical check label now says
“finite numerical comparison using SymPy”; the docstring explicitly calls this
an untrusted heuristic using the same evaluator, not independent proof.

The repair deliberately declines values outside machine complex range. It does
not prove recognition, symbolic equivalence, or all other math-organ operations.
It does not change the immutable original/appliance. Root must provision the
combined candidate and rerun actual-engine questions; the direct source tests
below are not a claim that the deployed end-to-end defect is already fixed.

## Changed files and exact checks

Owned files: `tools/usage/evidence/{inspect.py,README.md,cases.json,expectations.json}`,
`tests/usage/evidence/{test_inspector.py,test_math_finite.py}`, this report, and the
single root-authorized source above. Raw experiment artifacts remain under `var`.

`.venv/bin/python -B -m unittest discover -s tests/usage/evidence -v`:
**17 tests passed**, 0 skipped, in 0.353 seconds. Eleven cover inspector evidence
boundaries and complete input retention. Six math tests cover direct and ordinary
question entry points, 1/0, 0/0, infinities, NaN, log(0), large overflow, ordinary
integer/rational/irrational values, and finite complex values including sqrt(-1).

The inspector ran against all twelve actual retained replies. A separate check
compared all twelve `original` objects and complete active answer strings to the
runner records: **12/12 identical**. CLI `--case zero` showed the original `zoo`
answer, its check claim, the earlier refusal and the non-finite warning together.

Remaining work: combined-appliance engine regression; disambiguate John Smith;
return structured citations for specialist facts and calculations; explain proof
scope directly; expose why native comparisons are absent. No corpus, proof build
or candidate mutation was performed by this lane.

## First combined candidate: the real consumer exposed a missing repair

`candidate-first` retained the patched v1 hash, and all 17 focused checks passed
against that source. The requested original twelve-question rerun at
`var/usage-20261026/evidence/run-integrated-1/` nevertheless stopped after the
Einstein question returned HTTP 502 `runtime_error` / `AttributeError`: author
answered, birth errored, ten were explicitly not run. Root assigned that separate
integration defect to the conversation owner.

A fresh eight-question math run at
`var/usage-20261026/evidence/run-math-integrated-1/` completed with eight HTTP 200s.
It demonstrated that the repair had **not reached the active math consumer**:
1/0 still returned `zoo`, 0/0 returned `nan`, log(0) returned `zoo`, all marked
answered and “recomputed numerically”. Ordinary arithmetic returned 391; the
finite complex result was I; conversion and kinetic energy remained correct.
The rational 1/3 was rendered as 0.333333 by the earlier closed-grammar evaluator,
not by the patched organ. It is an approximation without an explicit approximation
label, not the exact rational in the independently written expectation.

The active import chain is precise: w480 imports `math_organ_v1`, w482 overrides
`_c480_math` with `math_organ_v2`, then w490 overrides it with `math_organ_v3`.
All three reside under `root/wander-train`; there are no admitted-path duplicates
of these math modules. Looking only at w480 was an incomplete source trace.

Root granted v2 and v3 ownership. Both now import the same
`finite_numeric_agreement` helper from v1 (which has no import back to either),
and call it in direct evaluation and sampled equivalence. This avoids three
independent copies of the repaired comparison. Their check labels/docstrings
also describe the actual heuristic. Base copies matched candidate-first before
editing. Frozen hashes:

- v1: `62ad8bdc8ab0c198824c2c03c3f23625c48f365bfff53e38064d5fcae183bf11`
- v2: `5078b240a78d2b5b6d061b4d49ace4bb8f3ef04e0e13fd2ce3a93b1bc2aff5a2`
- v3: `d7e07221e2616732134053259fdbcbf6d1ab5826dbb406a571785f1098a9bfe0`

`MATH_ORGAN_SOURCE=var/ap1-upstream-slim/root/wander-train/math_organ_v2.py`
and the corresponding v3 invocation of the scoped unittest command each passed
**17/17 tests, zero skips** (0.272 and 0.262 seconds). The loader binds each module
to the v1 helper in its own selected source directory. Additional owned artifacts
are `repair-cases.json` and `repair-expectations.json`, written before that
focused real-engine run. No candidate was mutated. Another combined provision
and real-engine run is required before reporting this defect fixed end to end.

## Final combined candidate: end-to-end confirmation

The final immutable runtime is `var/usage-20261026/candidate`. Both final run
capability snapshots report deployment receipt SHA256
`e3628455a546219ad1505cd04b548a4282bff7647cc10a8c78fb30ae548b66d8`, matching
the local `APPLIANCE.json` bytes. All three math module hashes match the frozen
hashes above. This identifies the package used; it is not a proof attestation.

Original questions were rerun under `run-final-original/`: **12/12 HTTP 200,
zero HTTP or transport errors, zero not-run**. All six originally correct answers
(author, Einstein birth, capital, product, conversion, kinetic energy) are
**verbatim identical** to their original active answers. The Einstein integration
exception is gone. The 1/0 case now has status `withheld` and says division by
zero is undefined; the later math organ no longer overrides that refusal. The
remaining original behavior is unchanged: ambiguous John Smith still picks the
explorer; unknown title and complete bibliography clarify; malformed arithmetic
and proof-scope question withhold. Original-set statuses are now seven answered,
three withheld and two clarification; this is not a blanket correctness score.

Repair questions were rerun independently under `run-final-repair/`:
**8/8 HTTP 200, zero HTTP or transport errors, zero not-run**.

| Probe | Actual final outcome |
| --- | --- |
| 1/0 | Withheld; explicitly says division by zero is undefined. |
| 0/0 | Withheld; explicitly says division by zero is undefined. |
| log(0) | Clarification; no `zoo`/`nan` admission. The explanation still says parsing failed, so the refusal is safe but not informative about the mathematical domain. |
| 17 * 23 | 391, answered. |
| 1/3 | 0.333333, answered by closed grammar; the preexisting unlabeled approximation remains. |
| sqrt(-1) | I, answered; check now says “finite numerical comparison using SymPy”. |
| 10 meters to feet | 32.80839895, exactly 12500/381 feet, answered. |
| 2 kg at 3 m/s kinetic energy | 9 J, answered. |

This establishes the repaired non-finite admission behavior through the actual
engine, plus preservation of the supported finite complex result. It does not
establish completeness or correctness for all symbolic expressions.

The final inspector also distinguishes a refused computation from a returned
computed value: `provenance.kind="computation"` on a withheld answer no longer
creates a computed-value observation. One regression was added for this observed
reply shape. **18/18 scoped tests passed, zero skipped**, against the final v3
source and its same-package v1 helper (0.261 seconds). The inspector processed all
20 final records; all 20 complete original objects and active answer strings were
preserved exactly. JSON inspections are retained as
`inspection-final-original.json` and `inspection-final-repair.json` under the
lane's private scratch directory. No final candidate files were changed.

No specialist panels were run in this lane; no new theorem claim is made.
Remaining defects are the ambiguous identity choice, unlabeled 1/3 rounding,
missing structured citations/proof scope, and uninformative log(0) clarification.
