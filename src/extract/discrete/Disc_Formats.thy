theory Disc_Formats
  imports Disc_Dtext
begin

text \<open>dataformats (upstream/root/specialists/dataformats): exact data-format
operations on byte lists (natural numbers below 256), so every answer keeps the
question's bytes exactly: number bases, base64, URL percent-encoding, JSON
validity, SHA-256/SHA-1/MD5 digests and the weekday of an ISO date. Base
conversion, base64 and percent-encoding are proved to invert each other. The
digests are executable specifications checked by known-answer vectors (not
proved against any other definition), and the JSON validator follows CPython's
scanner and is tested against it (not proved against RFC 8259).\<close>

section \<open>Number bases\<close>

function to_digits :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "to_digits b n = (if b < 2 \<or> n < b then [n] else to_digits b (n div b) @ [n mod b])"
  by pat_completeness auto
termination
proof (relation "measure (\<lambda>p. snd p)")
  show "wf (measure (\<lambda>p. snd p))" by simp
next
  fix b n :: nat
  assume c: "\<not> (b < 2 \<or> n < b)"
  have b1: "1 < b" and n0: "0 < n" using c by auto
  show "((b, n div b), (b, n)) \<in> measure (\<lambda>p. snd p)"
    using div_less_dividend[OF b1 n0] by simp
qed

declare to_digits.simps[simp del]

definition from_digits :: "nat \<Rightarrow> nat list \<Rightarrow> nat" where
  "from_digits b ds = foldl (\<lambda>a d. a * b + d) 0 ds"

lemma from_digits_append: "from_digits b (xs @ ys) = foldl (\<lambda>a d. a * b + d) (from_digits b xs) ys"
  by (simp add: from_digits_def)

lemma to_digits_step: "2 \<le> b \<Longrightarrow> b \<le> n \<Longrightarrow> to_digits b n = to_digits b (n div b) @ [n mod b]"
  by (simp add: to_digits.simps[of b n])

lemma to_digits_small: "n < b \<Longrightarrow> to_digits b n = [n]"
  by (simp add: to_digits.simps[of b n])

theorem from_to_digits: "2 \<le> b \<Longrightarrow> from_digits b (to_digits b n) = n"
proof (induction n rule: less_induct)
  case (less n)
  show ?case
  proof (cases "n < b")
    case True
    then show ?thesis by (simp add: to_digits_small from_digits_def)
  next
    case False
    have lt: "n div b < n" using less.prems False by (simp add: div_less_dividend)
    have ih: "from_digits b (to_digits b (n div b)) = n div b" using less.IH[OF lt] less.prems by simp
    show ?thesis using ih to_digits_step[OF less.prems] False
      by (simp add: from_digits_append)
  qed
qed

theorem to_digits_below: "2 \<le> b \<Longrightarrow> \<forall>d \<in> set (to_digits b n). d < b"
proof (induction n rule: less_induct)
  case (less n)
  show ?case
  proof (cases "n < b")
    case True
    then show ?thesis by (simp add: to_digits_small)
  next
    case False
    have lt: "n div b < n" using less.prems False by (simp add: div_less_dividend)
    have m: "n mod b < b" using less.prems by simp
    have bn: "b \<le> n" using False by simp
    have ih: "\<forall>d \<in> set (to_digits b (n div b)). d < b" by (rule less.IH[OF lt less.prems])
    show ?thesis by (subst to_digits_step[OF less.prems bn]) (simp add: ih m)
  qed
qed

definition dc :: "nat \<Rightarrow> nat" where
  "dc d = (if d < 10 then 48 + d else 87 + d)"

definition dv :: "nat \<Rightarrow> nat option" where
  "dv c = (if 48 \<le> c \<and> c \<le> 57 then Some (c - 48)
           else if 97 \<le> c \<and> c \<le> 102 then Some (c - 87) else None)"

lemma dv_dc: "d < 16 \<Longrightarrow> dv (dc d) = Some d"
  unfolding dv_def dc_def by auto

definition digits_val :: "nat \<Rightarrow> nat list \<Rightarrow> nat option" where
  "digits_val b cs = (if \<forall>c \<in> set cs. (case dv c of Some d \<Rightarrow> d < b | None \<Rightarrow> False)
      then Some (from_digits b (map (\<lambda>c. the (dv c)) cs)) else None)"

definition base_convert :: "nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "base_convert src dst cs = (case digits_val src cs of None \<Rightarrow> None
      | Some n \<Rightarrow> Some (map dc (to_digits dst n)))"

text \<open>The converted digits denote the same number in the target base.\<close>
lemma dvs: "\<forall>d \<in> set ds. d < 16 \<Longrightarrow> map (\<lambda>c. the (dv c)) (map dc ds) = ds"
  by (induction ds) (auto simp: dv_dc)

lemma dv_all: "\<forall>d \<in> set ds. d < b \<Longrightarrow> b \<le> 16 \<Longrightarrow>
    \<forall>c \<in> set (map dc ds). (case dv c of Some d \<Rightarrow> d < b | None \<Rightarrow> False)"
  by (auto simp: dv_dc)

text \<open>The converted digits denote the same number in the target base.\<close>
theorem base_convert_value:
  assumes "2 \<le> dst" "dst \<le> 16" "base_convert src dst cs = Some out"
  shows "digits_val dst out = digits_val src cs"
proof -
  obtain n where n: "digits_val src cs = Some n" and ov: "out = map dc (to_digits dst n)"
    using assms(3) by (auto simp: base_convert_def split: option.splits)
  have lt: "\<forall>d \<in> set (to_digits dst n). d < dst" by (rule to_digits_below[OF assms(1)])
  have lt16: "\<forall>d \<in> set (to_digits dst n). d < 16" using lt assms(2) by (metis order_less_le_trans)
  note back0 = dv_all[OF lt assms(2)]
  have dv1: "digits_val dst (map dc (to_digits dst n)) = Some (from_digits dst (to_digits dst n))"
    using back0 dvs[OF lt16] by (simp add: digits_val_def)
  have "digits_val dst out = Some (from_digits dst (to_digits dst n))" using dv1 ov by simp
  also have "\<dots> = Some n" using from_to_digits[OF assms(1), of n] by simp
  finally show ?thesis using n by simp
qed

section \<open>Base64\<close>

definition b64c :: "nat \<Rightarrow> nat" where
  "b64c i = (if i < 26 then 65 + i else if i < 52 then 71 + i else if i < 62 then i - 4
             else if i = 62 then 43 else 47)"

definition b64i :: "nat \<Rightarrow> nat option" where
  "b64i c = (if 65 \<le> c \<and> c \<le> 90 then Some (c - 65)
             else if 97 \<le> c \<and> c \<le> 122 then Some (c - 71)
             else if 48 \<le> c \<and> c \<le> 57 then Some (c + 4)
             else if c = 43 then Some 62 else if c = 47 then Some 63 else None)"

