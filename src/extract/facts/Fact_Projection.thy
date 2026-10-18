theory Fact_Projection
  imports Facts_Rows
begin

text \<open>Typed projections from explicitly transcribed source assertions. The
source sentence contains both directions of exchange; its old scalar value only
contains sugars. These edges are a transcription of that sentence, not a proof
of biological truth or of English interpretation.\<close>

datatype partner = Plant | Fungus
datatype resource = Sugars | Water | Minerals

definition exchange_edges :: "(partner \<times> partner \<times> resource) list" where
  "exchange_edges = [(Plant,Fungus,Sugars), (Fungus,Plant,Water), (Fungus,Plant,Minerals)]"
definition transferred :: "partner \<Rightarrow> partner \<Rightarrow> resource list" where
  "transferred giver receiver = map (\<lambda>(a,b,r). r)
     (filter (\<lambda>(a,b,r). a=giver \<and> b=receiver) exchange_edges)"

theorem transferred_exact:
  "r \<in> set (transferred giver receiver) \<longleftrightarrow>
    (giver,receiver,r) \<in> set exchange_edges"
  by (cases giver; cases receiver; cases r) (simp_all add: transferred_def exchange_edges_def)

theorem exchange_reverse_disjoint:
  "giver \<noteq> receiver \<Longrightarrow>
    set (transferred giver receiver) \<inter> set (transferred receiver giver) = {}"
  by (cases giver; cases receiver) (simp_all add: transferred_def exchange_edges_def)

fun resource_text :: "resource \<Rightarrow> String.literal" where
  "resource_text Sugars = STR ''sugars''"
| "resource_text Water = STR ''water''"
| "resource_text Minerals = STR ''mineral nutrients (especially phosphorus and nitrogen)''"
fun join_resources :: "resource list \<Rightarrow> String.literal" where
  "join_resources [] = STR ''''"
| "join_resources [r] = resource_text r"
| "join_resources (r # s # rest) = resource_text r + STR '' and '' + join_resources (s # rest)"

text \<open>The request identifies the source field; it is supplied by an
untrusted whole-question parser. Projection only applies after the checked
Facts answer selected the corresponding source row. It preserves row identity.\<close>
datatype field_request = AnomieMeaning | ExchangeDirection partner partner

definition projected_value :: "field_request \<Rightarrow> outcome \<Rightarrow> String.literal option" where
  "projected_value req answer = (case answer of Silent _ \<Rightarrow> None
    | Answer k v s name i \<Rightarrow> (case req of
      AnomieMeaning \<Rightarrow> if name=STR ''facts_sociology_v1'' \<and> i=1
         then Some (STR ''normlessness'') else None
    | ExchangeDirection a b \<Rightarrow> if name=STR ''facts_mycelial_v1'' \<and> i=1 \<and> a\<noteq>b
         then Some (join_resources (transferred a b)) else None))"

theorem projection_requires_source:
  "projected_value req answer = Some value \<Longrightarrow>
    (\<exists>k v s name i. answer=Answer k v s name i \<and> i=1 \<and>
      (name=STR ''facts_sociology_v1'' \<or> name=STR ''facts_mycelial_v1''))"
  by (auto simp: projected_value_def split: outcome.splits field_request.splits if_splits)

end
