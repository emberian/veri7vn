(* Fixed adapter: durable metadata is derived from owned builder handles, never
   supplied by a decoded request or reconstructed from candidate result names. *)
functor Veri7vn_Native_Build_Recovery
  (structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
     where type export_intent=Veri7vn_Native_Export_Intent.intent
   structure Recovery:sig
     type configuration
     type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string}
     val qualify_candidate:configuration -> Veri7vn_Native_Identity_Allocator.allocator ->
       Veri7vn_Native_Development_Codec.metadata ->
       {development:Veri7vn_Managed_Provenance.development,
        exports:Veri7vn_Managed_Provenance.consequence list,
        original_intent:Veri7vn_Native_Export_Intent.intent,
        parents:(IntInf.int option*string*Veri7vn_Managed_Provenance.development)list} -> artifacts
     val qualify_request:configuration -> Veri7vn_Native_Identity_Allocator.allocator ->
       Veri7vn_Native_Development_Codec.metadata ->
       {source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
        exports:Thm_Name.T list,original_intent:Veri7vn_Native_Export_Intent.intent,
        control:Veri7vn_Native_Deferred_Build_Types.plan,
        phase:Veri7vn_Native_Build_Request_Envelope.phase,
        parents:(IntInf.int option*string*Veri7vn_Managed_Provenance.development)list} -> artifacts
   end) =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Intent=Veri7vn_Native_Export_Intent;
  type plan={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,execution:IntInf.int,
    semantic_generation:IntInf.int,input_bindings:IntInf.int list};
  fun metadata (projection:Builder.projection) (plan:plan) recipe intent semantic_generation =
    let val original=Intent.binding intent
      val descriptor=L.offsets(#slice original)
    in {workspace=P.source_workspace(#source(recipe:P.replay_recipe)),
      template= #template projection,source_owner= #source_owner projection,
      source_revision= #source_revision projection,manifest= #manifest projection,
      parents= #parents projection,profile= #profile projection,setup= #setup projection,
      export_intent= #export_intent projection,candidate= #candidate projection,
      lineage= #execution plan,request= #request plan,goal= #goal plan,slot= #slot plan,
      charged_generation= #semantic_generation plan,semantic_generation=semantic_generation,
      input_bindings= #input_bindings plan,dependencies= #dependencies projection,
      descriptor_source=P.source_identity(#source original),
      descriptor_start= #start descriptor,descriptor_stop= #stop descriptor}:
      Veri7vn_Native_Development_Codec.metadata end;
  fun candidate configuration allocator candidate=
    let val development=Builder.development candidate
      val generation=case I.lookup_generation_id allocator(P.generation development)of
        SOME id=>id | NONE=>error "Candidate native generation is not bound to the durable allocator"
      val intent=Builder.original_intent candidate
      val m=metadata(Builder.projection candidate)(Builder.execution_plan candidate)
        (Builder.recipe candidate)intent generation
    in Recovery.qualify_candidate configuration allocator m{development=development,
      exports=Builder.exports candidate,original_intent=intent,
      parents=Builder.parent_bindings candidate}end;
  fun request configuration allocator {control,phase} prepared=
    let val recipe=Builder.prepared_recipe prepared
      val plan=Builder.prepared_plan prepared
      val intent=Builder.prepared_original_intent prepared
      val m=metadata(Builder.prepared_projection prepared)plan recipe intent(#semantic_generation plan)
    in Recovery.qualify_request configuration allocator m{source= #source recipe,slice= #slice recipe,
      exports=Builder.prepared_exports prepared,original_intent=intent,control=control,phase=phase,
      parents=Builder.prepared_parents prepared}end;
end;

(* A pending request restoration retains inputs only. It never replays its target
   or issues a ticket; the current generated-state owner must still authorize it. *)
functor Veri7vn_Native_Build_Request_Restore
  (structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Request:VERI7VN_CHECKED_BUILD_REQUEST_VIEW
     where type export_intent=Builder.export_intent
       and type checked_request=Builder.checked_request) :>
sig
  type restored
  val restore:Builder.installation -> Request.checked_request -> restored
  val prepared:restored -> Builder.prepared
  val binding:restored -> Request.binding
  val phase:restored -> Request.phase
  val control_plan:restored -> Request.control_plan option
  val is_live:restored -> bool
  val release:restored -> unit
end =
struct
  structure E=Veri7vn_Executable_Identity;
  datatype restored=Restored of {prepared:Builder.prepared,witness:Request.checked_request,
    active:bool Synchronized.var};
  fun require true _=()|require false text=error text;
  fun is_live(Restored{prepared,witness,active})=Synchronized.value active andalso
    Request.is_live witness andalso Builder.prepared_live prepared;
  fun prepared(owner as Restored{prepared,...})=
    (require(is_live owner) "Restored build request released";prepared);
  fun binding(owner as Restored{witness,...})=
    (require(is_live owner) "Restored build request released";Request.binding witness);
  fun phase(owner as Restored{witness,...})=
    (require(is_live owner) "Restored build request released";Request.phase witness);
  fun control_plan(owner as Restored{witness,...})=
    (require(is_live owner) "Restored build request released";Request.control_plan witness);
  fun release(Restored{witness,active,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn live=>
      (if live then Request.release witness else ();false)));
  fun restore installation checked=
    let val b=Request.binding checked
      val _=require(Request.is_live checked andalso E.same(Request.executable checked,Builder.executable))
        "Restored build request pin/ownership mismatch"
      val prepared=Builder.restore_prepared installation checked
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val witness=Request.retain checked
      in Restored{prepared=prepared,witness=witness,
        active=Synchronized.var "restored_build_request" true}end)end;
end;
