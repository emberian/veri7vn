# Joint-relation and work-year premise checks

27 October 2026. This continues the two defects recorded in
[AP1-premise.md](AP1-premise.md), against private upstream source `2a42ed7`.

The premise guard now distinguishes a positive source contradiction from a
condition the records do not establish. Missing facts can stop an incomplete
answer, but the user is no longer told that missing facts make the premise
false. A typed terminal refusal keeps later fallbacks from undoing this choice.

## What changed

The joint-person check recognizes complete questions such as “Which band did
Jane Smith form with John Smith?” and “Which novel did Jane Smith and John
Smith write?” It keeps both whole names, requires distinct unambiguous human
IDs, binds the displayed answer to its answer ID, and checks positive rows for
the requested relation. A spouse, membership, or other incidental connection
does not prove that two people founded a band or wrote a book together.

Supported noun/verb pairs are band/form or found; company or organization/found;
book or novel/write; film or movie/direct or produce; song or opera/compose.
Both “with” and “and” forms are supported. Answer-kind classification requires
positive P31/P279 evidence; novels may also use positive P136 genre or P7937
form-of-creative-work paths. The real store uses P7937=novel for Pride and
Prejudice, Emma, The Hobbit and Nineteen Eighty-Four, and a three-volume-novel
subclass for The Lord of the Rings. “Literary work” or “romantic fiction” alone
does not establish the more specific novel condition.
The bounded ancestry search makes no claim of exclusion when evidence is
missing. Other question forms are not silently reinterpreted as these relations.

The work-year check recognizes complete “Who directed the 1948 film Hamlet?”
and “Who wrote the novel Example (1948)?” forms, with optional double quotes
around the title. The single direct relation citation must identify a candidate
of the exact whole title and the asked property. That cited work must positively
meet the requested film/movie/book/novel kind and publication-year condition.
The full bounded index pool is requested, with a 65th row detecting overflow;
neither a truncated pool nor a fragment of the title is accepted. Other
positively matching candidates with different stored answers cause refusal.
Candidates missing type/date/answer evidence remain explicitly unresolved;
their absence of evidence does not establish global disambiguation. Incidental
`(Q...)` mentions no longer select the work. Film years mean release/publication years and book years mean
publication years in this bounded language interpretation; inception and first
performance dates are not substituted.

A positive P577 date must have source-bound precision and Gregorian-calendar
bounds wholly inside the requested year, using the existing
`date_precision_v1.publication_intervals` operation supplied by the U3 date lane.
This retains each positive statement's source, identity and qualifiers,
including typed P291 publication-place qualifiers. Format/edition modifiers,
unknown qualifiers and uncertainty cannot silently become unqualified date
witnesses. The stricter chronology `interval()` operation remains unchanged.
Flattened timestamp digits alone cannot
establish this. There is no ten-year tolerance. Another recorded release year
is **insufficient evidence**, not a contradiction: editions, regions and
additional releases may be absent from the store. A matching positive date can
satisfy the year condition even when other releases are also recorded.
Julian-only, uncertain, broader-than-year or missing metadata do not confirm a
Gregorian year. No source completeness or world-truth theorem is claimed.

`assess()` returns `contradiction` for the earlier explicit sole-creator check,
`insufficient_evidence` for unsupported recognized conditions, or
`supported_condition` for a checked cited work/year. Accepted year replies gain
an explicit `premise_check` receipt with that work ID, the publication statements
and unresolved senses. They do not claim complete global disambiguation.
`check()`
retains its old optional reason-string interface. w571 consumes the typed
assessment, preserves existing terminal refusals, removes stale answer
attribution on replacement, and emits terminal `premise_conflict` or
`premise_unverified`. Evidence-read exceptions no longer silently count as a
passed check. Unknown legacy reason strings are treated as insufficient
evidence rather than upgraded to contradictions.

## Reproduced consumer behavior

`var/u3-premise/consumer-comparison.json` compares actual baseline and revised
w571/premise code against the same small SQLite fixture. The preceding answerer
is an explicit double; names SQL, relation SQL, date precision, the premise
predicate and final w571 response construction are real code. This is a
consumer-boundary experiment, **not a full Engine or live-store run**.

