theory GeoStats_Weighted
  imports GeoStats_Stats
begin

text \<open>A weighted mean uses finite lists of observations and weights of
identical length. Zero weights are allowed, negative weights are not, and the
sum of weights must be positive. Weights need not sum to one.\<close>

definition weighted_valid :: "rat list \<Rightarrow> rat list \<Rightarrow> bool" where
  "weighted_valid xs ws \<longleftrightarrow> length xs = length ws \<and>
     (\<forall>w\<in>set ws. 0 \<le> w) \<and> 0 < sum_list ws"

definition weighted_total :: "rat list \<Rightarrow> rat list \<Rightarrow> rat" where
  "weighted_total xs ws = sum_list (map (\<lambda>(x,w). x*w) (zip xs ws))"

definition weighted_mean :: "rat list \<Rightarrow> rat list \<Rightarrow> rat option" where
  "weighted_mean xs ws = (if weighted_valid xs ws
     then Some (weighted_total xs ws / sum_list ws) else None)"

theorem weighted_balance:
  assumes "weighted_mean xs ws = Some q"
  shows "weighted_valid xs ws \<and> q * sum_list ws = weighted_total xs ws"
  using assms by (auto simp: weighted_mean_def weighted_valid_def field_simps split: if_splits)

theorem weighted_rejects_invalid:
  "weighted_mean xs ws = None \<longleftrightarrow> \<not> weighted_valid xs ws"
  by (simp add: weighted_mean_def)

lemma weighted_ones:
  "weighted_total xs (replicate (length xs) 1) = sum_list xs"
  by (induction xs) (simp_all add: weighted_total_def)

theorem weighted_equal_weights:
  assumes "xs \<noteq> []"
  shows "weighted_mean xs (replicate (length xs) 1) = Some (smean xs)"
  using assms by (simp add: weighted_mean_def weighted_valid_def weighted_ones smean_def sum_list_replicate)

lemma weighted_total_interval:
  assumes "length xs = length ws"
      and "\<forall>x\<in>set xs. lo \<le> x \<and> x \<le> hi"
      and "\<forall>w\<in>set ws. 0 \<le> w"
  shows "lo * sum_list ws \<le> weighted_total xs ws \<and>
         weighted_total xs ws \<le> hi * sum_list ws"
  using assms
proof (induction xs arbitrary: ws)
  case Nil
  then show ?case by (simp add: weighted_total_def)
next
  case (Cons x xs)
  then obtain w rest where ws: "ws = w # rest" by (cases ws) auto
  have bounds: "lo \<le> x" "x \<le> hi" "0 \<le> w"
    using Cons.prems ws by auto
  have tail: "lo * sum_list rest \<le> weighted_total xs rest \<and>
              weighted_total xs rest \<le> hi * sum_list rest"
    using Cons.IH Cons.prems ws by auto
  have left: "lo * w \<le> x * w" using bounds(1,3) by (rule mult_right_mono)
  have right: "x * w \<le> hi * w" using bounds(2,3) by (rule mult_right_mono)
  have total: "weighted_total (x # xs) (w # rest) = x * w + weighted_total xs rest"
    by (simp add: weighted_total_def)
  have lower: "lo * w + lo * sum_list rest \<le> x * w + weighted_total xs rest"
    using left tail by (intro add_mono) auto
  have upper: "x * w + weighted_total xs rest \<le> hi * w + hi * sum_list rest"
    using right tail by (intro add_mono) auto
  show ?case using lower upper
    by (simp only: ws total sum_list.Cons distrib_left; intro conjI; assumption)
qed

theorem weighted_between:
  assumes "weighted_mean xs ws = Some q"
      and "\<forall>x\<in>set xs. lo \<le> x \<and> x \<le> hi"
  shows "lo \<le> q \<and> q \<le> hi"
proof -
  have valid: "weighted_valid xs ws" and balance: "q * sum_list ws = weighted_total xs ws"
    using weighted_balance[OF assms(1)] by auto
  have positive: "0 < sum_list ws" using valid by (simp add: weighted_valid_def)
  have bounds: "lo * sum_list ws \<le> q * sum_list ws \<and>
                q * sum_list ws \<le> hi * sum_list ws"
    using weighted_total_interval[of xs ws lo hi] valid assms(2) balance
    by (auto simp: weighted_valid_def)
  show ?thesis using bounds by (simp add: mult_le_cancel_right_pos[OF positive])
qed

definition weighted_reply :: "rat list \<Rightarrow> rat list \<Rightarrow> reply" where
  "weighted_reply xs ws = (case weighted_mean xs ws of
      None \<Rightarrow> Reply False (STR ''impossible'')
        (STR ''A weighted mean needs equally many values and nonnegative weights with a positive total.'') None
    | Some q \<Rightarrow> Reply True (STR ''weighted_mean'')
          (STR ''The weighted mean is '' + f4 q + STR '' (sum of value times weight / sum of weights).'') (Some (f4 q)))"

end
