(* Instantiate this functor once in the FINAL PRIVATE native assembly. Export only
   restricted consume views to family functors. The owner view, issuer and scope
   constructors must remain lexical-private to the single actual state owner.
   Tickets represent already durably charged generated commands, never proofs. *)
signature VERI7VN_OPERATION_TICKET_VIEW =
sig
  type operation_identity =
    {workspace: string, request: IntInf.int, profile: IntInf.int,
     code_generation: IntInf.int, operation: IntInf.int, step: IntInf.int,
     cost: IntInf.int, inputs: IntInf.int list, owner_version: IntInf.int,
     epoch: IntInf.int, journal_sequence: IntInf.int, semantic_generation: IntInf.int,
     implementation_artifact: string}
  type execution_identity =
    {execution: IntInf.int, slot: IntInf.int, operation: operation_identity}
  type acquisition_identity =
    {attempt: IntInf.int, slot: IntInf.int, source_binding: IntInf.int,
     capability: IntInf.int, target: IntInf.int, sources: IntInf.int list,
     dependencies: IntInf.int list, protocol: string, receipt: string,
     operation: operation_identity}
  datatype retention_destination = RequestDestination of IntInf.int |
    SessionDestination of IntInf.int | WorkspaceDestination
  type retention_identity =
    {workspace:string,request:IntInf.int,grant:IntInf.int,object_id:IntInf.int,
     destination:retention_destination,owner_version:IntInf.int,epoch:IntInf.int,
     journal_sequence:IntInf.int}
  type 'a pure_ticket
  type 'a acquisition_ticket
  type 'a retention_ticket
  val consume_pure: 'a pure_ticket -> execution_identity * 'a
  val consume_acquisition: 'a acquisition_ticket -> acquisition_identity * 'a
  val consume_retention: 'a retention_ticket -> retention_identity * 'a
end;

signature VERI7VN_OPERATION_TICKET_OWNER =
sig
  include VERI7VN_OPERATION_TICKET_VIEW
  type issuer
  type scope
  val new_issuer: unit -> issuer
  val begin_scope: issuer -> {owner_version: IntInf.int, epoch: IntInf.int} -> scope
  val close_scope: scope -> unit
  (* Only the actual state owner may call these after exact generated-command
     persistence/acknowledgement and native association validation. Payloads are
     actual typed native objects, not an ID resolver or acceptance callback. *)
  val issue_pure: scope -> execution_identity -> 'a -> 'a pure_ticket
  val issue_acquisition: scope -> acquisition_identity -> 'a -> 'a acquisition_ticket
  val issue_retention: scope -> retention_identity -> 'a -> 'a retention_ticket
end;

