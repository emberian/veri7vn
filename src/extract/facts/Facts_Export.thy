theory Facts_Export
  imports Facts_Rows
begin

definition organ_by_id :: "String.literal \<Rightarrow> organ option" where
  "organ_by_id d = List.find (\<lambda>og. organ_id og = d) organs"

text \<open>Every pattern an organ may consult; the recognizer compiles these.\<close>
definition organ_patterns :: "organ \<Rightarrow> String.literal list" where
  "organ_patterns og =
     (case organ_boundary og of Some (a, b) \<Rightarrow> [a, b] | None \<Rightarrow> []) @
     [store_gate (organ_store og)] @
     (case store_block (organ_store og) of Some b \<Rightarrow> [b] | None \<Rightarrow> []) @
     [store_ask (organ_store og)] @ map guard (store_rules (organ_store og))"

definition is_answer :: "outcome \<Rightarrow> bool" where
  "is_answer a = (case a of Answer _ _ _ _ _ \<Rightarrow> True | Silent _ \<Rightarrow> False)"

text \<open>Code-evaluated at build time, not a theorem: the family has the 22 manifests
in order, ids are distinct, and three replies on hand-made feature maps (an answer,
a block, the medicine-r2 boundary).\<close>
definition self_test :: bool where
  "self_test \<longleftrightarrow>
     length organs = 22 \<and> distinct (map organ_id organs) \<and>
     map_option organ_id (organ_by_id (STR ''medicine-r2'')) = Some (STR ''medicine-r2'') \<and>
     (let og = organ_literature_v2; st = organ_store og; rs = store_rules st;
          m = (\<lambda>p. p = store_gate st \<or> p = store_ask st \<or> p = guard (rs ! 4) \<or> p = guard (rs ! 24)) in
        organ_reply False m og = Answer (STR ''literature'') (STR ''Pequod'')
          (STR ''Captain Ahab's ship is the Pequod.'') (STR ''facts_literature_v2'') 4 \<and>
        organ_reply True m og = Silent Narrative) \<and>
     (let og = organ_pets; st = organ_store og;
          m = (\<lambda>p. p = store_gate st \<or> p = store_ask st \<or> p = the (store_block st) \<or> p = guard (hd (store_rules st))) in
        organ_reply False m og = Silent Blocked) \<and>
     (let og = organ_medicine_r2; st = organ_store og; b = the (organ_boundary og);
          m = (\<lambda>p. p = fst b \<or> p = store_gate st \<or> p = store_ask st \<or> p = guard (hd (store_rules st))) in
        organ_reply False m og = Silent Boundary \<and>
        is_answer (organ_reply False m organ_medicine))"

export_code organ_reply family_reply organs organ_by_id organ_patterns organ_id organ_store
  store_name store_kind is_answer self_test integer_of_nat
  Answer Silent Boundary Narrative Off_gate Blocked Not_asked No_rule
  in SML module_name Facts file_prefix facts

ML \<open>
  val theorems = [@{thm first_match}, @{thm no_rule_no_answer}, @{thm interpret_table_local},
    @{thm guard_exact}, @{thm answer_from_table}, @{thm organ_silent}, @{thm no_rule_silent},
    @{thm boundary_narrows}, @{thm boundary_only_silences}, @{thm family_first}, @{thm family_none},
    @{thm literature_order_matters}]
    @ @{thms order_matters} @ @{thms tables_well_formed} @
    [@{thm rows_facts_literature_v2},
     @{thm rows_facts_worldhistory_v1},
     @{thm rows_facts_arthistory_v1},
     @{thm rows_facts_medicine_v1},
     @{thm rows_facts_law_v1},
     @{thm rows_facts_psychology_v1},
     @{thm rows_facts_sociology_v1},
     @{thm rows_facts_linguistics_v1},
     @{thm rows_facts_poetry_v1},
     @{thm rows_facts_botany_v1},
     @{thm rows_facts_entomology_v1},
     @{thm rows_facts_marinebio_v1},
     @{thm rows_facts_ornithology_v1},
     @{thm rows_facts_mycology_v1},
     @{thm rows_facts_mycelial_v1},
     @{thm rows_facts_pets_v1},
     @{thm rows_facts_childdev_v1},
     @{thm rows_facts_etiquette_v1},
     @{thm rows_facts_firesafety_v2},
     @{thm rows_facts_firstaid_v1},
     @{thm rows_facts_javascript_v1},
     @{thm organ_rows_bound}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("facts theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "facts self test failed";
  val _ = writeln ("VERI7VN_FACTS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
