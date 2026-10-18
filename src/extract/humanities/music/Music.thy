theory Music
  imports "Veri7vn_Humanities_Base.Hum_Num"
begin

text \<open>
  Oracle7 music-v2 and music-v2-r2 (upstream/root/specialists/music-v2*/organ_music_v1.py,
  organ_music_v2.py, organ_music_v2_r2.py) as one verified HOL kernel. Pitch classes,
  intervals, key signatures, scales and MIDI numbers are modular arithmetic over 12 and
  over the seven letters; frequency and cents are real numbers (a twelfth root of two
  and a logarithm) enclosed by Isabelle's verified interval arithmetic.

  The untrusted SML recognizer reads the question and builds an @{text mreq}; every
  value, decline and reply text below comes from this theory. The tables are HOL
  constants transcribed from the organ and checked by tables_check.py.
\<close>

section \<open>Letters, pitch classes, spelling\<close>

datatype letter = N_C | N_D | N_E | N_F | N_G | N_A | N_B

fun lidx :: "letter \<Rightarrow> nat" where
  "lidx N_C = 0" | "lidx N_D = 1" | "lidx N_E = 2" | "lidx N_F = 3"
| "lidx N_G = 4" | "lidx N_A = 5" | "lidx N_B = 6"

fun lup :: "letter \<Rightarrow> letter" where
  "lup N_C = N_D" | "lup N_D = N_E" | "lup N_E = N_F" | "lup N_F = N_G"
| "lup N_G = N_A" | "lup N_A = N_B" | "lup N_B = N_C"

fun lstep :: "nat \<Rightarrow> letter \<Rightarrow> letter" where
  "lstep 0 L = L" | "lstep (Suc k) L = lstep k (lup L)"

text \<open>The natural pitch class of each letter (the organ's NAT).\<close>
fun nat_pc :: "letter \<Rightarrow> int" where
  "nat_pc N_C = 0" | "nat_pc N_D = 2" | "nat_pc N_E = 4" | "nat_pc N_F = 5"
| "nat_pc N_G = 7" | "nat_pc N_A = 9" | "nat_pc N_B = 11"

text \<open>A spelled note: a letter and an accidental count (sharps positive).\<close>
type_synonym pnote = "letter \<times> int"

definition pcn :: "pnote \<Rightarrow> int" where
  "pcn n = (nat_pc (fst n) + snd n) mod 12"

definition spellable :: "pnote \<Rightarrow> bool" where
  "spellable n \<longleftrightarrow> \<bar>snd n\<bar> \<le> 2"

fun letter_str :: "letter \<Rightarrow> String.literal" where
  "letter_str N_C = STR ''C''" | "letter_str N_D = STR ''D''" | "letter_str N_E = STR ''E''"
| "letter_str N_F = STR ''F''" | "letter_str N_G = STR ''G''" | "letter_str N_A = STR ''A''"
| "letter_str N_B = STR ''B''"

definition acc_str :: "int \<Rightarrow> String.literal" where
  "acc_str a = (if a = 0 then STR '''' else if a = 1 then STR ''#'' else if a = -1 then STR ''b''
     else if a = 2 then STR ''##'' else if a = -2 then STR ''bb'' else STR ''?'')"

definition spell :: "pnote \<Rightarrow> String.literal" where
  "spell n = letter_str (fst n) + acc_str (snd n)"

lemma lidx_lup: "lidx (lup L) = (lidx L + 1) mod 7"
  by (cases L) simp_all

lemma abs_le2: "\<bar>a :: int\<bar> \<le> 2 \<Longrightarrow> a \<in> set [-2, -1, 0, 1, 2]"
proof -
  assume h: "\<bar>a\<bar> \<le> 2"
  then have "-2 \<le> a" "a \<le> 2" by (simp_all add: abs_le_iff)
  then have "a = -2 \<or> a = -1 \<or> a = 0 \<or> a = 1 \<or> a = 2" by arith
  then show ?thesis by auto
qed

lemma mod12_cong: "x = y + 12 * k \<Longrightarrow> x mod 12 = (y :: int) mod 12"
  by simp

lemma mod12_eq: "u mod 12 = u - 12 * (u div 12 :: int)"
  using minus_div_mult_eq_mod[of u 12] by (simp add: mult.commute)

lemma mod12_sub: "(u mod 12 - v mod 12) mod 12 = (u - v :: int) mod 12"
proof -
  have "u mod 12 - v mod 12 = (u - v) + 12 * (v div 12 - u div 12)"
    by (subst mod12_eq[of u], subst mod12_eq[of v]) (simp add: algebra_simps)
  then show ?thesis by (rule mod12_cong)
qed

lemma mod12_diff: "(u mod 12 - v mod 12 - ((u - v) + 12 * t) :: int) mod 12 = 0"
proof -
  have "u mod 12 - v mod 12 - ((u - v) + 12 * t) = 0 + 12 * (v div 12 - u div 12 - t)"
    by (subst mod12_eq[of u], subst mod12_eq[of v]) (simp add: algebra_simps)
  then have "(u mod 12 - v mod 12 - ((u - v) + 12 * t)) mod 12 = (0::int) mod 12" by (rule mod12_cong)
  then show ?thesis by simp
qed

lemma mod12_rep: "k = (d :: int) mod 12 \<Longrightarrow> k = d + 12 * (- (d div 12))"
  using minus_div_mult_eq_mod[of d 12] by linarith

lemma pc_fold: "((L0 :: int) + ((p - L0 + 6) mod 12 - 6)) mod 12 = p mod 12"
proof -
  have "L0 + ((p - L0 + 6) mod 12 - 6) = p + 12 * (- ((p - L0 + 6) div 12))"
    by (subst mod12_eq[of "p - L0 + 6"]) (simp add: algebra_simps)
  then show ?thesis by (rule mod12_cong)
qed

lemma lidx_lstep: "lidx (lstep i L) = (lidx L + i) mod 7"
proof (induction i arbitrary: L)
  case 0
  show ?case by (cases L) simp_all
next
  case (Suc i)
  have a: "lidx (lstep i (lup L)) = (lidx (lup L) + i) mod 7" by (rule Suc.IH)
  have b: "lidx (lup L) = (lidx L + 1) mod 7" by (rule lidx_lup)
  have c: "lidx (lstep (Suc i) L) = lidx (lstep i (lup L))" by simp
  have d: "((lidx L + 1) mod 7 + i) mod 7 = (lidx L + 1 + i) mod 7" by (rule mod_add_left_eq)
  show ?case using a b c d by simp
qed

section \<open>Key signatures\<close>

text \<open>Position on the line of fifths (F = -1, C = 0, G = 1, ...). A major key with
tonic letter L and a accidentals has @{text "lof L + 7a"} sharps (flats if negative);
the natural minor has three fewer.\<close>
fun lof :: "letter \<Rightarrow> int" where
  "lof N_F = -1" | "lof N_C = 0" | "lof N_G = 1" | "lof N_D = 2"
| "lof N_A = 3" | "lof N_E = 4" | "lof N_B = 5"

definition fifths :: "letter \<Rightarrow> int \<Rightarrow> bool \<Rightarrow> int" where
  "fifths L a m = lof L + 7 * a - (if m then 3 else 0)"

definition keysig_of :: "pnote \<Rightarrow> bool \<Rightarrow> int option" where
  "keysig_of n m = (if \<bar>fifths (fst n) (snd n) m\<bar> \<le> 7 then Some (fifths (fst n) (snd n) m) else None)"

text \<open>The organ's four lists (SHARP_MAJ, FLAT_MAJ, SHARP_MIN, FLAT_MIN) of keys with
sharps or flats, in order of the number of accidentals.\<close>
definition sharp_maj :: "pnote list" where
  "sharp_maj = [(N_C, 0), (N_G, 0), (N_D, 0), (N_A, 0), (N_E, 0), (N_B, 0), (N_F, 1), (N_C, 1)]"
definition flat_maj :: "pnote list" where
  "flat_maj = [(N_C, 0), (N_F, 0), (N_B, -1), (N_E, -1), (N_A, -1), (N_D, -1), (N_G, -1), (N_C, -1)]"
definition sharp_min :: "pnote list" where
  "sharp_min = [(N_A, 0), (N_E, 0), (N_B, 0), (N_F, 1), (N_C, 1), (N_G, 1), (N_D, 1), (N_A, 1)]"
definition flat_min :: "pnote list" where
  "flat_min = [(N_A, 0), (N_D, 0), (N_G, 0), (N_C, 0), (N_F, 0), (N_B, -1), (N_E, -1), (N_A, -1)]"

fun idx_of :: "'a \<Rightarrow> 'a list \<Rightarrow> nat" where
  "idx_of x [] = 0" | "idx_of x (y # ys) = (if x = y then 0 else Suc (idx_of x ys))"

definition sharp_list :: "bool \<Rightarrow> pnote list" where
  "sharp_list m = (if m then sharp_min else sharp_maj)"
definition flat_list :: "bool \<Rightarrow> pnote list" where
  "flat_list m = (if m then flat_min else flat_maj)"

text \<open>The organ's procedure, read off the lists.\<close>
definition keysig_table :: "pnote \<Rightarrow> bool \<Rightarrow> int option" where
  "keysig_table n m =
    (if n \<in> set (sharp_list m) \<and> n \<noteq> hd (sharp_list m) then Some (int (idx_of n (sharp_list m)))
     else if n \<in> set (flat_list m) \<and> n \<noteq> hd (flat_list m) then Some (- int (idx_of n (flat_list m)))
     else if n = hd (sharp_list m) then Some 0 else None)"

lemma keysig_table_all:
  "list_all (\<lambda>L. list_all (\<lambda>a. list_all (\<lambda>m. keysig_table (L, a) m = keysig_of (L, a) m) [False, True])
      [-2, -1, 0, 1, 2]) [N_C, N_D, N_E, N_F, N_G, N_A, N_B]"
  by (code_simp | simp add: keysig_table_def keysig_of_def fifths_def sharp_list_def flat_list_def
      sharp_maj_def flat_maj_def sharp_min_def flat_min_def)

