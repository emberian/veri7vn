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
| Python `re` (search, re.I, `(?-i:...)`, lookaround, `\b \w \s \d` and their negations) and `narrow_v1` | `regex.sml`, `recognizer.sml` | **untrusted**. Checked by differential test against Python on every pattern and panel question |
| JSON framing; decoding the tables' `\uXXXX` text escape to UTF-8 | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

The kernel never reads text. Its inputs are the narrowing verdict and a feature map
`m :: String.literal => bool`, which says whether a given pattern of the store matches the turn.
The untrusted recognizer computes both. Everything after the features is proved:

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
python3 tools/dev/check-native --session Veri7vn_Facts --session-root src/extract/facts \
  --expect 'VERI7VN_FACTS PASS' --timeout 600
python3 src/extract/facts/tables_check.py
sh src/extract/facts/build.sh
echo '{"id": "1", "q": "Who narrates Moby-Dick?", "session": "s"}' | var/facts/bin/facts --specialist literature-v2
python3 src/extract/facts/score.py
```

The binary is not committed. It lives under `var/facts/bin/`.

## Current result

All 22 specialists were run on their own panels with `--specialist ID`. Every held-out count equals
the shipped verdict. Wrong answers: 0. False yes: 0.
- 18 specialists answer every held-out item.
- literature-v2 answers 11 of 12. botany, marinebio and ornithology each answer 7 of 9. These are
  the organs' own misses, reproduced with the same silence.
- Every dev split is fully right.

The binary was compared with the shipped organ, byte for byte. That covers every panel question,
plus all 924 core-panel questions for each specialist. Status, kind, value and response text agree
on every one, with 0 differences.

The binary is 335 KB and starts in about 7 ms. The median time per question in the binary is under
0.5 ms, against a budget of 50 ms. Details: [lane handoff](../../../project/lanes/O19-facts.md).
