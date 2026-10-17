theory Government
  imports Facts_Common
begin

text \<open>
  Oracle7 government (upstream/root/specialists/government/organ_government_v1.py): the US
  Constitution as a store: the 27 amendments, which amendment covers a topic, Articles
  I-VII and fixed structural numbers. The untrusted recognizer matches the organ's ordered
  topic and fact patterns and passes one bit per rule; the kernel takes the first rule
  whose bit is set.
\<close>

definition amendments :: "String.literal list" where
  "amendments = [
    STR ''freedom of religion, speech, the press, assembly and petition'',
    STR ''the right to keep and bear arms'',
    STR ''no quartering of soldiers in private homes'',
    STR ''protection against unreasonable searches and seizures'',
    STR ''due process, no self-incrimination, no double jeopardy, grand juries, just compensation for takings'',
    STR ''a speedy and public jury trial and the right to counsel in criminal cases'',
    STR ''jury trial in civil cases'',
    STR ''no excessive bail or fines and no cruel and unusual punishment'',
    STR ''rights retained by the people beyond those listed'',
    STR ''powers not delegated to the federal government are reserved to the states or the people'',
    STR ''limits on suits against states in federal court'',
    STR ''separate electoral votes for President and Vice President'',
    STR ''abolished slavery'',
    STR ''citizenship, due process and equal protection of the laws'',
    STR ''voting rights regardless of race'',
    STR ''the federal income tax'',
    STR ''direct election of senators'',
    STR ''prohibition of alcohol'',
    STR ''women'' + apos + STR ''s right to vote'',
    STR ''terms begin in January (the lame-duck amendment)'',
    STR ''repealed prohibition'',
    STR ''a two-term limit for the President'',
    STR ''electoral votes for Washington, D.C.'',
    STR ''abolished poll taxes in federal elections'',
    STR ''presidential succession and disability'',
    STR ''voting age of 18'',
    STR ''congressional pay changes take effect only after an election'']"

definition articles :: "String.literal list" where
  "articles = [
    STR ''the legislative branch (Congress)'',
    STR ''the executive branch (the President)'',
    STR ''the judicial branch (the Supreme Court and federal courts)'',
    STR ''the states and relations between them'',
    STR ''the amendment process'',
    STR ''federal supremacy, national debts and oaths of office'',
    STR ''ratification of the Constitution'']"

text \<open>The amendment each topic rule answers, in the organ's TOPIC order.\<close>
definition topic_nums :: "nat list" where
  "topic_nums = [13, 19, 16, 21, 18, 26, 22, 24, 17, 14, 1, 2, 3, 4, 5, 6, 8, 10, 25, 15, 23, 27, 20]"

text \<open>FACTS: the number and the sentence stating it, in the organ's order.\<close>
definition fact_rows :: "(nat \<times> String.literal) list" where
  "fact_rows = [
    (100, STR ''There are 100 senators (2 per state, Article I and the 17th Amendment).''),
    (435, STR ''There are 435 voting members of the House of Representatives (fixed by statute since 1929).''),
    (538, STR ''There are 538 electors (435 + 100 + 3 for D.C.).''),
    (270, STR ''It takes 270 electoral votes to win (a majority of 538).''),
    (27, STR ''The Constitution has 27 amendments.''),
    (9, STR ''There are 9 Supreme Court justices (set by statute, 1869).''),
    (6, STR ''A senator'' + apos + STR ''s term is 6 years.''),
    (2, STR ''A representative'' + apos + STR ''s term is 2 years.''),
    (4, STR ''A presidential term is 4 years.''),
    (35, STR ''A President must be at least 35 years old (Article II).''),
    (30, STR ''A senator must be at least 30 years old (Article I).''),
    (25, STR ''A representative must be at least 25 years old (Article I).''),
    (10, STR ''The Bill of Rights is the first 10 amendments.'')]"

datatype vreq = VTopic "bool list" | VAmend nat | VArticle nat | VFact "bool list"

datatype vout =
    VSilent
  | VTopicV nat String.literal
  | VAmendV nat String.literal
  | VImposs nat
  | VArtV nat String.literal
  | VFactV nat String.literal

