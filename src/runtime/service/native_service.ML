signature VERI7VN_NATIVE_SERVICE =
sig
  (* There is no frame/projection/callback constructor for this ingress. *)
  val boot_image: unit -> Veri7vn_Native_Recovery_Check.image
  val public_development: unit -> Veri7vn_Managed_Provenance.development
  val identity_allocator: unit -> Veri7vn_Native_Identity_Allocator.allocator
  val issue_admitted: Veri7vn_Native_Authority_Descriptor.descriptor -> unit
  val release_admitted: Veri7vn_Native_Authority_Descriptor.descriptor -> unit
  (* Fixed trusted-ML diagnostics only; never a resident protocol operation. *)
  structure Test_Only:
  sig
    datatype fault = BeforeExport | BeforeIssue
    val check_proposal_cleanup: fault -> unit
    val check_rpc_ownership: unit -> unit
    val check_cleanup_ownership: unit -> unit
    val check_pending_alias_cleanup: unit -> unit
  end
end;
structure Veri7vn_Native_Service :> VERI7VN_NATIVE_SERVICE =
struct
structure F = Veri7vn_Metadata_Frame;
structure D = Veri7vn_Native_Authority_Descriptor;
structure I = Veri7vn_Native_Identity_Allocator;
structure V = Veri7vn_Native_Recovery_Check;
val boot_policy=Veri7vn_Native_Admission.policy @{theory};
val boot = Synchronized.var "veri7vn_native_boot_image" (NONE: (string * V.image) option);
fun boot_image ()=(case Synchronized.value boot of SOME (_,image)=>image
  | NONE=>error "Native deployment image not installed");
fun install_boot bytes =
  (F.guard (size bytes>0 andalso size bytes<=1048576) "Native boot manifest bound";
   Synchronized.change boot (fn previous=>case previous of
     SOME (old,image)=>if bytes=old then SOME (old,image) else error "Native boot image cannot be rebound"
   | NONE=>SOME (bytes,V.install_host_image boot_policy bytes)));

val identity_block = Synchronized.var "veri7vn_service_identity_block" (NONE: I.allocator option);
fun identity_allocator () = (case Synchronized.value identity_block of
  SOME value => value | NONE => error "Durable host identity block not installed");
fun install_ids payload =
  (case space_explode "," payload of
    [workspace, first, past] =>
      let
        fun decimal value = (F.guard (size value > 0 andalso size value <= 128 andalso
          String.sub (value, 0) <> #"0" andalso forall Char.isDigit (String.explode value))
          "invalid durable identity decimal"; the (IntInf.fromString value));
        val _ = (case Synchronized.value identity_block of
          NONE => () | SOME previous => F.guard (I.workspace previous = workspace)
            "resident native workspace mismatch");
        val allocator = I.install_host_block {workspace=workspace,
          first=decimal first, past=decimal past};
      in Synchronized.change identity_block (K (SOME allocator)) end
  | _ => error "invalid durable identity block shape");
val coordinator = Synchronized.var "veri7vn_native_service_coordinator" ();
fun serialized f = Synchronized.change_result coordinator (fn () => (f (), ()));
val native_poisoned=Synchronized.var "veri7vn_native_incarnation_poisoned" false;
structure Request=Veri7vn_Interpreted_Request;
structure Language=Veri7vn_Native_Language_Input;
structure Mathematics=Veri7vn_Mathematics_Execution;
structure MathGate=Veri7vn_Native_Math_Gate;
structure MathRecovery=Veri7vn_Native_Math_Recovery;
structure Display=Veri7vn_Refined_Math_Display;
structure RecoveryInputs=Veri7vn_Native_Recovery_Inputs;
val math_workspace_owners=Synchronized.var "veri7vn_private_math_workspace_owners"
  ([]:MathRecovery.workspace_owner list);
structure Literals=Veri7vn_Native_Literals;
structure Tickets=Veri7vn_Private_Operation_Tickets ();
structure MathWorker=Veri7vn_Math_Ticket_Execution_Fn
  (structure Mathematics=Mathematics structure Tickets=Tickets);
val issuer=Tickets.new_issuer ();
datatype math_entry=MathEntry of {request:Request.request,input:Literals.input,bridge:Display.bridge,
  execution:IntInf.int,cost:IntInf.int,dependencies:IntInf.int list,
  observed:IntInf.int list Synchronized.var,active:bool Synchronized.var,released:bool Synchronized.var,
  job:MathWorker.job option Synchronized.var,monitor:unit Future.future option Synchronized.var,
  witness:MathGate.witness option Synchronized.var,
  failure:string option Synchronized.var};
val math_requests=Synchronized.var "veri7vn_native_math_requests" ([]:(IntInf.int*math_entry) list);
fun entry_request (MathEntry {request,...})=request;
fun entry_native_live (MathEntry {request,bridge,cost,...})=
  Request.live request andalso Display.bridge_matches bridge(Request.instance request) andalso
  (case Mathematics.modeled_cost(Request.family_request request) of
    Mathematics.Ready actual=>actual=cost andalso
      Veri7vn_Executable_Identity.same(Request.executable request,Mathematics.executable())
  | _=>false) handle ERROR _=>false;
fun entry_live (entry as MathEntry {active,...})=Synchronized.value active andalso entry_native_live entry;
fun entry_bridge(MathEntry {bridge,...})=bridge;
fun entry_prerequisites entry=distinct(op =)(Request.native_prerequisites(entry_request entry) @
  Display.managed_dependencies(entry_bridge entry));
fun request_id entry= #request_id(Request.project(entry_request entry));
fun lookup_request id=AList.lookup(op =)(Synchronized.value math_requests) id;
fun math_entry id=(case lookup_request id of SOME entry=>entry | NONE=>error "Unknown native request");
fun entry_depends id (MathEntry {witness,dependencies,observed,...})=
  member(op =)(dependencies @ Synchronized.value observed) id orelse
  (case Synchronized.value witness of NONE=>false | SOME w=>
    id=MathGate.evidence w orelse member(op =)(MathGate.dependencies w) id);
datatype gate=Admitted of D.descriptor | MathInput of math_entry | MathParameter of math_entry | MathReserve of math_entry |
  MathStatement of math_entry | MathBridge of math_entry |
  MathExecute of math_entry | MathEvidence of math_entry* MathGate.witness |
  MathPublish of math_entry* MathGate.witness | RestoredMath of math_entry |
  RestoredOutput of math_entry*MathGate.witness | Lifecycle of F.lifecycle;
fun gate_live (Admitted d)=D.is_live d
  | gate_live (MathInput e)=entry_live e
  | gate_live (MathParameter e)=entry_live e
  | gate_live (MathReserve e)=entry_live e
  | gate_live (MathStatement e)=entry_live e
  | gate_live (MathBridge e)=entry_live e
  | gate_live (MathExecute e)=entry_live e
  | gate_live (MathEvidence(e,w))=entry_live e andalso MathGate.live w
  | gate_live (MathPublish(e,w))=entry_live e andalso MathGate.live w
  | gate_live (RestoredMath e)=entry_native_live e
  | gate_live (RestoredOutput(_,w))=MathGate.live w
  | gate_live (Lifecycle _)=true;
fun gate_frame (Admitted d) _=D.event_frame d
  | gate_frame (MathInput e) _=F.math_input_frame (Request.project(entry_request e))
  | gate_frame (MathParameter e) _=F.math_parameter_frame (Request.project(entry_request e))
      (Request.managed_dependencies(entry_request e))
  | gate_frame (MathStatement e) _=F.math_statement_frame(Request.project(entry_request e))
      (Display.project_bridge(entry_bridge e))
  | gate_frame (MathBridge e) _=F.math_bridge_frame(Request.project(entry_request e))
      (Display.project_bridge(entry_bridge e))
  | gate_frame (MathReserve (e as MathEntry {cost,...})) revision=
      F.math_reserve_frame (Request.project(entry_request e)) revision cost
        (entry_prerequisites e)
  | gate_frame (MathExecute (e as MathEntry {execution,cost,...})) _=
      F.math_execute_frame (Request.project(entry_request e)) execution cost
  | gate_frame (MathEvidence(_,w)) _=MathGate.evidence_frame w
  | gate_frame (MathPublish(_,w)) _=MathGate.publication_frame w
  | gate_frame (RestoredMath _) _=error "Restoration association is not an event"
  | gate_frame (RestoredOutput _) _=error "Restoration association is not an event"
  | gate_frame (Lifecycle action) _=F.lifecycle_frame action;
fun pure_command_matches (MathEntry {request,execution,cost,...})
    ({execution=actual,request=rid,slot,cost=charge,inputs}:F.pure_run) =
  let val p=Request.project request
  in actual=execution andalso rid= #request_id p andalso slot= #output_slot_id p andalso
    #profile charge= #profile_id p andalso #code_generation charge= #executable_generation p andalso
    #operation charge= #operation_id p andalso #step charge= #step_id p andalso
    #units charge=cost andalso inputs=[#parameter_id p] end;
fun supports (MathExecute e) [F.PureRun run]=pure_command_matches e run
  | supports (Lifecycle (F.Cancel rid)) [F.StopRequest actual]=rid=actual
  | supports (Lifecycle _) commands=forall (fn F.RemoveManaged _=>true |
      F.AuthorityChanged _=>true | _=>false) commands
  | supports _ commands=null commands;
fun recovery_view (Admitted descriptor)=F.KernelAssociation(D.event_frame descriptor)
  | recovery_view(MathReserve(entry as MathEntry {request,bridge,cost,...}))=F.MathRequestAssociation
      {names=Request.project request,dependencies=entry_prerequisites entry,
        managed=Request.managed_dependencies request,bridge=Display.project_bridge bridge,cost=cost}
  | recovery_view(MathEvidence(_,witness))=F.MathOutputAssociation
      {evidence=MathGate.evidence_frame witness,publication=MathGate.publication_frame witness}
  | recovery_view(RestoredMath(entry as MathEntry {request,bridge,cost,...}))=F.MathRequestAssociation
      {names=Request.project request,dependencies=entry_prerequisites entry,
        managed=Request.managed_dependencies request,bridge=Display.project_bridge bridge,cost=cost}
  | recovery_view(RestoredOutput(_,witness))=F.MathOutputAssociation
      {evidence=MathGate.evidence_frame witness,publication=MathGate.publication_frame witness}
  | recovery_view _=F.NoAssociation;
structure SupportGroups=Table(type key=IntInf.int*IntInf.int
  val ord=prod_ord IntInf.compare IntInf.compare);
fun retirement_registrations (Lifecycle (F.Forget _)) =
    let fun add key group (seen,groups)=
          if SupportGroups.defined seen key then (seen,groups) else
            (SupportGroups.update(key,())seen,group::groups);
      fun collect (_,entry) state=
        let val names=Request.project(entry_request entry);
          val bridge=Display.project_bridge(entry_bridge entry)
        in state |> add (#bridge_id bridge,#statement_code_id bridge)
            [F.math_statement_frame names bridge,F.math_bridge_frame names bridge]
          |> add (#input_identity names,0) [F.math_input_frame names] end;
      val (_,groups)=fold collect (Synchronized.value math_requests)(SupportGroups.empty,[])
    in rev groups end
  | retirement_registrations _=[];
structure Owner=Veri7vn_Native_State_Owner (struct
  type event=gate
  val is_live=gate_live
  val event_frame=gate_frame
  val supports=supports
  val retirement_registrations=retirement_registrations
  val recovery_view=recovery_view
end);
type recovery_material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
  projection:string,sequent:string,context_closure:string,reconstruction:string,
  executable:string option,dependencies:IntInf.int list};
fun boot_bytes()=(case Synchronized.value boot of SOME(bytes,_)=>bytes
  | NONE=>error "Native boot image unavailable");
fun kernel_material descriptor (m:Veri7vn_Native_Recovery_Export.material):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=NONE,
    dependencies=distinct(op =)(D.evidence_id descriptor::
      Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))};
