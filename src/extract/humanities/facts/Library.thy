theory Library
  imports Facts_Common
begin

text \<open>
  Oracle7 library (upstream/root/specialists/library/organ_library_v1.py): the Library of
  Congress Classification outline and the ISBN-13, ISBN-10 and ISSN check digits. The
  check digits are modular arithmetic on digit lists and are proved against their
  defining congruences; the classification is a table. Digits are naturals, with the
  letter X (the check value 10) written 10. The untrusted recognizer extracts the digits,
  the code letters and the question words.
\<close>

section \<open>Check digits\<close>

fun wsum :: "(nat \<Rightarrow> nat) \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat" where
  "wsum w i [] = 0" | "wsum w i (d # ds) = w i * d + wsum w (Suc i) ds"

lemma wsum_append: "wsum w i (xs @ ys) = wsum w i xs + wsum w (i + length xs) ys"
  by (induction xs arbitrary: i) simp_all

definition w13 :: "nat \<Rightarrow> nat" where "w13 i = (if even i then 1 else 3)"
definition w10 :: "nat \<Rightarrow> nat" where "w10 i = 10 - i"
definition wissn :: "nat \<Rightarrow> nat" where "wissn i = 8 - i"

text \<open>The organ's check digits: ISBN-13 weights 1,3 alternating, check
@{text "(10 - sum mod 10) mod 10"}; ISBN-10 weights 10..2, check
@{text "(11 - sum mod 11) mod 11"} (10 is X); ISSN weights 8..2, the same mod 11.\<close>
definition chk13 :: "nat list \<Rightarrow> nat" where "chk13 xs = (10 - wsum w13 0 xs mod 10) mod 10"
definition chk10 :: "nat list \<Rightarrow> nat" where "chk10 xs = (11 - wsum w10 0 xs mod 11) mod 11"
definition chkissn :: "nat list \<Rightarrow> nat" where "chkissn xs = (11 - wsum wissn 0 xs mod 11) mod 11"

lemma chk_gen: "0 < m \<Longrightarrow> (S + (m - S mod m) mod m) mod (m :: nat) = 0"
proof (cases "S mod m = 0")
  case True
  then show ?thesis using mod_less by simp
next
  case False
  assume m: "0 < m"
  have lt: "S mod m < m" using m by simp
  have e1: "(m - S mod m) mod m = m - S mod m" by (rule mod_less) (use False m in arith)
  have f: "S div m * m + S mod m = S" by (rule div_mult_mod_eq)
  have le: "S mod m \<le> m" using lt by simp
  have e2: "S + (m - S mod m) = (S div m + 1) * m"
  proof -
    have "S + (m - S mod m) = (S div m * m + S mod m) + (m - S mod m)" by (simp only: f)
    also have "\<dots> = S div m * m + (S mod m + (m - S mod m))" by (simp only: add.assoc)
    also have "S mod m + (m - S mod m) = m" by (rule le_add_diff_inverse[OF le])
    finally show ?thesis by (simp add: algebra_simps)
  qed
  show ?thesis using e1 e2 by simp
qed

lemma chk_unique:
  assumes m: "0 < m" and y: "y < m" and z: "(S + y) mod (m :: nat) = 0"
  shows "y = (m - S mod m) mod m"
proof -
  define r where "r = S mod m"
  have r: "r < m" using m by (simp add: r_def)
  have "(r + y) mod m = 0" using z by (simp add: r_def mod_add_left_eq)
  then obtain k where k: "r + y = m * k" by auto
  have k2: "k < 2"
  proof (rule ccontr)
    assume "\<not> k < 2"
    then have "2 \<le> k" by simp
    then have "m * 2 \<le> m * k" by (rule mult_le_mono2)
    then show False using k r y by linarith
  qed
  show ?thesis
  proof (cases "k = 0")
    case True
    then have "r = 0" "y = 0" using k by simp_all
    then show ?thesis by (simp add: r_def)
  next
    case False
    then have k1: "k = 1" using k2 by simp
    then have s: "r + y = m" using k by simp
    have "y \<noteq> m" using y by simp
    have "(m - r) mod m = m - r" by (rule mod_less) (use s y m in arith)
    moreover have "y = m - r" using s by simp
    ultimately show ?thesis by (simp add: r_def)
  qed
qed

lemma chk_iff:
  "0 < m \<Longrightarrow> d < m \<Longrightarrow> (((m - S mod m) mod m = d) = ((S + d) mod (m :: nat) = 0))"
  using chk_gen[of m S] chk_unique[of m d S] by metis

