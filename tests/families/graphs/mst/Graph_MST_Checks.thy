theory Graph_MST_Checks
 imports Veri7vn_Graphs.Graph_Dispatch_Soundness
begin

definition a where "a = \<lparr>row_key=1,relation_key=0,tail=0,head=1,weight= -3\<rparr>"
definition b where "b = \<lparr>row_key=2,relation_key=0,tail=1,head=2,weight=2\<rparr>"
definition c where "c = \<lparr>row_key=3,relation_key=0,tail=0,head=2,weight=10\<rparr>"
definition parallel where "parallel = a\<lparr>row_key:=4\<rparr>"
definition g where "g = \<lparr>vertices=[0,1,2],edges=[a,b,c,parallel],directed=False\<rparr>"
lemmas fixture_defs = a_def b_def c_def parallel_def g_def
lemmas checker_defs = cut_dual_check_def cut_dual_bound_def dual_edge_price_def
 cut_price_def crosses_cut_def proper_vertex_cut_def feasible_tree_check_def
 canonical_tree_def path_cost_def

lemma signed_multiedge_certificate:
 "cut_dual_check g [a,b] (-3) [([2],5)]"
 by (simp add: fixture_defs checker_defs)
lemma tied_parallel_certificate:
 "cut_dual_check g [b,parallel] (-3) [([2],5)]"
 by (simp add: fixture_defs checker_defs)
lemma actual_minimum_tree:
 "minimum_tree g [a,b]"
 using cut_dual_check_sound signed_multiedge_certificate by blast
lemma excessive_price_rejected:
 "\<not> cut_dual_check g [a,b] (-3) [([2],6)]"
 by (simp add: fixture_defs checker_defs)
lemma negative_multiplier_rejected:
 "\<not> cut_dual_check g [a,b] (-3) [([2],-1)]"
 by (simp add: fixture_defs checker_defs)
lemma improper_cut_rejected:
 "\<not> cut_dual_check g [a,b] (-3) [([],5)]"
 by (simp add: fixture_defs checker_defs)
lemma isolated_vertex_rejected:
 "\<not> cut_dual_check (g\<lparr>vertices:=[0,1,2,3]\<rparr>) [a,b] (-3) [([2],5)]"
 by (simp add: fixture_defs checker_defs)
lemma directed_profile_rejected:
 "\<not> cut_dual_check (g\<lparr>directed:=True\<rparr>) [a,b] (-3) [([2],5)]"
 by (simp add: fixture_defs checker_defs)

definition run_signed_certificate where
 "run_signed_certificate = cut_dual_check g [a,b] (-3) [([2],5)]"
ML \<open>
 val _ = if @{code run_signed_certificate} then ()
   else error "generated signed multiedge MST cut certificate rejected";
\<close>

definition p01 where "p01 = \<lparr>row_key=10,relation_key=0,tail=0,head=1,weight=0\<rparr>"
definition p12 where "p12 = \<lparr>row_key=11,relation_key=0,tail=1,head=2,weight=1\<rparr>"
definition p23 where "p23 = \<lparr>row_key=12,relation_key=0,tail=2,head=3,weight=1\<rparr>"
definition p03 where "p03 = \<lparr>row_key=13,relation_key=0,tail=0,head=3,weight=1\<rparr>"
definition pg where "pg = \<lparr>vertices=[0,1,2,3],edges=[p01,p12,p23,p03],directed=False\<rparr>"
definition pp where "pp = [([(0,0),(1,0),(2,2),(3,3)],1::int)]"
lemmas partition_fixture_defs = p01_def p12_def p23_def p03_def pg_def pp_def
lemmas partition_checker_defs = partition_dual_check_def partition_dual_bound_def
 partition_edge_price_def partition_price_def partition_crosses_def partition_blocks_def
 feasible_tree_check_def canonical_tree_def path_cost_def
lemma signed_partition_certificate:
 "partition_dual_check g [a,b] (-3) [([(0,0),(1,0),(2,2)],5)]"
 by (simp add: fixture_defs partition_checker_defs)
lemma tied_parallel_partition_certificate:
 "partition_dual_check g [b,parallel] (-3) [([(0,0),(1,0),(2,2)],5)]"
 by (simp add: fixture_defs partition_checker_defs)
lemma partition_negative_multiplier_rejected:
 "\<not> partition_dual_check g [a,b] (-3) [([(0,0),(1,0),(2,2)],-1)]"
 by (simp add: fixture_defs partition_checker_defs)
lemma partition_isolated_vertex_rejected:
 "\<not> partition_dual_check (g\<lparr>vertices:=[0,1,2,3]\<rparr>) [a,b] (-3)
   [([(0,0),(1,0),(2,2)],5)]"
 by (simp add: fixture_defs partition_checker_defs)

lemma three_block_certificate:
 "partition_dual_check pg [p01,p12,p23] 0 pp"
 by (simp add: partition_fixture_defs partition_checker_defs)
lemma partition_certifies_existing_minimum_semantics:
 "minimum_tree pg [p01,p12,p23]"
 using partition_dual_check_sound three_block_certificate by blast
lemma partition_nonoptimal_tree_rejected:
 "\<not> partition_dual_check pg [p12,p23,p03] 0 pp"
 by (simp add: partition_fixture_defs partition_checker_defs)
lemma partition_price_inflation_rejected:
 "\<not> partition_dual_check pg [p01,p12,p23] 0
    [([(0,0),(1,0),(2,2),(3,3)],2)]"
 by (simp add: partition_fixture_defs partition_checker_defs)
definition run_partition_certificate where
 "run_partition_certificate = partition_dual_check pg [p01,p12,p23] 0 pp"
ML \<open>
 val _ = if @{code run_partition_certificate} then ()
   else error "generated three-block MST partition certificate rejected";
\<close>

definition run_default_signed where
 "run_default_signed = graph_dispatch 8 8 4 g MinimumSpanningTree"
definition run_default_partition where
 "run_default_partition = graph_dispatch 8 8 4 pg MinimumSpanningTree"

definition signed_default_ok where
 "signed_default_ok = (case run_default_signed of MinimumTree tree cost \<Rightarrow>
    length tree=2 \<and> cost= -1 | _ \<Rightarrow> False)"
definition partition_default_ok where
 "partition_default_ok = (case run_default_partition of MinimumTree tree cost \<Rightarrow>
    length tree=3 \<and> cost=2 | _ \<Rightarrow> False)"
ML \<open>
 val _ = if @{code signed_default_ok} then ()
   else error "default signed MST did not produce certified exact optimum";
 val _ = if @{code partition_default_ok} then ()
   else error "default three-block MST did not produce certified exact optimum";
 val _ = writeln "VERI7VN_GRAPH_MST_PARTITION_CHECKS_PASS";
\<close>
end
