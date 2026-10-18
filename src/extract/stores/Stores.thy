theory Stores
  imports "Veri7vn_Stores_Base.Stores_Base" "HOL.Real"
begin

text \<open>
  Six shipped Oracle7 specialists that read a store, as one HOL kernel:

  \<^item> cooking, cooking-v2, cooking-v3, cooking-v3-r2
    (upstream/root/specialists/cooking*/organ_nutrition_v*.py,
    organ_cooking_v3_r2.py): nutrients per portion from USDA SR Legacy
    (nutrition_v1.sqlite3);
  \<^item> warehouse, warehouse-r2 (organ_site_v2.py, organ_site_v3.py): a site's
    stock, bins, sensors and reorder proposals (site_fresh.sqlite3), with
    per-conversation state.

  The kernel is the DECISION over rows that an untrusted shim fetched from the
  store (lane F's pattern, src/isabelle/reader): which food, which nutrient row,
  whether the readings in play disagree, which household portion, the grams
  and the stated number; for the site, the stock count, the run-out days, the
  freshness of a reading, the low-stock list and the session state machine
  (propose, confirm, cancel). Every fetch carries the shim's claim that it
  returned every stored row it asked for; the kernel declines when that claim
  is absent. Reading English (which food the words name, which item or zone)
  is the untrusted recognizer's job (recognizer.sml).
\<close>

section \<open>Shared: first minimum, exact decimals, text\<close>

fun first_min :: "('a \<Rightarrow> 'k::linorder) \<Rightarrow> 'a list \<Rightarrow> 'a option" where
  "first_min f [] = None"
| "first_min f (x # xs) = (case first_min f xs of
     None \<Rightarrow> Some x
   | Some y \<Rightarrow> if f x \<le> f y then Some x else Some y)"

lemma first_min_None [simp]: "first_min f xs = None \<longleftrightarrow> xs = []"
  by (induction xs) (auto split: option.splits)

text \<open>The first element with the least key: it is in the list and no element
has a smaller key (SQL's ORDER BY key LIMIT 1 over rows in store order).\<close>
lemma first_min_Some:
  "first_min f xs = Some y \<Longrightarrow> y \<in> set xs \<and> (\<forall>z\<in>set xs. f y \<le> f z)"
proof (induction xs arbitrary: y)
  case Nil
  then show ?case by simp
next
  case (Cons x xs)
  show ?case
  proof (cases "first_min f xs")
    case None
    then have "xs = []" by simp
    then show ?thesis using Cons.prems by simp
  next
    case (Some y')
    then have ih: "y' \<in> set xs" "\<forall>z\<in>set xs. f y' \<le> f z" using Cons.IH by auto
    show ?thesis
    proof (cases "f x \<le> f y'")
      case True
      then have yx: "y = x" using Cons.prems Some by simp
      have "\<forall>z\<in>set xs. f x \<le> f z" using True ih(2) by (blast intro: order_trans)
      then show ?thesis using yx by simp
    next
      case False
      then have yy: "y = y'" using Cons.prems Some by simp
      have "f y' \<le> f x" using False by (meson linear)
      then show ?thesis using yy ih by simp
    qed
  qed
qed

text \<open>The tie rule: SQL's ORDER BY key LIMIT 1 keeps the first row in store
order among equals. The chosen row has a strictly larger key at every earlier
row and a key no larger at every later row, so it is the unique first minimum.\<close>
theorem first_min_tie_first:
  "first_min f xs = Some y \<Longrightarrow>
     \<exists>pre post. xs = pre @ y # post \<and> (\<forall>z\<in>set pre. f y < f z) \<and> (\<forall>z\<in>set post. f y \<le> f z)"
proof (induction xs arbitrary: y)
  case Nil then show ?case by simp
next
  case (Cons x xs)
  show ?case
  proof (cases "first_min f xs")
    case None
    then have "xs = []" by simp
    then show ?thesis using Cons.prems by (auto intro!: exI[of _ "[]"] exI[of _ "[]"])
  next
    case (Some y')
    show ?thesis
    proof (cases "f x \<le> f y'")
      case True
      then have yx: "y = x" using Cons.prems Some by simp
      have all: "\<forall>z\<in>set xs. f x \<le> f z" using True first_min_Some[OF Some] by (blast intro: order_trans)
      then show ?thesis using yx all by (intro exI[of _ "[]"] exI[of _ xs]) simp
    next
      case False
      then have yy: "y = y'" using Cons.prems Some by simp
      obtain pre post where d: "xs = pre @ y' # post" "\<forall>z\<in>set pre. f y' < f z" "\<forall>z\<in>set post. f y' \<le> f z"
        using Cons.IH[OF Some] by blast
      have "f y' < f x" using False by simp
      then show ?thesis using yy d \<open>f y' < f x\<close> by (intro exI[of _ "x # pre"] exI[of _ post] conjI) auto
    qed
  qed
qed

definition pow10 :: "nat \<Rightarrow> rat" where "pow10 k = of_nat (10 ^ k)"

lemma pow10_pos [simp]: "0 < pow10 k"
  by (simp add: pow10_def)

lemma pow10_nz [simp]: "pow10 k \<noteq> 0"
  using pow10_pos[of k] by linarith

lemma set_mapf: "set (List.map_filter f xs) = {y. \<exists>x\<in>set xs. f x = Some y}"
  by (induction xs) (auto split: option.splits)

text \<open>A value rounded to @{text k} decimals (an exact tie rounds up).\<close>
definition round_dp :: "nat \<Rightarrow> rat \<Rightarrow> int" where
  "round_dp k q = \<lfloor>q * pow10 k + 1 / 2\<rfloor>"

lemma half_bound:
  fixes a x p :: rat
  assumes p: "0 < p" and e: "\<bar>a - x\<bar> \<le> 1 / 2"
  shows "\<bar>a / p - x / p\<bar> \<le> 1 / (2 * p)"
proof -
  have "\<bar>a / p - x / p\<bar> = \<bar>a - x\<bar> / p"
    using p by (simp add: diff_divide_distrib[symmetric] abs_divide)
  also have "\<dots> \<le> (1 / 2) / p" using divide_right_mono[OF e, of p] p by simp
  also have "\<dots> = 1 / (2 * p)" by simp
  finally show ?thesis .
qed

theorem round_dp_sound:
  "\<bar>of_int (round_dp k q) / pow10 k - q\<bar> \<le> 1 / (2 * pow10 k)"
proof -
  let ?x = "q * pow10 k + 1 / 2"
  have c: "of_int \<lfloor>?x\<rfloor> \<le> ?x \<and> ?x < of_int \<lfloor>?x\<rfloor> + 1" using floor_correct[of ?x] by simp
  have e: "\<bar>of_int (round_dp k q) - q * pow10 k\<bar> \<le> 1 / 2"
    using c unfolding round_dp_def abs_le_iff by linarith
  have "\<bar>of_int (round_dp k q) / pow10 k - (q * pow10 k) / pow10 k\<bar> \<le> 1 / (2 * pow10 k)"
    by (rule half_bound[OF pow10_pos e])
  then show ?thesis by simp
qed

text \<open>Python's round() and @{text "%.0f"}: a tie goes to the even neighbour.\<close>
definition round_even :: "rat \<Rightarrow> int" where
  "round_even q = (let f = \<lfloor>q\<rfloor>; r = q - of_int f in
     if r < 1 / 2 then f else if 1 / 2 < r then f + 1 else if even f then f else f + 1)"

text \<open>Text (ASCII). digits, digit_lit, lit, strip_zeros, pad2 and render_dec
are copied from lane G (src/extract/quantity/Quantity.thy, Python's
@{text "%.pg"} layout for @{text "m * 10^e"}).\<close>

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

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

definition show_nat :: "nat \<Rightarrow> String.literal" where
  "show_nat n = lit (digits n)"

text \<open>Python's @{text "%.kf"} layout of @{text "m / 10^k"}.\<close>
definition render_fixed :: "nat \<Rightarrow> int \<Rightarrow> String.literal" where
  "render_fixed k m = (if k = 0 then show_int m else
     let a = nat \<bar>m\<bar>; ip = a div 10 ^ k; fp = digits (a mod 10 ^ k) in
     (if m < 0 then STR ''-'' else STR '''') + lit (digits ip) + STR ''.''
       + lit (replicate (k - length fp) 0 @ fp))"

definition pow10i :: "int \<Rightarrow> rat" where
  "pow10i e = (if 0 \<le> e then of_nat (10 ^ nat e) else 1 / of_nat (10 ^ nat (- e)))"

fun exp_up :: "nat \<Rightarrow> rat \<Rightarrow> int \<Rightarrow> int" where
  "exp_up 0 q x = x"
| "exp_up (Suc n) q x = (if pow10i (x + 1) \<le> q then exp_up n q (x + 1) else x)"

fun exp_dn :: "nat \<Rightarrow> rat \<Rightarrow> int \<Rightarrow> int" where
  "exp_dn 0 q x = x"
| "exp_dn (Suc n) q x = (if q < pow10i x then exp_dn n q (x - 1) else x)"

text \<open>Six significant digits, as Python's @{text "%g"} gives (an exact tie
rounds up; Python rounds the binary float).\<close>
definition sig6 :: "rat \<Rightarrow> int \<times> int" where
  "sig6 q = (if q = 0 then (0, 0) else
     let a = \<bar>q\<bar>; x = exp_dn 400 a (exp_up 400 a 0); e = x - 5;
         m = \<lfloor>a / pow10i e + 1 / 2\<rfloor>;
         (m, e) = (if 1000000 \<le> m then (m div 10, e + 1) else (m, e)) in
     (if q < 0 then - m else m, e))"

definition show_g :: "rat \<Rightarrow> String.literal" where
  "show_g q = render_dec 6 (sig6 q)"

definition apos :: String.literal where "apos = String.implode [CHR 0x27]"
definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition lowc :: "char \<Rightarrow> char" where
  "lowc c = (let n = (of_char c :: nat) in if 65 \<le> n \<and> n \<le> 90 then char_of (n + 32) else c)"

definition upc :: "char \<Rightarrow> char" where
  "upc c = (let n = (of_char c :: nat) in if 97 \<le> n \<and> n \<le> 122 then char_of (n - 32) else c)"

definition lowl :: "String.literal \<Rightarrow> char list" where
  "lowl s = map lowc (String.explode s)"

definition lower :: "String.literal \<Rightarrow> String.literal" where
  "lower s = String.implode (lowl s)"

definition cap :: "String.literal \<Rightarrow> String.literal" where
  "cap s = (case String.explode s of [] \<Rightarrow> s | c # cs \<Rightarrow> String.implode (upc c # cs))"

definition starts :: "char list \<Rightarrow> char list \<Rightarrow> bool" where
  "starts p s \<longleftrightarrow> take (length p) s = p"

definition contains :: "char list \<Rightarrow> char list \<Rightarrow> bool" where
  "contains p s \<longleftrightarrow> list_ex (\<lambda>i. take (length p) (drop i s) = p) [0..<Suc (length s)]"

definition slen :: "String.literal \<Rightarrow> nat" where
  "slen s = length (String.explode s)"

fun join :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join sep [] = STR ''''"
| "join sep [x] = x"
| "join sep (x # xs) = x + sep + join sep xs"

text \<open>The family reply: status (answered, withheld or clarify), the organ's
kind, the response text, and the stated value when there is one.\<close>
datatype reply = Reply (answered: bool) (reply_status: String.literal) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")


section \<open>Nutrition (cooking, cooking-v2, cooking-v3, cooking-v3-r2)\<close>

subsection \<open>Tables (checked against the organ and the store by tables_check.py)\<close>

datatype nutrient = N_saturated_fat | N_calories | N_protein | N_fat | N_carbohydrate | N_fiber
  | N_sugar | N_sodium | N_calcium | N_iron | N_vitamin_c | N_potassium | N_cholesterol

text \<open>The organ's NUTRIENTS list, in its order (the asked nutrient is the first
one mentioned; ties go to the smaller key).\<close>
definition nutrient_order :: "nutrient list" where
  "nutrient_order = [N_saturated_fat, N_calories, N_protein, N_fat, N_carbohydrate, N_fiber,
     N_sugar, N_sodium, N_calcium, N_iron, N_vitamin_c, N_potassium, N_cholesterol]"

fun nutrient_key :: "nutrient \<Rightarrow> String.literal" where
  "nutrient_key N_saturated_fat = STR ''saturated fat''"
| "nutrient_key N_calories = STR ''calories''"
| "nutrient_key N_protein = STR ''protein''"
| "nutrient_key N_fat = STR ''fat''"
| "nutrient_key N_carbohydrate = STR ''carbohydrate''"
| "nutrient_key N_fiber = STR ''fiber''"
| "nutrient_key N_sugar = STR ''sugar''"
| "nutrient_key N_sodium = STR ''sodium''"
| "nutrient_key N_calcium = STR ''calcium''"
| "nutrient_key N_iron = STR ''iron''"
| "nutrient_key N_vitamin_c = STR ''vitamin c''"
| "nutrient_key N_potassium = STR ''potassium''"
| "nutrient_key N_cholesterol = STR ''cholesterol''"

text \<open>The store's unit for each key (build_nutrition_store_v1.py KEYS).\<close>
fun nutrient_unit :: "nutrient \<Rightarrow> String.literal" where
  "nutrient_unit N_saturated_fat = STR ''g''"
| "nutrient_unit N_calories = STR ''kcal''"
| "nutrient_unit N_protein = STR ''g''"
| "nutrient_unit N_fat = STR ''g''"
| "nutrient_unit N_carbohydrate = STR ''g''"
| "nutrient_unit N_fiber = STR ''g''"
| "nutrient_unit N_sugar = STR ''g''"
| "nutrient_unit N_sodium = STR ''mg''"
| "nutrient_unit N_calcium = STR ''mg''"
| "nutrient_unit N_iron = STR ''mg''"
| "nutrient_unit N_vitamin_c = STR ''mg''"
| "nutrient_unit N_potassium = STR ''mg''"
| "nutrient_unit N_cholesterol = STR ''mg''"

datatype mass_unit = MU_g | MU_kg | MU_oz | MU_lb

fun grams_per :: "mass_unit \<Rightarrow> rat" where
  "grams_per MU_g = 1"
| "grams_per MU_kg = 1000"
| "grams_per MU_oz = 283495 / 10000"
| "grams_per MU_lb = 453592 / 1000"

text \<open>The organ's MASS dictionary, in its order.\<close>
definition mass_names :: "(String.literal \<times> mass_unit) list" where
  "mass_names = [(STR ''g'', MU_g), (STR ''gram'', MU_g), (STR ''grams'', MU_g),
     (STR ''kg'', MU_kg), (STR ''kilogram'', MU_kg), (STR ''kilograms'', MU_kg),
     (STR ''oz'', MU_oz), (STR ''ounce'', MU_oz), (STR ''ounces'', MU_oz),
     (STR ''lb'', MU_lb), (STR ''lbs'', MU_lb), (STR ''pound'', MU_lb), (STR ''pounds'', MU_lb)]"

