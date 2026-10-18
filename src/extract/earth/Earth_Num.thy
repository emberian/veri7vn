theory Earth_Num
  imports "Veri7vn_Earth_Base.Earth_Base"
begin

text \<open>
  Numeric core of the earth family (lane S03-earth). A value the family states is
  an @{text xexpr}: an exact rational, or a real given by a @{text floatarith}
  expression that Isabelle's verified interval arithmetic encloses. Both are
  turned into a decimal with a proved error bound (@{text render_x_sound}) and
  laid out as the organ's number format (four significant digits, fixed
  places, comma-grouped integers, three-digit scientific).

  The rounding lemmas follow lane G (src/extract/quantity/Quantity.thy) and lane D
  (src/extract/acoustics/Acoustics.thy); the proofs of @{text round_at_error},
  @{text round_sig_sound} and @{text to_dec_sound} are theirs, restated over a pair of
  real bounds instead of a float interval.
\<close>

abbreviation rl :: "rat \<Rightarrow> real" where "rl \<equiv> of_rat"

section \<open>Decimals and rounding\<close>

definition pow10 :: "int \<Rightarrow> real" where
  "pow10 k = (if 0 \<le> k then 10 ^ nat k else inverse (10 ^ nat (- k)))"

lemma pow10_pos: "0 < pow10 k"
  by (simp add: pow10_def)

definition dec_val :: "int \<times> int \<Rightarrow> real" where
  "dec_val d = (case d of (m, e) \<Rightarrow> of_int m * pow10 e)"

definition round_at :: "real \<Rightarrow> int \<Rightarrow> int \<times> int" where
  "round_at x e = (\<lfloor>x / pow10 e + 1 / 2\<rfloor>, e)"

lemma round_at_error: "\<bar>dec_val (round_at x e) - x\<bar> \<le> pow10 e / 2"
proof -
  define p where "p = pow10 e"
  have p: "0 < p" by (simp add: p_def pow10_pos)
  define y where "y = x / p"
  have x: "x = y * p" using p by (simp add: y_def)
  have lo: "of_int \<lfloor>y + 1 / 2\<rfloor> \<le> y + 1 / 2" by (rule of_int_floor_le)
  have hi: "y + 1 / 2 < of_int \<lfloor>y + 1 / 2\<rfloor> + 1" by (rule real_of_int_floor_add_one_gt)
  have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> \<le> 1 / 2" using lo hi by linarith
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> - y\<bar> * p \<le> 1 / 2 * p" using p by (intro mult_right_mono) auto
  then have "\<bar>of_int \<lfloor>y + 1 / 2\<rfloor> * p - y * p\<bar> \<le> p / 2"
    using p by (simp add: abs_mult left_diff_distrib[symmetric])
  then show ?thesis by (simp add: dec_val_def round_at_def p_def[symmetric] y_def[symmetric] x[symmetric])
qed

text \<open>An exact decimal tie rounds up.\<close>
theorem round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
proof -
  have "x / pow10 e + 1 / 2 = of_int (n + 1)" using assms by simp
  then show ?thesis by (simp add: round_at_def)
qed

fun exp_up :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_up B x 0 e = e"
| "exp_up B x (Suc n) e = (if B * pow10 e \<le> x then exp_up B x n (e + 1) else e)"

fun exp_down :: "real \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> int \<Rightarrow> int" where
  "exp_down L x 0 e = e"
| "exp_down L x (Suc n) e = (if x < L * pow10 e then exp_down L x n (e - 1) else e)"

definition sig_exp :: "nat \<Rightarrow> real \<Rightarrow> int" where
  "sig_exp p x = exp_down (10 ^ (p - 1)) \<bar>x\<bar> 400 (exp_up (10 ^ p) \<bar>x\<bar> 400 0)"

definition round_sig :: "nat \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "round_sig p x = (if x = 0 then Some (0, 0) else
     let e = sig_exp p x in if 10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar> then Some (round_at x e) else None)"

theorem round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
proof (cases "x = 0")
  case True
  then have "d = (0, 0)" using assms by (simp add: round_sig_def)
  then show ?thesis using True by (simp add: dec_val_def)
