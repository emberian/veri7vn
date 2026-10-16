theory Ordered_Index
  imports Veri7vn_Effects_RBT.RBT
begin

text \<open>Exact ordered buckets: duplicates and source order are observable.
The specification is list filtering, independently of the tree representation.\<close>

definition bucket_lookup :: "('k::linorder, 'a list) RBT.rbt \<Rightarrow> 'k \<Rightarrow> 'a list" where
  "bucket_lookup index key = (case RBT.lookup index key of None \<Rightarrow> [] | Some xs \<Rightarrow> xs)"

fun bucket_index :: "('a \<Rightarrow> 'k::linorder) \<Rightarrow> 'a list \<Rightarrow> ('k, 'a list) RBT.rbt" where
  "bucket_index key [] = RBT.empty"
| "bucket_index key (x#xs) = (let index = bucket_index key xs in
    RBT.insert (key x) (x # bucket_lookup index (key x)) index)"

lemma bucket_index_exact:
  "bucket_lookup (bucket_index key xs) k = filter (\<lambda>x. key x = k) xs"
  by (induction xs) (auto simp: bucket_lookup_def Let_def split: option.splits)

lemma bucket_index_member:
  "x \<in> set (bucket_lookup (bucket_index key xs) k) \<longleftrightarrow>
    x \<in> set xs \<and> key x = k"
  by (simp add: bucket_index_exact)

definition bucket_prepend where
  "bucket_prepend x k index = RBT.insert k (x # bucket_lookup index k) index"

lemma bucket_prepend_lookup:
  "bucket_lookup (bucket_prepend x k index) q =
    (if q=k then x # bucket_lookup index q else bucket_lookup index q)"
  by (auto simp: bucket_prepend_def bucket_lookup_def)

lemma bucket_prepend_keys:
  assumes "distinct ks"
  shows "bucket_lookup (fold (bucket_prepend x) ks index) q =
    (if q \<in> set ks then x # bucket_lookup index q else bucket_lookup index q)"
  using assms by (induction ks arbitrary: index) (auto simp: bucket_prepend_lookup)

fun multi_bucket_index :: "('a \<Rightarrow> 'k::linorder list) \<Rightarrow> 'a list \<Rightarrow> ('k, 'a list) RBT.rbt" where
  "multi_bucket_index keys [] = RBT.empty"
| "multi_bucket_index keys (x#xs) =
    fold (bucket_prepend x) (remdups (keys x)) (multi_bucket_index keys xs)"

lemma multi_bucket_index_exact:
  "bucket_lookup (multi_bucket_index keys xs) k = filter (\<lambda>x. k \<in> set (keys x)) xs"
  by (induction xs) (simp_all add: bucket_prepend_keys bucket_lookup_def)

definition membership_index :: "'k::linorder list \<Rightarrow> ('k, unit) RBT.rbt" where
  "membership_index xs = fold (\<lambda>x index. RBT.insert x () index) xs RBT.empty"

lemma membership_fold_exact:
  "RBT.lookup (fold (\<lambda>x index. RBT.insert x () index) xs index) k =
    (if k \<in> set xs then Some () else RBT.lookup index k)"
  by (induction xs arbitrary: index) auto

lemma membership_index_exact:
  "RBT.lookup (membership_index xs) k \<noteq> None \<longleftrightarrow> k \<in> set xs"
  by (simp add: membership_index_def membership_fold_exact)

export_code bucket_index multi_bucket_index bucket_lookup membership_index
  in SML module_name OrderedIndex

end