lemma wsum_last: "wsum w 0 (xs @ [y]) = wsum w 0 xs + w (length xs) * y"
  by (simp add: wsum_append)

text \<open>The defining property: appended to its digits, the check digit makes the weighted
sum (the check digit has weight 1) divisible by 10 (ISBN-13) or 11 (ISBN-10, ISSN), and it
is the only digit that does.\<close>
theorem chk13_valid: "length xs = 12 \<Longrightarrow> wsum w13 0 (xs @ [chk13 xs]) mod 10 = 0"
  using chk_gen[of 10 "wsum w13 0 xs"] by (simp add: wsum_last w13_def chk13_def)

theorem chk13_unique:
  "length xs = 12 \<Longrightarrow> y < 10 \<Longrightarrow> wsum w13 0 (xs @ [y]) mod 10 = 0 \<Longrightarrow> y = chk13 xs"
  using chk_unique[of 10 y "wsum w13 0 xs"] by (simp add: wsum_last w13_def chk13_def)

theorem chk13_valid_iff:
  "length xs = 12 \<Longrightarrow> y < 10 \<Longrightarrow> (chk13 xs = y) = (wsum w13 0 (xs @ [y]) mod 10 = 0)"
  using chk13_valid chk13_unique by metis

theorem chk10_valid: "length xs = 9 \<Longrightarrow> wsum w10 0 (xs @ [chk10 xs]) mod 11 = 0"
  using chk_gen[of 11 "wsum w10 0 xs"] by (simp add: wsum_last w10_def chk10_def)

theorem chk10_unique:
  "length xs = 9 \<Longrightarrow> y \<le> 10 \<Longrightarrow> wsum w10 0 (xs @ [y]) mod 11 = 0 \<Longrightarrow> y = chk10 xs"
  using chk_unique[of 11 y "wsum w10 0 xs"] by (simp add: wsum_last w10_def chk10_def)

theorem chk10_valid_iff:
  "length xs = 9 \<Longrightarrow> y \<le> 10 \<Longrightarrow> (chk10 xs = y) = (wsum w10 0 (xs @ [y]) mod 11 = 0)"
  using chk10_valid chk10_unique by metis

theorem chkissn_valid: "length xs = 7 \<Longrightarrow> wsum wissn 0 (xs @ [chkissn xs]) mod 11 = 0"
  using chk_gen[of 11 "wsum wissn 0 xs"] by (simp add: wsum_last wissn_def chkissn_def)

theorem chkissn_unique:
  "length xs = 7 \<Longrightarrow> y \<le> 10 \<Longrightarrow> wsum wissn 0 (xs @ [y]) mod 11 = 0 \<Longrightarrow> y = chkissn xs"
  using chk_unique[of 11 y "wsum wissn 0 xs"] by (simp add: wsum_last wissn_def chkissn_def)

theorem chkissn_valid_iff:
  "length xs = 7 \<Longrightarrow> y \<le> 10 \<Longrightarrow> (chkissn xs = y) = (wsum wissn 0 (xs @ [y]) mod 11 = 0)"
  using chkissn_valid chkissn_unique by metis

section \<open>Classification tables\<close>

definition lcc_classes :: "(String.literal \<times> String.literal) list" where
  "lcc_classes = [
    (STR ''A'', STR ''General Works''),
    (STR ''B'', STR ''Philosophy, Psychology, Religion''),
    (STR ''C'', STR ''Auxiliary Sciences of History''),
    (STR ''D'', STR ''World History (except the Americas)''),
    (STR ''E'', STR ''History of the Americas (United States)''),
    (STR ''F'', STR ''History of the Americas (local US, Canada, Latin America)''),
    (STR ''G'', STR ''Geography, Anthropology, Recreation''),
    (STR ''H'', STR ''Social Sciences''),
    (STR ''J'', STR ''Political Science''),
    (STR ''K'', STR ''Law''),
    (STR ''L'', STR ''Education''),
    (STR ''M'', STR ''Music''),
    (STR ''N'', STR ''Fine Arts''),
    (STR ''P'', STR ''Language and Literature''),
    (STR ''Q'', STR ''Science''),
    (STR ''R'', STR ''Medicine''),
    (STR ''S'', STR ''Agriculture''),
    (STR ''T'', STR ''Technology''),
    (STR ''U'', STR ''Military Science''),
    (STR ''V'', STR ''Naval Science''),
    (STR ''Z'', STR ''Bibliography, Library Science, Information Resources'')]"