text \<open>The formula (line of fifths) is the organ's table: for every spelling with at most
two accidentals, the key has a signature exactly when the organ lists it, and the number
agrees.\<close>
theorem keysig_formula_is_table:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "keysig_table n m = keysig_of n m"
proof -
  obtain L a where n: "n = (L, a)" by (cases n)
  have h: "\<bar>a\<bar> \<le> 2" using assms n by simp
  have a: "a \<in> set [-2, -1, 0, 1, 2 :: int]" by (rule abs_le2[OF h])
  have L: "L \<in> set [N_C, N_D, N_E, N_F, N_G, N_A, N_B]" by (cases L) simp_all
  have mm: "m \<in> set [False, True]" by simp
  have all: "\<forall>L\<in>set [N_C, N_D, N_E, N_F, N_G, N_A, N_B]. \<forall>a\<in>set [-2, -1, 0, 1, 2 :: int].
      \<forall>m\<in>set [False, True]. keysig_table (L, a) m = keysig_of (L, a) m"
    using keysig_table_all by (simp only: list_all_iff)
  show ?thesis unfolding n using all L a mm by blast
qed

text \<open>The circle of fifths: the tonic's pitch class is seven semitones per sharp
(major), and nine more for the relative minor, modulo 12.\<close>
lemma pc_lof: "nat_pc L mod 12 = (7 * lof L) mod 12"
  by (cases L) simp_all

theorem keysig_circle_of_fifths:
  "(nat_pc L + a) mod 12 = (7 * fifths L a m + (if m then 9 else 0)) mod 12"
proof -
  have h1: "(nat_pc L + a) mod 12 = (7 * lof L + a) mod 12"
    by (rule mod_add_cong[OF pc_lof]) simp
  have h2: "7 * fifths L a m + (if m then 9 else 0) = (7 * lof L + a) + 12 * (4 * a - (if m then 1 else 0))"
    by (cases m) (simp_all add: fifths_def algebra_simps)
  have "(7 * fifths L a m + (if m then 9 else 0)) mod 12 = (7 * lof L + a) mod 12"
    by (rule mod12_cong[OF h2])
  then show ?thesis using h1 by simp
qed

section \<open>Relative keys\<close>

definition rel_letter :: "letter \<Rightarrow> bool \<Rightarrow> letter" where
  "rel_letter L m = (if m then lup (lup L) else lup (lup (lup (lup (lup L)))))"

definition rel_key :: "pnote \<Rightarrow> bool \<Rightarrow> pnote" where
  "rel_key n m = (let L2 = rel_letter (fst n) m;
                      pc2 = (nat_pc (fst n) + snd n + (if m then 3 else 9)) mod 12
                  in (L2, (pc2 - nat_pc L2 + 6) mod 12 - 6))"

lemma acc5: "\<bar>a :: int\<bar> \<le> 2 \<Longrightarrow> a = -2 \<or> a = -1 \<or> a = 0 \<or> a = 1 \<or> a = 2"
  by (simp add: abs_le_iff) arith

theorem rel_key_pitch:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "pcn (rel_key n m) = (pcn n + (if m then 3 else 9)) mod 12"
proof -
  obtain L a where n: "n = (L, a)" by (cases n)
  have "a = -2 \<or> a = -1 \<or> a = 0 \<or> a = 1 \<or> a = 2" using acc5 assms n by simp
  then show ?thesis by (cases L; cases m; elim disjE; simp add: n pcn_def rel_key_def rel_letter_def Let_def)
qed

theorem rel_key_letter:
  "lidx (fst (rel_key n m)) = (lidx (fst n) + (if m then 2 else 5)) mod 7"
proof -
  obtain L a where n: "n = (L, a)" by (cases n)
  show ?thesis by (cases L; cases m; simp add: n rel_key_def rel_letter_def Let_def)
qed

text \<open>A relative pair shares one key signature.\<close>
theorem rel_key_signature:
  assumes "\<bar>snd n\<bar> \<le> 2"
  shows "fifths (fst (rel_key n m)) (snd (rel_key n m)) (\<not> m) = fifths (fst n) (snd n) m"
proof -
  obtain L a where n: "n = (L, a)" by (cases n)
  have "a = -2 \<or> a = -1 \<or> a = 0 \<or> a = 1 \<or> a = 2" using acc5 assms n by simp
  then show ?thesis by (cases L; cases m; elim disjE; simp add: n fifths_def rel_key_def rel_letter_def Let_def)
qed

section \<open>Scales\<close>

definition steps :: "bool \<Rightarrow> int list" where
  "steps m = (if m then [2, 1, 2, 2, 1, 2, 2] else [2, 2, 1, 2, 2, 2, 1])"

definition off_at :: "bool \<Rightarrow> nat \<Rightarrow> int" where
  "off_at m i = sum_list (take i (steps m))"

definition scale_note :: "pnote \<Rightarrow> bool \<Rightarrow> nat \<Rightarrow> pnote" where
  "scale_note n m i = (let L = lstep i (fst n); p = nat_pc (fst n) + snd n + off_at m i
                       in (L, (p - nat_pc L + 6) mod 12 - 6))"

definition scale_notes :: "pnote \<Rightarrow> bool \<Rightarrow> pnote list" where
  "scale_notes n m = map (scale_note n m) [0..<7]"

theorem scale_steps_close: "sum_list (steps m) = 12"
  by (cases m; simp add: steps_def)

theorem scale_note_letter: "fst (scale_note n m i) = lstep i (fst n)"
  by (simp add: scale_note_def Let_def)

