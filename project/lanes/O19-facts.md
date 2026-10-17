# Lane O19-facts: the FactsOrgan family (handoff, 2026-10-17)

Twenty-two Oracle7 specialists share one organ class, `FactsOrgan`
(`organ_facts_v1.py`, byte-identical in every folder). medicine-r2 wraps it in
`FactsOrganBoundary`. The lane lifts them as **one verified interpreter plus 21
transcribed rule tables**, not as 22 kernels. Medicine and medicine-r2 share a store.
The tables hold 417 rows. Everything is exported to SML and compiled with Isabelle's
MLton into one binary, `var/facts/bin/facts` (334,536 bytes, not in git). The binary
speaks the answerer contract, with `--specialist ID` for one manifest. With no
argument it asks the whole family in order.
Files: `src/extract/facts/` ([README](../../src/extract/facts/README.md)).

## Result on the shipped panels

Counts are right / wrong / withheld on a valid item / false yes. The harness
(`tools/parity/harness.py`, `--specialist {id}`) and the lane's `score.py` give the same counts.

| Specialist | dev n | dev right/wrong/withheld-valid/false-yes | held-out n | held-out | shipped held-out | p50 in binary (ms), budget 50 | core taken (harness, cap 9) |
|---|---|---|---|---|---|---|---|
| literature-v2 | 18 | 18/0/0/0 | 12 | **11/0/1/0** | 11/12, 0 wrong, 0 fy | 0.44 | 7 |
| worldhistory | 11 | 11/0/0/0 | 11 | **11/0/0/0** | 11/11 | 0.09 | 0 |
| arthistory | 11 | 11/0/0/0 | 11 | **11/0/0/0** | 11/11 | 0.11 | 1 |
| medicine-r2 | 9 | 9/0/0/0 | 9 | **9/0/0/0** | no shipped verdict | 0.20 | 0 |
| medicine | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.34 | 0 |
| law | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.12 | 0 |
| psychology | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.24 | 0 |
| sociology | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.36 | 0 |
| linguistics | 11 | 11/0/0/0 | 11 | **11/0/0/0** | 11/11 | 0.13 | 0 |
| poetry | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.06 | 1 |
| botany | 9 | 9/0/0/0 | 9 | **7/0/2/0** | 7/9 | 0.14 | 0 |
| entomology | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.11 | 0 |
| marinebio | 9 | 9/0/0/0 | 9 | **7/0/2/0** | 7/9 | 0.10 | 0 |
| ornithology | 9 | 9/0/0/0 | 9 | **7/0/2/0** | 7/9 | 0.08 | 0 |
| mycology | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.10 | 0 |
| mycelial | 7 | 7/0/0/0 | 7 | **7/0/0/0** | 7/7 | 0.15 | 0 |
| pets | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.19 | 0 |
| childdev | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.28 | 0 |
| etiquette | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 1.29 | 0 |
| firesafety-v2 | 18 | 18/0/0/0 | 10 | **10/0/0/0** | 10/10 | 0.41 | 0 |
| firstaid | 9 | 9/0/0/0 | 9 | **9/0/0/0** | 9/9 | 0.33 | 0 |
| javascript | 10 | 10/0/0/0 | 10 | **10/0/0/0** | 10/10 | 0.15 | 0 |

Every held-out count equals the shipped verdict. Wrong answers: 0 everywhere. False yes: 0 everywhere.
The 7 held-out misses are the organs' own misses: the shipped organ also withholds them.
They are reproduced exactly, with the same silence reason:
- literature-v2: "Which book begins 'It was the best of times, it was the worst of times'?"
  (BLOCK matches `\bworst\b`).
- botany: "Describe the vein pattern in dicot leaves: parallel or net?" (no ASK word) and
  "What is the function of stomata in plants?" (no row).
- marinebio: "Which animal is the biggest that has ever lived?" (off GATE) and
  "Which fish is the largest in the ocean?" (no row).
- ornithology: "Which bird is the fastest when diving?" and
  "Which animals are the only ones with feathers?" (both no row).

**Agreement with the organ, byte for byte.** `score.py` runs the shipped organ in Python next to
the binary. It covers every panel question of the 22 specialists, and also all 924 core-panel
questions (`upstream/workbench/data/core_panel.json`) for each specialist, about 21,000 replies.
Status, kind, value and the full response text are identical on every one: **0 disagreements**. The
one family-mode difference is expected. For "What is a dog's normal body temperature?" medicine is
earlier in the family order and answers first.

