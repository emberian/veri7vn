(* Native Search context ownership. Published is the parent's fixed, acknowledged
   logical-publication view over the genuine Initial admitted-context producer.
   This module owns resources, never permission, a registry or a scheduler.
   Public construction remains the strict P.public_image producer path. *)
functor Veri7vn_Search_Context_Fn(Published:VERI7VN_ADMITTED_LOGICAL_CONTEXT) :>
sig
  type context
  type admitted=Published.context
  datatype origin=Boot | Qualified of Veri7vn_Qualification_Export_Types.initial_projection
  type snapshot={semantic:IntInf.int,origin:origin,dependencies:IntInf.int list}
  val bind_public:Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> Veri7vn_Managed_Provenance.development -> context
  val bind_admitted_into:context option Unsynchronized.ref ->
    Veri7vn_Native_Identity_Allocator.allocator -> admitted -> context
  val allocator:context -> Veri7vn_Native_Identity_Allocator.allocator
  val development:context -> Veri7vn_Managed_Provenance.development
  val policy:context -> Veri7vn_Native_Admission.policy
  val snapshot:context -> snapshot
  val semantic_generation:context -> IntInf.int
  val dependencies:context -> IntInf.int list
  val catalogue_owned:Veri7vn_Managed_Provenance.construction_scope -> context ->
    Thm_Name.T list -> Veri7vn_Managed_Provenance.consequence list
  val is_live:context -> bool
  val retain:context -> context
  val release:context -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure S=Veri7vn_Native_Sequent;
  type admitted=Published.context;
  datatype origin=Boot | Qualified of Veri7vn_Qualification_Export_Types.initial_projection;
  type snapshot={semantic:IntInf.int,origin:origin,dependencies:IntInf.int list};
  datatype owner=Public | Admitted of admitted;
  type payload={ids:I.allocator,development:P.development,policy:A.policy,
    snapshot:snapshot,owner:owner};
  fun require true _=()|require false message=error message;
  fun owner_live Public=true|owner_live(Admitted owner)=Published.is_live owner;
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({ids,development,policy,snapshot,owner}:payload)=>
      owner_live owner andalso P.development_live development andalso
      P.development_workspace development=I.workspace ids andalso
      I.lookup_generation_id ids(P.generation development)=SOME(#semantic snapshot)andalso
      Context.eq_thy(A.policy_theory policy,Proof_Context.theory_of(R.context(P.generation development)))
    val dispose=fn({owner,...}:payload)=>case owner of Public=>()|Admitted owner=>Published.release owner);
  type context=Root.checked;
  fun allocator context= #ids(Root.read context);
  fun development context= #development(Root.read context);
  fun policy context= #policy(Root.read context);
  fun snapshot context= #snapshot(Root.read context);
  fun semantic_generation context= #semantic(snapshot context);
  fun dependencies context= #dependencies(snapshot context);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
  fun bind_public ids policy development=Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=require(P.development_live development andalso
        P.development_workspace development=I.workspace ids andalso
        Context.eq_thy(A.policy_theory policy,Proof_Context.theory_of(R.context(P.generation development))))
        "Search public context workspace/policy mismatch";
      val scope=P.construction_scope();
      (* This producer rejects replay/definition contexts, even when they use
         the same theory name. It is not replaced by a policy-theory check. *)
      val checked=Exn.capture(restore(fn()=>ignore(P.public_theorem_owned scope development("HOL.TrueI",0))))();
      val _=P.abort_scope scope;val _=Exn.release checked;
      val semantic=I.generation_id ids(P.generation development);
      val view={ids=ids,development=development,policy=policy,owner=Public,
        snapshot={semantic=semantic,origin=Boot,
          dependencies=distinct(op =)(semantic::P.development_dependencies development)}}:payload
    in Root.create view end)();
  fun bind_admitted_into target ids admitted=Thread_Attributes.uninterruptible_body(fn _=>
    let val _=require(is_none(!target)andalso Published.is_live admitted)
        "Search admitted context target occupied or publication owner unavailable";
      val development=Published.development admitted;
      val policy=Published.policy admitted;
      val semantic=Published.semantic_generation admitted;
      val _=require(Published.workspace admitted=I.workspace ids andalso
        P.development_workspace development=I.workspace ids andalso
        I.lookup_generation_id ids(P.generation development)=SOME semantic andalso
        Context.eq_thy(A.policy_theory policy,Proof_Context.theory_of(R.context(P.generation development))))
        "Search admitted context is not the actual qualified native receiver";
      val kept=Published.retain admitted;
      val result=Exn.capture(fn()=>
        let val dependencies=distinct(op =)(semantic::Published.dependencies kept @
          P.development_dependencies development);
          val _=require(length dependencies<=8192 andalso
            forall(fn id=>id>0 andalso size(IntInf.toString id)<=128)dependencies)
            "Search admitted context dependency bound"
        in Root.create{ids=ids,development=development,policy=policy,owner=Admitted kept,
          snapshot={semantic=semantic,origin=Qualified(Published.qualification_pin kept),dependencies=dependencies}}end)()
    in case result of Exn.Res context=>(target:=SOME context;context)|Exn.Exn failure=>
      (Published.release kept;Exn.reraise failure)end);
  fun catalogue_owned scope context names=
    let val {development,owner,...}=Root.read context;
      val _=require(length names<=128) "Search selected catalogue bound";
      fun selected name=case owner of Public=>P.public_theorem_owned scope development name|
        Admitted admitted=>
          let val candidates=filter(fn fact=>P.public_name fact=SOME name)(Published.logical_exports admitted);
            val original=case candidates of [fact]=>fact|
              _=>error "Search selected theorem is not an exact qualified logical export";
            (* These cells belong to the Search scope. The bridge's exported
               cells remain borrowed and must never be released by Search. *)
            val fact=P.named_theorem_owned scope development name;
            val expected=P.accepted original;val actual=P.accepted fact;
            val _=require(R.same_generation(A.generation expected,P.generation development)andalso
              R.same_generation(A.generation actual,P.generation development)andalso
              Thm.eq_thm(A.theorem expected,A.theorem actual)andalso
              S.matches(S.capture(A.target expected)(A.theorem expected))(A.target actual)(A.theorem actual))
              "Search qualified catalogue changed its native theorem or full sequent"
          in fact end
    in map selected names end;
end;