theorem grams_pos: "0 < grams_per u"
  by (cases u) simp_all

datatype measure = M_cup | M_tbsp | M_tsp

fun measure_key :: "measure \<Rightarrow> String.literal" where
  "measure_key M_cup = STR ''cup''"
| "measure_key M_tbsp = STR ''tbsp''"
| "measure_key M_tsp = STR ''tsp''"

text \<open>The organ's MEASURE dictionary, in its order.\<close>
definition measure_names :: "(String.literal \<times> measure) list" where
  "measure_names = [(STR ''cup'', M_cup), (STR ''cups'', M_cup), (STR ''tbsp'', M_tbsp),
     (STR ''tablespoon'', M_tbsp), (STR ''tablespoons'', M_tbsp), (STR ''tsp'', M_tsp),
     (STR ''teaspoon'', M_tsp), (STR ''teaspoons'', M_tsp)]"

subsection \<open>Requests and fetched rows\<close>

text \<open>The amount the question asks about, as the recognizer read it: none
(USDA's 100 g), a mass, a household measure, or a count of the food. The
words as written are kept for the reply text.\<close>
datatype amount =
    A_default
  | A_mass rat String.literal mass_unit
  | A_measure rat String.literal String.literal measure
  | A_count rat String.literal String.literal

text \<open>A nutrition query: the asked nutrient and amount, the food words, the
recognizer's food reading (fdc id and description) and the readings still in
play (the organ's near list, which includes the reading itself); then the
fetched rows: every stored nutrient row of the asked nutrient for those foods
(fdc id, amount per 100 g, unit) and every stored portion row of the food
(label, grams) in store order; and the shim's completeness claim.\<close>
datatype nquery = NQ
  (nq_nutrient: nutrient) (nq_amount: amount) (nq_phrase: String.literal)
  (nq_hit: "(int \<times> String.literal) option") (nq_near: "(int \<times> String.literal) list")
  (nq_rows: "(int \<times> rat \<times> String.literal) list") (nq_portions: "(String.literal \<times> rat) list")
  (nq_complete: bool)

datatype ndecline = ND_unknown_food | ND_no_value | ND_clarify | ND_no_portion | ND_incomplete

text \<open>An answer: grams of food, amount per 100 g, the value, and the household
portion used (if any).\<close>
datatype noutcome = NAnswer rat rat rat "String.literal option" | NDecline ndecline

definition row_of :: "(int \<times> rat \<times> String.literal) list \<Rightarrow> int \<Rightarrow> (rat \<times> String.literal) option" where
  "row_of rows f = map_of rows f"

lemma row_of_Some: "row_of rows f = Some r \<Longrightarrow> (f, r) \<in> set rows"
  by (auto simp: row_of_def dest: map_of_SomeD)

text \<open>The fetched rows are well formed and agree with the query they answer,
checked here and not taken from the shim: no negative amount, the store's unit
is the nutrient's unit, at most one row per food, every row is for a food the
query named (the reading or one in play), the reading is among those in play,
and every stored portion weighs something. What the kernel cannot see is a
row the shim left out; that part stays the shim's claim (@{text nq_complete}).\<close>
definition rows_ok :: "nquery \<Rightarrow> bool" where
  "rows_ok e \<longleftrightarrow> (\<forall>r\<in>set (nq_rows e). 0 \<le> fst (snd r) \<and> snd (snd r) = nutrient_unit (nq_nutrient e))
     \<and> distinct (map fst (nq_rows e))
     \<and> (\<forall>r\<in>set (nq_rows e). fst r \<in> set (map fst (nq_near e)))
     \<and> (case nq_hit e of None \<Rightarrow> True | Some fd \<Rightarrow> fd \<in> set (nq_near e))
     \<and> (\<forall>p\<in>set (nq_portions e). 0 < snd p)"

text \<open>The values of the readings in play that have a row (with their
descriptions).\<close>
definition near_vals :: "nquery \<Rightarrow> (rat \<times> String.literal) list" where
  "near_vals e = List.map_filter (\<lambda>fd. map_option (\<lambda>r. (fst r, snd fd)) (row_of (nq_rows e) (fst fd))) (nq_near e)"

fun lmax :: "rat list \<Rightarrow> rat" where
  "lmax [] = 0"
| "lmax (x # xs) = fold max xs x"

fun lmin :: "rat list \<Rightarrow> rat" where
  "lmin [] = 0"
| "lmin (x # xs) = fold min xs x"

lemma fold_max_ge: "y \<in> set (a # xs) \<Longrightarrow> y \<le> fold max xs (a :: rat)"
proof (induction xs arbitrary: a y)
  case Nil
  then show ?case by simp
next
  case (Cons b bs)
  have m: "max b a \<le> fold max bs (max b a)" using Cons.IH[where a="max b a" and y="max b a"] by simp
  from Cons.prems consider "y = a" | "y = b" | "y \<in> set bs" by auto
  then show ?case
  proof cases
    case 1
    have "a \<le> max b a" by simp
    then have "a \<le> fold max bs (max b a)" using m by (rule order_trans)
    then show ?thesis using 1 by simp
  next
    case 2
    have "b \<le> max b a" by simp
    then have "b \<le> fold max bs (max b a)" using m by (rule order_trans)
    then show ?thesis using 2 by simp
  next
    case 3
    then show ?thesis using Cons.IH[where a="max b a" and y=y] by simp
  qed
qed

lemma fold_min_le: "y \<in> set (a # xs) \<Longrightarrow> fold min xs (a :: rat) \<le> y"
proof (induction xs arbitrary: a y)
  case Nil
  then show ?case by simp
next
  case (Cons b bs)
  have m: "fold min bs (min b a) \<le> min b a" using Cons.IH[where a="min b a" and y="min b a"] by simp
  from Cons.prems consider "y = a" | "y = b" | "y \<in> set bs" by auto
  then show ?case
  proof cases
    case 1
    have "min b a \<le> a" by simp
    with m have "fold min bs (min b a) \<le> a" by (rule order_trans)
    then show ?thesis using 1 by simp
  next
    case 2
    have "min b a \<le> b" by simp
    with m have "fold min bs (min b a) \<le> b" by (rule order_trans)
    then show ?thesis using 2 by simp
  next
    case 3
    then show ?thesis using Cons.IH[where a="min b a" and y=y] by simp
  qed
qed

lemma lmax_ge: "x \<in> set xs \<Longrightarrow> x \<le> lmax xs"
  by (cases xs) (auto intro: fold_max_ge)

lemma lmin_le: "x \<in> set xs \<Longrightarrow> lmin xs \<le> x"
  by (cases xs) (auto intro: fold_min_le)

text \<open>The readings in play disagree materially: the largest and smallest value
differ by more than 15% of the largest (the organ's SUPERPOSED rule; with one
value the spread is zero, so its @{text "len(vals) > 1"} guard is implied).\<close>
definition spread :: "rat list \<Rightarrow> bool" where
  "spread vs \<longleftrightarrow> 0 < lmax vs \<and> 15 / 100 < (lmax vs - lmin vs) / lmax vs"

definition like_measure :: "measure \<Rightarrow> String.literal \<Rightarrow> bool" where
  "like_measure m l \<longleftrightarrow> starts (''1 '' @ String.explode (measure_key m)) (lowl l)
     \<or> starts (''1.0 '' @ String.explode (measure_key m)) (lowl l)"

text \<open>SQL: label LIKE '1 cup%' OR label LIKE '1.0 cup%' ORDER BY length(label).\<close>
definition measure_portion :: "measure \<Rightarrow> (String.literal \<times> rat) list \<Rightarrow> (String.literal \<times> rat) option" where
  "measure_portion m ps = first_min (\<lambda>p. slen (fst p)) (filter (\<lambda>p. like_measure m (fst p)) ps)"

text \<open>A per-item weight: not a cup, tbsp, tsp, oz or ml measure.\<close>
definition count_ok :: "String.literal \<Rightarrow> bool" where
  "count_ok l \<longleftrightarrow> \<not> (contains ''cup'' (lowl l) \<or> contains ''tbsp'' (lowl l) \<or> contains ''tsp'' (lowl l)
     \<or> contains ''oz'' (lowl l) \<or> contains ''ml'' (lowl l))"

text \<open>ORDER BY medium DESC, large DESC, whole DESC, (label LIKE '1 %') DESC, length(label).\<close>
definition count_key :: "String.literal \<Rightarrow> bool \<times> bool \<times> bool \<times> bool \<times> nat" where
  "count_key l = (\<not> contains ''medium'' (lowl l), \<not> contains ''large'' (lowl l),
     \<not> contains ''whole'' (lowl l), \<not> starts ''1 '' (lowl l), slen l)"

