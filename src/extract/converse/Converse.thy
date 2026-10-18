theory Converse
  imports "HOL-Library.Code_Target_Numeral"
begin

text \<open>A finite policy over supplied final receipts. Entity identity and type,
English recognition, numeric/unit interpretation, and external effects are
outside this model. Query and answer entities are distinct slots. No theorem
here asserts that a label identifies a real person or that a rewrite preserves
English meaning.\<close>

datatype entity_kind = Person | Thing | Unknown
datatype entity = Entity String.literal entity_kind
datatype reference = Person_ref | Thing_ref | Answer_thing_ref | Subject_ref | Number_ref | Variable_ref
datatype resolution = Query_slot | Answer_slot | Number_slot | Variable_slot | Missing | Ambiguous

fun of_kind :: "entity_kind \<Rightarrow> entity option \<Rightarrow> bool" where
  "of_kind k None = False"
| "of_kind k (Some (Entity entity_id t)) = (k = t)"
fun possible_person :: "entity option \<Rightarrow> bool" where
  "possible_person None = False"
| "possible_person (Some (Entity entity_id t)) = (t \<noteq> Thing)"
fun possible_thing :: "entity option \<Rightarrow> bool" where
  "possible_thing None = False"
| "possible_thing (Some (Entity entity_id t)) = (t \<noteq> Person)"

fun same_entity :: "entity option \<Rightarrow> entity option \<Rightarrow> bool" where
  "same_entity (Some (Entity a k)) (Some (Entity b l)) = (a = b)"
| "same_entity _ _ = False"

fun resolve :: "reference \<Rightarrow> entity option \<Rightarrow> entity option \<Rightarrow> bool \<Rightarrow> bool \<Rightarrow> resolution" where
  "resolve Person_ref q a n v =
    (if of_kind Person q then
       if possible_person a \<and> \<not> same_entity q a then Ambiguous else Query_slot
     else if of_kind Person a then
       if possible_person q \<and> \<not> same_entity q a then Ambiguous else Answer_slot
     else Missing)"
| "resolve Thing_ref q a n v =
    (if of_kind Thing q then Query_slot else if of_kind Thing a then
       if possible_thing q \<and> \<not> same_entity q a then Ambiguous else Answer_slot
     else Missing)"
| "resolve Answer_thing_ref q a n v = (if of_kind Thing a then Answer_slot else Missing)"
| "resolve Subject_ref q a n v = (if q = None then Missing else Query_slot)"
| "resolve Number_ref q a n v = (if n then Number_slot else Missing)"
| "resolve Variable_ref q a n v = (if v then Variable_slot else Missing)"

lemma person_requires_human:
  "resolve Person_ref q a n v = Query_slot \<Longrightarrow> of_kind Person q"
  "resolve Person_ref q a n v = Answer_slot \<Longrightarrow> of_kind Person a"
  by (auto split: if_splits)
lemma known_person_possible:
  assumes "of_kind Person e"
  shows "possible_person e"
proof (cases e)
  case None
  with assms show ?thesis by simp
next
  case (Some en)
  with assms show ?thesis by (cases en) auto
qed
lemma distinct_people_ambiguous:
  "of_kind Person q \<Longrightarrow> of_kind Person a \<Longrightarrow> \<not> same_entity q a \<Longrightarrow>
   resolve Person_ref q a n v = Ambiguous"
  by (simp add: known_person_possible)
lemma unknown_cannot_be_person:
  "resolve Person_ref (Some (Entity entity_id Unknown)) None n v = Missing"
  by simp
lemma unknown_answer_competes_with_person:
  "x \<noteq> y \<Longrightarrow> resolve Person_ref (Some (Entity x Person)) (Some (Entity y Unknown)) n v = Ambiguous"
  by simp
lemma unknown_query_competes_with_person:
  "x \<noteq> y \<Longrightarrow> resolve Person_ref (Some (Entity x Unknown)) (Some (Entity y Person)) n v = Ambiguous"
  by simp
lemma query_thing_preferred:
  "of_kind Thing q \<Longrightarrow> resolve Thing_ref q a n v = Query_slot"
  by simp
lemma unknown_query_competes_with_thing:
  "x \<noteq> y \<Longrightarrow> resolve Thing_ref (Some (Entity x Unknown)) (Some (Entity y Thing)) n v = Ambiguous"
  by simp
lemma answer_thing_requires_answer:
  "resolve Answer_thing_ref q a n v = Answer_slot \<Longrightarrow> of_kind Thing a"
  by (auto split: if_splits)
