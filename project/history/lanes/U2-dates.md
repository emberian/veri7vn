# U2: dates retain precision, calendar and uncertainty

Runtime implementation and a 200-pair metadata sidecar are frozen and replayed
on final-v3: **21/21 actual task checks pass**, comprising 17 supported answers
and four appropriate refusals, with no HTTP/transport errors. On 192 selected shipped date-panel rows, 191 supported answers
are restored: **186 own-scorer correct, five source-vs-gold disagreements, one
unchanged decline**. All five disagreements preserve the bound primary source's
precision/calendar/BCE convention. No full six-criterion score is claimed.
35 date/import/order/consumer tests and 34 U1 router controls pass. No theorem statements
changed; no store or immutable candidate was edited.

## The failure and source evidence

The four-column relation table `fact(s,p,o,lit)` retains a timestamp and loses
the date's precision, calendar and qualifiers. The original store builder is not
present in the shipped source/drop. The implementation history therefore cannot
be attributed to a particular uninspected importer line.

For Shakespeare, the primary Wikidata JSON statement records
`+1564-04-00T00:00:00Z`, precision 10 (month), Julian calendar. Its same-revision
RDF node gives `1564-04-01T00:00:00Z`, still with precision 10 and Julian calendar.
The legacy store retained the latter literal alone. Reading its digits as an
exact date produced the false **1 April 1564** answer.
The [Shakespeare Birthplace Trust](https://www.shakespeare.org.uk/explore-shakespeare/shakespedia/william-shakespeare/when-was-shakespeare-born/)
independently states April 1564 and explains that the exact day is unrecorded.
The live source also retains deprecated April 23 and baptism-based April 26
claims; neither is silently promoted to an exact birthday.

Day 1 is not an uncertainty marker. J. D. Salinger's source records January 1,
1919 at day precision, corroborated by the [PBS documentary timeline](https://www.pbs.org/wnet/americanmasters/jd-salinger-salinger-timeline/2838/).
Jimmy Carter's October 1, 1924 date has day precision and is corroborated by the
[Nobel Prize record](https://www.nobelprize.org/prizes/peace/2002/carter/facts/).
Wikidata's [date documentation](https://www.wikidata.org/wiki/Help:Dates)
explains the format distinctions and why January 1 values need their metadata.

## Baseline: 12 real questions

Shared-runner receipts: `var/usage-20261026/dates/baseline-1/` against
`var/usage-20261026/candidate-final`. All 12 received HTTP 200.

| Case | Baseline reply or limitation |
| --- | --- |
| Shakespeare birth | Incorrect exact April 1, 1564. |
| Exact date of Shakespeare's birth | Withheld with an unrelated passage about tragicomedies; did not offer the supported month. |
| Shakespeare birth year | Correct 1564. |
| Salinger birth | 1919 only; genuinely known January 1 was lost by the display heuristic. |
| Carter birth | Correct October 1, 1924. |
| Curie birth | Correct November 7, 1867. |
| Newton birth | January 4, 1643 with no calendar label. |
| Newton birth in Julian calendar | A sourced text answer gives December 25, 1642; primary comparison is the [Newton Project](https://newtonproject.ox.ac.uk/his-life-and-work-at-a-glance). |
| Hildegard birth | 1098 without preserving the source's circa qualifier. |
| Sappho birth | Incorrect exact 650 BC; the bound preferred source value is end of the seventh century BCE. |
| Cicero birth | Incorrect December 31, 106 BC from an RDF literal; the source JSON date is January 3, 106 BCE in the Julian calendar. |
| Whitman birth, deliberately outside the initial sidecar | An exact relation date printed without available precision/calendar metadata. The fact may be correct; this route cannot establish that from the flattened field. |

## Implementation and input contract

A 2,548,330-byte versioned sidecar covers 195 entities and 200 P569/P570
entity/property pairs: the selected panel slice, eight original regressions, and
Jane Austen for the Mini conversation consumer. It retains every selected source claim, including deprecated ranks,
references and qualifiers. A bounded importer fetches JSON and RDF at the same
revision, joins statement IDs, checks metadata agreement and binds exact RDF
literals to the immutable existing store. It does not guess JSON-to-RDF date
conversion. No large dump or store copy was downloaded.

New runtime inputs are `root/relstore/date_precision_v1.json` and
`root/wander-train/date_precision_v1.py`. Schema details and reproducible commands
are in `tools/usage/dates/README.md`. The runtime has no network dependency.

All three reach routers, the exact router, and both shared relation-specialist
readers now pass entity/property context to one shared renderer. Present source
metadata yields the source's precision and calendar; missing/mismatched metadata
uses the existing decline contract instead of asserting a date. A year request can receive a supported
year, and an exact-day request can receive a supported month with “day
unspecified.” Genuine first-of-month dates remain exact. BCE dates are read from
the historical JSON representation rather than applying a second offset to RDF.
Candidates must agree on the source-aware display, not just on equal flattened
literals.

The relation reader adds narrow whole-question forms for exact birth-date and
explicit Julian/Gregorian requests. Existing reader indices and dropped-pattern
indices are preserved. The U1 composer-role and creator/name fixes remain.
P569/P570 receipt labels now say date of birth/death rather than incorrectly
calling every date a year.

The date-order composer uses supported calendar-local intervals. It answers only
when intervals do not overlap and calendars match. It retains all bounded
stored values rather than choosing a minimum timestamp. Missing metadata,
unknown qualifiers, circa and cross-calendar comparisons do not prove an order.
Direct real-store checks preserve ordering of Salinger/Carter, Curie/Carter, and
Shakespeare/Newton, including Shakespeare's month uncertainty. Hildegard's circa
date does not become a fabricated precise ordering premise.

## Checks, files and remaining work

35/35 date/import/order/consumer tests cover true day-one dates, month/year/century
precision, BCE, calendars, requested representation, deprecated/preferred ranks,
missing context, mismatched metadata, qualifiers, uncertainty, invalid dates,
import binding/revision checks and interval overlap. Existing U1 direct router
controls pass 34/34. These are narrow implementation checks, not panel scores.

Private edited files: `root/wander-train/reach_router_v1.py`, `reach_router_v2.py`,
`reach_router_v3.py`, `exact_router_v1.py`, `relation_spec_v1.py`,
`relation_spec_v2.py`, `knowledge_composer_v1.py`; new helper and sidecar named
above. Their frozen hashes are in
`var/usage-20261026/dates/frozen-hashes-3.json`. Owned deliverables are
`tools/usage/dates/{import_precision.py,selection.json,cases.json,expectations.json,README.md}`,
`tests/usage/dates/test_precision.py`, and this report.

The final immutable-candidate replay is recorded below. Coverage is intentionally
bounded: the broader data rebuild must preserve these fields at import time;
this lane does not pretend to recover precision for millions of unannotated
rows. Calendar conversion in ordering, unrecognized semantic qualifiers, and
unsupported source precisions remain explicit limits. Existing relation-organ
wrappers discard extra structured date-evidence fields; the rendered text keeps
precision/calendar/qualifiers, while complete citations remain inspectable in the
sidecar. Propagating that structured evidence into top-level replies is a named
follow-up. Missing-metadata specialist replies now use `status: withheld`; reach/exact
readers return no answer instead of reviving the flattened timestamp.

Consumer: anyone asking when an event happened or which happened first. The
change avoids confident invented days while preserving supported precise dates
and useful coarser answers.


## Scoped shipped date-panel impact

Root requested a real eligibility check before release. The four shipped
specialists `rel-actors`, `rel-novelists`, `rel-mathematicians`, and `rel-chemists`
were run directly on **only forward P569/P570** rows, both dev and heldout, with
their own unchanged `relspec_scorer.ok` functions. These are 192 selected rows,
not a full six-criterion evaluation. The repeatable command is
`tools/usage/dates/score_date_panels.py`; item receipts are retained in
`var/usage-20261026/dates/panels-before/` and `panels-after/`.

| Stage | Own-scorer correct | Own-scorer wrong | Declined | Explicitly unavailable metadata |
| --- | ---: | ---: | ---: | ---: |
| Original candidate | 191 | 0 | 1 | 0 |
| First eight-record sidecar | 94 | 97 | 1 | 191 |
| Expanded metadata + real decline contract | 186 | 5 | 1 | 0 |

The apparent 94 successes in the second row are **not supported date answers**:
the scorer finds an expected year within an explicitly unverified stored
timestamp. The generic wrapper still labeled that explanation `answered`.
Actual supported-date eligibility on this slice fell from 191 to zero. This was
not accepted as a finished improvement.

Missing-metadata replies now use the shared specialist's real decline contract;
reach/exact routes return no date answer. Three additional checks verify that
these paths cannot revive an unannotated timestamp. Malformed valid JSON roots,
records and nested fields also fail closed. That stage passed 29 tests; the
final active-consumer suite passes 35.

The bounded import covers all selected panel entity/property pairs plus
the eight initial pairs and Jane Austen's P569 for the actual Mini conversation
consumer: **195 entities, 200 pairs**. Full JSON/RDF snapshots remain in scratch;
only selected date claims and their references enter the sidecar. Four workers
share a 1.2-second source-request pace and honor rate-limit backoff. The first
unpaced run was stopped by its recorded PID after HTTP 429s; completed snapshots
were retained and reused. The completed import has zero failed entities. Final scoped receipts are in
`var/usage-20261026/dates/panels-final-1/`; no original panel/scorer was edited.
191 answers retain bound precision metadata, and the lone Charles Farrell
death-date decline already occurred in the baseline. Final full-engine results
are recorded below.


### Five source-vs-gold disagreements

These are scorer disagreements, not five independently established historical
errors. The primary claim is source data, not a theorem of historical truth.
The unchanged scorer compares against the flattened old gold; the reader now
preserves the exact bound claim's metadata. No gold was edited.

| Entity/property | Old gold | Bound claim and corrected reply | Same-revision evidence |
| --- | --- | --- | --- |
| Yu Deng Q102585127/P569 | 1 June 1989 | JSON `+1989-06-00`, precision 10, Gregorian. **June 1989; day unspecified**. RDF `1989-06-01` is a month placeholder, not evidence of day 1. | [revision 2560181472](https://www.wikidata.org/wiki/Special:EntityData/Q102585127.json?revision=2560181472), statement `7cae8bff-4570-0db7-1d97-e68758a4b406` |
| Abd al-Rahman al-Sufi Q11075/P569 | 12 December 903 | JSON `+0903-12-07`, precision 11, Julian. **7 December 903 (Julian calendar)**. Same RDF node stores `0903-12-12`; it must not be labeled a source-calendar day without conversion evidence. | [revision 2550579264](https://www.wikidata.org/wiki/Special:EntityData/Q11075.json?revision=2550579264), statement `2134DF91-B63F-4455-B8E6-95738DBFD537` |
| Diocles of Carystus Q1226886/P570 | 179 BC | JSON `-0180-00-00`, precision 9, Julian, P5102=circa. **180 BCE; month/day unspecified; circa**. RDF `-0179-01-01` uses astronomical year numbering. | [revision 2549130251](https://www.wikidata.org/wiki/Special:EntityData/Q1226886.json?revision=2549130251), statement `3A5F505D-D196-4F72-9759-5AEDA3C614EF` |
| Pythagoras Q10261/P569 | 582 BC | Preferred JSON `-0582-00-00`, precision 7, Julian, earliest 586 BCE/latest 569 BCE, preferred-rank reason most inclusive value. **6th century BCE with those bounds**. The year request cannot upgrade century precision. | [revision 2560830332](https://www.wikidata.org/wiki/Special:EntityData/Q10261.json?revision=2560830332), statement `84f2ccb4-437f-1736-158a-5961091dfb0e` |
| Ahmes Q1073335/P569 | 1659 BC | JSON `-1660-00-00`, precision 9, Julian, circa and P31=Q26961029 retained. **1660 BCE; circa**, with opaque qualifier preserved. RDF `-1659-01-01` uses astronomical numbering. | [revision 2551566046](https://www.wikidata.org/wiki/Special:EntityData/Q1073335.json?revision=2551566046), statement `288ad939-428e-85b7-76be-d5465aa13978` |

Each record also retains the same-revision RDF URL, both snapshot hashes, full
selected claims/references/qualifiers, and the exact legacy-literal binding.
Expanded sidecar SHA-256:
`3e2392fbc65a610790b35f06e49d5d28372ff01aa9b8f677b453ab20727a9e15`.

The remaining broad-data task is a versioned native date import for the rest of
the store, not pretending the bounded pack supplies global coverage. The current
importer handles additional explicit selections without a large dump or store
rewrite, up to 256 entities/2,048 pairs and a 16 MiB sidecar.


## Final-v2 actual engine replay and comparison consumer repair

Immutable `var/usage-20261027/candidate-final-v2` (private source e9a1cc6,
Earth/Space Linux overlay) received all original 12 questions successfully:
11 supported precision-aware answers and one correct missing-metadata refusal
(Whitman). Receipts: `dates/replay-final-v2/` under the usage scratch directory.
The source values match the table above. Shakespeare's exact-date question gets
the supported month; Salinger and Carter keep genuine day-one dates; all source
calendars and tested uncertainty qualifiers remain visible. Whitman is now
`withheld` and no flattened date is revived through fallback.

The six extra real consumer questions passed Austen conversation continuity and
explicit Gregorian Newton, but exposed three ordering failures. An earlier
active route, `oracle_release_runtime_w426.py::_c426_compare`, bypassed the new
helper by extracting any year from each person's page. It compared Salinger's
birth with Carter's 1977 presidency, and Shakespeare's birth with Newton's 1668
telescope; it also printed an exact gap for Hildegard's circa date. This was an
actual consumer failure, despite the helper's passing direct tests.

Root transferred that exact private runtime file. The consumer now delegates
to the shared source-bound date ordering operation and returns contextual date
receipts. It no longer derives a numeric age gap from unrelated prose. Missing,
overlapping or unsupported dates use the existing terminal refusal contract,
so later fallbacks cannot revive the abandoned years. Explicit “Who was born
earlier/later” questions require P569; unrelated both/bridge methods remain
unchanged. The narrow suite now passes 35 tests, including the actual consumer
method, reader failure, terminal refusal and birth-property constraints. U1's
34 router controls still pass.

The ten-file freeze is `dates/frozen-hashes-3.json`; the additional runtime path is
`root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w426.py`.
The consumer replay pack now contains nine cases, adding explicit birth ordering,
missing metadata and same-person negative controls. Final-v3 full-engine replay completed below; final-v2 remains historical
evidence of the ordering failure.


## Final-v3 delivered behavior

Immutable candidate: `/Users/ember/dev/o7vn/var/usage-20261027/candidate-final-v3`,
private source commit `2a42ed7`, all ten `frozen-hashes-3.json` identities verified
by root during provisioning. Both shared-runner runs completed with HTTP 200 for
every question and no transport errors: `dates/replay-final-v3/` (12 original)
and `dates/consumer-final-v3/` (nine consumer questions). The explicit assessment
receipt is `dates/final-assessment.json`.

All 12 original final-v3 responses are identical to the reviewed final-v2
responses: 11 useful date answers and one missing-metadata refusal. The nine
consumer questions now deliver six correct supported answers and three terminal
refusals. These 21 actual task checks are not an additional specialist-panel or
Mini-admission score.

| Consumer question | Actual final-v3 result |
| --- | --- |
| Who wrote Emma? → When was she born? | Jane Austen → 16 December 1775 (Gregorian calendar), answered; provenance resolves the pronoun to Jane Austen. |
| Newton in the Gregorian calendar | 4 January 1643 (Gregorian calendar), answered from the matching source representation. |
| Who is older, Salinger or Carter? | Salinger, with 1 January 1919 and 1 October 1924 Gregorian birth receipts. No invented 58-year gap. |
| Who is older, Shakespeare or Newton? | Shakespeare, with April 1564 Julian/day unspecified and 25 December 1642 Julian receipts. Coarser precision still establishes an order. No invented 104-year gap. |
| Who was born earlier, Salinger or Carter? | Salinger with the same supported birth receipts. |
| Hildegard or Shakespeare? | Withheld with terminal `date_order_unverified`; circa is not promoted to a precise interval. |
| Whitman or Salinger? | Withheld with terminal `date_order_unverified`; unannotated date digits do not prove an order. |
| Salinger or Salinger? | Withheld with terminal `date_order_unverified`; no strict order between identical subjects. |

The actual comparison answers use `compose:comparison` with
`method: source_date_intervals`; negative controls retain terminal refusal
receipts through the final head. Exact full reply envelopes and contextual steps
are retained in the two results files. This connects the helper to its active
consumer rather than relying only on direct helper checks.

Remaining work is the broader native precision-preserving data import and
structured source-evidence propagation described above. No broad date coverage,
full six-criterion panel success, or historical truth theorem is claimed.