| Condition supplied to w571 | Before | After |
| --- | --- | --- |
| No joint-founder rows | Withheld, described as a false premise | Withheld, explicitly insufficient evidence |
| Incidental connections but no requested founder rows | Answered | Withheld, insufficient evidence |
| Both actual founder rows | Answered | Answered |
| Incidental first QID dated 1800; cited work has bound 1948 release | Wrongly withheld | Answered |
| Requested 1949; only a bound 1948 release | Answered through tolerance | Withheld, insufficient evidence |
| Requested 1850; only a bound 1948 release | Withheld, described as a false premise | Withheld, explicitly insufficient evidence |

The focused suite now passes **55 tests**:

`.venv/bin/python -I -B -m unittest discover -s var/ap1-upstream-slim/tests/premise_v3 -p 'test_*.py'`

The **18 existing final-outcome tests** also pass:

`.venv/bin/python -I -B var/ap1-upstream-slim/tests/runtime_outcomes/test_final_outcome.py`

Controls include correct cofounder/coauthor/director rows, wrong property and
direction, same-name ambiguity, answer-ID/text disagreement, wrong entity kind,
positive subclass and genre paths, incidental/wrong/multiple citations, absent
metadata, multiple release dates, coarse precision, uncertainty, calendar
mismatch, evidence-reader errors, preserved terminal refusals and the prior
exclusive-creator contradiction. Additional controls exercise P7937 form,
polysemous-title positive binding, conflicting and agreeing other matched works,
overflow, retained regional publication witnesses and rejected format modifiers.
No Isabelle/native build ran.

### Answer binding correction after adversarial review

Terra then supplied a real defect in the new condition check: a work with
stored director Jane Smith and a valid 1948 date could receive a supported
condition receipt even when the earlier reply claimed John Smith. Work and
date binding alone were insufficient.

YEAR now binds the **complete proposed answer** to the work's actual asked
creator-property rows. If lower-reader value IDs are supplied, their full set
must agree with those rows. Both the displayed answer and the citation's value
text must be full renderings of the complete source labels. Matching substrings,
surplus prose, mismatching IDs and partial coauthor lists cannot pass. The
ordinary reach/title list renderer is supported for up to its five-value bound,
including harmless value ordering changes and names containing commas. Legacy
replies without value IDs may bind through the complete source labels; their
receipt explicitly says the lower-reader IDs were not supplied.

The exact John-versus-Jane counterexample now reaches a terminal
`premise_unverified` through actual w571. Separate controls test correct IDs
with wrong text, correct text with wrong IDs, conflicting answer/citation text,
duplicate IDs, complete reordered coauthor lists, partial lists and punctuation
inside a whole name. The unrelated-QID regression uses an incidental ID inside
the citation label; extra unrecognized prose in the answer itself is now
insufficient instead of being discarded. All eight real-store positive work
cases below still pass, and both negative controls still withhold.

## Earlier real-store boundary checks

`var/u3-premise/real-store-consumer.json` runs actual w571 and the current helper
over the read-only final-v3 knowledge stores, using the new date sidecar. Only
the preceding answer is constructed from the actual requested creator rows;
this still does **not** establish full Engine routing. Eight supported cases
answer, and two unsupported year conditions withhold:

| Requested work/year | Result at w571 with real source evidence |
| --- | --- |
| Hamlet, 1948 film | Supported cited-work answer |
| Hamlet, 1850 film | Insufficient year evidence |
| Pride and Prejudice, 1813 novel | Supported cited-work answer |
| Emma, 1815 novel | Supported cited-work answer |
| Emma, 1816 novel | Insufficient year evidence; not a claim that the title-page date is false |
| The Hobbit, 1937 novel | Supported cited-work answer |
| Nineteen Eighty-Four, requested as 1984, 1949 novel | Supported cited-work answer |
| Casablanca, 1942 film | Supported regional publication witness retained |
| The Shawshank Redemption, 1994 film | Supported regional publication witness retained |
| Pride and Prejudice, 2005 film | Supported regional publication witness retained |

The date lane's source import preserves Emma's 23 December 1815 publication
claim; 1816 is the first edition's title-page date. Missing a bound 1816
publication witness is not proof that “the 1816 novel” is false. The two cases
remain deliberately distinct.