theorem scale_note_pitch: "pcn (scale_note n m i) = (pcn n + off_at m i) mod 12"
proof -
  define p where "p = nat_pc (fst n) + snd n + off_at m i"
  have "pcn (scale_note n m i) = (nat_pc (lstep i (fst n)) + ((p - nat_pc (lstep i (fst n)) + 6) mod 12 - 6)) mod 12"
    by (simp add: pcn_def scale_note_def Let_def p_def)
  also have "\<dots> = p mod 12" by (rule pc_fold)
  also have "\<dots> = (pcn n + off_at m i) mod 12" by (simp add: p_def pcn_def mod_add_left_eq add.assoc)
  finally show ?thesis .
qed

theorem scale_first: "\<bar>snd n\<bar> \<le> 2 \<Longrightarrow> scale_note n m 0 = n"
proof -
  assume h: "\<bar>snd n\<bar> \<le> 2"
  obtain L a where n: "n = (L, a)" by (cases n)
  have "a \<in> set [-2, -1, 0, 1, 2 :: int]" using abs_le2[of a] h n by simp
  then show ?thesis by (auto simp: n scale_note_def off_at_def Let_def)
qed

text \<open>Adjacent degrees are one letter apart and a whole or half step apart.\<close>
theorem scale_adjacent:
  assumes "i < 6"
  shows "lidx (fst (scale_note n m (Suc i))) = (lidx (fst (scale_note n m i)) + 1) mod 7"
proof -
  have d: "((lidx (fst n) + i) mod 7 + 1) mod 7 = (lidx (fst n) + i + 1) mod 7" by (rule mod_add_left_eq)
  have "lidx (fst (scale_note n m (Suc i))) = (lidx (fst n) + Suc i) mod 7"
    by (simp only: scale_note_letter lidx_lstep)
  moreover have "lidx (fst (scale_note n m i)) = (lidx (fst n) + i) mod 7"
    by (simp only: scale_note_letter lidx_lstep)
  ultimately show ?thesis using d by simp
qed

lemma off_at_Suc: "i < 7 \<Longrightarrow> off_at m (Suc i) = off_at m i + steps m ! i"
proof -
  assume i: "i < 7"
  have l: "length (steps m) = 7" by (cases m; simp add: steps_def)
  show ?thesis using i l by (simp add: off_at_def take_Suc_conv_app_nth)
qed

theorem scale_adjacent_distance:
  assumes "i < 7"
  shows "(pcn (scale_note n m (Suc i)) - pcn (scale_note n m i)) mod 12 = steps m ! i mod 12"
proof -
  have a: "pcn (scale_note n m (Suc i)) = (pcn n + off_at m (Suc i)) mod 12" by (rule scale_note_pitch)
  have b: "pcn (scale_note n m i) = (pcn n + off_at m i) mod 12" by (rule scale_note_pitch)
  have c: "off_at m (Suc i) = off_at m i + steps m ! i" by (rule off_at_Suc[OF assms])
  define X where "X = pcn n + off_at m i"
  have "(pcn (scale_note n m (Suc i)) - pcn (scale_note n m i)) mod 12 = (((X + steps m ! i) mod 12) - (X mod 12)) mod 12"
    using a b c by (simp add: X_def add.assoc)
  also have "\<dots> = ((X + steps m ! i) - X) mod 12" by (rule mod12_sub)
  also have "\<dots> = steps m ! i mod 12" by simp
  finally show ?thesis .
qed

definition sig_ok :: "pnote list \<Rightarrow> bool" where
  "sig_ok ns = list_all (\<lambda>x. \<bar>snd x\<bar> \<le> 1) ns"

definition count_acc :: "int \<Rightarrow> pnote list \<Rightarrow> nat" where
  "count_acc a ns = length (filter (\<lambda>x. snd x = a) ns)"

lemma scale_signature_all:
  "list_all (\<lambda>L. list_all (\<lambda>a. list_all (\<lambda>m.
      (case keysig_of (L, a) m of None \<Rightarrow> True
       | Some k \<Rightarrow> sig_ok (scale_notes (L, a) m) \<and> count_acc 1 (scale_notes (L, a) m) = nat k
                   \<and> count_acc (-1) (scale_notes (L, a) m) = nat (- k))) [False, True])
      [-2, -1, 0, 1, 2]) [N_C, N_D, N_E, N_F, N_G, N_A, N_B]"
  by (code_simp | simp add: sig_ok_def count_acc_def scale_notes_def scale_note_def off_at_def steps_def
      keysig_of_def fifths_def Let_def)

text \<open>The scale of a key that has a signature uses exactly the sharps (or flats) the
signature has, once each, and no double accidental.\<close>
theorem scale_matches_signature:
  assumes "\<bar>snd n\<bar> \<le> 2" "keysig_of n m = Some k"
  shows "sig_ok (scale_notes n m) \<and> count_acc 1 (scale_notes n m) = nat k
         \<and> count_acc (-1) (scale_notes n m) = nat (- k)"
proof -
  obtain L a where n: "n = (L, a)" by (cases n)
  have h: "\<bar>a\<bar> \<le> 2" using assms(1) n by simp
  have a: "a \<in> set [-2, -1, 0, 1, 2 :: int]" by (rule abs_le2[OF h])
  have L: "L \<in> set [N_C, N_D, N_E, N_F, N_G, N_A, N_B]" by (cases L) simp_all
  have mm: "m \<in> set [False, True]" by simp
  have all: "\<forall>L\<in>set [N_C, N_D, N_E, N_F, N_G, N_A, N_B]. \<forall>a\<in>set [-2, -1, 0, 1, 2 :: int].
      \<forall>m\<in>set [False, True].
      (case keysig_of (L, a) m of None \<Rightarrow> True
       | Some k \<Rightarrow> sig_ok (scale_notes (L, a) m) \<and> count_acc 1 (scale_notes (L, a) m) = nat k
                   \<and> count_acc (-1) (scale_notes (L, a) m) = nat (- k))"
    using scale_signature_all by (simp only: list_all_iff)
  have "(case keysig_of (L, a) m of None \<Rightarrow> True
       | Some k \<Rightarrow> sig_ok (scale_notes (L, a) m) \<and> count_acc 1 (scale_notes (L, a) m) = nat k
                   \<and> count_acc (-1) (scale_notes (L, a) m) = nat (- k))"
    using all L a mm by blast
  then show ?thesis using assms(2) n by simp
qed

section \<open>Intervals\<close>

datatype quality = Q_dim | Q_min | Q_maj | Q_perf | Q_aug

text \<open>The organ's QUAL: (letter steps, semitones, quality).\<close>
definition qual_rows :: "(nat \<times> int \<times> quality) list" where
  "qual_rows = [(0, 0, Q_perf), (0, 1, Q_aug),
    (1, 0, Q_dim), (1, 1, Q_min), (1, 2, Q_maj), (1, 3, Q_aug),
    (2, 2, Q_dim), (2, 3, Q_min), (2, 4, Q_maj), (2, 5, Q_aug),
    (3, 4, Q_dim), (3, 5, Q_perf), (3, 6, Q_aug),
    (4, 6, Q_dim), (4, 7, Q_perf), (4, 8, Q_aug),
    (5, 7, Q_dim), (5, 8, Q_min), (5, 9, Q_maj), (5, 10, Q_aug),
    (6, 9, Q_dim), (6, 10, Q_min), (6, 11, Q_maj),
    (7, 11, Q_dim), (7, 12, Q_perf)]"

definition qual_lookup :: "nat \<Rightarrow> int \<Rightarrow> quality option" where
  "qual_lookup s k = (case List.find (\<lambda>r. fst r = s \<and> fst (snd r) = k) qual_rows of
      Some r \<Rightarrow> Some (snd (snd r)) | None \<Rightarrow> None)"

definition major_base :: "nat \<Rightarrow> int" where
  "major_base s = (if s = 0 then 0 else if s = 1 then 2 else if s = 2 then 4 else if s = 3 then 5
     else if s = 4 then 7 else if s = 5 then 9 else if s = 6 then 11 else 12)"

definition perfect_type :: "nat \<Rightarrow> bool" where
  "perfect_type s \<longleftrightarrow> s = 0 \<or> s = 3 \<or> s = 4 \<or> s = 7"