lemma absent_numeric_refused:
  "resolve Number_ref q a False v = Missing"
  "resolve Variable_ref q a n False = Missing"
  by simp_all

text \<open>Interpretation happens before evaluation. Completeness is a supplied
English-recognition premise. Only resolved slots permit a contextual question;
missing or ambiguous references produce clarification without evaluating a
different literal question. A false completeness premise preserves raw input.\<close>
datatype query_mode = Raw_question | Context_question | Clarify_reference
fun choose_query :: "bool \<Rightarrow> resolution \<Rightarrow> query_mode" where
  "choose_query False r = Raw_question"
| "choose_query True Missing = Clarify_reference"
| "choose_query True Ambiguous = Clarify_reference"
| "choose_query True _ = Context_question"
lemma incomplete_keeps_raw:
  "choose_query False r = Raw_question"
  by simp
lemma context_requires_resolved_slot:
  "choose_query complete r = Context_question \<Longrightarrow>
   complete \<and> r \<in> {Query_slot, Answer_slot, Number_slot, Variable_slot}"
  by (cases complete; cases r) auto
lemma unresolved_never_evaluates_context:
  "choose_query True Missing = Clarify_reference \<and>
   choose_query True Ambiguous = Clarify_reference"
  by simp

text \<open>Unrecognized means the route cascade took no turn. Answered, captured
refusal, ambiguity, and error are terminal. At most one proposed rewrite is
available: there is no recursive transition in this policy.\<close>
datatype outcome = Unrecognized | Answered | Refused | Failed
datatype selection = Original | Rewritten

definition may_rewrite :: "outcome \<Rightarrow> bool" where
  "may_rewrite r = (r = Unrecognized)"
definition select :: "outcome \<Rightarrow> outcome option \<Rightarrow> selection" where
  "select raw candidate = (if raw = Unrecognized \<and> candidate \<noteq> None \<and>
     candidate \<noteq> Some Unrecognized then Rewritten else Original)"
lemma terminal_preserved:
  "raw \<noteq> Unrecognized \<Longrightarrow> select raw candidate = Original"
  by (simp add: select_def)
lemma rewritten_has_candidate:
  "select raw candidate = Rewritten \<Longrightarrow> raw = Unrecognized \<and>
    (\<exists>r. candidate = Some r \<and> r \<noteq> Unrecognized)"
  by (auto simp: select_def split: option.splits if_splits)
lemma failed_candidate_is_terminal:
  "select Unrecognized (Some Failed) = Rewritten"
  by (simp add: select_def)

datatype 'a evaluated = Evaluated outcome 'a
fun chosen :: "selection \<Rightarrow> 'a \<Rightarrow> 'a \<Rightarrow> 'a" where
  "chosen Original raw rewritten = raw"
| "chosen Rewritten raw rewritten = rewritten"
lemma chosen_preserves_payload:
  "select raw_class candidate = Original \<Longrightarrow>
   chosen (select raw_class candidate) raw rewritten = raw"
  by simp

text \<open>The ledger contains final accepted events, including refusals, for
literal recall. Ground is retained across recall only; a substantive unanswered
turn clears it. Evaluation has no ledger argument or update operation. The
consumer's external warehouse protocol is checked separately by integration
probes; these list laws do not prove filesystem purity.\<close>
datatype 'a event = Event outcome 'a

definition append_final :: "String.literal \<Rightarrow> 'a event \<Rightarrow>
  (String.literal \<Rightarrow> 'a event list) \<Rightarrow> (String.literal \<Rightarrow> 'a event list)" where
  "append_final s e logs = logs(s := logs s @ [e])"
lemma one_final_append:
  "append_final s e logs s = logs s @ [e]"
  by (simp add: append_final_def)
lemma other_session_unchanged:
  "s \<noteq> t \<Longrightarrow> append_final s e logs t = logs t"
  by (simp add: append_final_def)
lemma final_length:
  "length (append_final s e logs s) = Suc (length (logs s))"
  by (simp add: append_final_def)
lemma recall_is_recorded:
  "last (append_final s e logs s) = e"
  by (simp add: append_final_def)

definition retain_ground :: "bool \<Rightarrow> outcome \<Rightarrow> bool" where
  "retain_ground recall result = (recall \<or> result = Answered)"
lemma substantive_refusal_clears_ground:
  "\<not> retain_ground False Refused \<and> \<not> retain_ground False Failed \<and>
   \<not> retain_ground False Unrecognized"
  by (simp add: retain_ground_def)

end