The harness decision is `INCOMPLETE` for every specialist only because no head answerer was run, so
DOMAIN and FALSE YES against the core are unmeasured. Lane, self and budget hold. Core takes are
within the cap of 9: literature-v2 7 ("Name the author of War and Peace", and so on), arthistory 1,
poetry 1, every other specialist 0. The organ takes the same core questions (0 disagreements above).
Cold start is 6 to 11 ms. The slowest question takes 4.3 ms in the binary (literature-v2).

## What is proved (session `Veri7vn_Facts`, marker `VERI7VN_FACTS PASS theorems=36 oracles=0`)

The kernel never sees text. Its input is the narrowing verdict `narr` and a feature map
`m :: String.literal ⇒ bool`. For each pattern of the store, the feature map says whether that
pattern matches the turn. The untrusted recognizer supplies both. An organ is
`Organ id boundary (Store name kind gate block ask rules)`, and a rule is
`Rule guard fact_value sentence`. `admitted narr m og` is the conjunction of the checks that come
before the table: not boundary-silent, not narrative, the gate matches, the block does not match,
and the ask matches.

Statements, verbatim:

```
theorem first_match:
  "interpret_table m rs = Some (i, r) ⟷
     i < length rs ∧ rs ! i = r ∧ m (guard r) ∧ (∀j<i. ¬ m (guard (rs ! j)))"

theorem no_rule_no_answer:
  "interpret_table m rs = None ⟷ (∀r ∈ set rs. ¬ m (guard r))"

theorem interpret_table_local:
  assumes "∀r ∈ set rs. m (guard r) = m' (guard r)"
  shows "interpret_table m rs = interpret_table m' rs"

theorem order_matters:
  assumes "m (guard r1)" "m (guard r2)" "fact_value r1 ≠ fact_value r2"
  shows "map_option (fact_value ∘ snd) (interpret_table m (r1 # r2 # rs)) = Some (fact_value r1)"
    and "map_option (fact_value ∘ snd) (interpret_table m (r2 # r1 # rs)) = Some (fact_value r2)"
    and "interpret_table m (r1 # r2 # rs) ≠ interpret_table m (r2 # r1 # rs)"

theorem guard_exact:
  "organ_reply narr m og = Answer k v s n i ⟷
     admitted narr m og ∧
     i < length (store_rules (organ_store og)) ∧
     m (guard (store_rules (organ_store og) ! i)) ∧
     (∀j<i. ¬ m (guard (store_rules (organ_store og) ! j))) ∧
     k = store_kind (organ_store og) ∧ n = store_name (organ_store og) ∧
     v = fact_value (store_rules (organ_store og) ! i) ∧
     s = sentence (store_rules (organ_store og) ! i)"

theorem answer_from_table:
  "organ_reply narr m og = Answer k v s n i ⟹ Rule (guard (store_rules (organ_store og) ! i)) v s ∈ set (store_rules (organ_store og))"

theorem organ_silent:
  "organ_reply narr m og = Silent why ⟷
     (if boundary_silent m og then why = Boundary
      else if narr then why = Narrative
      else if ¬ m (store_gate (organ_store og)) then why = Off_gate
      else if blocked m (organ_store og) then why = Blocked
      else if ¬ m (store_ask (organ_store og)) then why = Not_asked
      else why = No_rule ∧ (∀r ∈ set (store_rules (organ_store og)). ¬ m (guard r)))"

theorem no_rule_silent:
  "admitted narr m og ⟹
     organ_reply narr m og = Silent No_rule ⟷ (∀r ∈ set (store_rules (organ_store og)). ¬ m (guard r))"

theorem boundary_narrows:
  "organ_reply narr m (Organ d (Some b) st) = Answer k v s n i ⟹
   organ_reply narr m (Organ d' None st) = Answer k v s n i"

theorem boundary_only_silences:
  "¬ boundary_silent m (Organ d (Some b) st) ⟹
   organ_reply narr m (Organ d (Some b) st) = organ_reply narr m (Organ d' None st)"

theorem family_first:
  "family_reply narr m ogs = Some (d, a) ⟹
     ∃i<length ogs. organ_id (ogs ! i) = d ∧ organ_reply narr m (ogs ! i) = a ∧
       (∃k v s n r. a = Answer k v s n r) ∧
       (∀j<i. ∃why. organ_reply narr m (ogs ! j) = Silent why)"

theorem family_none:
  "family_reply narr m ogs = None ⟷ (∀og ∈ set ogs. ∃why. organ_reply narr m og = Silent why)"

theorem literature_order_matters:
  "let rs = facts_literature_v2_rules; m = (λp. p = guard (rs ! 4) ∨ p = guard (rs ! 24)) in
     map_option (fact_value ∘ snd) (interpret_table m rs) = Some STR ''Pequod'' ∧
     map_option (fact_value ∘ snd) (interpret_table m (rs[4 := rs ! 24, 24 := rs ! 4])) = Some STR ''Moby-Dick''"
```

