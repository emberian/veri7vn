theory Disc_Dtext
  imports Complex_Main "HOL-Library.Code_Target_Numeral"
begin

text \<open>Shared reply type and plain-ASCII text helpers for the discrete family.
A response is a list of pieces: a literal (ASCII) or raw bytes copied from the
question (so data-format answers keep their bytes exactly).\<close>

datatype piece = PS String.literal | PB "nat list"
datatype jv = JNone | JRaw String.literal | JStr "nat list"
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: "piece list") (stated: jv)

definition piece_lit :: "piece \<Rightarrow> String.literal option" where
  "piece_lit p = (case p of PS s \<Rightarrow> Some s | PB _ \<Rightarrow> None)"

definition piece_raw :: "piece \<Rightarrow> nat list" where
  "piece_raw p = (case p of PB l \<Rightarrow> l | PS _ \<Rightarrow> [])"

fun digits :: "nat \<Rightarrow> nat list" where
  "digits n = (if n < 10 then [n] else digits (n div 10) @ [n mod 10])"

definition digit_lit :: "nat \<Rightarrow> String.literal" where
  "digit_lit d = (if d = 0 then STR ''0'' else if d = 1 then STR ''1'' else if d = 2 then STR ''2''
    else if d = 3 then STR ''3'' else if d = 4 then STR ''4'' else if d = 5 then STR ''5''
    else if d = 6 then STR ''6'' else if d = 7 then STR ''7'' else if d = 8 then STR ''8''
    else STR ''9'')"

definition lit :: "nat list \<Rightarrow> String.literal" where
  "lit ds = foldr (\<lambda>d s. digit_lit d + s) ds (STR '''')"

definition strip_zeros :: "nat list \<Rightarrow> nat list" where
  "strip_zeros ds = rev (dropWhile (\<lambda>d. d = 0) (rev ds))"

definition pad2 :: "nat list \<Rightarrow> nat list" where
  "pad2 ds = (if length ds < 2 then 0 # ds else ds)"

definition show_nat :: "nat \<Rightarrow> String.literal" where
  "show_nat n = lit (digits n)"

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

