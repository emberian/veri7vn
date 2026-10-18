theory Life_Num
  imports "HOL-Decision_Procs.Approximation" "Veri7vn_Commons.Commons_Num"
begin

text \<open>Lane S09-life: exact and enclosed numbers for the life-science family
(genetics-v2, biology, ecology, forestry, wildlife, microbiology-v2). The rounding,
enclosure and digit layout (pow10 .. render_dec) come from Veri7vn_Commons
(src/extract/commons/Commons_Num.thy, lifted from lane G); it lives in the
cached base session so the family kernels rebuild quickly. This theory adds:
a plain (never exponent) layout, the stated decimal of an exact rational, and the
fraction and percent layouts the genetics organ prints.\<close>

definition prec :: nat where "prec = 72"

section \<open>Plain layouts and stated decimals\<close>

text \<open>The layout of a decimal @{text "m * 10^e"} without an exponent part
(the organs print fixed-point text; their scorers do not read e-notation).\<close>
definition render_plain :: "int \<times> int \<Rightarrow> String.literal" where
  "render_plain d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>) in
     if 0 \<le> e then sg + lit (ds @ replicate (nat e) 0)
     else
       (let p = nat (- e);
            ip = (if p < length ds then take (length ds - p) ds else [0]);
            fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                              else replicate (p - length ds) 0 @ ds)
        in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr)))"

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

text \<open>The decimal stated for an exact rational: a whole number exactly,
otherwise four significant digits.\<close>
definition num_dec :: "rat \<Rightarrow> (int \<times> int) option" where
  "num_dec q = (if is_int q then Some (fst (quotient_of q), 0) else round_sig 4 (rl q))"

theorem num_dec_sound:
  assumes "num_dec q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / 2000"
proof (cases "is_int q")
  case True
  obtain a b where ab: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have b: "b = 1" using True by (simp add: is_int_def)
  have "q = of_int a / of_int b" using ab by (rule quotient_of_div)
  then have qa: "q = of_int a" using b by simp
  have "d = (a, 0)" using assms True ab by (simp add: num_dec_def)
  then have "dec_val d = rl q" using qa by (simp add: dec_val_def pow10_def)
  then show ?thesis by simp
next
  case False
  have "round_sig 4 (rl q) = Some d" using assms False by (simp add: num_dec_def)
  then have "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" by (rule round_sig_sound)
  then show ?thesis by simp
qed

definition plain_lit :: "rat \<Rightarrow> String.literal" where
  "plain_lit q = (case num_dec q of Some d \<Rightarrow> render_plain d | None \<Rightarrow> STR ''?'')"

text \<open>The decimal with a fixed number of places after the point (absolute
error at most half a unit in the last place).\<close>
definition fixed_dec :: "nat \<Rightarrow> rat \<Rightarrow> int \<times> int" where
  "fixed_dec p q = round_at (rl q) (- int p)"

theorem fixed_dec_sound: "\<bar>dec_val (fixed_dec p q) - rl q\<bar> \<le> pow10 (- int p) / 2"
  unfolding fixed_dec_def using round_at_error[of "rl q" "- int p"] by linarith

definition fixed_lit :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fixed_lit p q = render_plain (fixed_dec p q)"

text \<open>Python's @{text "str(Fraction)"}: @{text "a/b"}, or just @{text a} when
the denominator is one.\<close>
definition frac_lit :: "rat \<Rightarrow> String.literal" where
  "frac_lit q = (case quotient_of q of (a, b) \<Rightarrow>
     if b = 1 then show_int a else show_int a + STR ''/'' + show_int b)"

end