functor Veri7vn_Private_Operation_Tickets () :> VERI7VN_OPERATION_TICKET_OWNER =
struct
  type operation_identity =
    {workspace: string, request: IntInf.int, profile: IntInf.int,
     code_generation: IntInf.int, operation: IntInf.int, step: IntInf.int,
     cost: IntInf.int, inputs: IntInf.int list, owner_version: IntInf.int,
     epoch: IntInf.int, journal_sequence: IntInf.int, semantic_generation: IntInf.int,
     implementation_artifact: string};
  type execution_identity =
    {execution: IntInf.int, slot: IntInf.int, operation: operation_identity};
  type acquisition_identity =
    {attempt: IntInf.int, slot: IntInf.int, source_binding: IntInf.int,
     capability: IntInf.int, target: IntInf.int, sources: IntInf.int list,
     dependencies: IntInf.int list, protocol: string, receipt: string,
     operation: operation_identity};
  datatype retention_destination = RequestDestination of IntInf.int |
    SessionDestination of IntInf.int | WorkspaceDestination;
  type retention_identity =
    {workspace:string,request:IntInf.int,grant:IntInf.int,object_id:IntInf.int,
     destination:retention_destination,owner_version:IntInf.int,epoch:IntInf.int,
     journal_sequence:IntInf.int};
  datatype issuer = Issuer of {identity: serial, active: bool Synchronized.var};
  type scope_state = {open_scope: bool, cleanup: (unit -> unit) list};
  datatype scope = Scope of {issuer: serial, owner_version: IntInf.int,
    epoch: IntInf.int, state: scope_state Synchronized.var,
    release_owner: bool Synchronized.var};
  datatype 'a pure_ticket = Pure of scope * execution_identity * 'a option Unsynchronized.ref;
  datatype 'a acquisition_ticket = Acquisition of scope * acquisition_identity * 'a option Unsynchronized.ref;
  datatype 'a retention_ticket = Retention of scope * retention_identity * 'a option Unsynchronized.ref;
  fun require true _ = () | require false message = error message;
  fun natural n = n >= 0 andalso size (IntInf.toString n) <= 128;
  fun naturals ns = length ns <= 8192 andalso forall natural ns;
  fun new_issuer () = Issuer {identity=serial (),active=Synchronized.var "veri7vn_ticket_owner" false};
  fun begin_scope (Issuer {identity,active}) {owner_version,epoch} =
    let
      val _=require (natural owner_version andalso natural epoch) "operation owner identity bound";
      val _=Synchronized.change active (fn running =>
        (require (not running) "operation issuer scope already open"; true));
    in Scope {issuer=identity,owner_version=owner_version,epoch=epoch,
      state=Synchronized.var "veri7vn_ticket_scope" {open_scope=true,cleanup=[]},release_owner=active} end;
  fun close_scope (Scope {state,release_owner,...}) =
    let val first=Synchronized.change_result state (fn {open_scope,cleanup} =>
      (List.app (fn release => release ()) cleanup; (open_scope,{open_scope=false,cleanup=[]})))
    in if first then Synchronized.change release_owner (K false) else () end;
  fun check_identity (Scope {owner_version,epoch,...}) (identity:operation_identity) =
    (require (#owner_version identity=owner_version andalso #epoch identity=epoch)
       "operation ticket owner/version mismatch";
     require (size (#workspace identity)>0 andalso size (#workspace identity)<=128 andalso
       forall natural [#request identity,#profile identity,
         #code_generation identity,#operation identity,#step identity,#cost identity,
         #journal_sequence identity,#semantic_generation identity] andalso
       #cost identity>0 andalso naturals (#inputs identity) andalso
       size (#implementation_artifact identity)=64 andalso
       forall (fn c => Char.isDigit c orelse (#"a" <= c andalso c <= #"f"))
         (String.explode (#implementation_artifact identity))) "operation ticket identity bound");
  fun in_scope (Scope {state,...}) f = Synchronized.change_result state
    (fn st as {open_scope,...} => (require open_scope "operation ticket scope closed"; f st));
  fun issue_pure scope identity payload =
    let
      val _=check_identity scope (#operation (identity:execution_identity));
      val _=require (natural (#execution identity) andalso natural (#slot identity)) "pure ticket identity bound";
      val root=Unsynchronized.ref (SOME payload);
    in in_scope scope (fn {open_scope,cleanup} =>
      (Pure (scope,identity,root),{open_scope=open_scope,cleanup=(fn () => root:=NONE)::cleanup})) end;
  fun issue_acquisition scope (identity:acquisition_identity) payload =
    let
      val _=check_identity scope (#operation identity);
      val _=require (forall natural [#attempt identity,#slot identity,#source_binding identity,#capability identity,#target identity] andalso
        naturals (#sources identity) andalso naturals (#dependencies identity) andalso
        size (#protocol identity)>0 andalso size (#protocol identity)<=256 andalso
        size (#receipt identity)>0 andalso size (#receipt identity)<=1024) "acquisition ticket identity bound";
      val root=Unsynchronized.ref (SOME payload);
    in in_scope scope (fn {open_scope,cleanup} =>
      (Acquisition (scope,identity,root),{open_scope=open_scope,cleanup=(fn () => root:=NONE)::cleanup})) end;
  fun issue_retention scope (identity:retention_identity) payload =
    let
      val Scope {owner_version,epoch,...}=scope;
      val _=require (#owner_version identity=owner_version andalso #epoch identity=epoch)
        "retention ticket owner/version mismatch";
      val _=require (size (#workspace identity)>0 andalso size (#workspace identity)<=128 andalso
        forall natural [#request identity,#grant identity,#object_id identity,#journal_sequence identity] andalso
        (case #destination identity of RequestDestination n=>natural n |
          SessionDestination n=>natural n | WorkspaceDestination=>true)) "retention ticket identity bound";
      val root=Unsynchronized.ref (SOME payload);
    in in_scope scope (fn {open_scope,cleanup}=>
      (Retention (scope,identity,root),{open_scope=open_scope,cleanup=(fn()=>root:=NONE)::cleanup})) end;
  fun consume_pure (Pure (scope,identity,root)) =
    in_scope scope (fn st =>
      (case !root of NONE => error "operation ticket already consumed"
      | SOME payload => (root:=NONE; ((identity,payload),st))));
  fun consume_acquisition (Acquisition (scope,identity,root)) =
    in_scope scope (fn st =>
      (case !root of NONE => error "acquisition ticket already consumed"
      | SOME payload => (root:=NONE; ((identity,payload),st))));
  fun consume_retention (Retention (scope,identity,root)) =
    in_scope scope (fn st=>
      (case !root of NONE=>error "retention ticket already consumed"
      | SOME payload=>(root:=NONE;((identity,payload),st))));
end;
