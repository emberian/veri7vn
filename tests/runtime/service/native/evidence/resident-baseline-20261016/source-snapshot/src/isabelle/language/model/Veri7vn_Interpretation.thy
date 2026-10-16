theory Veri7vn_Interpretation
  imports Main
begin

text \<open>Positions below count elements of the retained carrier: instantiate with bytes
for byte codecs, or codepoints after a separately declared decoding boundary.\<close>
type_synonym span = "nat \<times> nat"
definition slice :: "'a list \<Rightarrow> span \<Rightarrow> 'a list" where
  "slice xs s = take (snd s - fst s) (drop (fst s) xs)"
definition valid_span :: "'a list \<Rightarrow> span \<Rightarrow> bool" where
  "valid_span xs s \<longleftrightarrow> fst s \<le> snd s \<and> snd s \<le> length xs"

datatype 'a segment = Language span "'a list" | Literal span
fun segment_span where
  "segment_span (Language s ys) = s" |
  "segment_span (Literal s) = s"
fun segment_view where
  "segment_view xs (Language s ys) = ys" |
  "segment_view xs (Literal s) = slice xs s"
definition normalized_view where
  "normalized_view xs parts = concat (map (segment_view xs) parts)"
fun contiguous :: "nat \<Rightarrow> 'a segment list \<Rightarrow> nat \<Rightarrow> bool" where
  "contiguous p [] n = (p = n)" |
  "contiguous p (s # ss) n =
    (fst (segment_span s) = p \<and> p \<le> snd (segment_span s) \<and>
     contiguous (snd (segment_span s)) ss n)"
definition well_mapped where
  "well_mapped xs parts \<longleftrightarrow> contiguous 0 parts (length xs) \<and>
    (\<forall>s\<in>set parts. valid_span xs (segment_span s))"
text \<open>A map retains zero-output deletions and expanded language segments. Literal
operations consume original slices, never their surrounding normalized view.\<close>
definition literal_argument where
  "literal_argument xs s = slice xs s"
lemma literal_never_normalized:
  "segment_view xs (Literal s) = literal_argument xs s"
  by (simp add: literal_argument_def)
lemma valid_slice_length:
  "valid_span xs (a,b) \<Longrightarrow> length (slice xs (a,b)) = b-a"
  by (auto simp: valid_span_def slice_def)

text \<open>Grammar entries are typed native goals paired with exact retained input.
This finite declarative recognizer is executable. A model proposal has no entry
unless admitted to this declared table. Different goals may share an input.\<close>
record ('a,'g) grammar_rule =
  rule_id :: nat
  surface :: "'a list"
  native_goal :: 'g
  open_conditions :: "nat list"
record ('a,'g) derivation =
  used_rule :: nat
  originating_span :: span
  derived_goal :: 'g
  remaining_conditions :: "nat list"
definition elaborate where
  "elaborate rules xs s = map (\<lambda>r.
      \<lparr>used_rule = rule_id r, originating_span = s,
       derived_goal = native_goal r, remaining_conditions = open_conditions r\<rparr>)
    (filter (\<lambda>r. surface r = slice xs s) rules)"
definition declared_derivation where
  "declared_derivation rules xs d \<longleftrightarrow>
    valid_span xs (originating_span d) \<and>
    (\<exists>r\<in>set rules. rule_id r = used_rule d \<and>
      surface r = slice xs (originating_span d) \<and>
      native_goal r = derived_goal d \<and>
      open_conditions r = remaining_conditions d)"
lemma elaborate_sound:
  "valid_span xs s \<Longrightarrow> d \<in> set (elaborate rules xs s) \<Longrightarrow>
    declared_derivation rules xs d"
  by (auto simp: elaborate_def declared_derivation_def)
lemma elaborate_complete:
  assumes "r \<in> set rules" "surface r = slice xs s"
  shows "\<lparr>used_rule = rule_id r, originating_span = s,
       derived_goal = native_goal r, remaining_conditions = open_conditions r\<rparr>
       \<in> set (elaborate rules xs s)"
  using assms by (auto simp: elaborate_def)

datatype 'd recognition = Unrecognized | Resolved 'd | Ambiguous "'d list"
fun recognize where
  "recognize [] = Unrecognized" |
  "recognize [d] = Resolved d" |
  "recognize (d # e # ds) = Ambiguous (d # e # ds)"
lemma ambiguity_retains_all:
  "recognize ds = Ambiguous alternatives \<Longrightarrow> alternatives = ds \<and> length ds \<ge> 2"
  by (cases ds rule: recognize.cases) auto

text \<open>The explicit selection receipt is data for policy review, not evidence of
unexpressed human intent. No interpretation semantics quantifies over that intent.\<close>
record 'd selection =
  alternatives :: "'d list"
  chosen :: 'd
  decision_id :: nat
definition selection_valid where
  "selection_valid receipt \<longleftrightarrow> chosen receipt \<in> set (alternatives receipt)"

end
