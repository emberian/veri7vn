theory Policy_Runtime_Checks
  imports "Veri7vn_Policy_Service.Policy_Service"
begin
ML \<open>
local
  structure M=Veri7vn_Policy_Execution;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  val pin=M.executable();
  val generation=R.generation @{context}{packages=["versioned-policies"],runtime="policy-runtime-check",
    policy="native-test",sources=[],interpretation="source-owned-conditional-policy"};
  fun ready(M.Ready x)=x
    | ready(M.Refused(M.Runtime_Error message))=error message
    | ready(M.Refused(M.Invalid_Contract messages))=error(cat_lines messages)
    | ready(M.Refused _)=error "Policy runtime refused";
  val instance=ready(M.attach{policy=A.policy @{theory},generation=generation,
    code_context=Veri7vn_Executable_Identity.code_theory pin,limits={nodes=10000,depth=200,seconds=3}});
  val _=if null(A.observed_oracles(M.contract instance))then ()else error "Policy admitted oracle";
  fun check input expected=
    let val request=ready(M.prepare pin instance input);
      val other=ready(M.prepare pin instance input);
      val output=ready(M.execute pin instance request);
      val projected=Thm.term_of(ready(M.project pin output));
      val _=if M.belongs_to request output andalso not(M.belongs_to other output)
        andalso ready(M.modeled_cost request)>0 then ()else error "Policy invocation association lost";
      val _=if Thm.term_of(ready(M.input output)) aconv Thm.term_of input then ()
        else error "Policy original input lost";
      val eq= @{term "(=)::policy_reply\<Rightarrow>policy_reply\<Rightarrow>bool"}$projected$expected;
      val value=Code_Evaluation.dynamic_value_strict @{context} eq;
      val _=if value aconv @{term True}then ()else error "Policy projected result mismatch";
      val _=M.release_request request;
      val _=case M.project pin output of M.Refused M.Released=>()
        | _=>error "Released policy projection survived";
      val _=M.release_request other;
    in ()end;
  val _=check @{cterm "registered_policy_dispatch (PolicyCall (epa_2024_recipe PM25 [11])
    (Some ''EPA-AQS-2024-PM-revision'') (AQIInput Hours24 (PolicyFraction 90999 10000)) [12])"}
    @{term "PolicyReport (epa_2024_recipe PM25 [11]) (AQIValue 50 90) PolicyComputed [] [11,12]"};
  val _=check @{cterm "registered_policy_dispatch (PolicyCall (ibc_2021_recipe Business [])
    (Some ''IBC-2021-Table-1004.5'') (OccupancyInput GrossArea (PolicyFraction 150000000001 1000000000)) [])"}
    @{term "PolicyReport (ibc_2021_recipe Business []) (Occupants 2) PolicyComputed [] []"};
  val _=check @{cterm "registered_policy_dispatch (PolicyCall (fda_2022_recipe [])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'') (CoolingInput None (Some (PolicyFraction 5 1))) [])"}
    @{term "PolicyReport (fda_2022_recipe []) CoolingAssessment PolicyConditionsMissing
      [(InitialStage,ConditionMissing),(TotalCooling,ConditionMet),(Chronology,ConditionMissing)] []"};
  val _=check @{cterm "registered_policy_dispatch (PolicyCall (fda_2022_recipe [])
    (Some ''FDA-Food-Code-2022-3-501.14(A)'')
    (CoolingInput (Some (PolicyFraction 3 1)) (Some (PolicyFraction 5 1))) [])"}
    @{term "PolicyReport (fda_2022_recipe []) CoolingAssessment PolicyConditionsFailed
      [(InitialStage,ConditionFailed),(TotalCooling,ConditionMet),(Chronology,ConditionMet)] []"};
  val _=check @{cterm "registered_policy_dispatch (PolicyCall (fda_2022_recipe []) None (CoolingInput None None) [])"}
    @{term "PolicyRefused MissingRuleVersion"};
  structure Private=Veri7vn_Private_Operation_Tickets();
  structure View:VERI7VN_OPERATION_TICKET_VIEW=Private;
  structure Worker=Veri7vn_Domain_Ticket_Execution_Fn
    (structure Domain=M structure Tickets=View);
  val issuer=Private.new_issuer();
  fun issue execution request extra=
    let val scope=Private.begin_scope issuer{owner_version=0,epoch=0};
      val operation:Private.operation_identity={workspace="policy-fixture",request=2,profile=3,
        code_generation=4,operation=5,step=0,cost=ready(M.modeled_cost request)+extra,inputs=[6],
        owner_version=0,epoch=0,journal_sequence=1,semantic_generation=7,
        implementation_artifact="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"};
      val ticket=Private.issue_pure scope{execution=execution,slot=8,operation=operation}
        {executable=pin,instance=instance,request=request,operation=M.operation instance};
      val answer=Worker.start ticket;
      val _=Private.close_scope scope;
    in answer end;
  val transferred=ready(M.prepare pin instance @{cterm "registered_policy_dispatch
    (PolicyCall (fda_2022_recipe []) None (CoolingInput None None) [])"});
  val job=(case issue 1 transferred 0 of Worker.Ready job=>job
    | _=>error "Charged policy worker refused");
  val _=case issue 2 transferred 0 of Worker.Refused Worker.Request_Already_Owned=>()
    | _=>error "Policy request executed through two worker transfers";
  val completed=(case Worker.collect job of Worker.Ready output=>output
    | _=>error "Charged policy worker failed");
  val actual=(case Worker.native_output completed of Worker.Ready output=>output
    | _=>error "Policy worker result unavailable");
  val _=if M.belongs_to transferred actual then ()else error "Policy worker detached native invocation";
  val _=Worker.cancel job;
  val wrong=ready(M.prepare pin instance @{cterm "registered_policy_dispatch
    (PolicyCall (fda_2022_recipe []) None (CoolingInput None None) [])"});
  val _=case issue 3 wrong 1 of Worker.Refused Worker.Wrong_Cost=>()
    | _=>error "Policy worker accepted invented execution charge";
  val _=case M.modeled_cost wrong of M.Refused M.Released=>()
    | _=>error "Refused transferred policy request leaked";
  val _=M.release_instance instance;
  val _=writeln "POLICY_RUNTIME_CHECKS_PASS";
in end
\<close>
end
