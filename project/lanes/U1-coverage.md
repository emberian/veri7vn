# U1 coverage: missing records versus missed knowledge

15 original offline questions were replayed through the final combined immutable
candidate. Final result: **9 fully correct, 0 incorrect, 1 underqualified answer,
5 unresolved questions**. All seven initially correct responses are unchanged.
Only the three targeted replies changed. Initial run and final replay are
distinguished below.
No specialist panels ran. These are task outcomes, not a six-criterion score.
No Isabelle changes or theorem claims were made.

## Initial measured outcomes

The 15 responses comprised 10 answers and 5 nonanswers. Independent review found
7 fully correct answers, 2 incorrect answers, and 1 answer requiring an event
qualification. Of the 5 nonanswers, 2 missed usable knowledge and 3 safely left
an unresolved question unanswered. The latter three did not complete the task;
the two generic clarifications did not explain the actual ambiguity or missing
coverage. All 15 received HTTP 200. Median wall latency was 0.268 seconds;
maximum was 3.628 seconds, excluding startup. Full replies, including provenance
and encoded original bodies, are retained in
`var/usage-20261026/coverage/run-1/results.jsonl`.

| Case | Outcome and diagnosis |
| --- | --- |
| Who wrote Leaves of Grass? | Correct: Walt Whitman. |
| Who is the author of Leaves of Grass? | Correct: Walt Whitman. |
| Did Walt Whitman write Leaves of Grass? | Generic clarification despite the existing P50 row and successful forward questions; unsupported verification wording. |
| Where was Marie Curie born? | Correct: Warsaw. |
| Where was Maria Skłodowska born? | Incorrect: answers about Mary Q345 in Judea. Intended Q7186 has Warsaw/Freta Street P19 rows. Exact normalized maiden-name alias is missing; partial first-name linking escapes a fragment guard. |
| When was Marie Curie born? | Correct: 7 November 1867. |
| What is the capital of Canada? | Correct: Ottawa. |
| Who designed the Python programming language? | Correct: Guido van Rossum, P287. |
| Who created Python? | Incorrect semantic substitution: Guido plus Python Software Foundation, from developer P178. The official history attributes creation to Guido and dates PSF establishment to 2001. |
| When did the Golden Gate Bridge open? | Returns 28 May 1937 without saying this is vehicle opening. Pedestrians first crossed on 27 May; answer needs event qualification. |
| When did the Golden Gate Bridge open to pedestrians? | Useful refusal: no admitted evidence for this qualifier. P1619 only stores 28 May here; do not reuse that as the pedestrian date. This probe does not prove the fact absent from every text corpus. |
| In which constellation is the Andromeda Galaxy? | Needless refusal, despite Q2469 P59 Q9256 and a correct supporting passage. |
| In which constellation is M31? | Correct: Andromeda, from exactly that relation. |
| Where was Washington born? | Safely asks for clarification, but generically. It should ask which person. |
| List every poem Walt Whitman wrote. | Safely refuses unsupported exhaustive enumeration, but generically. Needs edition/scope and complete bibliography; a partial inverse list is not every poem. |

Primary expectations were written before the run and retained separately from
runner cases in `tools/usage/coverage/expectations.json`. Two operator guesses
for entity IDs (Leaves of Grass and Walt Whitman) were corrected by exact-name
lookup after the run; expected natural-language facts and sources did not change.

Independent sources:

- [Library of Congress: Leaves of Grass](https://www.loc.gov/item/03023679/)
- [Nobel Prize: Marie Curie questions and answers](https://www.nobelprize.org/prizes/physics/1903/marie-curie/questions-and-answers/)
- [Government of Canada: land and climate](https://www.canada.ca/en/immigration-refugees-citizenship/services/settle-canada/land-climate.html)
- [Python's official history and license](https://docs.python.org/3.13/license.html)
- [Golden Gate Bridge operator: key dates](https://www.goldengate.org/bridge/history-research/moments-events/key-dates/)
- [NASA: Messier 31](https://science.nasa.gov/mission/hubble/science/explore-the-night-sky/hubble-messier-catalog/messier-31/)

## Useful improvement

`tools/usage/coverage/diagnose.py` reads the original runner output and an
operator's intended entity/relation mapping. It retains the reply, proposes an
investigation, and shows bounded exact-name and relation probes. It distinguishes
wrong subjects, missing aliases, missing entity/property pairs, unavailable
properties, missed stored facts, unsupported qualifiers, ambiguity, and exhaustive
operations. An answered status is explicitly still subject to review.

The inspector uses immutable read-only SQLite, query-only mode, named indexes,
row limits and an instruction budget. It neither imports the runtime nor copies
stores. It never treats missing rows as false facts, or present rows as complete,
unique or independently verified. Package hashes are reported as declared
metadata, not fresh integrity checks. `tools/usage/coverage/README.md` explains
how a data maintainer or support operator can repeat the workflow.

Current evidence matters: this candidate includes `relations_v2.sqlite3` and the
real `names_v1.sqlite3`. The old 30-property v1 ceiling is not a ceiling for this
package: P287, P1619 and P59 all answered in this batch. The inspector records
release identity and relevant manifest store hashes. Its real output is retained
at `var/usage-20261026/coverage/diagnosis-1.json`.

Checks: `.venv/bin/python -B -m unittest discover -s tests/usage/coverage -p
 'test_*.py' -v` passed 8 tests. They exercise classification boundaries,
unchanged read-only fixture stores, failed writes, and truncated probe results.
The real diagnostic completed all 15 retained cases in under one second.

## Concrete next steps

1. Add a sourced Maria Skłodowska alias to Q7186 through the data build workflow,
   and reject unresolved adjacent name fragments. Current normalization splits
   `Skłodowska` into `sk odowska`; the fragment guard ignores `sk` because it is
   shorter than three characters. Improving normalization without rebuilding the
   matching name index would create a new mismatch, so do not change just one.
2. Preserve creator versus developer semantics. P178 can include later maintainers;
   Python's P287 designer record already identifies Guido.
3. Distinguish entity identity from name overlap: Andromeda Galaxy Q2469 and
   constellation Q9256 are different despite sharing a label word. Existing
   final guards in all three reach routers reject the full-name question for
   lexical overlap.
4. Ingest event-specific bridge opening evidence with its pedestrian/vehicle
   qualifier and primary-source citation. The four-column fact schema currently
   cannot express that qualifier; an extra bare date would introduce ambiguity.
5. A yes/no relation checker should bind both named entities and the property;
   absence would remain unknown unless coverage supports a negative conclusion.
6. For exhaustive bibliography, capture edition and completeness premises. Never
   turn a bounded inverse lookup into a complete inventory claim.

A related date limitation reported to root: Shakespeare Q692 P569 is stored as
`1564-04-01T00:00:00Z`; this store has no date precision column. The display layer
cannot recover whether day 1 is real or a month-precision placeholder. A blanket
rule rewriting every day 1 as an uncertain month would damage genuine dates;
precision/source evidence must travel with the record.

## Private router repairs, frozen for integration

Root authorized edits to private Slim's `root/wander-train/reach_router_v1.py`,
`reach_router_v2.py`, and `reach_router_v3.py`. All three bases byte-matched the
immutable candidate before editing. The candidate and original receipts remain
unchanged. A portable diff is `tools/usage/coverage/router-fixes.patch`.

- All three fragment guards now account for unexplained adjacent tokens shorter
  than three letters. Maria Skłodowska no longer becomes Mary; unsupported name
  resolution remains unanswered rather than being silently repaired with a guess.
- All three final guards compare entity IDs for identity. Distinct entities may
  share label words, so the full Andromeda Galaxy question now reaches P59.
  Literal overlap safeguards remain in place.
- v3 treats `created` as creator P170; it also admits designer P287 when every
  relevant candidate has positive, bounded P31/P279 evidence of being a
  programming language. Missing or mixed type evidence declines this extension.
  Developer P178 cannot satisfy creation. Python now returns Guido from P287;
  `Who developed Python?` still returns Guido and PSF from P178. Other designer,
  creator, author and founder routes retain their intended semantics.

`tools/usage/coverage/check_routers.py` runs direct checks against the real
immutable stores plus controlled negative cases. **34/34 checks passed**; receipt:
`var/usage-20261026/coverage/router-checks.json`. It checks short and Unicode name
fragments, a legitimate pen-name alias, full-name and catalog-number astronomy,
self identity versus equal labels, literal restatement, creator/developer
separation, missing type evidence and mixed candidate types. Initial direct
before/after observations are in `router-direct-first.json` in the same folder.
These checks are not full-engine composition or specialist panel results.

Private sources are frozen with SHA-256 values in
`var/usage-20261026/coverage/frozen-router-hashes.json`. The full-engine replay below completed that composition check.

Changed tracked deliverables: `tools/usage/coverage/cases.json`,
`expectations.json`, `diagnose.py`, `check_routers.py`, `router-fixes.patch`,
`README.md`; `tests/usage/coverage/test_diagnose.py`; this report. Private source
edits are the three reach routers above. No other lane's files were edited.
The consumers are users asking offline knowledge questions, data maintainers
triaging refusals, and root's corrected appliance integration. No theorem claim
or specialist-panel result is made.


## Final combined-runtime replay

The original `cases.json` was replayed without edits using the shared runner:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --runtime /Users/ember/dev/o7vn/var/usage-20261026/candidate \
  --cases tools/usage/coverage/cases.json \
  --out var/usage-20261026/coverage/run-2
```

All **15/15** cases received HTTP 200; the runner exited zero with no stop reason.
The final results are **9 fully correct, 0 incorrect, 1 underqualified answer,
5 nonanswers**. The seven correct original response texts are byte-for-byte
unchanged. Exactly three response texts changed:

| Case | Final active behavior |
| --- | --- |
| Maria Skłodowska birthplace | Generic clarification via `act:clarify|vessel:receipt`; the wrong Mary/Judea answer is gone. This is a safety repair, not a completed lookup. The missing full alias still needs source-backed enrichment. |
| Python creator | Guido van Rossum, active route `reach>v3>LINK>ROUTE:agent:created>RELATE:P287:fwd>AGREE>FIT>READ`; later developer PSF is no longer presented as original creator. |
| Andromeda Galaxy constellation | Andromeda, active route `reach>LINK>ROUTE:pattern:constellation|*>RELATE:P59:fwd>AGREE>FIT>READ`; full-name wording now succeeds just like M31. |

Median request latency was **0.242 seconds**, maximum **2.624 seconds**, excluding
startup. The bridge date still needs event qualification; pedestrian opening,
ambiguous Washington, exhaustive Whitman poems, and Leaves yes/no remain
unresolved. Maria's now-safe alias refusal is the fifth nonanswer. These limits
are retained in the results rather than counted as task successes.

Runtime identity: `/Users/ember/dev/o7vn/var/usage-20261026/candidate`, profile
`oracle7-slim-4.9`, base source revision
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`.
The directly hashed `APPLIANCE.json` is
`e3628455a546219ad1505cd04b548a4282bff7647cc10a8c78fb30ae548b66d8`;
its declared usage-patch SHA-256 is
`eecb26f28f86f015b4a0c3e6056d3a8e9fafe6e9760e811db2289e7701d424a7`.
All three router source files directly hash to the frozen lane versions.

Evidence: `var/usage-20261026/coverage/run-2/results.jsonl` retains the full
responses; `run-2/summary.json` retains runner completion;
`diagnosis-2.json` contains the bounded store observations; `convergence.json`
records counts, identity and assertions that the three fixes reached active
routes and the seven original positives were preserved. No candidate was edited.
No specialist panels ran; the result is only this usage pack's measured behavior.