text \<open>Two-letter subclasses: code, description, main class letter. (The organ's SUB also
holds the one-letter key Z, which its two-letter branch never reaches.)\<close>
definition lcc_subs :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "lcc_subs = [
    (STR ''QA'', STR ''Mathematics (including computer science)'', STR ''Q''),
    (STR ''QB'', STR ''Astronomy'', STR ''Q''),
    (STR ''QC'', STR ''Physics'', STR ''Q''),
    (STR ''QD'', STR ''Chemistry'', STR ''Q''),
    (STR ''QE'', STR ''Geology'', STR ''Q''),
    (STR ''QH'', STR ''Natural history, Biology'', STR ''Q''),
    (STR ''QK'', STR ''Botany'', STR ''Q''),
    (STR ''QL'', STR ''Zoology'', STR ''Q''),
    (STR ''QM'', STR ''Human anatomy'', STR ''Q''),
    (STR ''QP'', STR ''Physiology'', STR ''Q''),
    (STR ''QR'', STR ''Microbiology'', STR ''Q''),
    (STR ''PS'', STR ''American literature'', STR ''P''),
    (STR ''PR'', STR ''English literature'', STR ''P''),
    (STR ''PQ'', STR ''French, Italian, Spanish and Portuguese literature'', STR ''P''),
    (STR ''PT'', STR ''German, Dutch and Scandinavian literature'', STR ''P''),
    (STR ''PN'', STR ''Literature (general)'', STR ''P''),
    (STR ''PE'', STR ''English language'', STR ''P''),
    (STR ''BF'', STR ''Psychology'', STR ''B''),
    (STR ''BL'', STR ''Religions, Mythology'', STR ''B''),
    (STR ''HB'', STR ''Economic theory, Demography'', STR ''H''),
    (STR ''HF'', STR ''Commerce'', STR ''H''),
    (STR ''HM'', STR ''Sociology (general)'', STR ''H''),
    (STR ''HV'', STR ''Social pathology, Social and public welfare, Criminology'', STR ''H''),
    (STR ''JK'', STR ''Political institutions (United States)'', STR ''J''),
    (STR ''RC'', STR ''Internal medicine'', STR ''R''),
    (STR ''RT'', STR ''Nursing'', STR ''R''),
    (STR ''TK'', STR ''Electrical engineering, Electronics, Nuclear engineering'', STR ''T''),
    (STR ''TA'', STR ''Engineering (general), Civil engineering'', STR ''T''),
    (STR ''ML'', STR ''Literature on music'', STR ''M''),
    (STR ''MT'', STR ''Instruction and study (music)'', STR ''M''),
    (STR ''ND'', STR ''Painting'', STR ''N''),
    (STR ''NA'', STR ''Architecture'', STR ''N''),
    (STR ''GV'', STR ''Recreation, Leisure'', STR ''G''),
    (STR ''GN'', STR ''Anthropology'', STR ''G'')]"

definition unused_letters :: "String.literal list" where
  "unused_letters = [STR ''I'', STR ''O'', STR ''W'', STR ''X'', STR ''Y'']"

definition alphabet :: "String.literal list" where
  "alphabet = [STR ''A'', STR ''B'', STR ''C'', STR ''D'', STR ''E'', STR ''F'', STR ''G'', STR ''H'', STR ''I'', STR ''J'', STR ''K'', STR ''L'', STR ''M'', STR ''N'', STR ''O'', STR ''P'', STR ''Q'', STR ''R'', STR ''S'', STR ''T'', STR ''U'', STR ''V'', STR ''W'', STR ''X'', STR ''Y'', STR ''Z'']"