definition qdelta :: "bool \<Rightarrow> quality \<Rightarrow> int" where
  "qdelta p q = (case q of Q_perf \<Rightarrow> 0 | Q_maj \<Rightarrow> 0 | Q_min \<Rightarrow> -1 | Q_aug \<Rightarrow> 1
                 | Q_dim \<Rightarrow> (if p then -1 else -2))"

text \<open>The organ's table is the textbook rule: the semitones of a diatonic interval are
those of the major (or perfect) interval, one more if augmented, one fewer if minor or
(perfect type) diminished, two fewer if diminished (major type). Perfect qualities only
for the perfect types, major and minor only for the others.\<close>
theorem qual_rows_rule:
  "\<forall>r \<in> set qual_rows. (case r of (s, k, q) \<Rightarrow>
      k = major_base s + qdelta (perfect_type s) q
      \<and> (perfect_type s \<longrightarrow> q \<noteq> Q_maj \<and> q \<noteq> Q_min)
      \<and> (\<not> perfect_type s \<longrightarrow> q \<noteq> Q_perf))"
  by (simp add: qual_rows_def major_base_def perfect_type_def qdelta_def)

theorem qual_rows_distinct:
  "distinct (map (\<lambda>r. (fst r, fst (snd r))) qual_rows)"
  by (simp add: qual_rows_def)

theorem qual_lookup_sound:
  "qual_lookup s k = Some q \<Longrightarrow> (s, k, q) \<in> set qual_rows"
proof -
  assume h: "qual_lookup s k = Some q"
  then obtain r where r: "List.find (\<lambda>r. fst r = s \<and> fst (snd r) = k) qual_rows = Some r"
    and q: "q = snd (snd r)"
    by (auto simp: qual_lookup_def split: option.splits)
  from r[unfolded find_Some_iff] obtain i where i: "i < length qual_rows" "fst (qual_rows ! i) = s \<and> fst (snd (qual_rows ! i)) = k"
    "r = qual_rows ! i"
    by blast
  have "(s, k, q) = qual_rows ! i" using i q by (metis prod.collapse)
  then show ?thesis using i(1) by (metis nth_mem)
qed

definition step_name :: "nat \<Rightarrow> String.literal" where
  "step_name s = (if s = 0 then STR ''unison'' else if s = 1 then STR ''second'' else if s = 2 then STR ''third''
     else if s = 3 then STR ''fourth'' else if s = 4 then STR ''fifth'' else if s = 5 then STR ''sixth''
     else if s = 6 then STR ''seventh'' else STR ''octave'')"

fun qual_word :: "quality \<Rightarrow> String.literal" where
  "qual_word Q_dim = STR ''diminished''" | "qual_word Q_min = STR ''minor''"
| "qual_word Q_maj = STR ''major''" | "qual_word Q_perf = STR ''perfect''"
| "qual_word Q_aug = STR ''augmented''"

definition iname :: "nat \<Rightarrow> quality \<Rightarrow> String.literal" where
  "iname s q = qual_word q + STR '' '' + step_name s"

text \<open>Named intervals asked as "how many semitones": the organ's IVL, in the order the
organ tries them (longest name first, ties in table order).\<close>
definition ivl_order :: "(String.literal \<times> int) list" where
  "ivl_order = [(STR ''diminished seventh'', 9),
    (STR ''augmented fourth'', 6),
    (STR ''diminished fifth'', 6),
    (STR ''augmented fifth'', 8),
    (STR ''perfect fourth'', 5),
    (STR ''perfect octave'', 12),
    (STR ''perfect fifth'', 7),
    (STR ''minor seventh'', 10),
    (STR ''major seventh'', 11),
    (STR ''minor second'', 1),
    (STR ''major second'', 2),
    (STR ''minor third'', 3),
    (STR ''major third'', 4),
    (STR ''minor sixth'', 8),
    (STR ''major sixth'', 9),
    (STR ''minor ninth'', 13),
    (STR ''major ninth'', 14),
    (STR ''tritone'', 6),
    (STR ''unison'', 0),
    (STR ''octave'', 12)]"

definition midi_num :: "pnote \<Rightarrow> int \<Rightarrow> int" where
  "midi_num n oct = 12 * (oct + 1) + nat_pc (fst n) + snd n"

theorem midi_pitch: "midi_num n oct mod 12 = pcn n"
proof -
  have "midi_num n oct = (nat_pc (fst n) + snd n) + 12 * (oct + 1)" by (simp add: midi_num_def)
  then show ?thesis unfolding pcn_def by (rule mod12_cong[where k = "oct + 1"])
qed

definition bsel :: "nat \<Rightarrow> int \<Rightarrow> int \<Rightarrow> (nat \<times> int) option" where
  "bsel st semi sp = (if sp < 0 \<or> sp > 12 then None
                      else if sp = 12 \<and> st = 0 then Some (7, 12)
                      else if sp \<noteq> semi then None else Some (st, semi))"

lemma bsel_sound:
  "bsel st semi sp = Some (s, k) \<Longrightarrow> k = sp \<and> 0 \<le> sp \<and> sp \<le> 12 \<and> (s = 7 \<or> s = st)"
  by (auto simp: bsel_def split: if_splits)

definition between :: "pnote \<Rightarrow> int option \<Rightarrow> pnote \<Rightarrow> int option \<Rightarrow> (nat \<times> int) option" where
  "between n1 o1 n2 o2 =
     (let st = (lidx (fst n2) + 7 - lidx (fst n1)) mod 7;
          semi = (nat_pc (fst n2) + snd n2 - nat_pc (fst n1) - snd n1) mod 12
      in case (o1, o2) of
           (None, None) \<Rightarrow> Some (st, semi)
         | (Some x, Some y) \<Rightarrow> bsel st semi (midi_num n2 y - midi_num n1 x)
         | _ \<Rightarrow> None)"

text \<open>The distance up from the first note to the second: the semitone count is the
pitch-class difference (and the octave difference when octaves are given), the letter
steps are the letter distance.\<close>
theorem between_sound:
  assumes "between n1 o1 n2 o2 = Some (st, k)"
  shows "0 \<le> k \<and> k \<le> 12 \<and> st \<le> 7 \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
         \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)
         \<and> (st < 7 \<longrightarrow> st = (lidx (fst n2) + 7 - lidx (fst n1)) mod 7)"
proof -
  define u1 where "u1 = nat_pc (fst n1) + snd n1"
  define u2 where "u2 = nat_pc (fst n2) + snd n2"
  define st0 where "st0 = (lidx (fst n2) + 7 - lidx (fst n1)) mod 7"
  define semi where "semi = (u2 - u1) mod 12"
  have sem: "semi = (nat_pc (fst n2) + snd n2 - nat_pc (fst n1) - snd n1) mod 12"
    by (simp add: semi_def u1_def u2_def algebra_simps)
  have st7: "st0 < 7" by (simp add: st0_def)
  have s0: "0 \<le> semi" and s12: "semi < 12" by (simp_all add: semi_def)
  have pc: "pcn n2 - pcn n1 = u2 mod 12 - u1 mod 12" by (simp add: pcn_def u1_def u2_def)
  have rep: "semi = (u2 - u1) + 12 * (- ((u2 - u1) div 12))" by (rule mod12_rep) (simp add: semi_def)
  have mm: "\<forall>x y. midi_num n2 y - midi_num n1 x = (u2 - u1) + 12 * (y - x)"
    by (simp add: midi_num_def u1_def u2_def algebra_simps)
  show ?thesis
  proof (cases o1; cases o2)
    assume n: "o1 = None" "o2 = None"
    then have e: "st = st0" "k = semi" using assms by (simp_all add: between_def Let_def st0_def sem)
    have "(pcn n2 - pcn n1 - k) mod 12 = 0" using mod12_diff[of u2 u1 "- ((u2 - u1) div 12)"] pc rep e by simp
    then show ?thesis using e s0 s12 st7 n by (simp add: st0_def)
  next
    fix y assume "o1 = None" "o2 = Some y"
    then show ?thesis using assms by (simp add: between_def Let_def)
  next
    fix x assume "o1 = Some x" "o2 = None"
    then show ?thesis using assms by (simp add: between_def Let_def)
  next
    fix x y assume o: "o1 = Some x" "o2 = Some y"
    define sp where "sp = midi_num n2 y - midi_num n1 x"
    have spd: "sp = (u2 - u1) + 12 * (y - x)" using mm by (simp add: sp_def)
    have unf: "bsel st0 semi sp = Some (st, k)"
      using assms o by (simp add: between_def Let_def sp_def st0_def sem)
    have key: "k = sp \<and> 0 \<le> sp \<and> sp \<le> 12 \<and> (st = 7 \<or> st = st0)" by (rule bsel_sound[OF unf])
    have "(pcn n2 - pcn n1 - k) mod 12 = 0"
      using mod12_diff[of u2 u1 "y - x"] pc key spd by simp
    moreover have "\<forall>x' y'. o1 = Some x' \<longrightarrow> o2 = Some y' \<longrightarrow> midi_num n2 y' - midi_num n1 x' = k"
      using o key sp_def by simp
    moreover have "st < 7 \<longrightarrow> st = st0" using key by auto
    ultimately show ?thesis using key o st0_def by auto
  qed
