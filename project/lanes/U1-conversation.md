# U1 conversation: corrections must change the next turn

26 October 2026. Owner: Codex conversation lane. **No specialist panels were run.**
These are real conversation experiments and narrow Python regressions, not panel
scores, theorem claims, or proof/admission authority.

## What the user can do now

In the tested private repair, an author answer supports a birth-date follow-up,
including after changing the book. A fresh conversation does not inherit another
conversation's author. A numerical correction updates the result used by the
next calculation: `14 * 6` → `84`; divide by seven → `12`; correct the original
multiplication to `21 * 6` → `126`; divide by seven → **18**, not **1.714286**.
An explicitly new topic whose author cannot be answered no longer leaves the
previous author available to `he`. Ordinary arithmetic survives `Thanks`, and
solving `x + 3 = 8` supports `What is x squared?` → `25`.

The original immutable candidate has not changed. Root has now integrated the
repair into the final combined artifact, and the rerun below confirms these
behaviors there. This is not a claim that all forms of conversation memory work. The supplemental heater-cost
follow-up still withholds, and a complete transfer-duration question containing
grammatical `it` is misread by an older referent-substitution layer.

## Independent expectations and actual initial task

`tools/usage/conversation/cases.json` contains 15 turns across four conversations,
interleaved deliberately. `expectations.json` was written before the first query.
The unknown title was invented for this experiment. All rows used the real
`Engine.chat` through `tools/usage/run_batch.py`; no expected answer reached the
engine. Each run completed all 15 HTTP requests without transport/backend error.

| ID | Question | Immutable candidate | Final private repair | Judgment |
|---|---|---|---|---|
| lit-1 | Who wrote Leaves of Grass? | Walt Whitman, with description | same | Correct |
| isolation-1 | When was he born? (new session) | asks who `he` means | same | Correct separation |
| lit-2 | When was he born? | 31 May 1819; resolves Whitman | same | Correct |
| lit-3 | I meant Hamlet. Who wrote it? | William Shakespeare | same | Correction works |
| lit-4 | When was he born? | **1 April 1564**; resolves Shakespeare | same | Entity correct; unsupported exact date remains |
| isolation-2 | Who wrote Pride and Prejudice? | Jane Austen | same | Correct |
| isolation-3 | When was she born? | 16 December 1775; resolves Austen | same | Correct |
| math-1 | What is 14 * 6? | 84 | same | Correct |
| math-2 | What is that divided by 7? | 12 | same | Correct |
| math-3 | Correction: calculate 21 * 6 instead. | 126 | same | Correct delivered answer |
| math-4 | What is that divided by 7? | **12 / 7 = 1.714286** | **126 / 7 = 18** | Stale result repaired |
| stale-1 | Who wrote Hamlet? | William Shakespeare | same | Correct |
| stale-2 | New topic: who wrote The Clockwork Sea of Zeralune? | withholds; no admitted record | same | Useful refusal; awkward unrelated `New` explanation |
| stale-3 | When was he born? | **Shakespeare, 1 April 1564** | asks who `he` means | Stale author repaired |
| stale-4 | Who wrote Leaves of Grass? | Walt Whitman | same | Recovery works |

Against the expectations, baseline completes 12/15; the repair completes 14/15.
The remaining date error is separate from entity resolution. Root owns its
precision investigation. Median observed request latency was 0.132 seconds
baseline and 0.148 seconds repaired; maxima 1.939 and 2.387 seconds. These small
runs are not a performance benchmark.

Complete receipts (every field, exact response bytes, path/provenance, request,
latency, startup identity and logs) remain in:

- `var/usage-20261026/conversation/baseline/{results.jsonl,summary.json,adapter.log}`
- `var/usage-20261026/conversation/repaired/{results.jsonl,summary.json,adapter.log}`
- `var/usage-20261026/conversation/final/{results.jsonl,summary.json,adapter.log}`
- `var/usage-20261026/conversation/continuations/{results.jsonl,summary.json,adapter.log}`

The intermediate `repaired` run is intentionally retained: it fixed both stale
states but broke Whitman/Austen follow-ups because AP1's support predicate did
not recognize `organ:relation>`. Correcting that omission restored the original
useful answers in `final`.

## Supplemental continuation checks

Eight more real turns, expectations recorded in `continuations-expectations.json`
before use, completed without transport/backend error:

| Turns | Actual outcome |
|---|---|
| ack-1 through ack-3 | `3 + 4` → 7; `Thanks` → acknowledgement; `that times 2` → 14 |
| solved-1 and solved-2 | `x + 3 = 8` → x = 5; `x squared` → 25 |
| quantity-1 | 2 kW heater for 3 hours → 6 kWh, correctly |
| quantity-2 | `What does that cost at $0.20 per kWh?` → withheld, with an unrelated passage about year 20 |
| transfer-1 | `How long does it take to transfer 1GB at100Mbps?` → withheld; M53 changes it to `Summarize that times 2.` |

6/8 supplemental expectations complete. The quantity parser does not recognize
`It uses 6 kWh`; its fallback instead sees an intermediate `= 6000` with no
recognized Wh unit. The transfer defect comes from
`root/wander-train/oracle_release_runtime_ao.py` (also mirrored in admitted):
its generic deictic substitution treats grammatical `it` as the old topic.
Neither defect is hidden or converted into success. These are actual remaining
work, not new ownership barriers. Their repairs need source coordination.

## Implementation and evidence

