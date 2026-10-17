theory Facts_Kernel
  imports Main
begin

text \<open>Lane O19: the FactsOrgan interpreter shared by 22 Oracle7 specialists
(\<open>upstream/root/specialists/*/organ_facts_v1.py\<close>, one file, byte-identical in
every folder). A store supplies a GATE pattern a turn must match, an optional BLOCK
pattern it must not match, an ASK pattern marking a question, and FACTS: an ordered
table of rows (pattern, value, sentence). The first row whose pattern matches
answers with its sentence; when none does the organ is silent.

The kernel never reads text. Its input is the narrowing verdict and a feature map
\<open>m :: String.literal \<Rightarrow> bool\<close> that says, for a pattern of the store, whether
that pattern matches the turn. Both come from the UNTRUSTED recognizer
(\<open>recognizer.sml\<close>, a port of Python \<open>re\<close> and \<open>narrow_v1\<close>). What is proved
here is everything after the features: which row answers, that the reply is that
row's value and sentence verbatim, and exactly when the organ stays silent.\<close>

datatype rule = Rule (guard: String.literal) (fact_value: String.literal) (sentence: String.literal)

datatype store = Store
  (store_name: String.literal) (store_kind: String.literal) (store_gate: String.literal)
  (store_block: "String.literal option") (store_ask: String.literal) (store_rules: "rule list")

text \<open>An organ is a store plus an optional boundary (medicine-r2's
\<open>FactsOrganBoundary\<close>): a pair (NOT_MINE, MINE); the organ is silent when the turn
matches NOT_MINE and not MINE.\<close>
datatype organ = Organ
  (organ_id: String.literal) (organ_boundary: "(String.literal \<times> String.literal) option")
  (organ_store: store)

type_synonym features = "String.literal \<Rightarrow> bool"

datatype silence = Boundary | Narrative | Off_gate | Blocked | Not_asked | No_rule

datatype outcome =
    Answer (out_kind: String.literal) (out_value: String.literal) (out_sentence: String.literal)
      (out_store: String.literal) (out_row: nat)
  | Silent silence

subsection \<open>The ordered rule table\<close>

text \<open>First-match interpretation: the first row, in table order, whose guard the
features accept, with its row number (0-based, as the store's list index).\<close>
fun interpret_table :: "features \<Rightarrow> rule list \<Rightarrow> (nat \<times> rule) option" where
  "interpret_table m [] = None"
| "interpret_table m (r # rs) =
     (if m (guard r) then Some (0, r) else map_option (\<lambda>(i, x). (Suc i, x)) (interpret_table m rs))"

lemma all_less_Suc_split: "(\<forall>j<Suc k. P j) \<longleftrightarrow> P 0 \<and> (\<forall>j<k. P (Suc j))"
  by (auto simp: less_Suc_eq_0_disj)

lemma map_option_Suc_eq:
  "map_option (\<lambda>(i, x). (Suc i, x)) X = Some (Suc k, r) \<longleftrightarrow> X = Some (k, r)"
  by (cases X) (auto split: prod.splits)

lemma map_option_Suc_neq_0:
  "map_option (\<lambda>(i, x). (Suc i, x)) X \<noteq> Some (0, r)"
  by (cases X) (auto split: prod.splits)

theorem first_match:
  "interpret_table m rs = Some (i, r) \<longleftrightarrow>
     i < length rs \<and> rs ! i = r \<and> m (guard r) \<and> (\<forall>j<i. \<not> m (guard (rs ! j)))"
proof (induction rs arbitrary: i)
  case Nil
  then show ?case by simp
next
  case (Cons a rs)
  show ?case
  proof (cases i)
    case 0
    then show ?thesis by (auto simp: map_option_Suc_neq_0)
  next
    case (Suc k)
    then show ?thesis using Cons.IH[of k] by (auto simp: map_option_Suc_eq all_less_Suc_split)
  qed
qed

theorem no_rule_no_answer:
  "interpret_table m rs = None \<longleftrightarrow> (\<forall>r \<in> set rs. \<not> m (guard r))"
  by (induction rs) auto

text \<open>Determinism needs no theorem (the interpreter is a function); what matters
is that only the features of the table's own guards can change the answer.\<close>
theorem interpret_table_local:
  assumes "\<forall>r \<in> set rs. m (guard r) = m' (guard r)"
  shows "interpret_table m rs = interpret_table m' rs"
  using assms by (induction rs) auto

text \<open>Order is part of the specification: two rows that both fire and carry
different values give different answers in the two orders.\<close>
theorem order_matters:
  assumes "m (guard r1)" "m (guard r2)" "fact_value r1 \<noteq> fact_value r2"
  shows "map_option (fact_value \<circ> snd) (interpret_table m (r1 # r2 # rs)) = Some (fact_value r1)"
    and "map_option (fact_value \<circ> snd) (interpret_table m (r2 # r1 # rs)) = Some (fact_value r2)"
    and "interpret_table m (r1 # r2 # rs) \<noteq> interpret_table m (r2 # r1 # rs)"
  using assms by auto

text \<open>A table is well formed when it is non-empty, no guard or sentence is the
empty string (an empty pattern matches every turn and would make every later row
dead), and no guard is repeated (a repeated guard's later row is dead).\<close>
definition table_well_formed :: "rule list \<Rightarrow> bool" where
  "table_well_formed rs \<longleftrightarrow>
     rs \<noteq> [] \<and> distinct (map guard rs) \<and>
     (\<forall>r \<in> set rs. guard r \<noteq> 0 \<and> sentence r \<noteq> 0 \<and> fact_value r \<noteq> 0)"

subsection \<open>The organ\<close>

definition blocked :: "features \<Rightarrow> store \<Rightarrow> bool" where
  "blocked m st = (case store_block st of Some b \<Rightarrow> m b | None \<Rightarrow> False)"

definition boundary_silent :: "features \<Rightarrow> organ \<Rightarrow> bool" where
  "boundary_silent m og = (case organ_boundary og of Some (nm, mi) \<Rightarrow> m nm \<and> \<not> m mi | None \<Rightarrow> False)"

text \<open>\<open>FactsOrgan.answer\<close> (and \<open>FactsOrganBoundary.answer\<close> before it), step for
step: boundary, narrowing, gate, block, ask, then the table.\<close>
definition store_reply :: "bool \<Rightarrow> features \<Rightarrow> store \<Rightarrow> outcome" where
  "store_reply narr m st =
     (if narr then Silent Narrative
      else if \<not> m (store_gate st) then Silent Off_gate
      else if blocked m st then Silent Blocked
      else if \<not> m (store_ask st) then Silent Not_asked
      else case interpret_table m (store_rules st) of
             None \<Rightarrow> Silent No_rule
           | Some (i, r) \<Rightarrow> Answer (store_kind st) (fact_value r) (sentence r) (store_name st) i)"

definition organ_reply :: "bool \<Rightarrow> features \<Rightarrow> organ \<Rightarrow> outcome" where
  "organ_reply narr m og =
     (if boundary_silent m og then Silent Boundary else store_reply narr m (organ_store og))"

definition admitted :: "bool \<Rightarrow> features \<Rightarrow> organ \<Rightarrow> bool" where
  "admitted narr m og \<longleftrightarrow>
     \<not> boundary_silent m og \<and> \<not> narr \<and> m (store_gate (organ_store og)) \<and>
     \<not> blocked m (organ_store og) \<and> m (store_ask (organ_store og))"

text \<open>The organ answers with row \<open>i\<close> exactly when the turn is admitted (boundary,
narrowing, gate, block and ask all pass on the supplied features) and row \<open>i\<close> is the
first row of the table whose guard holds; the reply is that row's value and
sentence, verbatim, under the store's kind.\<close>
theorem guard_exact:
  "organ_reply narr m og = Answer k v s n i \<longleftrightarrow>
     admitted narr m og \<and>
     i < length (store_rules (organ_store og)) \<and>
     m (guard (store_rules (organ_store og) ! i)) \<and>
     (\<forall>j<i. \<not> m (guard (store_rules (organ_store og) ! j))) \<and>
     k = store_kind (organ_store og) \<and> n = store_name (organ_store og) \<and>
     v = fact_value (store_rules (organ_store og) ! i) \<and>
     s = sentence (store_rules (organ_store og) ! i)"
proof -
  let ?rs = "store_rules (organ_store og)"
  have "organ_reply narr m og = Answer k v s n i \<longleftrightarrow>
        admitted narr m og \<and> (\<exists>r. interpret_table m ?rs = Some (i, r) \<and>
          k = store_kind (organ_store og) \<and> n = store_name (organ_store og) \<and>
          v = fact_value r \<and> s = sentence r)"
    by (auto simp: organ_reply_def store_reply_def admitted_def split: option.splits prod.splits)
  also have "\<dots> \<longleftrightarrow> admitted narr m og \<and>
     i < length ?rs \<and> m (guard (?rs ! i)) \<and> (\<forall>j<i. \<not> m (guard (?rs ! j))) \<and>
     k = store_kind (organ_store og) \<and> n = store_name (organ_store og) \<and>
     v = fact_value (?rs ! i) \<and> s = sentence (?rs ! i)"
    by (auto simp: first_match)
  finally show ?thesis .
qed

theorem answer_from_table:
  "organ_reply narr m og = Answer k v s n i \<Longrightarrow> Rule (guard (store_rules (organ_store og) ! i)) v s \<in> set (store_rules (organ_store og))"
  using nth_mem by (fastforce simp: guard_exact rule.collapse)

text \<open>Silence, with its reason: the first check that fails, in the organ's order.\<close>
theorem organ_silent:
  "organ_reply narr m og = Silent why \<longleftrightarrow>
     (if boundary_silent m og then why = Boundary
      else if narr then why = Narrative
      else if \<not> m (store_gate (organ_store og)) then why = Off_gate
      else if blocked m (organ_store og) then why = Blocked
      else if \<not> m (store_ask (organ_store og)) then why = Not_asked
      else why = No_rule \<and> (\<forall>r \<in> set (store_rules (organ_store og)). \<not> m (guard r)))"
  by (auto simp: organ_reply_def store_reply_def no_rule_no_answer[symmetric] split: option.splits prod.splits)

theorem no_rule_silent:
  "admitted narr m og \<Longrightarrow>
     organ_reply narr m og = Silent No_rule \<longleftrightarrow> (\<forall>r \<in> set (store_rules (organ_store og)). \<not> m (guard r))"
  by (auto simp: admitted_def organ_silent)

text \<open>medicine-r2's boundary only narrows: wherever the bounded organ answers, the
same store without a boundary gives the same answer (the docstring's "Nothing else
changes").\<close>
theorem boundary_narrows:
  "organ_reply narr m (Organ d (Some b) st) = Answer k v s n i \<Longrightarrow>
   organ_reply narr m (Organ d' None st) = Answer k v s n i"
  by (cases b) (auto simp: guard_exact admitted_def boundary_silent_def)

theorem boundary_only_silences:
  "\<not> boundary_silent m (Organ d (Some b) st) \<Longrightarrow>
   organ_reply narr m (Organ d (Some b) st) = organ_reply narr m (Organ d' None st)"
  by (simp add: organ_reply_def boundary_silent_def[of m "Organ d' None st"])

subsection \<open>The family\<close>

text \<open>Without a named specialist the binary asks the organs in a fixed order; the
first organ that answers gives the reply.\<close>
fun family_reply :: "bool \<Rightarrow> features \<Rightarrow> organ list \<Rightarrow> (String.literal \<times> outcome) option" where
  "family_reply narr m [] = None"
| "family_reply narr m (og # ogs) =
     (case organ_reply narr m og of
        Answer k v s n i \<Rightarrow> Some (organ_id og, Answer k v s n i)
      | Silent _ \<Rightarrow> family_reply narr m ogs)"

theorem family_first:
  "family_reply narr m ogs = Some (d, a) \<Longrightarrow>
     \<exists>i<length ogs. organ_id (ogs ! i) = d \<and> organ_reply narr m (ogs ! i) = a \<and>
       (\<exists>k v s n r. a = Answer k v s n r) \<and>
       (\<forall>j<i. \<exists>why. organ_reply narr m (ogs ! j) = Silent why)"
proof (induction ogs)
  case Nil
  then show ?case by simp
next
  case (Cons og ogs)
  show ?case
  proof (cases "organ_reply narr m og")
    case (Answer k v s n r)
    with Cons.prems show ?thesis by (intro exI[of _ 0]) (auto simp: Answer)
  next
    case (Silent why)
    from Cons.prems Silent have "family_reply narr m ogs = Some (d, a)" by simp
    then obtain i where i: "i < length ogs" "organ_id (ogs ! i) = d"
        "organ_reply narr m (ogs ! i) = a" "\<exists>k v s n r. a = Answer k v s n r"
        "\<forall>j<i. \<exists>why. organ_reply narr m (ogs ! j) = Silent why"
      using Cons.IH by blast
    have "\<forall>j<Suc i. \<exists>why. organ_reply narr m ((og # ogs) ! j) = Silent why"
      using i(5) Silent by (simp add: all_less_Suc_split)
    with i show ?thesis by (intro exI[of _ "Suc i"]) auto
  qed
qed

theorem family_none:
  "family_reply narr m ogs = None \<longleftrightarrow> (\<forall>og \<in> set ogs. \<exists>why. organ_reply narr m og = Silent why)"
  by (induction ogs) (auto split: outcome.splits)

end
