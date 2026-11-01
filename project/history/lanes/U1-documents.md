# U1 documents: supplied text, 26 October 2026

The passing candidate can answer some direct yes/no questions about a short
inline passage with a quote. It did not complete ordinary document summaries,
timelines, open questions, cross-sentence comparison, or a passage follow-up in
this experiment. A conflicting pair of versions produced an incorrect answer.

No shipped specialist panels ran. These are 14 authored usage tasks, not panel
numbers or evidence of a fleet-wide score. No theorem was added or claimed.

## Actual use

Inputs and independently written expectations:
`tools/usage/documents/cases.json` and `expectations.json`.
Run: `.venv/bin/python -B tools/usage/run_batch.py --cases tools/usage/documents/cases.json --out var/usage-20261026/documents/run-1`.
All 14 obtained HTTP 200 replies; runner exited 0. Complete replies, raw bytes,
request text and timing remain in that output directory.

| Task ID | Actual outcome | Assessment |
|---|---|---|
| plain-owner | Asks what “this” refers to, despite inline text | Answerable task uncompleted |
| yes-owner | Yes; quotes Nira Vale as director | Correct answer |
| followup | No admitted record for opening date | Answerable task uncompleted; prior passage not retained as a document |
| absent | No covering Sunday sentence | Appropriate withholding |
| negation | No; quotes “not open on Sunday” | Correct answer |
| factoid | Did not parse “Who is the director” | Answerable task uncompleted |
| summary | Did not parse inline summary task | Answerable task uncompleted |
| timeline | Says admitted material on Archive contains zero dated statements | Answerable task uncompleted; supplied dates did not reach timeline route |
| comparison | No single covering sentence | Answerable task uncompleted; 2018 versus 2020 requires two sentences |
| conflicting-versions | Yes; quotes only version one | Incorrect answer; version two explicitly says not open |
| citation | No covering sentence after citation instruction appended | Answerable task uncompleted; extra instructions become question terms |
| fiction-scope | Yes; quotes fictional Mira Voss author statement | Correct within supplied fictional scope, without substituting background knowledge |
| ordinary-summary | No provenance-admitted material to summarize | Answerable task uncompleted |
| modal | Planned opening does not settle present opening | Appropriate withholding |

Totals: **3 correct answers, 2 appropriate withholds, 8 answerable tasks left
uncompleted, 1 incorrect answer**. The statuses were 4 answered, 7 withheld,
3 clarification. HTTP latency min 0.038415 s, median 0.123283 s, max 2.803296 s;
these include transport and exclude startup, and are not a benchmark.

The simple successful question already cites its source sentence. Appending
“Cite the supporting sentence” turns it into a failure. The contradiction is more
serious: lexical coverage selects one sentence without considering the opposing
sentence at equal coverage. A displayed source quote is not enough assurance.

## Supported input, checked against source

`tools/appliance/serve.py` accepts exactly request_id, conversation_id, text.
The worker calls `Engine.chat`, whose wrapper exposes no ingestion operation.
Runtime D has `ingest_document(session_id, title, text)` internally; this does
not make it an HTTP API. The live passage grammar is anchored, case-sensitive
`Passage: ... Question: ...`; w434 handles the surface and w442 overrides its
passage matching with aliases. The last Question delimiter separates the question.
Its yes/no reader selects one covering sentence. It is not a general document QA
or summarization interface. These are interface limitations plus routing/reader
defects, not missing real-world records: all needed facts were supplied.

## Implemented workflow

`tools/usage/documents/prepare.py` reads a small UTF-8 file, writes runner cases
and a source manifest, and inspects retained replies. It preserves complete
source text, normalizes only request whitespace, repeats the passage for every
question, and refuses oversized requests instead of truncating them. It warns
on question shapes outside the inline yes/no reader. It never guesses an answer
or rewrites a question into a different task.

Inspection preserves the complete Oracle reply, checks it belongs to the exact
prepared request, and maps passage quotes to all matching source line ranges.
Source bytes are hashed. Matching text is explicitly not entailment or truth.
The archive fixture compiles to exactly the original successful live `yes-owner`
request; its retained real answer was inspected and maps to source line 2.
Artifacts are under `var/usage-20261026/documents/prepared-1/`.

This benefits someone asking bounded questions about a short local note: it
removes guesswork about input grammar and provides usable local citations.
It does not solve summaries, persistence, attachments, or broad reading.

## Concrete reader repair

With root's explicit ownership approval, edited only:
`var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w442.py`.
Before editing, checked its bytes matched the immutable passing candidate.
The candidate was not modified. The reproducible patch is
`tools/usage/documents/conflicting-passages.patch`; isolated copy is under
`var/usage-20261026/documents/repair/`.

The repair collects verdicts from covering sentences. If comparably covered
sentences produce opposite verdicts, it withholds and returns all such source
quotes. A partial lexical match for a different archive does not veto a fully
covered answer: candidate coverage must be at least the selected sentence's
coverage. Existing alias coverage is retained. This is a narrow conflict guard,
not a semantic contradiction solver or a rule that newer versions win. It can
miss conflicts whose wording is not covered and can over-withhold when a
historical change is explicitly described. It preserves uncertainty.

Checks: `.venv/bin/python -B -m unittest discover -s tests/usage/documents -p 'test_*.py' -v`:
**8 tests passed**. Five cover preparation, byte bounds, grammar, source/request
identity and multiline/duplicate quote locations. Three isolated method tests
cover the original bug and both version orders, positive/negative/agreement and
different-subject controls, missing and modal facts. They AST-load actual helper
and verdict code, apply the patch to a temporary source copy, and disable WordNet
aliases because these cases use literal words. The original method answers the
conflict; patched method withholds and retains both complete quotes.

These scoped method regressions were followed by the combined-candidate
full-engine check below. They remain separate from shipped specialist panels.

Changed owned files: `tools/usage/documents/{prepare.py,README.md,archive.txt,questions.json,cases.json,expectations.json,conflicting-passages.patch}`,
`tests/usage/documents/{test_prepare.py,test_conflict_repair.py}`, and this report.
Consumer: shared runner, small-text users, and root's appliance patch integration.


## Combined-candidate full-engine check

Ran the original 14 cases unchanged against
`var/usage-20261026/candidate-first`:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --runtime var/usage-20261026/candidate-first \
  --cases tools/usage/documents/cases.json \
  --out var/usage-20261026/documents/run-combined-1
```

All 14 received HTTP 200, zero transport/HTTP errors, adapter return code 0.
The conflicting-version task now returns `withheld` on
`reading:withheld|vessel:receipt`:

> The passage contains covering sentences with conflicting answers, so I will not choose a version.

Its references retain both complete source sentences:

- Version one says the Lumen Archive is open on Sunday.
- Version two says the Lumen Archive is not open on Sunday.

All other 13 cases have exactly unchanged **status, path, response text and
references** compared with the original passing candidate. In particular,
`yes-owner`, `negation`, and `fiction-scope` remain correct answers; the missing
fact and modal cases remain appropriate withholds. The unchanged fields do not
claim every metadata field or latency is identical.

Combined result: **3 correct answers, 3 appropriate withholds, 8 answerable tasks
left uncompleted, 0 incorrect answers**. This demonstrates the narrow conflict
repair in the actual engine; it does not add the eight missing document tasks.
HTTP latency min 0.052091 s, median 0.2171335 s, max 6.233176 s, excluding startup.
No performance inference is drawn from these concurrent usage runs.

Complete combined replies, bytes, prompts and timing remain in
`var/usage-20261026/documents/run-combined-1/`. The original candidate and the
combined candidate were not edited. No further source repair was needed.
