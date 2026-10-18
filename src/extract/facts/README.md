# The FactsOrgan family, end to end

Twenty-two shipped Oracle7 specialists use one organ class, `FactsOrgan`
(`upstream/root/specialists/*/organ_facts_v1.py`, the same file in every folder). Each one supplies
a store, and medicine-r2 also wraps the class in a boundary. A store gives a GATE pattern the turn
must match, a BLOCK pattern it must not match, an ASK pattern that marks a question, and FACTS: an
ordered table of rows (pattern, value, sentence). The first row whose pattern matches answers with
its sentence. If no row matches, the organ is silent. This folder carries them as one interpreter
and 21 transcribed tables (medicine and medicine-r2 share a store):

literature-v2, worldhistory, arthistory, medicine-r2, medicine, law, psychology, sociology,
linguistics, poetry, botany, entomology, marinebio, ornithology, mycology, mycelial, pets, childdev,
etiquette, firesafety-v2, firstaid, javascript.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Rule, store, organ, outcome; first-match interpreter; the organ's checks in order; family order | `base/Facts_Kernel.thy` | HOL, proved; exported to SML |
| The 21 stores and 22 organs (417 rows) | `Facts_Tables.thy` | HOL constants, defined from ML string literals. `tables_check.py` checks them against each specialist's own store file |
| Well-formedness of every table; table order changes an answer in literature-v2 | `Facts_Tables.thy` | HOL, proved by simp over the literal tables |
| Export, self test, oracle check | `Facts_Export.thy` | the build fails if a listed theorem depends on an oracle or the self test fails |
| Python `re` (search, re.I, `(?-i:...)`, lookaround, `\b \w \s \d` and their negations) and `narrow_v1` | `../commons/commons.sml`, `recognizer.sml` | **untrusted**. Checked by differential test against Python on every pattern and panel question |
| JSON framing; decoding the tables' `\uXXXX` text escape to UTF-8 | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

The answerer supplies the question text, narrowing verdict and a fallback feature map.
`Word_Guards.thy` checks literal ASCII word/phrase guards itself, including every row in
the linguistics store. Its checked occurrence is conjoined with the recognizer
predicate, so it cannot undo a subject or requested-attribute restriction. It checks ASCII case folding, substring equality and word
boundaries. The driver passes actual UTF-8 bytes through the exported
`question_bytes` decoder; non-ASCII bytes count as word characters. This is a
conservative byte boundary, not complete Unicode word segmentation. Other patterns still use
the untrusted regex engine. The reply's `provenance.recognition` distinguishes
these two cases. This checks which text matched a row; it does not prove that
a source assertion is true or that a natural-language interpretation is correct.

The English recognizer normalizes equivalent question constructions and ignores
quoted wording when applying literature's opinion block. It retains trailing
scope: the unrestricted largest-animal answer is still unavailable for Loch Ness.
The human-temperature row accepts explicit human or unqualified question forms;
an arbitrary animal qualifier cannot select the human value. These recognizer
checks remain untrusted and have separate positive and negative probes.

After these features, the following selection rules are proved:

- `first_match`: the table answers row `i` exactly when its guard holds and no earlier guard holds.
- `no_rule_no_answer`: the table gives nothing exactly when no guard holds.
- `guard_exact`: the organ answers `(kind, value, sentence, store, i)` exactly when the boundary,
  narrowing, gate, block and ask checks pass and row `i` is the first match. The value and sentence
  are that row's, verbatim.
- `organ_silent`: silence happens exactly when one of those checks fails, and the reason it gives is
  the first check that failed.
- `boundary_narrows`: medicine-r2's boundary only ever removes answers.
- `order_matters`, `literature_order_matters`: the order of the table is part of the specification.
- `*_well_formed`: in every table, no guard is empty or repeated, so no row is dead by repetition.

Statements are in the [lane handoff](../../../project/lanes/O19-facts.md).