AP1 reconciled four stores but omitted w29's `_last_value` and w529's module-global
`chat_context_v2._STATES`. The new helper lends the old context module a private
per-runtime/per-session context for the duration of a turn. At the final boundary
it discards intermediate context and rebuilds from the delivered supported reply.
Refusals clear the legacy referents. Explicit `New topic:` / `Switching topics:` /
`Change of topic:` clears the relevant legacy cache and reentry record before
querying. The previous module slot is restored afterward, including nested
sessions and separate runtime instances using the same session ID.

Numerical memory is retained from the final closed arithmetic route, or from the
known scalar `organ:math>evaluate` response grammar (finite scalar only). Units
and solved variables still use the legacy final-reply parser; this does not
promote a unit-bearing value into a dimensionless number. The helper is explicitly
untrusted Python. The route spelling is not a proof, and no new theorem is claimed.

Root-approved changes in `var/ap1-upstream-slim`:

- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/runtime_final_outcome.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/runtime_conversation_state.py` (new)
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w557.py`

Tracked lane files:

- `tools/usage/conversation/{cases.json,expectations.json,continuations.json,continuations-expectations.json}`
- `tools/usage/conversation/runtime_conversation_state.py` (reviewable helper source)
- `tools/usage/conversation/conversation-state.patch` (candidate-relative three-file patch)
- `tests/usage/conversation/test_state.py`
- this report

Both existing source files matched candidate SHA-256 before editing; receipts
are in `var/usage-20261026/conversation/source-inventory.json`. The private test
view copied only those three source files and linked the remaining candidate
entries; the shared adapter assigned state to its external workspace and disabled
bytecode writes. No corpus copy, upstream write, heavy build, Git operation, or
subagent was used. The immutable candidate remains the baseline.

Exact checks:

```
.venv/bin/python -B -m unittest discover -s tests/usage/conversation -v
# 9 tests passed
.venv/bin/python -B -m unittest discover -s var/ap1-upstream-slim/tests/runtime_outcomes -v
# 18 tests passed
```

The nine lane tests load the real legacy context module with controlled entity
lookups: author retention, explicit topic/refusal reset, corrected scalar,
quantity units, acknowledgement, speculative clarification, two runtime instances
sharing a session ID, nested different sessions, and rejection of non-scalar or
nonfinite values. The existing 18 AP1 tests cover the real final folds with lower
reader doubles, including nested outcomes, exception cleanup, and final refusal.
The real 15-turn rerun is the composition check that originally exposed the route
omission; fixture success alone was not treated as sufficient.


## Integration correction: nullable rewrite metadata

The first combined candidate exposed an integration regression in this helper:
standalone birth answers from `family_precedence` contain
`provenance.chat_resolved: null`. The helper assumed that field was a dictionary.
Einstein and John Williams queries therefore raised AttributeError and stopped
their batches. The original full replies are now retained in
`tests/usage/conversation/birth-replies.json` with their source receipt paths.

A real-engine reproduction with traceback instrumentation in the private helper
confirmed the failing `.get` at line 71; its complete log is
`var/usage-20261026/conversation/birth-error-reproduction/adapter.log`.
The instrumentation was removed. The helper now accepts a rewritten question
only from a dictionary containing a nonempty string; absent, null, or malformed
optional metadata uses the actual input question. This is a schema fix, not
exception suppression or a rewrite of Oracle's answer.

The repaired real run `var/usage-20261026/conversation/birth-fixed/` completed
both requests with HTTP 200: Einstein → 14 March 1879; Williams → 8 February
1932. This checks runtime recovery, not disambiguation of the Williams name.
`tools/usage/conversation/birth-regression.json` retains the two queries.
The lane suite now has **11 passing tests**, including the two actual reply
variants and typed optional-metadata cases; all **18 AP1 tests still pass**.
The approved private source, helper copy, candidate-relative patch, and source
hash inventory were updated. Neither immutable candidate was modified.


## Final combined artifact: definitive rerun

The final combined candidate at `var/usage-20261026/candidate` was tested with
all original 15 turns followed by the two birth regressions in one 17-turn batch:

```
.venv/bin/python -B tools/usage/run_batch.py \
  --runtime var/usage-20261026/candidate \
  --cases var/usage-20261026/conversation/combined-cases.json \
  --out var/usage-20261026/conversation/combined-final
```

**17/17 requests completed with HTTP 200, zero runtime or transport errors.**
The original expectations remain **14/15 met**; Shakespeare's exact birth date
is still the sole failure in that pack. Both direct birth regression queries
succeed: Einstein → 14 March 1879; Williams → 8 February 1932. Williams here is
only an HTTP/runtime regression check, not evidence that his ambiguous name is
correctly disambiguated.

The changed math wording does not break remembered scalar results. `math-3`
now says `126. In steps: read 126; then evaluate. Checked: finite numerical
comparison using SymPy.` The next turn still computes **126 / 7 = 18**.
The failed new topic still causes the next `he` question to clarify, and the
ordinary author follow-ups and separate-session check still pass.

Complete final receipts are `combined-final/results.jsonl`, `summary.json`, and
`adapter.log` under the lane scratch directory. Median request latency was
0.092 seconds, maximum 1.534 seconds. The recorded deployment receipt SHA-256 is
`e3628455a546219ad1505cd04b548a4282bff7647cc10a8c78fb30ae548b66d8`;
the usage patch SHA-256 is
`eecb26f28f86f015b4a0c3e6056d3a8e9fafe6e9760e811db2289e7701d424a7`.
The runner hashes the receipt bytes; this is not independent validation of all
package contents. No candidate files were edited. No specialist panels were run.
