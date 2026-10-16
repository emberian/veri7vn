functor Veri7vn_Initial_Qualification_Template
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure PreparedOwner:VERI7VN_BUILD_PREPARED_LEASE
   structure OutputOwner:VERI7VN_QUALIFICATION_BUILD_OUTPUT_LEASE
   structure Admission:VERI7VN_INITIAL_PACKAGE_ADMISSION
   structure Recovery:VERI7VN_CHECKED_INITIAL_QUALIFICATION_TEMPLATE
   sharing type Recovery.prepared=Builder.prepared
   sharing type Recovery.intent=Intent.intent
   sharing type Intent.intent=Builder.export_intent=Admission.intent
   sharing type Builder.prepared=PreparedOwner.prepared
   sharing type Builder.candidate=OutputOwner.candidate=Admission.candidate) :>
sig
  include VERI7VN_CHECKED_INITIAL_QUALIFICATION_REQUEST
    where type candidate=Builder.candidate and type intent=Intent.intent
  type template
  val prepare:Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Qualification_Recovery_Types.initial_context -> PreparedOwner.lease -> template
  val restore_template:Recovery.checked -> template
  val snapshot:template -> Veri7vn_Initial_Qualification_Template_Types.snapshot
  val template_live:template -> bool
  val retain_template:template -> template
  val release_template:template -> unit
  val bind:Veri7vn_Native_Identity_Allocator.allocator -> template -> OutputOwner.lease -> checked
