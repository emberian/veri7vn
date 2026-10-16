theory Ordered_Index_Tests
  imports Veri7vn_Ordered_Index.Ordered_Index
begin

text \<open>Mixed roles interleave in original order; a repeated role key does not
repeat its record. Repeated source records do remain repeated.\<close>
definition fixture_keys :: "nat \<Rightarrow> nat list" where
  "fixture_keys row = (if row=0 then [7,7] else if row=1 then [9,7] else [7,9])"

lemma mixed_roles:
  "bucket_lookup (multi_bucket_index fixture_keys [0,1,2,1]) 7 = [0,1,2,1]"
  by (simp add: multi_bucket_index_exact fixture_keys_def)

lemma absent_role:
  "bucket_lookup (multi_bucket_index fixture_keys [0,1,2,1]) 11 = []"
  by (simp add: multi_bucket_index_exact fixture_keys_def)

lemma isolated_vertex:
  "RBT.lookup (membership_index [3::nat,8,3]) 8 = Some ()"
  by (simp add: membership_index_def membership_fold_exact)

end
