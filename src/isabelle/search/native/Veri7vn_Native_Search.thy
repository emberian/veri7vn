theory Veri7vn_Native_Search
  imports "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets"
    "Veri7vn_Strategies.Veri7vn_Strategies"
begin
definition search_work_cost :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "search_work_cost expansions frontier actions successors facts =
    1 + expansions * (1 + actions * successors * (1 + facts)) + frontier"
lemma search_work_cost_positive:
  "0 < search_work_cost expansions frontier actions successors facts"
  by (simp add: search_work_cost_def)
ML_file "native_search.ML"
end