definition count_portion :: "(String.literal \<times> rat) list \<Rightarrow> (String.literal \<times> rat) option" where
  "count_portion ps = first_min (\<lambda>p. count_key (fst p)) (filter (\<lambda>p. count_ok (fst p)) ps)"

fun amount_grams :: "amount \<Rightarrow> (String.literal \<times> rat) list \<Rightarrow> (rat \<times> String.literal option) option" where
  "amount_grams A_default ps = Some (100, None)"
| "amount_grams (A_mass q w u) ps = Some (q * grams_per u, None)"
| "amount_grams (A_measure q nt ut m) ps = map_option (\<lambda>p. (q * snd p, Some (fst p))) (measure_portion m ps)"
| "amount_grams (A_count q nt w) ps = map_option (\<lambda>p. (q * snd p, Some (fst p))) (count_portion ps)"

subsection \<open>The decision\<close>

definition nkernel :: "nquery \<Rightarrow> noutcome" where
  "nkernel e = (if \<not> nq_complete e \<or> \<not> rows_ok e then NDecline ND_incomplete else
     case nq_hit e of
       None \<Rightarrow> NDecline ND_unknown_food
     | Some fd \<Rightarrow> (case row_of (nq_rows e) (fst fd) of
         None \<Rightarrow> NDecline ND_no_value
       | Some r \<Rightarrow>
           if spread (map fst (near_vals e)) then NDecline ND_clarify
           else (case amount_grams (nq_amount e) (nq_portions e) of
             None \<Rightarrow> NDecline ND_no_portion
           | Some (g, pl) \<Rightarrow> NAnswer g (fst r) (fst r * g / 100) pl)))"

subsection \<open>Theorems\<close>

text \<open>An answer is the stored amount per 100 g of the food read, scaled to the
grams asked: value = per100 * grams / 100; the fetch was complete; the
readings in play agree.\<close>
theorem nutrient_answer_sound:
  assumes "nkernel e = NAnswer g p v pl"
  shows "\<exists>f d. nq_hit e = Some (f, d) \<and> row_of (nq_rows e) f = Some (p, nutrient_unit (nq_nutrient e))
    \<and> amount_grams (nq_amount e) (nq_portions e) = Some (g, pl) \<and> v = p * g / 100
    \<and> nq_complete e \<and> \<not> spread (map fst (near_vals e))"
proof -
  have c: "nq_complete e" "rows_ok e" using assms by (auto simp: nkernel_def split: if_splits)
  obtain fd where h: "nq_hit e = Some fd"
    using assms c by (cases "nq_hit e") (auto simp: nkernel_def)
  obtain r where r: "row_of (nq_rows e) (fst fd) = Some r"
    using assms c h by (cases "row_of (nq_rows e) (fst fd)") (auto simp: nkernel_def)
  have ns: "\<not> spread (map fst (near_vals e))"
    using assms c h r by (auto simp: nkernel_def split: if_splits)
  have ag: "amount_grams (nq_amount e) (nq_portions e) = Some (g, pl)" and pv: "p = fst r" "v = fst r * g / 100"
    using assms c h r ns by (auto simp: nkernel_def split: option.splits prod.splits)
  have "snd r = nutrient_unit (nq_nutrient e)"
    using row_of_Some[OF r] c(2) by (auto simp: rows_ok_def)
  then have "r = (p, nutrient_unit (nq_nutrient e))" using pv by (cases r) simp
  then show ?thesis using h r ag pv c ns by (cases fd) auto
qed

theorem nutrient_requires_complete: "nkernel e = NAnswer g p v pl \<Longrightarrow> nq_complete e"
  using nutrient_answer_sound by blast

text \<open>An answer rests on rows the kernel itself found consistent with the
query: one row per food, all for foods in play, the reading among them, and the
reading's own row present.\<close>
theorem nutrient_answer_covered:
  assumes "nkernel e = NAnswer g p v pl"
  shows "distinct (map fst (nq_rows e)) \<and> (\<forall>r\<in>set (nq_rows e). fst r \<in> set (map fst (nq_near e)))
    \<and> (\<exists>fd. nq_hit e = Some fd \<and> fd \<in> set (nq_near e) \<and> (fst fd, p, nutrient_unit (nq_nutrient e)) \<in> set (nq_rows e))"
proof -
  have ok: "rows_ok e" using assms by (auto simp: nkernel_def split: if_splits)
  obtain f d where h: "nq_hit e = Some (f, d)" and r: "row_of (nq_rows e) f = Some (p, nutrient_unit (nq_nutrient e))"
    using nutrient_answer_sound[OF assms] by blast
  have "(f, p, nutrient_unit (nq_nutrient e)) \<in> set (nq_rows e)" using row_of_Some[OF r] by simp
  moreover have "(f, d) \<in> set (nq_near e)" using ok h by (auto simp: rows_ok_def)
  ultimately show ?thesis using ok h by (auto simp: rows_ok_def)
qed

theorem nutrient_value: "nkernel e = NAnswer g p v pl \<Longrightarrow> v = p * g / 100"
  using nutrient_answer_sound by blast

theorem nutrient_default_grams:
  "nq_amount e = A_default \<Longrightarrow> nkernel e = NAnswer g p v pl \<Longrightarrow> g = 100 \<and> pl = None"
  using nutrient_answer_sound[of e g p v pl] by auto

theorem nutrient_mass_grams:
  "nq_amount e = A_mass q w u \<Longrightarrow> nkernel e = NAnswer g p v pl \<Longrightarrow> g = q * grams_per u \<and> v = p * q * grams_per u / 100"
  using nutrient_answer_sound[of e g p v pl] by auto

lemma measure_portion_Some:
  assumes "measure_portion m ps = Some (l, w)"
  shows "(l, w) \<in> set ps \<and> like_measure m l \<and> (\<forall>x\<in>set ps. like_measure m (fst x) \<longrightarrow> slen l \<le> slen (fst x))"
  using first_min_Some[OF assms[unfolded measure_portion_def]] by auto

lemma count_portion_Some:
  assumes "count_portion ps = Some (l, w)"
  shows "(l, w) \<in> set ps \<and> count_ok l \<and> (\<forall>x\<in>set ps. count_ok (fst x) \<longrightarrow> count_key l \<le> count_key (fst x))"
  using first_min_Some[OF assms[unfolded count_portion_def]] by auto

text \<open>A household measure is converted with a stored portion of that measure
(label "1 cup..." or "1.0 cup..."), the shortest such label.\<close>
theorem nutrient_measure_portion:
  assumes "nq_amount e = A_measure q nt ut m" "nkernel e = NAnswer g p v pl"
  shows "\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> like_measure m l \<and> g = q * w
    \<and> (\<forall>x\<in>set (nq_portions e). like_measure m (fst x) \<longrightarrow> slen l \<le> slen (fst x))"
proof -
  have "amount_grams (nq_amount e) (nq_portions e) = Some (g, pl)"
    using nutrient_answer_sound[OF assms(2)] by blast
  then obtain l w where "measure_portion m (nq_portions e) = Some (l, w)" "g = q * w" "pl = Some l"
    using assms(1) by auto
  then show ?thesis using measure_portion_Some by blast
qed

