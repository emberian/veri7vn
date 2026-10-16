(* Initial logical-export admission observation. The expected manifest intent is
   the exact opaque pre-build owner retained by Builder. The observation reuses
   actual C02 consequences; it creates no additional theorem or quality claim. *)
signature VERI7VN_INITIAL_PACKAGE_ADMISSION =
sig
  type candidate
  type intent
  type observation
  val executable:Veri7vn_Executable_Identity.pin
  val observer_generation:Veri7vn_Native_Registry.generation
  val profile:string
  val measure:intent -> candidate -> observation
  val is_live:observation -> bool
  val candidate:observation -> candidate
  val original_intent:observation -> intent
  val checked_exports:observation -> Veri7vn_Managed_Provenance.consequence list
  val dependencies:observation -> IntInf.int list
  val count:observation -> int
  val semantic_reuse_permitted:observation -> bool
  val release:observation -> unit
end;

functor Veri7vn_Initial_Package_Admission
  (structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   sharing type Builder.export_intent=Intent.intent
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_INITIAL_PACKAGE_ADMISSION where type candidate=Builder.candidate
    and type intent=Intent.intent =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  type candidate=Builder.candidate;
  type intent=Intent.intent;
  type payload={candidate:candidate,intent:intent,exports:P.consequence list,
    dependencies:IntInf.int list,count:int};
  datatype observation=Observation of payload option Synchronized.var;
  val executable=executable;
  val profile="native-export-admission/1";
  val observer_generation=R.generation (Proof_Context.init_global(Veri7vn_Executable_Identity.code_theory executable))
    {packages=[profile],runtime= #artifact(Veri7vn_Executable_Identity.manifest executable),
      policy="fixed-kernel-export-observation/1",sources=[],interpretation=profile};
  fun require true _=() | require false message=error message;
  fun measure intent candidate=
    let
      val _=require(Builder.is_live candidate andalso Intent.is_live intent)
        "Initial admission candidate/intent unavailable";
      val _=require(Intent.same(intent,Builder.original_intent candidate))
        "Initial admission requires the original pre-build manifest intent";
      val binding=Intent.binding intent;
      val projection=Builder.projection candidate;
      val _=require(#source_revision binding= #source_revision projection andalso
        #manifest binding= #manifest projection andalso #export_intent binding= #export_intent projection)
        "Initial admission source/manifest association mismatch";
      val _=require(Intent.workspace intent=P.development_workspace(Builder.development candidate))
        "Initial admission workspace mismatch";
      (* Executable locators need a real refinement/implementation bridge. This
         logical profile must not activate code merely named in a descriptor. *)
      val _=require(null(Intent.executable_locators intent))
        "Initial logical-export admission does not support executable locators";
      val expected=Intent.theorem_names intent;
      val names=Builder.declared_exports candidate;
      val exports=Builder.exports candidate;
      val _=require(not(null expected) andalso length expected<=256 andalso
        expected=names andalso length exports=length expected)
        "Initial admission exact canonical manifest exports differ";
      val generation=Builder.native_generation candidate;
      fun check(name,consequence)=
        let
          val _=require(P.is_live consequence andalso P.public_name consequence=SOME name)
            "Initial admission canonical C02 export provenance mismatch";
          val accepted=P.accepted consequence;
          val _=require(R.same_generation(generation,A.generation accepted))
            "Initial admission C02 export generation mismatch";
          val _=(case A.route accepted of A.Kernel=>() |
            A.Oracle _=>error "Initial admission profile requires kernel exports");
          val _=require(null(A.observed_oracles accepted)) "Initial admission export uses an oracle";
          val _=require(member(op =)(P.dependencies consequence)(#source_owner projection))
            "Initial admission export missing actual source owner";
        in () end;
      val _=List.app check(expected ~~ exports);
      val intent_dependencies= #dependencies binding;
      val _=require(forall(member(op =)(#dependencies projection))intent_dependencies)
        "Initial admission candidate lost original descriptor dependencies";
      val dependencies=distinct(op =)([#candidate projection,#source_owner projection,
        #source_revision projection,#manifest projection,#export_intent projection] @
        #dependencies projection @ intent_dependencies @ maps P.dependencies exports);
      val _=require(length dependencies<=8192 andalso Builder.is_live candidate andalso
        Intent.is_live intent andalso forall P.is_live exports) "Initial admission closure unavailable/bounds";
    in Observation(Synchronized.var "native_initial_admission_observation"
      (SOME{candidate=candidate,intent=intent,exports=exports,dependencies=dependencies,count=length exports})) end;
  fun get(Observation cell)=(case Synchronized.value cell of NONE=>error "Initial admission observation released"
    | SOME p=>p);
  fun is_live observation=(let val {candidate,intent,exports,...}=get observation
    in Builder.is_live candidate andalso Intent.is_live intent andalso forall P.is_live exports end)
    handle ERROR _=>false;
  fun checked observation=(require(is_live observation) "Initial admission observation unavailable";get observation);
  fun candidate observation= #candidate(checked observation);
  fun original_intent observation= #intent(checked observation);
  fun checked_exports observation= #exports(checked observation);
  fun dependencies observation= #dependencies(checked observation);
  fun count observation= #count(checked observation);
  fun semantic_reuse_permitted observation=(ignore(checked observation);false);
  fun release(Observation cell)=Synchronized.change cell(K NONE);
end;
