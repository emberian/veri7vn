(* Reconstruct an unresolved Q template only from the actual retained BuildRequest
   owner. Source/intent replay belongs to that typed BuildRequest checker. *)
functor Veri7vn_Check_Initial_Qualification_Template
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure PreparedOwner:VERI7VN_BUILD_PREPARED_LEASE
   structure Admission:VERI7VN_INITIAL_PACKAGE_ADMISSION
   structure Checkpoint:VERI7VN_INITIAL_TEMPLATE_CHECKPOINT
   sharing type Intent.intent=Builder.export_intent=Admission.intent
   sharing type Builder.prepared=PreparedOwner.prepared) :>
sig
  include VERI7VN_CHECKED_INITIAL_QUALIFICATION_TEMPLATE
    where type prepared=Builder.prepared and type intent=Intent.intent
  val check:Veri7vn_Native_Identity_Allocator.allocator -> Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Committed_Native_Recovery.committed -> PreparedOwner.lease -> checked
end =
struct
  structure T=Veri7vn_Initial_Qualification_Template_Types;
  structure C=Veri7vn_Qualification_Material_Check;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure Wire=Veri7vn_Initial_Template_Codec;
  type prepared=Builder.prepared;
  type intent=Intent.intent;
  type binding={prepared:prepared,intent:intent,snapshot:T.snapshot};
  type payload={binding:binding,owner:PreparedOwner.lease};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({owner,...}:payload)=>PreparedOwner.is_live owner
    val dispose=fn({owner,...}:payload)=>PreparedOwner.release owner);
  type checked=Root.checked;
  fun prepared_pin(p:Builder.projection):T.prepared_pin=
    {template= #template p,source_owner= #source_owner p,source_revision= #source_revision p,
      manifest= #manifest p,parents= #parents p,profile= #profile p,setup= #setup p,
      export_intent= #export_intent p,candidate= #candidate p,dependencies= #dependencies p};
  fun check allocator image committed owner=
    let
      val m=C.check image Admission.executable Veri7vn_Recovery_Manifest.InitialQualificationRequest
        "initial-qualification-request/2" committed;
      val wire=Wire.decode(#projection m);
      val _=C.require(PreparedOwner.is_live owner) "Initial template BuildRequest owner unavailable";
      val prepared=PreparedOwner.prepared owner;
      val intent=Builder.prepared_original_intent prepared;
      val original=Intent.binding intent;
      val pin=prepared_pin(Builder.prepared_projection prepared);
      val plan=Builder.prepared_plan prepared;
      val context= #context wire;
      val names= #names wire;
      val _=C.require(#association m= #request_slot context andalso #semantic_generation m= #semantic_generation names andalso
        #workspace m=Veri7vn_Native_Identity_Allocator.workspace allocator andalso #workspace m=Intent.workspace intent andalso
        #prepared wire=pin andalso #build wire=plan andalso #profile wire=Admission.profile andalso
        #request plan= #request context andalso #goal plan<> #goal context andalso
        #source_revision original= #source_revision pin andalso #manifest original= #manifest pin andalso
        #export_intent original= #export_intent pin) "Initial template native plan/intent/identity mismatch";
      val _=C.require(case N.lookup_semantic_generation_id allocator Admission.observer_generation of
        NONE=>true | SOME id=>id= #semantic_generation names) "Initial template observer semantic pin mismatch";
      val expected=distinct(op =)([#request_slot context,#candidate pin,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#executable_generation context,
        #interpretation context,#semantic_generation names,P.source_identity(#source original),#source_revision original,
        #manifest original,#export_intent original] @ #dependencies pin @ #dependencies original);
      val _=C.require(#dependencies wire=expected andalso not(null(Intent.theorem_names intent)) andalso
        null(Intent.executable_locators intent) andalso Checkpoint.template(#checkpoint m)wire)
        "Initial template original contract/checkpoint mismatch";
      val retained=PreparedOwner.retain owner;
      val result=Exn.capture Root.create{owner=retained,binding={prepared=prepared,intent=intent,snapshot=wire}};
    in case result of Exn.Res checked=>checked | Exn.Exn exn=>(PreparedOwner.release retained;Exn.reraise exn) end;
  fun binding checked= #binding(Root.read checked);
  fun executable checked=(ignore(Root.read checked);Admission.executable);
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b=binding checked in
      [{workspace=Intent.workspace(#intent b),generation=Admission.observer_generation,
        semantic_generation= #semantic_generation(#names(#snapshot b))}] end
  end);
  val fragment=Bind.fragment;
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;
