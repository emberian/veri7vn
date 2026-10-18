theory Materials_Numbers
  imports Materials_Base "Veri7vn_Commons.Commons_Num"
begin

text \<open>Number machinery shared by the materials family. The rounding, the
decimal layout and the interval enclosure come from Veri7vn_Commons
(src/extract/commons/Commons_Num.thy, lifted from lane G), with two
additions: a three-digit enclosure (@{text to_dec3}, the water organ prints the
hydrogen-ion concentration with %.3g) and a fixed-point enclosure
(@{text to_fixed}, the additive organ prints volumes with three decimals).
The family's own @{text enclose} (by mode) and @{text render_fixed} (no
digit-count argument) are different functions from the commons ones of the
same names, so the commons names are hidden below.\<close>

hide_const (open) Commons_Num.enclose Commons_Num.render_fixed
hide_fact (open) Commons_Num.enclose_def Commons_Num.enclose_sound Commons_Num.render_fixed_def

section \<open>Enclosures\<close>

text \<open>Three significant digits from a float interval enclosing a value, or a
refusal when the interval is too wide (lane D's @{text to_dec3}).\<close>
definition to_dec3 :: "float interval \<Rightarrow> (int \<times> int) option" where
  "to_dec3 X = (let lo = real_of_float (lower X); hi = real_of_float (upper X); mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else let e = sig_exp 3 mid in
       if hi - lo \<le> \<bar>mid\<bar> / 1000000 \<and> 100 * pow10 e \<le> \<bar>mid\<bar> then Some (round_at mid e) else None)"

theorem to_dec3_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_dec3 X = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 100 + 1 / 1000000000"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  define mid where "mid = (lo + hi) / 2"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have "d = (0, 0)" using d by (simp add: to_dec3_def Let_def lo_def hi_def)
    then have "dec_val d = 0" by (simp add: dec_val_def)
    then have eq: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" by simp
    have "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    then show ?thesis using eq by linarith
  next
    case False
    define e where "e = sig_exp 3 mid"
    have chk: "hi - lo \<le> \<bar>mid\<bar> / 1000000" "100 * pow10 e \<le> \<bar>mid\<bar>" and dd: "d = round_at mid e"
      using d False by (simp_all add: to_dec3_def Let_def lo_def hi_def mid_def e_def split: if_splits)
    have r: "\<bar>dec_val d - mid\<bar> \<le> \<bar>mid\<bar> / 200"
      unfolding dd using round_at_error[of mid e] chk(2) by linarith
    have "\<bar>mid - x\<bar> \<le> (hi - lo) / 2"
      unfolding mid_def using xin by (rule midpoint_close)
    moreover have "(hi - lo) / 2 \<le> (\<bar>mid\<bar> / 1000000) / 2"
      using chk(1) by (rule divide_right_mono) simp
    then have "(hi - lo) / 2 \<le> \<bar>mid\<bar> / 2000000" by simp
    ultimately have m: "\<bar>mid - x\<bar> \<le> \<bar>mid\<bar> / 2000000" by (rule order_trans)
    have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - mid\<bar> + \<bar>mid - x\<bar>" by arith
    have M: "\<bar>mid\<bar> \<le> \<bar>x\<bar> + \<bar>mid - x\<bar>" by arith
    show ?thesis using r m tri M by linarith
  qed
qed

section \<open>Fixed-point enclosure\<close>

text \<open>An interval around a value, rounded to a fixed number of decimals
@{text "10^e"} when the interval is narrow enough that the midpoint's
rounding is within one unit of the value.\<close>
definition to_fixed :: "int \<Rightarrow> float interval \<Rightarrow> (int \<times> int) option" where
  "to_fixed e X = (let lo = real_of_float (lower X); hi = real_of_float (upper X) in
     if hi - lo \<le> pow10 e / 1000 then Some (round_at ((lo + hi) / 2) e) else None)"

lemma snd_round_at [simp]: "snd (round_at x e) = e"
  by (simp add: round_at_def)

theorem to_fixed_sound:
  assumes x: "x \<in>\<^sub>r X" and d: "to_fixed e X = Some d"
  shows "snd d = e \<and> \<bar>dec_val d - x\<bar> \<le> pow10 e"