text \<open>A count of the food uses a stored per-item weight (not a cup, spoon, oz or
ml measure), preferring medium, then large, then whole, then a "1 ..." label,
then the shortest.\<close>
theorem nutrient_count_portion:
  assumes "nq_amount e = A_count q nt w0" "nkernel e = NAnswer g p v pl"
  shows "\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> count_ok l \<and> g = q * w
    \<and> (\<forall>x\<in>set (nq_portions e). count_ok (fst x) \<longrightarrow> count_key l \<le> count_key (fst x))"
proof -
  have "amount_grams (nq_amount e) (nq_portions e) = Some (g, pl)"
    using nutrient_answer_sound[OF assms(2)] by blast
  then obtain l w where "count_portion (nq_portions e) = Some (l, w)" "g = q * w" "pl = Some l"
    using assms(1) by auto
  then show ?thesis using count_portion_Some by blast
qed

abbreviation realq :: "rat \<Rightarrow> real" where "realq \<equiv> of_rat"

lemma realq_scale:
  assumes h: "v = p * (q * w) / 100" shows "realq v = realq p * realq q * realq w / 100"
proof -
  have "realq v = realq (p * (q * w) / 100)" by (simp only: h)
  also have "\<dots> = realq p * realq q * realq w / 100" by (simp add: of_rat_mult of_rat_divide mult.assoc)
  finally show ?thesis .
qed

text \<open>The stated value against the real-number model: with the portion row used,
the answer is (per 100 g) x quantity x (grams of the portion) / 100 as real
numbers, and for a mass it is the mass in grams (positive units) scaled the
same way.\<close>
theorem nutrient_portion_real:
  assumes "nkernel e = NAnswer g p v pl"
  shows "(\<forall>q nt ut m. nq_amount e = A_measure q nt ut m \<longrightarrow>
      (\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> 0 < w \<and>
        realq v = realq p * realq q * realq w / 100))
    \<and> (\<forall>q nt w0. nq_amount e = A_count q nt w0 \<longrightarrow>
      (\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> 0 < w \<and>
        realq v = realq p * realq q * realq w / 100))
    \<and> (\<forall>q nt u. nq_amount e = A_mass q nt u \<longrightarrow>
        realq v = realq p * realq q * realq (grams_per u) / 100)"
proof (intro conjI allI impI)
  fix q nt ut m assume a: "nq_amount e = A_measure q nt ut m"
  from nutrient_measure_portion[OF a assms] obtain l w where lw: "pl = Some l" "(l, w) \<in> set (nq_portions e)" "g = q * w" by blast
  have ok: "rows_ok e" using assms by (auto simp: nkernel_def split: if_splits)
  then have "0 < w" using lw(2) by (auto simp: rows_ok_def)
  moreover have "v = p * g / 100" using nutrient_value[OF assms] .
  ultimately show "\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> 0 < w \<and> realq v = realq p * realq q * realq w / 100"
    using lw realq_scale[of v p q w] by (intro exI[of _ l] exI[of _ w]) auto
next
  fix q nt w0 assume a: "nq_amount e = A_count q nt w0"
  from nutrient_count_portion[OF a assms] obtain l w where lw: "pl = Some l" "(l, w) \<in> set (nq_portions e)" "g = q * w" by blast
  have ok: "rows_ok e" using assms by (auto simp: nkernel_def split: if_splits)
  then have "0 < w" using lw(2) by (auto simp: rows_ok_def)
  moreover have "v = p * g / 100" using nutrient_value[OF assms] .
  ultimately show "\<exists>l w. pl = Some l \<and> (l, w) \<in> set (nq_portions e) \<and> 0 < w \<and> realq v = realq p * realq q * realq w / 100"
    using lw realq_scale[of v p q w] by (intro exI[of _ l] exI[of _ w]) auto
next
  fix q nt u assume a: "nq_amount e = A_mass q nt u"
  from nutrient_mass_grams[OF a assms] have "v = p * (q * grams_per u) / 100" by (simp add: mult.assoc)
  from realq_scale[OF this] show "realq v = realq p * realq q * realq (grams_per u) / 100" .
qed

text \<open>When it answers, any two readings in play differ by at most 15% of the
largest: it never picks silently among readings that disagree.\<close>
theorem nutrient_readings_agree:
  assumes a: "nkernel e = NAnswer g p v pl"
    and x: "x \<in> set (map fst (near_vals e))" and y: "y \<in> set (map fst (near_vals e))"
  shows "x - y \<le> 15 / 100 * lmax (map fst (near_vals e))"
proof -
  let ?vs = "map fst (near_vals e)"
  have ns: "\<not> spread ?vs" using nutrient_answer_sound[OF a] by blast
  have ok: "rows_ok e" using a by (auto simp: nkernel_def split: if_splits)
  have nonneg: "\<forall>z\<in>set ?vs. 0 \<le> z"
  proof
    fix z assume "z \<in> set ?vs"
    then obtain fd r where "fd \<in> set (nq_near e)" "row_of (nq_rows e) (fst fd) = Some r" "z = fst r"
      by (auto simp: near_vals_def set_mapf)
    then have "(fst fd, r) \<in> set (nq_rows e)" "z = fst r" by (auto dest: row_of_Some)
    then show "0 \<le> z" using ok by (auto simp: rows_ok_def)
  qed
  have xh: "x \<le> lmax ?vs" using x by (rule lmax_ge)
  have yl: "lmin ?vs \<le> y" using y by (rule lmin_le)
  show ?thesis
  proof (cases "0 < lmax ?vs")
    case True
    then have "(lmax ?vs - lmin ?vs) / lmax ?vs \<le> 15 / 100" using ns by (auto simp: spread_def)
    then have "lmax ?vs - lmin ?vs \<le> 15 / 100 * lmax ?vs" using True by (simp add: divide_le_eq)
    then show ?thesis using xh yl by linarith
  next
    case False
    have y0: "0 \<le> y" using nonneg y by blast
    have yh: "y \<le> lmax ?vs" using y by (rule lmax_ge)
    show ?thesis using False xh y0 yh by linarith
  qed
qed

theorem nutrient_unknown_food:
  "nkernel e = NDecline ND_unknown_food \<longleftrightarrow> nq_complete e \<and> rows_ok e \<and> nq_hit e = None"
  by (auto simp: nkernel_def split: option.splits prod.splits if_splits)

theorem nutrient_no_value:
  "nkernel e = NDecline ND_no_value \<longleftrightarrow>
     nq_complete e \<and> rows_ok e \<and> (\<exists>fd. nq_hit e = Some fd \<and> row_of (nq_rows e) (fst fd) = None)"
  by (auto simp: nkernel_def split: option.splits prod.splits if_splits)

theorem nutrient_clarify:
  "nkernel e = NDecline ND_clarify \<longleftrightarrow>
     nq_complete e \<and> rows_ok e \<and> (\<exists>fd r. nq_hit e = Some fd \<and> row_of (nq_rows e) (fst fd) = Some r)
     \<and> spread (map fst (near_vals e))"
  by (auto simp: nkernel_def split: option.splits prod.splits if_splits)

theorem nutrient_no_portion:
  "nkernel e = NDecline ND_no_portion \<longleftrightarrow>
     nq_complete e \<and> rows_ok e \<and> (\<exists>fd r. nq_hit e = Some fd \<and> row_of (nq_rows e) (fst fd) = Some r)
     \<and> \<not> spread (map fst (near_vals e)) \<and> amount_grams (nq_amount e) (nq_portions e) = None"
  by (auto simp: nkernel_def split: option.splits prod.splits if_splits)

text \<open>No portion exactly when no stored portion row fits the measure (or, for
a count, no per-item row exists); a mass or no amount always has grams.\<close>
theorem amount_grams_none:
  "amount_grams a ps = None \<longleftrightarrow>
     (\<exists>q nt ut m. a = A_measure q nt ut m \<and> (\<forall>x\<in>set ps. \<not> like_measure m (fst x)))
     \<or> (\<exists>q nt w. a = A_count q nt w \<and> (\<forall>x\<in>set ps. \<not> count_ok (fst x)))"
  by (cases a) (auto simp: measure_portion_def count_portion_def filter_empty_conv)

theorem nutrient_incomplete:
  "nkernel e = NDecline ND_incomplete \<longleftrightarrow> \<not> nq_complete e \<or> \<not> rows_ok e"
  by (auto simp: nkernel_def split: option.splits prod.splits if_splits)

subsection \<open>The stated number\<close>

text \<open>The organ prints kcal and mg values of 10 or more as whole numbers, other
values of 1 or more with one decimal, smaller ones with two.\<close>
definition dp_of :: "String.literal \<Rightarrow> rat \<Rightarrow> nat" where
  "dp_of u v = (if (u = STR ''kcal'' \<or> u = STR ''mg'') \<and> 10 \<le> v then 0 else if 1 \<le> v then 1 else 2)"

definition stated_num :: "String.literal \<Rightarrow> rat \<Rightarrow> rat" where
  "stated_num u v = of_int (round_dp (dp_of u v) v) / pow10 (dp_of u v)"

text \<open>The stated number is within the cooking scorer's tolerance of the
value: 5% of it, or 0.15 absolute.\<close>
theorem stated_within_tolerance:
  "\<bar>stated_num u v - v\<bar> \<le> max (v / 20) (15 / 100)"
proof -
  define d where "d = dp_of u v"
  define er where "er = stated_num u v - v"
  have b: "\<bar>er\<bar> \<le> 1 / (2 * pow10 d)"
    unfolding er_def stated_num_def d_def by (rule round_dp_sound)
  have "d = 0 \<and> 10 \<le> v \<or> d = 1 \<or> d = 2"
    unfolding d_def dp_of_def by auto
  then consider "d = 0" "10 \<le> v" | "d = 1" | "d = 2" by blast
  then show ?thesis
  proof cases
    case 1
    then have "\<bar>er\<bar> \<le> 1 / 2" using b by (simp add: pow10_def)
    then have "\<bar>er\<bar> \<le> v / 20" using 1 by linarith
    then show ?thesis by (simp add: er_def le_max_iff_disj)
  next
    case 2
    then have "\<bar>er\<bar> \<le> 1 / 20" using b by (simp add: pow10_def)
    then have "\<bar>er\<bar> \<le> 15 / 100" by linarith
    then show ?thesis by (simp add: er_def le_max_iff_disj)
  next
    case 3
    then have "\<bar>er\<bar> \<le> 1 / 200" using b by (simp add: pow10_def)
    then have "\<bar>er\<bar> \<le> 15 / 100" by linarith
    then show ?thesis by (simp add: er_def le_max_iff_disj)
  qed
