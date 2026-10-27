# U1 research: sourced questions and relation roles

25 real Oracle7 turns were run against the immutable passing appliance through
the shared adapter runner. Both runs completed with HTTP 200 for every turn and
no transport errors. No shipped specialist panels were run, so this lane has no
six-criterion panel numbers and makes no fleet claim. No new theorem is claimed.

Final integration reran all original 15 cases against
`var/usage-20261026/candidate`: all 15 completed with HTTP 200, no transport or
runtime errors, and no skipped cases. Eight unambiguous factual answers are
correct, one date is correct for a silently selected identity, and six turns
still clarify. There are zero wrong factual answers in this pack. The original
composer failure is repaired, all seven originally correct facts are preserved,
and the intermediate candidate's birth-date exception is resolved. These are
usage results, not specialist panel numbers.

## What works and what failed

The first 15 turns produced seven unambiguous correct factual answers, one wrong
factual answer, one correct birth date for a silently selected identity, and six
clarifications. The latter include a useful book-versus-film distinction and a
safe refusal of an Austen/Whitman false premise; they are not completed research
answers. A second ten-turn wording experiment produced nine correct factual
answers and one failed source-follow-up. Full judgments are in
`tools/usage/research/outcomes.json`.

Authorship for Leaves of Grass, Frankenstein, Pride and Prejudice and Stoner
worked. Mary Shelley's spouse and the 1818/1813 publication dates worked. The
George Eliot alias and 1855 publication date became available through explicit
biography/book wording. “John Edward Williams” returned the novelist's birth
date; bare “John Williams” selected the composer without explaining ambiguity.

The confirmed wrong answer was:

> Who composed the music for Star Wars (1977)?

Oracle answered James Arnold Taylor, citing his P800 association with Star Wars
Q462. P800 means notable work; it does not establish composition. Q462 is the
franchise. The film Q17738 already has the correct P86 composer, John Williams,
in the same store. Five follow-up composer wordings returned the correct answer.
This is a routing/meaning failure, not missing composer data.

The source-follow-up after Whitman asked which “that” the user meant despite a
single previous answer. Even the short “Sources?” after Shelley did not parse.
Existing references can still be retained by the caller: authorship replies have
Wikidata triples and opaque corpus IDs; the 1818 reply includes its supporting
sentence. Five of the nine initially answered replies have empty structured
reference arrays, even when their prose contains a useful Wikidata receipt.

## Repair and useful caller

Root granted only `var/ap1-upstream-slim/root/wander-train/relation_spec_v1.py`
outside this lane's normal paths. Before editing, its SHA256 equaled the passing
candidate's: `08f905b8f87cfb8d85256836dfff96a4f69b0d1299f017a0c5fee7985`.
The immutable candidate and original upstream were never modified.

The repair recognizes whole composer questions, looks up the entire title,
checks an optional parenthesized publication year, and reads P86. Eligible
candidates must agree on one composer. A capped alias lookup is refused; partial
title matches and inverse P800 are not accepted. Non-composer mined relations
continue through their existing path. P26/P86/P800 receipt labels now say spouse,
composer and notable work rather than misleading aliases from the label dump.
The exact source delta is `tools/usage/research/relation-semantics.patch`.

The accompanying untrusted `dossier.py` preserves complete runner records,
extracts only the current answer's visible IDs, adds navigation links and flags
property mismatches against caller-declared requirements. It detected the live
P800/P86 mismatch. It does not fetch links, certify truth, resolve opaque corpus
IDs, or promote withheld answers. Its consumer is a research assistant preparing
a cited note: review the requested relation and evidence before reusing the fact.

## Checks and retained evidence

- `python -B -m unittest discover -s tests/usage/research -v`: 16 tests passed
  (six dossier checks, ten relation semantics checks).
- Live read-only store calls to the patched reader: four supported composer
  variants return John Williams/P86/Q17738 for the films domain; the same four
  return no answer for singers. The invented 1777 date returns no answer in both
  domains. These ten calls are recorded in `reader-check.json`; they are not
  integrated engine turns or specialist panels.
- First-run median external request latency 0.354 seconds, maximum 3.134 seconds;
  second-run median 1.307 seconds, maximum 6.516 seconds. These exclude startup
  and queue time and should not be compared with Oracle's internal latency label.
- Full answers, raw response bytes, capabilities, logs and workspaces:
  `var/usage-20261026/research/run-1/` and `run-2/`.
- Dossier from the first run: `var/usage-20261026/research/dossier-1.json`.

Independent expectations preceded execution. Their source links are in the two
expectation JSON files: Library of Congress edition records, University of
Virginia Austen text, Oxford biography, NYRB author biography, University of
Arkansas author archive, Lucasfilm composer credit and the Shelley archive.
Property meanings were independently checked at Wikidata P800 and P86.

## Integrated results and remaining limits

Root packaged the repair into `var/usage-20261026/candidate-first`. The full
engine now answers the original r12 with John Williams and P86, selecting the
1977 soundtrack album Q2715371 through `rel-albums`. The original seven
unambiguous correct facts remain correct; Mary's husband receipt now says
“spouse.” All 16 regression tests also pass against this packaged module.

The intermediate combined run exposed a failure outside the exercised composer branch:
“When was John Williams born?” (r14) returns HTTP 502 `runtime_error`, type
`AttributeError`. The adapter reports possible state change and stops; r15 was
not run. Baseline r14 completed. This has been reported to root for the combined
repair owner's diagnosis; no candidate bytes were changed. Retained replies and
the error are in `var/usage-20261026/research/run-3-integrated/`; the dossier is
`var/usage-20261026/research/dossier-3-integrated.json`.

The final candidate resolves that exception. The fresh full rerun at
`var/usage-20261026/research/run-4-final/` completed all 15 cases: r12 remains
John Williams/P86; r14 returns the composer's 8 February 1932 birth date; r15
safely clarifies. All seven original unambiguous correct answers remain correct.
All 16 scoped tests pass with `RESEARCH_RELATION_SOURCE` pointing to the final
candidate module. Median external query latency was 0.279 seconds and maximum
2.316 seconds, excluding startup and queue time. The final dossier is
`var/usage-20261026/research/dossier-4-final.json`. Intermediate failure evidence
is retained unchanged.

Source-follow-up handling and silent homonym selection remain unresolved in
this pack. The broader coverage lane's creator/developer and partial-name cases
are outside this lane's final rerun; consult its report for their current status.
The composer repair handles a bounded set of whole-question
phrasings, not arbitrary prose. Specialist panel effects remain unmeasured.

Files added: `tools/usage/research/{cases.json,expectations.json,followups.json,
followup-expectations.json,requirements.json,outcomes.json,dossier.py,README.md,
relation-semantics.patch}`, `tests/usage/research/{test_dossier.py,
test_relation_semantics.py}`, and this report. The only extra source mutation is
the explicitly granted relation module above. Root owns integration and Git.
