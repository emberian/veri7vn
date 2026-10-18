# Document question, page and sentence witnesses

Owner: Codex document lane. Ordinary cause, process and event-date questions now
run through a lightweight source fetch and extracted decision. The final proof
passes ten theorem scans with zero oracles and 22 computed checks. The actual
consumer answers five of twenty authored source questions and withholds fifteen,
with no errors; all 28 evidence controls pass. The composed document frontdoor
passes 23 checks and closes all three recorded descendants on SIGTERM. These
are scoped capability and assertion counts, not specialist-panel completion.
Runtime dispatcher wiring remains the final integration step.

## Problem and source evidence

The legacy document adapter never constructs the typed `Explain` turns that its
HOL route supports. Its page anchor accepts fetched `resolved` or `conjunctive`
flags. A nonempty claim ID would not repair the question-to-page connection.

Actual source inspection also refutes using a page match as sentence support:

- Photosynthesis page `sw3518` includes expected process definitions, then
  sentences about cosmic building blocks, supernovae and Halley's Comet. Both
  the page-sentence association and source row carry that page ID.
- The Albert Einstein page includes birth statements for several people.
  A generic year plus “born” does not identify Einstein's birth.
- The bare Mercury alias points to OpenStax page `ox1467`, whose opening
  sentences discuss the Moon.

These examples come from the shipped immutable SQLite store. They establish
neither malicious data nor a broken join. They show why row authenticity,
page association, and support for the asked subject/event are separate questions.

## Decision and consumer

`anchor_fetch.py` proposes a complete typed question, queries every matching
title alias (including an explicit singular fallback), and returns up to 60
sentences only when the aliases identify one page. The SQLite connection uses
`mode=ro&immutable=1`. It preserves both the association page ID and the source
row page ID. The old heavy Oracle runtime chain is not imported.

`Document_Anchors.anchored_decide` checks the complete supported question shape,
matching alias keys, agreement of all matching supplied aliases, both sentence
page IDs, title equality, and a nonblank citation ID. An answer must contain a
literal requested-topic subject (or canonical title only for an exact requested
alias) and a kind-specific causal, process or event clause.
The final-s retrieval fallback cannot authorize a different sentence subject.
Exact alias-to-title referent identity remains a trusted lookup premise.
Event dates require a direct `in YYYY` or `by NAME in YYYY` phrase after the
requested event cue and a clause boundary after the year. The finite NAME syntax
accepts capitalized alphabetic tokens and named role words; it does not perform
general name resolution or event entailment. There is no
fallback from the requested event to a generic dated sentence.

The answer quotes the selected source sentence with its citation. These are
controlled text forms, not a proof of general natural-language causal entailment
or of the source assertion's truth. Surname resolution, pronouns, contextual
clauses and arbitrary linguistic paraphrases are not yet supported.

`frontdoor.py` consumes the new adapter before the legacy document adapter.
Recognized missing, ambiguous or unsupported source evidence is a decisive
refusal; only a silent question falls through. The legacy adapter starts lazily.
Both child processes are closed on EOF/SIGTERM by their recorded process handles.
The checked native and composition tests are ready for runtime wiring.

## Statements and trust boundary

The main source-witness theorem states that an answer has a supplied row whose
page identifiers and title agree with the selected matching alias, whose ID is
nonempty, and whose text satisfies the checked subject/event clause. The clause
theorem exposes the literal subject, cue and nonempty suffix in the answer's
sentence. The rendering theorem binds the actual response to that row's sentence,
claim ID and title. A date answer has an actual year substring.

The snapshot theorem additionally assumes set equality between supplied matching
aliases and the matching source-snapshot aliases, plus supplied-row membership
in an authentic snapshot. Under those premises the returned row belongs to the
snapshot and every matching snapshot alias agrees on the selected page/title.
The fetch does not dynamically prove those premises. Omitting an alias can hide
ambiguity. Source truth remains outside the model.

## Checks and remaining work

Seven focused Python fetch tests pass: ambiguous aliases, explicit singular fallback,
source-page mismatch preservation, whole-topic matching, refusal to strip trailing
question content, full-field reconstruction, and preservation of an alias whose article row is missing. The final executable passes: 22 extracted boundary cases, 20 author-written source questions,
and 28 raw-evidence controls. These are not untouched specialist panels.

The existing recorded 924-question core panel contains zero questions matching
these complete cause/process/when forms. There is no existing-panel completion
score for this extension. The preceding quotation packet is separately integrated
as `010f72e` with 63 theorems, zero oracles and three actual adapter smoke replies.

