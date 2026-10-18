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
`Word_Guards.thy` checks literal `\bword\b` guards itself, including every row in
the linguistics store. It checks ASCII case folding, substring equality and word
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

## Current result

All 22 specialists score **221/221 dev and 207/207 heldout**, with zero wrong,
false yes or valid omissions. Family mode now gives the same counts. Seven
reachable heldout omissions were closed through existing table rows, and an
older family-order error (human medicine answering a dog's temperature) was
removed. All 924 core questions for each specialist still match its shipped
organ's status, kind, value and response text.

The final export passed 62 theorem checks with zero oracles. There are 29/29
positive and negative probes through the native binary and actual dispatcher,
plus 3/3 unpinned family temperature-scope probes. These fixed Facts panels have
no fresh random seeds. The binary is 385,480 bytes; median cold start is 5.35 ms,
and specialist median round trips range from 0.240 to 1.449 ms.

Exact proof/native receipts, theorem statements, scope and remaining limits are
in [the continuation report](../../../project/lanes/C-symbolic-facts-humanities.md).
The recognizer's final temperature narrowing follows the proof snapshot; native
input hashes bind that change separately from the unchanged proved theories.
