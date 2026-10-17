theory Converse_Export
  imports Converse
begin

text \<open>Mock chain entry points for the executable self test. They stand for
  the real AM/AN entries: the probe writes no log (AM enters below AN), the
  dispatch appends exactly one transition (AN records one per call). \<open>mock_served\<close>
  answers exactly one form, so the self test can exercise both the served and
  the unserved-predicate branches of the fallback.\<close>

definition mock_log :: "dstate \<Rightarrow> status \<Rightarrow> dstate" where
  "mock_log \<sigma> s = DState (slot_topic \<sigma>) (log \<sigma> @ [Turn s None])"

definition mock_answers :: "dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate" where
  "mock_answers \<sigma> t = (Reply Answered (STR ''mock:route'') (STR ''the chain answered''), mock_log \<sigma> Answered)"

definition mock_declines :: "dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate" where
  "mock_declines \<sigma> t = (Reply Withheld (STR ''mock:route'') (STR ''''), mock_log \<sigma> Withheld)"

definition mock_served :: "dstate \<Rightarrow> String.literal \<Rightarrow> reply \<times> dstate" where
  "mock_served \<sigma> t =
     (if t = STR ''How old is the Pacific Ocean?'' then mock_answers \<sigma> t else mock_declines \<sigma> t)"

text \<open>A grounded session: one answered turn that opened the Pacific Ocean
  (an opener form, as AO's \<open>_live_topic\<close> requires), and the empty session.\<close>

definition st_empty :: dstate where
  "st_empty = DState None []"

definition st_grounded :: dstate where
  "st_grounded = DState None [Turn Answered (Some (STR ''the Pacific Ocean''))]"

definition st_slot :: dstate where
  "st_slot = DState (Some (STR ''Moon'')) [Turn Answered (Some (STR ''the Pacific Ocean''))]"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     summarize (STR ''Moon'') = STR ''Summarize Moon.''
   \<and> live_topic st_empty = None
   \<and> live_topic st_grounded = Some (STR ''the Pacific Ocean'')
   \<and> live_topic st_slot = Some (STR ''Moon'')
   \<and> resolved st_grounded (STR ''the big one'') False = Some (STR ''the Pacific Ocean'')
   \<and> resolved st_empty (STR ''the big one'') False = None
   \<and> rewrite st_grounded (Repair (STR ''the Pacific Ocean'') False)
       = Some (STR ''Summarize the Pacific Ocean.'', Repair_accept)
   \<and> rewrite st_empty (Repair (STR ''volcanoes'') False) = Some (STR ''Summarize volcanoes.'', Repair_accept)
   \<and> rewrite st_empty (Repair (STR ''that place'') True) = None
   \<and> rewrite st_grounded (Opener (STR ''that place'') True)
       = Some (STR ''Summarize the Pacific Ocean.'', Opener_alias)
   \<and> rewrite st_empty (Ellipsis (STR ''the thing with the water'') False)
       = Some (STR ''Summarize the thing with the water.'', Ellipsis_completion)
   \<and> rewrite st_empty (Bare (STR ''volcanoes'')) = Some (STR ''Summarize volcanoes.'', Ellipsis_completion)
   \<and> rewrite st_grounded Continuation = None
   \<and> rewrite st_grounded Plain = None
   \<and> rewrite st_slot (Pred (STR ''how old is it'')) = Some (STR ''How old is Moon?'', Referent_substitution)
   \<and> rewrite st_empty (Pred (STR ''how old is it'')) = None
   \<and> rewrite st_slot (Pred (STR ''not a key'')) = None
   \<and> rewrite st_grounded (Free_deictic (STR ''Where is '') (STR ''?''))
       = Some (STR ''Where is the Pacific Ocean?'', Referent_substitution)
   \<and> form mock_answers st_grounded (Free_deictic (STR ''Where is '') (STR ''?'')) (STR ''Where is it?'')
       = STR ''Where is it?''
   \<and> form mock_declines st_empty Plain (STR ''Who directed Yojimbo?'') = STR ''Who directed Yojimbo?''
   \<and> form mock_declines st_grounded (Repair (STR ''the Pacific Ocean'') False) (STR ''I meant the Pacific Ocean'')
       = STR ''Summarize the Pacific Ocean.''
   \<and> form mock_served st_grounded (Pred (STR ''how old is it'')) (STR ''How old is it?'')
       = STR ''How old is the Pacific Ocean?''
   \<and> form mock_declines st_grounded (Pred (STR ''how old is it'')) (STR ''How old is it?'')
       = STR ''Summarize the Pacific Ocean.''
   \<and> note_of mock_declines st_grounded (Repair (STR ''the Pacific Ocean'') False) (STR ''I meant the Pacific Ocean'')
       = Some (Repair_accept, STR ''I meant the Pacific Ocean'', STR ''Summarize the Pacific Ocean.'', False)
   \<and> note_of mock_declines st_grounded (Pred (STR ''how old is it'')) (STR ''How old is it?'')
       = Some (Referent_substitution, STR ''How old is it?'', STR ''Summarize the Pacific Ocean.'', True)
   \<and> note_of mock_answers st_grounded (Repair (STR ''the Pacific Ocean'') False) (STR ''I meant the Pacific Ocean'')
       = None
   \<and> (case conv_step mock_served mock_answers st_grounded (Pred (STR ''how old is it'')) (STR ''How old is it?'') of
        (rep, \<sigma>') \<Rightarrow> r_status rep = Answered \<and> r_text rep = STR ''the chain answered''
           \<and> length (log \<sigma>') = Suc (length (log st_grounded)))
   \<and> (case conv_step mock_declines mock_declines st_grounded (Repair (STR ''the Pacific Ocean'') False)
                (STR ''I meant the Pacific Ocean'') of
        (_, \<sigma>') \<Rightarrow> length (log \<sigma>') = Suc (length (log st_grounded)))"

export_code rewrite form note_of conv_step live_topic resolved summarize lookup_pred
  predicate_of referential_nps mock_answers mock_declines self_test
  Reply Answered Withheld Clarify
  Referent_substitution Ellipsis_completion Opener_alias Repair_accept
  Plain Repair Opener Ellipsis Bare Pred Free_deictic Continuation Turn DState
  in SML module_name Converse file_prefix converse

ML \<open>
  val theorems = [@{thm conv_step_is_one_dispatch}, @{thm warrant_stays_with_route},
    @{thm form_cases}, @{thm gate_no_new_answer}, @{thm probe_state_discarded},
    @{thm probe_leaves_log_unchanged}, @{thm note_iff_conversion},
    @{thm no_silent_substitution}, @{thm predicate_of_shape},
    @{thm conv_step_deterministic}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("converse theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "converse self test failed";
  val _ = writeln ("VERI7VN_CONVERSE PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