Plus `<store>_well_formed: table_well_formed <store>_rules` for all 21 tables (`tables_well_formed`).
`table_well_formed rs` means `rs ≠ [] ∧ distinct (map guard rs) ∧ (∀r ∈ set rs. guard r ≠ 0 ∧ sentence r ≠ 0 ∧ fact_value r ≠ 0)`.
No guard repeats in any shipped table, so there is no explicit list of shadowed rows. Semantic
shadowing, where one regex subsumes a later one, is not checked: it is regex containment, outside
this kernel. The self test (`Facts_Export.self_test`, code-evaluated) checks three things on
hand-built feature maps: the Pequod answer, a pets BLOCK, and the medicine-r2 boundary.

Build: base session `Veri7vn_Facts_Base` (kernel, 2 s) plus `Veri7vn_Facts` (tables, export, 2.5
min). Most of the time goes to `literature_order_matters` and the well-formedness simps over the
literal tables. One build was enough, so the session was not split per table.

## Trusted and untrusted

- **Untrusted**: `regex.sml`, `recognizer.sml` (Python `re` with re.I, `(?-i:...)`, lookaround,
  `\b \w \s \d` and negations; the port of `narrow_v1.narrative`), and `main.sml` (JSON, the
  `\uXXXX` decoding). Evidence for the regex port is a differential test against Python `re`.
  It runs 1,243 strings (every pattern, plus the values and sentences that compile as regexes)
  over 1,284 texts: every panel question of the 22 specialists, as written, upper-cased and
  lower-cased, plus the narrowing verdict. The result is 0 mismatches
  (`var/facts/tools/difftest.py`). The organ comparison above covers the composition.
- **Transcription**: `tables_check.py` reads the ML literals the HOL constants are defined from. It
  checks them against each specialist's own store file: 22 checks, plus DEFAULT_ASK, the family
  order and the medicine-r2 boundary. Result: `tables_check: 0 failures`. A mutation test (two
  sentences edited) is caught. The tables were written by `var/facts/tools/gen_tables.py`, a scratch
  helper that is not committed and not trusted. Root may want it moved into the lane folder.
- **Regex broadcast (d85f26c)**: this lane's `regex.sml` is a superset of the fixed shared file. It
  folds case inside the engine, as Python re.I does, rather than lower-casing patterns, and it adds
  the scoped `(?-i:...)` group. firesafety-v2's `(?-i:\bPASS\b)` and firstaid's `(?-i:\bRICE\b)` need
  that group: lower-casing the text would make them unmatchable. Text is passed as written. The
  recognizer calls `Regex.compile p` with the pattern as written. Root's
  `src/extract/quantity/regex_test.sml` passes against this copy (`REGEX_TEST PASS`). `compileCS` is
  the case-sensitive variant.
- The boundary patterns are matched on whitespace-normalised text. The organ uses the raw text, but
  these patterns are single words under `\b`, so the result cannot differ.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Facts --session-root src/extract/facts \
  --expect 'VERI7VN_FACTS PASS' --timeout 600
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/facts/tables_check.py
sh src/extract/facts/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/facts/score.py          # panels + core vs organ
B=var/facts/bin/facts
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "$B --specialist {id}" \
  --lane-answerer "$B --specialist {id}" --split both --out var/facts/parity \
  --specialist literature-v2,worldhistory,arthistory,medicine-r2,medicine,law,psychology,sociology,linguistics,poetry,botany,entomology,marinebio,ornithology,mycology,mycelial,pets,childdev,etiquette,firesafety-v2,firstaid,javascript
```

Receipt: `var/native-scaffold/sessions/30b3d2fb5075e865/receipt.json` (status passed).
Harness verdicts: `var/facts/parity/`. Lane score: `var/facts/score.json`, `var/facts/score.txt`.

## Remaining

- DOMAIN and FALSE YES against the head are not measured, because no head answerer was run.
- The feature map is trusted input. The kernel proves nothing about whether a regex matches. Lifting
  the regex semantics into HOL (a verified matcher for this Python subset) would close that gap and
  is the natural next step for every lane that ports organ regexes.
- `gen_tables.py` is scratch. Commit it if root wants regeneration to be reproducible.
