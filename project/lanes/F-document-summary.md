# Source-backed extractive summaries

Wrap-up preservation: the unfinished five-file source draft is committed and
pushed on `codex/parked-document-summary-20261018`, commit `9525094`. Its
branch-only `project/parked/document-summary-20261018.json` records exact hashes
and the blocker. Active checkout files now match the committed E predecessor.
The unpublished parser proposal and independent questions are also preserved on
`codex/parked-staged-proposals-20261018`. This preserves unfinished work; it does
not make the summary proof or capability complete. Local evidence remains intact.

Owner: Codex document lane. Builds on E discourse, integrated as `0b185dc`.
This packet is unfinished and frozen after the final allowed drain build failed.
No summary native or capability result is claimed. The integrated E discourse
native and its parser remain active.

The E full-dispatch check is recorded separately at
`var/dispatch/successor/20261018T102017Z/receipt.json`: three discourse requests
answered through Document. Chile's capital was answered by Geography and the
square's area by GeoStats (40000 cm²), so those are not Document refusal checks.
Ran's director remained withheld. Two originally expected refusals were useful
upstream answers; the initial 8/10 assertion count is not a wrong-answer count.

## Behavior and scope

The successor accepts the complete requests “Summarize <topic>” and “Give me a
summary of <topic>”. It preserves articles inside names such as The Cure. The
same matching-alias agreement and source-page witnesses used by discourse govern
this request. Every selected sentence must begin with the requested subject or
its explicitly permitted title and one of the finite supported clause forms.

The extracted decision selects up to three distinct passages in supplied source
order, removing repeated citation IDs or identical sentence text. Each passage
is quoted with its own citation under “Selected source passages about <topic>”.
It does not paraphrase the passages, claim that they cover the entire source,
resolve source contradictions, or establish factual truth. Fetch returns at most
60 rows. The selected source excerpts are an extractive summary, not a proof of
general natural-language summarization or entailment.

The source survey found useful passages for photosynthesis, penicillin,
chlorophyll, digestion, volcano, earthquakes, The Cure and The Band. Some
otherwise meaningful requests have no matching supplied clause. Albert Einstein's
available biography opens with parenthetical dates, outside the finite grammar;
Mercury's source association supplies no directly matching sentence.

## New statements

- Summary selection implies a supported whole request and agreeing supplied
  matching aliases. It returns one to three claims with distinct citation IDs
  and distinct literal sentences.
- Every selected claim comes from a supplied row with the matching page, source
  page and title, a nonblank citation, and the requested subject/clause syntax.
- If all matching aliases are supplied and all supplied rows belong to the
  source snapshot, every selected claim has that source witness and all matching
  snapshot aliases agree. Neither premise is replaced with a checked flag.
- The actual rendered reply contains the source sentence of every selected
  claim, not only the first one.

## Checks and receipts

First proof attempt `20261018T102454Z-6f557e9d1e8e` failed after seven seconds
of proof execution. Retained diagnostics:
`var/anchors/remote-attempts/20261018T102454Z-6f557e9d1e8e/results/session.log`.
Three induction proofs needed explicit cases on the row list; the final quotation
proof needed an explicit output-prefix witness; code export rejected a natural
number constructor under the target's numeric representation. The successor adds
the list cases, supplies that prefix, and proves an executable recursion equation.

The final authorized repaired attempt, `20261018T103246Z-b2131bc4ca39`, failed
in five seconds at `Document_Anchors.thy` line 180: `code del` is not a valid
attribute argument in Isabelle2026-RC1. It stopped before the remaining proof
repairs or export could be checked. The retained diagnostics are in
`var/anchors/remote-attempts/20261018T103246Z-b2131bc4ca39/results/session.log`.

The installed Isabelle implementation, `src/Pure/Isar/code.ML` lines 1616–1619,
accepts `code drop`. That one-word correction is now in the frozen source but
has **not** been built. No third attempt was launched. Both collectors exited,
all receipts are collected, and no lane-owned job remains active. The marker
14 theorem scans / zero oracles / 32 checks remains an intended target, not an
achieved result. The old E native and parser remain active; no summary export
or native was published.

`var/document/summary-before.json` records three actual E baseline requests:
“Summarize photosynthesis”, “Summarize The Cure”, and “Give me a summary of
digestion”; all three returned ordinary clarification, with no answer.

Fifteen authored source requests are written before this native, including whole
topics, article-bearing proper titles, comparison suffixes, negation and missing
supported clauses. These will report answers, meaningful withholds and errors
separately from assertion passes. Eleven synthetic evidence controls test the
third selected passage, citation/text deduplication, the three-passage bound,
blank matching aliases, whole-question binding and flags that must not release
wrong-page rows. They make no claim of actual source truth.

The parent independently prepared six ordinary requests before the new native:
`var/symbolic/document-summary-independent-questions.json`. These are review
expectations, not mandates to answer unsupported requests.

The recorded 924-item core panel contains five summary-path items, but all five
are nominal relation requests (four currencies and the inventor of dynamite),
not actual summary commands. They are recorded in
`var/document/summary-core-selected.json`; the relation lane owns their full
property/subject interpretation. There are zero recorded questions using the two
new summary forms, and no shipped specialist panel score for this capability. The theorem
checks and authored controls are not substitutes for one.

## Consumer and remaining work

The existing document frontdoor will consume the new constructor in the same
native. Only a silent request falls through; missing/ambiguous/no-clause replies
remain terminal. Parser publication, actual native checks and composed default
routing remain to do after proof succeeds. Timeline and simple-explanation
composition, and legacy weak-definition admission, remain separate outstanding
work.

## Exact retained work and resume commands

Owned source paths for this packet:

- `src/isabelle/document/anchors/Document_Anchors.thy`
- `src/isabelle/document/anchors/Document_Anchors_Export.thy`
- `tools/document/anchor_main.sml`
- `tools/document/check_summary.py`
- `tools/document/summary_probes.json`
- `project/lanes/F-document-summary.md`

The summary parser proposal is retained, deliberately unpublished, in
`var/document/summary-parser-line.txt`. After successful proof and native build,
insert that exact line after `FORMS = [` in `tools/document/anchor_fetch.py`.
Then add summary to the existing whole-request reconstruction test in
`tools/document/test_anchor_fetch.py`. Keep articles inside summary topics.

Both failed attempts have been fully collected. After the drain, when this
packet is explicitly resumed, build the corrected source once:

```sh
tools/dev/remote-build persvati src/isabelle/document/anchors Veri7vn_Document_Anchors -d src/isabelle/document --expect 'VERI7VN_DOCUMENT_ANCHORS PASS theorems=14 oracles=0 checks=32'
```

Use that **new successful receipt**, not either failed receipt, for the native:

```sh
sh tools/document/build_anchors.sh var/anchors/remote-attempts/NEW_SUCCESSFUL_ATTEMPT/receipt.json
```

After publishing the summary parser line, run the focused consumer checks:

```sh
.venv/bin/python -I -B tools/document/check_summary.py
.venv/bin/python -I -B tools/document/check_anchors.py --out var/document/summary-existing-regression.json
.venv/bin/python -I -B tools/document/test_anchor_fetch.py
```

Inspect actual selected passages; pass counts alone do not establish useful
summarization. Parent has the six independent prewritten questions. Run a narrow
Document frontdoor/default-dispatch composition check and freeze/capture the new
native and exact sources before root integration. The corrected source still needs actual proof/export/native confirmation. Keep
the parser unpublished until it has that matching binary. Do not treat the local
syntax correction or prepared controls as successful summary checks.