lemma b64i_b64c: "i < 64 \<Longrightarrow> b64i (b64c i) = Some i"
  unfolding b64i_def b64c_def by auto

fun b64_enc :: "nat list \<Rightarrow> nat list" where
  "b64_enc [] = []"
| "b64_enc [a] = [b64c (a div 4), b64c ((a mod 4) * 16), 61, 61]"
| "b64_enc [a, b] = [b64c (a div 4), b64c ((a mod 4) * 16 + b div 16), b64c ((b mod 16) * 4), 61]"
| "b64_enc (a # b # c # r) =
     [b64c (a div 4), b64c ((a mod 4) * 16 + b div 16), b64c ((b mod 16) * 4 + c div 64), b64c (c mod 64)]
     @ b64_enc r"

fun b64_dec :: "nat list \<Rightarrow> nat list option" where
  "b64_dec [] = Some []"
| "b64_dec [a, b, c, d] =
     (case (b64i a, b64i b) of
        (Some x, Some y) \<Rightarrow>
          (case (b64i c, b64i d) of
             (Some z, Some w) \<Rightarrow> Some [x * 4 + y div 16, (y mod 16) * 16 + z div 4, (z mod 4) * 64 + w]
           | (Some z, None) \<Rightarrow> if d = 61 then Some [x * 4 + y div 16, (y mod 16) * 16 + z div 4] else None
           | (None, _) \<Rightarrow> if c = 61 \<and> d = 61 then Some [x * 4 + y div 16] else None)
      | _ \<Rightarrow> None)"
| "b64_dec (a # b # c # d # r) =
     (case (b64i a, b64i b, b64i c, b64i d, b64_dec r) of
        (Some x, Some y, Some z, Some w, Some rest) \<Rightarrow>
          Some ([x * 4 + y div 16, (y mod 16) * 16 + z div 4, (z mod 4) * 64 + w] @ rest)
      | _ \<Rightarrow> None)"
| "b64_dec _ = None"

lemma b64i_pad: "b64i 61 = None" by (simp add: b64i_def)

lemma H1: "(p::nat) < 16 \<Longrightarrow> (s * 16 + p) div 16 = s \<and> (s * 16 + p) mod 16 = p" by presburger
lemma H2: "(m::nat) < 4 \<Longrightarrow> (t * 4 + m) div 4 = t \<and> (t * 4 + m) mod 4 = m" by presburger

lemma ar1: "(b::nat) < 256 \<Longrightarrow> (a::nat) div 4 * 4 + (a mod 4 * 16 + b div 16) div 16 = a"
proof -
  assume b: "b < 256"
  have hp: "b div 16 < 16" using b by simp
  have "(a mod 4 * 16 + b div 16) div 16 = a mod 4" using H1[OF hp] by simp
  then show ?thesis by simp
qed

lemma ar2: "(b::nat) < 256 \<Longrightarrow> (c::nat) < 256 \<Longrightarrow>
    ((a::nat) mod 4 * 16 + b div 16) mod 16 * 16 + (b mod 16 * 4 + c div 64) div 4 = b"
proof -
  assume b: "b < 256" and c: "c < 256"
  have hp: "b div 16 < 16" using b by simp
  have hm: "c div 64 < 4" using c by simp
  have e1: "(a mod 4 * 16 + b div 16) mod 16 = b div 16" using H1[OF hp] by simp
  have e2: "(b mod 16 * 4 + c div 64) div 4 = b mod 16" using H2[OF hm] by simp
  show ?thesis using e1 e2 by simp
qed

lemma ar3: "(c::nat) < 256 \<Longrightarrow> ((b::nat) mod 16 * 4 + c div 64) mod 4 * 64 + c mod 64 = c"
proof -
  assume c: "c < 256"
  have hm: "c div 64 < 4" using c by simp
  have "(b mod 16 * 4 + c div 64) mod 4 = c div 64" using H2[OF hm] by simp
  then show ?thesis by simp
qed

lemma ar1p: "(a::nat) div 4 * 4 + (a mod 4 * 16) div 16 = a" by simp

lemma ar2p: "(b::nat) < 256 \<Longrightarrow> ((a::nat) mod 4 * 16 + b div 16) mod 16 * 16 + (b mod 16 * 4) div 4 = b"
proof -
  assume b: "b < 256"
  have hp: "b div 16 < 16" using b by simp
  have e1: "(a mod 4 * 16 + b div 16) mod 16 = b div 16" using H1[OF hp] by simp
  show ?thesis using e1 by simp
qed

lemma enc_group:
  assumes "a < 256" "b < 256" "c < 256"
  shows "b64_dec [b64c (a div 4), b64c ((a mod 4) * 16 + b div 16),
                  b64c ((b mod 16) * 4 + c div 64), b64c (c mod 64)] = Some [a, b, c]"
proof -
  have i1: "a div 4 < 64" and i2: "(a mod 4) * 16 + b div 16 < 64"
    and i3: "(b mod 16) * 4 + c div 64 < 64" and i4: "c mod 64 < 64" using assms by auto
  show ?thesis
    using b64i_b64c[OF i1] b64i_b64c[OF i2] b64i_b64c[OF i3] b64i_b64c[OF i4] assms
    by (simp add: ar1 ar2 ar3 ar1p ar2p | (simp, arith) | auto simp: ar1 ar2 ar3 ar1p ar2p)
qed

lemma enc_nonempty: "r \<noteq> [] \<Longrightarrow> \<exists>e es. b64_enc r = e # es"
  by (cases r rule: b64_enc.cases) auto

lemma dec_enc1: "a < 256 \<Longrightarrow> b64_dec (b64_enc [a]) = Some [a]"
proof -
  assume a: "a < 256"
  have i1: "a div 4 < 64" and i2: "(a mod 4) * 16 < 64" using a by auto
  show ?thesis using b64i_b64c[OF i1] b64i_b64c[OF i2] b64i_pad a by (simp add: ar1 ar2 ar3 ar1p ar2p | (simp, arith) | auto simp: ar1 ar2 ar3 ar1p ar2p)
qed

lemma dec_enc2: "a < 256 \<Longrightarrow> b < 256 \<Longrightarrow> b64_dec (b64_enc [a, b]) = Some [a, b]"
proof -
  assume a: "a < 256" and b: "b < 256"
  have i1: "a div 4 < 64" and i2: "(a mod 4) * 16 + b div 16 < 64" and i3: "(b mod 16) * 4 < 64"
    using a b by auto
  show ?thesis using b64i_b64c[OF i1] b64i_b64c[OF i2] b64i_b64c[OF i3] b64i_pad a b by (simp add: ar1 ar2 ar3 ar1p ar2p | (simp, arith) | auto simp: ar1 ar2 ar3 ar1p ar2p)