next
  case False
  define e where "e = sig_exp p x"
  have chk: "10 ^ (p - 1) * pow10 e \<le> \<bar>x\<bar>" and dd: "d = round_at x e"
    using assms False by (simp_all add: round_sig_def Let_def e_def split: if_splits)
  have r: "\<bar>dec_val d - x\<bar> \<le> pow10 e / 2" unfolding dd by (rule round_at_error)
  have L: "(10::real) ^ (p - 1) \<noteq> 0" by simp
  have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))"
    using chk by (rule divide_right_mono) simp
  moreover have "(10 ^ (p - 1) * pow10 e) / (2 * 10 ^ (p - 1)) = pow10 e / 2"
    using L by (simp add: field_simps)
  ultimately have "pow10 e / 2 \<le> \<bar>x\<bar> / (2 * 10 ^ (p - 1))" by simp
  then show ?thesis using r by linarith
qed

lemma midpoint_close:
  fixes lo hi x :: real
  assumes "lo \<le> x" "x \<le> hi"
  shows "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2"
proof (rule abs_leI)
  show "(lo + hi) / 2 - x \<le> (hi - lo) / 2" using assms(1) by (simp add: field_simps)
  show "- ((lo + hi) / 2 - x) \<le> (hi - lo) / 2" using assms(2) by (simp add: field_simps)
qed

text \<open>Four significant digits for a value known to lie in @{text "[lo, hi]"}, or a
refusal when the enclosure is too wide (lane D's @{text to_dec}).\<close>
definition to_dec :: "real \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "to_dec lo hi = (let mid = (lo + hi) / 2 in
     if lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000 then Some (0, 0)
     else let e = sig_exp 4 mid in
       if hi - lo \<le> \<bar>mid\<bar> / 1000000 \<and> 1000 * pow10 e \<le> \<bar>mid\<bar> then Some (round_at mid e) else None)"

theorem to_dec_sound:
  assumes xin: "lo \<le> x" "x \<le> hi" and d: "to_dec lo hi = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000"
proof -
  define mid where "mid = (lo + hi) / 2"
  show ?thesis
  proof (cases "lo \<le> 0 \<and> 0 \<le> hi \<and> hi - lo \<le> 1 / 1000000000")
    case True
    then have "d = (0, 0)" using d by (simp add: to_dec_def Let_def)
    then have "dec_val d = 0" by (simp add: dec_val_def)
    then have eq: "\<bar>dec_val d - x\<bar> = \<bar>x\<bar>" by simp
    have "\<bar>x\<bar> \<le> 1 / 1000000000" using True xin by arith
    then show ?thesis using eq by linarith
  next
    case False
    define e where "e = sig_exp 4 mid"
    have chk: "hi - lo \<le> \<bar>mid\<bar> / 1000000" "1000 * pow10 e \<le> \<bar>mid\<bar>" and dd: "d = round_at mid e"
      using d False by (simp_all add: to_dec_def Let_def mid_def e_def split: if_splits)
    have r: "\<bar>dec_val d - mid\<bar> \<le> \<bar>mid\<bar> / 2000"
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

text \<open>A fixed number of decimal places for a value in @{text "[lo, hi]"}.\<close>
definition to_places :: "nat \<Rightarrow> real \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "to_places n lo hi =
     (if hi - lo \<le> pow10 (- int n) / 100 then Some (round_at ((lo + hi) / 2) (- int n)) else None)"

theorem to_places_sound:
  assumes xin: "lo \<le> x" "x \<le> hi" and d: "to_places n lo hi = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> 101 / 200 * pow10 (- int n)"
proof -
  define e where "e = - int n"
  have chk: "hi - lo \<le> pow10 e / 100" and dd: "d = round_at ((lo + hi) / 2) e"
    using d by (simp_all add: to_places_def e_def split: if_splits)
  have r: "\<bar>dec_val d - (lo + hi) / 2\<bar> \<le> pow10 e / 2"
    unfolding dd by (rule round_at_error)
  have "\<bar>(lo + hi) / 2 - x\<bar> \<le> (hi - lo) / 2" using xin by (rule midpoint_close)
  moreover have "(hi - lo) / 2 \<le> (pow10 e / 100) / 2" using chk by (rule divide_right_mono) simp
  ultimately have m: "\<bar>(lo + hi) / 2 - x\<bar> \<le> pow10 e / 200" by simp
  have tri: "\<bar>dec_val d - x\<bar> \<le> \<bar>dec_val d - (lo + hi) / 2\<bar> + \<bar>(lo + hi) / 2 - x\<bar>" by arith
  show ?thesis unfolding e_def[symmetric] using r m tri by linarith
qed

section \<open>Expressions and their enclosures\<close>

definition I :: "int \<Rightarrow> floatarith" where "I i = floatarith.Num (Float i 0)"

definition Q :: "rat \<Rightarrow> floatarith" where
  "Q q = (case quotient_of q of (a, b) \<Rightarrow> floatarith.Mult (I a) (floatarith.Inverse (I b)))"

lemma interp_I [simp]: "interpret_floatarith (I i) xs = of_int i"
  by (simp add: I_def)

lemma interp_Q [simp]: "interpret_floatarith (Q q) xs = rl q"
proof -
  obtain a b where qa: "quotient_of q = (a, b)" by (cases "quotient_of q")
  then have "q = of_int a / of_int b" by (rule quotient_of_div)
  then have "rl q = of_int a / of_int b" by (simp add: of_rat_divide)
  then show ?thesis by (simp add: Q_def qa divide_inverse)
qed

definition fsub :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where
  "fsub a b = floatarith.Add a (floatarith.Minus b)"
definition fdiv :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where
  "fdiv a b = floatarith.Mult a (floatarith.Inverse b)"

lemma interp_fsub [simp]: "interpret_floatarith (fsub a b) xs = interpret_floatarith a xs - interpret_floatarith b xs"
  by (simp add: fsub_def)
lemma interp_fdiv [simp]: "interpret_floatarith (fdiv a b) xs = interpret_floatarith a xs / interpret_floatarith b xs"
  by (simp add: fdiv_def divide_inverse)

datatype xexpr = XRat rat | XFa nat floatarith

fun xsem :: "xexpr \<Rightarrow> real" where
  "xsem (XRat q) = rl q"
| "xsem (XFa p e) = interpret_floatarith e []"

fun fa_of :: "xexpr \<Rightarrow> floatarith" where
  "fa_of (XRat q) = Q q"
| "fa_of (XFa p e) = e"

lemma interp_fa_of [simp]: "interpret_floatarith (fa_of x) [] = xsem x"
  by (cases x) simp_all

fun affine_x :: "rat \<Rightarrow> rat \<Rightarrow> xexpr \<Rightarrow> xexpr" where
  "affine_x a b (XRat q) = XRat (a * q + b)"
| "affine_x a b (XFa p e) = XFa p (floatarith.Add (floatarith.Mult (Q a) e) (Q b))"

lemma xsem_affine_x [simp]: "xsem (affine_x a b x) = rl a * xsem x + rl b"
  by (cases x) (simp_all add: of_rat_mult of_rat_add)

fun scale_x :: "rat \<Rightarrow> xexpr \<Rightarrow> xexpr" where
  "scale_x c (XRat q) = XRat (c * q)"
| "scale_x c (XFa p e) = XFa p (floatarith.Mult (Q c) e)"

lemma xsem_scale_x [simp]: "xsem (scale_x c x) = rl c * xsem x"
  by (cases x) (simp_all add: of_rat_mult)

definition dprec :: nat where "dprec = 50"

fun xint :: "xexpr \<Rightarrow> (real \<times> real) option" where
  "xint (XRat q) = Some (rl q, rl q)"
| "xint (XFa p e) = (case approx p e [] of None \<Rightarrow> None
     | Some X \<Rightarrow> Some (real_of_float (lower X), real_of_float (upper X)))"