qed

subsection \<open>Reply text (the organ's wording, ASCII: x for the multiplication sign)\<close>

definition shown :: "String.literal \<Rightarrow> rat \<Rightarrow> String.literal" where
  "shown u v = render_fixed (dp_of u v) (round_dp (dp_of u v) v)"

definition strip_one :: "String.literal \<Rightarrow> String.literal" where
  "strip_one l = (let cs = String.explode l in
     if starts ''1 '' cs then String.implode (drop 2 cs)
     else if starts ''1.0 '' cs then String.implode (drop 4 cs) else l)"

definition what_text :: "nutrient \<Rightarrow> rat \<Rightarrow> String.literal" where
  "what_text n v = (if n = N_calories then shown (nutrient_unit n) v + STR '' kcal''
     else shown (nutrient_unit n) v + STR '' '' + nutrient_unit n + STR '' of '' + nutrient_key n)"

definition source_text :: "int \<Rightarrow> String.literal \<Rightarrow> rat \<Rightarrow> nutrient \<Rightarrow> String.literal" where
  "source_text f d p n = STR '' (USDA SR Legacy #'' + show_int f + STR '': '' + d + STR ''; ''
     + show_g p + STR '' '' + nutrient_unit n + STR '' per 100 g).''"

definition opts_text :: "nquery \<Rightarrow> String.literal" where
  "opts_text e = join (STR ''; '') (take 3 (sort_key slen (remdups (map snd (near_vals e)))))"

definition nreply :: "nquery \<Rightarrow> reply" where
  "nreply e = (let n = nq_nutrient e; ph = nq_phrase e; k = nutrient_key n;
                   d = (case nq_hit e of Some fd \<Rightarrow> snd fd | None \<Rightarrow> STR ''''); f = (case nq_hit e of Some fd \<Rightarrow> fst fd | None \<Rightarrow> 0) in
     case nkernel e of
       NAnswer g p v pl \<Rightarrow>
         let st = Some (render_fixed (dp_of (nutrient_unit n) v) (round_dp (dp_of (nutrient_unit n) v) v)) in
         (case nq_amount e of
            A_count q nt w \<Rightarrow> Reply True (STR ''answered'') (STR ''nutrient'')
              (nt + STR '' '' + w + STR '' ('' + show_g q + STR '' x ''
                 + strip_one (case pl of Some l \<Rightarrow> l | None \<Rightarrow> STR '''') + STR '', '' + show_g g
                 + STR '' g total) has '' + what_text n v + source_text f d p n) st
          | A_measure q nt ut m \<Rightarrow> Reply True (STR ''answered'') (STR ''nutrient'')
              (nt + STR '' '' + ut + STR '' ('' + show_g g + STR '' g) of ''
                 + (if ph = STR '''' then d else lower ph) + STR '' has '' + what_text n v + source_text f d p n) st
          | A_mass q w u \<Rightarrow> Reply True (STR ''answered'') (STR ''nutrient'')
              (show_g q + STR '' '' + w + STR '' of ''
                 + (if ph = STR '''' then d else lower ph) + STR '' has '' + what_text n v + source_text f d p n) st
          | A_default \<Rightarrow> Reply True (STR ''answered'') (STR ''nutrient'')
              (STR ''100 g of '' + (if ph = STR '''' then d else lower ph) + STR '' has '' + what_text n v
                 + source_text f d p n) st)
     | NDecline ND_unknown_food \<Rightarrow> Reply False (STR ''withheld'') (STR ''unknown_food'')
         (STR ''I don'' + apos + STR ''t have a USDA entry for '' + dq + (if ph = STR '''' then STR ''that'' else ph)
           + dq + STR '', so I can'' + apos + STR ''t give you its '' + k + STR ''.'') None
     | NDecline ND_no_value \<Rightarrow> Reply False (STR ''withheld'') (STR ''no_value'')
         (STR ''USDA'' + apos + STR ''s entry '' + dq + d + dq + STR '' has no '' + k
           + STR '' value, so I won'' + apos + STR ''t estimate one.'') None
     | NDecline ND_clarify \<Rightarrow> Reply False (STR ''clarify'') (STR ''clarify'')
         (STR ''USDA has several entries that fit '' + dq + lower ph + dq + STR '', and their '' + k
           + STR '' differs by more than 15%: '' + opts_text e + STR ''. Which one do you mean?'') None
     | NDecline ND_no_portion \<Rightarrow> (case nq_amount e of
         A_measure q nt ut m \<Rightarrow> Reply False (STR ''withheld'') (STR ''no_portion'')
           (STR ''USDA gives no '' + measure_key m + STR '' weight for '' + dq + d + dq + STR '', so I can'' + apos
             + STR ''t convert '' + nt + STR '' '' + ut + STR ''. Ask me in grams instead.'') None
       | _ \<Rightarrow> Reply False (STR ''withheld'') (STR ''no_portion'')
           (STR ''USDA gives no per-item weight for '' + dq + d + dq + STR '', so I can'' + apos
             + STR ''t count them. Ask me in grams instead.'') None)
     | NDecline ND_incomplete \<Rightarrow> Reply False (STR ''withheld'') (STR ''incomplete'')
         (STR ''The store fetch did not claim every row, so I won'' + apos + STR ''t answer.'') None)"

theorem nreply_answered_iff: "answered (nreply e) \<longleftrightarrow> (\<exists>g p v pl. nkernel e = NAnswer g p v pl)"
  by (auto simp: nreply_def Let_def split: noutcome.splits ndecline.splits amount.splits)

theorem nreply_states:
  "nkernel e = NAnswer g p v pl \<Longrightarrow>
     stated (nreply e) = Some (render_fixed (dp_of (nutrient_unit (nq_nutrient e)) v)
                                 (round_dp (dp_of (nutrient_unit (nq_nutrient e)) v) v))"
  by (auto simp: nreply_def Let_def split: amount.splits)


section \<open>The site (warehouse, warehouse-r2)\<close>

subsection \<open>Tables\<close>

datatype skind = SK_temperature | SK_humidity | SK_light | SK_co2 | SK_occupancy

text \<open>The organ's KIND_WORDS, in its order.\<close>
definition skind_order :: "skind list" where
  "skind_order = [SK_temperature, SK_humidity, SK_light, SK_co2, SK_occupancy]"

fun skind_key :: "skind \<Rightarrow> String.literal" where
  "skind_key SK_temperature = STR ''temperature''"
| "skind_key SK_humidity = STR ''humidity''"
| "skind_key SK_light = STR ''light''"
| "skind_key SK_co2 = STR ''co2''"
| "skind_key SK_occupancy = STR ''occupancy''"

definition skind_label :: "skind \<Rightarrow> String.literal" where
  "skind_label k = (if k = SK_co2 then STR ''CO2'' else skind_key k)"

text \<open>The organ's _unit table.\<close>
definition unit_suffixes :: "(String.literal \<times> String.literal) list" where
  "unit_suffixes = [(STR ''C'', STR '' C''), (STR ''%'', STR ''%''), (STR ''lux'', STR '' lux''),
     (STR ''ppm'', STR '' ppm''), (STR ''people'', STR '' people'')]"

definition unit_suffix :: "String.literal \<Rightarrow> String.literal" where
  "unit_suffix u = (case map_of unit_suffixes u of Some s \<Rightarrow> s | None \<Rightarrow> STR '' '' + u)"

subsection \<open>Session state, intents and fetched rows\<close>

type_synonym item = "String.literal \<times> String.literal"   \<comment> \<open>sku, name\<close>
type_synonym zone = "int \<times> String.literal"             \<comment> \<open>zone id, name\<close>
type_synonym sensor = "String.literal \<times> rat \<times> rat"     \<comment> \<open>unit, normal low, normal high\<close>

datatype slast = SL_none | SL_item | SL_sensor | SL_zone_status

text \<open>One conversation's memory: a pending reorder proposal (quantity, item)
and what was last spoken about.\<close>
datatype sstate = SState (s_pending: "(nat \<times> item) option") (s_item: "item option")
  (s_zone: "zone option") (s_kind: "skind option") (s_last: slast)

definition s0 :: sstate where "s0 = SState None None None None SL_none"

text \<open>What the recognizer read the turn to ask, after resolving pronouns,
follow-ups and ellipsis against the session (untrusted).\<close>
datatype rintent =
    R_self | R_neighbour | R_reorder nat "item option" String.literal | R_low
  | R_where item | R_runout item | R_stock item
  | R_zone_status zone | R_sensor zone skind bool
  | R_unknown_item String.literal | R_kind_only skind | R_off_site | R_none

text \<open>A yes or no is a confirmation only when a proposal is pending; otherwise
the turn is read as the fallback.\<close>
datatype intent = I_read rintent | I_confirm bool rintent

text \<open>Fetched rows. Times are seconds (the shim's ISO timestamps, parsed by the
untrusted driver); now and the freshness bound in minutes come from the
store's meta table.\<close>
datatype sev = SEv
  (ev_now: int) (ev_fresh: int)
  (ev_events: "(int \<times> int) list")     \<comment> \<open>every stock event of the item: time, delta\<close>
  (ev_reorder: int)                     \<comment> \<open>the item's reorder level\<close>
  (ev_bin: "(String.literal \<times> String.literal) option")   \<comment> \<open>the item's bin label and zone name\<close>
  (ev_next: "(String.literal \<times> (String.literal \<times> int list) list) option option")
     \<comment> \<open>for the neighbour: None = no bin after it; Some (label, items by name with their deltas)\<close>
  (ev_sensor: "(sensor \<times> (int \<times> rat) list) option")   \<comment> \<open>the zone's sensor of the kind and all its readings\<close>
  (ev_zone: "(skind \<times> sensor \<times> (int \<times> rat) list) list")  \<comment> \<open>every sensor of the zone with its readings\<close>
  (ev_items: "(String.literal \<times> int \<times> int list) list")   \<comment> \<open>every item: name, reorder level, deltas\<close>
  (ev_self: "nat \<times> nat \<times> nat \<times> String.literal list")
  (ev_where: "String.literal list")    \<comment> \<open>zones with a sensor of the kind, by zone id\<close>
  (ev_complete: bool)

datatype flag = F_stale skind rat | F_out skind

datatype soutcome =
    SO_stock String.literal int int
  | SO_where String.literal String.literal String.literal
  | SO_runout_unused String.literal int
  | SO_runout String.literal int rat int
  | SO_low "(String.literal \<times> int \<times> int) list"
  | SO_sensor String.literal skind String.literal rat rat rat rat bool
  | SO_stale String.literal skind rat
  | SO_missing_sensor String.literal skind
  | SO_zone_status String.literal "(skind \<times> rat \<times> String.literal) list" "flag list"
  | SO_neighbour_last String.literal String.literal
  | SO_neighbour String.literal String.literal String.literal "(String.literal \<times> int) list"
  | SO_self nat nat nat "String.literal list"
  | SO_confirm nat item int
  | SO_ordered nat item
  | SO_cancelled
  | SO_unknown_item String.literal bool
  | SO_clarify_zone skind "String.literal list"
  | SO_missing_kind skind
  | SO_off_site
  | SO_not_taken
  | SO_incomplete

subsection \<open>Computations\<close>

definition stock_count :: "(int \<times> int) list \<Rightarrow> int" where
  "stock_count evs = sum_list (map snd evs)"

text \<open>Units picked in the seven days before now.\<close>
definition used7 :: "int \<Rightarrow> (int \<times> int) list \<Rightarrow> int" where
  "used7 now evs = - sum_list (map snd (filter (\<lambda>x. snd x < 0 \<and> now - 7 * 86400 \<le> fst x) evs))"

definition age_min :: "int \<Rightarrow> int \<Rightarrow> rat" where
  "age_min now ts = of_int (now - ts) / 60"

definition stale :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> bool" where
  "stale now fresh ts \<longleftrightarrow> of_int fresh < age_min now ts"

theorem stale_mono: "stale now fresh ts \<Longrightarrow> now \<le> now' \<Longrightarrow> stale now' fresh ts"
proof -
  assume s: "stale now fresh ts" and le: "now \<le> now'"
  have "age_min now ts \<le> age_min now' ts" using le by (simp add: age_min_def divide_right_mono)
  then show ?thesis using s by (simp add: stale_def)
qed

text \<open>The latest reading (SQL: ORDER BY ts DESC LIMIT 1).\<close>
definition latest :: "(int \<times> rat) list \<Rightarrow> (int \<times> rat) option" where
  "latest rs = first_min (\<lambda>r. - fst r) rs"

definition in_range :: "sensor \<Rightarrow> rat \<Rightarrow> bool" where
  "in_range sn v \<longleftrightarrow> fst (snd sn) \<le> v \<and> v \<le> snd (snd sn)"

definition zone_sorted :: "(skind \<times> sensor \<times> (int \<times> rat) list) list \<Rightarrow> (skind \<times> sensor \<times> (int \<times> rat) list) list" where
  "zone_sorted zs = sort_key (\<lambda>z. skind_key (fst z)) zs"

text \<open>The zone's live readings, by kind name: a stale reading is never reported.\<close>
definition part_of :: "int \<Rightarrow> int \<Rightarrow> skind \<times> sensor \<times> (int \<times> rat) list \<Rightarrow> (skind \<times> rat \<times> String.literal) option" where
  "part_of now fresh z = (case latest (snd (snd z)) of
       None \<Rightarrow> None
     | Some r \<Rightarrow> if stale now fresh (fst r) then None else Some (fst z, snd r, fst (fst (snd z))))"

