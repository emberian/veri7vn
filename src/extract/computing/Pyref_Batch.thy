theory Pyref_Batch
  imports Pyref
begin

text \<open>A batch retains each requested role and name in order. Success means
complete reference coverage for every job; partial results remain explicitly
withheld. Nothing here establishes completeness of the reference or executes APIs.\<close>

datatype pyjob = PyJob pyask pycand
fun candidate_name where "candidate_name (PyCand c dotted long) = c"
fun py_field where
  "py_field PQ_module e = pe_module e"
| "py_field PQ_signature e = pe_sig e"
| "py_field PQ_doc e = pe_doc e"
fun role_text where
  "role_text PQ_module = STR ''module''"
| "role_text PQ_signature = STR ''signature''"
| "role_text PQ_doc = STR ''description''"

definition py_job_covered where
  "py_job_covered j \<longleftrightarrow> (case j of PyJob q c \<Rightarrow>
    \<exists>nm e. py_resolve [c] = PyFound nm \<and> py_lookup nm = Some e \<and>
      (q \<noteq> PQ_signature \<or> pe_sig e \<noteq> STR ''''))"

definition py_job_reply where
  "py_job_reply j = (case j of PyJob q c \<Rightarrow>
    let r = py_reply q [c] in
      if answered r then r else if reply_kind r = STR ''not_taken'' then
        Reply False (STR ''unknown'') (STR ''My reference cannot resolve '' + candidate_name c + STR ''.'') None
      else r)"

lemma py_job_answered_base:
  "answered (py_job_reply (PyJob q c)) = answered (py_reply q [c])"
  by (simp add: py_job_reply_def Let_def)

lemma py_job_covered_iff:
  "answered (py_job_reply j) \<longleftrightarrow> py_job_covered j"
proof (cases j)
  case (PyJob q c)
  show ?thesis
  proof (cases "py_resolve [c]")
    case (PyFound nm)
    have "py_lookup nm \<noteq> None" by (rule py_found_lookup[OF PyFound])
    then obtain e where entry: "py_lookup nm = Some e" by auto
    obtain n p s m g d where shape: "e = (n,p,s,m,g,d)" by (cases e rule: prod_cases6) auto
    show ?thesis using PyJob PyFound entry shape
      by (cases q) (auto simp: py_job_answered_base py_job_covered_def py_reply_def)
  qed (auto simp: PyJob py_job_answered_base py_job_covered_def py_reply_def)
qed

lemma py_job_states_own_role:
  assumes "py_resolve [c] = PyFound nm" "py_lookup nm = Some e"
    "q \<noteq> PQ_signature \<or> pe_sig e \<noteq> STR ''''"
  shows "answered (py_job_reply (PyJob q c)) \<and>
    stated (py_job_reply (PyJob q c)) = Some (py_field q e)"
  using assms by (cases q) (simp_all add: py_job_reply_def py_reply_def Let_def)

fun py_job_text where
  "py_job_text (PyJob q c) = role_text q + STR '' '' + candidate_name c + STR '': '' + response (py_job_reply (PyJob q c))"

definition py_batch_reply where
  "py_batch_reply jobs = (if jobs = [] then Reply False (STR ''not_taken'') (STR '''') None
    else let complete = list_all (\<lambda>j. answered (py_job_reply j)) jobs in
      Reply complete (if complete then STR ''reference_batch'' else STR ''reference_incomplete'')
        ((if complete then STR '''' else STR ''I cannot answer every requested reference lookup. '') +
          join_lit (STR '' | '') (map py_job_text jobs)) None)"

theorem py_batch_complete_iff:
  "answered (py_batch_reply jobs) \<longleftrightarrow> jobs \<noteq> [] \<and> (\<forall>j \<in> set jobs. py_job_covered j)"
  by (simp add: py_batch_reply_def Let_def list_all_iff py_job_covered_iff)

theorem py_batch_job_sound:
  assumes "answered (py_batch_reply jobs)" "PyJob q c \<in> set jobs"
  shows "\<exists>nm e. e \<in> set py_entries \<and> pe_name e = nm \<and>
    py_resolve [c] = PyFound nm \<and> py_lookup nm = Some e \<and>
    stated (py_job_reply (PyJob q c)) = Some (py_field q e)"
proof -
  have "py_job_covered (PyJob q c)" using assms by (simp add: py_batch_complete_iff)
  then obtain nm e where facts: "py_resolve [c] = PyFound nm" "py_lookup nm = Some e"
    "q \<noteq> PQ_signature \<or> pe_sig e \<noteq> STR ''''"
    unfolding py_job_covered_def by auto
  have row: "e \<in> set py_entries \<and> pe_name e = nm" by (rule py_lookup_sound[OF facts(2)])
  have field_result: "stated (py_job_reply (PyJob q c)) = Some (py_field q e)"
    by (rule conjunct2[OF py_job_states_own_role[OF facts]])
  show ?thesis using row facts field_result by blast
qed

theorem py_batch_order_and_coverage:
  "length (map py_job_text jobs) = length jobs"
  "i < length jobs \<Longrightarrow> (map py_job_text jobs) ! i = py_job_text (jobs ! i)"
  by simp_all

definition py_batch_scope_reply :: reply where
  "py_batch_scope_reply = Reply False (STR ''reference_scope'')
    (STR ''I cannot parse every requested Python lookup. Use a name list for one role, or separate signature, module and description clauses.'') None"

definition py_batch_self_test where
  "py_batch_self_test \<longleftrightarrow>
    answered (py_batch_reply [PyJob PQ_signature (PyCand (STR ''len'') None True),
      PyJob PQ_module (PyCand (STR ''os.remove'') (Some (STR ''os'', STR ''remove'')) True)]) \<and>
    \<not> answered (py_batch_reply [PyJob PQ_doc (PyCand (STR ''os.remove'') (Some (STR ''os'', STR ''remove'')) True),
      PyJob PQ_doc (PyCand (STR ''os.mkdir'') (Some (STR ''os'', STR ''mkdir'')) True)]) \<and>
    \<not> answered (py_batch_reply [])"

end