end =
struct
  structure T=Veri7vn_Initial_Qualification_Template_Types;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure I=Veri7vn_Native_Identity_Allocator;
  type candidate=Builder.candidate;
  type intent=Intent.intent;
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun prepared_pin(p:Builder.projection):T.prepared_pin=
    {template= #template p,source_owner= #source_owner p,source_revision= #source_revision p,
      manifest= #manifest p,parents= #parents p,profile= #profile p,setup= #setup p,
      export_intent= #export_intent p,candidate= #candidate p,dependencies= #dependencies p};
  datatype origin=Fresh of PreparedOwner.lease | Restored of Recovery.checked;
  fun origin_live(Fresh owner)=PreparedOwner.is_live owner | origin_live(Restored owner)=Recovery.is_live owner;
  fun release_origin(Fresh owner)=PreparedOwner.release owner | release_origin(Restored owner)=Recovery.release owner;
  type template_payload={origin:origin,intent:intent,snapshot:T.snapshot};
  structure Template=Veri7vn_Checked_Qualification_Root(type payload=template_payload
    val live=fn({origin,intent,...}:template_payload)=>origin_live origin andalso Intent.is_live intent
    val dispose=fn({origin,...}:template_payload)=>release_origin origin);
  type template=Template.checked;
  fun prepare allocator (context:Veri7vn_Qualification_Recovery_Types.initial_context) owner=
    let
      val _=require(PreparedOwner.is_live owner) "Initial template prepared owner unavailable";
      val prepared=PreparedOwner.prepared owner;
      val intent=Builder.prepared_original_intent prepared;
      val original=Intent.binding intent;
      val pin=prepared_pin(Builder.prepared_projection prepared);
      val plan=Builder.prepared_plan prepared;
      val _=require(Intent.workspace intent=I.workspace allocator andalso #request plan= #request context andalso
        #goal plan<> #goal context andalso #slot plan<> #request_slot context andalso
        #slot plan<> #slot context andalso #request_slot context<> #slot context)
        "Initial template workspace/child/slot mismatch";
      val _=require(forall positive[#request context,#goal context,#request_slot context,#interpretation context,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#acceptance_metric context,
        #count_metric context,#unit_id context,#executable_generation context,#slot context] andalso
        #acceptance_metric context<> #count_metric context) "Initial template context bounds";
      val _=require(not(null(Intent.theorem_names intent)) andalso null(Intent.executable_locators intent))
        "Initial template supports nonempty logical intent only";
      val names={claim=I.allocate allocator,target=I.allocate allocator,evidence=I.allocate allocator,
        contract=I.allocate allocator,attempt=I.allocate allocator,qualification=I.allocate allocator,
        observation=I.allocate allocator,semantic_generation=N.semantic_generation_id allocator Admission.observer_generation};
      val dependencies=distinct(op =)([#request_slot context,#candidate pin,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#executable_generation context,
        #interpretation context,#semantic_generation names,P.source_identity(#source original),#source_revision original,
        #manifest original,#export_intent original] @ #dependencies pin @ #dependencies original);
      val _=require(length dependencies<=8192) "Initial template dependency bounds";
      val retained=PreparedOwner.retain owner;
      val result=Exn.capture Template.create{origin=Fresh retained,intent=intent,
        snapshot={context=context,names=names,prepared=pin,build=plan,profile=Admission.profile,dependencies=dependencies}};
    in case result of Exn.Res template=>template | Exn.Exn exn=>(PreparedOwner.release retained;Exn.reraise exn) end;
  fun restore_template checked=
    let
      val _=require(Recovery.is_live checked andalso
        Veri7vn_Executable_Identity.same(Recovery.executable checked,Admission.executable))
        "Initial template recovery code/owner mismatch";
      val {prepared,intent,snapshot}=Recovery.binding checked;
      val _=require(Builder.prepared_live prepared andalso
        Intent.same(intent,Builder.prepared_original_intent prepared)) "Initial template recovered source mismatch";
      val retained=Recovery.retain checked;
    in case Exn.capture Template.create{origin=Restored retained,intent=intent,snapshot=snapshot} of
      Exn.Res template=>template | Exn.Exn exn=>(Recovery.release retained;Exn.reraise exn) end;
  fun snapshot template= #snapshot(Template.read template);
  val template_live=Template.is_live;
  val retain_template=Template.retain;
  val release_template=Template.release;
  type binding={candidate:candidate,intent:intent,snapshot:Veri7vn_Pending_Qualification_Types.initial,
    phase:Veri7vn_Pending_Qualification_Types.phase};
  type bound_payload={binding:binding,template:template,output:OutputOwner.lease};
  structure Bound=Veri7vn_Checked_Qualification_Root(type payload=bound_payload
    val live=fn({template,output,...}:bound_payload)=>Template.is_live template andalso OutputOwner.is_live output
    val dispose=fn({template,output,...}:bound_payload)=>(OutputOwner.release output;Template.release template));
  type checked=Bound.checked;
  fun bind allocator template output=
    let
      val {intent,snapshot=original,...}=Template.read template;
      val _=require(OutputOwner.is_live output) "Initial template requires acknowledged native build output";
      val candidate=OutputOwner.candidate output;
      val actual=Builder.projection candidate;
      val expected= #prepared original;
      val context= #context original;
      val names= #names original;
      val plan= #build original;
      val original_intent=Intent.binding intent;
      val _=require(I.workspace allocator=Intent.workspace intent andalso
        OutputOwner.assigned_slot output= #slot plan andalso Builder.execution_plan candidate=plan andalso
        Intent.same(intent,Builder.original_intent candidate)) "Initial template output plan/intent mismatch";
      val _=require(#template actual= #template expected andalso #source_owner actual= #source_owner expected andalso
        #source_revision actual= #source_revision expected andalso #manifest actual= #manifest expected andalso
        #parents actual= #parents expected andalso #profile actual= #profile expected andalso #setup actual= #setup expected andalso
        #export_intent actual= #export_intent expected andalso #candidate actual= #candidate expected andalso
        #lineage actual= #execution plan andalso forall(member(op =)(#dependencies actual)) (#dependencies expected))
        "Initial template did not receive its exact prepared native artifact";
      val _=require(N.lookup_semantic_generation_id allocator Admission.observer_generation=
        SOME(#semantic_generation names)) "Initial template observer meaning changed";
      val candidate_generation=N.semantic_generation_id allocator(Builder.native_generation candidate);
      val _=require(candidate_generation<> #semantic_generation names) "Initial template observer aliases subject";
      val dependencies=distinct(op =)([#request_slot context,#candidate actual,#contract names,#observation names,
        #run_spec context,#policy context,#policy_resource context,#exposure context,#executable_generation context,
        #interpretation context,#semantic_generation names,candidate_generation,
        P.source_identity(#source original_intent),#source_revision original_intent,#manifest original_intent,
        #export_intent original_intent] @ #dependencies actual @ #dependencies original_intent);
      val _=require(length dependencies<=8192 andalso forall(member(op =)dependencies)(#dependencies original))
        "Initial template specialization lost original dependencies";
      val kept_template=Template.retain template;
      val kept_output=case Exn.capture OutputOwner.retain output of Exn.Res lease=>lease
        | Exn.Exn exn=>(Template.release kept_template;Exn.reraise exn);
      val result=Exn.capture Bound.create{template=kept_template,output=kept_output,
        binding={candidate=candidate,intent=intent,phase=Veri7vn_Pending_Qualification_Types.RequestPrepared,
          snapshot={request_slot= #request_slot context,context=context,names=names,candidate=actual,
            profile=Admission.profile,dependencies=dependencies}}};
    in case result of Exn.Res checked=>checked
      | Exn.Exn exn=>(OutputOwner.release kept_output;Template.release kept_template;Exn.reraise exn) end;
  fun binding checked= #binding(Bound.read checked);
  fun executable checked=(ignore(Bound.read checked);Admission.executable);
  structure Bind=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=checked
    fun bindings checked=let val b=binding checked in
      [{workspace=Intent.workspace(#intent b),generation=Admission.observer_generation,
        semantic_generation= #semantic_generation(#names(#snapshot b))}] end
  end);
  val fragment=Bind.fragment;
  val is_live=Bound.is_live;
  val retain=Bound.retain;
  val release=Bound.release;
end;
