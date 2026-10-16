(* Intrinsic qualified logical context. This is not a publication token. The
   private parent exposes it to an active consumer only through its separately
   acknowledged/current publication association. No generated-state callbacks. *)
signature VERI7VN_ADMITTED_LOGICAL_CONTEXT =
sig
  type context
  val development:context -> Veri7vn_Managed_Provenance.development
  val policy:context -> Veri7vn_Native_Admission.policy
  val logical_exports:context -> Veri7vn_Managed_Provenance.consequence list
  val qualification_pin:context -> Veri7vn_Qualification_Export_Types.initial_projection
  val semantic_generation:context -> IntInf.int
  val dependencies:context -> IntInf.int list
  val workspace:context -> string
  val is_live:context -> bool
  val retain:context -> context
  val release:context -> unit
end;

functor Veri7vn_Initial_Admitted_Context
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure CandidateOwner:VERI7VN_BUILD_CANDIDATE_LEASE
   structure FreshOwner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   structure Checked:VERI7VN_CHECKED_INITIAL_QUALIFICATION
   sharing type Builder.export_intent=Intent.intent=Checked.intent
   sharing type Builder.candidate=CandidateOwner.candidate=Checked.candidate
   val result:FreshOwner.value -> Veri7vn_Qualification_Export_Types.initial_projection * int
   val exports:FreshOwner.value -> Veri7vn_Managed_Provenance.consequence list
   val executable:Veri7vn_Executable_Identity.pin
   val observer_generation:Veri7vn_Native_Registry.generation) :>