text \<open>SUBJECT in the order the organ tries it (longest subject first, ties in table
order): subject, class code, and the description the reply gives.\<close>
definition subject_order :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "subject_order = [
    (STR ''electrical engineering'', STR ''TK'', STR ''Electrical engineering, Electronics, Nuclear engineering''),
    (STR ''american literature'', STR ''PS'', STR ''American literature''),
    (STR ''english literature'', STR ''PR'', STR ''English literature''),
    (STR ''political science'', STR ''J'', STR ''Political Science''),
    (STR ''computer science'', STR ''QA'', STR ''Mathematics (including computer science)''),
    (STR ''military science'', STR ''U'', STR ''Military Science''),
    (STR ''library science'', STR ''Z'', STR ''Bibliography, Library Science, Information Resources''),
    (STR ''naval science'', STR ''V'', STR ''Naval Science''),
    (STR ''microbiology'', STR ''QR'', STR ''Microbiology''),
    (STR ''architecture'', STR ''NA'', STR ''Architecture''),
    (STR ''anthropology'', STR ''GN'', STR ''Anthropology''),
    (STR ''mathematics'', STR ''QA'', STR ''Mathematics (including computer science)''),
    (STR ''agriculture'', STR ''S'', STR ''Agriculture''),
    (STR ''physiology'', STR ''QP'', STR ''Physiology''),
    (STR ''psychology'', STR ''BF'', STR ''Psychology''),
    (STR ''philosophy'', STR ''B'', STR ''Philosophy, Psychology, Religion''),
    (STR ''technology'', STR ''T'', STR ''Technology''),
    (STR ''astronomy'', STR ''QB'', STR ''Astronomy''),
    (STR ''chemistry'', STR ''QD'', STR ''Chemistry''),
    (STR ''sociology'', STR ''HM'', STR ''Sociology (general)''),
    (STR ''economics'', STR ''HB'', STR ''Economic theory, Demography''),
    (STR ''education'', STR ''L'', STR ''Education''),
    (STR ''fine arts'', STR ''N'', STR ''Fine Arts''),
    (STR ''geography'', STR ''G'', STR ''Geography, Anthropology, Recreation''),
    (STR ''mythology'', STR ''BL'', STR ''Religions, Mythology''),
    (STR ''painting'', STR ''ND'', STR ''Painting''),
    (STR ''medicine'', STR ''R'', STR ''Medicine''),
    (STR ''religion'', STR ''BL'', STR ''Religions, Mythology''),
    (STR ''physics'', STR ''QC'', STR ''Physics''),
    (STR ''geology'', STR ''QE'', STR ''Geology''),
    (STR ''biology'', STR ''QH'', STR ''Natural history, Biology''),
    (STR ''zoology'', STR ''QL'', STR ''Zoology''),
    (STR ''anatomy'', STR ''QM'', STR ''Human anatomy''),
    (STR ''nursing'', STR ''RT'', STR ''Nursing''),
    (STR ''botany'', STR ''QK'', STR ''Botany''),
    (STR ''music'', STR ''M'', STR ''Music''),
    (STR ''math'', STR ''QA'', STR ''Mathematics (including computer science)''),
    (STR ''law'', STR ''K'', STR ''Law'')]"

section \<open>Requests and kernel\<close>

datatype lreq =
    LIsbn bool "nat list" String.literal bool bool bool
  | LCode String.literal
  | LSubject "bool list"

datatype lout =
    LSilent
  | LIssnCheck "nat list" nat
  | LIssnValid "nat list" bool nat
  | LBadIssn String.literal
  | LConv "nat list"
  | LI13Check "nat list" nat
  | LI10Check "nat list" nat
  | LValid13 "nat list" bool nat
  | LValid10 "nat list" bool nat
  | LBadIsbn String.literal nat
  | LClassV String.literal String.literal
  | LSubV String.literal String.literal String.literal
  | LBadLetter String.literal
  | LSubjV String.literal String.literal String.literal

definition all_digits :: "nat list \<Rightarrow> bool" where
  "all_digits ds = list_all (\<lambda>d. d < 10) ds"

definition isbn_prefix :: "nat list" where "isbn_prefix = [9, 7, 8]"

definition lkernel :: "lreq \<Rightarrow> lout" where
  "lkernel r = (case r of
      LIsbn issn ds raw ac av cv \<Rightarrow>
        (if issn then
           (if ac \<and> length ds = 7 \<and> all_digits ds then LIssnCheck ds (chkissn ds)
            else if length ds = 8 \<and> all_digits (take 7 ds) then
              LIssnValid ds (chkissn (take 7 ds) = ds ! 7) (chkissn (take 7 ds))
            else LBadIssn raw)
         else
           (if cv \<and> length ds = 10 \<and> all_digits (take 9 ds) then
              LConv (isbn_prefix @ take 9 ds @ [chk13 (isbn_prefix @ take 9 ds)])
            else if ac \<and> length ds = 12 \<and> all_digits ds then LI13Check ds (chk13 ds)
            else if ac \<and> length ds = 9 \<and> all_digits ds then LI10Check ds (chk10 ds)
            else if length ds = 13 \<and> all_digits ds then
              LValid13 ds (chk13 (take 12 ds) = ds ! 12) (chk13 (take 12 ds))
            else if length ds = 10 \<and> all_digits (take 9 ds) then
              LValid10 ds (chk10 (take 9 ds) = ds ! 9) (chk10 (take 9 ds))
            else if ac \<or> av then LBadIsbn raw (length ds)
            else LSilent))
    | LCode code \<Rightarrow>
        (case map_of lcc_subs code of
           Some (t, par) \<Rightarrow> LSubV code t par
         | None \<Rightarrow>
             (case map_of lcc_classes code of
                Some t \<Rightarrow> LClassV code t
              | None \<Rightarrow> (if code \<in> set unused_letters then LBadLetter code else LSilent)))
    | LSubject bs \<Rightarrow>
        (case pick bs subject_order of Some (s, c, d) \<Rightarrow> LSubjV s c d | None \<Rightarrow> LSilent))"

