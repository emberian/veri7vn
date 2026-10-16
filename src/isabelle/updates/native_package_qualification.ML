(* Fixed receiver-side structural interface measurement. This is an observation of admitted
   named exports, not a universal claim of implementation or package quality.
   The resident caller must durably reserve/start qualification before calling
   measure; only a closed service gate may project it into generated evidence. *)
signature VERI7VN_PACKAGE_QUALIFICATION =
sig
  type candidate
  type observation
  type contract
  val retain_baseline_contract: candidate -> contract
  val contract_live: contract -> bool
  val baseline: contract -> candidate
  val expected_exports:contract -> (Thm_Name.T * Veri7vn_Native_Sequent.snapshot) list
  val release_contract: contract -> unit
  val executable: Veri7vn_Executable_Identity.pin
  val observer_generation:Veri7vn_Native_Registry.generation
  val profile: string
  val semantic_reuse_permitted: observation -> bool
  val measure: contract -> candidate -> observation
  val is_live: observation -> bool
  val candidate: observation -> candidate
  val checked_exports: observation -> Veri7vn_Managed_Provenance.consequence list
  val count: observation -> int
  val dependencies: observation -> IntInf.int list
  val release: observation -> unit
end;

functor Veri7vn_Package_Qualification
  (structure Builder: VERI7VN_NATIVE_BUILD_CANDIDATE
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_PACKAGE_QUALIFICATION where type candidate=Builder.candidate =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  type candidate=Builder.candidate;
  structure S=Veri7vn_Native_Sequent;
  datatype contract=Contract of {baseline:candidate,expected:(Thm_Name.T*S.snapshot)list} option Synchronized.var;
  type payload={candidate:candidate,contract:contract,exports:P.consequence list,count:int,
    dependencies:IntInf.int list};
  datatype observation=Observation of payload option Synchronized.var;
  val executable=executable;
  val profile="named-native-export-structure/1";
  val observer_generation=R.generation (Proof_Context.init_global(Veri7vn_Executable_Identity.code_theory executable))
    {packages=[profile],runtime= #artifact(Veri7vn_Executable_Identity.manifest executable),
      policy="fixed-kernel-export-observation/1",sources=[],interpretation=profile};
  fun require true _=() | require false message=error message;
  fun get_contract(Contract cell)=(case Synchronized.value cell of
    NONE=>error "Qualification contract released" | SOME p=>p);
  fun contract_live contract=(Builder.is_live(#baseline(get_contract contract))) handle ERROR _=>false;
  fun baseline contract=(require(contract_live contract) "Qualification baseline unavailable";
    #baseline(get_contract contract));
  fun expected_exports contract=(require(contract_live contract) "Qualification baseline unavailable";
    #expected(get_contract contract));
  fun release_contract(Contract cell)=Synchronized.change cell(K NONE);
  fun retain_baseline_contract baseline=
    let
      val names=Builder.declared_exports baseline;
      val exports=Builder.exports baseline;
      val _=require(Builder.is_live baseline andalso not(null names) andalso
        length names<=256 andalso length names=length exports) "Unsupported baseline export profile";
      fun capture(name,consequence)=
        let val accepted=P.accepted consequence
          val _=require(P.is_live consequence andalso P.public_name consequence=SOME name)
            "Baseline export name/owner mismatch"
          val _=require(R.same_generation(Builder.native_generation baseline,A.generation accepted))
            "Baseline export generation mismatch"
          val _=(case A.route accepted of A.Kernel=>() | A.Oracle _=>error "Baseline oracle unsupported")
          val _=require(null(A.observed_oracles accepted)) "Baseline export uses an oracle"
          val snapshot=S.capture(A.target accepted)(A.theorem accepted)
          val _=require(size(S.encode snapshot)<=65536) "Baseline sequent bound"
        in (name,snapshot) end;
      val expected=map capture(names ~~ exports);
    in Contract(Synchronized.var "native_package_expected_contract"(SOME {baseline=baseline,expected=expected})) end;
  fun measure contract candidate=
    let
      val _=require(Builder.is_live candidate) "Qualification candidate unavailable";
      val {baseline,expected}=get_contract contract;
      val _=require(contract_live contract) "Qualification baseline unavailable";
      val development=Builder.development candidate;
      val names=Builder.declared_exports candidate;
      val exports=Builder.exports candidate;
      val _=require(not(null names) andalso length names<=256 andalso
        length names=length exports) "Unsupported qualification export profile";
      val _=require(names=map #1 expected) "Qualification canonical export names differ";
      fun check((name,consequence),(_,snapshot))=
        let val accepted=P.accepted consequence
          val _=require(P.is_live consequence andalso P.public_name consequence=SOME name)
            "Qualification export name/owner mismatch"
          val _=require(R.same_generation(P.generation development,A.generation accepted))
            "Qualification export generation mismatch"
          val _=(case A.route accepted of A.Kernel=>() |
            A.Oracle _=>error "Qualification profile requires kernel exports")
          val _=require(null(A.observed_oracles accepted)) "Qualification export uses an oracle"
          val _=require(S.matches snapshot (A.target accepted)(A.theorem accepted))
            "Qualification native sequent/assumptions differ"
        in () end;
      val _=List.app check ((names ~~ exports) ~~ expected);
      val dependencies=distinct(op =)([#candidate(Builder.projection candidate),
        #candidate(Builder.projection baseline)] @ #dependencies(Builder.projection candidate) @
        #dependencies(Builder.projection baseline) @ maps P.dependencies exports);
      val _=require(length dependencies<=8192) "Qualification dependency bound";
      val _=require(Builder.is_live candidate andalso contract_live contract andalso forall P.is_live exports)
        "Qualification candidate released during measurement";
    in Observation(Synchronized.var "native_package_qualification"
      (SOME {candidate=candidate,contract=contract,exports=exports,count=length exports,dependencies=dependencies})) end;
  fun get(Observation cell)=(case Synchronized.value cell of
    NONE=>error "Qualification observation released" | SOME p=>p);
  fun is_live observation=(let val {candidate,contract,exports,...}=get observation
    in Builder.is_live candidate andalso contract_live contract andalso forall P.is_live exports end) handle ERROR _=>false;
  fun checked observation=(require(is_live observation) "Qualification observation unavailable";get observation);
  fun candidate observation= #candidate(checked observation);
  fun checked_exports observation= #exports(checked observation);
  fun count observation= #count(checked observation);
  (* Sibling contexts can give equal constant names different definitions. This
     observation cannot license context transport or semantic cache reuse. *)
  fun semantic_reuse_permitted observation=(ignore(checked observation);false);
  fun dependencies observation= #dependencies(checked observation);
  (* Candidate/export owners are shared; releasing this observation never retires
     an active candidate or releases another request's native development. *)
  fun release(Observation cell)=Synchronized.change cell(K NONE);
end;