fun math_material dependencies (m:MathRecovery.material):recovery_material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=SOME(#executable m),dependencies=distinct(op =)(#association m::dependencies)};
val tokens = Synchronized.var "veri7vn_native_gate_tokens"
  ([]: (string * (gate * recovery_material option)) list);
val associations = Synchronized.var "veri7vn_live_native_associations"
  ([]: (IntInf.int * D.descriptor) list);
val cleanup_precommit=Synchronized.var "veri7vn_cleanup_precommit" (fn()=>());
val pending = Synchronized.var "veri7vn_pending_native_transition"
  (NONE: (string * gate * Owner.candidate) option);
val durable_sequence=Synchronized.var "veri7vn_native_durable_sequence" (0:IntInf.int);
fun emit id tag payload chunks = Output.protocol_message
  [Markup.function "veri7vn_service_v1"]
  ([XML.Text ("1|" ^ id ^ "|" ^ tag ^ "|" ^ payload)] :: map Bytes.contents_blob chunks);
fun issue_gate_token gate material =
  let val _=F.guard(not(Synchronized.value native_poisoned)) "Native incarnation requires restart";
    val _=F.guard(gate_live gate) "Native gate association unavailable";
    val token=serial_string ();
    val _=Synchronized.change tokens (fn entries=>
      (F.guard(length entries<256) "Native gate token limit";(token,(gate,material))::entries));
  in Output.protocol_message [Markup.function "veri7vn_service_token_v1"] [[XML.Text token]];token end;
fun issue_gate gate material=ignore(issue_gate_token gate material);
fun public_development ()=(ignore(boot_image());
  Veri7vn_Managed_Provenance.public_image (identity_allocator()) boot_policy);
val local_math=Synchronized.var "veri7vn_native_local_math_policy"
  (NONE:(Request.local_policy*Display.bridge*IntInf.int) option);
fun local_math_policy ()=(case Synchronized.value local_math of SOME(p,b,_) =>(p,b) | NONE=>
  let val _=ignore(boot_image());
    val development=public_development();
    val generation=Veri7vn_Managed_Provenance.generation development;
    val semantic=I.generation_id(identity_allocator())generation;
    val owned_instance=Unsynchronized.ref(NONE:Mathematics.instance option);
    val owned_context=Unsynchronized.ref(NONE:MathRecovery.workspace_owner option);
    val owned_bridge=Unsynchronized.ref(NONE:Display.bridge option);
    fun build()=
      let val pin=Mathematics.executable();
        val instance=(case Mathematics.attach {policy=boot_policy,generation=generation,
            code_context=Veri7vn_Executable_Identity.code_theory pin,
            limits={nodes=20000,depth=2048,work=512,seconds=5}} of
          Mathematics.Ready value=>value | Mathematics.Refused _=>error "Shipped mathematics qualification failed");
        val _=owned_instance:=SOME instance;
        val policy=Request.allow_mathematics (identity_allocator()) pin instance;
        val bridge=Display.attach {allocator=identity_allocator(),policy=boot_policy,generation=generation,
          instance=instance,statement_pin=F.statement_executable()};
        val _=owned_bridge:=SOME bridge;
        val owner=MathRecovery.own_public(identity_allocator()) development instance bridge;
        val _=owned_context:=SOME owner;
        val _=Synchronized.change math_workspace_owners(cons owner);
        val _=Synchronized.change local_math (K(SOME(policy,bridge,semantic)));
      in (policy,bridge) end;
    val result=Exn.capture build()
  in case result of Exn.Res binding=>binding | Exn.Exn failure=>
    (Request.release_dependencies(I.workspace(identity_allocator()))[semantic];
     (case !owned_context of SOME owner=>MathRecovery.release_workspace owner
      | NONE=>(Option.app Display.release_bridge(!owned_bridge);
         (case !owned_instance of SOME instance=>Mathematics.release_instance instance | NONE=>());
          Veri7vn_Managed_Provenance.release development));
     Exn.reraise failure) end);
fun valid_id id = size id > 0 andalso size id <= 18 andalso forall Char.isDigit (String.explode id);
fun decimal text=(F.guard(size text>0 andalso size text<=128 andalso
  forall Char.isDigit(String.explode text) andalso (size text=1 orelse String.sub(text,0)<> #"0"))
  "Native identity control bound";the(IntInf.fromString text));
fun prepare id token =
  if is_some(Synchronized.value pending) then emit id "rejected" "pending_transition" [] else
  (case AList.lookup(op =)(Synchronized.value tokens) token of
    NONE=>emit id "rejected" "unknown_native_gate_token" []
  | SOME(gate,_)=>if not(gate_live gate) then
      (Owner.invalidate();Synchronized.change tokens(AList.delete(op =)token);
       emit id "rejected" "native_gate_expired" [])
    else if (case gate of MathStatement _=>Owner.registration_present gate
          | MathBridge _=>Owner.registration_present gate | _=>false) then
      (Owner.invalidate();Synchronized.change tokens(AList.delete(op =)token);
       (case gate of MathStatement entry=>
           if Owner.registration_present(MathBridge entry) then issue_gate(MathInput entry)NONE
           else issue_gate(MathBridge entry)NONE
         | MathBridge entry=>issue_gate(MathInput entry)NONE | _=>());
       emit id "rejected" "native_gate_expired" [])
    else let val _=(case gate of Lifecycle _=>(Synchronized.value cleanup_precommit)() | _=>());
      val candidate=Owner.prepare gate;
      val _=Synchronized.change pending(K(SOME(token,gate,candidate)));
    in emit id "prepared" (token ^ "," ^ IntInf.toString(Owner.revision candidate) ^ "," ^
      IntInf.toString(Owner.epoch candidate))
      [Bytes.string(Owner.event_frame candidate),Bytes.string(Owner.checkpoint candidate)] end);
fun validate token=(case Synchronized.value pending of
  SOME(current,_,candidate)=>token=current andalso Owner.valid candidate | NONE=>false);
fun deny_entry (MathEntry {active,...})=Synchronized.change active(K false);
fun release_entry (MathEntry {job,monitor,request,witness,input,released,...}) =
  ((case Synchronized.value job of NONE=>() | SOME running=>
      (MathWorker.cancel running;Synchronized.change job(K NONE)));
   (case Synchronized.value monitor of NONE=>() | SOME task=>
      (Future.cancel task;ignore(Future.join_result task);Synchronized.change monitor(K NONE)));
   (case Synchronized.value witness of NONE=>() | SOME value=>
      (MathGate.release value;Synchronized.change witness(K NONE)));
   Request.release request;Synchronized.change released(K true));
fun drain_unused_math_contexts()=
  List.app(fn owner=>
    (List.app(fn bridge_id=>
      let val entries=map snd(filter(fn(_,entry)=>
          #bridge_id(Display.project_bridge(entry_bridge entry))=bridge_id)(Synchronized.value math_requests));
        val drained=forall(fn MathEntry {released,...}=>Synchronized.value released)entries
      in if drained then MathRecovery.release_installation owner bridge_id else () end)
        (MathRecovery.installation_ids owner);
     List.app(fn semantic=>
      let val entries=map snd(filter(fn (_,entry)=>
          #semantic_generation(Request.project(entry_request entry))=semantic)(Synchronized.value math_requests));
        val drained=forall(fn MathEntry {released,...}=>Synchronized.value released)entries
      in if not drained then () else
        (Request.release_dependencies(I.workspace(identity_allocator()))[semantic];
         MathRecovery.release_context owner semantic;
         Synchronized.change local_math(fn current=>case current of SOME(_,_,actual)=>
           if actual=semantic then NONE else current | NONE=>NONE)) end)(MathRecovery.context_ids owner)))
    (Synchronized.value math_workspace_owners);
datatype cleanup=Cleanup of {release:(unit->unit) option Synchronized.var,
  task:unit Future.future option Synchronized.var};
val cleanups=Synchronized.var "veri7vn_retryable_native_cleanup" ([]:(IntInf.int*cleanup)list);
val max_cleanup_jobs=256;
fun cleanup_state(Cleanup {release,task})=if is_none(Synchronized.value release)then 1 else
  (case Synchronized.value task of NONE=>0 | SOME future=>
    (case Future.peek future of NONE=>0 | SOME(Exn.Res())=>1 | SOME(Exn.Exn _)=>2));
fun pending_cleanups entries=filter(fn(_,job)=>cleanup_state job<>1)entries;
fun cleanup_capacity()=F.guard(length(pending_cleanups(Synchronized.value cleanups))<max_cleanup_jobs)
  "Native cleanup intent capacity; retry outstanding cleanup before lifecycle transition";
val _=Synchronized.change cleanup_precommit(K cleanup_capacity);
fun start_cleanup(Cleanup {release,task})=
  (case Synchronized.value release of NONE=>() | SOME work=>
    let val future=Future.fork(fn()=>
      (work();Synchronized.change release(K NONE)))
    in Synchronized.change task(K(SOME future))end);
fun retain_cleanup target cleanup old=(target,cleanup)::pending_cleanups old;
fun launch_cleanup target work =
  let val cleanup=Cleanup {release=Synchronized.var "veri7vn_cleanup_owned_roots" (SOME work),
      task=Synchronized.var "veri7vn_native_cleanup_task" NONE};
    (* Preserve every admitted intent for this target. Revoke->Forget can overlap
       while the first worker still owns descriptors no longer in associations. *)
    val _=Synchronized.change cleanups(retain_cleanup target cleanup);
  in start_cleanup cleanup end;
fun cleanup_status id payload retry =
  let val target=decimal payload;
    val jobs=map snd(filter(fn(actual,_)=>actual=target)(Synchronized.value cleanups));
    val _=if retry then List.app(fn job=>if cleanup_state job=2 then start_cleanup job else ())jobs else ();
    val states=map cleanup_state jobs;
    val status=if null jobs then "unknown" else if member(op =)states 2 then "failed_retryable"
      else if member(op =)states 0 then "pending" else "complete"
  in emit id "cleanup" status [] end;
fun cleanup_barrier id =
  let val states=map(cleanup_state o snd)(Synchronized.value cleanups);
    val status=if Synchronized.value native_poisoned orelse member(op =)states 2
      then "failed_retryable" else if member(op =)states 0 then "pending" else "complete"
  in emit id "cleanup" status [] end;
fun retry_all_cleanups id =
  (List.app(fn (_,job)=>if cleanup_state job=2 then start_cleanup job else ())
    (Synchronized.value cleanups);
   cleanup_barrier id);
fun cleanup_action action invalidations =
  let
    val (target,removed)=(case action of F.Cancel rid=>(rid,[rid])
      | F.Revoke id=>(id,F.invalidation_ids invalidations) | F.Forget id=>(id,F.invalidation_ids invalidations)
      | F.RetireCapability id=>(id,[id]) | F.RetireSource id=>(id,[id]));
    val entries=map snd (filter(fn (_,entry)=>exists(fn id=>entry_depends id entry)removed)
      (Synchronized.value math_requests));
    val _=List.app deny_entry entries;
    val _=(case action of F.Forget _=>List.app(fn MathEntry {request,input,...}=>
      if member(op =)removed(#input_identity(Request.project request)) then Literals.invalidate input else ())entries
      | _=>());
    fun descriptor_removed descriptor=exists(fn id=>
      id=D.evidence_id descriptor orelse
      member(op =)(Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))id)removed;
    val descriptors=distinct (fn (left,right)=>D.evidence_id left=D.evidence_id right)
      (filter descriptor_removed (map snd (Synchronized.value associations) @
        map_filter(fn (_, (Admitted descriptor,_))=>SOME descriptor | _=>NONE)
          (Synchronized.value tokens)));
    (* Invalid pending aliases own original bytes/recovery exports even though
       they never reached durability. Drop their token material at this ack. *)
    val _=Synchronized.change tokens(filter(fn (_, (gate,_))=>case gate of
      Admitted descriptor=>not(descriptor_removed descriptor) | _=>gate_live gate));
    val _=Synchronized.change associations(filter(fn (_,descriptor)=>not(exists(fn other=>
      D.evidence_id other=D.evidence_id descriptor)descriptors)));
    fun release()=(List.app release_entry entries;List.app D.release descriptors;
      (case action of F.Cancel _=>() | _=>Request.release_dependencies(I.workspace(identity_allocator()))removed);
      serialized drain_unused_math_contexts);
  in if target=0 orelse null removed then () else launch_cleanup target release end;
fun implementation_artifact ()=(case Synchronized.value boot of
  SOME(bytes,_)=>Message_Digest.rep(SHA256.digest bytes) | NONE=>error "Boot image unavailable");
fun start_math entry sequence =
  let val MathEntry {request,bridge,execution,job,monitor,failure,...}=entry;
    val p=Request.project request;
    val cost=(case Mathematics.modeled_cost(Request.family_request request) of
      Mathematics.Ready n=>n | _=>error "Released prepared mathematics input");
    val version=Owner.current_version(); val epoch=Owner.current_epoch();
    val identity={execution=execution,slot= #output_slot_id p,
      operation={workspace=I.workspace(identity_allocator()),request= #request_id p,
        profile= #profile_id p,code_generation= #executable_generation p,
        operation= #operation_id p,step= #step_id p,cost=cost,inputs=[#parameter_id p],
        owner_version=version,epoch=epoch,journal_sequence=sequence,
        semantic_generation= #semantic_generation p,implementation_artifact=implementation_artifact()}};
    val scope=Tickets.begin_scope issuer {owner_version=version,epoch=epoch};
    val started=Exn.capture (fn()=>MathWorker.start(Tickets.issue_pure scope identity
      {executable=Request.executable request,instance=Request.instance request,
        request=Request.family_request request,operation=Request.family_operation request})) ();
    val _=Tickets.close_scope scope;
  in case started of
    Exn.Res(MathWorker.Ready running)=>
      (Synchronized.change job(K(SOME running));
       let val task=Future.fork(fn()=>
         let fun complete()=
         let
           val result=MathWorker.collect running;
           (* Projection and native substitution may allocate or time out. They
              run outside the owner lock; publication rechecks current authority. *)
           val specialized=Exn.capture (fn()=>case result of
             MathWorker.Ready output=>
               (F.guard(MathWorker.output_identity output=identity)
                  "Worker completion differs from the durably charged native handoff";
                case MathWorker.native_output output of
               MathWorker.Ready raw=>let
                 val witness=MathGate.specialize(identity_allocator()) bridge request execution raw;
                 val exported=Exn.capture(fn()=>math_material (MathGate.managed_dependencies witness)
                   (MathRecovery.export_output (boot_image()) (boot_bytes()) witness))();
               in case exported of Exn.Res material=>SOME(witness,material)
                 | Exn.Exn failure=>(MathGate.release witness;Exn.reraise failure) end
             | _=>NONE)
           | _=>NONE) ();
         in serialized(fn()=>case specialized of
             Exn.Res(SOME(witness,material))=>if entry_live entry andalso MathGate.live witness then
               let val MathEntry {witness=root,observed,...}=entry;
                 val _=Synchronized.change root(K(SOME witness));
                 val _=Synchronized.change observed(K(MathGate.managed_dependencies witness));
               in issue_gate (MathEvidence(entry,witness)) (SOME material) end
               else MathGate.release witness
           | _=>(case result of MathWorker.Ready output=>MathWorker.release_output output | _=>();
               Synchronized.change failure(K(SOME "execution.failure")))) end;
           val completed=Exn.capture complete()
         in case completed of Exn.Res()=>() | Exn.Exn _=>serialized(fn()=>
           let val MathEntry {witness=root,...}=entry;
             val owned=Synchronized.change_result root(fn old=>(old,NONE));
             val _=(case owned of NONE=>() | SOME witness=>
               (Synchronized.change tokens(filter(fn (_, (MathEvidence(_,other),_))=>
                   MathGate.evidence other<>MathGate.evidence witness | _=>true));
                MathGate.release witness));
           in Synchronized.change failure(K(SOME "execution.failure")) end) end)
       in Synchronized.change monitor(K(SOME task)) end)
  | _=>Synchronized.change failure(K(SOME "execution.handoff_rejected")) end;
fun after_ack gate commands sequence invalidations =
  (case gate of
    Admitted d=>Synchronized.change associations(AList.update(op =)(D.evidence_id d,d))
  | MathInput e=>issue_gate (MathParameter e) NONE
  | MathParameter e=>issue_gate (MathExecute e) NONE
  | MathReserve e=>if not(Owner.registration_present(MathStatement e))
      then issue_gate(MathStatement e)NONE else if not(Owner.registration_present(MathBridge e))
      then issue_gate(MathBridge e)NONE else issue_gate(MathInput e)NONE
  | MathStatement e=>if Owner.registration_present(MathBridge e) then issue_gate(MathInput e)NONE
      else issue_gate(MathBridge e)NONE
  | MathBridge e=>issue_gate(MathInput e)NONE
  | MathExecute e=>(F.guard(case commands of [F.PureRun run]=>pure_command_matches e run | _=>false)
      "Acknowledged command differs from fixed worker";start_math e sequence)
  | MathEvidence(e,w)=>issue_gate (MathPublish(e,w)) NONE
  | MathPublish _=>()
  | RestoredMath _=>error "Restored association cannot acknowledge an event"
  | RestoredOutput _=>error "Restored association cannot acknowledge an event"
  | Lifecycle action=>cleanup_action action invalidations);
fun acknowledge_internal id payload =
  (case space_explode "," payload of [token,sequence_text]=>
    if not(validate token) then emit id "rejected" "precommit_mismatch" [] else
    let val sequence=decimal sequence_text;
      val _=F.guard(sequence=Synchronized.value durable_sequence+1) "Durable sequence mismatch";
      val SOME(_,gate,candidate)=Synchronized.value pending;
      (* Installation and actual one-shot fixed-worker handoff share this
         uninterrupted coordinator interval. Long work and joins are outside. *)
      val commands=Owner.acknowledge candidate;
      val _=Synchronized.change durable_sequence(K sequence);
      val _=Synchronized.change pending(K NONE);
      val _=Synchronized.change tokens(AList.delete(op =) token);
      val handoff=Exn.capture(fn()=>after_ack gate commands sequence (Owner.invalidations candidate))();
      val _=(case handoff of Exn.Res()=>() | Exn.Exn failure=>
        (Synchronized.change native_poisoned(K true);Exn.reraise failure));
    in emit id "acknowledged" token [] end
  | _=>emit id "rejected" "acknowledgement_shape" []);
fun acknowledge id payload=Thread_Attributes.uninterruptible(fn _=>fn()=>acknowledge_internal id payload)();
fun gate_request_id (MathInput entry)=SOME(request_id entry)
  | gate_request_id(MathParameter entry)=SOME(request_id entry)
  | gate_request_id(MathReserve entry)=SOME(request_id entry)
  | gate_request_id(MathStatement entry)=SOME(request_id entry)
  | gate_request_id(MathBridge entry)=SOME(request_id entry)
  | gate_request_id(MathExecute entry)=SOME(request_id entry)
  | gate_request_id(MathEvidence(entry,_))=SOME(request_id entry)
  | gate_request_id(MathPublish(entry,_))=SOME(request_id entry)
  | gate_request_id _=NONE;
datatype proposal_fault=BeforeExport | BeforeIssue;
val proposal_fault=Synchronized.var "veri7vn_test_proposal_fault" (NONE:proposal_fault option);
val proposal_probe=Synchronized.var "veri7vn_test_proposal_probe"
  (NONE:{entry:math_entry,instance:Mathematics.instance,
    generation:Veri7vn_Native_Registry.generation} option);
fun proposal_fault_at point entry =
  let val armed=Synchronized.change_result proposal_fault(fn current=>
    if current=SOME point then (true,NONE) else (false,current))
  in if not armed then () else
    let val instance=Request.instance(entry_request entry);
      val generation=Veri7vn_Native_Admission.generation(Mathematics.contract instance)
    in Synchronized.change proposal_probe(K(SOME {entry=entry,instance=instance,generation=generation}));
      error "Injected native proposal failure" end end;
fun discard_new_input input=
  (Literals.invalidate input;Option.app I.release_disposed_input(Literals.drop_base input));
fun propose_math id payload bytes =
  let val _=F.guard(size bytes<=256) "Original request byte bound";
    val selection=if payload="" then NONE else SOME(IntInf.toInt(decimal payload));
    val _=F.guard(case selection of NONE=>true | SOME n=>n<=255) "Interpretation selection bound";
    val input=Literals.input {bytes=bytes,encoding="UTF-8"};
    val prepared=Unsynchronized.ref(NONE:Request.request option);
    val local_entry=Unsynchronized.ref(NONE:math_entry option);
    fun cleanup()=
      ((case !local_entry of NONE=>(case !prepared of NONE=>() | SOME request=>Request.release request)
        | SOME entry=>
          let val rid=request_id entry;
            val _=Synchronized.change tokens(filter(fn (_, (gate,_))=>gate_request_id gate<>SOME rid));
            val _=Synchronized.change math_requests(AList.delete(op =)rid)
          in release_entry entry end);
       discard_new_input input;drain_unused_math_contexts());
    fun run()=
      let val (policy,bridge)=local_math_policy()
      in case Request.elaborate_math policy input selection of Request.Ready request=>
        let val _=prepared:=SOME request;
          val _=Option.app I.release_disposed_input(Literals.drop_base input);
          val cost=(case Mathematics.modeled_cost(Request.family_request request) of
            Mathematics.Ready n=>n | _=>error "Native modeled cost unavailable");
          val execution=I.allocate(identity_allocator());
          val entry=MathEntry {request=request,input=input,bridge=bridge,execution=execution,
            cost=cost,dependencies=Request.managed_dependencies request @ Display.managed_dependencies bridge,
            observed=Synchronized.var "veri7vn_request_observed_dependencies" [execution],
            active=Synchronized.var "veri7vn_request_active" true,
            released=Synchronized.var "veri7vn_request_released" false,
            job=Synchronized.var "veri7vn_request_job" NONE,
            monitor=Synchronized.var "veri7vn_request_monitor" NONE,witness=Synchronized.var "veri7vn_request_witness" NONE,
            failure=Synchronized.var "veri7vn_request_failure" NONE};
          val _=local_entry:=SOME entry;
          (* Qualify retained material before publishing the proposal's native
             ownership roots. Nothing has a durable reservation at this point. *)
          val _=proposal_fault_at BeforeExport entry;
          val material=math_material (Request.managed_dependencies request @ Display.managed_dependencies bridge)
            (MathRecovery.export_request (boot_image()) (boot_bytes()) bridge request);
          val rid=request_id entry;
          val _=Synchronized.change math_requests(fn entries=>
            (F.guard(length entries<8192) "Native request ownership bound";AList.update(op =)(rid,entry)entries));
          val _=proposal_fault_at BeforeIssue entry;
          val _=issue_gate (MathReserve entry) (SOME material);
        in emit id "proposed" (IntInf.toString rid) [] end
      | Request.NeedsSelection _=>(discard_new_input input;emit id "needs_selection" "interpretation.ambiguous" [])
      | Request.NeedsLiteral _=>(discard_new_input input;emit id "needs_literal" "interpretation.literal" [])
      | Request.Refused _=>(discard_new_input input;emit id "rejected" "interpretation.unrecognized" []) end;
    val result=Exn.capture run()
  in case result of Exn.Res()=>() | Exn.Exn failure=>(cleanup();Exn.reraise failure) end;
structure Proposal_Test_Only =
struct
  datatype fault=datatype proposal_fault;
  fun check_proposal_cleanup point = serialized(fn()=>
    let
      val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
        andalso is_none(Synchronized.value pending) andalso not(Synchronized.value native_poisoned))
        "Proposal diagnostic requires an unused resident";
      val _=(case Synchronized.value boot of NONE=>install_boot "native-service-failure-test/1" | SOME _=>());
      val _=(case Synchronized.value identity_block of NONE=>
          install_ids "c0de0000000000000000000000000003,1000000,1065536" | SOME _=>());
      val version=Owner.current_version();
      val sequence=Synchronized.value durable_sequence;
      val _=Synchronized.change proposal_probe(K NONE);
      val _=Synchronized.change proposal_fault(K(SOME point));
      val outcome=Exn.capture(fn()=>propose_math "0" "" "the sum of -2 and 3")();
      val probe=Synchronized.change_result proposal_probe(fn old=>(old,NONE));
      val armed=Synchronized.change_result proposal_fault(fn old=>(old,NONE));
      val _=F.guard(Exn.is_exn outcome andalso is_none armed andalso is_some probe)
        "Proposal diagnostic did not reach its fixed failure boundary";
      val {entry,instance,generation}=the probe;
      val request=entry_request entry;
      val MathEntry {input,released,job,monitor,witness,...}=entry;
      val _=F.guard(not(Request.live request) andalso not(Literals.retained input) andalso
        Synchronized.value released andalso is_none(Synchronized.value job) andalso
        is_none(Synchronized.value monitor) andalso is_none(Synchronized.value witness))
        "Failed proposal retained an actual request, input or worker owner";
      val _=F.guard(Exn.is_exn(Exn.capture Mathematics.contract instance) andalso
        Exn.is_exn(Exn.capture Display.bridge_contract(entry_bridge entry)) andalso
        is_none(I.lookup_generation_id(identity_allocator())generation))
        "Failed proposal retained an instance or canonical generation owner";
      val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
        andalso is_none(Synchronized.value pending) andalso is_none(Synchronized.value local_math))
        "Failed proposal retained a registered entry, token or local instance policy";
      val _=F.guard(Owner.current_version()=version andalso Synchronized.value durable_sequence=sequence)
        "Undurable proposal failure changed committed authority";
    in () end);
end;
fun result_view (entry as MathEntry {witness,failure,...}) =
  if not(entry_live entry) then ("cancelled",[]) else
    case Synchronized.value witness of
      NONE=>(the_default "pending" (Synchronized.value failure),[])
    | SOME w=>if not(Owner.binding_live (request_id entry) (MathGate.evidence w))
      then ("pending",[]) else
      (case MathGate.display w of
        Veri7vn_Refined_Math_Display.Exact {statement_html,...}=>("accepted_exact",[statement_html])
      | Veri7vn_Refined_Math_Display.Undefined=>("undefined",[])
      | Veri7vn_Refined_Math_Display.Missing _=>("missing_parameters",[])
      | Veri7vn_Refined_Math_Display.Syntax=>("invalid_syntax",[])
      | Veri7vn_Refined_Math_Display.Budget=>("budget",[]));
fun poll_result id payload =
  let val request=decimal payload;
    val (status,artifacts)=(case lookup_request request of SOME entry=>result_view entry
      | NONE=>if Owner.request_unavailable request then ("cancelled",[])
          else error "Unknown native request")
  in emit id "result" status (map Bytes.string artifacts) end;
(* Owner inspection reports actual retained readings and numeric provenance. It
   never serializes ticket authority, private native contexts or source bytes. *)
fun inspect_request id payload =
  let val entry as MathEntry {request,input,execution,released,...}=math_entry(decimal payload);
    val p=Request.project request;
    fun n value=IntInf.toString value;
    fun node name attributes body=XML.Elem((name,attributes),body);
    val identity=node "identity"
      [("request",n(#request_id p)),("goal",n(#goal_id p)),
       ("interpretation",n(#interpretation_id p)),("decision",n(#decision_id p)),
       ("capability",n(#capability_id p)),("operation",n(#operation_id p)),
       ("semantic_generation",n(#semantic_generation p)),
       ("executable_generation",n(#executable_generation p)),("execution",n execution)][];
    val reading=if not(entry_live entry) then node "reading-unavailable"
        [("reason",if Synchronized.value released then "released" else "invalidated")][]
      else if not(Literals.retained input) then node "reading-unavailable" [("reason","not_retained")][]
      else let
        val (operation,_,_,slices)=Language.resolve(Request.reading request);
        val operation=(case operation of Language.Sum=>"sum" | Language.Difference=>"difference"
          | Language.Product=>"product" | Language.Quotient=>"quotient" | Language.SubtractFrom=>"subtract_from");
        fun literal slice=let val {start,stop}=Literals.offsets slice
          in node "literal" [("start",Int.toString start),("stop",Int.toString stop)][] end
      in node "reading" [("index",Int.toString(Request.selected_index request)),
        ("operation",operation),("input_bytes",Int.toString(size(Literals.bytes input)))](map literal slices)end;
    val (status,_)=result_view entry;
    val frame=YXML.string_of_body[node "veri7vn-request-inspection"
      [("version","1"),("status",status),("family","mathematics")][identity,reading]];
    val _=F.guard(size frame<=8192) "Native request inspection frame bound"
  in emit id "request_inspection" (n(#request_id p)) [Bytes.string frame] end;
fun inspect_routing id payload bytes =
  let val _=F.guard(payload="math/1" andalso size bytes<=256) "Native routing policy/input bound";
    val (applicable,budget,alternatives,blocked)=F.interpretation_packet_bytes bytes;
    val status=if budget then "budget" else if not applicable then "unrecognized"
      else if null alternatives then if null blocked then "structure_blocked" else "literal" else "readings";
    val artifacts=if status="readings" then
      [Bytes.string(space_implode "," (map_index(fn(index,_)=>Int.toString index)alternatives))] else []
  in emit id "routing" status artifacts end;
fun lifecycle id operation payload =
  let val target=decimal payload;
    val action=(case operation of "cancel"=>(ignore(math_entry target);F.Cancel target)
      | "retire_capability"=>(F.guard(exists(fn (_,e)=>
          #capability_id(Request.project(entry_request e))=target)(Synchronized.value math_requests))
          "Unknown native capability";F.RetireCapability target)
      | _=>(F.guard(member(op =)(Owner.revoked_ids())target orelse
          exists(fn (_,e)=>entry_depends target e)(Synchronized.value math_requests)
          orelse exists(fn (_,descriptor)=>target=D.evidence_id descriptor orelse
          member(op =)(Veri7vn_Native_Descriptor.native_object_dependencies(D.native descriptor))target)
            (Synchronized.value associations))
          "Unknown managed native association";
          if operation="forget" then F.Forget target else if operation="revoke" then F.Revoke target
          else error "Unknown lifecycle operation"));
    val token=issue_gate_token (Lifecycle action) NONE;
  in emit id "lifecycle_queued" token [] end;
fun command_info id token =
  (case Synchronized.value pending of SOME(current,gate,candidate)=>
    if current<>token orelse not(Owner.valid candidate) then emit id "rejected" "precommit_mismatch" [] else
      (case gate of MathExecute(MathEntry {request,execution,cost,...})=>
        let val p=Request.project request
        in emit id "commands" token [Bytes.string(space_implode "," ("pure"::map IntInf.toString
          [execution,#request_id p,#output_slot_id p,#profile_id p,#executable_generation p,
            #operation_id p,#step_id p,cost]))] end
      | _=>emit id "commands" "" [])
  | NONE=>emit id "rejected" "no_pending_transition" []);
fun recovery_material token=(case AList.lookup(op =)(Synchronized.value tokens) token of
    SOME(gate,SOME material)=>
      (F.guard(gate_live gate) "Native recovery association released";material)
  | _=>error "No kernel recovery material for native token");
fun material_slots (m:recovery_material)=
  [#manifest m,#projection m,#sequent m,#context_closure m,#reconstruction m] @
    the_list(#executable m);
fun recovery_info id token =
  (case AList.lookup(op =)(Synchronized.value tokens) token of
    SOME(_,SOME _)=>let val m=recovery_material token
      in emit id "recovery" (space_implode "," (token::IntInf.toString(#association m)::
        IntInf.toString(#semantic_generation m)::map(Int.toString o size)(material_slots m))) [] end
  | SOME _=>emit id "recovery_none" token []
  | NONE=>emit id "rejected" "unknown_native_gate_token" []);
fun recovery_read id payload=(case space_explode "," payload of [token,slot_text,offset_text]=>
  let val slot=IntInf.toInt(decimal slot_text);
    val offset=IntInf.toInt(decimal offset_text);
    val values=material_slots(recovery_material token);
    val _=F.guard(slot>=0 andalso slot<length values) "Recovery slot bound";
    val bytes=nth values slot;
    val _=F.guard(offset>=0 andalso offset<=size bytes) "Recovery offset bound";
    val chunk=String.substring(bytes,offset,Int.min(65536,size bytes-offset));
  in emit id "recovery_bytes" payload [Bytes.string chunk] end
  | _=>emit id "rejected" "recovery_read_shape" []);
fun recovery_dependencies id token=
  let val material=recovery_material token;
    val bytes=space_implode ","(map IntInf.toString(#dependencies material));
    val _=F.guard(size bytes<=1048576) "Native recovery dependency byte bound";
  in emit id "recovery_dependencies" token [Bytes.string bytes] end;
fun artifact_invalidations id token=
  (case Synchronized.value pending of SOME(current,gate,candidate)=>
    if current<>token orelse not(Owner.valid candidate) then emit id "rejected" "precommit_mismatch" [] else
      let val invalidations=Owner.invalidations candidate;
        val ids=F.invalidation_ids invalidations;
        val mode=if null ids then "none" else (case invalidations of
          F.Revoked _=>"revoke" | F.Forgotten _=>"forget" | F.NoInvalidations=>"none");
      in emit id "artifact_invalidations" (token ^ "," ^ mode)
        (if null ids then [] else [Bytes.string(space_implode ","(map IntInf.toString ids))]) end
  | NONE=>emit id "rejected" "no_pending_transition" []);
datatype restore_upload=Upload of {association:IntInf.int,semantic:IntInf.int,origin:IntInf.int,
  sizes:int list,chunks:string list Array.array,written:int Array.array};
datatype restore_transaction=Restore of {workspace:string,sequence:IntInf.int,checkpoint:string,
  required:F.recovery_identity list,materials:(IntInf.int*(IntInf.int*recovery_material))list Unsynchronized.ref,
  upload:restore_upload option Unsynchronized.ref,total:int Unsynchronized.ref,
  active:bool Synchronized.var,completed:bool Synchronized.var,task:unit Future.future option Synchronized.var};
val restoring=Synchronized.var "veri7vn_native_restore_transaction" (NONE:restore_transaction option);
fun restore_transaction()=(case Synchronized.value restoring of SOME transaction=>transaction
  | NONE=>error "No native restore transaction");
fun staging_transaction()=
  let val transaction as Restore {task,active,...}=restore_transaction();
    val _=F.guard(is_none(Synchronized.value task) andalso Synchronized.value active)
      "Native restore is not staging artifacts"
  in transaction end;
fun role_name F.KernelRole="kernel" | role_name F.MathRequestRole="request" | role_name F.MathOutputRole="output";
fun restore_begin id payload checkpoint =
  (case space_explode "," payload of [workspace,sequence_text,revision_text,epoch_text]=>
    let val _=F.guard(is_none(Synchronized.value restoring) andalso
        null(Synchronized.value tokens) andalso is_none(Synchronized.value pending) andalso
        null(Synchronized.value math_requests) andalso null(Synchronized.value associations))
        "Native restore requires fresh unassociated process";
      val sequence=decimal sequence_text;
      val state=the(F.decode_state checkpoint);
      val _=F.guard(workspace=I.workspace(identity_allocator()) andalso sequence>0 andalso
        F.revision state=decimal revision_text andalso F.epoch state=decimal epoch_text andalso
        F.encode_state state=checkpoint) "Native restore latest checkpoint identity mismatch";
      val required=F.required_associations state;
      val ids=map #association required;
      val _=F.guard(length ids<=8192 andalso length(distinct(op =)ids)=length ids)
        "Native restore association identity bound";
      val transaction=Restore {workspace=workspace,sequence=sequence,checkpoint=checkpoint,required=required,
        materials=Unsynchronized.ref [],upload=Unsynchronized.ref NONE,total=Unsynchronized.ref 0,
        active=Synchronized.var "native_restore_active" true,completed=Synchronized.var "native_restore_complete" false,
        task=Synchronized.var "native_restore_worker" NONE};
      val _=Synchronized.change restoring(K(SOME transaction));
      val bytes=space_implode "\n"(map(fn {association,semantic_generation,role}=>space_implode ","
        [role_name role,IntInf.toString association,IntInf.toString semantic_generation])required);
    in emit id "restore_required" "" [Bytes.string bytes] end
  | _=>emit id "rejected" "restore_begin_shape" []);
fun restore_material_begin id payload =
  let val Restore {required,materials,upload,total,sequence,...}=staging_transaction();
    val fields=space_explode "," payload;
    val _=F.guard(length fields=8 orelse length fields=9) "Restore material field arity";
    val association=decimal(nth fields 0); val semantic=decimal(nth fields 1);
    val origin=decimal(nth fields 2);val sizes=map(IntInf.toInt o decimal)(drop 3 fields);
    val caps=take(length sizes)[8192,1048576,1048576,16777216,100000,1048576];
    val _=F.guard(is_none(!upload) andalso is_none(AList.lookup(op =)(!materials)association) andalso
      exists(fn {association=actual,semantic_generation,...}=>actual=association andalso
        semantic_generation=semantic)required andalso origin>0 andalso origin<=sequence andalso
      ListPair.allEq (fn (size,cap)=>size>=0 andalso size<=cap)(sizes,caps) andalso
      fold(fn size=>fn used=>size+used)sizes 0<=268435456 - !total) "Restore material membership/resource bound";
    val _=total:= !total+fold(fn size=>fn used=>size+used)sizes 0;
    val _=upload:=SOME(Upload {association=association,semantic=semantic,origin=origin,sizes=sizes,
      chunks=Array.array(length sizes,[]),written=Array.array(length sizes,0)});
  in emit id "restore_material_ready" (IntInf.toString association) [] end;
fun restore_write id payload bytes =
  (case space_explode "," payload of [association_text,slot_text,offset_text]=>
    let val Restore {upload,...}=staging_transaction();
      val Upload {association,sizes,chunks,written,...}=the(!upload);
      val slot=IntInf.toInt(decimal slot_text);val offset=IntInf.toInt(decimal offset_text);
      val _=F.guard(association=decimal association_text andalso slot>=0 andalso slot<length sizes andalso
        offset=Array.sub(written,slot) andalso size bytes>0 andalso size bytes<=65536 andalso
        size bytes<=nth sizes slot-offset) "Restore material append bound";
      val _=Array.update(chunks,slot,bytes::Array.sub(chunks,slot));
      val _=Array.update(written,slot,offset+size bytes);
    in emit id "restore_written" payload [] end
  | _=>emit id "rejected" "restore_write_shape" []);
fun restore_material_end id payload =
  let val Restore {required,materials,upload,...}=staging_transaction();
    val Upload {association,semantic,origin,sizes,chunks,written}=the(!upload);
    val _=F.guard(association=decimal payload andalso
      forall(fn index=>Array.sub(written,index)=nth sizes index)(0 upto(length sizes-1)))
      "Incomplete restore material";
    val values=map(fn index=>String.concat(rev(Array.sub(chunks,index))))(0 upto(length sizes-1));
    val material={association=association,semantic_generation=semantic,manifest=nth values 0,
      projection=nth values 1,sequent=nth values 2,context_closure=nth values 3,reconstruction=nth values 4,
      executable=if length values=6 then SOME(nth values 5)else NONE,dependencies=[]}:recovery_material;
    val envelope=Veri7vn_Recovery_Manifest.decode {max_bytes=8192}(#manifest material);
    val expected= #role(the(find_first(fn {association=actual,...}=>actual=association)required));
    val profile=(case expected of F.KernelRole=>Veri7vn_Recovery_Manifest.KernelEvidence
      | F.MathRequestRole=>Veri7vn_Recovery_Manifest.MathRequest | F.MathOutputRole=>Veri7vn_Recovery_Manifest.MathOutput);
    val _=Veri7vn_Recovery_Manifest.require_profile profile envelope;
    val _=F.guard(#association envelope=association andalso #semantic_generation envelope=semantic)
      "Restore material differs from latest checkpoint role";
    val _=materials:=AList.update(op =)(association,(origin,material))(!materials);
    val _=upload:=NONE;
  in emit id "restore_material_staged" payload [] end;
fun as_math_material(m:recovery_material):MathRecovery.material=
  {association= #association m,semantic_generation= #semantic_generation m,manifest= #manifest m,
    projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
    reconstruction= #reconstruction m,executable=the(#executable m)};
fun restore_run (transaction as Restore {workspace,sequence,checkpoint,required,materials,upload,active,completed,...}) =
  let
    val _=F.guard(is_none(!upload) andalso length(!materials)=length required)
      "Incomplete native restore transaction";
    val metadata=the(F.decode_state checkpoint);
    val input_pool=RecoveryInputs.create(identity_allocator());
    val kernel_batch=V.restore_batch_with input_pool;val math_batch=MathRecovery.begin_batch_with input_pool;
    val rebuilt_descriptors=Unsynchronized.ref([]:D.descriptor list);
    val rebuilt_requests=Unsynchronized.ref([]:math_entry list);
    val rebuilt_outputs=Unsynchronized.ref([]:MathGate.witness list);
    val committed=Unsynchronized.ref([]:Veri7vn_Committed_Native_Recovery.committed list);
    val canonical_install_attempted=Unsynchronized.ref false;
    val retained_workspace=Unsynchronized.ref(NONE:MathRecovery.workspace_owner option);
    fun material_for association=the(AList.lookup(op =)(!materials)association);
    fun select role=filter(fn {role=actual,...}=>actual=role)required;
    fun run()=
      let
        val kernel=map(fn {association,...}=>
          let val (origin,m)=material_for association;
            val token=Veri7vn_Committed_Native_Recovery.install_committed_host
              {workspace=workspace,journal_sequence=origin,association=association,
                semantic_generation= #semantic_generation m,checkpoint=checkpoint,manifest= #manifest m,
                projection= #projection m,sequent= #sequent m,context_closure= #context_closure m,
                reconstruction= #reconstruction m};
            val _=committed:=token::(!committed)
          in V.recheck_in kernel_batch (identity_allocator()) (boot_image()) token end)(select F.KernelRole);
        val math_ids=map #semantic_generation(select F.MathRequestRole);
        val _=List.app(fn semantic=>ignore(exists(fn verified=>
          MathRecovery.supply_generation_for math_batch boot_policy verified semantic)kernel))math_ids;
        val requests=map(fn {association,...}=>MathRecovery.verify_request math_batch (identity_allocator())
          boot_policy (boot_image()) (boot_bytes()) (as_math_material(#2(material_for association))))
          (select F.MathRequestRole);
        val sealed=V.seal_batch kernel_batch;
        val _=Thread_Attributes.uninterruptible(fn _=>fn()=>
          (canonical_install_attempted:=true;
           I.install_fragments(identity_allocator())(V.fragment sealed::map MathRecovery.fragment requests)))();
        val descriptors=map(fn verified=>let val descriptor=D.restore(identity_allocator())verified;
          val _=rebuilt_descriptors:=descriptor::(!rebuilt_descriptors) in descriptor end)kernel;
        val entries=map(fn verified=>
          let val {request,bridge}=MathRecovery.restore_request(identity_allocator())verified;
            val rid= #request_id(Request.project request);
            val cost=(case Mathematics.modeled_cost(Request.family_request request) of Mathematics.Ready n=>n
              | _=>error "Restored native cost unavailable");
            val executions=F.execution_ids metadata rid;
            val _=F.guard(length executions<=1) "Multiple charged executions for fixed native request";
            val entry=MathEntry {request=request,input=Request.input_owner request,bridge=bridge,
              execution=(case executions of [execution]=>execution | _=>I.allocate(identity_allocator())),
              cost=cost,dependencies=Request.managed_dependencies request @ Display.managed_dependencies bridge,
              observed=Synchronized.var "restored_request_observed_dependencies" executions,
              active=Synchronized.var "restored_request_active" (not(F.request_cancelled metadata rid)),
              released=Synchronized.var "restored_request_released" false,
              job=Synchronized.var "restored_request_job" NONE,
              monitor=Synchronized.var "restored_request_monitor" NONE,witness=Synchronized.var "restored_request_output" NONE,
              failure=Synchronized.var "restored_request_interrupted" (SOME "execution.interrupted")};
            val _=rebuilt_requests:=entry::(!rebuilt_requests)
          in entry end)requests;
        val outputs=map(fn {association,...}=>
          let val m=as_math_material(#2(material_for association));
            val original=MathRecovery.output_request m;
            val entry as MathEntry {witness=root,failure,observed,...}=the(find_first(fn entry=>request_id entry=original)entries);
            val witness=MathRecovery.restore_output(identity_allocator()) (boot_image()) (boot_bytes())
              (entry_bridge entry) (entry_request entry) m;
            val _=rebuilt_outputs:=witness::(!rebuilt_outputs);
            val _=Synchronized.change root(K(SOME witness));
            val _=Synchronized.change observed(K(MathGate.managed_dependencies witness));
            val _=Synchronized.change failure(K NONE)
          in (entry,witness) end)(select F.MathOutputRole);
        val gates=map Admitted descriptors @ map RestoredMath entries @ map RestoredOutput outputs;
        val workspace_owner=MathRecovery.close_batch math_batch;
        val _=retained_workspace:=SOME workspace_owner;
        val _=RecoveryInputs.close input_pool;
        val _=serialized(fn()=>Thread_Attributes.uninterruptible(fn _=>fn()=>
          (F.guard(Synchronized.value active) "Native restore was cancelled";
           F.guard(Owner.restore_complete checkpoint gates) "Native complete association restore refused";
           Synchronized.change associations(K(map(fn d=>(D.evidence_id d,d))descriptors));
           Synchronized.change math_requests(K(map(fn e=>(request_id e,e))entries));
           Synchronized.change durable_sequence(K sequence);
           Synchronized.change math_workspace_owners(cons workspace_owner);
           List.app Veri7vn_Committed_Native_Recovery.release (!committed);
           Synchronized.change completed(K true)))());
      in () end;
    val result=Exn.capture run();
  in case result of Exn.Res()=>() | Exn.Exn failure=>
    ((if !canonical_install_attempted then Synchronized.change native_poisoned(K true) else ());
     List.app MathGate.release(!rebuilt_outputs);List.app release_entry(!rebuilt_requests);
     MathRecovery.abort_batch math_batch;
     (case !retained_workspace of NONE=>() | SOME owner=>MathRecovery.release_workspace owner);
     List.app D.release(!rebuilt_descriptors);V.abort_batch kernel_batch;
     RecoveryInputs.abort input_pool;
     List.app Veri7vn_Committed_Native_Recovery.release(!committed);
     Exn.reraise failure) end;
fun restore_finish id =
  let val transaction as Restore {task,active,...}=restore_transaction();
    val _=F.guard(is_none(Synchronized.value task) andalso Synchronized.value active) "Native restore already verifying";
    val _=Thread_Attributes.uninterruptible(fn _=>fn()=>
      let val future=Future.fork(fn()=>restore_run transaction)
      in Synchronized.change task(K(SOME future)) end)();
  in emit id "restore_verifying" "" [] end;
fun restore_progress id =
  let val Restore {task,completed,...}=restore_transaction()
  in case Synchronized.value task of NONE=>emit id "restore_staging" "" []
  | SOME future=>(case Future.peek future of NONE=>emit id "restore_verifying" "" []
    | SOME _=>if Synchronized.value completed then
        (Synchronized.change restoring(K NONE);emit id "restored" "complete_no_dispatch_replay" [])
      else (Synchronized.change restoring(K NONE);emit id "restore_failed" "native_association_recheck_failed" [])) end;
fun restore_abort id =
  let val Restore {task,active,completed,...}=restore_transaction();
    val _=F.guard(not(Synchronized.value completed)) "Native restore already committed";
    val _=Synchronized.change active(K false)
  in case Synchronized.value task of NONE=>(Synchronized.change restoring(K NONE);emit id "restore_aborted" "" [])
    | SOME future=>(Future.cancel future;emit id "restore_aborting" "" []) end;

fun issue_admitted descriptor =
  let val material=kernel_material descriptor
    (Veri7vn_Native_Recovery_Export.export(identity_allocator()) (boot_image()) descriptor)
  in serialized(fn()=>issue_gate (Admitted descriptor) (SOME material)) end;
fun release_admitted descriptor=serialized(fn()=>
  let val evidence=D.evidence_id descriptor;
    val _=D.release descriptor;
    val _=Synchronized.change tokens(filter(fn (_, (Admitted d,_))=>D.evidence_id d<>evidence | _=>true));
    val _=Synchronized.change associations(AList.delete(op =) evidence);
    val _=Synchronized.change pending(K NONE);
  in Owner.invalidate() end);
fun handle_command args =
  if length args<4 orelse length args>5 orelse fold(fn b=>fn n=>Bytes.size b+n) args 0>2200000
  then emit "0" "rejected" "frame_bound" [] else
  let val controls=map Bytes.content(take 4 args); val body=drop 4 args
  in case controls of ["1",id,operation,payload]=>
    if not(valid_id id) orelse size payload>512 then emit "0" "rejected" "control_bound" [] else
    if Synchronized.value native_poisoned andalso not(member(op =)
      ["status","restore_progress","cleanup_status","cleanup_barrier"]operation)
    then emit id "rejected" "native_incarnation_poisoned_restart_required" [] else
    if is_some(Synchronized.value restoring) andalso not(member(op =)
      ["status","restore_material_begin","restore_write","restore_material_end","restore_finish","restore_progress","restore_abort"]operation)
    then emit id "rejected" "native_recovery_in_progress" [] else
    (case (operation,body) of
      ("install_boot",[manifest])=>(install_boot(Bytes.content manifest);
        emit id "boot_installed" (Value.print_int(PolyML.ml_pid())) [])
    | ("install_ids",[])=>(install_ids payload;emit id "ids_installed" "" [])
    | ("status",[])=>if Synchronized.value native_poisoned
      then emit id "unavailable" "native_incarnation_poisoned_restart_required" []
      else emit id "ready" "resident_fixed_mathematics;typed_staged_recovery" []
    | ("initial",[])=>emit id "initial" "0,0" [Bytes.string(Owner.initial_frame())]
    | ("propose_math",[bytes])=>propose_math id payload (Bytes.content bytes)
    | ("poll_result",[])=>poll_result id payload
    | ("inspect_request",[])=>inspect_request id payload
    | ("inspect_routing",[bytes])=>inspect_routing id payload (Bytes.content bytes)
    | ("cancel",[])=>lifecycle id operation payload
    | ("forget",[])=>lifecycle id operation payload
    | ("revoke",[])=>lifecycle id operation payload
    | ("retire_capability",[])=>lifecycle id operation payload
    | ("prepare",[])=>prepare id payload
    | ("command_info",[])=>command_info id payload
    | ("recovery_info",[])=>recovery_info id payload
    | ("recovery_read",[])=>recovery_read id payload
    | ("recovery_dependencies",[])=>recovery_dependencies id payload
    | ("artifact_invalidations",[])=>artifact_invalidations id payload
    | ("cleanup_status",[])=>cleanup_status id payload false
    | ("cleanup_barrier",[])=>cleanup_barrier id
    | ("retry_cleanup",[])=>if payload="" then retry_all_cleanups id else cleanup_status id payload true
    | ("restore_begin",[checkpoint])=>restore_begin id payload (Bytes.content checkpoint)
    | ("restore_material_begin",[])=>restore_material_begin id payload
    | ("restore_write",[bytes])=>restore_write id payload (Bytes.content bytes)
    | ("restore_material_end",[])=>restore_material_end id payload
    | ("restore_finish",[])=>restore_finish id
    | ("restore_progress",[])=>restore_progress id
    | ("restore_abort",[])=>restore_abort id
    | ("validate",[])=>emit id (if validate payload then "valid" else "rejected") payload []
    | ("ack",[])=>acknowledge id payload
    | ("restore",[checkpoint])=>if Owner.restore_initial(Bytes.content checkpoint)
      then (Synchronized.change pending(K NONE);Synchronized.change tokens(K []);
        Synchronized.change durable_sequence(K(if payload="" then 1 else decimal payload));
        emit id "restored" "initial" [])
      else emit id "unavailable" "protected_native_association_reconstruction_required" []
    | _=>emit id "rejected" "operation_or_shape" [])
  | _=>emit "0" "rejected" "version_or_shape" [] end;
(* Protocol callbacks run on Isabelle's input reader. Native hashing and other
   Scala functions await Scala.result commands on that same reader, so executing
   a proposal in the callback deadlocks it. The reader only validates/registers
   bounded message ownership. One finite worker drains FIFO messages through the
   existing coordinator; it never introduces another authority state. *)
val rpc_max_items=64;
val rpc_max_bytes=16777216;
type rpc_message={id:string,args:Bytes.T list,bytes:int};
type rpc_state={pending:rpc_message list,active:rpc_message option,bytes:int,
  generation:serial option,worker:unit Future.future option};
val rpc_empty={pending=[],active=NONE,bytes=0,generation=NONE,worker=NONE}:rpc_state;
val rpc_queue=Synchronized.var "veri7vn_owned_native_rpc_queue"
  rpc_empty;
val rpc_operations=["install_boot","install_ids","status","initial","propose_math","poll_result","inspect_request","inspect_routing",
  "cancel","forget","revoke","retire_capability","prepare","command_info","recovery_info",
  "recovery_read","recovery_dependencies","artifact_invalidations","cleanup_status","cleanup_barrier",
  "retry_cleanup","restore_begin","restore_material_begin","restore_write","restore_material_end",
  "restore_finish","restore_progress","restore_abort","validate","ack","restore"];
fun rpc_id args=(case args of version::id::_=>
  if Bytes.size version=1 andalso Bytes.size id<=18 andalso Bytes.content version="1"
    andalso valid_id(Bytes.content id) then Bytes.content id else "0" | _=>"0");
fun rpc_dispatch({id,args,...}:rpc_message)=
  (case Exn.capture(fn()=>serialized(fn()=>handle_command args))() of Exn.Res()=>()
  | Exn.Exn exn=>if Exn.is_interrupt exn then Exn.reraise exn
      else emit id "rejected" "native_transition_failure" []);
fun rpc_pop owner (state as {pending,active,bytes,generation,worker}:rpc_state)=
  if generation<>SOME owner then (NONE,state) else
  (F.guard(is_none active) "Native RPC worker ownership overlap";
   case pending of []=>(NONE,rpc_empty)
   | message::rest=>(SOME message,{pending=rest,active=SOME message,bytes=bytes,
       generation=generation,worker=worker}));
fun rpc_take owner=Synchronized.change_result rpc_queue(rpc_pop owner);
fun rpc_completed owner ({id,bytes=count,...}:rpc_message)
    ({pending,active,bytes,generation,worker}:rpc_state)=
    (F.guard(generation=SOME owner andalso
      (case active of SOME actual=> #id actual=id | NONE=>false))
      "Native RPC message ownership changed";
     {pending=pending,active=NONE,bytes=bytes-count,generation=generation,worker=worker}:rpc_state);
fun rpc_release owner message=Synchronized.change rpc_queue(rpc_completed owner message);
fun rpc_detach owner (state as {pending,active,generation,...}:rpc_state)=
  if generation<>SOME owner then (NONE,state)
  else (SOME(the_list active @ pending),rpc_empty);
fun rpc_fits count ({pending,active,bytes,...}:rpc_state)=
  length pending+(if is_some active then 1 else 0)<rpc_max_items andalso
  count<=rpc_max_bytes-bytes;
fun rpc_abort owner exn = Thread_Attributes.uninterruptible(fn _=>fn()=>
  let
    val abandoned=Synchronized.change_result rpc_queue(fn state=>
      let val (detached,next)=rpc_detach owner state;
        val _=if is_some detached then Synchronized.change native_poisoned(K true) else ();
      in (detached,next) end);
    val _=List.app(fn {id,...}=>ignore(Exn.capture
      (fn()=>emit id "rejected" "native_rpc_worker_failed" [])()))(the_default [] abandoned);
    val _=if is_none abandoned then () else ignore(Exn.capture(fn()=>Output.system_message
      (if Exn.is_interrupt exn then "veri7vn resident RPC worker interrupted; restart required"
       else "veri7vn resident RPC worker failed; restart required"))());
  in () end)();
fun rpc_drain owner () =
  let
    fun advance()=Thread_Attributes.uninterruptible(fn restore=>fn()=>
      (case rpc_take owner of NONE=>false
      | SOME message=>
          let val result=Exn.capture(restore(fn()=>rpc_dispatch message))();
          in case result of Exn.Res()=>(rpc_release owner message;true)
            | Exn.Exn exn=>(rpc_abort owner exn;false) end))();
    fun loop()=if advance() then loop() else ();
  in case Exn.capture loop() of Exn.Res()=>() | Exn.Exn exn=>rpc_abort owner exn end;
fun rpc_enqueue args = Thread_Attributes.uninterruptible(fn _=>fn()=>
  let
    val id=rpc_id args;
    val shape=(case args of [_,_,_,_]=>true | [_,_,_,_,_]=>true | _=>false);
    fun add value NONE=NONE | add value (SOME total)=
      if Bytes.size value>2200000-total then NONE else SOME(total+Bytes.size value);
    val bounded=if shape then fold add args(SOME 0) else NONE;
    val headers=shape andalso (case args of version::request::operation::payload::_=>
      Bytes.size version<=1 andalso Bytes.size request<=18 andalso Bytes.size operation<=64
      andalso Bytes.size payload<=512 | _=>false);
    val controls=if headers then map Bytes.content(take 4 args) else [];
    val bytes=the_default 0 bounded;
    val valid=headers andalso is_some bounded andalso
      (case controls of ["1",actual,operation,payload]=>valid_id actual andalso
        size payload<=512 andalso member(op =)rpc_operations operation | _=>false);
    val attempt=Exn.capture(fn()=>if not valid then false else
      Synchronized.change_result rpc_queue(fn state as {pending,active,bytes=owned,generation,worker}=>
        if not(rpc_fits bytes state) orelse
          exists(fn message=> #id message=id)(the_list active @ pending) then (false,state)
        else
          let
            val message={id=id,args=args,bytes=bytes}:rpc_message;
            (* Fork while the registered queue ownership is locked: the task
               cannot pop its first message before its Future root is installed. *)
            val owner=case generation of SOME current=>current | NONE=>serial();
            val task=case worker of SOME previous=>previous | NONE=>Future.fork(rpc_drain owner);
          in (true,{pending=pending@[message],active=active,bytes=owned+bytes,
            generation=SOME owner,worker=SOME task}) end))();
  in case attempt of Exn.Res true=>() | Exn.Res false=>emit id "rejected"
      (if valid then "native_rpc_queue_limit" else "operation_or_frame_bound") []
    | Exn.Exn _=>emit id "rejected" "native_rpc_worker_unavailable" [] end)();
val _=Protocol_Command.define_bytes "veri7vn_service_v1" rpc_enqueue;
structure Test_Only =
struct
  datatype fault=datatype Proposal_Test_Only.fault;
  val check_proposal_cleanup=Proposal_Test_Only.check_proposal_cleanup;
  fun check_pending_alias_cleanup()=
    let
      val (target,entries)=serialized(fn()=>
        let val _=F.guard(null(Synchronized.value math_requests) andalso null(Synchronized.value tokens)
            andalso is_none(Synchronized.value pending)) "Pending alias diagnostic requires unused resident";
          val version=Owner.current_version();
          val _=propose_math "0" "" "the sum of -2 and 3";
          val _=propose_math "0" "" "the sum of 4 and 5";
          val entries=map snd(Synchronized.value math_requests);
          val _=F.guard(length entries=2) "Pending alias diagnostic did not elaborate both originals";
          val target=request_id(hd entries);
          val bridge=Display.project_bridge(entry_bridge(hd entries));
          val removed=[#bridge_id bridge,#statement_code_id bridge];
          val _=cleanup_action (F.Forget target) (F.Forgotten removed);
          val _=F.guard(forall(fn entry=>not(entry_live entry))entries andalso
            null(Synchronized.value tokens) andalso Owner.current_version()=version)
            "Invalidated undurable alias retained a usable gate or original recovery material"
        in (target,entries)end);
      val jobs=map snd(filter(fn(actual,_)=>actual=target)(Synchronized.value cleanups));
      val _=List.app(fn Cleanup {task,...}=>Option.app(fn future=>
        Exn.release(Future.join_result future))(Synchronized.value task))jobs;
      val _=serialized(fn()=>
        (F.guard(forall(fn MathEntry {request,input,released,...}=>
          Synchronized.value released andalso not(Request.live request) andalso not(Literals.retained input))entries)
          "Undurable alias retained actual request/input roots after draining";
         Synchronized.change math_requests(filter(fn(_,entry)=>not(exists(fn removed=>
           request_id removed=request_id entry)entries)))))
    in writeln "Native undurable alias token/material and input cleanup checks passed" end;
  fun check_cleanup_ownership()=
    let
      val attempts=Synchronized.var "cleanup_fixture_attempts" 0;
      fun job work=Cleanup {release=Synchronized.var "cleanup_fixture_roots" (SOME work),
        task=Synchronized.var "cleanup_fixture_task" NONE};
      fun join(Cleanup {task,...})=Option.app(fn future=>ignore(Future.join_result future))(Synchronized.value task);
      val first=job(fn()=>if Synchronized.change_result attempts(fn n=>(n,n+1))=0
        then error "fixed cleanup retry fixture" else ());
      val second=job(fn()=>());
      val _=start_cleanup first;
      val _=join first;
      val _=F.guard(cleanup_state first=2) "Failed cleanup lost retry ownership";
      val intents=retain_cleanup 1 second (retain_cleanup 1 first []);
      val _=F.guard(length intents=2) "Later same-target cleanup replaced captured roots";
      val _=start_cleanup second;
      val _=join second;
      val _=F.guard(length(pending_cleanups intents)=1 andalso cleanup_state first=2)
        "Completed later cleanup discarded failed earlier roots";
      val _=start_cleanup first;
      val _=join first;
      val _=F.guard(null(pending_cleanups intents) andalso Synchronized.value attempts=2)
        "Cleanup retry did not discharge every retained same-target intent";
      val _=List.app(fn(_,Cleanup {release,...})=>F.guard(is_none(Synchronized.value release))
        "Successful cleanup retained captured work closure")intents
    in writeln "Native same-target cleanup ownership/retry checks passed" end;
  fun check_rpc_ownership()=
    let
      val old=serial(); val fresh=serial();
      fun message id={id=id,args=map Bytes.string["1",id,"status",""],bytes=7+size id}:rpc_message;
      val first=message "11";val second=message "12";
      val root=Future.value();
      val initial={pending=[first,second],active=NONE,bytes= #bytes first+ #bytes second,
        generation=SOME old,worker=SOME root}:rpc_state;
      val (taken,active)=rpc_pop old initial;
      val _=F.guard(map #id(the_list taken)=["11"] andalso map #id(#pending active)=["12"]
        andalso #bytes active= #bytes initial) "RPC FIFO or active byte charge changed";
      val released=rpc_completed old first active;
      val (next,active2)=rpc_pop old released;
      val _=F.guard(map #id(the_list next)=["12"] andalso #bytes released= #bytes second)
        "RPC active ownership was not released before next message";
      val (_,drained)=rpc_pop old(rpc_completed old second active2);
      val _=F.guard(is_none(#generation drained) andalso is_none(#worker drained) andalso #bytes drained=0)
        "RPC drain did not atomically release its generation, worker and bytes";
      val successor={pending=[first],active=NONE,bytes= #bytes first,
        generation=SOME fresh,worker=SOME root}:rpc_state;
      val (stale,kept)=rpc_detach old successor;
      val _=F.guard(is_none stale andalso #generation kept=SOME fresh andalso
        #bytes kept= #bytes first andalso map #id(#pending kept)=["11"] andalso
        (case #worker kept of SOME actual=>Task_Queue.eq_task(Future.task_of actual,Future.task_of root)
        | NONE=>false)) "A finishing RPC burst cleared its successor's roots";
      val (failed,empty)=rpc_detach fresh successor;
      val _=F.guard(map #id(the_default [] failed)=["11"] andalso #bytes empty=0 andalso
        is_none(#worker empty) andalso is_none(#generation empty)) "Failed RPC burst retained private roots";
      val waiting=map(message o Value.print_int)(100 upto(100+rpc_max_items-2));
      val full={pending=waiting,active=SOME second,
        bytes=fold(fn item=>fn n=> #bytes item+n)waiting(#bytes second),
        generation=SOME old,worker=SOME root}:rpc_state;
      val _=F.guard(not(rpc_fits 1 full)) "RPC item bound excluded active ownership";
      val _=F.guard(rpc_fits(rpc_max_bytes- #bytes successor)successor andalso
        not(rpc_fits(rpc_max_bytes- #bytes successor+1)successor)) "RPC aggregate byte boundary changed";
    in () end;
end;
end;