proof -
  define lo where "lo = real_of_float (lower X)"
  define hi where "hi = real_of_float (upper X)"
  have xin: "lo \<le> x" "x \<le> hi" using x by (auto simp: lo_def hi_def set_of_eq)
  have chk: "hi - lo \<le> pow10 e / 1000" and dd: "d = round_at ((lo + hi) / 2) e"
    using d by (simp_all add: to_fixed_def Let_def lo_def hi_def split: if_splits)
  have r: "\<bar>dec_val d - (lo + hi) / 2\<bar> \<le> pow10 e / 2"
    unfolding dd by (rule round_at_error)
  have m: "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2" by (rule midpoint_close[OF xin])
  have p: "0 < pow10 e" by (rule pow10_pos)
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - (lo + hi) / 2\<bar> + \<bar>(lo + hi) / 2 - x\<bar>"
    by arith
  have s: "snd d = e" by (simp add: dd)
  have sum: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2 + (hi - lo) / 2"
    by (rule order_trans[OF tri add_mono[OF r m]])
  have half: "pow10 e / 2 + (hi - lo) / 2 \<le> pow10 e"
    using chk p by (simp add: field_simps)
  have "\<bar>dec_val d - x\<bar> \<le> pow10 e" by (rule order_trans[OF sum half])
  with s show ?thesis by simp
qed

section \<open>Layouts and the enclosure of one value\<close>

text \<open>How a decimal is laid out: fixed decimals with trailing zeros stripped,
a whole number with thousands separators, or Python's @{text "%.pg"}.\<close>
datatype layout = Fixed | Commas | Sig nat

fun tol_exact :: "layout \<Rightarrow> int \<times> int \<Rightarrow> real \<Rightarrow> real" where
  "tol_exact Fixed d x = pow10 (snd d) / 2"
| "tol_exact Commas d x = pow10 (snd d) / 2"
| "tol_exact (Sig p) d x = \<bar>x\<bar> / (2 * 10 ^ (p - 1))"

fun tol_approx :: "layout \<Rightarrow> int \<times> int \<Rightarrow> real \<Rightarrow> real" where
  "tol_approx Fixed d x = pow10 (snd d)"
| "tol_approx Commas d x = pow10 (snd d)"
| "tol_approx (Sig p) d x = \<bar>x\<bar> / 10 ^ (p - 1) + 1 / 1000000000"

datatype amode = M_sig3 | M_sig4 | M_add

definition prec :: nat where "prec = 120"

definition enclose :: "amode \<Rightarrow> floatarith \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "enclose m fa = (case approx prec fa [] of None \<Rightarrow> None | Some X \<Rightarrow>
     (case m of
        M_sig3 \<Rightarrow> map_option (\<lambda>d. (d, Sig 3)) (to_dec3 X)
      | M_sig4 \<Rightarrow> map_option (\<lambda>d. (d, Sig 4)) (to_dec X)
      | M_add \<Rightarrow>
          if 1000000 \<le> real_of_float (lower X) then map_option (\<lambda>d. (d, Commas)) (to_fixed 0 X)
          else if real_of_float (upper X) < 1000000 then map_option (\<lambda>d. (d, Fixed)) (to_fixed (-3) X)
          else None))"

theorem enclose_sound:
  assumes "enclose m fa = Some (d, lay)"
  shows "\<bar>dec_val d - interpret_floatarith fa []\<bar> \<le> tol_approx lay d (interpret_floatarith fa [])"
