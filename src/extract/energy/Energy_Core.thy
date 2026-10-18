theory Energy_Core
  imports "Veri7vn_Energy_Base.Energy_Base" "Veri7vn_Commons.Commons_Num"
begin

text \<open>
  Shared machinery of the energy family (lane S06-energy): verified rounding to
  significant digits and to fixed decimals, the number layouts the six organs
  print, a generic four-stage kernel with its soundness theorems, and the reply
  record. The rounding and interval pieces come from Veri7vn_Commons
  (src/extract/commons/Commons_Num.thy, lifted from lane G).
\<close>

section \<open>Interval precision\<close>

definition prec :: nat where "prec = 53"

section \<open>Number layouts\<close>

text \<open>The six organs print numbers in five different ways. G4 is Python's
@{text "%.4g"} (thermo). G4W is @{text "%.4g"} below a million and @{text "%.0f"}
above (home energy). G4C is @{text "%.4g"} below ten thousand and a rounded
whole number with thousands commas above (hvac). F3C and F4C are @{text "%.3f"}
and @{text "%.4f"} with trailing zeros stripped below ten thousand (a hundred
thousand), and the commas form above (renewables, iot). G6 is @{text "%g"}
(a tariff). M2 is a money amount: two decimals below 1000, whole with commas
above. An exact decimal tie rounds up (lane G's @{text round_tie_up}); Python's
@{text round} and @{text "%f"} round a binary tie to even.\<close>
datatype nfmt = G4 | G4W | G4C | F3C | F4C | G6 | M2 | FINT

definition num_dec_r :: "nfmt \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "num_dec_r f x = (case f of
      G4 \<Rightarrow> round_sig 4 x
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then round_sig 4 x else Some (round_at x 0)
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then round_sig 4 x else Some (round_at x 0)
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then Some (round_at x (-3)) else Some (round_at x 0)
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then Some (round_at x (-4)) else Some (round_at x 0)
    | G6 \<Rightarrow> round_sig 6 x
    | M2 \<Rightarrow> if x < 1000 then Some (round_at x (-2)) else Some (round_at x 0)
    | FINT \<Rightarrow> Some (round_at x 0))"

definition fmt_err_r :: "nfmt \<Rightarrow> real \<Rightarrow> real" where
  "fmt_err_r f x = (case f of
      G4 \<Rightarrow> \<bar>x\<bar> / (2 * 10 ^ (4 - 1))
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then \<bar>x\<bar> / (2 * 10 ^ (4 - 1)) else pow10 0 / 2
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then \<bar>x\<bar> / (2 * 10 ^ (4 - 1)) else pow10 0 / 2
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then pow10 (-3) / 2 else pow10 0 / 2
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then pow10 (-4) / 2 else pow10 0 / 2
    | G6 \<Rightarrow> \<bar>x\<bar> / (2 * 10 ^ (6 - 1))
    | M2 \<Rightarrow> if x < 1000 then pow10 (-2) / 2 else pow10 0 / 2
    | FINT \<Rightarrow> pow10 0 / 2)"

theorem num_dec_r_sound:
  assumes "num_dec_r f x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"
proof (cases f)
  case G4
  then have h: "round_sig 4 x = Some d" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_sig_sound[OF h] G4 by (simp add: fmt_err_r_def)
next
  case G4W
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 6")
    case True
    then have h: "round_sig 4 x = Some d" using assms G4W by (simp add: num_dec_r_def)
    show ?thesis using round_sig_sound[OF h] G4W True by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms G4W by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] G4W False h by (simp add: fmt_err_r_def)
  qed
next
  case G4C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 4")
    case True
    then have h: "round_sig 4 x = Some d" using assms G4C by (simp add: num_dec_r_def)
    show ?thesis using round_sig_sound[OF h] G4C True by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms G4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] G4C False h by (simp add: fmt_err_r_def)
  qed
next
  case F3C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 4")
    case True
    then have h: "d = round_at x (-3)" using assms F3C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-3"] F3C True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms F3C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] F3C False h by (simp add: fmt_err_r_def)
  qed
next
  case F4C
  show ?thesis
  proof (cases "\<bar>x\<bar> < 10 ^ 5")
    case True
    then have h: "d = round_at x (-4)" using assms F4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-4"] F4C True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms F4C by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] F4C False h by (simp add: fmt_err_r_def)
  qed
next
  case G6
  then have h: "round_sig 6 x = Some d" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_sig_sound[OF h] G6 by (simp add: fmt_err_r_def)
