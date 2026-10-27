# Research with Oracle7

Use this pack to check a small literature research workflow: authorship, edition
dates, related people, pen names, ambiguous names, and following an answer to its
source. Expectations and their independent sources are separate from engine inputs.

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/research/cases.json \
  --out var/usage-20261026/research/new-baseline
.venv/bin/python -B tools/usage/research/dossier.py \
  --results var/usage-20261026/research/new-baseline/results.jsonl \
  --requirements tools/usage/research/requirements.json \
  --out var/usage-20261026/research/new-dossier.json
```

The dossier retains each complete runner record. It adds navigation links for
Wikidata entity/property IDs and flags mismatched requested relations. For
example, a composer request needs P86: an inverse P800 “notable work” association
does not answer it. Links are not fetched or certified. Opaque corpus references,
unknown evidence fields, clarifications and refusals remain intact. A clean
dossier is not evidence that an answer is true; it still needs source review.

Practical workflow established by the retained runs:

1. Ask one relation at a time: “Who wrote Frankenstein?” works; a Mary-versus-Percy
   comparison did not parse. Preserve the first reply's references immediately.
2. Include the work type for a shared title: “When was the book Leaves of Grass
   published?” returned 1855; the unqualified title produced book/film ambiguity.
3. Carry full names and entity IDs between research steps. “John Edward Williams”
   retrieved the novelist's 1922 birth; bare “John Williams” selected the composer.
4. Ask for a person's biography when the alias question fails. “Who is George
   Eliot?” returned Mary Ann Evans; “real name” did not parse.
5. Review the property in a receipt, not merely the presence of a citation.
   The original composer question with “(1977)” returned a wrong P800 answer.
   Shorter composer questions returned the correct P86 answer. These are observed
   workarounds, not a claim that untested wording is safe.

“What source supports that answer?” and “Sources?” both failed after a correct
authorship answer. The dossier makes already-returned evidence inspectable without
depending on a conversational source-follow-up. It cannot resolve opaque corpus
IDs or establish that a quoted passage entails the answer.

`relation-semantics.patch` records the approved source repair against the passing
candidate's `root/wander-train/relation_spec_v1.py`. It reads explicit composer
requests through P86 and checks an optional parenthesized publication year. It
retains whole-title alias matching and agreement over eligible candidates; missing
composition data never falls back to a notable-work association. It also repairs
three misleading receipt labels (P26 spouse, P86 composer, P800 notable work).
The live reader check is narrower than an integrated engine result.

Run the scoped regressions:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/research -v
```

The semantics tests use `var/ap1-upstream-slim/root/wander-train/relation_spec_v1.py`
by default; set `RESEARCH_RELATION_SOURCE` to exercise another patched package.
No shipped specialist panels were run by this lane. Usage outcomes are recorded
in `outcomes.json`; they are not a fleet score.
