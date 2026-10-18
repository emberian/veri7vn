# Relation and document routes through the running system

Owner: Codex, 18 October 2026. This is a consumer-completion packet, not a
claim that all document semantics or all reader assurance work is finished.

## What now runs

`tools/relations/frontdoor.py` accepts ordinary `q`/`id`/`session` JSON lines.
It owns one persistent extracted relation decision process. It first matches
reader expressions, then asks only the matching specialists; it does not start
161 processes or query every store for unrelated questions. Each specialist's
compiled table is compared with its shipped configuration before use.

The general route requires all decisive readers to agree about the subject,
property, value and whether to answer. A refusal cannot be overwritten by a
different reader's answer, even for the same subject and property: their linker
pools can differ. Disagreement becomes a decisive withheld reply. Silence falls
through. This cross-reader composition is Python and is explicitly untrusted.

The existing pinned relation answerer keeps its previous decision and text.
Its provenance now identifies the actual store path, size and modification
time, the candidate/property scope, the finite linker and inverse limits, and
the coverage assumption. These filesystem facts are not a content digest.
Snapshot values are displayed labels with blanks removed; one label does not
establish one underlying entity. The `snapshot_complete_wrt` premise is not
reported as a check of omitted rows. The symbolic deputy owns the conditional
snapshot theorem in the relation theory.

The document adapter accepts `--binary`, marks captured refusals as decisive,
and marks generic terminal clarification as fallthrough. It reports fetched
claim identifiers and the actual kernel status, path and citations. A Python
presentation check now preserves those fields and the cited sentences; if a
decoration removes or rewrites a quoted sentence, it keeps the kernel's reply.
Neither this check nor the kernel's word-overlap rule proves factual entailment.

The runtime deputy integrates both adapters after specialist/math routes and
before the final fallback. Bare-phrase document captures are fallback routes;
they must not intercept an earlier recognized specialist request.

Both adapters close their own kernel child on input EOF and SIGTERM, including
when dispatch times out while a read is blocked. Cleanup waits briefly, then
terminates only the recorded child process if needed. An actual SIGTERM test
started each adapter and found its exact child PID; both exited with no surviving
kernel children. Receipt: `var/document/codex-shutdown-check.json`.

## Measurements

Four shipped held-out panels were scored through the **general** front door.
These are deliberately distinct from the prior specialist-pinned scores:

| Specialist | Items | Prior pinned right | General route right | Wrong | Extra withheld |
|---|---:|---:|---:|---:|---:|
| rel-novels | 60 | 41 | 35 | 0 | 6 |
| rel-films-v2 | 84 | 51 | 47 | 0 | 4 |
| rel-countries-v2 | 84 | 60 | 59 | 0 | 1 |
| rel-novelists | 96 | 96 | 86 | 0 | 10 |

All 21 extra withholds are explicit cross-reader ambiguity. Examples include
a novel and film with the same title but different publication dates, and
people with the same name in different occupations. Some are a same-subject
answer/refusal conflict between specialist rules. They remain withheld until
the reason for the refusal can be distinguished safely. The totals are
227 right, 0 wrong and 97 withheld over 324 all-positive items. The panel's
reported false-yes count is zero but does not measure behavior on invalid
questions. The other exam criteria were not measured by this scoped run.

Receipts: `var/relations/codex-frontdoor-heldout/`. Two initial harness commands
used nonexistent specialist IDs (`rel-films`, `rel-cities`) and produced harness
errors; the correct `-v2` IDs above were then measured. Those errors are not
included as question results.

Committed integration probes add 6 familiar factual questions and 20 negative
questions: wrong domains, absent names, incomplete questions and unrelated
requests. **6/6 positive answers, 20/20 negative abstentions, 0 errors.** These
probes were written by this adapter's author; they are not independent fresh
panels. The measured first reply was 128.1 ms including Python and table loading;
warm p50 was 0.318 ms. The first-reply budget of 20 ms is not met by this adapter.
Receipt: `var/relations/codex-frontdoor-probes.json`.