proof -
  obtain X where X: "approx prec fa [] = Some X"
    using assms by (auto simp: enclose_def split: option.splits)
  have mem: "interpret_floatarith fa [] \<in>\<^sub>r X"
  proof -
    have "bounded_by [] []" by (simp add: bounded_by_def)
    from approx[OF this X] show ?thesis .
  qed
  have e3: "(10::real) ^ (3 - 1) = 100" and e4: "(10::real) ^ (4 - 1) = 1000" by simp_all
  show ?thesis
  proof (cases m)
    case M_sig3
    then have h: "map_option (\<lambda>d. (d, Sig 3)) (to_dec3 X) = Some (d, lay)"
      using assms X by (simp add: enclose_def)
    then obtain d3 where d3: "to_dec3 X = Some d3" and dl: "d = d3" "lay = Sig 3"
      by (cases "to_dec3 X") auto
    from to_dec3_sound[OF mem d3] show ?thesis using dl e3 by simp
  next
    case M_sig4
    then have h: "map_option (\<lambda>d. (d, Sig 4)) (to_dec X) = Some (d, lay)"
      using assms X by (simp add: enclose_def)
    then obtain d4 where d4: "to_dec X = Some d4" and dl: "d = d4" "lay = Sig 4"
      by (cases "to_dec X") auto
    from to_dec_sound[OF mem d4] show ?thesis using dl e4 by simp
  next
    case M_add
    show ?thesis
    proof (cases "1000000 \<le> real_of_float (lower X)")
      case True
      then have h: "map_option (\<lambda>d. (d, Commas)) (to_fixed 0 X) = Some (d, lay)"
        using assms X M_add by (simp add: enclose_def)
      then obtain d0 where d0: "to_fixed 0 X = Some d0" and dl: "d = d0" "lay = Commas"
        by (cases "to_fixed 0 X") auto
      from to_fixed_sound[OF mem d0] show ?thesis using dl by simp
    next
      case False
      then have u: "real_of_float (upper X) < 1000000"
        and h: "map_option (\<lambda>d. (d, Fixed)) (to_fixed (-3) X) = Some (d, lay)"
        using assms X M_add by (auto simp: enclose_def split: if_splits)
      then obtain d0 where d0: "to_fixed (-3) X = Some d0" and dl: "d = d0" "lay = Fixed"
        by (cases "to_fixed (-3) X") auto
      from to_fixed_sound[OF mem d0] show ?thesis using dl by simp
    qed
  qed
qed

section \<open>Digits and layouts as text (ASCII)\<close>

definition render_fixed :: "int \<times> int \<Rightarrow> String.literal" where
  "render_fixed d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); p = nat (- e);
         ip = (if p < length ds then take (length ds - p) ds else [0]);
         fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                           else replicate (p - length ds) 0 @ ds)
     in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

fun commas_go :: "nat \<Rightarrow> nat list \<Rightarrow> String.literal" where
  "commas_go n [] = STR ''''"
| "commas_go n (d # ds) = digit_lit d
     + (if 1 < n \<and> (n - 1) mod 3 = 0 then STR '','' else STR '''') + commas_go (n - 1) ds"

definition render_commas :: "int \<Rightarrow> String.literal" where
  "render_commas m = (if m < 0 then STR ''-'' else STR '''')
     + commas_go (length (digits (nat \<bar>m\<bar>))) (digits (nat \<bar>m\<bar>))"

definition render_layout :: "layout \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_layout lay d = (case lay of
       Fixed \<Rightarrow> render_fixed d
     | Commas \<Rightarrow> render_commas (fst d)
     | Sig p \<Rightarrow> render_dec p d)"

text \<open>The same decimal as a JSON number token (no thousands separators).\<close>
definition render_json :: "layout \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_json lay d = (case lay of
       Fixed \<Rightarrow> render_fixed d
     | Commas \<Rightarrow> show_int (fst d)
     | Sig p \<Rightarrow> render_dec p d)"

section \<open>Stated values of exact results\<close>

text \<open>The four organs print their numbers differently. The additive organ
prints three decimals (a whole number with separators from 10^6 up), the soil
organ three decimals, the materials organ four decimals from 1 up to 10^6 and
four significant digits otherwise, the water organ four significant digits
(a whole number from 1000 up with separators).\<close>
datatype family = Fam_add | Fam_mat | Fam_soil | Fam_water

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

definition st_fixed :: "int \<Rightarrow> rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_fixed e q = Some (round_at (rl q) e, Fixed)"

definition st_commas :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_commas q = Some (round_at (rl q) 0, Commas)"

definition st_int :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_int q = (if is_int q then Some ((fst (quotient_of q), 0), Commas) else None)"

