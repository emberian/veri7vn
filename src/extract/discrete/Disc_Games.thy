theory Disc_Games
  imports Disc_Dtext
begin

text \<open>games-v3 (upstream/root/specialists/games-v3): exact probability by
counting. Poker hands over C(52,5), dice sums by convolution, at-least-one,
card draws, and distinct anagram counts.\<close>

section \<open>Anagrams: the multinomial count\<close>

function (sequential) letter_counts :: "'a list \<Rightarrow> nat list" where
  "letter_counts [] = []"
| "letter_counts (x # xs) = count_list (x # xs) x # letter_counts (filter (\<lambda>y. y \<noteq> x) xs)"
  by pat_completeness auto
termination by (relation "measure length") (auto simp: less_Suc_eq_le length_filter_le)

fun multi :: "nat list \<Rightarrow> nat" where
  "multi [] = 1"
| "multi (c # cs) = ((sum_list cs + c) choose c) * multi cs"

lemma multi_fact: "multi cs * prod_list (map fact cs) = fact (sum_list cs)"
proof (induction cs)
  case Nil
  show ?case by simp
next
  case (Cons c cs)
  have h: "fact c * fact (sum_list cs) * ((sum_list cs + c) choose c) = fact (sum_list cs + c)"
    using binomial_fact_lemma[where k=c and n="sum_list cs + c"] by simp
  have "multi (c # cs) * prod_list (map fact (c # cs))
      = ((sum_list cs + c) choose c) * fact c * (multi cs * prod_list (map fact cs))"
    by (simp add: algebra_simps)
  also have "\<dots> = ((sum_list cs + c) choose c) * fact c * fact (sum_list cs)"
    using Cons.IH by simp
  also have "\<dots> = fact (sum_list cs + c)" using h by (simp add: algebra_simps)
  finally show ?case by (simp add: add.commute)
qed

lemma count_filter_len: "count_list xs x + length (filter (\<lambda>y. y \<noteq> x) xs) = length xs"
  by (induction xs) auto

lemma sum_letter_counts: "sum_list (letter_counts xs) = length xs"
proof (induction xs rule: letter_counts.induct)
  case 1
  show ?case by simp
next
  case (2 x xs)
  have "count_list (x # xs) x = Suc (count_list xs x)" by simp
  then show ?case using 2 count_filter_len[of xs x] by simp
qed

definition anagram_count :: "nat list \<Rightarrow> nat" where
  "anagram_count w = multi (letter_counts w)"

text \<open>The multinomial identity: the stated count times the product of the
factorials of the letter multiplicities is the factorial of the word length.\<close>
theorem anagram_equation:
  "anagram_count w * prod_list (map fact (letter_counts w)) = fact (length w)"
  unfolding anagram_count_def using multi_fact[of "letter_counts w"] sum_letter_counts[of w] by simp

section \<open>Dice: the exact distribution of a sum\<close>

fun atn :: "nat list \<Rightarrow> nat \<Rightarrow> nat" where
  "atn [] k = 0"
| "atn (x # xs) 0 = x"
| "atn (x # xs) (Suc k) = atn xs k"

fun addv :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "addv [] ys = ys"
| "addv (x # xs) [] = x # xs"
| "addv (x # xs) (y # ys) = (x + y) # addv xs ys"

fun step_k :: "nat \<Rightarrow> nat list \<Rightarrow> nat list" where
  "step_k 0 old = []"
| "step_k (Suc f) old = addv (step_k f old) (replicate (Suc f) 0 @ old)"

fun dice_dist :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "dice_dist 0 s = [1]"
| "dice_dist (Suc n) s = step_k s (dice_dist n s)"

text \<open>The defining recursion: the ways @{term "ways n s k"} to total @{term k}
with @{term n} dice of @{term s} sides is the sum over the first die's face
@{text f} of the ways the other dice total @{text "k - f"}.\<close>
fun wsum :: "nat \<Rightarrow> (nat \<Rightarrow> nat) \<Rightarrow> nat \<Rightarrow> nat" where
  "wsum 0 g k = 0"
| "wsum (Suc f) g k = wsum f g k + (if Suc f \<le> k then g (k - Suc f) else 0)"

fun ways :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "ways 0 s k = (if k = 0 then 1 else 0)"
| "ways (Suc n) s k = wsum s (ways n s) k"

lemma at_addv: "atn (addv xs ys) k = atn xs k + atn ys k"
proof (induction xs ys arbitrary: k rule: addv.induct)
  case (1 ys)
  show ?case by simp
next
  case (2 x xs)
  show ?case by (cases k) simp_all