definition zone_parts :: "int \<Rightarrow> int \<Rightarrow> (skind \<times> sensor \<times> (int \<times> rat) list) list \<Rightarrow> (skind \<times> rat \<times> String.literal) list" where
  "zone_parts now fresh zs = List.map_filter (part_of now fresh) (zone_sorted zs)"

definition flag_of :: "int \<Rightarrow> int \<Rightarrow> skind \<times> sensor \<times> (int \<times> rat) list \<Rightarrow> flag option" where
  "flag_of now fresh z = (case latest (snd (snd z)) of
       None \<Rightarrow> None
     | Some r \<Rightarrow> if stale now fresh (fst r) then Some (F_stale (fst z) (age_min now (fst r)))
                 else if in_range (fst (snd z)) (snd r) then None else Some (F_out (fst z)))"

definition zone_flags :: "int \<Rightarrow> int \<Rightarrow> (skind \<times> sensor \<times> (int \<times> rat) list) list \<Rightarrow> flag list" where
  "zone_flags now fresh zs = List.map_filter (flag_of now fresh) (zone_sorted zs)"

definition low_of :: "String.literal \<times> int \<times> int list \<Rightarrow> (String.literal \<times> int \<times> int) option" where
  "low_of x = (let c = sum_list (snd (snd x)) in if c \<le> fst (snd x) then Some (fst x, c, fst (snd x)) else None)"

definition low_rows :: "(String.literal \<times> int \<times> int list) list \<Rightarrow> (String.literal \<times> int \<times> int) list" where
  "low_rows its = sort_key fst (List.map_filter low_of its)"

definition with_item :: "sstate \<Rightarrow> item \<Rightarrow> sstate" where
  "with_item s it = SState (s_pending s) (Some it) None None SL_item"

definition with_zone :: "sstate \<Rightarrow> zone \<Rightarrow> skind option \<Rightarrow> sstate" where
  "with_zone s z k = SState (s_pending s) None (Some z) k (if k = None then SL_zone_status else SL_sensor)"

definition with_kind :: "sstate \<Rightarrow> skind \<Rightarrow> sstate" where
  "with_kind s k = SState (s_pending s) None None (Some k) (s_last s)"

definition with_pending :: "sstate \<Rightarrow> (nat \<times> item) option \<Rightarrow> sstate" where
  "with_pending s p = SState p (s_item s) (s_zone s) (s_kind s) (s_last s)"

definition sensor_out :: "sev \<Rightarrow> zone \<Rightarrow> skind \<Rightarrow> bool \<Rightarrow> soutcome" where
  "sensor_out ev z k rng = (case ev_sensor ev of
       None \<Rightarrow> SO_missing_sensor (snd z) k
     | Some (sn, rs) \<Rightarrow> (case latest rs of
         None \<Rightarrow> SO_incomplete
       | Some (ts, v) \<Rightarrow>
           if stale (ev_now ev) (ev_fresh ev) ts then SO_stale (snd z) k (age_min (ev_now ev) ts)
           else SO_sensor (snd z) k (fst sn) v (fst (snd sn)) (snd (snd sn)) (age_min (ev_now ev) ts) rng))"

definition runout_out :: "sev \<Rightarrow> item \<Rightarrow> soutcome" where
  "runout_out ev it = (let c = stock_count (ev_events ev); u = used7 (ev_now ev) (ev_events ev) in
     if u \<le> 0 then SO_runout_unused (snd it) c
     else SO_runout (snd it) c (of_int u / 7) \<lfloor>of_int c / (of_int u / 7 :: rat)\<rfloor>)"

text \<open>One reading turn (no confirmation): the outcome and the new session state.\<close>
fun sread :: "sstate \<Rightarrow> rintent \<Rightarrow> sev \<Rightarrow> soutcome \<times> sstate" where
  "sread s R_self ev = (case ev_self ev of (a, b, c, ks) \<Rightarrow> (SO_self a b c ks, s))"
| "sread s R_neighbour ev = (case s_item s of
       None \<Rightarrow> (SO_not_taken, s)
     | Some it \<Rightarrow> (case ev_bin ev of
         None \<Rightarrow> (SO_incomplete, s)
       | Some (lb, zn) \<Rightarrow> (case ev_next ev of
           None \<Rightarrow> (SO_neighbour_last lb zn, s)
         | Some None \<Rightarrow> (SO_neighbour_last lb zn, s)
         | Some (Some (nb, its)) \<Rightarrow> (SO_neighbour nb lb zn (map (\<lambda>x. (fst x, sum_list (snd x))) its), s))))"
| "sread s (R_reorder n None w) ev = (SO_unknown_item w True, s)"
| "sread s (R_reorder n (Some it) w) ev =
     (SO_confirm n it (stock_count (ev_events ev)), with_pending s (Some (n, it)))"
| "sread s R_low ev = (SO_low (low_rows (ev_items ev)), s)"
| "sread s (R_where it) ev = (case ev_bin ev of
       None \<Rightarrow> (SO_incomplete, with_item s it)
     | Some (lb, zn) \<Rightarrow> (SO_where (snd it) lb zn, with_item s it))"
| "sread s (R_runout it) ev = (runout_out ev it, with_item s it)"
| "sread s (R_stock it) ev = (SO_stock (snd it) (stock_count (ev_events ev)) (ev_reorder ev), with_item s it)"
| "sread s (R_zone_status z) ev =
     (SO_zone_status (snd z) (zone_parts (ev_now ev) (ev_fresh ev) (ev_zone ev))
        (zone_flags (ev_now ev) (ev_fresh ev) (ev_zone ev)), with_zone s z None)"
| "sread s (R_sensor z k rng) ev = (sensor_out ev z k rng, with_zone s z (Some k))"
| "sread s (R_unknown_item w) ev = (SO_unknown_item w False, s)"
| "sread s (R_kind_only k) ev =
     (if ev_where ev = [] then SO_missing_kind k else SO_clarify_zone k (ev_where ev), with_kind s k)"
| "sread s R_off_site ev = (SO_off_site, s)"
| "sread s R_none ev = (SO_not_taken, s)"

text \<open>One turn. An incomplete fetch is declined and leaves the state alone.\<close>
fun sstep :: "sstate \<Rightarrow> intent \<Rightarrow> sev \<Rightarrow> soutcome \<times> sstate" where
  "sstep s (I_confirm yes r) ev = (case s_pending s of
       None \<Rightarrow> (if ev_complete ev then sread s r ev else (SO_incomplete, s))
     | Some (n, it) \<Rightarrow> (if yes then SO_ordered n it else SO_cancelled, with_pending s None))"
| "sstep s (I_read r) ev = (if ev_complete ev then sread s r ev else (SO_incomplete, s))"

subsection \<open>Theorems: the state machine\<close>

lemma sread_not_ordered: "fst (sread s r ev) \<noteq> SO_ordered n it"
  by (cases "(s, r, ev)" rule: sread.cases)
    (auto simp: runout_out_def sensor_out_def Let_def split: option.splits prod.splits)