next
  case M2
  show ?thesis
  proof (cases "x < 1000")
    case True
    then have h: "d = round_at x (-2)" using assms M2 by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x "-2"] M2 True h by (simp add: fmt_err_r_def)
  next
    case False
    then have h: "d = round_at x 0" using assms M2 by (simp add: num_dec_r_def)
    show ?thesis using round_at_error[of x 0] M2 False h by (simp add: fmt_err_r_def)
  qed
next
  case FINT
  then have h: "d = round_at x 0" using assms by (simp add: num_dec_r_def)
  show ?thesis using round_at_error[of x 0] FINT h by (simp add: fmt_err_r_def)
qed

fun rgroups :: "nat list \<Rightarrow> nat list list" where
  "rgroups [] = []"
| "rgroups [a] = [[a]]"
| "rgroups [a, b] = [[a, b]]"
| "rgroups (a # b # c # ds) = [a, b, c] # rgroups ds"

fun join_commas :: "String.literal list \<Rightarrow> String.literal" where
  "join_commas [] = STR ''''"
| "join_commas [x] = x"
| "join_commas (x # y # zs) = x + STR '','' + join_commas (y # zs)"

definition commas :: "int \<Rightarrow> String.literal" where
  "commas i = (if i < 0 then STR ''-'' else STR '''') +
     join_commas (rev (map (\<lambda>g. lit (rev g)) (rgroups (rev (digits (nat \<bar>i\<bar>))))))"

definition fixed2 :: "int \<Rightarrow> String.literal" where
  "fixed2 n = (if n < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>n\<bar> div 100)) + STR ''.''
     + lit [(nat \<bar>n\<bar> mod 100) div 10, (nat \<bar>n\<bar> mod 100) mod 10]"

definition layout :: "nfmt \<Rightarrow> real \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "layout f x d = (case f of
      G4 \<Rightarrow> render_dec 4 d
    | G4W \<Rightarrow> if \<bar>x\<bar> < 10 ^ 6 then render_dec 4 d else show_int (fst d)
    | G4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then render_dec 4 d else commas (fst d)
    | F3C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 4 then render_dec 100 d else commas (fst d)
    | F4C \<Rightarrow> if \<bar>x\<bar> < 10 ^ 5 then render_dec 100 d else commas (fst d)
    | G6 \<Rightarrow> render_dec 6 d
    | M2 \<Rightarrow> if x < 1000 then fixed2 (fst d) else commas (fst d)
    | FINT \<Rightarrow> show_int (fst d))"

definition show_fmt :: "nfmt \<Rightarrow> real \<Rightarrow> String.literal option" where
  "show_fmt f x = (case num_dec_r f x of None \<Rightarrow> None | Some d \<Rightarrow> Some (layout f x d))"

theorem show_fmt_sound:
  assumes "show_fmt f x = Some s"
  shows "\<exists>d. num_dec_r f x = Some d \<and> s = layout f x d \<and> \<bar>dec_val d - x\<bar> \<le> fmt_err_r f x"
  using assms num_dec_r_sound by (auto simp: show_fmt_def split: option.splits)

text \<open>A secondary number in a reply (an input or a by-product).\<close>
definition gf :: "nfmt \<Rightarrow> rat \<Rightarrow> String.literal" where
  "gf f q = (case show_fmt f (rl q) of Some s \<Rightarrow> s | None \<Rightarrow> STR ''?'')"

abbreviation gs :: "rat \<Rightarrow> String.literal" where "gs \<equiv> gf G4"

section \<open>Multiples of pi and power units\<close>

text \<open>The rotor area pi (D/2)^2 and the wind power are rational multiples of pi.
Their decimals come from Isabelle's verified interval arithmetic, never from a
float computed here.\<close>
definition pi_bounds :: "rat \<Rightarrow> (real \<times> real) option" where
  "pi_bounds c = (case approx prec (floatarith.Mult (Q c) floatarith.Pi) [] of
       None \<Rightarrow> None | Some X \<Rightarrow> Some (real_of_float (lower X), real_of_float (upper X)))"

theorem pi_bounds_sound:
  assumes "pi_bounds c = Some (lo, hi)"
  shows "lo \<le> rl c * pi \<and> rl c * pi \<le> hi"
