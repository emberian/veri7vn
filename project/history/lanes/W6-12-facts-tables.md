# W6-12 facts-tables: the organ tables as a checked equality

Changed files: `src/extract/facts/Facts_Rows.thy` (new, generated), `gen/gen_tables.py` (now also writes
Facts_Rows.thy), `ROOT` (Facts_Rows between Facts_Tables and Facts_Export), `Facts_Export.thy` (imports
Facts_Rows; the 22 new theorems named in the oracle scan; marker still last). `Facts_Tables.thy` is byte-identical
to before (regen leaves it unchanged). `tables_check.py` is kept as the independent Python comparison.

What it does: the generator reads each shipped store file a second time and writes every table as a second
constant `organ_rows_<store>`, serialised as hex digits of the 7-bit text of each guard, value and sentence (a
different encoding from the SML string literals that define `<store>_rules`). Each table equality is proved by
transitivity of the two definitions, so it holds only if the two lists are the same term, row by row. No `simp`
search, no `by eval`, no oracle.

New statements (verbatim; one per store, 21 of them, shown for two):

    theorem rows_facts_literature_v2: "facts_literature_v2_rules = organ_rows_facts_literature_v2"
    theorem rows_facts_javascript_v1: "facts_javascript_v1_rules = organ_rows_facts_javascript_v1"

and the family theorem (medicine and medicine-r2 share facts_medicine_v1):

    theorem organ_rows_bound:
      "map (store_rules o organ_store) organs =
        [organ_rows_facts_literature_v2, organ_rows_facts_worldhistory_v1, organ_rows_facts_arthistory_v1,
         organ_rows_facts_medicine_v1, organ_rows_facts_medicine_v1, organ_rows_facts_law_v1,
         organ_rows_facts_psychology_v1, organ_rows_facts_sociology_v1, organ_rows_facts_linguistics_v1,
         organ_rows_facts_poetry_v1, organ_rows_facts_botany_v1, organ_rows_facts_entomology_v1,
         organ_rows_facts_marinebio_v1, organ_rows_facts_ornithology_v1, organ_rows_facts_mycology_v1,
         organ_rows_facts_mycelial_v1, organ_rows_facts_pets_v1, organ_rows_facts_childdev_v1,
         organ_rows_facts_etiquette_v1, organ_rows_facts_firesafety_v2, organ_rows_facts_firstaid_v1,
         organ_rows_facts_javascript_v1]"

Limits: both sides come from the same untrusted generator reading the same store files, so the theorems say the
HOL table equals the generator's reading of the store, not that the generator reads Python correctly;
`tables_check.py` (separate parser, 0 failures) covers that.

Not delivered, with counterexamples: audit item 2 ("the sentence carries the stated value", `s = pre + v + suf`)
is false of the shipped data, so no theorem was written and the kernel was not touched. 12 of 417 rows have a
value that is not a substring of the sentence: facts_poetry_v1 value `5` / "Pentameter has five feet per line.";
facts_marinebio_v1 `0-200 m`, `200-1,000 m`, `1,000-4,000 m`, `4,000-6,000 m`, `below 6,000 m` (sentences phrase the
range differently); facts_ornithology_v1 `hummingbird`, `no`, `birds` (capitalised in the sentence);
facts_mycelial_v1 `ectomycorrhizae`, `arbuscular mycorrhizae` (capitalised); facts_firesafety_v2 `never`
("Never use water ..."). Root decides: case-insensitive infix plus fixing the 5 value strings, or drop item 2.
The count is therefore 21 table equalities plus `organ_rows_bound` (22 theorems), with the sentence theorem open.

Checks and results:
- Build: `tools/dev/remote-build persvati src/extract/facts Veri7vn_Facts -d src/extract/commons --expect 'VERI7VN_FACTS PASS'`:
  `VERI7VN_FACTS PASS theorems=58 oracles=0`, session 3:01 elapsed (Facts_Rows itself about 19 s; the rest is the
  existing well-formedness lemmas in Facts_Tables). One session, no child session needed.
- Generated SML byte-identical to the previous export. Binary rebuilt with the current commons.sml (UTF-8 Regex)
  to `var/facts/bin/facts.w612`.
- `tables_check.py`: 0 failures. `score.py`: 428 items, organ disagreements 0 on every panel. `harness.py` (documented
  command): per-specialist counts identical to `var/facts/harness.txt`, and all 428 item records identical to the
  earlier run apart from timing fields: 0 changed replies.
- Audit recount (`var/audit/markers.py`): Veri7vn_Facts thm=23 unscanned_thm=0, marker last, oracle scan true.
  Before: thm=12 theorems, 11 scanned. The 21 well-formedness lemmas stay lemma-class (unscanned_lem counts them; not changed here).
