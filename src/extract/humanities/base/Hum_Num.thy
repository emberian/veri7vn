theory Hum_Num
  imports "HOL-Decision_Procs.Approximation" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Lane S16-humanities: numerics and reply text shared by the humanities
family. The decimal rounding, the float-interval helpers and the digit layout come
from Veri7vn_Commons (src/extract/commons/Commons_Num.thy, lifted from lane G);
the fixed three-decimal rounding, which is what the music organ prints, is new
here.\<close>

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition cat :: "String.literal list \<Rightarrow> String.literal" where
  "cat xs = foldr (+) xs (STR '''')"

section \<open>Three decimals\<close>

text \<open>Exact rationals printed as the music organ prints them
(@{text "%.3f"} with trailing zeros removed): rounded to the nearest thousandth,
an exact tie rounding up.\<close>
definition fixed3 :: "rat \<Rightarrow> int" where
  "fixed3 q = \<lfloor>q * 1000 + 1 / 2\<rfloor>"

theorem fixed3_err: "\<bar>of_int (fixed3 q) / 1000 - q\<bar> \<le> (1::rat) / 2000"
proof -
  have c: "of_int \<lfloor>q * 1000 + 1 / 2\<rfloor> \<le> q * 1000 + 1 / 2 \<and>
           q * 1000 + 1 / 2 < of_int (\<lfloor>q * 1000 + 1 / 2\<rfloor> + 1)"
    by (rule floor_correct)
  then have lo: "of_int (fixed3 q) \<le> q * 1000 + 1 / 2" by (simp add: fixed3_def)
  have hi: "q * 1000 + 1 / 2 < of_int (fixed3 q) + 1" using c by (simp add: fixed3_def)
  show ?thesis by (rule abs_leI; use lo hi in linarith)
qed

definition g3 :: "rat \<Rightarrow> String.literal" where
  "g3 q = render_dec 17 (fixed3 q, -3)"

definition to_fixed3 :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed3 X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if hi - lo \<le> 1 / 1000000 \<and> \<bar>mid\<bar> < 100000 then Some (round_at mid (-3)) else None)"

theorem to_fixed3_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed3 X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> 1 / 1000 \<and> snd d = -3"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> 1 / 1000000" and dd: "d = round_at mid (-3)"
    using d by (simp_all add: to_fixed3_def Let_def lo_def hi_def mid_def split: if_splits)
  have r: "\<bar>dec_val d - mid\<bar> \<le> 1 / 2000"
    unfolding dd using round_at_error[of mid "-3"] by (simp add: pow10_def)
  have m: "\<bar>mid - x\<bar> \<le> (hi - lo) / 2"
    unfolding mid_def using xin by (rule midpoint_close)
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
  have c1: "(hi - lo) / 2 \<le> (1 / 1000000) / 2" by (rule divide_right_mono[OF chk]) simp
  have c2: "\<bar>mid - x\<bar> \<le> (1 / 1000000) / 2" by (rule order_trans[OF m c1])
  have c3: "\<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar> \<le> 1 / 2000 + (1 / 1000000) / 2" by (rule add_mono[OF r c2])
  have c4: "(1 / 2000 + (1 / 1000000) / 2 :: real) \<le> 1 / 1000" by simp
  have "\<bar>dec_val d - x\<bar> \<le> 1 / 1000" by (rule order_trans[OF tri order_trans[OF c3 c4]])
  moreover have "snd d = -3" by (simp add: dd round_at_def)
  ultimately show ?thesis by simp
qed

definition prec :: nat where "prec = 53"

definition enclose3 :: "nat \<Rightarrow> floatarith \<Rightarrow> (int \<times> int) option" where
  "enclose3 p e = (case approx p e [] of None \<Rightarrow> None | Some X \<Rightarrow> to_fixed3 X)"

theorem enclose3_sound:
  assumes "enclose3 p e = Some d"
  shows "\<bar>dec_val d - interpret_floatarith e []\<bar> \<le> 1 / 1000 \<and> snd d = -3"
proof -
  obtain X where X: "approx p e [] = Some X" and d: "to_fixed3 X = Some d"
    using assms by (auto simp: enclose3_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using to_fixed3_sound d by blast
qed

section \<open>First match on an ordered rule list\<close>

text \<open>The untrusted recognizer evaluates each rule's pattern against the text and
passes one bit per rule; the kernel takes the first rule whose bit is set.\<close>
definition pick :: "bool list \<Rightarrow> 'a list \<Rightarrow> 'a option" where
  "pick bs xs = map_option snd (List.find fst (zip bs xs))"

theorem pick_some:
  assumes "pick bs xs = Some x"
  shows "\<exists>i. i < length bs \<and> i < length xs \<and> bs ! i \<and> xs ! i = x \<and> (\<forall>j<i. \<not> bs ! j)"
proof -
  obtain p where p: "List.find fst (zip bs xs) = Some p" and x: "x = snd p"
    using assms by (auto simp: pick_def)
  from p[unfolded find_Some_iff] obtain i where i: "i < length (zip bs xs)" "fst (zip bs xs ! i)" "p = zip bs xs ! i"
    "\<forall>j<i. \<not> fst (zip bs xs ! j)"
    by blast
  have lb: "i < length bs" and lx: "i < length xs" using i(1) by simp_all
  have all: "\<forall>j<i. \<not> bs ! j"
  proof (intro allI impI)
    fix j assume j: "j < i"
    have jb: "j < length bs" and jx: "j < length xs" using j lb lx by simp_all
    have "\<not> fst (zip bs xs ! j)" using i(4) j by blast
    then show "\<not> bs ! j" using jb jx by simp
  qed
  have b: "bs ! i" using i(2) lb lx by simp
  have e: "xs ! i = x" using i(3) x lb lx by simp
  show ?thesis using lb lx b e all by blast
qed

theorem pick_none:
  assumes "pick bs xs = None"
  shows "\<forall>i. i < length bs \<longrightarrow> i < length xs \<longrightarrow> \<not> bs ! i"
proof (intro allI impI)
  fix i assume i: "i < length bs" "i < length xs"
  have f: "List.find fst (zip bs xs) = None" using assms by (simp add: pick_def)
  have l: "i < length (zip bs xs)" using i by simp
  have m: "zip bs xs ! i \<in> set (zip bs xs)" by (rule nth_mem[OF l])
  have z: "zip bs xs ! i = (bs ! i, xs ! i)" using i by simp
  have all: "\<forall>x. x \<in> set (zip bs xs) \<longrightarrow> \<not> fst x" using f[unfolded find_None_iff] by blast
  then have "\<not> fst (zip bs xs ! i)" using m by blast
  then show "\<not> bs ! i" using z by simp
qed

end