qed

section \<open>MIDI\<close>

text \<open>The organ's sharp-spelled note names by pitch class.\<close>
definition chroma :: "pnote list" where
  "chroma = [(N_C, 0), (N_C, 1), (N_D, 0), (N_D, 1), (N_E, 0), (N_F, 0), (N_F, 1), (N_G, 0),
             (N_G, 1), (N_A, 0), (N_A, 1), (N_B, 0)]"

lemma chroma_pc_all:
  "list_all (\<lambda>k. nat_pc (fst (chroma ! k)) + snd (chroma ! k) = int k) [0..<12]"
  by (code_simp | simp add: chroma_def)

lemma chroma_pc: "k < 12 \<Longrightarrow> nat_pc (fst (chroma ! k)) + snd (chroma ! k) = int k"
  using chroma_pc_all by (simp add: list_all_iff)

definition chroma_at :: "int \<Rightarrow> pnote" where
  "chroma_at k = chroma ! nat (k mod 12)"

theorem midi_name_roundtrip:
  "midi_num (chroma_at k) (k div 12 - 1) = k"
proof -
  have b: "k mod 12 < 12" by simp
  have z: "0 \<le> k mod 12" by simp
  have "nat (k mod 12) < 12" using b z by (simp add: nat_less_iff)
  from chroma_pc[OF this] have e: "nat_pc (fst (chroma ! nat (k mod 12))) + snd (chroma ! nat (k mod 12)) = k mod 12"
    using z by simp
  have "midi_num (chroma_at k) (k div 12 - 1) = 12 * (k div 12) + (nat_pc (fst (chroma ! nat (k mod 12))) + snd (chroma ! nat (k mod 12)))"
    by (simp add: chroma_at_def midi_num_def algebra_simps)
  also have "\<dots> = 12 * (k div 12) + k mod 12" using e by simp
  also have "\<dots> = k" by simp
  finally show ?thesis .
qed

section \<open>Durations\<close>

datatype dur = D_whole | D_half | D_quarter | D_eighth | D_sixteenth | D_thirty_second

fun beats_of :: "dur \<Rightarrow> rat" where
  "beats_of D_whole = 4" | "beats_of D_half = 2" | "beats_of D_quarter = 1"
| "beats_of D_eighth = 1 / 2" | "beats_of D_sixteenth = 1 / 4" | "beats_of D_thirty_second = 1 / 8"

definition beats :: "bool \<Rightarrow> dur \<Rightarrow> rat" where
  "beats dotted v = beats_of v * (if dotted then 3 / 2 else 1)"

definition dur_secs :: "rat \<Rightarrow> bool \<Rightarrow> dur \<Rightarrow> rat" where
  "dur_secs b dotted v = 60 / b * beats dotted v"

theorem dur_defining: "b \<noteq> 0 \<Longrightarrow> dur_secs b dotted v * b = 60 * beats dotted v"
  by (simp add: dur_secs_def field_simps)

theorem dur_quarter_60: "dur_secs 60 False D_quarter = 1"
  by (simp add: dur_secs_def beats_def)

theorem beats_halving:
  "beats_of D_whole = 2 * beats_of D_half \<and> beats_of D_half = 2 * beats_of D_quarter
   \<and> beats_of D_quarter = 2 * beats_of D_eighth \<and> beats_of D_eighth = 2 * beats_of D_sixteenth
   \<and> beats_of D_sixteenth = 2 * beats_of D_thirty_second"
  by simp

theorem dotted_adds_half: "beats True v = beats False v + beats False v / 2"
  by (simp add: beats_def field_simps)

fun dur_name :: "dur \<Rightarrow> String.literal" where
  "dur_name D_whole = STR ''whole''" | "dur_name D_half = STR ''half''"
| "dur_name D_quarter = STR ''quarter''" | "dur_name D_eighth = STR ''eighth''"
| "dur_name D_sixteenth = STR ''sixteenth''" | "dur_name D_thirty_second = STR ''thirty-second''"

section \<open>Equal temperament and cents\<close>

definition phys_freq :: "rat \<Rightarrow> int \<Rightarrow> real" where
  "phys_freq A k = rl A * 2 powr (of_int (k - 69) / 12)"

definition freq_fa :: "rat \<Rightarrow> int \<Rightarrow> floatarith" where
  "freq_fa A k = floatarith.Mult (Q A)
     (floatarith.Exp (floatarith.Mult (Q (of_int (k - 69) / 12)) (floatarith.Ln (I 2))))"

lemma interp_freq [simp]: "interpret_floatarith (freq_fa A k) xs = phys_freq A k"
proof -
  have "rl (of_int (k - 69) / 12 :: rat) = of_int (k - 69) / 12"
    by (simp add: of_rat_divide of_rat_diff of_rat_of_int_eq)
  then show ?thesis by (simp add: freq_fa_def phys_freq_def powr_def)
qed

theorem freq_a4: "phys_freq A 69 = rl A"
  by (simp add: phys_freq_def)

theorem freq_octave: "phys_freq A (k + 12) = 2 * phys_freq A k"
proof -
  have e: "(of_int (k + 12 - 69) / 12 :: real) = of_int (k - 69) / 12 + 1"
    by (simp add: field_simps)
  have "(2::real) powr (of_int (k + 12 - 69) / 12) = 2 powr (of_int (k - 69) / 12 + 1)"
    by (simp only: e)
  also have "\<dots> = 2 powr (of_int (k - 69) / 12) * 2 powr 1" by (rule powr_add)
  also have "\<dots> = 2 powr (of_int (k - 69) / 12) * 2" by (simp add: powr_one)
  finally show ?thesis by (simp add: phys_freq_def)
qed

theorem freq_semitone:
  assumes "0 < A"
  shows "(phys_freq A (k + 1) / phys_freq A k) ^ 12 = 2"
proof -
  have A: "(0::real) < rl A" using assms by (simp add: zero_less_of_rat_iff)
  have A0: "rl A \<noteq> 0" using A by simp
  have A1: "A \<noteq> 0" using assms by simp
  have P: "(0::real) < 2 powr (of_int (k - 69) / 12)" by simp
  have P0: "(2::real) powr (of_int (k - 69) / 12) \<noteq> 0" using P by simp
  have e: "(of_int (k + 1 - 69) / 12 :: real) = of_int (k - 69) / 12 + 1 / 12"
    by (simp add: field_simps)
  have h1: "phys_freq A (k + 1) = rl A * (2 powr (of_int (k - 69) / 12) * 2 powr (1 / 12))"
    unfolding phys_freq_def by (simp only: e powr_add)
  have h2: "phys_freq A k = rl A * 2 powr (of_int (k - 69) / 12)" by (simp add: phys_freq_def)
  have r: "phys_freq A (k + 1) / phys_freq A k = 2 powr (1 / 12)"
    unfolding h1 h2 by (simp add: field_simps A0 A1 P0)
  have "(2 powr (1 / 12 :: real)) ^ 12 = (2 powr (1 / 12 :: real)) powr (real 12)"
    by (rule powr_realpow[symmetric]) simp
  also have "\<dots> = 2 powr (1 / 12 * real 12)" by (simp add: powr_powr)
  also have "\<dots> = 2" by simp
  finally show ?thesis using r by simp