qed

lemma dec_enc3:
  assumes a: "a < 256" and b: "b < 256" and c: "c < 256" and ih: "b64_dec (b64_enc r) = Some r"
  shows "b64_dec (b64_enc (a # b # c # r)) = Some (a # b # c # r)"
proof (cases r)
  case Nil
  then show ?thesis using enc_group[OF a b c] by simp
next
  case (Cons d r4)
  obtain e es where ee: "b64_enc r = e # es" using enc_nonempty Cons by blast
  have ih': "b64_dec (e # es) = Some r" using ih ee by simp
  have i1: "a div 4 < 64" and i2: "(a mod 4) * 16 + b div 16 < 64"
    and i3: "(b mod 16) * 4 + c div 64 < 64" and i4: "c mod 64 < 64" using a b c by auto
  show ?thesis
    using ee ih' b64i_b64c[OF i1] b64i_b64c[OF i2] b64i_b64c[OF i3] b64i_b64c[OF i4] a b c
    by (simp add: ar1 ar2 ar3 ar1p ar2p | (simp, arith) | auto simp: ar1 ar2 ar3 ar1p ar2p)
qed

lemma rt_aux: "\<forall>bs. length bs \<le> n \<longrightarrow> (\<forall>x \<in> set bs. x < 256) \<longrightarrow> b64_dec (b64_enc bs) = Some bs"
proof (induction n)
  case 0
  show ?case by simp
next
  case (Suc n)
  show ?case
  proof (intro allI impI)
    fix bs :: "nat list"
    assume l: "length bs \<le> Suc n" and h: "\<forall>x \<in> set bs. x < 256"
    consider (e) "bs = []" | (o) a where "bs = [a]" | (t) a b where "bs = [a, b]"
      | (g) a b c r where "bs = a # b # c # r"
      by (cases bs rule: b64_enc.cases) auto
    then show "b64_dec (b64_enc bs) = Some bs"
    proof cases
      case e
      then show ?thesis by simp
    next
      case o
      then show ?thesis using h dec_enc1 by auto
    next
      case t
      then show ?thesis using h dec_enc2 by auto
    next
      case g
      then have r: "\<forall>x \<in> set r. x < 256" and r2: "length r \<le> n" using h l by auto
      have "b64_dec (b64_enc r) = Some r" using Suc.IH r r2 by blast
      then show ?thesis using g h dec_enc3 by auto
    qed
  qed
qed

theorem b64_roundtrip:
  "\<forall>x \<in> set bs. x < 256 \<Longrightarrow> b64_dec (b64_enc bs) = Some bs"
  using rt_aux[of "length bs"] by blast

function (sequential) utf8_ok :: "nat list \<Rightarrow> bool" where
  "utf8_ok [] = True"
| "utf8_ok (a # r) =
     (if a < 128 then utf8_ok r
      else if 194 \<le> a \<and> a \<le> 223 then
        (case r of b # r' \<Rightarrow> 128 \<le> b \<and> b \<le> 191 \<and> utf8_ok r' | _ \<Rightarrow> False)
      else if 224 \<le> a \<and> a \<le> 239 then
        (case r of b # c # r' \<Rightarrow>
           (if a = 224 then 160 \<le> b \<and> b \<le> 191 else if a = 237 then 128 \<le> b \<and> b \<le> 159
            else 128 \<le> b \<and> b \<le> 191) \<and> 128 \<le> c \<and> c \<le> 191 \<and> utf8_ok r' | _ \<Rightarrow> False)
      else if 240 \<le> a \<and> a \<le> 244 then
        (case r of b # c # d # r' \<Rightarrow>
           (if a = 240 then 144 \<le> b \<and> b \<le> 191 else if a = 244 then 128 \<le> b \<and> b \<le> 143
            else 128 \<le> b \<and> b \<le> 191) \<and> 128 \<le> c \<and> c \<le> 191 \<and> 128 \<le> d \<and> d \<le> 191 \<and> utf8_ok r'
         | _ \<Rightarrow> False)
      else False)"
  by pat_completeness auto
termination by (relation "measure length") auto

section \<open>URL percent-encoding\<close>

definition url_safe :: "nat \<Rightarrow> bool" where
  "url_safe c = ((65 \<le> c \<and> c \<le> 90) \<or> (97 \<le> c \<and> c \<le> 122) \<or> (48 \<le> c \<and> c \<le> 57)
     \<or> c = 95 \<or> c = 46 \<or> c = 45 \<or> c = 126)"

definition hexu :: "nat \<Rightarrow> nat" where
  "hexu d = (if d < 10 then 48 + d else 55 + d)"

definition hexv :: "nat \<Rightarrow> nat option" where
  "hexv c = (if 48 \<le> c \<and> c \<le> 57 then Some (c - 48)
             else if 65 \<le> c \<and> c \<le> 70 then Some (c - 55)
             else if 97 \<le> c \<and> c \<le> 102 then Some (c - 87) else None)"

lemma hexv_hexu: "d < 16 \<Longrightarrow> hexv (hexu d) = Some d"
  unfolding hexv_def hexu_def by auto

fun pct_enc :: "nat list \<Rightarrow> nat list" where
  "pct_enc [] = []"
| "pct_enc (c # r) = (if url_safe c then c # pct_enc r else 37 # hexu (c div 16) # hexu (c mod 16) # pct_enc r)"

function (sequential) pct_dec :: "nat list \<Rightarrow> nat list" where
  "pct_dec [] = []"