The legacy statement route still uses `anchor_present` flags. It needs the same
question/page witness treatment; W6-08 is not fully closed by this Explain route.
Useful controlled conditional clauses, such as “When there is enough pressure,
the volcano erupts,” are a subsequent semantic extension. Summary/timeline and
explain-simply composition also remain separate outstanding capabilities.

## Native build input binding

Both document build recipes now require a proof receipt argument and use that
attempt's exact exported ML file. They invoke `tools/dev/native-compile`, which
freezes the generated code and standalone wrapper before compilation and records
both inputs and the output binary. These wrappers currently have no commons
imports. The legacy executable was freshly rebuilt under this mechanism:
`var/document/native-attempts/20261018T073735Z-3c34559abfcb/compile-inputs.json`.
Its receipt binds the successful quotation proof and `tools/document/document_main.sml`;
its extracted startup checks passed. This is a new build record, not an attestation
applied retrospectively to an old executable.

```
sh tools/document/build.sh \
  var/document/remote-attempts/20261018T071146Z-0bfc8b40564a/receipt.json
sh tools/document/build_anchors.sh <successful-anchor-attempt>/receipt.json
.venv/bin/python -I -B tools/document/test_anchor_fetch.py
.venv/bin/python -I -B tools/document/check_anchors.py
```

Proof attempts: `20261018T072846Z-bafabf251280` was stopped after the function
package spent over 211 seconds expanding literal event-verb patterns. The worker
recorded `cancelled=true`, `build_completed=false`, exit 1 and no published
exports. Only that recorded attempt was cancelled. Retry
`20261018T074206Z-38709f747f31` uses a nonrecursive definition with string equality,
which preserves the event-cue table without generating constructor-pattern cases.

## Remaining statement route: observed semantic failures

Three current-adapter probes are saved in
`var/document/statement-anchor-baseline.jsonl`. “Tell me the capital of Chile”
returns an attributed definition of Chile, and “The director of the film Ran”
returns “A director is someone who is in charge of something.” Both replies have
`status=answered` and successful quotation checks, but do not answer the requested
relation. “The country in which the city of Lyon lies” returns a sentence naming
France and is responsive. The core panel records all three as answered, showing
why status/path parity is insufficient for this issue.

The ten recorded core `organ:converse>statement` questions are all relation-shaped
requests, saved separately in `var/document/statement-core-selected.json`. A
statement-anchor repair must preserve the whole requested property/subject or
explicitly refuse; it must not define a convenient word from the request. This
remains work beyond the first explanatory route packet.

The direct-comparison retry `38709f747f31` then ran in 7 seconds and exposed two
existential witness proof gaps. Attempt `ecd31298e827` ran in 8 seconds; its
remaining failures were the interaction of chained Isar facts with witness
introduction rules. The statements are unchanged. Attempt
`20261018T080025Z-f368cdd5bee7` supplies the witnesses before introducing the facts
needed to solve their goals. It failed in 9 seconds on method-argument syntax;
the repair brackets the compound method explicitly. The next attempt also narrows
final-s fallback subject matching and adds a corresponding negative regression. No failed export was published.

## Event-date correction found during review

The first green anchor proof (`20261018T080956Z-a643b3aedb6b`, 9 scanned
theorems, zero oracles, 16 computed checks) was compiled immutably as
`var/document-anchors/native-attempts/20261018T081544Z-7d88ea139606/compile-inputs.json`.
A separately proposed synthetic row exposed a genuine admission defect:
“Albert Einstein was born in Ulm, a city described in a 1900 atlas.” The executable
answered a birth-date question from that row because it checked for a year
anywhere in the sentence. `var/document/incidental-date-counterexample.json`
records the input and actual answer; it makes no source-truth claim.

The repair binds the year to the requested event's date phrase. Its new theorem
exposes the subject/event prefix, checked date modifier, four-digit year, and
following clause boundary within the selected source sentence. The earlier
quotation and year-presence theorems were true but insufficient. The repaired
proof and consumer checks now pass; the earlier green executable was not
integrated. Synthetic misleading-row checks measure evidence
rejection, while unsupported meaningful source questions remain valid withheld
questions, not invalid-question successes.