qed

definition phys_cents :: "rat \<Rightarrow> rat \<Rightarrow> real" where
  "phys_cents f1 f2 = 1200 * log 2 (rl f2 / rl f1)"

definition cents_fa :: "rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "cents_fa f1 f2 = floatarith.Mult (I 1200)
     (floatarith.Mult (floatarith.Ln (floatarith.Mult (Q f2) (floatarith.Inverse (Q f1))))
        (floatarith.Inverse (floatarith.Ln (I 2))))"

lemma interp_cents [simp]: "interpret_floatarith (cents_fa f1 f2) xs = phys_cents f1 f2"
  by (simp add: cents_fa_def phys_cents_def log_def divide_inverse)

text \<open>Cents measure the frequency ratio on a logarithmic scale: the ratio is two to the
power of cents over 1200.\<close>
theorem cents_model:
  assumes "0 < f1" "0 < f2"
  shows "2 powr (phys_cents f1 f2 / 1200) = rl f2 / rl f1"
proof -
  have a: "(0::real) < rl f1" and b: "(0::real) < rl f2" using assms by (simp_all add: zero_less_of_rat_iff)
  have "phys_cents f1 f2 / 1200 = log 2 (rl f2 / rl f1)" by (simp add: phys_cents_def)
  moreover have "(2::real) powr log 2 (rl f2 / rl f1) = rl f2 / rl f1"
    using a b by simp
  ultimately show ?thesis by simp
qed

section \<open>Requests and outcomes\<close>

datatype mreq =
    MCents rat rat
  | MDur rat bool dur
  | MKey pnote bool
  | MRel pnote bool
  | MScale pnote bool
  | MSemis "bool list"
  | MBetween pnote "int option" pnote "int option" bool
  | MMidiNote int
  | MMidiNum pnote "int option"
  | MFreq pnote "int option" rat

datatype mdecl = ImpKey | ImpScale | ImpMidiNum | ImpMidiRange | UnderMidi | UnderFreq | Imprecise

datatype mout =
    Silent
  | Decline mdecl
  | OCents "int \<times> int"
  | ODur rat
  | OSig int
  | ORel pnote
  | OScale "pnote list"
  | OSemis "String.literal \<times> int"
  | OBetween int
  | OIvl nat int quality
  | OMidiNote pnote int
  | OMidiNum int
  | OFreq "int \<times> int"

fun mkernel :: "mreq \<Rightarrow> mout" where
  "mkernel (MCents f1 f2) =
     (if 0 < f1 \<and> 0 < f2 then
        (case enclose3 prec (cents_fa f1 f2) of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> OCents d)
      else Silent)"
| "mkernel (MDur b dotted v) = (if 0 < b then ODur (dur_secs b dotted v) else Silent)"
| "mkernel (MKey n m) =
     (if spellable n then
        (case keysig_of n m of Some k \<Rightarrow> OSig k | None \<Rightarrow> Decline ImpKey)
      else Silent)"
| "mkernel (MRel n m) = (if spellable n \<and> spellable (rel_key n m) then ORel (rel_key n m) else Silent)"
| "mkernel (MScale n m) =
     (if spellable n then
        (if sig_ok (scale_notes n m) then OScale (scale_notes n m) else Decline ImpScale)
      else Silent)"
| "mkernel (MSemis bs) = (case pick bs ivl_order of Some r \<Rightarrow> OSemis r | None \<Rightarrow> Silent)"
| "mkernel (MBetween n1 o1 n2 o2 asks) =
     (if spellable n1 \<and> spellable n2 then
        (case between n1 o1 n2 o2 of
           None \<Rightarrow> Silent
         | Some (st, k) \<Rightarrow>
             if asks then OBetween k
             else (case qual_lookup st k of Some q \<Rightarrow> OIvl st k q | None \<Rightarrow> Silent))
      else Silent)"
| "mkernel (MMidiNote k) =
     (if k < 0 then Silent else if k \<le> 127 then OMidiNote (chroma_at k) (k div 12 - 1)
      else Decline ImpMidiNum)"
| "mkernel (MMidiNum n oc) =
     (case oc of None \<Rightarrow> Decline UnderMidi
      | Some oct \<Rightarrow>
          if \<not> spellable n then Silent
          else if 0 \<le> midi_num n oct \<and> midi_num n oct \<le> 127 then OMidiNum (midi_num n oct)
          else Decline ImpMidiRange)"
| "mkernel (MFreq n oc A) =
     (case oc of None \<Rightarrow> Decline UnderFreq
      | Some oct \<Rightarrow>
          if \<not> spellable n \<or> \<not> 0 < A then Silent
          else (case enclose3 prec (freq_fa A (midi_num n oct)) of
                  None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> OFreq d))"

section \<open>What each kind means\<close>

theorem key_value:
  "mkernel (MKey n m) = OSig k \<Longrightarrow>
     spellable n \<and> k = fifths (fst n) (snd n) m \<and> \<bar>k\<bar> \<le> 7
     \<and> (nat_pc (fst n) + snd n) mod 12 = (7 * k + (if m then 9 else 0)) mod 12"
proof -
  assume h: "mkernel (MKey n m) = OSig k"
  have sp: "spellable n" and ks: "keysig_of n m = Some k" using h by (auto split: if_splits option.splits)
  have k: "k = fifths (fst n) (snd n) m" and b: "\<bar>k\<bar> \<le> 7"
    using ks by (auto simp: keysig_of_def split: if_splits)
  show ?thesis using sp k b keysig_circle_of_fifths[of "fst n" "snd n" m] by simp
qed

theorem key_theoretical:
  "mkernel (MKey n m) = Decline ImpKey \<longleftrightarrow> spellable n \<and> 7 < \<bar>fifths (fst n) (snd n) m\<bar>"
  by (auto simp: keysig_of_def split: if_splits option.splits)

theorem key_matches_organ_table:
  "spellable n \<Longrightarrow> (mkernel (MKey n m) = OSig k) \<longleftrightarrow> keysig_table n m = Some k"
  using keysig_formula_is_table[of n m] by (auto simp: spellable_def split: option.splits)

theorem relative_value:
  "mkernel (MRel n m) = ORel r \<Longrightarrow>
     r = rel_key n m \<and> pcn r = (pcn n + (if m then 3 else 9)) mod 12
     \<and> (spellable n \<longrightarrow> fifths (fst r) (snd r) (\<not> m) = fifths (fst n) (snd n) m)"
proof -
  assume h: "mkernel (MRel n m) = ORel r"
  have sp: "spellable n" and r: "r = rel_key n m" using h by (auto split: if_splits)
  have a: "\<bar>snd n\<bar> \<le> 2" using sp by (simp add: spellable_def)
  show ?thesis using r rel_key_pitch[OF a, of m] rel_key_signature[OF a, of m] by simp
qed

theorem scale_value:
  "mkernel (MScale n m) = OScale ns \<Longrightarrow>
     ns = scale_notes n m \<and> length ns = 7 \<and> hd ns = n \<and> sig_ok ns
     \<and> (\<forall>i::nat<7. pcn (ns ! i) = (pcn n + off_at m i) mod 12 \<and> fst (ns ! i) = lstep i (fst n))"