| "pct_dec (c # r) =
     (if c = 37 then
        (case r of
           a # b # r' \<Rightarrow>
             (case hexv a of
                Some x \<Rightarrow> (case hexv b of Some y \<Rightarrow> (x * 16 + y) # pct_dec r' | None \<Rightarrow> 37 # pct_dec r)
              | None \<Rightarrow> 37 # pct_dec r)
         | _ \<Rightarrow> 37 # pct_dec r)
      else c # pct_dec r)"
  by pat_completeness auto
termination by (relation "measure length") auto

theorem pct_roundtrip: "\<forall>x \<in> set bs. x < 256 \<Longrightarrow> pct_dec (pct_enc bs) = bs"
proof (induction bs)
  case Nil
  show ?case by simp
next
  case (Cons c r)
  then have c: "c < 256" and r: "\<forall>x \<in> set r. x < 256" by simp_all
  have ih: "pct_dec (pct_enc r) = r" using Cons.IH r by simp
  show ?case
  proof (cases "url_safe c")
    case True
    then have "c \<noteq> 37" unfolding url_safe_def by auto
    then show ?thesis using True ih by (simp add: pct_dec.simps)
  next
    case False
    have h1: "c div 16 < 16" using c by auto
    have h2: "c mod 16 < 16" by simp
    show ?thesis using False ih hexv_hexu[OF h1] hexv_hexu[OF h2]
      by (simp add: pct_dec.simps)
  qed
qed

section \<open>Digests\<close>

definition M32 :: nat where "M32 = 4294967296"

definition bitop :: "(bool \<Rightarrow> bool \<Rightarrow> bool) \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "bitop f x y = sum_list (map (\<lambda>i. if f (odd (x div 2 ^ i)) (odd (y div 2 ^ i)) then 2 ^ i else 0) [0..<32])"

definition band :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "band = bitop (\<and>)"
definition bor :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "bor = bitop (\<or>)"
definition bxor :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "bxor = bitop (\<noteq>)"
definition bnot :: "nat \<Rightarrow> nat" where "bnot x = M32 - 1 - x"
definition add32 :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "add32 a b = (a + b) mod M32"
definition rotl :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "rotl x n = (x mod 2 ^ (32 - n)) * 2 ^ n + x div 2 ^ (32 - n)"
definition rotr :: "nat \<Rightarrow> nat \<Rightarrow> nat" where "rotr x n = rotl x (32 - n)"

definition w_be :: "nat list \<Rightarrow> nat" where "w_be bs = foldl (\<lambda>a b. a * 256 + b) 0 bs"
definition w_le :: "nat list \<Rightarrow> nat" where "w_le bs = w_be (rev bs)"

fun chunksf :: "nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat list list" where
  "chunksf 0 n xs = []"
| "chunksf (Suc f) n xs = (if xs = [] then [] else take n xs # chunksf f n (drop n xs))"

definition chunks :: "nat \<Rightarrow> nat list \<Rightarrow> nat list list" where
  "chunks n xs = chunksf (length xs) n xs"

definition be_bytes :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "be_bytes k v = map (\<lambda>i. (v div 256 ^ (k - 1 - i)) mod 256) [0..<k]"

definition sha_pad :: "bool \<Rightarrow> nat list \<Rightarrow> nat list" where
  "sha_pad big m = m @ [128] @ replicate ((119 - length m mod 64) mod 64) 0
       @ (if big then be_bytes 8 (8 * length m) else rev (be_bytes 8 (8 * length m)))"

lemma length_be_bytes: "length (be_bytes k v) = k"
  by (simp add: be_bytes_def)

lemma pad_mod: "(r::nat) < 64 \<Longrightarrow> (r + 1 + (119 - r) mod 64 + 8) mod 64 = 0"
proof (cases "r \<le> 55")
  case True
  assume "r < 64"
  have e: "119 - r = (55 - r) + 64 * 1" using True by simp
  have lt: "55 - r < 64" by simp
  have m: "(119 - r) mod 64 = 55 - r" unfolding e using lt by simp
  have s: "r + 1 + (55 - r) + 8 = 64" using True by simp
  show ?thesis unfolding m s by simp
next
  case False
  assume "r < 64"
  have lt: "119 - r < 64" using False by simp
  have m: "(119 - r) mod 64 = 119 - r" using lt by simp
  have s: "r + 1 + (119 - r) + 8 = 128" using False \<open>r < 64\<close> by simp
  show ?thesis unfolding m s by simp
qed

theorem sha_pad_blocks: "length (sha_pad big m) mod 64 = 0"
proof -
  have l: "length (sha_pad big m) = length m + 1 + (119 - length m mod 64) mod 64 + 8"
    by (simp add: sha_pad_def length_be_bytes)
  define q where "q = length m div 64"
  define r where "r = length m mod 64"
  have lm: "length m = 64 * q + r" unfolding q_def r_def by simp
  have rl: "r < 64" unfolding r_def by simp
  have "length (sha_pad big m) = 64 * q + (r + 1 + (119 - r) mod 64 + 8)"
    using l lm unfolding r_def[symmetric] by simp
  then show ?thesis using pad_mod[OF rl] by simp
qed

definition hex_byte :: "nat \<Rightarrow> nat list" where
  "hex_byte b = [dc (b div 16), dc (b mod 16)]"

definition hex_words :: "bool \<Rightarrow> nat list \<Rightarrow> nat list" where
  "hex_words big ws = concat (map hex_byte
      (concat (map (\<lambda>w. if big then be_bytes 4 w else rev (be_bytes 4 w)) ws)))"

definition zip_add :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "zip_add a b = map (\<lambda>p. add32 (fst p) (snd p)) (zip a b)"

subsection \<open>SHA-256\<close>

definition k256 :: "nat list" where
  "k256 = [1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
     3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
     3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
     2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
     666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
     2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
     430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
     1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298]"

definition h256 :: "nat list" where
  "h256 = [1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225]"

fun ext256 :: "nat \<Rightarrow> nat list \<Rightarrow> nat list" where
  "ext256 0 w = w"
| "ext256 (Suc k) w =
     (let n = length w; w15 = w ! (n - 15); w2 = w ! (n - 2);
          s0 = bxor (bxor (rotr w15 7) (rotr w15 18)) (w15 div 8);
          s1 = bxor (bxor (rotr w2 17) (rotr w2 19)) (w2 div 1024)
      in ext256 k (w @ [add32 (add32 (w ! (n - 16)) s0) (add32 (w ! (n - 7)) s1)]))"

definition r256 :: "nat list \<Rightarrow> nat \<times> nat \<Rightarrow> nat list" where
  "r256 st kw = (case st of
     [a, b, c, d, e, f, g, h] \<Rightarrow>
       (let s1 = bxor (bxor (rotr e 6) (rotr e 11)) (rotr e 25);
            ch = bxor (band e f) (band (bnot e) g);
            t1 = add32 (add32 (add32 (add32 h s1) ch) (fst kw)) (snd kw);
            s0 = bxor (bxor (rotr a 2) (rotr a 13)) (rotr a 22);
            mj = bxor (bxor (band a b) (band a c)) (band b c);
            t2 = add32 s0 mj
        in [add32 t1 t2, a, b, c, add32 d t1, e, f, g])
   | _ \<Rightarrow> st)"

definition block256 :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "block256 hs blk = zip_add hs (foldl r256 hs (zip k256 (ext256 48 (map w_be (chunks 4 blk)))))"

definition sha256 :: "nat list \<Rightarrow> nat list" where
  "sha256 m = hex_words True (foldl block256 h256 (chunks 64 (sha_pad True m)))"

subsection \<open>SHA-1\<close>

fun ext1 :: "nat \<Rightarrow> nat list \<Rightarrow> nat list" where
  "ext1 0 w = w"
| "ext1 (Suc k) w =
     (let n = length w in
      ext1 k (w @ [rotl (bxor (bxor (w ! (n - 3)) (w ! (n - 8))) (bxor (w ! (n - 14)) (w ! (n - 16)))) 1]))"

definition r1 :: "nat list \<Rightarrow> nat \<times> nat \<Rightarrow> nat list" where
  "r1 st iw = (case st of
     [a, b, c, d, e] \<Rightarrow>
       (let i = fst iw;
            f = (if i < 20 then bor (band b c) (band (bnot b) d)
                 else if i < 40 then bxor (bxor b c) d
                 else if i < 60 then bor (bor (band b c) (band b d)) (band c d)
                 else bxor (bxor b c) d);
            k = (if i < 20 then 1518500249 else if i < 40 then 1859775393
                 else if i < 60 then 2400959708 else 3395469782);
            t = add32 (add32 (add32 (add32 (rotl a 5) f) e) k) (snd iw)
        in [t, a, rotl b 30, c, d])
   | _ \<Rightarrow> st)"