definition st_sig :: "rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "st_sig q = (case round_sig 4 (rl q) of Some d \<Rightarrow> Some (d, Sig 4) | None \<Rightarrow> None)"

definition stated_of :: "family \<Rightarrow> rat \<Rightarrow> ((int \<times> int) \<times> layout) option" where
  "stated_of f q = (case f of
      Fam_add \<Rightarrow> if \<bar>q\<bar> < 1000000 then st_fixed (-3) q else st_commas q
    | Fam_soil \<Rightarrow> st_fixed (-3) q
    | Fam_mat \<Rightarrow> if 1 \<le> \<bar>q\<bar> \<and> \<bar>q\<bar> < 1000000 then st_fixed (-4) q else st_sig q
    | Fam_water \<Rightarrow> if 1000 \<le> \<bar>q\<bar> \<and> is_int q then st_int q
                   else if \<bar>q\<bar> < 1000000 then st_sig q else st_commas q)"

definition ok_st :: "((int \<times> int) \<times> layout) option \<Rightarrow> rat \<Rightarrow> bool" where
  "ok_st r q \<longleftrightarrow> (\<forall>d lay. r = Some (d, lay) \<longrightarrow> \<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q))"

lemma ok_fixed: "ok_st (st_fixed e q) q"
proof (unfold ok_st_def st_fixed_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume "Some (round_at (rl q) e, Fixed) = Some (d, lay)"
  then have d: "d = round_at (rl q) e" and lay: "lay = Fixed" by simp_all
  have h: "\<bar>dec_val (round_at (rl q) e) - rl q\<bar> \<le> pow10 e / 2" by (rule round_at_error)
  show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)"
    unfolding d lay tol_exact.simps snd_round_at by (rule h)
qed

lemma ok_commas: "ok_st (st_commas q) q"
proof (unfold ok_st_def st_commas_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume "Some (round_at (rl q) 0, Commas) = Some (d, lay)"
  then have d: "d = round_at (rl q) 0" and lay: "lay = Commas" by simp_all
  have h: "\<bar>dec_val (round_at (rl q) 0) - rl q\<bar> \<le> pow10 0 / 2" by (rule round_at_error)
  show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)"
    unfolding d lay tol_exact.simps snd_round_at by (rule h)
qed

lemma ok_int: "ok_st (st_int q) q"
proof (unfold ok_st_def st_int_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume h: "(if is_int q then Some ((fst (quotient_of q), 0), Commas) else None) = Some (d, lay)"
  then have isi: "is_int q" and d: "d = (fst (quotient_of q), (0::int))" and lay: "lay = Commas"
    by (auto split: if_splits)
  obtain a b where ab: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have b: "b = 1" using isi by (simp add: is_int_def)
  have "q = of_int a / of_int b" using ab by (rule quotient_of_div)
  then have qa: "rl q = of_int a" using b by simp
  have "dec_val d = rl q" using d ab qa by (simp add: dec_val_def pow10_def)
  then show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)" by (simp add: lay less_imp_le[OF pow10_pos])
qed

lemma ok_sig: "ok_st (st_sig q) q"
proof (unfold ok_st_def st_sig_def, intro allI impI)
  fix d :: "int \<times> int" and lay
  assume h: "(case round_sig 4 (rl q) of None \<Rightarrow> None | Some d \<Rightarrow> Some (d, Sig 4)) = Some (d, lay)"
  then obtain d0 where r: "round_sig 4 (rl q) = Some d0" and d: "d = d0" and lay: "lay = Sig 4"
    by (cases "round_sig 4 (rl q)") auto
  from round_sig_sound[OF r] have "\<bar>dec_val d0 - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" .
  then show "\<bar>dec_val d - rl q\<bar> \<le> tol_exact lay d (rl q)" by (simp add: d lay)
qed

theorem stated_of_sound: "ok_st (stated_of f q) q"
  by (cases f) (simp_all add: stated_of_def ok_fixed ok_commas ok_int ok_sig split: if_splits)

definition shw :: "family \<Rightarrow> rat \<Rightarrow> String.literal" where
  "shw f q = (case stated_of f q of Some (d, lay) \<Rightarrow> render_layout lay d | None \<Rightarrow> STR ''?'')"

end