proof -
  assume h: "mkernel (MScale n m) = OScale ns"
  then have s: "spellable n" and ns: "ns = scale_notes n m" and ok: "sig_ok ns"
    by (auto split: if_splits)
  have l: "length ns = 7" using ns by (simp add: scale_notes_def)
  have "hd ns = scale_note n m 0" using ns by (simp add: scale_notes_def upt_conv_Cons)
  moreover have "scale_note n m 0 = n" using s by (simp add: scale_first spellable_def)
  ultimately have hd: "hd ns = n" by simp
  have idx: "\<forall>i::nat<7. ns ! i = scale_note n m i"
  proof (intro allI impI)
    fix i :: nat assume "i < 7"
    then show "ns ! i = scale_note n m i" using ns by (simp add: scale_notes_def)
  qed
  show ?thesis using ns l hd ok idx by (auto simp: scale_note_pitch scale_note_letter)
qed

theorem scale_double_accidental:
  "mkernel (MScale n m) = Decline ImpScale \<longleftrightarrow> spellable n \<and> \<not> sig_ok (scale_notes n m)"
  by (auto split: if_splits)

theorem semitones_named:
  "mkernel (MSemis bs) = OSemis r \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length ivl_order \<and> bs ! i \<and> ivl_order ! i = r \<and> (\<forall>j<i. \<not> bs ! j)"
  by (auto dest: pick_some split: option.splits)

theorem semitones_named_none:
  "mkernel (MSemis bs) = Silent \<Longrightarrow> \<forall>i<length bs. i < length ivl_order \<longrightarrow> \<not> bs ! i"
  by (auto dest: pick_none split: option.splits)

theorem between_semitones:
  "mkernel (MBetween n1 o1 n2 o2 True) = OBetween k \<Longrightarrow>
     0 \<le> k \<and> k \<le> 12 \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
     \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)"
  by (auto dest: between_sound split: if_splits option.splits prod.splits)

theorem between_interval:
  "mkernel (MBetween n1 o1 n2 o2 False) = OIvl st k q \<Longrightarrow>
     (st, k, q) \<in> set qual_rows \<and> (pcn n2 - pcn n1 - k) mod 12 = 0
     \<and> (\<forall>x y. o1 = Some x \<longrightarrow> o2 = Some y \<longrightarrow> midi_num n2 y - midi_num n1 x = k)"
  by (auto dest: between_sound qual_lookup_sound split: if_splits option.splits prod.splits)

theorem midi_note_value:
  "mkernel (MMidiNote k) = OMidiNote nm oc \<Longrightarrow> 0 \<le> k \<and> k \<le> 127 \<and> midi_num nm oc = k"
  by (auto simp: midi_name_roundtrip split: if_splits)

theorem midi_note_impossible:
  "mkernel (MMidiNote k) = Decline w \<longleftrightarrow> w = ImpMidiNum \<and> 127 < k"
  by (auto split: if_splits)

theorem midi_number_value:
  "mkernel (MMidiNum n oc) = OMidiNum k \<Longrightarrow>
     (\<exists>oct. oc = Some oct \<and> k = midi_num n oct) \<and> 0 \<le> k \<and> k \<le> 127"
  by (auto split: if_splits option.splits)

text \<open>Enharmonic spelling can cross an octave boundary: C-flat4 is B3 and
B-sharp4 is C5. The inverse returns the canonical spelling with this carry.\<close>
theorem midi_kernel_roundtrip:
  assumes "mkernel (MMidiNum n (Some oct)) = OMidiNum k"
      "mkernel (MMidiNote k) = OMidiNote n' oct'"
  shows "pcn n' = pcn n \<and> oct' = oct + (nat_pc (fst n) + snd n) div 12"
proof -
  have k: "k = midi_num n oct" using midi_number_value[OF assms(1)] by auto
  have eq: "midi_num n' oct' = k" using midi_note_value[OF assms(2)] by blast
  have pc: "pcn n' = pcn n" using midi_pitch[of n' oct'] midi_pitch[of n oct] eq k by simp
  have oct: "oct' = k div 12 - 1" using assms(2) by (auto split: if_splits)
  show ?thesis using pc oct k by (simp add: midi_num_def add.commute add.left_commute add.assoc)
qed

theorem midi_number_underspecified: "mkernel (MMidiNum n None) = Decline UnderMidi"
  by simp

theorem freq_underspecified: "mkernel (MFreq n None A) = Decline UnderFreq"
  by simp

theorem freq_value:
  "mkernel (MFreq n oc A) = OFreq d \<Longrightarrow>
     (\<exists>oct. oc = Some oct \<and> \<bar>dec_val d - phys_freq A (midi_num n oct)\<bar> \<le> 1 / 1000) \<and> 0 < A"
  by (auto dest!: enclose3_sound split: if_splits option.splits)

theorem cents_value:
  "mkernel (MCents f1 f2) = OCents d \<Longrightarrow>
     0 < f1 \<and> 0 < f2 \<and> \<bar>dec_val d - phys_cents f1 f2\<bar> \<le> 1 / 1000"
  by (auto dest!: enclose3_sound split: if_splits option.splits)

theorem duration_value:
  "mkernel (MDur b dotted v) = ODur s \<Longrightarrow> 0 < b \<and> s * b = 60 * beats dotted v"
proof -
  assume h: "mkernel (MDur b dotted v) = ODur s"
  then have b: "0 < b" and s: "s = dur_secs b dotted v" by (auto split: if_splits)
  have "b \<noteq> 0" using b by auto
  then show ?thesis using b s dur_defining[of b dotted v] by simp
qed

section \<open>Reply text (ASCII)\<close>

definition mode_str :: "bool \<Rightarrow> String.literal" where
  "mode_str m = (if m then STR ''minor'' else STR ''major'')"

definition plural_s :: "int \<Rightarrow> String.literal" where
  "plural_s k = (if k = 1 then STR '''' else STR ''s'')"

definition join_notes :: "pnote list \<Rightarrow> String.literal" where
  "join_notes ns = (case ns of [] \<Rightarrow> STR '''' | x # xs \<Rightarrow> foldl (\<lambda>s y. s + STR '' '' + spell y) (spell x) xs)"