lemma split_last:
  assumes "length ds = Suc n"
  shows "ds = take n ds @ [ds ! n]"
proof -
  have n: "n < length ds" using assms by simp
  have a1: "take (Suc n) ds = take n ds @ [ds ! n]" by (rule take_Suc_conv_app_nth[OF n])
  have b: "ds = take (Suc n) ds" using assms by simp
  show ?thesis by (rule trans[OF b a1])
qed

lemma wsum_split_last:
  assumes "length ds = Suc n"
  shows "wsum w 0 ds = wsum w 0 (take n ds) + w n * ds ! n"
proof -
  have "ds = take n ds @ [ds ! n]" by (rule split_last[OF assms])
  then have "wsum w 0 ds = wsum w 0 (take n ds @ [ds ! n])" by (rule arg_cong[where f = "wsum w 0"])
  also have "\<dots> = wsum w 0 (take n ds) + wsum w (0 + length (take n ds)) [ds ! n]" by (rule wsum_append)
  also have "\<dots> = wsum w 0 (take n ds) + w n * ds ! n" using assms by simp
  finally show ?thesis .
qed

theorem issn_check_value:
  assumes "lkernel (LIsbn True ds raw ac av cv) = LIssnCheck ds' c"
  shows "ds' = ds \<and> length ds = 7 \<and> all_digits ds \<and> c = chkissn ds \<and> c \<le> 10
     \<and> wsum wissn 0 (ds @ [c]) mod 11 = 0"
proof -
  have d: "ds' = ds \<and> length ds = 7 \<and> all_digits ds \<and> c = chkissn ds"
    using assms by (auto simp: lkernel_def split: if_splits)
  have lt: "chkissn ds < 11" by (simp add: chkissn_def)
  show ?thesis using d lt chkissn_valid by auto
qed

theorem issn_valid_value:
  assumes "lkernel (LIsbn True ds raw ac av cv) = LIssnValid ds' ok c" "ds ! 7 \<le> 10"
  shows "ds' = ds \<and> length ds = 8 \<and> all_digits (take 7 ds) \<and> c = chkissn (take 7 ds)
         \<and> (ok \<longleftrightarrow> wsum wissn 0 ds mod 11 = 0)"
proof -
  have h: "ds' = ds" "length ds = 8" "all_digits (take 7 ds)" "ok = (chkissn (take 7 ds) = ds ! 7)"
    "c = chkissn (take 7 ds)"
    using assms(1) by (auto simp: lkernel_def split: if_splits)
  have s: "wsum wissn 0 ds = wsum wissn 0 (take 7 ds) + wissn 7 * ds ! 7"
    by (rule wsum_split_last) (use h(2) in simp)
  have "ok \<longleftrightarrow> wsum wissn 0 ds mod 11 = 0"
    unfolding h(4) using s assms(2) chk_iff[of 11 "ds ! 7" "wsum wissn 0 (take 7 ds)"] by (simp add: chkissn_def wissn_def)
  then show ?thesis using h by simp
qed

theorem isbn_convert_value:
  "lkernel (LIsbn False ds raw ac av cv) = LConv v \<Longrightarrow>
     length ds = 10 \<and> all_digits (take 9 ds) \<and> length v = 13
     \<and> take 3 v = [9, 7, 8] \<and> take 9 (drop 3 v) = take 9 ds
     \<and> wsum w13 0 v mod 10 = 0"
proof -
  assume h: "lkernel (LIsbn False ds raw ac av cv) = LConv v"
  then have v: "v = isbn_prefix @ take 9 ds @ [chk13 (isbn_prefix @ take 9 ds)]"
    and l: "length ds = 10" and dg: "all_digits (take 9 ds)"
    by (auto simp: lkernel_def split: if_splits)
  have l12: "length (isbn_prefix @ take 9 ds) = 12" using l by (simp add: isbn_prefix_def)
  have "wsum w13 0 v mod 10 = 0" using v chk13_valid[OF l12] by simp
  moreover have "length v = 13" using v l12 by simp
  moreover have "take 3 v = [9, 7, 8]" using v by (simp add: isbn_prefix_def)
  moreover have "take 9 (drop 3 v) = take 9 ds" using v l by (simp add: isbn_prefix_def)
  ultimately show ?thesis using l dg by simp