The symbolic deputy independently wrote 10 more adversarial questions outside
that set, covering negation, conjunction, time qualifiers, fake-title qualifiers,
trailing instructions, counterfactuals, ambiguous names and false attribution.
**10/10 withheld, 0 errors**; the ambiguous name was decisive and the other nine
fell through. Receipt: `var/symbolic/relations-independent-probes.json`. These
are independently authored adversarial checks, not fresh shipped-generator
panels or a broad measured false-yes rate.

Six composition tests cover equal claims, conflicting subjects/values/properties,
mixed answer/refusal, incomplete evidence, empty routing and decisive declines.
Nine document tests cover quotation rewrite, status/path/citation rewrite,
preserving decoration, missing rows, in-place citation mutation, absent citations,
empty sentences and empty citation IDs. A withheld reply with no citations
reports quotation checks as not applicable, not as successful empty checks.
Both suites
pass. They test the Python boundary; they are not theorem proofs.

Actual document adapter probes with the existing binary:

- `The currency of India`: withheld `capability:summarize`, `taken=true`.
- A made-up unknown book author: `act:clarify`, `taken=false`.
- `What is photosynthesis?`: answered from a cited source sentence;
  the quoted sentence, citation and decision survive presentation.

No new document specialist-panel score exists: this route has no specialist
panel. A full core-panel comparison was not rerun for metadata and a quotation
preservation check.

## Proof and build

New `answer_reply_quotes_sentence` states:

```
decide t ev = Answer c e
  ==> EXISTS pre suf.
        response_of t ev (decide t ev) = pre @ sentence c @ suf
```

It connects the actual rendered answer to the sentence in its cited claim,
using `answer_reply_carries_citation`. It is included in the final oracle scan.
The source assertion, fetched row authenticity and interpretation of the
question remain outside the theorem. Python presentation preservation is a
separate executed check, not covered by that HOL theorem.

Build status: pending. The first remote attempt
`20261018T063216Z-506ab3e2cfd1` was cancelled while queued after a transport
failure; no proof ran. The build owner recovered that receipt and repaired the
transport retry behavior before the current attempt was submitted.

## Remaining work and boundaries

- Document `anchor_present` still depends on fetched `resolved` and
  `conjunctive` fields. Replacing them with a nonempty-ID test would not establish
  a question-to-page anchor. A proper fix needs a title/FTS witness tied to the
  question and the claim fields, with the fetch and fixtures updated together.
- The audit's description of `released` as a fetch flag is stale: it already
  computes `def_question ev AND names_term ev c` in HOL. The question-class flag
  remains untrusted; the cited sentence's term overlap is checked in HOL.
- Summary, timeline and explain-simply composition remain unimplemented; their
  recognized captures deliberately withhold. The timed, untrusted bridge and
  the heavy original Python imports remain expensive.
- No new external relation data was acquired. Missing properties and omitted
  source metadata were not fabricated. The all-positive relation panels still
  need independently generated invalid/ambiguous cases beyond these probes.
- General routing loses coverage relative to a caller that already knows the
  specialist. It does not silently assume that hidden panel domain.

## Reproduce

```
.venv/bin/python -I -B tools/relations/test_frontdoor.py
.venv/bin/python -I -B tools/relations/check_frontdoor.py
.venv/bin/python -I -B tools/document/test_presentation.py
.venv/bin/python -I -B tools/parity/harness.py \
  --answerer '.venv/bin/python -I -B tools/relations/frontdoor.py --binary var/relations/bin/decide' \
  --specialist rel-novels,rel-films-v2,rel-countries-v2,rel-novelists \
  --split heldout --out var/relations/codex-frontdoor-heldout --timeout 15
tools/dev/remote-build persvati src/isabelle/document Veri7vn_Document \
  --expect 'VERI7VN_DOCUMENT PASS'
sh tools/document/build.sh
```

Changed paths owned here: `tools/relations/{answerer.py,fetch.py,frontdoor.py,
test_frontdoor.py,frontdoor_probes.json,check_frontdoor.py}`,
`tools/document/{answerer.py,test_presentation.py}`,
`src/isabelle/document/{Document_Route.thy,Document_Route_Export.thy}`, and this
report. No files under `upstream/` were edited; Python ran with bytecode disabled.