definition h1 :: "nat list" where
  "h1 = [1732584193, 4023233417, 2562383102, 271733878, 3285377520]"

definition block1 :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "block1 hs blk = zip_add hs (foldl r1 hs (zip [0..<80] (ext1 64 (map w_be (chunks 4 blk)))))"

definition sha1 :: "nat list \<Rightarrow> nat list" where
  "sha1 m = hex_words True (foldl block1 h1 (chunks 64 (sha_pad True m)))"

subsection \<open>MD5\<close>

definition t_md5 :: "nat list" where
  "t_md5 = [3614090360, 3905402710, 606105819, 3250441966, 4118548399, 1200080426, 2821735955, 4249261313,
     1770035416, 2336552879, 4294925233, 2304563134, 1804603682, 4254626195, 2792965006, 1236535329,
     4129170786, 3225465664, 643717713, 3921069994, 3593408605, 38016083, 3634488961, 3889429448,
     568446438, 3275163606, 4107603335, 1163531501, 2850285829, 4243563512, 1735328473, 2368359562,
     4294588738, 2272392833, 1839030562, 4259657740, 2763975236, 1272893353, 4139469664, 3200236656,
     681279174, 3936430074, 3572445317, 76029189, 3654602809, 3873151461, 530742520, 3299628645,
     4096336452, 1126891415, 2878612391, 4237533241, 1700485571, 2399980690, 4293915773, 2240044497,
     1873313359, 4264355552, 2734768916, 1309151649, 4149444226, 3174756917, 718787259, 3951481745]"

definition rm5 :: "nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat list" where
  "rm5 m st j = (case st of
     [a, b, c, d] \<Rightarrow>
       (let f = (if j < 16 then bor (band b c) (band (bnot b) d)
                 else if j < 32 then bor (band d b) (band (bnot d) c)
                 else if j < 48 then bxor (bxor b c) d
                 else bxor c (bor b (bnot d)));
            g = (if j < 16 then j else if j < 32 then (5 * j + 1) mod 16
                 else if j < 48 then (3 * j + 5) mod 16 else (7 * j) mod 16);
            f2 = add32 (add32 (add32 f a) (t_md5 ! j)) (m ! g);
            sh = (if j < 16 then [7, 12, 17, 22] ! (j mod 4) else if j < 32 then [5, 9, 14, 20] ! (j mod 4)
                  else if j < 48 then [4, 11, 16, 23] ! (j mod 4) else [6, 10, 15, 21] ! (j mod 4))
        in [d, add32 b (rotl f2 sh), b, c])
   | _ \<Rightarrow> st)"

definition h5 :: "nat list" where
  "h5 = [1732584193, 4023233417, 2562383102, 271733878]"

definition block5 :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "block5 hs blk = (let m = map w_le (chunks 4 blk) in
      zip_add hs (foldl (rm5 m) hs [0..<64]))"

definition md5 :: "nat list \<Rightarrow> nat list" where
  "md5 m = hex_words False (foldl block5 h5 (chunks 64 (sha_pad False m)))"

datatype halg = H_sha256 | H_sha1 | H_md5

definition digest :: "halg \<Rightarrow> nat list \<Rightarrow> nat list" where
  "digest a m = (case a of H_sha256 \<Rightarrow> sha256 m | H_sha1 \<Rightarrow> sha1 m | H_md5 \<Rightarrow> md5 m)"

section \<open>Weekday of a date\<close>

definition leap :: "nat \<Rightarrow> bool" where
  "leap y = (y mod 4 = 0 \<and> (y mod 100 \<noteq> 0 \<or> y mod 400 = 0))"

definition dim :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "dim y m = (if m = 2 then (if leap y then 29 else 28)
              else if m = 4 \<or> m = 6 \<or> m = 9 \<or> m = 11 then 30 else 31)"

definition valid_date :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "valid_date y m d = (1 \<le> y \<and> y \<le> 9999 \<and> 1 \<le> m \<and> m \<le> 12 \<and> 1 \<le> d \<and> d \<le> dim y m)"

text \<open>Days since 1970-01-01 (proleptic Gregorian).\<close>
definition days :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> int" where
  "days y m d =
     (let y' = (if m \<le> 2 then int y - 1 else int y);
          era = y' div 400; yoe = y' - era * 400;
          mp = (if m > 2 then int m - 3 else int m + 9);
          doy = (153 * mp + 2) div 5 + int d - 1;
          doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
      in era * 146097 + doe - 719468)"

definition weekday :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "weekday y m d = nat ((days y m d + 4) mod 7)"

definition day_name :: "nat \<Rightarrow> String.literal" where
  "day_name i = [STR ''Sunday'', STR ''Monday'', STR ''Tuesday'', STR ''Wednesday'', STR ''Thursday'',
                 STR ''Friday'', STR ''Saturday''] ! (i mod 7)"

theorem days_next_day_in_month:
  "valid_date y m d \<Longrightarrow> d < dim y m \<Longrightarrow> days y m (d + 1) = days y m d + 1"
  by (simp add: days_def Let_def)

theorem weekday_next_day:
  "valid_date y m d \<Longrightarrow> d < dim y m \<Longrightarrow> weekday y m (d + 1) = (weekday y m d + 1) mod 7"
proof -
  assume v: "valid_date y m d" and lt: "d < dim y m"
  define z where "z = days y m d + 4"
  have a: "days y m (d + 1) + 4 = z + 1" using days_next_day_in_month[OF v lt] unfolding z_def by simp
  have k0: "0 \<le> z mod 7" by simp
  have e: "(z + 1) mod 7 = (z mod 7 + 1) mod 7" by (simp add: mod_add_left_eq)
  have "nat ((z + 1) mod 7) = (nat (z mod 7) + 1) mod 7"
    unfolding e using k0 by (simp add: nat_mod_distrib nat_add_distrib)
  then show ?thesis unfolding weekday_def a z_def[symmetric] by simp
qed