qed

theorem isbn13_check_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LI13Check ds' c"
  shows "ds' = ds \<and> length ds = 12 \<and> all_digits ds \<and> c = chk13 ds \<and> c < 10
     \<and> wsum w13 0 (ds @ [c]) mod 10 = 0"
proof -
  have d: "ds' = ds \<and> length ds = 12 \<and> all_digits ds \<and> c = chk13 ds"
    using assms by (auto simp: lkernel_def split: if_splits)
  have lt: "chk13 ds < 10" by (simp add: chk13_def)
  show ?thesis using d lt chk13_valid by auto
qed

theorem isbn10_check_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LI10Check ds' c"
  shows "ds' = ds \<and> length ds = 9 \<and> all_digits ds \<and> c = chk10 ds \<and> c \<le> 10
     \<and> wsum w10 0 (ds @ [c]) mod 11 = 0"
proof -
  have d: "ds' = ds \<and> length ds = 9 \<and> all_digits ds \<and> c = chk10 ds"
    using assms by (auto simp: lkernel_def split: if_splits)
  have lt: "chk10 ds < 11" by (simp add: chk10_def)
  show ?thesis using d lt chk10_valid by auto
qed

theorem isbn13_valid_value:
  "lkernel (LIsbn False ds raw ac av cv) = LValid13 ds' ok c \<Longrightarrow>
     ds' = ds \<and> length ds = 13 \<and> all_digits ds \<and> c = chk13 (take 12 ds)
     \<and> (ok \<longleftrightarrow> wsum w13 0 ds mod 10 = 0)"
proof -
  assume "lkernel (LIsbn False ds raw ac av cv) = LValid13 ds' ok c"
  then have h: "ds' = ds" "length ds = 13" "all_digits ds" "ok = (chk13 (take 12 ds) = ds ! 12)"
    "c = chk13 (take 12 ds)"
    by (auto simp: lkernel_def split: if_splits)
  have d12: "ds ! 12 < 10"
  proof -
    have all: "\<forall>n<length ds. ds ! n < 10" using h(3) by (simp add: all_digits_def list_all_length)
    have "12 < length ds" using h(2) by simp
    then show ?thesis using all by blast
  qed
  have s: "wsum w13 0 ds = wsum w13 0 (take 12 ds) + w13 12 * ds ! 12"
    by (rule wsum_split_last) (use h(2) in simp)
  have "ok \<longleftrightarrow> wsum w13 0 ds mod 10 = 0"
    unfolding h(4) using s d12 chk_iff[of 10 "ds ! 12" "wsum w13 0 (take 12 ds)"] by (simp add: chk13_def w13_def)
  then show ?thesis using h by simp
qed

theorem isbn10_valid_value:
  assumes "lkernel (LIsbn False ds raw ac av cv) = LValid10 ds' ok c" "ds ! 9 \<le> 10"
  shows "ds' = ds \<and> length ds = 10 \<and> all_digits (take 9 ds) \<and> c = chk10 (take 9 ds)
         \<and> (ok \<longleftrightarrow> wsum w10 0 ds mod 11 = 0)"
proof -
  have h: "ds' = ds" "length ds = 10" "all_digits (take 9 ds)" "ok = (chk10 (take 9 ds) = ds ! 9)"
    "c = chk10 (take 9 ds)"
    using assms(1) by (auto simp: lkernel_def split: if_splits)
  have s: "wsum w10 0 ds = wsum w10 0 (take 9 ds) + w10 9 * ds ! 9"
    by (rule wsum_split_last) (use h(2) in simp)
  have "ok \<longleftrightarrow> wsum w10 0 ds mod 11 = 0"
    unfolding h(4) using s assms(2) chk_iff[of 11 "ds ! 9" "wsum w10 0 (take 9 ds)"] by (simp add: chk10_def w10_def)
  then show ?thesis using h by simp
qed

theorem bad_length:
  "lkernel (LIsbn issn ds raw ac av cv) = LBadIsbn raw' n \<Longrightarrow> \<not> issn \<and> n = length ds \<and> (ac \<or> av)"
  by (auto simp: lkernel_def split: if_splits)

theorem bad_issn:
  "lkernel (LIsbn issn ds raw ac av cv) = LBadIssn raw' \<Longrightarrow>
     issn \<and> raw' = raw \<and> \<not> (ac \<and> length ds = 7 \<and> all_digits ds)
     \<and> \<not> (length ds = 8 \<and> all_digits (take 7 ds))"
  by (auto simp: lkernel_def split: if_splits)