next
  case (3 x xs y ys)
  show ?case by (cases k) (simp_all add: 3)
qed

lemma at_shift: "atn (replicate f 0 @ old) k = (if f \<le> k then atn old (k - f) else 0)"
proof (induction f arbitrary: k)
  case 0
  show ?case by simp
next
  case (Suc f)
  show ?case by (cases k) (simp_all add: Suc)
qed

lemma at_step: "atn (step_k f old) k = wsum f (atn old) k"
proof (induction f)
  case 0
  show ?case by simp
next
  case (Suc f)
  have "atn (step_k (Suc f) old) k = atn (step_k f old) k + atn (replicate (Suc f) 0 @ old) k"
    by (simp only: step_k.simps at_addv)
  also have "\<dots> = wsum f (atn old) k + (if Suc f \<le> k then atn old (k - Suc f) else 0)"
    using Suc.IH at_shift[of "Suc f" old k] by simp
  finally show ?case by simp
qed

theorem dist_ways: "atn (dice_dist n s) k = ways n s k"
proof (induction n arbitrary: k)
  case 0
  show ?case by (cases k) simp_all
next
  case (Suc n)
  have "ways n s = atn (dice_dist n s)" using Suc by (intro ext) simp
  then show ?case by (simp add: at_step)
qed

lemma sum_addv: "sum_list (addv xs ys) = sum_list xs + sum_list ys"
  by (induction xs ys rule: addv.induct) auto

lemma sum_step: "sum_list (step_k f old) = f * sum_list old"
  by (induction f) (simp_all add: sum_addv)

text \<open>The counts add up to all @{text "s^n"} equally likely outcomes.\<close>
theorem sum_dist: "sum_list (dice_dist n s) = s ^ n"
  by (induction n) (simp_all add: sum_step)

section \<open>Poker hands\<close>

fun ff :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "ff n 0 = 1"
| "ff n (Suc k) = n * ff (n - 1) k"

lemma ff2: "ff n 2 = n * (n - 1)" by (simp add: numeral_eq_Suc)
lemma ff3: "ff n 3 = n * (n - 1) * (n - 2)" by (simp add: numeral_eq_Suc)
lemma ff5: "ff n 5 = n * (n - 1) * (n - 2) * (n - 3) * (n - 4)" by (simp add: numeral_eq_Suc)
lemma fact2: "fact (2::nat) = 2" by (simp add: numeral_eq_Suc)
lemma fact3: "fact (3::nat) = 6" by (simp add: numeral_eq_Suc)
lemma fact5: "fact (5::nat) = 120" by (simp add: numeral_eq_Suc)

definition cm :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "cm n k = ff n k div fact k"


datatype hand = H_royal | H_straight_flush | H_four | H_full_house | H_flush
  | H_straight | H_three | H_two_pair | H_pair

fun hand_count :: "hand \<Rightarrow> nat" where
  "hand_count H_royal = 4"
| "hand_count H_straight_flush = 36"
| "hand_count H_four = 13 * 48"
| "hand_count H_full_house = 13 * cm 4 3 * 12 * cm 4 2"
| "hand_count H_flush = 4 * cm 13 5 - 40"
| "hand_count H_straight = 10 * 4 ^ 5 - 40"
| "hand_count H_three = 13 * cm 4 3 * cm 12 2 * 16"
| "hand_count H_two_pair = cm 13 2 * cm 4 2 ^ 2 * 44"
| "hand_count H_pair = 13 * cm 4 2 * cm 12 3 * 64"

definition hand_total :: nat where "hand_total = cm 52 5"

definition hand_list :: "hand list" where
  "hand_list = [H_royal, H_straight_flush, H_four, H_full_house, H_flush, H_straight,
                H_three, H_two_pair, H_pair]"

theorem hand_values:
  "map hand_count hand_list = [4, 36, 624, 3744, 5108, 10200, 54912, 123552, 1098240]
   \<and> hand_total = 2598960"
  unfolding hand_list_def hand_total_def by (simp add: cm_def ff2 ff3 ff5 fact2 fact3 fact5)

text \<open>Partition check: the nine named hands and the 1,302,540 hands with no
combination add up to every five-card hand.\<close>
theorem hand_partition: "sum_list (map hand_count hand_list) + 1302540 = hand_total"
  unfolding hand_list_def hand_total_def by (simp add: cm_def ff2 ff3 ff5 fact2 fact3 fact5)

section \<open>Cards\<close>

datatype card = C_ace | C_king | C_queen | C_jack | C_face | C_heart | C_spade
  | C_diamond | C_club | C_red | C_black