The pre-repair executable's 20 authored source-question assertions passed: five
answers and fifteen withholds, no errors. Those are answerability counts, not
a specialist-panel score. The 28 evidence controls exposed seven failures: three
incidental or subordinate date uses, two blank matching aliases, a whitespace
citation, and a punctuation-only requested topic. Identical duplicate aliases
remain allowed; conflicting aliases refuse. Unkeyed evidence is outside the
matching-key scope, whose source completeness remains an explicit premise.

The repaired model keeps every supplied matching-key alias and requires every
page/title to be nonblank and agree. Its snapshot equality covers all matching
aliases without excluding blank rows. The consumer uses a LEFT JOIN to retain
aliases whose article metadata is absent, rather than discarding that uncertainty.
Blank or unrelated sentence rows cannot supply an answer, while their presence
does not negate a separate valid witness; no row-completeness or uniqueness of
explanation claim is made. Release/resolved booleans are not inputs to this model.

Date attempt `20261018T081652Z-83f95f39f25d` failed on an existential proof goal
after eight seconds. Attempt `20261018T082734Z-79a1349b1661` repairs that proof
and includes the batched boundary corrections. It passed ten theorem scans with zero oracles and 22 computed checks. The first actual
composed consumer check passed 23 expected-status assertions and closed its three
recorded descendants in 291 ms on SIGTERM; this uses the earlier defective date
executable and will be repeated after the corrected native is built.

## Final checked packet

- Proof: `var/anchors/remote-attempts/20261018T082734Z-79a1349b1661/receipt.json`,
  exit 0, uncancelled, `VERI7VN_DOCUMENT_ANCHORS PASS theorems=10 oracles=0 checks=22`.
- Native: `var/document-anchors/native-attempts/20261018T083135Z-a06176c9879f/compile-inputs.json`,
  output `var/document_anchors/bin/document_anchors`, SHA256
  `6a5bda4e8fc56cbdb27c3644b4e8281328a4766af7ba2d00df6f2b3a7b5f9a9e`.
- `var/document/anchors-check.json`: 20 source-question assertions pass,
  five answers / fifteen withholds / zero errors; 28 evidence controls pass.
  The synthetic incidental-city year returns `no_direct_clause`; blank matching
  aliases return `ambiguous_anchor`. Cold process first reply 63 ms, warm median
  3.45 ms, native 284,728 bytes on this machine in this run.
- `var/document/frontdoor-check.json`: 23 composition assertions pass on the same
  anchor hash plus legacy hash `cd4aea18d1ea79219865caa9e235f2fa2073b731a6f34a4a14e6f62bfd70bcbb`.
  SIGTERM exits in 359 ms; all three recorded descendant PIDs are gone.
- Seven fetch tests pass. All five adapter/checker Python modules parse.

The final theorem statements are in `Document_Anchors.thy`. In particular,
`event_answer_bound_date` exposes a subject and event cue from the requested
finite grammar, a checked date modifier immediately after them, an actual
four-digit year, and a following clause boundary. `anchored_answer_snapshot`
requires exact alias-set coverage and authentic row membership; under these
premises every matching snapshot alias agrees on the selected page/title.
Neither proves natural-language entailment, exact-alias referent identity, or
source factual truth. The quoted sentence may contain additional source claims.

Runtime startup contract:
```
.venv/bin/python -I -B tools/document/frontdoor.py \
  --binary var/document/bin/document \
  --anchors-binary var/document_anchors/bin/document_anchors
```
It consumes ordinary `q`/`id`/`session` JSONL. Answer, error, or `taken=true`
refusal is terminal; only `taken=false` falls through. Both binaries and the
external SQLite store are runtime dependencies. This is separate from the
21-family specialist archive.

Changed paths: `src/isabelle/document/anchors/{ROOT,Document_Anchors.thy,Document_Anchors_Export.thy}`,
`tools/document/{anchor_fetch.py,anchor_answerer.py,anchor_main.sml,build_anchors.sh,frontdoor.py,
test_anchor_fetch.py,anchor_probes.json,check_anchors.py,check_frontdoor.py,build.sh}`,
this report, and the receipt argument in `C-symbolic-document-relations.md`.

Parent independently authored fourteen ordinary source questions before running
the candidate, then repeated them on final hash `6a5bda4e...`: three sourced
answers, eleven meaningful withholds, zero errors and no necessary-keyword or
exclusion failures (`var/symbolic/document-independent-final.json`). Newton's
birth sentence uses a calendar aside and spelled-out date; the narrowed finite
grammar withholds it. That is a capability limit, not an invalid question.
