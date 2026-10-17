theory Facts_Common
  imports "Veri7vn_Humanities_Base.Hum_Num"
begin

text \<open>Shared pieces of the lookup families (grammar, mythology, US history, library,
government): ordinals as the organs print them, joining alternatives, and the lookup of
the first candidate word that a table knows.\<close>

definition ord_suffix :: "nat \<Rightarrow> String.literal" where
  "ord_suffix n = (if 10 \<le> n mod 100 \<and> n mod 100 \<le> 20 then STR ''th''
     else if n mod 10 = 1 then STR ''st'' else if n mod 10 = 2 then STR ''nd''
     else if n mod 10 = 3 then STR ''rd'' else STR ''th'')"

definition ordinal :: "nat \<Rightarrow> String.literal" where
  "ordinal n = show_int (int n) + ord_suffix n"

theorem ord_suffix_teens: "10 \<le> n mod 100 \<Longrightarrow> n mod 100 \<le> 20 \<Longrightarrow> ord_suffix n = STR ''th''"
  by (simp add: ord_suffix_def)

theorem ord_suffix_units:
  assumes h: "\<not> (10 \<le> n mod 100 \<and> n mod 100 \<le> 20)"
  shows "(n mod 10 = 1 \<longrightarrow> ord_suffix n = STR ''st'') \<and> (n mod 10 = 2 \<longrightarrow> ord_suffix n = STR ''nd'')
     \<and> (n mod 10 = 3 \<longrightarrow> ord_suffix n = STR ''rd'')
     \<and> (n mod 10 \<noteq> 1 \<and> n mod 10 \<noteq> 2 \<and> n mod 10 \<noteq> 3 \<longrightarrow> ord_suffix n = STR ''th'')"
  by (simp add: ord_suffix_def h)

definition join_with :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_with sep xs = (case xs of [] \<Rightarrow> STR '''' | x # xs' \<Rightarrow> foldl (\<lambda>s y. s + sep + y) x xs')"

definition join_or :: "String.literal list \<Rightarrow> String.literal" where
  "join_or xs = join_with (STR '' or '') xs"

definition quoted :: "String.literal \<Rightarrow> String.literal" where
  "quoted w = apos + w + apos"

text \<open>The first candidate word the table knows, with its row: the organs try the quoted
words and the word after "of/for/verb/..." in this order and answer for the first one that
is in the table.\<close>
definition first_known :: "(String.literal \<times> 'a) list \<Rightarrow> String.literal list \<Rightarrow> (String.literal \<times> 'a) option" where
  "first_known tbl cands = (case List.find (\<lambda>w. map_of tbl w \<noteq> None) cands of
      Some w \<Rightarrow> Some (w, the (map_of tbl w)) | None \<Rightarrow> None)"

theorem first_known_some:
  assumes "first_known tbl cands = Some (w, v)"
  shows "map_of tbl w = Some v \<and>
         (\<exists>i<length cands. cands ! i = w \<and> (\<forall>j<i. map_of tbl (cands ! j) = None))"
proof -
  obtain w' where f: "List.find (\<lambda>w. map_of tbl w \<noteq> None) cands = Some w'"
  proof (cases "List.find (\<lambda>w. map_of tbl w \<noteq> None) cands")
    case None
    then show ?thesis using assms unfolding first_known_def by (simp only: option.case) simp
  next
    case (Some x)
    then show ?thesis using that by blast
  qed
  have h: "Some (w', the (map_of tbl w')) = Some (w, v)" using assms unfolding first_known_def by (simp only: f option.case)
  have e: "w' = w \<and> the (map_of tbl w') = v" using h by (metis option.inject prod.inject)
  from f[unfolded find_Some_iff] obtain i where i: "i < length cands" "map_of tbl (cands ! i) \<noteq> None" "w' = cands ! i"
    "\<forall>j<i. \<not> (map_of tbl (cands ! j) \<noteq> None)"
    by blast
  have nz: "map_of tbl w' \<noteq> None" using i(2,3) by simp
  obtain y where y: "map_of tbl w' = Some y" using nz by auto
  have m: "map_of tbl w = Some v" using y e by auto
  have "cands ! i = w" using i(3) e by simp
  moreover have "\<forall>j<i. map_of tbl (cands ! j) = None" using i(4) by simp
  ultimately show ?thesis using m i(1) by blast
qed

theorem first_known_none:
  assumes "first_known tbl cands = None"
  shows "\<forall>c\<in>set cands. map_of tbl c = None"
proof -
  have "List.find (\<lambda>w. map_of tbl w \<noteq> None) cands = None"
    using assms by (auto simp: first_known_def split: option.splits)
  then show ?thesis by (simp add: find_None_iff)
qed

end