fun card_good :: "card \<Rightarrow> nat" where
  "card_good C_ace = 4" | "card_good C_king = 4" | "card_good C_queen = 4"
| "card_good C_jack = 4" | "card_good C_face = 12" | "card_good C_heart = 13"
| "card_good C_spade = 13" | "card_good C_diamond = 13" | "card_good C_club = 13"
| "card_good C_red = 26" | "card_good C_black = 26"

fun seq_prob :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> rat" where
  "seq_prob g n 0 = 1"
| "seq_prob g n (Suc k) = (rat_of_nat g / rat_of_nat n) * seq_prob (g - 1) (n - 1) k"

text \<open>k draws in a row without replacement, all good: the probability times
the number of ordered k-card sequences from the deck is the number of ordered
k-card sequences of good cards.\<close>
theorem seq_prob_ordered:
  "g \<le> n \<Longrightarrow> seq_prob g n k * rat_of_nat (ff n k) = rat_of_nat (ff g k)"
proof (induction k arbitrary: g n)
  case 0
  show ?case by simp
next
  case (Suc k)
  show ?case
  proof (cases "n = 0")
    case True
    with Suc.prems have "g = 0" by simp
    with True show ?thesis by simp
  next
    case False
    have ih: "seq_prob (g - 1) (n - 1) k * rat_of_nat (ff (n - 1) k) = rat_of_nat (ff (g - 1) k)"
      using Suc.IH[of "g - 1" "n - 1"] Suc.prems by simp
    have "seq_prob g n (Suc k) * rat_of_nat (ff n (Suc k))
        = (rat_of_nat g / rat_of_nat n) * rat_of_nat n * (seq_prob (g - 1) (n - 1) k * rat_of_nat (ff (n - 1) k))"
      by (simp add: algebra_simps)
    also have "\<dots> = rat_of_nat g * rat_of_nat (ff (g - 1) k)"
    proof -
      have nn: "rat_of_nat n \<noteq> 0" using False by simp
      have "(rat_of_nat g / rat_of_nat n) * rat_of_nat n = rat_of_nat g" using nn by (simp add: field_simps)
      then show ?thesis using ih by simp
    qed
    finally show ?thesis by simp
  qed
qed

section \<open>Requests and the kernel\<close>

datatype gkind = GK_poker_prob | GK_poker_count | GK_dice_sum | GK_at_least_one
  | GK_card_one | GK_card_k | GK_card_k_repl | GK_anagrams

datatype gdecl = GD_impossible nat nat nat | GD_no_word | GD_no_rolls

datatype greq =
    G_poker bool hand
  | G_dice nat nat nat
  | G_atleast nat nat
  | G_atleast_unknown
  | G_card_one card
  | G_card_k card nat bool
  | G_anagram "nat list"
  | G_anagram_none

datatype gout = GProb gkind rat | GCount gkind nat | GDecline gdecl

fun g_kernel :: "greq \<Rightarrow> gout" where
  "g_kernel (G_poker True h) = GCount GK_poker_count (hand_count h)"
| "g_kernel (G_poker False h) = GProb GK_poker_prob (rat_of_nat (hand_count h) / rat_of_nat hand_total)"
| "g_kernel (G_dice n s k) =
     (if atn (dice_dist n s) k = 0 then GDecline (GD_impossible k n s)
      else GProb GK_dice_sum (rat_of_nat (atn (dice_dist n s) k) / rat_of_nat (s ^ n)))"
| "g_kernel (G_atleast s k) = GProb GK_at_least_one (1 - (rat_of_nat (s - 1) / rat_of_nat s) ^ k)"
| "g_kernel G_atleast_unknown = GDecline GD_no_rolls"
| "g_kernel (G_card_one c) = GProb GK_card_one (rat_of_nat (card_good c) / 52)"
| "g_kernel (G_card_k c k repl) =
     (if repl then GProb GK_card_k_repl ((rat_of_nat (card_good c) / 52) ^ k)
      else GProb GK_card_k (seq_prob (card_good c) 52 k))"
| "g_kernel (G_anagram w) = GCount GK_anagrams (anagram_count w)"
| "g_kernel G_anagram_none = GDecline GD_no_word"

theorem dice_value:
  "g_kernel (G_dice n s k) = GProb GK_dice_sum p \<Longrightarrow>
     p = rat_of_nat (ways n s k) / rat_of_nat (s ^ n) \<and> 0 < ways n s k"
  by (auto simp: dist_ways split: if_splits)

