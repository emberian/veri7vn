theory Veri7vn_Grammar
  imports Veri7vn_Interpretation
begin

text \<open>Typed parser combinators compose values without reparsing display strings.
Positions are in the immutable input carrier, so captures retain absolute spans.
The relation argument describes this declared fragment, not human intent.\<close>
type_synonym ('a,'v) parser = "'a list \<Rightarrow> nat \<Rightarrow> ('v \<times> nat) list"
definition parser_sound where
  "parser_sound p R \<longleftrightarrow> (\<forall>xs i v j. (v,j) \<in> set (p xs i) \<longrightarrow>
    i \<le> j \<and> j \<le> length xs \<and> R xs i v j)"
definition token :: "'a list \<Rightarrow> ('a,unit) parser" where
  "token word xs i = (if i + length word \<le> length xs \<and>
    slice xs (i,i + length word) = word then [((),i + length word)] else [])"
definition capture :: "nat \<Rightarrow> ('a list \<Rightarrow> 'v option) \<Rightarrow> ('a,span \<times> 'v) parser" where
  "capture n codec xs i = (if i+n \<le> length xs then
    (case codec (slice xs (i,i+n)) of None \<Rightarrow> [] |
     Some v \<Rightarrow> [(((i,i+n),v),i+n)]) else [])"
definition sequence :: "('a,'v) parser \<Rightarrow> ('a,'w) parser \<Rightarrow> ('a,'v \<times> 'w) parser" where
  "sequence p q xs i = concat (map (\<lambda>(v,j).
    map (\<lambda>(w,k). ((v,w),k)) (q xs j)) (p xs i))"
definition choice :: "('a,'v) parser \<Rightarrow> ('a,'v) parser \<Rightarrow> ('a,'v) parser" where
  "choice p q xs i = p xs i @ q xs i"
definition project :: "('v \<Rightarrow> 'w) \<Rightarrow> ('a,'v) parser \<Rightarrow> ('a,'w) parser" where
  "project f p xs i = map (\<lambda>(v,j). (f v,j)) (p xs i)"
lemma token_sound:
  "parser_sound (token word) (\<lambda>xs i v j.
    j = i + length word \<and> slice xs (i,j) = word)"
  by (auto simp: parser_sound_def token_def split: if_splits)
lemma capture_sound:
  assumes codec: "\<And>raw v. codec raw = Some v \<Longrightarrow> meaning raw v"
  shows "parser_sound (capture n codec) (\<lambda>xs i sv j.
    fst sv = (i,j) \<and> j=i+n \<and> meaning (slice xs (i,j)) (snd sv))"
proof (unfold parser_sound_def, intro allI impI)
  fix xs i sv j
  assume mem: "(sv,j) \<in> set (capture n codec xs i)"
  have bound: "i+n \<le> length xs"
    using mem by (cases "i+n \<le> length xs") (auto simp: capture_def)
  show "i \<le> j \<and> j \<le> length xs \<and>
    (fst sv = (i,j) \<and> j=i+n \<and> meaning (slice xs (i,j)) (snd sv))"
  proof (cases "codec (slice xs (i,i+n))")
    case None
    with mem bound show ?thesis by (simp add: capture_def)
  next
    case (Some v)
    have result: "sv = ((i,i+n),v)" "j=i+n"
      using mem bound Some by (auto simp: capture_def)
    have "meaning (slice xs (i,i+n)) v" by (rule codec[OF Some])
    with result bound show ?thesis by simp
  qed
qed
lemma sequence_sound:
  assumes "parser_sound p P" "parser_sound q Q"
  shows "parser_sound (sequence p q) (\<lambda>xs i vw k.
    \<exists>j. P xs i (fst vw) j \<and> Q xs j (snd vw) k)"
  using assms by (auto simp: parser_sound_def sequence_def; meson order_trans)
lemma choice_sound:
  assumes "parser_sound p P" "parser_sound q Q"
  shows "parser_sound (choice p q) (\<lambda>xs i v j. P xs i v j \<or> Q xs i v j)"
  using assms by (auto simp: parser_sound_def choice_def)
lemma project_sound:
  assumes "parser_sound p P"
  shows "parser_sound (project f p) (\<lambda>xs i w j. \<exists>v. P xs i v j \<and> w=f v)"
  using assms by (fastforce simp: parser_sound_def project_def)
lemma choice_retains_readings:
  "set (choice p q xs i) = set (p xs i) \<union> set (q xs i)"
  by (simp add: choice_def)

text \<open>Parameterized specialist-language instance: a literal-operation keyword,
opening quote, exact-length typed capture, closing quote. The codec supplies a
partial typed meaning, never a stringly-typed universal value. Literal length
may come from an admitted boundary recognizer; its completeness is a separate
obligation. This instance proves exact slices regardless of surrounding cues.\<close>
definition quoted_capture where
  "quoted_capture quote n codec =
    project (\<lambda>(_, (v,_)). v)
      (sequence (token [quote]) (sequence (capture n codec) (token [quote])))"
definition specialist_request where
  "specialist_request keyword quote n codec =
    project snd (sequence (token keyword) (quoted_capture quote n codec))"
lemma quoted_capture_sound:
  assumes codec: "\<And>raw v. codec raw = Some v \<Longrightarrow> meaning raw v"
  shows "parser_sound (quoted_capture quote n codec) (\<lambda>xs i sv k.
    fst sv = (i+1,i+1+n) \<and> k=i+n+2 \<and>
    meaning (slice xs (fst sv)) (snd sv))"
proof -
  have cap: "parser_sound (capture n codec) (\<lambda>xs i sv j.
    fst sv = (i,j) \<and> j=i+n \<and> meaning (slice xs (i,j)) (snd sv))"
    by (rule capture_sound[OF codec])
  note inner = sequence_sound[OF cap token_sound[of "[quote]"]]
  note outer = sequence_sound[OF token_sound[of "[quote]"] inner]
  note projected = project_sound[OF outer, of "\<lambda>(_, (v,_)). v"]
  show ?thesis using projected
    by (fastforce simp: parser_sound_def quoted_capture_def algebra_simps)
qed
lemma specialist_literal_sound:
  assumes codec: "\<And>raw v. codec raw = Some v \<Longrightarrow> meaning raw v"
  shows "parser_sound (specialist_request word quote n codec) (\<lambda>xs i sv k.
    fst sv = (i+length word+1,i+length word+1+n) \<and>
    k=i+length word+n+2 \<and> meaning (slice xs (fst sv)) (snd sv))"
proof -
  have quoted: "parser_sound (quoted_capture quote n codec) (\<lambda>xs i sv k.
    fst sv = (i+1,i+1+n) \<and> k=i+n+2 \<and>
    meaning (slice xs (fst sv)) (snd sv))"
    by (rule quoted_capture_sound[OF codec])
  note combined = sequence_sound[OF token_sound[of word] quoted]
  note projected = project_sound[OF combined, of snd]
  show ?thesis using projected
    by (fastforce simp: parser_sound_def specialist_request_def algebra_simps)
qed

end
