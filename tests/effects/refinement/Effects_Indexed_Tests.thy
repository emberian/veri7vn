theory Effects_Indexed_Tests
  imports Veri7vn_Effects_Indexed.Effects_Indexed
begin

definition fixture_value :: "nat \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "fixture_value key dependencies = \<lparr>retained_id=key, retained_owner=WorkspaceShared,
    retained_dependencies=dependencies, retained_read_dependencies=[],
    retained_access_requirements=[], retained_payload=key\<rparr>"

lemma indexed_empty_duplicates:
  "indexed_forget_closure [] [2,2,1] = Some [2,2,1]" by eval
lemma indexed_seed_order:
  "indexed_forget_closure [fixture_value 1 [0],fixture_value 0 []] [0] = Some [0,1]" by eval
lemma indexed_seed_only_order:
  "indexed_forget_closure [fixture_value 1 [],fixture_value 0 []] [0,1] = Some [0,1]" by eval
ML \<open>
local
  val nat = Veri7vn_Numerals.nat_of_integer;
  val integer = Veri7vn_Numerals.integer_of_nat;
  val fixture = @{code fixture_value};
  val records = [fixture (nat 1) [nat 0],fixture (nat 0) [],fixture (nat 2) [nat 1]];
  val seeds = [nat 0,nat 2,nat 0];
  fun display NONE = "None"
    | display (SOME ids) = "Some[" ^ commas (map (IntInf.toString o integer) ids) ^ "]";
  val _ = warning ("INDEXED_ORDER_DIAGNOSTIC indexed=" ^ display (@{code indexed_forget_closure} records seeds) ^
    " reference=" ^ display (@{code forget_closure} records seeds));
in end;
\<close>

lemma indexed_seed_and_fired_order:
  "indexed_forget_closure [fixture_value 1 [0],fixture_value 0 [],fixture_value 2 [1]] [0,2,0] =
    forget_closure [fixture_value 1 [0],fixture_value 0 [],fixture_value 2 [1]] [0,2,0]" by eval
lemma indexed_cycle_duplicates:
  "indexed_forget_closure [fixture_value 2 [1,1],fixture_value 1 [2],
      fixture_value 2 [0],fixture_value 3 [2]] [0,0] =
    forget_closure [fixture_value 2 [1,1],fixture_value 1 [2],
      fixture_value 2 [0],fixture_value 3 [2]] [0,0]" by eval
lemma indexed_missing_seed:
  "indexed_forget_closure [fixture_value 0 [4],fixture_value 1 [0]] [4,5,4] = Some [5,4,0,1]" by eval
lemma indexed_disconnected_seed:
  "indexed_forget_closure [fixture_value 0 [],fixture_value 1 []] [4,4] = Some [4]" by eval
lemma ancestor_duplicate_records:
  "map_option (\<lambda>summary. map (\<lambda>key. protected_ancestors_hit summary [key]) [0,1,2,3,4,5])
    (protected_ancestor_summary [fixture_value 2 [0],fixture_value 2 [1],
      fixture_value 3 [2],fixture_value 1 [4],fixture_value 4 [1]] [3]) =
    Some [True,True,True,True,True,False]" by eval
lemma ancestor_absent_and_empty:
  "map_option (\<lambda>summary. protected_ancestors_hit summary [4])
    (protected_ancestor_summary [] [4,4]) = Some True" by eval
lemma indexed_history_order:
  "indexed_new_ids [3,2,3] [1,2,1,4,3,4,5] = [1,4,5]" by eval
end
