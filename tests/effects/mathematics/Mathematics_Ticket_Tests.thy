theory Mathematics_Ticket_Tests
  imports Veri7vn_Mathematics_Ticket_Execution.Mathematics_Ticket_Execution
begin
ML \<open>
local
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure Private=Veri7vn_Private_Operation_Tickets ();
  structure View:VERI7VN_OPERATION_TICKET_VIEW=Private;
  structure Worker=Veri7vn_Math_Ticket_Execution_Fn
    (structure Mathematics=M structure Tickets=View);
  fun math_failure M.Wrong_Executable="Wrong_Executable"
    | math_failure M.Wrong_Generation="Wrong_Generation"
    | math_failure (M.Invalid_Contract reasons)="Invalid_Contract: " ^ commas reasons
    | math_failure M.Request_Bound="Request_Bound"
    | math_failure M.Unsupported_Input="Unsupported_Input"
    | math_failure M.Execution_Budget="Execution_Budget"
    | math_failure M.Released="Released"
    | math_failure (M.Runtime_Error message)="Runtime_Error: " ^ message;
  fun worker_failure (Worker.Ticket_Rejected message)="Ticket_Rejected: " ^ message
    | worker_failure Worker.Wrong_Executable="Wrong_Executable"
    | worker_failure Worker.Wrong_Generation="Wrong_Generation"
    | worker_failure Worker.Wrong_Operation="Wrong_Operation"
    | worker_failure Worker.Wrong_Cost="Wrong_Cost"
    | worker_failure Worker.Request_Already_Owned="Request_Already_Owned"
    | worker_failure (Worker.Execution_Failed reason)="Execution_Failed " ^ math_failure reason
    | worker_failure Worker.Released="Released"
    | worker_failure Worker.Worker_Failed="Worker_Failed (exceptional Future completion)";
  val issuer=Private.new_issuer ();
  val pin=M.executable ();
  val generation=R.generation @{context} {packages=["mathematics"],runtime="ticket-test",
    policy="fixed-operation-test",sources=[],interpretation="closed-expression"};
  val instance=(case M.attach {policy=A.policy @{theory},generation=generation,
    code_context=E.code_theory pin,limits={nodes=5000,depth=100,work=100,seconds=2}} of
    M.Ready value=>value | _=>error "math instance fixture");
  fun prepared native=(case M.prepare pin instance native of M.Ready value=>value
    | M.Refused reason=>error ("math prepared fixture: " ^ math_failure reason));
  fun charge request=(case M.modeled_cost request of M.Ready value=>value
    | _=>error "math actual charge unavailable");
  fun issued execution request extra =
    let
      val scope=Private.begin_scope issuer {owner_version=0,epoch=0};
      val operation:Private.operation_identity={workspace="fixture",request=2,profile=3,
        code_generation=4,operation=5,step=0,cost=charge request+extra,inputs=[6],
        owner_version=0,epoch=0,journal_sequence=1,semantic_generation=7,
        implementation_artifact="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"};
      val ticket=Private.issue_pure scope {execution=execution,slot=8,operation=operation}
        {executable=pin,instance=instance,request=request,operation=M.operation instance};
      val answer=Worker.start ticket;
      val _=Private.close_scope scope;
    in answer end;
  fun job (Worker.Ready value)=value
    | job (Worker.Refused reason)=error ("charged math worker did not start: " ^ worker_failure reason);
  fun result task=(case Worker.collect task of Worker.Ready value=>value
    | Worker.Refused reason=>error ("charged math worker terminal refusal: " ^ worker_failure reason));
  fun exact output expected=(case Worker.native_output output of Worker.Ready native=>
    (case M.output_view native of M.Ready (M.Exact_Rational value)=>
      if value=expected then () else error "wrong worker value"
    | _=>error "math exact view unavailable") | _=>error "worker output unavailable");
  val one=prepared @{cterm "closed_expression_run 100 (Plus (Rational 2) (Rational 3))"};
  val first=job (issued 1 one 0);
  val _=(case issued 2 one 0 of Worker.Refused Worker.Request_Already_Owned=>()
    | _=>error "same native request transferred to two workers");
  val two=prepared @{cterm "closed_expression_run 100 (Plus (Rational 3) (Rational 4))"};
  val second=job (issued 3 two 0);
  val first_output=result first;
  val second_output=result second;
  val _=exact first_output (5,1);
  val _=exact second_output (7,1);
  val _=Worker.cancel first;
  val _=(case Worker.native_output first_output of Worker.Refused Worker.Released=>()
    | _=>error "cancelled worker output retained");
  val _=exact second_output (7,1);
  val wrong=prepared @{cterm "closed_expression_run 100 (Rational 1)"};
  val _=(case issued 4 wrong 1 of Worker.Refused Worker.Wrong_Cost=>()
    | _=>error "caller charge accepted instead of actual prepared charge");
  val _=(case M.modeled_cost wrong of M.Refused M.Released=>()
    | _=>error "failed transferred request payload retained");
  val _=Worker.cancel second;
  val _=M.release_instance instance;
in
  val _=writeln "VERI7VN_EFFECTS math_ticket_workers PASS";
end;
\<close>
end