theorem dice_impossible:
  "g_kernel (G_dice n s k) = GDecline (GD_impossible k' n' s') \<longleftrightarrow>
     ways n s k = 0 \<and> k' = k \<and> n' = n \<and> s' = s"
  by (auto simp: dist_ways split: if_splits)

theorem atleast_value:
  "g_kernel (G_atleast s k) = GProb GK_at_least_one p \<Longrightarrow>
     p + (rat_of_nat (s - 1) / rat_of_nat s) ^ k = 1"
  by simp

theorem atleast_range:
  assumes "1 \<le> s" and "g_kernel (G_atleast s k) = GProb GK_at_least_one p"
  shows "0 \<le> p \<and> p \<le> 1"
proof -
  have a0: "0 \<le> rat_of_nat (s - 1) / rat_of_nat s" by simp
  have sp: "0 < rat_of_nat s" using assms(1) by simp
  have a1: "rat_of_nat (s - 1) / rat_of_nat s \<le> 1"
    by (simp add: pos_divide_le_eq[OF sp])
  have "(rat_of_nat (s - 1) / rat_of_nat s) ^ k \<le> 1" using power_le_one[OF a0 a1] .
  moreover have "0 \<le> (rat_of_nat (s - 1) / rat_of_nat s) ^ k" using a0 by simp
  ultimately show ?thesis using assms(2) by auto
qed

theorem card_one_value:
  "g_kernel (G_card_one c) = GProb GK_card_one p \<Longrightarrow> p * 52 = rat_of_nat (card_good c)"
  by simp

theorem card_k_ordered:
  "g_kernel (G_card_k c k False) = GProb GK_card_k p \<Longrightarrow>
     p * rat_of_nat (ff 52 k) = rat_of_nat (ff (card_good c) k)"
  using seq_prob_ordered[of "card_good c" 52 k] by (cases c) auto

theorem card_k_repl_value:
  "g_kernel (G_card_k c k True) = GProb GK_card_k_repl p \<Longrightarrow> p = (rat_of_nat (card_good c) / 52) ^ k"
  by simp

theorem poker_value:
  "g_kernel (G_poker False h) = GProb GK_poker_prob p \<Longrightarrow>
     p * rat_of_nat hand_total = rat_of_nat (hand_count h)"
proof -
  assume h: "g_kernel (G_poker False h) = GProb GK_poker_prob p"
  have p: "p = rat_of_nat (hand_count h) / rat_of_nat hand_total" using h by simp
  have t: "hand_total = 2598960" using hand_values by simp
  show ?thesis unfolding p t by simp
qed

theorem anagram_value:
  "g_kernel (G_anagram w) = GCount GK_anagrams v \<Longrightarrow>
     v * prod_list (map fact (letter_counts w)) = fact (length w)"
proof -
  assume h: "g_kernel (G_anagram w) = GCount GK_anagrams v"
  have "v = anagram_count w" using h by simp
  then show ?thesis using anagram_equation[of w] by simp
qed

section \<open>Reply text (ASCII)\<close>

fun hand_name :: "hand \<Rightarrow> String.literal" where
  "hand_name H_royal = STR ''royal flush''" | "hand_name H_straight_flush = STR ''straight flush''"
| "hand_name H_four = STR ''four of a kind''" | "hand_name H_full_house = STR ''full house''"
| "hand_name H_flush = STR ''flush''" | "hand_name H_straight = STR ''straight''"
| "hand_name H_three = STR ''three of a kind''" | "hand_name H_two_pair = STR ''two pair''"
| "hand_name H_pair = STR ''one pair''"

fun hand_extra :: "hand \<Rightarrow> String.literal" where
  "hand_extra H_flush = STR '', straight flushes excluded''"
| "hand_extra H_straight = STR '', straight flushes excluded''"
| "hand_extra H_straight_flush = STR '', royal flushes excluded''"
| "hand_extra h = STR ''''"

fun card_label :: "card \<Rightarrow> String.literal" where
  "card_label C_ace = STR ''ace''" | "card_label C_king = STR ''king''"
| "card_label C_queen = STR ''queen''" | "card_label C_jack = STR ''jack''"
| "card_label C_face = STR ''face card''" | "card_label C_heart = STR ''heart''"
| "card_label C_spade = STR ''spade''" | "card_label C_diamond = STR ''diamond''"
| "card_label C_club = STR ''club''" | "card_label C_red = STR ''red card''"
| "card_label C_black = STR ''black card''"

fun seq_parts :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> String.literal list" where
  "seq_parts g n 0 = []"
| "seq_parts g n (Suc k) = (show_nat g + STR ''/'' + show_nat n) # seq_parts (g - 1) (n - 1) k"