lemma sread_not_cancelled: "fst (sread s r ev) \<noteq> SO_cancelled"
  by (cases "(s, r, ev)" rule: sread.cases)
    (auto simp: runout_out_def sensor_out_def Let_def split: option.splits prod.splits)

text \<open>An order is logged only on a confirmation of the pending proposal, for
exactly the proposed quantity and item.\<close>
theorem confirm_requires_proposal:
  "fst (sstep s i ev) = SO_ordered n it \<Longrightarrow> s_pending s = Some (n, it) \<and> (\<exists>r. i = I_confirm True r)"
  by (cases i) (auto simp: sread_not_ordered split: option.splits prod.splits if_splits)

theorem confirm_without_proposal_refused:
  "s_pending s = None \<Longrightarrow> fst (sstep s i ev) \<noteq> SO_ordered n it \<and> fst (sstep s i ev) \<noteq> SO_cancelled"
  by (cases i) (auto simp: sread_not_ordered sread_not_cancelled)

text \<open>A yes or no answers the pending proposal once: it is consumed, so a
second yes cannot place a second order.\<close>
theorem confirm_consumes:
  "s_pending s = Some (n, it) \<Longrightarrow>
     sstep s (I_confirm yes r) ev = (if yes then SO_ordered n it else SO_cancelled, with_pending s None)
     \<and> s_pending (snd (sstep s (I_confirm yes r) ev)) = None"
  by (simp add: with_pending_def)

theorem no_double_order:
  "s_pending s = Some p \<Longrightarrow> fst (sstep (snd (sstep s (I_confirm yes r) ev)) (I_confirm yes' r') ev') \<noteq> SO_ordered n it"
  by (cases p) (auto simp: with_pending_def sread_not_ordered)

text \<open>A reorder of a known item proposes, and does nothing else: it sets the
pending proposal, quotes the current count, and places no order.\<close>
theorem propose_sets_pending:
  "ev_complete ev \<Longrightarrow> sstep s (I_read (R_reorder n (Some it) w)) ev =
     (SO_confirm n it (stock_count (ev_events ev)), with_pending s (Some (n, it)))"
  by simp

text \<open>Proposals are idempotent per session: repeating the same proposal gives
the same reply and the same state.\<close>
theorem propose_idempotent:
  "sstep (snd (sstep s (I_read (R_reorder n x w)) ev)) (I_read (R_reorder n x w)) ev = sstep s (I_read (R_reorder n x w)) ev"
  by (cases x) (auto simp: with_pending_def)

text \<open>A turn that is not a confirmation never touches a pending proposal,
except a new proposal, which replaces it.\<close>
theorem reading_keeps_proposal:
  "(\<forall>n x w. r \<noteq> R_reorder n x w) \<Longrightarrow> s_pending (snd (sstep s (I_read r) ev)) = s_pending s"
  by (cases "(s, r, ev)" rule: sread.cases)
    (auto simp: with_item_def with_zone_def with_kind_def split: option.splits prod.splits)

theorem incomplete_fetch_declines:
  "\<not> ev_complete ev \<Longrightarrow> sstep s (I_read r) ev = (SO_incomplete, s)"
  by simp

subsection \<open>Theorems: freshness and the stated values\<close>

lemma latest_Some: "latest rs = Some (ts, v) \<Longrightarrow> (ts, v) \<in> set rs \<and> (\<forall>x\<in>set rs. fst x \<le> ts)"
  using first_min_Some[of "\<lambda>r. - fst r" rs "(ts, v)"] by (auto simp: latest_def)

lemma sstep_from_read:
  "fst (sstep s i ev) = o' \<Longrightarrow> o' = SO_incomplete \<or> (\<exists>n it. o' = SO_ordered n it) \<or> o' = SO_cancelled
     \<or> (ev_complete ev \<and> (\<exists>r. fst (sread s r ev) = o'))"
  by (cases i) (auto split: option.splits prod.splits if_splits)

lemma sread_sensor:
  "fst (sread s r ev) = SO_sensor zn k u v lo hi a rng \<Longrightarrow> \<exists>z k' b. sensor_out ev z k' b = SO_sensor zn k u v lo hi a rng"
  by (cases "(s, r, ev)" rule: sread.cases) (auto simp: runout_out_def Let_def split: option.splits prod.splits if_splits)

lemma sread_stock:
  "fst (sread s r ev) = SO_stock nm c rl \<Longrightarrow> c = stock_count (ev_events ev) \<and> rl = ev_reorder ev"
  by (cases "(s, r, ev)" rule: sread.cases)
    (auto simp: runout_out_def sensor_out_def Let_def split: option.splits prod.splits if_splits)

lemma sread_runout:
  "fst (sread s r ev) = SO_runout nm c rate d \<Longrightarrow> \<exists>it. runout_out ev it = SO_runout nm c rate d"
  by (cases "(s, r, ev)" rule: sread.cases) (auto simp: sensor_out_def split: option.splits prod.splits if_splits)

text \<open>A sensor value is reported only from the zone sensor's latest reading,
and only when that reading is no older than the freshness bound.\<close>
theorem sensor_fresh:
  assumes "fst (sstep s i ev) = SO_sensor zn k u v lo hi a rng"
  shows "\<exists>sn rs ts. ev_sensor ev = Some (sn, rs) \<and> latest rs = Some (ts, v) \<and> (ts, v) \<in> set rs
    \<and> (\<forall>x\<in>set rs. fst x \<le> ts) \<and> a = age_min (ev_now ev) ts \<and> a \<le> of_int (ev_fresh ev)
    \<and> sn = (u, lo, hi) \<and> ev_complete ev"
proof -
  from sstep_from_read[OF assms] obtain r where c: "ev_complete ev"
    and rd: "fst (sread s r ev) = SO_sensor zn k u v lo hi a rng" by auto
  from sread_sensor[OF rd] obtain z k' b where so: "sensor_out ev z k' b = SO_sensor zn k u v lo hi a rng"
    by blast
  then obtain sn rs ts v' where e: "ev_sensor ev = Some (sn, rs)" "latest rs = Some (ts, v')"
    and ns: "\<not> stale (ev_now ev) (ev_fresh ev) ts"
    by (auto simp: sensor_out_def split: option.splits prod.splits if_splits)
  then have q: "v' = v" "a = age_min (ev_now ev) ts" "fst sn = u" "fst (snd sn) = lo" "snd (snd sn) = hi"
    using so by (auto simp: sensor_out_def)
  have "sn = (u, lo, hi)" using q(3-5) by (cases sn rule: prod_cases3) auto
  moreover have "a \<le> of_int (ev_fresh ev)" using ns q(2) by (simp add: stale_def not_less)
  ultimately show ?thesis using e c latest_Some[OF e(2)] q(1,2)
    by (auto intro!: exI[of _ sn] exI[of _ rs] exI[of _ ts])
qed

text \<open>A stale latest reading is declined, never reported as current.\<close>
theorem stale_declines:
  assumes "ev_complete ev" "ev_sensor ev = Some (sn, rs)" "latest rs = Some (ts, v)"
    "of_int (ev_fresh ev) < age_min (ev_now ev) ts"
  shows "fst (sstep s (I_read (R_sensor z k rng)) ev) = SO_stale (snd z) k (age_min (ev_now ev) ts)"
  using assms by (simp add: sensor_out_def stale_def)

text \<open>A zone report lists only fresh latest readings of the zone's sensors.\<close>
theorem zone_parts_fresh:
  assumes "(k, v, u) \<in> set (zone_parts now fresh zs)"
  shows "\<exists>sn rs ts. (k, sn, rs) \<in> set zs \<and> latest rs = Some (ts, v) \<and> \<not> stale now fresh ts \<and> fst sn = u"
proof -
  obtain z where z: "z \<in> set zs" "part_of now fresh z = Some (k, v, u)"
    using assms by (auto simp: zone_parts_def zone_sorted_def set_mapf)
  obtain a sn rs where zz: "z = (a, sn, rs)" by (cases z rule: prod_cases3)
  show ?thesis
  proof (cases "latest rs")
    case None
    then show ?thesis using z zz by (simp add: part_of_def)
  next
    case (Some r)
    obtain ts w where r: "r = (ts, w)" by (cases r)
    then have "(k, sn, rs) \<in> set zs \<and> latest rs = Some (ts, v) \<and> \<not> stale now fresh ts \<and> fst sn = u"
      using z zz Some by (auto simp: part_of_def split: if_splits)
    then show ?thesis by blast
  qed
qed

theorem stock_value:
  assumes "fst (sstep s i ev) = SO_stock nm c rl"
  shows "c = sum_list (map snd (ev_events ev)) \<and> rl = ev_reorder ev"
proof -
  from sstep_from_read[OF assms] obtain r where "fst (sread s r ev) = SO_stock nm c rl" by auto
  then have "c = stock_count (ev_events ev) \<and> rl = ev_reorder ev" by (rule sread_stock)
  then show ?thesis by (simp add: stock_count_def)
qed

text \<open>Run-out: the rate is the units picked in the last seven days over seven,
and the days are the whole number of days the count lasts at that rate.\<close>
theorem runout_days:
  assumes "fst (sstep s i ev) = SO_runout nm c rate d"
  shows "c = stock_count (ev_events ev) \<and> rate = of_int (used7 (ev_now ev) (ev_events ev)) / 7 \<and> 0 < rate
     \<and> of_int d \<le> of_int c / rate \<and> of_int c / rate < of_int d + 1"
proof -
  from sstep_from_read[OF assms] obtain r where "fst (sread s r ev) = SO_runout nm c rate d" by auto
  then obtain it where ro: "runout_out ev it = SO_runout nm c rate d" using sread_runout by blast
  then have u: "0 < used7 (ev_now ev) (ev_events ev)" and v: "c = stock_count (ev_events ev)"
    "rate = of_int (used7 (ev_now ev) (ev_events ev)) / 7" "d = \<lfloor>of_int c / rate\<rfloor>"
    by (auto simp: runout_out_def Let_def split: if_splits)
  have r0: "0 < rate" using u by (simp add: v(2) zero_less_divide_iff)
  have fl: "of_int d \<le> of_int c / rate \<and> of_int c / rate < of_int d + 1"
    using floor_correct[of "of_int c / rate"] v(3) by simp
  show ?thesis using v(1,2) r0 fl by blast
qed

text \<open>The low-stock list is exactly the items at or below their reorder level,
by name.\<close>
theorem low_exact:
  "set (low_rows its) = {(nm, sum_list ds, rl) | nm rl ds. (nm, rl, ds) \<in> set its \<and> sum_list ds \<le> rl}"
proof (rule set_eqI)
  fix x
  show "x \<in> set (low_rows its) \<longleftrightarrow> x \<in> {(nm, sum_list ds, rl) | nm rl ds. (nm, rl, ds) \<in> set its \<and> sum_list ds \<le> rl}"
  proof
    assume "x \<in> set (low_rows its)"
    then obtain y where y: "y \<in> set its" "low_of y = Some x"
      by (auto simp: low_rows_def set_mapf)
    then show "x \<in> {(nm, sum_list ds, rl) | nm rl ds. (nm, rl, ds) \<in> set its \<and> sum_list ds \<le> rl}"
      by (cases y rule: prod_cases3) (auto simp: low_of_def Let_def split: if_splits)
  next
    assume "x \<in> {(nm, sum_list ds, rl) | nm rl ds. (nm, rl, ds) \<in> set its \<and> sum_list ds \<le> rl}"
    then obtain nm rl ds where x: "x = (nm, sum_list ds, rl)" "(nm, rl, ds) \<in> set its" "sum_list ds \<le> rl"
      by blast
    have "low_of (nm, rl, ds) = Some x" using x by (simp add: low_of_def)
    then show "x \<in> set (low_rows its)" using x(2) unfolding low_rows_def set_sort set_mapf by blast
  qed
qed

theorem low_sorted: "sorted (map fst (low_rows its))"
  by (simp add: low_rows_def)

subsection \<open>Reply text (the organ's wording)\<close>

definition age_text :: "rat \<Rightarrow> String.literal" where
  "age_text m = (if m < 3 / 2 then STR ''just now''
     else if m < 90 then show_int (round_even m) + STR '' minutes ago''
     else show_int (round_even (m / 60)) + STR '' hours ago'')"

definition range_text :: "rat \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> rat \<Rightarrow> String.literal" where
  "range_text lo hi u v = (let rng = show_g lo + STR ''-'' + show_g hi + unit_suffix u in
     if lo \<le> v \<and> v \<le> hi then STR ''within its normal '' + rng
     else if hi < v then STR ''above its normal '' + rng else STR ''below its normal '' + rng)"

