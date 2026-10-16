theory Graph_MST_Checker
 imports Graph_MST
begin

definition crosses_cut where
 "crosses_cut cut e \<longleftrightarrow> (tail e \<in> set cut) \<noteq> (head e \<in> set cut)"

definition proper_vertex_cut where
 "proper_vertex_cut g cut \<longleftrightarrow>
   (\<exists>u\<in>set (vertices g). u\<in>set cut) \<and>
   (\<exists>v\<in>set (vertices g). v\<notin>set cut)"

definition cut_price where
 "cut_price priced e = (if crosses_cut (fst priced) e then snd priced else (0::int))"

definition dual_edge_price where
 "dual_edge_price prices e = sum_list (map (\<lambda>p. cut_price p e) prices)"

definition cut_dual_bound where
 "cut_dual_bound g baseline prices =
    baseline * int (length (vertices g)-1) + sum_list (map snd prices)"

definition cut_dual_check where
 "cut_dual_check g tree baseline prices \<longleftrightarrow>
   \<not> directed g \<and> feasible_tree_check g tree \<and>
   (\<forall>p\<in>set prices. 0\<le>snd p \<and> proper_vertex_cut g (fst p)) \<and>
   (\<forall>e\<in>set (edges g). baseline + dual_edge_price prices e \<le> weight e) \<and>
   path_cost tree = cut_dual_bound g baseline prices"

definition partition_crosses where
 "partition_crosses labels e \<longleftrightarrow> component labels (tail e)\<noteq>component labels (head e)"

definition partition_blocks where
 "partition_blocks g labels = length (remdups (map (component labels) (vertices g)))"

definition partition_price where
 "partition_price p e = (if partition_crosses (fst p) e then snd p else (0::int))"

definition partition_edge_price where
 "partition_edge_price prices e = sum_list (map (\<lambda>p. partition_price p e) prices)"

definition partition_dual_bound where
 "partition_dual_bound g baseline prices = baseline * int (length (vertices g)-1) +
  sum_list (map (\<lambda>p. snd p * int (partition_blocks g (fst p)-1)) prices)"

definition partition_dual_check where
 "partition_dual_check g tree baseline prices \<longleftrightarrow>
   \<not> directed g \<and> feasible_tree_check g tree \<and>
   (\<forall>p\<in>set prices. 0\<le>snd p) \<and>
   (\<forall>e\<in>set (edges g). baseline + partition_edge_price prices e \<le> weight e) \<and>
   path_cost tree = partition_dual_bound g baseline prices"
end