definition vkernel :: "vreq \<Rightarrow> vout" where
  "vkernel r = (case r of
      VTopic bs \<Rightarrow> (case pick bs topic_nums of Some n \<Rightarrow> VTopicV n (amendments ! (n - 1)) | None \<Rightarrow> VSilent)
    | VAmend n \<Rightarrow> (if 1 \<le> n \<and> n \<le> length amendments then VAmendV n (amendments ! (n - 1)) else VImposs n)
    | VArticle n \<Rightarrow> (if 1 \<le> n \<and> n \<le> length articles then VArtV n (articles ! (n - 1)) else VSilent)
    | VFact bs \<Rightarrow> (case pick bs fact_rows of Some (v, s) \<Rightarrow> VFactV v s | None \<Rightarrow> VSilent))"

theorem amendments_count: "length amendments = 27"
  by (simp add: amendments_def)

theorem articles_count: "length articles = 7"
  by (simp add: articles_def)

theorem topics_are_amendments: "\<forall>n\<in>set topic_nums. 1 \<le> n \<and> n \<le> length amendments"
  by (simp add: topic_nums_def amendments_def)

text \<open>The structural numbers agree with each other and with the amendment table.\<close>
theorem electors_sum:
  "fst (fact_rows ! 2) = fst (fact_rows ! 1) + fst (fact_rows ! 0) + 3"
  by (simp add: fact_rows_def)

theorem electoral_majority:
  "fst (fact_rows ! 3) = fst (fact_rows ! 2) div 2 + 1"
  by (simp add: fact_rows_def)

theorem amendment_count_fact: "fst (fact_rows ! 4) = length amendments"
  by (simp add: fact_rows_def amendments_def)

theorem bill_of_rights_is_first_ten:
  "fst (fact_rows ! 12) = 10 \<and> 10 \<le> length amendments"
  by (simp add: fact_rows_def amendments_def)

theorem topic_value:
  "vkernel (VTopic bs) = VTopicV n t \<Longrightarrow>
     1 \<le> n \<and> n \<le> 27 \<and> amendments ! (n - 1) = t \<and>
     (\<exists>i. i < length bs \<and> i < length topic_nums \<and> bs ! i \<and> topic_nums ! i = n \<and> (\<forall>j<i. \<not> bs ! j))"
proof -
  assume h: "vkernel (VTopic bs) = VTopicV n t"
  obtain n' where p: "pick bs topic_nums = Some n'"
    using h by (cases "pick bs topic_nums") (auto simp: vkernel_def)
  have h1: "vkernel (VTopic bs) = VTopicV n' (amendments ! (n' - 1))" using p by (simp add: vkernel_def)
  have h2: "VTopicV n' (amendments ! (n' - 1)) = VTopicV n t" using h1 h by simp
  have e: "n' = n \<and> amendments ! (n' - 1) = t" by (rule iffD1[OF vout.inject(1) h2])
  from pick_some[OF p] obtain i where
    i: "i < length bs \<and> i < length topic_nums \<and> bs ! i \<and> topic_nums ! i = n' \<and> (\<forall>j<i. \<not> bs ! j)"
    by blast
  have mem: "n' \<in> set topic_nums" using i by (metis nth_mem)
  have rng: "1 \<le> n' \<and> n' \<le> length amendments" using topics_are_amendments mem by blast
  have n: "n' = n" using e by blast
  have a2: "amendments ! (n - 1) = t" using e n by metis
  have rng2: "1 \<le> n \<and> n \<le> 27" using rng n amendments_count by simp
  have i2: "i < length bs \<and> i < length topic_nums \<and> bs ! i \<and> topic_nums ! i = n \<and> (\<forall>j<i. \<not> bs ! j)"
    using i n by simp
  show ?thesis using rng2 a2 i2 by blast
qed

theorem amend_value:
  "vkernel (VAmend n) = VAmendV m t \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> 27 \<and> amendments ! (n - 1) = t"
  by (auto simp: vkernel_def amendments_count split: if_splits)

theorem amend_impossible:
  "vkernel (VAmend n) = VImposs m \<longleftrightarrow> m = n \<and> (n < 1 \<or> 27 < n)"
  by (auto simp: vkernel_def amendments_count split: if_splits)