definition flag_text :: "int \<Rightarrow> flag \<Rightarrow> String.literal" where
  "flag_text now f = (case f of F_stale k a \<Rightarrow> skind_label k + STR '' sensor stale ('' + age_text a + STR '')''
     | F_out k \<Rightarrow> skind_label k + STR '' out of range'')"

definition unknown_text :: "String.literal \<Rightarrow> bool \<Rightarrow> String.literal" where
  "unknown_text w ro = STR ''I don'' + apos + STR ''t have anything called '' + dq + w + dq + STR '' in this site''
     + apos + (if ro then STR ''s records, so I can'' + apos + STR ''t reorder it.''
               else STR ''s records, so I can'' + apos + STR ''t give you a count or a location for it.'')"

definition ans :: "String.literal \<Rightarrow> String.literal \<Rightarrow> String.literal option \<Rightarrow> reply" where
  "ans k t v = Reply True (STR ''answered'') k t v"

definition wh :: "String.literal \<Rightarrow> String.literal \<Rightarrow> reply" where
  "wh k t = Reply False (STR ''withheld'') k t None"

fun sreply :: "soutcome \<Rightarrow> reply" where
  "sreply (SO_stock nm c rl) = ans (STR ''stock'') (STR ''We have '' + show_int c + STR '' '' + nm + STR ''.''
     + (if c \<le> rl then STR '' That'' + apos + STR ''s at or below its reorder level of '' + show_int rl + STR ''.'' else STR ''''))
     (Some (show_int c))"
| "sreply (SO_where nm lb zn) = ans (STR ''where'') (STR ''The '' + nm + STR '' are in bin '' + lb + STR '', in '' + zn + STR ''.'')
     (Some (dq + lb + dq))"
| "sreply (SO_runout_unused nm c) = ans (STR ''runout'') (cap nm + STR '' aren'' + apos
     + STR ''t being used at the moment - none picked in the last 7 days - so at this rate they won'' + apos
     + STR ''t run out. We have '' + show_int c + STR ''.'') (Some (dq + STR ''not_used'' + dq))"
| "sreply (SO_runout nm c rate d) = ans (STR ''runout'') (STR ''At the last 7 days'' + apos + STR '' rate (''
     + render_fixed 1 (round_dp 1 rate) + STR '' a day) the '' + show_int c + STR '' '' + nm + STR '' last about ''
     + show_int d + STR '' days.'') (Some (show_int d))"
| "sreply (SO_low rs) = (if rs = [] then ans (STR ''low'') (STR ''Nothing is at or below its reorder level.'') None
     else ans (STR ''low'') (show_nat (length rs) + STR '' item'' + (if length rs = 1 then STR '''' else STR ''s are'')
       + STR '' at or below reorder level: ''
       + join (STR ''; '') (map (\<lambda>r. fst r + STR '' ('' + show_int (fst (snd r)) + STR '', reorder at ''
                                     + show_int (snd (snd r)) + STR '')'') rs) + STR ''.'') None)"
| "sreply (SO_sensor zn k u v lo hi a rng) = (if rng
     then ans (STR ''range'') ((if lo \<le> v \<and> v \<le> hi then STR ''Yes'' else STR ''No'') + STR ''. '' + zn + STR '' ''
       + skind_label k + STR '' is '' + show_g v + unit_suffix u + STR '', '' + range_text lo hi u v + STR '', read ''
       + age_text a + STR ''.'') (Some (dq + (if lo \<le> v \<and> v \<le> hi then STR ''yes'' else STR ''no'') + dq))
     else ans (STR ''sensor'') (zn + STR '' '' + skind_label k + STR '' is '' + show_g v + unit_suffix u + STR '', ''
       + range_text lo hi u v + STR '', read '' + age_text a + STR ''.'') (Some (show_g v)))"
| "sreply (SO_stale zn k a) = wh (STR ''stale'') (STR ''The '' + zn + STR '' '' + skind_label k + STR '' sensor'' + apos
     + STR ''s last reading is '' + age_text a + STR '', so I can'' + apos + STR ''t tell you the current ''
     + skind_label k + STR '' - the sensor may be offline.'')"
| "sreply (SO_missing_sensor zn k) = wh (STR ''missing_sensor'') (STR ''There'' + apos + STR ''s no '' + skind_label k
     + STR '' sensor in '' + zn + STR '', so I can'' + apos + STR ''t tell you the '' + skind_label k + STR '' there.'')"
| "sreply (SO_zone_status zn ps fs) = ans (STR ''zone_status'') (zn + STR '': ''
     + (if ps = [] then STR ''no live readings''
        else join (STR '', '') (map (\<lambda>p. skind_label (fst p) + STR '' '' + show_g (fst (snd p)) + unit_suffix (snd (snd p))) ps))
     + STR ''. '' + cap (if fs = [] then STR ''all readings in range'' else join (STR ''; '') (map (flag_text 0) fs)) + STR ''.'') None"
| "sreply (SO_neighbour_last lb zn) = ans (STR ''neighbour'') (lb + STR '' is the last bin in '' + zn
     + STR '' - there'' + apos + STR ''s nothing next to it on that side.'') None"
| "sreply (SO_neighbour nb lb zn its) = (if its = []
     then ans (STR ''neighbour'') (STR ''Bin '' + nb + STR '', next to '' + lb + STR '' in '' + zn + STR '', is empty.'') None
     else ans (STR ''neighbour'') (STR ''Bin '' + nb + STR '', next to '' + lb + STR '' in '' + zn + STR '', holds: ''
       + join (STR ''; '') (map (\<lambda>x. fst x + STR '' ('' + show_int (snd x) + STR '')'') its) + STR ''.'') None)"
| "sreply (SO_self a b c ks) = ans (STR ''self'') (STR ''I can see this site: '' + show_nat a + STR '' items across ''
     + show_nat b + STR '' zones, their stock movements, and '' + show_nat c + STR '' sensors ('' + join (STR '', '') ks
     + STR ''). I don'' + apos + STR ''t know anything beyond this site.'') None"
| "sreply (SO_confirm n it c) = ans (STR ''confirm'') (STR ''Reorder '' + show_nat n + STR '' '' + snd it
     + STR ''? We have '' + show_int c + STR '' now. Say yes to confirm or no to cancel.'') None"
| "sreply (SO_ordered n it) = ans (STR ''ordered'') (STR ''Done - I'' + apos + STR ''ve logged a request for ''
     + show_nat n + STR '' '' + snd it + STR ''. It'' + apos + STR ''s marked as requested until someone approves it.'') None"
| "sreply SO_cancelled = ans (STR ''cancelled'') (STR ''Cancelled - no order placed.'') None"
| "sreply (SO_unknown_item w ro) = wh (STR ''unknown_item'') (unknown_text w ro)"
| "sreply (SO_clarify_zone k zs) = Reply False (STR ''clarify'') (STR ''clarify'') (STR ''Which zone? I have ''
     + skind_label k + STR '' sensors in '' + join (STR '', '') zs + STR ''.'') None"
| "sreply (SO_missing_kind k) = wh (STR ''missing_sensor'') (STR ''There'' + apos + STR ''s no '' + skind_label k
     + STR '' sensor anywhere on this site.'')"
| "sreply SO_off_site = wh (STR ''off_site'') (STR ''That'' + apos + STR ''s outside what I can see. I only know this site - ''
     + STR ''its stock, its zones and its sensors - so I won'' + apos + STR ''t guess about anything else.'')"
| "sreply SO_not_taken = wh (STR '''') (STR '''')"
| "sreply SO_incomplete = wh (STR ''incomplete'') (STR ''The store fetch did not claim every row, so I won''
     + apos + STR ''t answer.'')"

text \<open>Whether the organ takes the turn at all (it returns None otherwise).\<close>
definition taken :: "soutcome \<Rightarrow> bool" where
  "taken o' \<longleftrightarrow> o' \<noteq> SO_not_taken"

theorem stale_not_answered: "\<not> answered (sreply (SO_stale zn k a))"
  by (simp add: wh_def)

theorem sensor_reply_states_value:
  "stated (sreply (SO_sensor zn k u v lo hi a False)) = Some (show_g v)"
  by (simp add: ans_def)

end