theorem lcc_sub_value:
  "lkernel (LCode c) = LSubV c' t par \<Longrightarrow> c' = c \<and> map_of lcc_subs c = Some (t, par)"
  by (auto simp: lkernel_def split: option.splits if_splits)

theorem lcc_class_value:
  "lkernel (LCode c) = LClassV c' t \<Longrightarrow> c' = c \<and> map_of lcc_classes c = Some t \<and> map_of lcc_subs c = None"
  by (auto simp: lkernel_def split: option.splits if_splits)

theorem lcc_unused_value:
  "lkernel (LCode c) = LBadLetter c' \<Longrightarrow>
     c' = c \<and> c \<in> set unused_letters \<and> map_of lcc_classes c = None \<and> map_of lcc_subs c = None"
  by (auto simp: lkernel_def split: option.splits if_splits)

theorem lcc_subject_first_match:
  "lkernel (LSubject bs) = LSubjV s c d \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length subject_order \<and> bs ! i \<and> subject_order ! i = (s, c, d) \<and> (\<forall>j<i. \<not> bs ! j)"
  by (auto simp: lkernel_def dest: pick_some split: option.splits prod.splits)

section \<open>Reply text\<close>

definition dstr :: "nat \<Rightarrow> String.literal" where
  "dstr d = (if d = 10 then STR ''X'' else show_int (int d))"

definition dlit :: "nat list \<Rightarrow> String.literal" where
  "dlit ds = cat (map dstr ds)"

definition vword :: "bool \<Rightarrow> String.literal" where
  "vword ok = (if ok then STR ''Valid'' else STR ''Invalid'')"

definition vlow :: "bool \<Rightarrow> String.literal" where
  "vlow ok = (if ok then STR ''valid'' else STR ''invalid'')"

definition ltext :: "lout \<Rightarrow> String.literal" where
  "ltext res = (case res of
      LSilent \<Rightarrow> STR ''''
    | LIssnCheck ds c \<Rightarrow> cat [STR ''The check digit is '', dstr c, STR '' (weights 8..2, mod 11; ISSN '', dlit (take 4 ds),
          STR ''-'', dlit (drop 4 ds), dstr c, STR '').'']
    | LIssnValid ds ok c \<Rightarrow> cat [vword ok, STR '' - ISSN '', dlit (take 4 ds), STR ''-'', dlit (drop 4 ds), STR '' is '',
          vlow ok, STR '' (check digit should be '', dstr c, STR '').'']
    | LBadIssn raw \<Rightarrow> cat [STR ''An ISSN has 8 characters (7 digits plus a check digit); '', apos, raw, apos, STR '' does not.'']
    | LConv v \<Rightarrow> cat [STR ''The ISBN-13 is '', dlit v, STR '' (978 + first 9 digits + new check digit '', dstr (last v), STR '').'']
    | LI13Check ds c \<Rightarrow> cat [STR ''The check digit is '', dstr c, STR '' (ISBN-13 weights 1,3; ISBN '', dlit ds, dstr c, STR '').'']
    | LI10Check ds c \<Rightarrow> cat [STR ''The check digit is '', dstr c, STR '' (ISBN-10 weights 10..2, mod 11; ISBN '', dlit ds,
          dstr c, STR '').'']
    | LValid13 ds ok c \<Rightarrow> cat [vword ok, STR '' - ISBN '', dlit ds, STR '' is '', vlow ok, STR '' (check digit should be '',
          dstr c, STR '').'']
    | LValid10 ds ok c \<Rightarrow> cat [vword ok, STR '' - ISBN '', dlit ds, STR '' is '', vlow ok, STR '' (check digit should be '',
          dstr c, STR '').'']
    | LBadIsbn raw n \<Rightarrow> cat [STR ''An ISBN has 10 or 13 digits (9 or 12 before the check digit); '', apos, raw, apos,
          STR '' has '', show_int (int n), STR ''.'']
    | LClassV c t \<Rightarrow> cat [STR ''LCC class '', c, STR '' is '', t, STR ''.'']
    | LSubV c t par \<Rightarrow> cat [STR ''LCC '', c, STR '' is '', t, STR '' (subclass of '', par, STR '', '',
          (case map_of lcc_classes par of Some p \<Rightarrow> p | None \<Rightarrow> STR ''''), STR '').'']
    | LBadLetter c \<Rightarrow> cat [STR ''LCC does not use the letter '', c, STR '' as a main class (I, O, W, X and Y are unused).'']
    | LSubjV s c d \<Rightarrow> cat [STR ''Books on '', s, STR '' are classed in LCC '', c, STR '' ('', d, STR '').''])"