theorem article_value:
  "vkernel (VArticle n) = VArtV m t \<Longrightarrow> m = n \<and> 1 \<le> n \<and> n \<le> 7 \<and> articles ! (n - 1) = t"
  by (auto simp: vkernel_def articles_count split: if_splits)

theorem fact_value:
  "vkernel (VFact bs) = VFactV v s \<Longrightarrow>
     \<exists>i. i < length bs \<and> i < length fact_rows \<and> bs ! i \<and> fact_rows ! i = (v, s) \<and> (\<forall>j<i. \<not> bs ! j)"
  by (auto simp: vkernel_def dest: pick_some split: option.splits prod.splits)

definition roman :: "nat \<Rightarrow> String.literal" where
  "roman n = (if n = 1 then STR ''I'' else if n = 2 then STR ''II'' else if n = 3 then STR ''III''
     else if n = 4 then STR ''IV'' else if n = 5 then STR ''V'' else if n = 6 then STR ''VI''
     else if n = 7 then STR ''VII'' else STR ''?'')"

definition vtext :: "vout \<Rightarrow> String.literal" where
  "vtext res = (case res of
      VSilent \<Rightarrow> STR ''''
    | VTopicV n t \<Rightarrow> cat [STR ''It is the '', ordinal n, STR '' Amendment: '', t, STR ''.'']
    | VAmendV n t \<Rightarrow> cat [STR ''The '', ordinal n, STR '' Amendment covers '', t, STR ''.'']
    | VImposs n \<Rightarrow> cat [STR ''The US Constitution has 27 amendments; there is no '', ordinal n, STR '' Amendment.'']
    | VArtV n t \<Rightarrow> cat [STR ''Article '', roman n, STR '' covers '', t, STR ''.'']
    | VFactV v s \<Rightarrow> s)"

definition vkind :: "vout \<Rightarrow> String.literal" where
  "vkind res = (case res of VSilent \<Rightarrow> STR ''silent'' | VTopicV n t \<Rightarrow> STR ''amend_for_topic''
               | VAmendV n t \<Rightarrow> STR ''amend_subject'' | VImposs n \<Rightarrow> STR ''impossible''
               | VArtV n t \<Rightarrow> STR ''article_subject'' | VFactV v s \<Rightarrow> STR ''fact_number'')"

definition vstated :: "vout \<Rightarrow> String.literal" where
  "vstated res = (case res of VSilent \<Rightarrow> STR '''' | VTopicV n t \<Rightarrow> show_int (int n) | VAmendV n t \<Rightarrow> t
                 | VImposs n \<Rightarrow> STR '''' | VArtV n t \<Rightarrow> t | VFactV v s \<Rightarrow> show_int (int v))"

definition vreply :: "vreq \<Rightarrow> reply" where
  "vreply r = (case vkernel r of VSilent \<Rightarrow> Reply False (STR ''silent'') (STR '''') None
      | VImposs n \<Rightarrow> Reply False (STR ''impossible'') (vtext (VImposs n)) None
      | v \<Rightarrow> Reply True (vkind v) (vtext v) (Some (vstated v)))"

theorem vreply_answered_iff:
  "answered (vreply r) \<longleftrightarrow> (vkernel r \<noteq> VSilent \<and> (\<forall>n. vkernel r \<noteq> VImposs n))"
  by (auto simp: vreply_def split: vout.splits)

definition gov_self_test :: bool where
  "gov_self_test \<longleftrightarrow>
     length amendments = 27 \<and>
     vkernel (VAmend 28) = VImposs 28 \<and>
     response (vreply (VAmend 28)) = STR ''The US Constitution has 27 amendments; there is no 28th Amendment.'' \<and>
     response (vreply (VAmend 13)) = cat [STR ''The 13th Amendment covers '', amendments ! 12, STR ''.''] \<and>
     response (vreply (VArticle 3)) = cat [STR ''Article III covers '', articles ! 2, STR ''.''] \<and>
     response (vreply (VTopic (map (\<lambda>n. n = 13) topic_nums))) =
       cat [STR ''It is the 13th Amendment: '', amendments ! 12, STR ''.''] \<and>
     fst (fact_rows ! 3) = 270"

end
