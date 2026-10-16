theory Veri7vn_Source_Authoring
  imports "Veri7vn_Execution.Veri7vn_Execution_Bundle"
begin
text \<open>Bounded term authoring surface. This is separate from the production
bulk source path, whose input is an opaque admitted native acquisition and whose
rows remain reflected carriers. This surface is not a row transport protocol.\<close>
definition source_trace_term :: "source_trace \<Rightarrow> Code_Evaluation.term" where
  "source_trace_term = Code_Evaluation.term_of"
ML_file "../bundle/source_bundle.ML"
end