text \<open>Thousands separators, as Python's @{text "format(n, ',')"}.\<close>
definition commas :: "nat \<Rightarrow> String.literal" where
  "commas n = (let ds = digits n; k = length ds in
     foldr (\<lambda>p s. digit_lit (snd p) +
              (if fst p + 1 < k \<and> (k - 1 - fst p) mod 3 = 0 then STR '','' else STR '''') + s)
           (zip [0..<k] ds) (STR ''''))"

text \<open>Python's @{text str} of a Fraction: numerator, and a slash and the
denominator unless it is 1.\<close>
definition show_frac :: "rat \<Rightarrow> String.literal" where
  "show_frac q = (case quotient_of q of (n, d) \<Rightarrow>
     if d = 1 then show_int n else show_int n + STR ''/'' + show_nat (nat d))"

text \<open>Python's @{text "%.pg"} layout for a decimal @{text "m * 10^e"} (lane G's
@{text render_dec}).\<close>
definition render_dec :: "nat \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_dec p d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); k = int (length ds); x = e + k - 1 in
     if x < -4 \<or> int p \<le> x then
       (let fr = strip_zeros (tl ds) in
        sg + lit [hd ds] + (if fr = [] then STR '''' else STR ''.'' + lit fr) + STR ''e''
          + (if x < 0 then STR ''-'' else STR ''+'') + lit (pad2 (digits (nat \<bar>x\<bar>))))
     else if 0 \<le> e then sg + lit (ds @ replicate (nat e) 0)
     else
       (let p = nat (- e);
            ip = (if p < length ds then take (length ds - p) ds else [0]);
            fr = strip_zeros (if p < length ds then drop (length ds - p) ds
                              else replicate (p - length ds) 0 @ ds)
        in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr)))"

section \<open>Percentages: fixed point, four decimals\<close>

definition pct_num :: "rat \<Rightarrow> nat" where
  "pct_num q = nat \<lfloor>1000000 * q + 1 / 2\<rfloor>"

theorem pct_num_sound:
  assumes "0 \<le> q"
  shows "\<bar>rat_of_nat (pct_num q) / 10000 - 100 * q\<bar> \<le> 1 / 20000"
proof -
  let ?x = "1000000 * q + 1 / 2"
  have x0: "0 \<le> ?x" using assms by simp
  have f0: "0 \<le> \<lfloor>?x\<rfloor>" using x0 by simp
  have k: "int (nat \<lfloor>?x\<rfloor>) = \<lfloor>?x\<rfloor>" using f0 by simp
  have n: "rat_of_nat (pct_num q) = rat_of_int \<lfloor>?x\<rfloor>"
  proof -
    have "rat_of_nat (nat \<lfloor>?x\<rfloor>) = rat_of_int (int (nat \<lfloor>?x\<rfloor>))" by simp
    then show ?thesis unfolding pct_num_def using k by simp
  qed
  have lo: "rat_of_int \<lfloor>?x\<rfloor> \<le> ?x" by (rule of_int_floor_le)
  have hi: "?x < rat_of_int \<lfloor>?x\<rfloor> + 1" using floor_correct[of ?x] by simp
  show ?thesis unfolding abs_le_iff using n lo hi by (intro conjI; linarith)
qed

text \<open>Python's @{text "('%.4f' % (float(f)*100)).rstrip('0').rstrip('.')"} on the
exact rational (an exact tie rounds up).\<close>
definition pct_text :: "rat \<Rightarrow> String.literal" where
  "pct_text q = (let n = pct_num q; ip = n div 10000; fr = strip_zeros ((replicate (4 - length (digits (n mod 10000))) 0 @ digits (n mod 10000)))
     in show_nat ip + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

section \<open>Significant-digit rendering of a rational (Python %.6g)\<close>

fun ex_pos :: "nat \<Rightarrow> rat \<Rightarrow> int \<Rightarrow> int" where
  "ex_pos 0 q e = e"
| "ex_pos (Suc f) q e = (if q < 10 then e else ex_pos f (q / 10) (e + 1))"

fun ex_neg :: "nat \<Rightarrow> rat \<Rightarrow> int \<Rightarrow> int" where
  "ex_neg 0 q e = e"
| "ex_neg (Suc f) q e = (if 1 \<le> q then e else ex_neg f (q * 10) (e - 1))"

definition ex10 :: "rat \<Rightarrow> int" where
  "ex10 q = (if 1 \<le> q then ex_pos 400 q 0 else ex_neg 400 q 0)"

definition p10 :: "int \<Rightarrow> rat" where
  "p10 k = (if 0 \<le> k then 10 ^ nat k else 1 / 10 ^ nat (- k))"

definition fmt_g :: "nat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "fmt_g p q = (if q = 0 then STR ''0'' else
     let a = \<bar>q\<bar>; x = ex10 a; m = nat \<lfloor>a / p10 (x + 1 - int p) + 1 / 2\<rfloor>;
         d = (if m = 10 ^ p then (10 ^ (p - 1), x + 2 - int p) else (int m, x + 1 - int p))
     in render_dec p (if q < 0 then (- fst d, snd d) else d))"

text \<open>Python's @{text "fmt"}: an integer-valued number as an integer, else six
significant digits.\<close>
definition fmt_num :: "rat \<Rightarrow> String.literal" where
  "fmt_num q = (if snd (quotient_of q) = 1 then show_int (fst (quotient_of q)) else fmt_g 6 q)"

definition mkreply :: "bool \<Rightarrow> String.literal \<Rightarrow> piece list \<Rightarrow> jv \<Rightarrow> reply" where
  "mkreply = Reply"

end
