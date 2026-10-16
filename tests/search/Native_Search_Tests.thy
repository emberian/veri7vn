theory Native_Search_Tests
  imports "Veri7vn_Native_Search.Veri7vn_Native_Search"
begin
ML \<open>val search_receiver_context = @{context};\<close>
lemma search_worker_conjunction: "P \<Longrightarrow> Q \<Longrightarrow> P \<and> Q"
  by (rule conjI)
ML \<open>
local
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  (* Test issuer only. Production owner is lexical-private in host assembly. *)
  structure T=Veri7vn_Private_Operation_Tickets ();
  structure W=Veri7vn_Search_Fn (T);
  structure S=W.Search;
  val ctxt = @{context};
  val gen=R.generation ctxt {packages=[],runtime="native-search-test",policy="kernel",
    sources=[],interpretation="exact"};
  val receiver=R.generation search_receiver_context
    {packages=[],runtime="native-search-receiver",policy="kernel",sources=[],interpretation="exact"};
  val target=Thm.cterm_of search_receiver_context @{prop "P \<longrightarrow> (P \<and> P)"};
  val instance=S.qualify {expansions=100,frontier=100,successors=2,milliseconds=5000};
  fun prepare ()=S.prepare instance receiver gen target ["TrueI","search_worker_conjunction"]
    [S.Apply 0,S.Introduce,S.Retrieve,S.Split,S.Assume];
  val prepared=prepare ();
  fun payload request={instance=instance,request=request,operation=S.operation instance,
    executable=S.executable instance,generation=gen,receiver=receiver};
  val issuer=T.new_issuer ();
  val scope=T.begin_scope issuer {owner_version=1,epoch=1};
  val identity={execution=1,slot=2,operation={workspace="search-test",request=1,
    profile=1,code_generation=1,operation=1,step=1,cost=S.cost prepared,inputs=[1],
    owner_version=1,epoch=1,journal_sequence=1,semantic_generation=1,
    implementation_artifact=replicate_string 64 "a"}};
  val ticket=T.issue_pure scope identity (payload prepared);
  val job=W.start ticket;
  val output=W.join job;
  val report=W.report output;
  val _=T.close_scope scope;
  val bytes=(case #outcome report of S.ProofProposal wire=>wire
    | _=>error "multistep native producer found no proof");
  val _=if #expansions report>1 andalso
    exists (fn {route=S.Failed,...}=>true | _=>false) (#trace report)
    then () else error "multistep/scoped alternate failure missing";
  val result=Veri7vn_Proof_Transport.receive (A.policy (Proof_Context.theory_of search_receiver_context)) receiver
    {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=[]} bytes;
  val _=case result of A.Accepted admitted=>
    if Thm.prop_of (A.theorem admitted) aconv Thm.term_of target then
      writeln "SEARCH multistep_receiver_exact_target PASS"
    else error "search receiver changed target"
    | A.Rejected reasons=>error (space_implode "; " reasons);
  val _=if can W.start ticket then error "search replayed consumed ticket" else
    writeln "SEARCH consumed_ticket_replay_rejected PASS";
  val _=W.release_output output;
  val _=if S.is_live prepared then error "joined search retained native input" else ();
  val scope2=T.begin_scope issuer {owner_version=1,epoch=1};
  val prepared2=prepare ();
  val identity2={execution=2,slot=3,operation= #operation identity};
  val foreign_instance=S.qualify {expansions=100,frontier=100,successors=2,milliseconds=5000};
  val mismatched={instance=foreign_instance,request=prepared2,
    operation=S.operation foreign_instance,executable=S.executable foreign_instance,generation=gen,receiver=receiver};
  val badticket=T.issue_pure scope2 identity2 mismatched;
  val _=if can W.start badticket then error "equal-cost foreign search instance ran" else ();
  val _=S.release_instance foreign_instance;
  val job2=W.start (T.issue_pure scope2 identity2 (payload prepared2));
  val duplicate=T.issue_pure scope2 {execution=3,slot=4,operation= #operation identity}
    (payload prepared2);
  val _=if can W.start duplicate then error "prepared target concurrently shared" else
    writeln "SEARCH exact_instance_single_owner PASS";
  val _=W.request_cancel job2;
  val output2=W.join job2;
  val cancelled=W.report output2;
  val _=T.close_scope scope2;
  val _=case #outcome cancelled of S.Cancelled=>
    writeln "SEARCH cancelled_late_proposal_suppressed PASS"
    | _=>error "cancelled search exposed a late proof proposal";
  val _=W.release_output output2;
  val scope3=T.begin_scope issuer {owner_version=1,epoch=1};
  fun stopped_case limits target actions expected =
    let val bounded=S.qualify limits;
      val request=S.prepare bounded receiver gen target [] actions;
      val event={execution=4,slot=5,operation={workspace="search-test",request=2,
        profile=2,code_generation=1,operation=1,step=1,cost=S.cost request,inputs=[2],
        owner_version=1,epoch=1,journal_sequence=1,semantic_generation=1,
        implementation_artifact=replicate_string 64 "a"}};
      val job=W.start(T.issue_pure scope3 event
        {instance=bounded,request=request,operation=S.operation bounded,
         executable=S.executable bounded,generation=gen,receiver=receiver});
      val output=W.join job;
      val report=W.report output;
      val _=if expected (#outcome report) andalso not(null(#trace report)) then ()
        else error "search stop lost scope or inspectable attempted route";
      val _=W.release_output output;
    in S.release_instance bounded end;
  val _=stopped_case {expansions=1,frontier=100,successors=2,milliseconds=5000}
    target [S.Introduce,S.Split,S.Assume]
    (fn S.BudgetStop=>true | _=>false);
  val _=stopped_case {expansions=10,frontier=100,successors=2,milliseconds=5000}
    (Thm.cterm_of search_receiver_context @{prop "False"}) [S.Assume]
    (fn S.Exhausted=>true | _=>false);
  val _=T.close_scope scope3;
  val _=writeln "SEARCH budget_exhaustion_not_refutation PASS";
  val _=S.release_instance instance;
in end
\<close>

definition scheduler_fixture where
  "scheduler_fixture = (let initial =
      \<lparr>pending_steps=[(0::nat,SeekWitness 1),(1,Counterexample 2)],
        strategy_trace=[],charged_steps=0,
        retained_candidates=[]::(nat \<times> nat \<times> proposal_scope) list,
        retained_refutations=[],route_failures=[],goal_blockers=[]\<rparr>;
      run = (\<lambda>goal action. if goal=0 then Candidate 7 FeasibleWitness
        else ScopedBlocker 9);
      partial=schedule run False 1 initial;
      full=schedule run False 2 initial
    in snd partial=BudgetStopped \<and>
      retained_candidates (fst partial)=[(0,7,FeasibleWitness)] \<and>
      pending_steps (fst partial)=[(1,Counterexample 2)] \<and>
      retained_refutations (fst full)=[] \<and>
      goal_blockers (fst full)=[(1,9)] \<and>
      charged_steps (fst full)=2)"
ML \<open>
  if @{code scheduler_fixture} then writeln "SEARCH multipart_scope_budget PASS"
  else error "scheduler promoted partial witness or lost scoped blocker"
\<close>
end