proof -
  from assms obtain X where X: "approx prec (floatarith.Mult (Q c) floatarith.Pi) [] = Some X"
    and lo: "lo = real_of_float (lower X)" and hi: "hi = real_of_float (upper X)"
    by (auto simp: pi_bounds_def split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith (floatarith.Mult (Q c) floatarith.Pi) [] \<in>\<^sub>r X" .
  then have "rl c * pi \<in>\<^sub>r X" by simp
  then show ?thesis using lo hi by (auto simp: set_of_eq)
qed

definition pi_fmt :: "nfmt \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "pi_fmt f c = (case pi_bounds c of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow> show_fmt f ((lo + hi) / 2))"

text \<open>The unit of a power: GW, MW, kW or W by the size of the value, refused
when the enclosure straddles a unit boundary.\<close>
definition pw_scale :: "real \<Rightarrow> real \<Rightarrow> (real \<times> nat) option" where
  "pw_scale lo hi = (if 10 ^ 9 \<le> lo then Some (10 ^ 9, 3) else if 10 ^ 9 \<le> hi then None
     else if 10 ^ 6 \<le> lo then Some (10 ^ 6, 2) else if 10 ^ 6 \<le> hi then None
     else if 10 ^ 3 \<le> lo then Some (10 ^ 3, 1) else if 10 ^ 3 \<le> hi then None
     else Some (1, 0))"

theorem pw_scale_sound:
  assumes "pw_scale lo hi = Some (s, i)"
  shows "0 < s \<and> (s = 1 \<or> s \<le> lo) \<and> (hi < 1000 * s \<or> i = 3)"
  using assms by (auto simp: pw_scale_def split: if_splits)

definition pw_label :: "bool \<Rightarrow> nat \<Rightarrow> String.literal" where
  "pw_label en i = (if i = 3 then STR ''G'' else if i = 2 then STR ''M'' else if i = 1 then STR ''k'' else STR '''')
     + (if en then STR ''Wh'' else STR ''W'')"

definition pw_show :: "bool \<Rightarrow> real \<Rightarrow> real \<Rightarrow> String.literal option" where
  "pw_show en lo hi = (case pw_scale lo hi of None \<Rightarrow> None | Some (s, i) \<Rightarrow>
     (case show_fmt F3C ((lo + hi) / 2 / s) of None \<Rightarrow> None
      | Some n \<Rightarrow> Some (n + STR '' '' + pw_label en i)))"

theorem pw_show_sound:
  assumes "pw_show en lo hi = Some t"
  shows "\<exists>s i d. pw_scale lo hi = Some (s, i) \<and> num_dec_r F3C ((lo + hi) / 2 / s) = Some d \<and>
         \<bar>dec_val d - (lo + hi) / 2 / s\<bar> \<le> fmt_err_r F3C ((lo + hi) / 2 / s)"
proof -
  from assms obtain s i n where s: "pw_scale lo hi = Some (s, i)" and n: "show_fmt F3C ((lo + hi) / 2 / s) = Some n"
    by (auto simp: pw_show_def split: option.splits)
  from show_fmt_sound[OF n] show ?thesis using s by blast
qed

lemma pos_ne: "0 < (x::rat) \<Longrightarrow> x \<noteq> 0"
  by (metis less_irrefl)

section \<open>Outcomes and the generic kernel\<close>

text \<open>An outcome is an exact rational value of a named kind, a rational multiple
of pi (rotor areas and wind power), an answer with no number, or a decline.
A decline carries its class and the words the reply uses.\<close>
datatype dcl = D_under | D_imposs | D_sizing | D_tariff | D_model

datatype outcome =
    Exact String.literal rat
  | PiMul String.literal rat
  | Fixed String.literal
  | Decline dcl String.literal

text \<open>Four stages in the order the organs test: an up-front impossibility
(@{text pre}), a missing quantity (@{text miss}, always underspecified), a late
impossibility or other refusal (@{text post}), an answer without a number
(@{text fx}); otherwise the value.\<close>
definition mk_kernel ::
  "('r \<Rightarrow> (dcl \<times> String.literal) option) \<Rightarrow> ('r \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> (dcl \<times> String.literal) option) \<Rightarrow> ('r \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> String.literal) \<Rightarrow> ('r \<Rightarrow> rat) \<Rightarrow> ('r \<Rightarrow> bool) \<Rightarrow> 'r \<Rightarrow> outcome" where
  "mk_kernel pre miss post fx kd vl pf r =
     (case pre r of Some (d, w) \<Rightarrow> Decline d w | None \<Rightarrow>
      (case miss r of Some w \<Rightarrow> Decline D_under w | None \<Rightarrow>
       (case post r of Some (d, w) \<Rightarrow> Decline d w | None \<Rightarrow>
        (case fx r of Some k \<Rightarrow> Fixed k | None \<Rightarrow>
         (if pf r then PiMul (kd r) (vl r) else Exact (kd r) (vl r))))))"