lemma xint_sound:
  assumes "xint x = Some (lo, hi)"
  shows "lo \<le> xsem x \<and> xsem x \<le> hi"
proof (cases x)
  case (XRat q)
  then show ?thesis using assms by simp
next
  case (XFa p e)
  obtain X where X: "approx p e [] = Some X" and lh: "lo = real_of_float (lower X)" "hi = real_of_float (upper X)"
    using assms XFa by (auto split: option.splits)
  have "bounded_by [] []" by (simp add: bounded_by_def)
  from approx[OF this X] have "interpret_floatarith e [] \<in>\<^sub>r X" .
  then show ?thesis using XFa lh by (simp add: set_of_eq)
qed

section \<open>Text\<close>

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

text \<open>Python's @{text "%.pg"} layout of a decimal @{text "m * 10^e"} (lane D).\<close>
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

text \<open>Python's @{text "('%.nf' % x).rstrip('0').rstrip('.')"} for a decimal @{text "m * 10^(-n)"}.\<close>
definition render_fixed :: "nat \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_fixed n d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds0 = digits (nat \<bar>m\<bar>);
         ds = replicate (n + 1 - length ds0) 0 @ ds0;
         ip = take (length ds - n) ds;
         fr = strip_zeros (drop (length ds - n) ds)
     in sg + lit ip + (if fr = [] then STR '''' else STR ''.'' + lit fr))"

fun commas :: "nat list \<Rightarrow> String.literal" where
  "commas [] = STR ''''"
| "commas (d # ds) = digit_lit d + (if ds \<noteq> [] \<and> length ds mod 3 = 0 then STR '','' else STR '''') + commas ds"

text \<open>Python's @{text "format(n, ',')"} for the integer @{text "m * 10^0"}.\<close>
definition render_comma :: "int \<times> int \<Rightarrow> String.literal" where
  "render_comma d = (case d of (m, e) \<Rightarrow>
     (if m < 0 then STR ''-'' else STR '''') + commas (digits (nat \<bar>m\<bar>)))"

text \<open>Python's @{text "%.3e"} for a decimal already rounded to four significant digits.\<close>
definition render_sci3 :: "int \<times> int \<Rightarrow> String.literal" where
  "render_sci3 d = (case d of (m, e) \<Rightarrow>
     if m = 0 then STR ''0.000e+00'' else
     let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>); x = e + int (length ds) - 1;
         mant = take 4 (ds @ replicate 4 0)
     in sg + lit [hd mant] + STR ''.'' + lit (tl mant) + STR ''e''
          + (if x < 0 then STR ''-'' else STR ''+'') + lit (pad2 (digits (nat \<bar>x\<bar>))))"

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

text \<open>A number the question gave, echoed as written (up to 15 digits).\<close>
definition show_input :: "rat \<Rightarrow> String.literal" where
  "show_input q = (if snd (quotient_of q) = 1 then show_int (fst (quotient_of q))
     else case round_sig 15 (rl q) of Some d \<Rightarrow> render_dec 15 d | None \<Rightarrow> STR ''?'')"

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"

section \<open>Layouts\<close>

datatype layout = L4 | LP nat | LC | LSci

fun render_layout :: "layout \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "render_layout L4 d = render_dec 4 d"
| "render_layout (LP n) d = render_fixed n d"
| "render_layout LC d = render_comma d"
| "render_layout LSci d = render_sci3 d"

fun round_layout :: "layout \<Rightarrow> real \<Rightarrow> real \<Rightarrow> (int \<times> int) option" where
  "round_layout L4 lo hi = to_dec lo hi"
| "round_layout (LP n) lo hi = to_places n lo hi"
| "round_layout LC lo hi = to_places 0 lo hi"
| "round_layout LSci lo hi = to_dec lo hi"

fun layout_err :: "layout \<Rightarrow> real \<Rightarrow> real" where
  "layout_err L4 x = \<bar>x\<bar> / 1000 + 1 / 1000000000"
| "layout_err (LP n) x = 101 / 200 * pow10 (- int n)"
| "layout_err LC x = 101 / 200"
| "layout_err LSci x = \<bar>x\<bar> / 1000 + 1 / 1000000000"

theorem round_layout_sound:
  assumes a: "lo \<le> x" "x \<le> hi" and r: "round_layout L lo hi = Some d"
  shows "\<bar>dec_val d - x\<bar> \<le> layout_err L x"
proof (cases L)
  case L4
  then have "to_dec lo hi = Some d" using r by simp
  then show ?thesis using to_dec_sound[OF a(1) a(2)] L4 by simp
next
  case (LP n)
  then have "to_places n lo hi = Some d" using r by simp
  then show ?thesis using to_places_sound[OF a(1) a(2)] LP by simp
next
  case LC
  then have "to_places 0 lo hi = Some d" using r by simp
  then have "\<bar>dec_val d - x\<bar> \<le> 101 / 200 * pow10 (- int 0)"
    by (rule to_places_sound[OF a(1) a(2)])
  then show ?thesis using LC by (simp add: pow10_def)
next
  case LSci
  then have "to_dec lo hi = Some d" using r by simp
  then show ?thesis using to_dec_sound[OF a(1) a(2)] LSci by simp
qed

text \<open>How an organ lays a number out, as a function of its size.\<close>
datatype gfmt = GFix layout | GGeo | GSeis | GHydro | GOcean

fun layout_of :: "gfmt \<Rightarrow> real \<Rightarrow> layout" where
  "layout_of (GFix L) m = L"
| "layout_of GGeo m = (if m \<noteq> 0 \<and> (10 ^ 7 \<le> \<bar>m\<bar> \<or> \<bar>m\<bar> < 1 / 1000) then L4
     else if \<bar>m\<bar> < 10 ^ 5 then LP 4 else LC)"
| "layout_of GSeis m = (if m = 0 then L4
     else if 10 ^ 6 \<le> \<bar>m\<bar> \<or> \<bar>m\<bar> < 1 / 1000 then LSci
     else if \<bar>m\<bar> < 1000 then LP 3 else LC)"
| "layout_of GHydro m = (if \<bar>m\<bar> < 10 ^ 6 then L4 else LC)"
| "layout_of GOcean m = (if \<bar>m\<bar> < 10 ^ 5 then LP 3 else LC)"

definition render_x :: "gfmt \<Rightarrow> xexpr \<Rightarrow> String.literal option" where
  "render_x f x = (case xint x of None \<Rightarrow> None | Some (lo, hi) \<Rightarrow>
     (let L = layout_of f ((lo + hi) / 2) in map_option (render_layout L) (round_layout L lo hi)))"

theorem render_x_sound:
  assumes "render_x f x = Some s"
  shows "\<exists>L d. s = render_layout L d \<and> \<bar>dec_val d - xsem x\<bar> \<le> layout_err L (xsem x)"
proof -
  obtain lo hi where I: "xint x = Some (lo, hi)"
    using assms by (auto simp: render_x_def split: option.splits)
  obtain d where d: "round_layout (layout_of f ((lo + hi) / 2)) lo hi = Some d"
    and s: "s = render_layout (layout_of f ((lo + hi) / 2)) d"
    using assms I by (auto simp: render_x_def Let_def split: option.splits)
  have b1: "lo \<le> xsem x" and b2: "xsem x \<le> hi" using xint_sound[OF I] by auto
  have rs: "\<bar>dec_val d - xsem x\<bar> \<le> layout_err (layout_of f ((lo + hi) / 2)) (xsem x)"
    by (rule round_layout_sound[OF b1 b2 d])
  show ?thesis using s rs by blast
qed

definition stated_x :: "xexpr \<Rightarrow> String.literal option" where
  "stated_x x = render_x (GFix L4) x"

text \<open>A secondary number in a reply: the rendering, or a question mark when no
digits can be pinned down.\<close>
definition showx :: "gfmt \<Rightarrow> xexpr \<Rightarrow> String.literal" where
  "showx f x = (case render_x f x of Some s \<Rightarrow> s | None \<Rightarrow> STR ''?'')"

section \<open>Outcomes and replies\<close>

datatype decl = Under String.literal | Imposs String.literal | Ask String.literal | Range String.literal | Imprecise

datatype outcome = Value xexpr | Word String.literal | Note | Decline decl

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition need_text :: "String.literal \<Rightarrow> String.literal" where
  "need_text w = STR ''I need '' + w + STR '' to work that out; I won'' + apos + STR ''t assume it.''"

definition imprecise_text :: String.literal where
  "imprecise_text = STR ''I could not pin that number down to the digits I state.''"

definition reply_val :: "gfmt \<Rightarrow> String.literal \<Rightarrow> (String.literal \<Rightarrow> String.literal) \<Rightarrow> xexpr \<Rightarrow> reply" where
  "reply_val f k txt x = (case render_x f x of
     None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
   | Some s \<Rightarrow> Reply True k (txt s) (stated_x x))"

theorem reply_val_states:
  assumes "answered (reply_val f k txt x)"
  shows "\<exists>s. render_x f x = Some s \<and> response (reply_val f k txt x) = txt s"
  using assms by (auto simp: reply_val_def split: option.splits)

definition reply_with :: "(xexpr \<Rightarrow> String.literal option) \<Rightarrow> String.literal \<Rightarrow>
    (String.literal \<Rightarrow> String.literal) \<Rightarrow> xexpr \<Rightarrow> reply" where
  "reply_with rd k txt x = (case rd x of
     None \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None
   | Some s \<Rightarrow> Reply True k (txt s) (stated_x x))"

theorem reply_with_states:
  assumes "answered (reply_with rd k txt x)"
  shows "\<exists>s. rd x = Some s \<and> response (reply_with rd k txt x) = txt s"
  using assms by (auto simp: reply_with_def split: option.splits)

definition decline_reply :: "String.literal \<Rightarrow> decl \<Rightarrow> reply" where
  "decline_reply k w = (case w of
     Under t \<Rightarrow> Reply False (STR ''underspecified'') (need_text t) None
   | Imposs t \<Rightarrow> Reply False (STR ''impossible'') t None
   | Ask t \<Rightarrow> Reply False (STR ''underspecified'') t None
   | Range t \<Rightarrow> Reply False (STR ''out_of_range'') t None
   | Imprecise \<Rightarrow> Reply False (STR ''imprecise'') imprecise_text None)"

theorem decline_reply_withheld: "\<not> answered (decline_reply k w)"
  by (cases w) (simp_all add: decline_reply_def)

end