definition lkind :: "lout \<Rightarrow> String.literal" where
  "lkind res = (case res of
      LSilent \<Rightarrow> STR ''silent'' | LIssnCheck ds c \<Rightarrow> STR ''issn_check'' | LIssnValid ds ok c \<Rightarrow> STR ''issn_valid''
    | LBadIssn raw \<Rightarrow> STR ''impossible'' | LConv v \<Rightarrow> STR ''isbn_convert'' | LI13Check ds c \<Rightarrow> STR ''isbn13_check''
    | LI10Check ds c \<Rightarrow> STR ''isbn10_check'' | LValid13 ds ok c \<Rightarrow> STR ''isbn_valid''
    | LValid10 ds ok c \<Rightarrow> STR ''isbn_valid'' | LBadIsbn raw n \<Rightarrow> STR ''impossible''
    | LClassV c t \<Rightarrow> STR ''lcc_class'' | LSubV c t par \<Rightarrow> STR ''lcc_sub'' | LBadLetter c \<Rightarrow> STR ''impossible''
    | LSubjV s c d \<Rightarrow> STR ''lcc_for_subject'')"

definition lstated :: "lout \<Rightarrow> String.literal" where
  "lstated res = (case res of
      LIssnCheck ds c \<Rightarrow> dstr c | LIssnValid ds ok c \<Rightarrow> vlow ok | LConv v \<Rightarrow> dlit v | LI13Check ds c \<Rightarrow> dstr c
    | LI10Check ds c \<Rightarrow> dstr c | LValid13 ds ok c \<Rightarrow> vlow ok | LValid10 ds ok c \<Rightarrow> vlow ok
    | LClassV c t \<Rightarrow> t | LSubV c t par \<Rightarrow> t | LSubjV s c d \<Rightarrow> c | _ \<Rightarrow> STR '''')"

definition lwithheld :: "lout \<Rightarrow> bool" where
  "lwithheld res = (case res of LSilent \<Rightarrow> True | LBadIssn raw \<Rightarrow> True | LBadIsbn raw n \<Rightarrow> True
                   | LBadLetter c \<Rightarrow> True | _ \<Rightarrow> False)"

definition lreply :: "lreq \<Rightarrow> reply" where
  "lreply r = (let res = lkernel r in
      if lwithheld res then Reply False (lkind res) (ltext res) None
      else Reply True (lkind res) (ltext res) (Some (lstated res)))"

theorem lreply_answered_iff: "answered (lreply r) \<longleftrightarrow> \<not> lwithheld (lkernel r)"
  by (simp add: lreply_def Let_def)

definition library_self_test :: bool where
  "library_self_test \<longleftrightarrow>
     chk13 [9, 7, 8, 0, 3, 0, 6, 4, 0, 6, 1, 5] = 7 \<and>
     chk10 [0, 3, 0, 6, 4, 0, 6, 1, 5] = 2 \<and>
     chkissn [0, 3, 7, 8, 5, 9, 5] = 5 \<and>
     chkissn [0, 0, 0, 0, 0, 0, 6] = 10 \<and>
     response (lreply (LIsbn False [0, 3, 0, 6, 4, 0, 6, 1, 5, 2] (STR ''0306406152'') False False True)) =
       STR ''The ISBN-13 is 9780306406157 (978 + first 9 digits + new check digit 7).'' \<and>
     response (lreply (LIsbn False [9, 7, 8, 0, 3, 0, 6, 4, 0, 6, 1, 5, 7] (STR ''x'') False True False)) =
       STR ''Valid - ISBN 9780306406157 is valid (check digit should be 7).'' \<and>
     response (lreply (LIsbn True [0, 0, 0, 0, 0, 0, 6, 10] (STR ''x'') False True False)) =
       STR ''Valid - ISSN 0000-006X is valid (check digit should be X).'' \<and>
     response (lreply (LIsbn False [1, 2, 3, 4, 5] (STR ''12345'') True False False)) =
       cat [STR ''An ISBN has 10 or 13 digits (9 or 12 before the check digit); '', apos, STR ''12345'', apos, STR '' has 5.''] \<and>
     lkernel (LCode (STR ''I'')) = LBadLetter (STR ''I'') \<and>
     lkernel (LCode (STR ''K'')) = LClassV (STR ''K'') (STR ''Law'')"

end