theorem mk_exact:
  "mk_kernel pre miss post fx kd vl pf r = Exact k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> \<not> pf r \<and> k = kd r \<and> q = vl r"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_pi:
  "mk_kernel pre miss post fx kd vl pf r = PiMul k q \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = None \<and> pf r \<and> k = kd r \<and> q = vl r"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_fixed:
  "mk_kernel pre miss post fx kd vl pf r = Fixed k \<longleftrightarrow>
     pre r = None \<and> miss r = None \<and> post r = None \<and> fx r = Some k"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

theorem mk_decline:
  "mk_kernel pre miss post fx kd vl pf r = Decline d w \<longleftrightarrow>
     pre r = Some (d, w) \<or> (pre r = None \<and> miss r = Some w \<and> d = D_under) \<or>
     (pre r = None \<and> miss r = None \<and> post r = Some (d, w))"
  by (auto simp: mk_kernel_def split: option.splits prod.splits if_splits)

section \<open>Replies\<close>

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition dcl_name :: "dcl \<Rightarrow> String.literal" where
  "dcl_name d = (case d of D_under \<Rightarrow> STR ''underspecified'' | D_imposs \<Rightarrow> STR ''impossible''
     | D_sizing \<Rightarrow> STR ''sizing'' | D_tariff \<Rightarrow> STR ''need_tariff''
     | D_model \<Rightarrow> STR ''unsupported_model'')"

definition decline_text :: "dcl \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "decline_text d w = (case d of
       D_under \<Rightarrow> STR ''I need '' + w + STR '' to work that out; I won'' + apos + STR ''t assume it.''
     | _ \<Rightarrow> w)"

definition imprecise_text :: String.literal where
  "imprecise_text = STR ''The interval arithmetic could not pin the digits; I won'' + apos + STR ''t guess.''"

text \<open>@{text shw} writes the stated number (None when the layout cannot be
decided), @{text ext} puts it in the sentence, @{text pit} writes a whole
sentence for a multiple of pi, @{text fxt} the sentence of an answer without a
number.\<close>
definition mk_reply ::
  "('r \<Rightarrow> outcome) \<Rightarrow> ('r \<Rightarrow> rat \<Rightarrow> String.literal option) \<Rightarrow> ('r \<Rightarrow> bool) \<Rightarrow>
   ('r \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal) \<Rightarrow> ('r \<Rightarrow> rat \<Rightarrow> String.literal option) \<Rightarrow>
   ('r \<Rightarrow> String.literal \<Rightarrow> String.literal) \<Rightarrow> 'r \<Rightarrow> reply" where
  "mk_reply kn shw plain ext pit fxt r = (case kn r of
       Exact k q \<Rightarrow> (case shw r q of
           None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
         | Some V \<Rightarrow> Reply True k (ext r q V) (if plain r then Some V else None))
     | PiMul k c \<Rightarrow> (case pit r c of
           None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
         | Some s \<Rightarrow> Reply True k s None)
     | Fixed k \<Rightarrow> Reply True k (fxt r k) None
     | Decline d w \<Rightarrow> Reply False (dcl_name d) (decline_text d w) None)"

theorem mk_reply_answered_iff:
  "answered (mk_reply kn shw plain ext pit fxt r) \<longleftrightarrow>
     (\<exists>k q V. kn r = Exact k q \<and> shw r q = Some V) \<or> (\<exists>k c s. kn r = PiMul k c \<and> pit r c = Some s) \<or>
     (\<exists>k. kn r = Fixed k)"
  by (auto simp: mk_reply_def split: outcome.splits option.splits)

theorem mk_reply_exact:
  "kn r = Exact k q \<Longrightarrow> shw r q = Some V \<Longrightarrow>
     response (mk_reply kn shw plain ext pit fxt r) = ext r q V \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = k"
  by (simp add: mk_reply_def)

theorem mk_reply_withheld:
  "kn r = Decline d w \<Longrightarrow>
     \<not> answered (mk_reply kn shw plain ext pit fxt r) \<and>
     response (mk_reply kn shw plain ext pit fxt r) = decline_text d w \<and>
     reply_kind (mk_reply kn shw plain ext pit fxt r) = dcl_name d"
  by (simp add: mk_reply_def)

end