definition mtext :: "mreq \<Rightarrow> mout \<Rightarrow> String.literal" where
  "mtext r res = (case (r, res) of
     ((MCents f1 f2), (OCents d)) \<Rightarrow>
       cat [STR ''The interval is '', render_dec 17 d, STR '' cents (1200 x log2('', g3 f2, STR '' / '', g3 f1, STR '')).'']
   | ((MDur b dotted v), (ODur s)) \<Rightarrow>
     cat [STR ''A '', (if dotted then STR ''dotted '' else STR ''''), dur_name v, STR '' note at '', g3 b,
          STR '' bpm lasts '', g3 s, STR '' seconds (60 / '', g3 b, STR '' x '', g3 (beats dotted v),
          STR '' beats, quarter-note beat).'']
   | ((MKey n m), (OSig k)) \<Rightarrow>
     (if 0 < k then cat [spell n, STR '' '', mode_str m, STR '' has '', show_int k, STR '' sharp'', plural_s k,
                        STR '' in its key signature.'']
      else if k < 0 then cat [spell n, STR '' '', mode_str m, STR '' has '', show_int (- k), STR '' flat'',
                              plural_s (- k), STR '' in its key signature.'']
      else cat [spell n, STR '' '', mode_str m, STR '' has 0 sharps or flats in its key signature.''])
   | ((MRel n m), (ORel r)) \<Rightarrow>
     cat [STR ''The relative '', mode_str (\<not> m), STR '' of '', spell n, STR '' '', mode_str m, STR '' is '',
          spell r, STR '' '', mode_str (\<not> m), STR ''.'']
   | ((MScale n m), (OScale ns)) \<Rightarrow>
     cat [STR ''The '', spell n, STR '' '', (if m then STR ''natural minor'' else STR ''major''),
          STR '' scale is '', join_notes ns, STR ''.'']
   | ((MSemis bs), (OSemis r)) \<Rightarrow>
     cat [STR ''A '', fst r, STR '' is '', show_int (snd r), STR '' semitone'', plural_s (snd r), STR ''.'']
   | ((MBetween n1 o1 n2 o2 asks), (OBetween k)) \<Rightarrow>
     cat [STR ''From '', spell n1, STR '' up to '', spell n2, STR '' is '', show_int k, STR '' semitones.'']
   | ((MBetween n1 o1 n2 o2 asks), (OIvl st k q)) \<Rightarrow>
     cat [STR ''The interval from '', spell n1, STR '' up to '', spell n2, STR '' is a '', iname st q,
          STR '' ('', show_int (int st), STR '' letter steps, '', show_int k, STR '' semitones).'']
   | ((MMidiNote k), (OMidiNote nm oc)) \<Rightarrow>
     cat [STR ''MIDI note '', show_int k, STR '' is '', spell nm, show_int oc, STR '' (middle C = C4 = 60).'']
   | ((MMidiNum n oc), (OMidiNum k)) \<Rightarrow>
     cat [STR ''The MIDI note number of '', spell n, (case oc of Some oct \<Rightarrow> show_int oct | None \<Rightarrow> STR ''''),
          STR '' is '', show_int k, STR '' (middle C = C4 = 60).'']
   | ((MFreq n oc A), (OFreq d)) \<Rightarrow>
     cat [STR ''The frequency of '', spell n, (case oc of Some oct \<Rightarrow> show_int oct | None \<Rightarrow> STR ''''),
          STR '' is '', render_dec 17 d, STR '' Hz (12-tone equal temperament, A4 = '', g3 A, STR '' Hz: '', g3 A,
          STR '' x 2^(('', (case oc of Some oct \<Rightarrow> show_int (midi_num n oct) | None \<Rightarrow> STR ''''),
          STR '' - 69)/12)).'']
   | (_, _) \<Rightarrow> STR '''')"

definition mdecl_kind :: "mdecl \<Rightarrow> String.literal" where
  "mdecl_kind w = (case w of UnderMidi \<Rightarrow> STR ''underspecified'' | UnderFreq \<Rightarrow> STR ''underspecified''
                   | Imprecise \<Rightarrow> STR ''imprecise'' | _ \<Rightarrow> STR ''impossible'')"

definition mdecl_text :: "mreq \<Rightarrow> mdecl \<Rightarrow> String.literal" where
  "mdecl_text r w = (case (r, w) of
     (MKey n m, ImpKey) \<Rightarrow> cat [spell n, STR '' '', mode_str m,
        STR '' is a theoretical key - its signature would need double sharps or flats; it is written as its enharmonic.'']
   | (MScale n m, ImpScale) \<Rightarrow> cat [spell n, STR '' '', mode_str m,
        STR '' needs double sharps or flats; it is usually written as its enharmonic.'']
   | (MMidiNote k, ImpMidiNum) \<Rightarrow> cat [STR ''MIDI note numbers run 0-127; '', show_int k, STR '' is not one.'']
   | (MMidiNum n oc, ImpMidiRange) \<Rightarrow> cat [spell n, (case oc of Some oct \<Rightarrow> show_int oct | None \<Rightarrow> STR ''''),
        STR '' is outside the MIDI range 0-127.'']
   | (_, UnderMidi) \<Rightarrow> cat [STR ''I need the octave number (e.g. C4) to work that out; I won'', apos, STR ''t assume it.'']
   | (_, UnderFreq) \<Rightarrow> cat [STR ''I need the octave (e.g. A4) to work that out; I won'', apos, STR ''t assume it.'']
   | _ \<Rightarrow> STR ''The value could not be enclosed precisely enough to state.'')"

fun mkind :: "mout \<Rightarrow> String.literal" where
  "mkind (OCents d) = STR ''cents''" | "mkind (ODur s) = STR ''duration''"
| "mkind (OSig k) = STR ''key_sig''" | "mkind (ORel r) = STR ''relative''"
| "mkind (OScale ns) = STR ''scale''" | "mkind (OSemis r) = STR ''semitones''"
| "mkind (OBetween k) = STR ''semitones_between''" | "mkind (OIvl st k q) = STR ''interval''"
| "mkind (OMidiNote nm oc) = STR ''midi_note''" | "mkind (OMidiNum k) = STR ''midi_number''"
| "mkind (OFreq d) = STR ''frequency''" | "mkind Silent = STR ''silent''"
| "mkind (Decline w) = mdecl_kind w"

fun mstated :: "mout \<Rightarrow> String.literal" where
  "mstated (OCents d) = render_dec 17 d" | "mstated (ODur s) = g3 s"
| "mstated (OSig k) = show_int k" | "mstated (ORel r) = spell r"
| "mstated (OScale ns) = join_notes ns" | "mstated (OSemis r) = show_int (snd r)"
| "mstated (OBetween k) = show_int k" | "mstated (OIvl st k q) = iname st q"
| "mstated (OMidiNote nm oc) = spell nm + show_int oc" | "mstated (OMidiNum k) = show_int k"
| "mstated (OFreq d) = render_dec 17 d" | "mstated Silent = STR ''''" | "mstated (Decline w) = STR ''''"

definition mreply :: "mreq \<Rightarrow> reply" where
  "mreply r = (case mkernel r of
      Silent \<Rightarrow> Reply False (STR ''silent'') (STR '''') None
    | Decline w \<Rightarrow> Reply False (mdecl_kind w) (mdecl_text r w) None
    | v \<Rightarrow> Reply True (mkind v) (mtext r v) (Some (mstated v)))"

theorem mreply_answered_iff:
  "answered (mreply r) \<longleftrightarrow> (mkernel r \<noteq> Silent \<and> (\<forall>w. mkernel r \<noteq> Decline w))"
  by (auto simp: mreply_def split: mout.splits)

theorem mreply_silent: "mkernel r = Silent \<Longrightarrow> \<not> answered (mreply r) \<and> response (mreply r) = STR ''''"
  by (simp add: mreply_def)

theorem mreply_withheld_names_decline:
  "mkernel r = Decline w \<Longrightarrow> \<not> answered (mreply r) \<and> reply_kind (mreply r) = mdecl_kind w"
  by (simp add: mreply_def)

definition music_self_test :: bool where
  "music_self_test \<longleftrightarrow>
     keysig_of (N_A, -1) False = Some (-4) \<and> keysig_of (N_G, 1) False = None \<and>
     rel_key (N_E, -1) False = (N_C, 0) \<and> rel_key (N_C, 0) True = (N_E, -1) \<and>
     scale_notes (N_G, 0) True = [(N_G, 0), (N_A, 0), (N_B, -1), (N_C, 0), (N_D, 0), (N_E, -1), (N_F, 0)] \<and>
     between (N_F, 0) None (N_B, 0) None = Some (3, 6) \<and>
     between (N_C, 0) (Some 4) (N_C, 0) (Some 5) = Some (7, 12) \<and>
     between (N_G, 0) None (N_F, 0) None = Some (6, 10) \<and>
     qual_lookup 6 10 = Some Q_min \<and>
     mkernel (MMidiNote 90) = OMidiNote (N_F, 1) 6 \<and>
     mkernel (MMidiNote 150) = Decline ImpMidiNum \<and>
     mkernel (MMidiNum (N_E, -1) (Some 4)) = OMidiNum 63 \<and>
     mkernel (MFreq (N_D, 0) None 440) = Decline UnderFreq \<and>
     mkernel (MDur 90 False D_half) = ODur (4 / 3) \<and>
     g3 (4 / 3) = STR ''1.333'' \<and> g3 (3 / 2) = STR ''1.5'' \<and> g3 3 = STR ''3'' \<and>
     response (mreply (MKey (N_A, -1) False)) = STR ''Ab major has 4 flats in its key signature.'' \<and>
     response (mreply (MRel (N_E, -1) False)) = STR ''The relative minor of Eb major is C minor.'' \<and>
     response (mreply (MScale (N_G, 0) True)) = STR ''The G natural minor scale is G A Bb C D Eb F.'' \<and>
     response (mreply (MBetween (N_F, 0) None (N_B, 0) None False)) =
       STR ''The interval from F up to B is a augmented fourth (3 letter steps, 6 semitones).''"

end