The tables are written as SML string literals because Isabelle's `STR ''...''` syntax admits no
backslash. The ML only builds terms, and each constant is an ordinary definition
(`Specification.definition`). Isabelle's string literals are 7-bit, so the two sentences that
contain a degree sign (medicine, pets) store it as `°`. The driver decodes it.

## Build and run

```sh
tools/dev/remote-build persvati src/extract/facts Veri7vn_Facts --expect 'VERI7VN_FACTS PASS'
python3 src/extract/facts/tables_check.py
sh src/extract/facts/build.sh
echo '{"id": "1", "q": "Who narrates Moby-Dick?", "session": "s"}' | var/facts/bin/facts --specialist literature-v2
python3 src/extract/facts/score.py
```

The binary is not committed. It lives under `var/facts/bin/`.

`Facts_Tables.thy` is generated. `sh src/extract/facts/gen/regen.sh` rewrites it from the shipped stores
(`gen/gen_tables.py`, not trusted), and the output is byte-identical to the committed file.
`tables_check.py` is the independent check.

The recognizer calls `Regex.compileI` from `../commons/commons.sml`, not the plain `Regex.compile`.
`compileI` folds case inside the matcher, as Python's re.I does, and supports the case-sensitive group
`(?-i:...)`. firesafety-v2's `(?-i:\bPASS\b)` and firstaid's `(?-i:\bRICE\b)` need that group: with
`compile`'s convention of lower-casing the text, those patterns could never match. (Until lane W5-12 this
family carried its own `regex.sml` for that; the case modes now live in commons.)

## Completed second packet

All 22 specialists and family mode score **221/221 dev and 207/207 heldout**,
with zero wrong answers, false yeses or valid omissions. Seven reachable
heldout omissions were closed through existing rows. Typed question grammars
now keep animal measurements out of human rows, newborn teeth out of adult
counts, definitions out of attribution rows, and local records out of global
rows. These recognizer interpretations remain untrusted.

The second export passed 63 theorem checks with zero oracles. The checked
literal syntax now covers 115 of 417 source guards (58 single words plus 57
phrases); this is a syntactic inventory, not a world-truth theorem. All 113
positive/negative probes pass natively, in unpinned family mode and through the
actual dispatcher. Creator answers retain the known work title matched by the
selected row; original source prose remains in `provenance.source_sentence`.
Title extraction/rendering is untrusted, and arbitrary user qualifiers are not
copied into the answer.

Across each specialist's 924 core questions there are two status/value changes:
impossible-date artwork questions now stay silent. Six further differences only
retain the matched work title in the response. These fixed panels have no
fresh random seeds. The binary is 422,872 bytes.

`build.sh` uses the shared `tools/dev/native-compile` helper to freeze the actual
MLB inputs, validate their checked export against a passed proof receipt and
publish the binary atomically. `FACTS_GEN` and `FACTS_RECEIPT` can pin an immutable
export and proof receipt. Main and recognizer changes after the proof snapshot
are bound separately in the native receipt; the proved theories match.

Exact proof/native receipts, theorem statements, per-specialist review limits
and remaining useful extensions are in
[the continuation report](../../../project/lanes/C-symbolic-facts-humanities.md).

## Third packet

The third packet adds a checked finite JavaScript expression evaluator and
source-bound requested-field projections for anomie and mycorrhizal exchange.
It passed 72 theorem checks with zero oracles. Whole expressions preserve case,
precedence and string content; numeric intermediates stay within the safe-integer
interval. Unsupported operations decline. This is not a complete ECMAScript model.
Source projections validate the actual selected source row; their transcribed
world assertions remain assumptions.

Current native and dispatcher probes contain 98 supported answers, 102 valid or
underspecified requests withheld, and 3 malformed-expression refusals. All 203
policy assertions pass; a refusal assertion is not an answered capability.
Two independent generated JavaScript corpora produce 673 Node-matching answers,
0 wrong answers and 127 withheld-valid out of 800 expressions. Shipped panel
numbers remain 221/221 dev and 207/207 heldout for specialists and family mode.
The current binary is 497,864 bytes. See the report for exact receipts, source
bindings, new theorem statements, corpus seeds and outstanding scope gaps.