## Full Engine v2 failure and actual reader repair

The real U3 v2 Engine run exposed a missed integration boundary: **all ten
positive work-year questions withheld or clarified**, despite the eight earlier
source-constructed boundary positives. The full receipts are
`var/u3-service/u3-v2-real/calls.jsonl`. Actual specialists render value QIDs and
trailing specialist tags; earlier prose readers supply additional sentences;
and the title route treated `1948 film Hamlet` as a whole title. Both Pride and
Prejudice film-year questions failed parsing. The guard was refusing partial
or unbound replies correctly, but that did not make a useful complete system.

The correction is in the owning reader path, not by stripping arbitrary prose
until a name matches. `title_route_v1` now asks the shared premise helper to
read recognized complete work-year requests. It enumerates exact whole-title
candidates within the same bounded pool, checks positive kind, source-bound
publication year and complete creator rows, and requires agreement across the
known supported readings. It returns a structured relation answer with the
explicit unknown-sense scope. w568 always renders that canonical source answer
for a recognized supported year request, replacing partial prose even if the
earlier reply happened to name the correct person. The independent w571 guard
then checks the complete answer/IDs against the source rows as before. Missing
conditions and known conflicts produce terminal insufficiency; pre-existing
terminal refusals remain intact.

The v2 run also answered the explicit sole-Shakespeare premise about Emma
through a literature specialist. This was not a later refusal override:
`owner()` could not bind the work/citation and returned no contradiction, which
previously let the exclusive condition disappear. A recognized exclusive
condition that is not positively contradicted now yields typed insufficiency.
Even one matching creator row does not establish that no co-creator exists.
Bare possessives remain outside that exclusive assertion, and unrecognized
generic queries are not rewritten. Complete supported grammar identifies the
request; initials such as J. R. R. are not mistaken for several sentences. A
recognized condition longer than the 160-character bound receives explicit
insufficiency instead of silently escaping the check.

`var/u3-premise/replay-real-reader-stack.json` replays actual `title_route_v1`,
w568 and w571 with the real read-only stores and refreshed date metadata. Its
earlier-reader input is reconstructed from each v2 withheld-reply receipt or
the original clarification. **All ten positive cases now answer; Hamlet 1949
and Emma 1816 remain insufficient, and sole-Shakespeare Emma now withholds.**
This is stronger than a source-constructed answer fixture, but still does not
replace the pending complete v3 Engine replay. No Engine was started by this
lane.

The 55 tests include the actual title/w568/w571 chain with the observed
specialist and prose shapes, the prior clarification, conflicting typed/year
candidates, terminal refusal preservation and an unbound exclusive premise.
All 18 existing final-outcome tests also pass after this reader change.

**Specialist panel numbers: none measured.** No scorer gold or panel was edited.
The expected truth is the supplied source fixture and explicit request
condition, not the old implementation's response.

## Integration and remaining work

Owned changed files in `var/ap1-upstream-slim`:

- `root/wander-train/premise_v3.py`
- `root/wander-train/title_route_v1.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w568.py`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w571.py`
- `tests/premise_v3/test_owner.py`
- `tests/premise_v3/test_conditions.py` (new)

Root owns the contribution patch, candidate assembly and commits. Immutable
`candidate-final-v3` and original upstream/survey snapshots were not edited.
No full Engine was started by this lane.

The source is ready for a coordinated candidate replay. Its dependency is the
U3 date lane's helper and 211-pair sidecar, frozen separately in
`var/u3-dates/frozen-hashes-v2.json`; the six owned source/test hashes are in
`var/u3-premise/frozen-hashes.json`. The date lane supplies
`tools/usage/dates/work-cases.json` and its expected conditions for the shared
full Engine runner. That full routing result remains pending root integration.

Joint-person source coverage remains limited: the real names index has multiple
Brian May/Roger Taylor readings, and Queen has no P112 founder rows in this
store. A valid real-world cofounder question therefore can remain insufficient;
arbitrary membership rows will not be used to pretend that missing founding
evidence exists. Broader question grammar, source coverage, identity resolution
and calendar conversion remain separate work.
