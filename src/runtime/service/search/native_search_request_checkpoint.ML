(* Fixed read-only generated checkpoint query. It neither runs a reducer nor
   constructs a native receiver. Only the C-authenticated request factory calls
   this before acquiring a lease from the SAME shared native recovery graph. *)
structure Veri7vn_Search_Request_Checkpoint =
struct
  structure C=Veri7vn_Committed_Native_Recovery;
  structure W=Veri7vn_Native_Authority_Wire;
  type projection={identity:Veri7vn_Native_Request_Scope.identity,context:IntInf.int,
    receiver:IntInf.int,worker:IntInf.int,input:IntInf.int,cost:IntInf.int};
  type names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
    template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
    evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
    deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int};
  type phase={execution:IntInf.int option,stopped:string option,reason:IntInf.int option};
  fun nat n=Veri7vn_Numerals.nat_of_integer n;
  fun decoded committed=
    let fun convert(W.Atom number)= @{code WireNat}(nat number)
          | convert(W.Node(tag,children))= @{code WireNode}(nat(IntInf.fromInt tag),map convert children)
    in @{code decode_checkpoint}(convert(W.read(#checkpoint(C.materials committed))))end;
  fun stop "exhausted"= @{code SearchExhausted} | stop "budget"= @{code SearchBudget} |
    stop "deadline"= @{code SearchDeadline} | stop "cancelled"= @{code SearchCancelled} |
    stop "failed"= @{code SearchFailed} | stop _=error "Search checkpoint stopped variant";
  fun matches committed (p:projection)(n:names)({execution,stopped,reason}:phase)=
    let val i= #identity p;
      val values=[#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
        #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,#execution n,#code n,
        #evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
      val control= @{code search_service_control}(map nat values);
      (* First profile's catalogue contains ONLY actual named public theorems in
         this same image, so its native prerequisites are original source+receiver.
         Q.restore independently checks each canonical name/theorem again. *)
      val deps=distinct(op =)[#parameter n,#capability n,#operation n,#profile n,#code n,#template n,
        #input p,#receiver p,#interpretation i,#decision i];
      val consumed=is_some execution;
      fun pending state=
        exists(fn r=> @{code request_id}r=nat(#request i) andalso not(@{code request_cancelled}r) andalso
          exists(fn g=> @{code goal_id}g=nat(#goal i) andalso
            (case @{code goal_outcome}g of @{code AwaitingOutput}slot=>slot=nat(#slot i)
             | @{code Accepted}(_,eid)=>consumed andalso eid=nat(#evidence n) | _=>false))(@{code request_goals}r))
          (@{code requests}state);
      val names_ok=forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)values andalso
        length(distinct(op =)values)=length values andalso #context p= #receiver p andalso #worker p= #receiver p andalso
        (case execution of NONE=>true | SOME id=>id= #execution n);
      val phase_ok=case(stopped,reason)of(NONE,NONE)=>true
        |(SOME kind,SOME id)=>consumed andalso id=(case kind of "exhausted"=> #exhausted n | "budget"=> #budget n |
          "deadline"=> #deadline n | "cancelled"=> #cancelled n | "failed"=> #failed n | _=>0)
        |_=>false;
    in names_ok andalso phase_ok andalso (case decoded committed of NONE=>false | SOME state=>
      @{code search_service_request_matches}state control(map nat deps)(nat(#cost p)) andalso
      @{code search_service_execution_matches}state control(nat(#cost p))consumed andalso
      (case stopped of NONE=>pending state | SOME kind=> @{code search_service_stopped_matches}state control(stop kind)))end;
  (* A source-proof capsule is independently rechecked even when its original
     execution parent is terminal. This query authorizes no worker or visible
     binding: it checks the exact original charge and native evidence plus any
     already recorded publication, under continuing managed access. *)
  fun output_matches committed(p:projection)(n:names)native=
    let val i= #identity p;
      val values=[#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
        #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,#execution n,#code n,
        #evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
      val control= @{code search_service_control}(map nat values);
      val deps=distinct(op =)[#parameter n,#capability n,#operation n,#profile n,#code n,#template n,
        #input p,#receiver p,#interpretation i,#decision i]
    in case decoded committed of NONE=>false|SOME state=>
      @{code search_service_request_matches}state control(map nat deps)(nat(#cost p))andalso
      @{code search_service_execution_matches}state control(nat(#cost p))true andalso
      (case(@{code search_service_evidence}control(map nat deps)(map nat native),
            @{code search_service_publish}control(map nat deps)(map nat native))of
        (@{code AttachEvidence}e,@{code StageOutput}(_, @{code ClaimOutput}a,NONE))=>
          member(op =)(@{code evidence_table}state)e andalso @{code evidence_accessible}state e andalso
          (case filter(fn actual=> @{code assigned_slot}actual=nat(#slot i))
            (@{code claim_assignments}state)of []=>true|[actual]=>actual=a|_=>false)
        |_=>false)end;
end;