definition join_x :: "String.literal list \<Rightarrow> String.literal" where
  "join_x xs = (case xs of [] \<Rightarrow> STR '''' | x # r \<Rightarrow> foldl (\<lambda>a b. a + STR '' x '' + b) x r)"

definition frac_reply :: "String.literal \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> piece list" where
  "frac_reply k p why = [PS (STR ''The probability is '' + show_frac p + STR '' ('' + pct_text p
      + STR ''%; '' + why + STR '').'')]"

definition anagram_den :: "nat list \<Rightarrow> String.literal" where
  "anagram_den w = (let cs = filter (\<lambda>c. 1 < c) (letter_counts w) in
      if cs = [] then STR ''1'' else join_x (map (\<lambda>c. show_nat c + STR ''!'') cs))"

definition gk_name :: "gkind \<Rightarrow> String.literal" where
  "gk_name k = (case k of GK_poker_prob \<Rightarrow> STR ''poker_prob'' | GK_poker_count \<Rightarrow> STR ''poker_count''
     | GK_dice_sum \<Rightarrow> STR ''dice_sum'' | GK_at_least_one \<Rightarrow> STR ''at_least_one''
     | GK_card_one \<Rightarrow> STR ''card_one'' | GK_card_k \<Rightarrow> STR ''card_k''
     | GK_card_k_repl \<Rightarrow> STR ''card_k_repl'' | GK_anagrams \<Rightarrow> STR ''anagrams'')"

definition g_reply :: "greq \<Rightarrow> reply" where
  "g_reply r = (case g_kernel r of
     GProb k p \<Rightarrow>
       let why = (case r of
          G_poker b h \<Rightarrow> commas (hand_count h) + STR '' of '' + commas hand_total
              + STR '' five-card hands are a '' + hand_name h + hand_extra h
        | G_dice n s kk \<Rightarrow> show_nat (atn (dice_dist n s) kk) + STR '' of the '' + commas (s ^ n)
              + STR '' equally likely outcomes of '' + show_nat n + STR '' d'' + show_nat s
              + STR '' total '' + show_nat kk
        | G_atleast s kk \<Rightarrow> STR ''1 - ('' + show_nat (s - 1) + STR ''/'' + show_nat s + STR '')^'' + show_nat kk
        | G_card_one c \<Rightarrow> show_nat (card_good c) + STR '' '' + card_label c + STR ''s in 52 cards''
        | G_card_k c kk b \<Rightarrow>
            (if b then STR ''('' + show_nat (card_good c) + STR ''/52)^'' + show_nat kk + STR '', with replacement''
             else join_x (seq_parts (card_good c) 52 kk) + STR '', without replacement'')
        | _ \<Rightarrow> STR '''')
       in Reply True (gk_name k) (frac_reply (gk_name k) p why) JNone
   | GCount k n \<Rightarrow>
       (case r of
          G_poker b h \<Rightarrow>
            Reply True (gk_name k)
              [PS (STR ''There are '' + commas n + STR '' '' + hand_name h + STR '' hands (of ''
                  + commas hand_total + STR '' five-card hands)'' + STR ''.'')] (JRaw (show_nat n))
        | G_anagram w \<Rightarrow>
            Reply True (gk_name k)
              ([PS (STR ''The number of distinct arrangements is '' + commas n + STR '' (''
                  + show_nat (length w) + STR ''! / ('' + anagram_den w + STR '') for ''), PB w, PS (STR '').'')])
              (JRaw (show_nat n))
        | _ \<Rightarrow> Reply True (gk_name k) [] JNone)
   | GDecline (GD_impossible kk n s) \<Rightarrow>
       Reply False (STR ''impossible'')
         [PS (show_nat kk + STR '' is not a possible total with '' + show_nat n + STR '' ''
             + show_nat s + STR ''-sided dice (range '' + show_nat n + STR ''-'' + show_nat (n * s) + STR '').'')] JNone
   | GDecline GD_no_word \<Rightarrow>
       Reply False (STR ''underspecified'')
         [PS (STR ''Which word? Give it like the word BANANA and I will count the distinct arrangements.'')] JNone
   | GDecline GD_no_rolls \<Rightarrow>
       Reply False (STR ''underspecified'')
         [PS (STR ''I could not tell how many rolls that is; say in 10 rolls and I will work it out.'')] JNone)"

theorem g_reply_answered:
  "answered (g_reply r) \<longleftrightarrow> (\<forall>d. g_kernel r \<noteq> GDecline d)"
  by (cases r) (auto simp: g_reply_def split: gout.splits gdecl.splits greq.splits if_splits)

end