theorem epoch_is_thursday: "day_name (weekday 1970 1 1) = STR ''Thursday''"
  by (simp add: day_name_def weekday_def days_def Let_def)

section \<open>JSON validity (CPython scanner semantics)\<close>

datatype jinfo = JI_obj nat | JI_arr nat | JI_str nat | JI_int | JI_float | JI_bool | JI_null
datatype jres = JOk jinfo nat | JFail String.literal nat
datatype sres = SOk "nat list" nat | SFail String.literal nat
datatype jtop = JT_ok jinfo | JT_bad String.literal nat nat

definition bslash :: String.literal where "bslash = String.implode [CHR 0x5C]"

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition is_ws :: "nat \<Rightarrow> bool" where "is_ws c = (c = 32 \<or> c = 9 \<or> c = 10 \<or> c = 13)"
definition is_dig :: "nat \<Rightarrow> bool" where "is_dig c = (48 \<le> c \<and> c \<le> 57)"

fun skipw :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat" where
  "skipw 0 s i = i"
| "skipw (Suc f) s i = (if i < length s \<and> is_ws (s ! i) then skipw f s (i + 1) else i)"

definition skipws :: "nat list \<Rightarrow> nat \<Rightarrow> nat" where "skipws s i = skipw (length s) s i"

fun skipd :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat" where
  "skipd 0 s i = i"
| "skipd (Suc f) s i = (if i < length s \<and> is_dig (s ! i) then skipd f s (i + 1) else i)"

definition hex4 :: "nat list \<Rightarrow> nat \<Rightarrow> nat option" where
  "hex4 s i = (if i + 4 \<le> length s then
      (case (hexv (s ! i), hexv (s ! (i + 1)), hexv (s ! (i + 2)), hexv (s ! (i + 3))) of
         (Some a, Some b, Some c, Some d) \<Rightarrow> Some (((a * 16 + b) * 16 + c) * 16 + d)
       | _ \<Rightarrow> None)
    else None)"

definition u8enc :: "nat \<Rightarrow> nat list" where
  "u8enc cp = (if cp < 128 then [cp]
     else if cp < 2048 then [192 + cp div 64, 128 + cp mod 64]
     else if cp < 65536 then [224 + cp div 4096, 128 + (cp div 64) mod 64, 128 + cp mod 64]
     else [240 + cp div 262144, 128 + (cp div 4096) mod 64, 128 + (cp div 64) mod 64, 128 + cp mod 64])"

fun jstr :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> sres" where
  "jstr 0 s i b acc = SFail (STR ''Unterminated string starting at'') b"
