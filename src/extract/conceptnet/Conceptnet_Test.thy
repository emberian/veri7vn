theory Conceptnet_Test
  imports Conceptnet_Export
begin

text \<open>Fixtures are rows read from the sealed build m13e5_conceptnet_build_a_v1
(dog UsedFor; kitten IsA cat; cat UsedFor). Each lemma states the whole reply
the kernel produces and is proved by the simplifier from the definitions
(kernel-checked, no evaluation oracle).\<close>

lemmas kernel_defs =
  decide_def decide_direct_def decide_derived_def first_derived.simps
  collect_edges_def sel_spec_def derived_pairs_def parent_edges_def fwd_specs_def
  edge_matches_def declared_witness_def add_line.simps add_dline.simps

lemmas fixture_defs =
  e_dog_comp_def e_dog_guard_def e_dog_pet_def e_dog_antonym_def dog_edges_def req_dog_def
  e_kitten_isa_cat_def e_kitten_isa_frag_def e_cat_catch_def e_cat_comp_def
  kitten_edges_def req_kitten_def

subsection \<open>Direct route: the adapter's exact answer\<close>

text \<open>The three heaviest dog/UsedFor edges, weight order with the 2.828 tie
broken by end label (guarding property before pet), the Antonym edge filtered
out, surface texts de-bracketed and capitalized.\<close>
lemma dog_direct:
  "decide [IsA, PartOf] req_dog dog_edges =
     C_answer [(cp ''A dog is for companionship.'',
                 (cp ''conceptnet57:UsedFor:dog->companionship'', 6325000, cp ''/d/conceptnet/4/en'')),
               (cp ''A dog is used for guarding property.'',
                 (cp ''conceptnet57:UsedFor:dog->guarding property'', 2828000, cp ''/d/conceptnet/4/en'')),
               (cp ''A dog is for a pet.'',
                 (cp ''conceptnet57:UsedFor:dog->pet'', 2828000, cp ''/d/conceptnet/4/en''))]"
  by (simp add: kernel_defs fixture_defs)

definition e_dog_comp2 :: cedge where
  "e_dog_comp2 = \<lparr>c_rel = UsedFor, c_start = cp ''dog'', c_end = cp ''companionship'',
    c_weight = 1000000, c_surface = cp ''[[a dog]] is for [[companionship]]'',
    c_dataset = cp ''/d/conceptnet/5.7''\<rparr>"

text \<open>A cheaper edge rendering the same line is dropped by deduplication, not
added as a second copy.\<close>
lemma dog_direct_dedup:
  "decide [IsA, PartOf] req_dog (dog_edges @ [e_dog_comp2]) =
     C_answer [(cp ''A dog is for companionship.'',
                 (cp ''conceptnet57:UsedFor:dog->companionship'', 6325000, cp ''/d/conceptnet/4/en'')),
               (cp ''A dog is used for guarding property.'',
                 (cp ''conceptnet57:UsedFor:dog->guarding property'', 2828000, cp ''/d/conceptnet/4/en'')),
               (cp ''A dog is for a pet.'',
                 (cp ''conceptnet57:UsedFor:dog->pet'', 2828000, cp ''/d/conceptnet/4/en''))]"
  by (simp add: kernel_defs fixture_defs e_dog_comp2_def)

definition e_dog_plain :: cedge where
  "e_dog_plain = \<lparr>c_rel = UsedFor, c_start = cp ''dog'', c_end = cp ''hunting'',
    c_weight = 900000, c_surface = [], c_dataset = cp ''/d/conceptnet/4/en''\<rparr>"

text \<open>An empty surface text falls to the relation template.\<close>
lemma dog_plain_template:
  "map fst (decide_direct \<lparr>c_concept = cp ''dog'', c_specs = [(UsedFor, Fwd)]\<rparr> [e_dog_plain])
     = [cp ''Dog is used for hunting.'']"
  by (simp add: kernel_defs e_dog_plain_def)

subsection \<open>Derived route: two hops, both declared\<close>

text \<open>No UsedFor edge of kitten exists, so the direct route abstains; the
decision derives through the heaviest IsA parent (cat, 4.472, ahead of fragile
animal, 2.0) and answers with cat's UsedFor edges (the 4.0 tie ordered catch
mice before companionship by end label). Every line names the parent, and the
two hops' provenance is carried.\<close>
lemma kitten_derived:
  "decide [IsA, PartOf] req_kitten kitten_edges =
     C_derived [\<lparr>d_via = cp ''cat'',
                 d_line = cp ''(via cat) You can use a cat to catch mice.'',
                 d_hop1 = (cp ''conceptnet57:IsA:kitten->cat'', 4472000, cp ''/d/conceptnet/4/en''),
                 d_hop2 = (cp ''conceptnet57:UsedFor:cat->catch mice'', 4000000, cp ''/d/conceptnet/4/en'')\<rparr>,
                \<lparr>d_via = cp ''cat'',
                 d_line = cp ''(via cat) A cat is for companionship.'',
                 d_hop1 = (cp ''conceptnet57:IsA:kitten->cat'', 4472000, cp ''/d/conceptnet/4/en''),
                 d_hop2 = (cp ''conceptnet57:UsedFor:cat->companionship'', 4000000, cp ''/d/conceptnet/4/en'')\<rparr>]"
  by (simp add: kernel_defs fixture_defs)

subsection \<open>Abstention\<close>

lemma dog_empty_abstains:
  "decide [IsA, PartOf] req_dog [] = C_abstain"
  by (rule decide_empty_is_abstain)

lemma unicorn_no_edges_abstains:
  "decide [IsA, PartOf] \<lparr>c_concept = cp ''unicorn'', c_specs = [(UsedFor, Fwd)]\<rparr> kitten_edges
     = C_abstain"
  by (simp add: kernel_defs fixture_defs)

lemma no_mediators_abstains:
  "decide [] req_kitten kitten_edges = C_abstain"
  by (simp add: kernel_defs fixture_defs)

subsection \<open>Marker\<close>

ML \<open>
  val theorems = [@{thm decide_direct_witnessed}, @{thm decide_direct_bounded},
    @{thm decide_derived_witnessed}, @{thm decide_derived_bounded},
    @{thm decide_empty_is_abstain}, @{thm decide_abstain_iff},
    @{thm answer_nonempty_bounded}, @{thm derived_nonempty_bounded},
    @{thm no_matching_edges_abstains}, @{thm render_edge_sentence},
    @{thm sel_spec_sorted}, @{thm sel_spec_len}, @{thm sel_spec_subset},
    @{thm isort_sorted}, @{thm parse_rel_name_roundtrip},
    @{thm dog_direct}, @{thm dog_direct_dedup}, @{thm dog_plain_template},
    @{thm kitten_derived}, @{thm unicorn_no_edges_abstains},
    @{thm no_mediators_abstains}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("conceptnet theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "conceptnet self test failed";
  val _ = writeln ("VERI7VN_CONCEPTNET PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