sig
  include VERI7VN_ADMITTED_LOGICAL_CONTEXT
  val create:Veri7vn_Native_Identity_Allocator.allocator -> FreshOwner.lease -> CandidateOwner.lease -> context
  val restore:Veri7vn_Native_Identity_Allocator.allocator -> Checked.checked -> CandidateOwner.lease -> context
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure N=Veri7vn_Native_Descriptor;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure S=Veri7vn_Native_Sequent;
  structure X=Veri7vn_Qualification_Export_Types;
  fun require true _=() | require false message=error message;
  datatype origin=Fresh of FreshOwner.lease | Restored of Checked.checked;
  fun origin_live(Fresh owner)=FreshOwner.is_live owner | origin_live(Restored checked)=Checked.is_live checked;
  fun release_origin(Fresh owner)=FreshOwner.release owner | release_origin(Restored checked)=Checked.release checked;
  type payload={origin:origin,candidate:CandidateOwner.lease,development:P.development,
    policy:A.policy,exports:P.consequence list,pin:X.initial_projection,semantic:IntInf.int,
    dependencies:IntInf.int list,workspace:string};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({origin,candidate,development,exports,...}:payload)=>origin_live origin andalso
      CandidateOwner.is_live candidate andalso P.development_live development andalso forall P.is_live exports
    val dispose=fn({origin,candidate,...}:payload)=>(release_origin origin;CandidateOwner.release candidate));
  type context=Root.checked;
  fun validate allocator candidate (pin:X.initial_projection) count facts=
    let
      val _=require(Builder.is_live candidate) "Admitted context candidate unavailable";
      val development=Builder.development candidate;
      val generation=Builder.native_generation candidate;
      val actual=Builder.projection candidate;
      val original=Intent.binding(Builder.original_intent candidate);
      val expected=Builder.declared_exports candidate;
      val native_facts=Builder.exports candidate;
      val workspace=P.development_workspace development;
      val _=require(I.workspace allocator=workspace andalso #candidate pin=actual andalso
        #profile pin="native-export-admission/1" andalso count>0 andalso count<=256 andalso
        count=length facts andalso length facts=length native_facts andalso
        expected=Intent.theorem_names(Builder.original_intent candidate) andalso
        null(Intent.executable_locators(Builder.original_intent candidate)))
        "Admitted context exact qualified candidate/profile/export mismatch";
      val intent= #intent pin;
      val _=require(#source_owner intent=P.source_identity(#source original) andalso
        #source_revision intent= #source_revision original andalso #manifest intent= #manifest original andalso
        #export_intent intent= #export_intent original andalso #dependencies intent= #dependencies original)
        "Admitted context original intent association mismatch";
      val names= #names pin;
      val semantic=case N.lookup_semantic_generation_id allocator generation of SOME id=>id
        | NONE=>error "Admitted context native subject generation unregistered";
      val _=require(N.lookup_semantic_generation_id allocator observer_generation=SOME(#semantic_generation names) andalso
        semantic<> #semantic_generation names andalso E.exact_code_context executable
          (Proof_Context.theory_of(R.context observer_generation))) "Admitted context observer/subject pin mismatch";
      fun check((name,fact),native_fact)=
        let val accepted=P.accepted fact
          val native=P.accepted native_fact
          val _=require(P.is_live fact andalso P.is_live native_fact andalso P.workspace fact=workspace andalso
            P.public_name fact=SOME name andalso P.public_name native_fact=SOME name andalso
            R.same_generation(A.generation accepted,generation) andalso
            R.same_generation(A.generation native,generation)) "Admitted context native export provenance mismatch"
          val _=(case A.route accepted of A.Kernel=>() | A.Oracle _=>error "Admitted context requires kernel exports")
          val _=require(null(A.observed_oracles accepted) andalso
            S.matches(S.capture(A.target native)(A.theorem native))(A.target accepted)(A.theorem accepted))
            "Admitted context full native export/assumption mismatch"
        in () end;
      val _=List.app check((expected ~~ facts) ~~ native_facts);
      val policy=A.acceptance_policy(P.accepted(hd facts));
      val _=require(Context.eq_thy(A.policy_theory policy,Proof_Context.theory_of(R.context generation)))
        "Admitted context policy is not its actual native development context";
      val dependencies=distinct(op =)([#claim names,#target names,#evidence names,#contract names,
        #attempt names,#qualification names,#observation names,#semantic_generation names,semantic] @
        #dependencies pin @ P.development_dependencies development @ maps P.dependencies facts);
      val _=require(length dependencies<=8192) "Admitted context complete closure bound";
    in {development=development,policy=policy,exports=facts,pin=pin,semantic=semantic,
      dependencies=dependencies,workspace=workspace} end;
  fun create allocator fresh candidate_owner=Thread_Attributes.uninterruptible_body(fn _=>
    let
      val _=require(FreshOwner.is_live fresh andalso CandidateOwner.is_live candidate_owner)
        "Admitted context qualified/candidate lease unavailable";
      val qualified=FreshOwner.value fresh;
      val (pin,count)=result qualified;
      val facts=exports qualified;
      val candidate=CandidateOwner.candidate candidate_owner;
      val data=validate allocator candidate pin count facts;
      val _=require(FreshOwner.workspace fresh= #workspace data andalso result qualified=(pin,count))
        "Admitted context qualified owner changed during capture";
      val retained=FreshOwner.retain fresh;
      val kept=case Exn.capture CandidateOwner.retain candidate_owner of Exn.Res kept=>kept
        | Exn.Exn exn=>(FreshOwner.release retained;Exn.reraise exn);
      val value={origin=Fresh retained,candidate=kept,development= #development data,policy= #policy data,
        exports= #exports data,pin=pin,semantic= #semantic data,dependencies= #dependencies data,workspace= #workspace data};
    in case Exn.capture Root.create value of Exn.Res context=>context
      | Exn.Exn exn=>(FreshOwner.release retained;CandidateOwner.release kept;Exn.reraise exn) end);
  fun restore allocator checked candidate_owner=Thread_Attributes.uninterruptible_body(fn _=>
    let
      val _=require(Checked.is_live checked andalso CandidateOwner.is_live candidate_owner andalso
        E.same(Checked.executable checked,executable)) "Admitted context checked owner/code unavailable";
      val b=Checked.binding checked;
      val candidate=CandidateOwner.candidate candidate_owner;
      val _=require(R.same_generation(Builder.native_generation(#candidate b),Builder.native_generation candidate) andalso
        Intent.same(#intent b,Builder.original_intent candidate)) "Admitted context restored native subject mismatch";
      val original=Intent.binding(#intent b);
      val pin:X.initial_projection={context= #context b,names= #names b,candidate= #candidate_pin b,
        intent={source_owner=P.source_identity(#source original),source_revision= #source_revision original,
          manifest= #manifest original,export_intent= #export_intent original,dependencies= #dependencies original},
        dependencies= #dependencies b,profile= #profile b};
      val facts=Builder.exports candidate;
      val _=Veri7vn_Qualification_Restore_Check.exports(#exports b)facts;
      val data=validate allocator candidate pin (#count b) facts;
      val retained=Checked.retain checked;
      val kept=case Exn.capture CandidateOwner.retain candidate_owner of Exn.Res kept=>kept
        | Exn.Exn exn=>(Checked.release retained;Exn.reraise exn);
      val value={origin=Restored retained,candidate=kept,development= #development data,policy= #policy data,
        exports= #exports data,pin=pin,semantic= #semantic data,dependencies= #dependencies data,workspace= #workspace data};
    in case Exn.capture Root.create value of Exn.Res context=>context
      | Exn.Exn exn=>(Checked.release retained;CandidateOwner.release kept;Exn.reraise exn) end);
  fun development context= #development(Root.read context);
  fun policy context= #policy(Root.read context);
  fun logical_exports context= #exports(Root.read context);
  fun qualification_pin context= #pin(Root.read context);
  fun semantic_generation context= #semantic(Root.read context);
  fun dependencies context= #dependencies(Root.read context);
  fun workspace context= #workspace(Root.read context);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;