| "jstr (Suc f) s i b acc =
     (if i < length s then
        (let c = s ! i in
         if c = 34 then SOk (rev acc) (i + 1)
         else if c = 92 then
           (if i + 1 < length s then
              (let e = s ! (i + 1) in
               if e = 34 \<or> e = 92 \<or> e = 47 then jstr f s (i + 2) b (e # acc)
               else if e = 98 then jstr f s (i + 2) b (8 # acc)
               else if e = 102 then jstr f s (i + 2) b (12 # acc)
               else if e = 110 then jstr f s (i + 2) b (10 # acc)
               else if e = 114 then jstr f s (i + 2) b (13 # acc)
               else if e = 116 then jstr f s (i + 2) b (9 # acc)
               else if e = 117 then
                 (case hex4 s (i + 2) of
                    None \<Rightarrow> SFail (STR ''Invalid '' + bslash + STR ''uXXXX escape'') (i + 1)
                  | Some u \<Rightarrow>
                      (if 55296 \<le> u \<and> u < 56320 \<and> i + 11 < length s \<and> s ! (i + 6) = 92 \<and> s ! (i + 7) = 117 then
                         (case hex4 s (i + 8) of
                            Some v \<Rightarrow>
                              (if 56320 \<le> v \<and> v < 57344
                               then jstr f s (i + 12) b (rev (u8enc (65536 + (u - 55296) * 1024 + (v - 56320))) @ acc)
                               else jstr f s (i + 6) b (rev (u8enc u) @ acc))
                          | None \<Rightarrow> jstr f s (i + 6) b (rev (u8enc u) @ acc))
                       else jstr f s (i + 6) b (rev (u8enc u) @ acc)))
               else SFail (STR ''Invalid '' + bslash + STR ''escape'') i)
            else SFail (STR ''Unterminated string starting at'') b)
         else if c < 32 then SFail (STR ''Invalid control character at'') i
         else jstr f s (i + 1) b (c # acc))
      else SFail (STR ''Unterminated string starting at'') b)"

definition ncps :: "nat list \<Rightarrow> nat" where
  "ncps bs = length (filter (\<lambda>b. b < 128 \<or> 192 \<le> b) bs)"

definition lit_at :: "nat list \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> bool" where
  "lit_at s i w = (take (length w) (drop i s) = w)"

definition jnum :: "nat list \<Rightarrow> nat \<Rightarrow> (bool \<times> nat) option" where
  "jnum s i =
     (let n = length s; st = (if s ! i = 45 then i + 1 else i) in
      if n \<le> st then None
      else
        (let c = s ! st;
             p1 = (if 49 \<le> c \<and> c \<le> 57 then Some (skipd n s (st + 1)) else if c = 48 then Some (st + 1) else None)
         in case p1 of
              None \<Rightarrow> None
            | Some q1 \<Rightarrow>
                (let fr = (q1 < n \<and> s ! q1 = 46 \<and> q1 + 1 < n \<and> is_dig (s ! (q1 + 1)));
                     q2 = (if fr then skipd n s (q1 + 2) else q1);
                     ex = (if q2 < n \<and> (s ! q2 = 101 \<or> s ! q2 = 69) then
                             (let q = q2 + 1; q' = (if q < n \<and> (s ! q = 45 \<or> s ! q = 43) then q + 1 else q);
                                  r = skipd n s q' in if q' < r then Some r else None)
                           else None)
                 in case ex of Some r \<Rightarrow> Some (True, r) | None \<Rightarrow> Some (fr, q2))))"

fun jval :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> jres"
and jarr :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> jres"
and jobj :: "nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> nat list list \<Rightarrow> jres" where
  "jval 0 s i = JFail (STR ''Expecting value'') i"
| "jval (Suc f) s i =
     (if length s \<le> i then JFail (STR ''Expecting value'') i
      else
        (let c = s ! i in
         if c = 34 then
           (case jstr (length s + 1) s (i + 1) i [] of
              SOk bs j \<Rightarrow> JOk (JI_str (ncps bs)) j
            | SFail m p \<Rightarrow> JFail m p)
         else if c = 123 then
           (let j = skipws s (i + 1) in
            if j < length s \<and> s ! j = 125 then JOk (JI_obj 0) (j + 1) else jobj f s j [])
         else if c = 91 then
           (let j = skipws s (i + 1) in
            if j < length s \<and> s ! j = 93 then JOk (JI_arr 0) (j + 1) else jarr f s j 0)
         else if c = 110 \<and> lit_at s i [110, 117, 108, 108] then JOk JI_null (i + 4)
         else if c = 116 \<and> lit_at s i [116, 114, 117, 101] then JOk JI_bool (i + 4)
         else if c = 102 \<and> lit_at s i [102, 97, 108, 115, 101] then JOk JI_bool (i + 5)
         else if c = 78 \<and> lit_at s i [78, 97, 78] then JOk JI_float (i + 3)
         else if c = 73 \<and> lit_at s i [73, 110, 102, 105, 110, 105, 116, 121] then JOk JI_float (i + 8)
         else if c = 45 \<and> lit_at s (i + 1) [73, 110, 102, 105, 110, 105, 116, 121] then JOk JI_float (i + 9)
         else if c = 45 \<or> is_dig c then
           (case jnum s i of
              Some (isf, q) \<Rightarrow> JOk (if isf then JI_float else JI_int) q
            | None \<Rightarrow> JFail (STR ''Expecting value'') i)
         else JFail (STR ''Expecting value'') i))"
| "jarr 0 s j cnt = JFail (STR ''Expecting value'') j"
| "jarr (Suc f) s j cnt =
     (case jval f s j of
        JFail m p \<Rightarrow> JFail m p
      | JOk _ k \<Rightarrow>
          (let k2 = skipws s k in
           if k2 < length s \<and> s ! k2 = 93 then JOk (JI_arr (cnt + 1)) (k2 + 1)
           else if k2 < length s \<and> s ! k2 = 44 then jarr f s (skipws s (k2 + 1)) (cnt + 1)
           else JFail (STR ''Expecting ',' delimiter'') k2))"
| "jobj 0 s j keys = JFail (STR ''Expecting property name enclosed in double quotes'') j"
| "jobj (Suc f) s j keys =
     (if length s \<le> j \<or> s ! j \<noteq> 34 then JFail (STR ''Expecting property name enclosed in double quotes'') j
      else
        (case jstr (length s + 1) s (j + 1) j [] of
           SFail m p \<Rightarrow> JFail m p
         | SOk key k \<Rightarrow>
             (let k2 = skipws s k in
              if length s \<le> k2 \<or> s ! k2 \<noteq> 58 then JFail (STR ''Expecting ':' delimiter'') k2
              else
                (case jval f s (skipws s (k2 + 1)) of
                   JFail m p \<Rightarrow> JFail m p
                 | JOk _ m \<Rightarrow>
                     (let m2 = skipws s m; keys' = key # keys in
                      if m2 < length s \<and> s ! m2 = 125 then JOk (JI_obj (length (remdups keys'))) (m2 + 1)
                      else if m2 < length s \<and> s ! m2 = 44 then jobj f s (skipws s (m2 + 1)) keys'
                      else JFail (STR ''Expecting ',' delimiter'') m2)))))"

definition cp_count :: "nat list \<Rightarrow> nat" where
  "cp_count bs = length (filter (\<lambda>b. b < 128 \<or> 192 \<le> b) bs)"

definition last_nl :: "nat list \<Rightarrow> nat option" where
  "last_nl pre = (let ps = filter (\<lambda>k. pre ! k = 10) [0..<length pre] in
      if ps = [] then None else Some (last ps))"

definition json_bad :: "nat list \<Rightarrow> String.literal \<Rightarrow> nat \<Rightarrow> jtop" where
  "json_bad s m p =
     (let pre = take p s; line = length (filter (\<lambda>b. b = 10) pre) + 1 in
      case last_nl pre of
        None \<Rightarrow> JT_bad m line (cp_count pre + 1)
      | Some k \<Rightarrow> JT_bad m line (cp_count (drop k pre)))"

definition json_check :: "nat list \<Rightarrow> jtop" where
  "json_check s =
     (if take 3 s = [239, 187, 191] then json_bad s (STR ''Unexpected UTF-8 BOM (decode using utf-8-sig)'') 0
      else
        (case jval (length s + 2) s (skipws s 0) of
           JFail m p \<Rightarrow> json_bad s m p
         | JOk info k \<Rightarrow>
             (let k2 = skipws s k in
              if k2 = length s then JT_ok info else json_bad s (STR ''Extra data'') k2)))"

section \<open>Requests, kernel, reply\<close>

datatype freq =
    F_json "nat list"
  | F_b64dec "nat list"
  | F_b64enc "nat list"
  | F_hash halg "nat list"
  | F_urldec "nat list"
  | F_urlenc "nat list"
  | F_base "nat list" nat nat "nat list"
  | F_day "nat list" nat nat nat

datatype fout =
    FJson jtop
  | FB64dec "nat list" "nat list"
  | FB64bad "nat list"
  | FB64enc "nat list" "nat list"
  | FHash halg "nat list" "nat list"
  | FUrlDec "nat list" "nat list"
  | FUrlBad "nat list"
  | FUrlEnc "nat list" "nat list"
  | FBase "nat list" nat nat "nat list" "nat list"
  | FBaseBad "nat list" nat
  | FDay "nat list" nat
  | FDateBad "nat list"

definition f_kernel :: "freq \<Rightarrow> fout" where
  "f_kernel r = (case r of
     F_json s \<Rightarrow> FJson (json_check s)
   | F_b64dec p \<Rightarrow>
       (if \<forall>c \<in> set p. c < 128 then
          (case b64_dec p of Some bs \<Rightarrow> if utf8_ok bs then FB64dec p bs else FB64bad p | None \<Rightarrow> FB64bad p)
        else FB64bad p)
   | F_b64enc p \<Rightarrow> FB64enc p (b64_enc p)
   | F_hash a p \<Rightarrow> FHash a p (digest a p)
   | F_urldec p \<Rightarrow> (let bs = pct_dec p in if utf8_ok bs then FUrlDec p bs else FUrlBad p)
   | F_urlenc p \<Rightarrow> FUrlEnc p (pct_enc p)
   | F_base tok src dst cs \<Rightarrow>
       (case base_convert src dst cs of Some out \<Rightarrow> FBase tok src dst cs out | None \<Rightarrow> FBaseBad tok src)
   | F_day tok y m d \<Rightarrow> if valid_date y m d then FDay tok (weekday y m d) else FDateBad tok)"

theorem f_base_sound:
  "2 \<le> src \<Longrightarrow> src \<le> 16 \<Longrightarrow> 2 \<le> dst \<Longrightarrow> dst \<le> 16 \<Longrightarrow>
   f_kernel (F_base tok src dst cs) = FBase tok' src' dst' cs' out \<Longrightarrow>
     digits_val dst out = digits_val src cs \<and> (\<exists>n. digits_val src cs = Some n)"
proof -
  assume a: "2 \<le> dst" "dst \<le> 16" and k: "f_kernel (F_base tok src dst cs) = FBase tok' src' dst' cs' out"
  then have bc: "base_convert src dst cs = Some out" by (auto simp: f_kernel_def split: option.splits)
  then have "\<exists>n. digits_val src cs = Some n" by (auto simp: base_convert_def split: option.splits)
  moreover have "digits_val dst out = digits_val src cs" using base_convert_value[OF a bc] .
  ultimately show ?thesis by blast
qed

theorem f_base_declines:
  "f_kernel (F_base tok src dst cs) = FBaseBad tok' src' \<Longrightarrow> digits_val src cs = None"
  by (auto simp: f_kernel_def base_convert_def split: option.splits)

theorem f_b64dec_ok:
  "f_kernel (F_b64dec p) = FB64dec p' bs \<Longrightarrow> p' = p \<and> b64_dec p = Some bs \<and> utf8_ok bs"
  by (auto simp: f_kernel_def split: option.splits if_splits)

theorem f_b64enc_decodes:
  "(\<forall>x \<in> set p. x < 256) \<Longrightarrow> f_kernel (F_b64enc p) = FB64enc p' out \<Longrightarrow> b64_dec out = Some p"
  using b64_roundtrip by (auto simp: f_kernel_def)

theorem f_url_roundtrip:
  "(\<forall>x \<in> set p. x < 256) \<Longrightarrow> f_kernel (F_urlenc p) = FUrlEnc p' out \<Longrightarrow> pct_dec out = p"
  using pct_roundtrip by (auto simp: f_kernel_def)

theorem f_day_valid:
  "f_kernel (F_day tok y m d) = FDay tok' w \<Longrightarrow> valid_date y m d \<and> w = weekday y m d"
  by (auto simp: f_kernel_def split: if_splits)

theorem f_day_invalid:
  "f_kernel (F_day tok y m d) = FDateBad tok \<longleftrightarrow> \<not> valid_date y m d"
  by (auto simp: f_kernel_def split: if_splits)

section \<open>Reply text\<close>

definition jtype_text :: "jinfo \<Rightarrow> String.literal" where
  "jtype_text i = (case i of JI_obj _ \<Rightarrow> STR ''an object'' | JI_arr _ \<Rightarrow> STR ''an array''
     | JI_str _ \<Rightarrow> STR ''a str'' | JI_int \<Rightarrow> STR ''a int'' | JI_float \<Rightarrow> STR ''a float''
     | JI_bool \<Rightarrow> STR ''a bool'' | JI_null \<Rightarrow> STR ''a NoneType'')"

definition jlen :: "jinfo \<Rightarrow> nat" where
  "jlen i = (case i of JI_obj n \<Rightarrow> n | JI_arr n \<Rightarrow> n | JI_str n \<Rightarrow> n | _ \<Rightarrow> 1)"

definition halg_name :: "halg \<Rightarrow> String.literal" where
  "halg_name a = (case a of H_sha256 \<Rightarrow> STR ''SHA256'' | H_sha1 \<Rightarrow> STR ''SHA1'' | H_md5 \<Rightarrow> STR ''MD5'')"

definition f_reply :: "freq \<Rightarrow> reply" where
  "f_reply r = (case f_kernel r of
     FJson (JT_ok i) \<Rightarrow>
       Reply True (STR ''json_valid'')
         [PS (STR ''Yes, that is valid JSON ('' + jtype_text i + STR '' with '' + show_nat (jlen i) + STR '' ''
              + (case i of JI_obj _ \<Rightarrow> STR ''keys'' | _ \<Rightarrow> STR ''items'') + STR '').'')] (JRaw (STR ''true''))
   | FJson (JT_bad m l c) \<Rightarrow>
       Reply True (STR ''json_invalid'')
         [PS (STR ''No, that is not valid JSON: '' + m + STR '' at line '' + show_nat l + STR '', column '' + show_nat c + STR ''.'')]
         (JRaw (STR ''false''))
   | FB64dec p bs \<Rightarrow>
       Reply True (STR ''b64_decode'')
         ([PS ((STR ''Base64 '' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' decodes to '' + dq + STR ''''))] @ [PB bs] @ [PS ((STR '''' + dq + STR ''.''))]) (JStr bs)
   | FB64bad p \<Rightarrow>
       Reply False (STR ''b64_invalid'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' is not valid base64 text (or does not decode to UTF-8), so I will not guess at it.''))]) JNone
   | FB64enc p out \<Rightarrow>
       Reply True (STR ''b64_encode'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' in base64 is '' + dq + STR ''''))] @ [PB out] @ [PS ((STR '''' + dq + STR ''.''))]) (JStr out)
   | FHash a p out \<Rightarrow>
       Reply True (STR ''hash'')
         ([PS (STR ''The '' + halg_name a + (STR '' of '' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' (UTF-8) is ''))] @ [PB out] @ [PS (STR ''.'')]) (JStr out)
   | FUrlDec p bs \<Rightarrow>
       Reply True (STR ''url_decode'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' URL-decodes to '' + dq + STR ''''))] @ [PB bs] @ [PS ((STR '''' + dq + STR ''.''))]) (JStr bs)
   | FUrlBad p \<Rightarrow>
       Reply False (STR ''url_invalid'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' does not percent-decode to UTF-8 text, so I will not guess at it.''))]) JNone
   | FUrlEnc p out \<Rightarrow>
       Reply True (STR ''url_encode'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB p] @ [PS ((STR '''' + dq + STR '' URL-encodes to '' + dq + STR ''''))] @ [PB out] @ [PS ((STR '''' + dq + STR ''.''))]) (JStr out)
   | FBase tok src dst cs out \<Rightarrow>
       Reply True (STR ''base'')
         ([PB cs] @ [PS (STR '' (base '' + show_nat src + STR '') is '')] @ [PB out]
          @ [PS (STR '' in base '' + show_nat dst + STR ''.'')]) (JStr out)
   | FBaseBad tok src \<Rightarrow>
       Reply False (STR ''base_invalid'')
         ([PS ((STR '''' + dq + STR ''''))] @ [PB tok] @ [PS ((STR '''' + dq + STR '' has a digit that is not allowed in base '') + show_nat src
            + STR '', so it is not a valid number there.'')]) JNone
   | FDay tok w \<Rightarrow>
       Reply True (STR ''weekday'') ([PB tok] @ [PS (STR '' is a '' + day_name w + STR ''.'')]) JNone
   | FDateBad tok \<Rightarrow>
       Reply False (STR ''date_invalid'')
         ([PB tok] @ [PS (STR '' is not a real calendar date, so it has no weekday.'')]) JNone)"

end
