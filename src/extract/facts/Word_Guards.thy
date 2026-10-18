theory Word_Guards
  imports Facts_Rows "HOL-Library.Code_Target_Numeral"
begin

text \<open>A checked, executable meaning for literal word guards. This handles guards
of the form backslash-b, ASCII letters/spaces, backslash-b, including every linguistics
row. Other patterns and the narrative classification remain untrusted. Bytes above
ASCII count as word characters: an ASCII language name embedded in a Unicode word
cannot become a false boundary. Case folding here is explicitly ASCII.\<close>

definition word_char :: "char \<Rightarrow> bool" where
  "word_char c \<longleftrightarrow> (let n = (of_char c :: nat) in
     48 \<le> n \<and> n \<le> 57 \<or> 65 \<le> n \<and> n \<le> 90 \<or>
     97 \<le> n \<and> n \<le> 122 \<or> n = 95 \<or> 128 \<le> n)"

definition ascii_lower :: "char \<Rightarrow> char" where
  "ascii_lower c = (let n = (of_char c :: nat) in
     if 65 \<le> n \<and> n \<le> 90 then char_of (n + 32) else c)"

definition word_guard :: "String.literal \<Rightarrow> string option" where
  "word_guard p = (let cs = String.explode p; w = take (length cs - 4) (drop 2 cs) in
     if 4 < length cs \<and> take 2 cs = [CHR 0x5c, CHR 0x62] \<and>
        drop (length cs - 2) cs = [CHR 0x5c, CHR 0x62] \<and>
        list_all (\<lambda>c. c = CHR 0x20 \<or> (97 \<le> (of_char c :: nat) \<and> (of_char c :: nat) \<le> 122)) w \<and>
        hd w \<noteq> CHR 0x20 \<and> last w \<noteq> CHR 0x20
     then Some w else None)"

definition word_at :: "string \<Rightarrow> string \<Rightarrow> nat \<Rightarrow> bool" where
  "word_at q w i \<longleftrightarrow> w \<noteq> [] \<and> i + length w \<le> length q \<and>
     take (length w) (drop i q) = w \<and>
     (i = 0 \<or> \<not> word_char (q ! (i - 1))) \<and>
     (i + length w = length q \<or> \<not> word_char (q ! (i + length w)))"

text \<open>Questions are byte strings, not Isabelle's ASCII-only literals. JSON/UTF-8
framing remains untrusted; this decoder converts each supplied byte to its HOL
character without asking the code generator to treat Unicode as an ASCII literal.\<close>
definition question_bytes :: "integer list \<Rightarrow> string" where
  "question_bytes bs = map (\<lambda>b. char_of (nat_of_integer b)) bs"

definition word_holds :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "word_holds q w \<longleftrightarrow>
     list_ex (word_at (map ascii_lower q) w) [0..<length q]"

theorem word_holds_occurrence:
  "word_holds q w \<longleftrightarrow> (\<exists>i<length q.
     word_at (map ascii_lower q) w i)"
  by (auto simp: word_holds_def list_ex_iff)

definition checked_features :: "string \<Rightarrow> features \<Rightarrow> features" where
  "checked_features q m p = (case word_guard p of Some w \<Rightarrow> word_holds q w \<and> m p | None \<Rightarrow> m p)"

text \<open>The independent occurrence check may remove a recognizer match; it cannot
undo a subject, attribute or scope restriction made by that recognizer.\<close>
theorem checked_feature_narrows:
  "checked_features q m p \<Longrightarrow> m p"
  by (auto simp: checked_features_def split: option.splits)

definition text_organ_reply :: "bool \<Rightarrow> string \<Rightarrow> features \<Rightarrow> organ \<Rightarrow> outcome" where
  "text_organ_reply narr q m og = organ_reply narr (checked_features q m) og"

definition text_family_reply :: "bool \<Rightarrow> string \<Rightarrow> features \<Rightarrow> organ list \<Rightarrow> (String.literal \<times> outcome) option" where
  "text_family_reply narr q m ogs = family_reply narr (checked_features q m) ogs"

theorem text_answer_word_occurs:
  assumes "text_organ_reply narr q m og = Answer k v s n i"
      "word_guard (guard (store_rules (organ_store og) ! i)) = Some w"
  shows "\<exists>j<length q. word_at (map ascii_lower q) w j"
  using assms by (auto simp: text_organ_reply_def guard_exact checked_features_def word_holds_occurrence)

theorem text_answer_first_row:
  "text_organ_reply narr q m og = Answer k v s n i \<Longrightarrow>
     i < length (store_rules (organ_store og)) \<and>
     v = fact_value (store_rules (organ_store og) ! i) \<and>
     s = sentence (store_rules (organ_store og) ! i) \<and>
     (\<forall>j<i. \<not> checked_features q m (guard (store_rules (organ_store og) ! j)))"
  by (simp add: text_organ_reply_def guard_exact)

definition answer_word_guard :: "organ \<Rightarrow> nat \<Rightarrow> String.literal option" where
  "answer_word_guard og i = map_option String.implode (word_guard (guard (store_rules (organ_store og) ! i)))"

theorem linguistics_guards_checked:
  "list_all (\<lambda>r. word_guard (guard r) \<noteq> None) (store_rules (organ_store organ_linguistics))"
  by code_simp

end
