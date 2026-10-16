(* Fixed source-proof association. No operation here issues a charge or licenses
   publication. The serialized resident owner must bind the actual W.identity to
   this SAME Q/child, current support, pins and incarnation before using a frame.
   A worker wire is admitted through Q's original source recipe and independently
   in the immutable receiver context. The source-owning proof generation remains
   separate. First deployed profile: one shipped context, exact parent policy,
   no external hypotheses/meta-premises/sort assumptions/oracles. *)
functor Veri7vn_Search_Gate_Fn (Q:
sig
  type request
  val receiver: request -> Veri7vn_Managed_Provenance.development
  val source: request -> Veri7vn_Managed_Provenance.source_owner
  val slice: request -> Veri7vn_Native_Literals.slice
  val target: request -> cterm
  val dependencies: request -> IntInf.int list
  val native_scope: request -> Veri7vn_Native_Request_Scope.child option
  val live: request -> bool
  val prove_owned: Veri7vn_Managed_Provenance.construction_scope -> request -> string ->
    Veri7vn_Managed_Provenance.development * Veri7vn_Managed_Provenance.consequence
end) :>
sig
  type request=Q.request
  type witness
  type projection={identity:Veri7vn_Native_Request_Scope.identity,
    receiver_semantic:IntInf.int,proof_semantic:IntInf.int,dependencies:IntInf.int list}
  type saved={identity:Veri7vn_Native_Request_Scope.identity,receiver_semantic:IntInf.int,
    proof_semantic:IntInf.int,target:term,sequent:string,encoding:string,bytes:string,start:int,stop:int}
  val reconstruct_into: witness option Unsynchronized.ref ->
    Veri7vn_Managed_Provenance.construction_scope -> request -> string -> witness
  (* Exclusive verified private source-proof certificate, not a generic user
     evidence assignment. Consumed on success AND failure. The caller first
     authenticates its exact outer SearchOutput/goal association under C. No
     worker start, search dispatch, effect, ticket or charge is replayed. *)
  val restore_into: witness option Unsynchronized.ref -> request -> saved ->
    Veri7vn_Native_Recovery_Check.verified -> witness
  val request: witness -> request
  (* Counted native proof view; retaining it grants no active request/ticket. *)
  val retain: witness -> witness
  val active_live: witness -> bool
  val accepted: witness -> Veri7vn_Native_Admission.accepted
  val source_consequence: witness -> Veri7vn_Managed_Provenance.consequence
  val proof_development: witness -> Veri7vn_Managed_Provenance.development
  val project: witness -> projection
  val snapshot: witness -> saved
  val live: witness -> bool
  val release: witness -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure Sequent=Veri7vn_Native_Sequent;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Claim=Veri7vn_Native_Release_Claim;
  type request=Q.request;
  type projection={identity:Scope.identity,receiver_semantic:IntInf.int,
    proof_semantic:IntInf.int,dependencies:IntInf.int list};
  type saved={identity:Scope.identity,receiver_semantic:IntInf.int,proof_semantic:IntInf.int,
    target:term,sequent:string,encoding:string,bytes:string,start:int,stop:int};
  type payload={request:request,child:Scope.child,receiver:P.development,saved:saved,development:P.development,
    consequence:P.consequence,accepted:A.accepted,registry:R.registry,
    projection:projection,sequent:Sequent.snapshot,release:unit->unit};
  datatype witness=Witness of {view:Claim.owner,
    root:(int*payload option) Synchronized.var};
  fun require true _=() | require false message=error message;
  fun get(Witness{view,root})=
    (require(Claim.is_live view) "Search native proof view released or releasing";
     case #2(Synchronized.value root)of SOME p=>p|NONE=>error "Search native proof association released");
  fun live witness=(let val {receiver,development,consequence,accepted,...}=get witness
      val proof=P.generation development;
      val generation=P.generation receiver;
    in P.development_live receiver andalso
      P.development_live development andalso P.is_live consequence andalso
      R.same_generation(A.generation accepted,generation) andalso
      Context.eq_thy(Proof_Context.theory_of(R.context proof),Proof_Context.theory_of(R.context generation))
    end)handle ERROR _=>false;
  fun active_live witness=live witness andalso
    (let val{request,child,...}=get witness in Q.live request andalso Scope.child_live child end)
      handle ERROR _=>false;
  fun checked witness=(require(live witness) "Search native proof association unavailable";get witness);
  fun request witness=(require(active_live witness) "Search execution request is inactive";#request(checked witness));
  fun accepted witness= #accepted(checked witness);
  fun source_consequence witness= #consequence(checked witness);
  fun proof_development witness= #development(checked witness);
  fun project witness= #projection(checked witness);
  fun retain(witness as Witness{root,view})=Thread_Attributes.uninterruptible_body(fn _=>
    Claim.with_live view(fn()=>
    let val _=require(live witness) "Search native proof root unavailable";
      val next=Claim.create();
      val _=Synchronized.change root(fn(n,SOME p)=>
          (require(n>0 andalso n<1024) "Search retained proof view bound";(n+1,SOME p))|
        _=>error "Search native proof root already released")
    in Witness{view=next,root=root}end));
  fun release(Witness{view,root})=Thread_Attributes.uninterruptible_body(fn _=>
    case Claim.try_claim view of NONE=>
      require(Claim.is_done view) "Search proof cleanup is already in progress"|SOME claim=>
      let val disposed=Exn.capture(fn()=>Synchronized.change root(fn(n,payload)=>
        if n>1 then(n-1,payload)else(case payload of
          NONE=>(0,NONE)|SOME{release,...}=>(release();(0,NONE)))))()
      in case disposed of Exn.Res()=>Claim.finish claim|Exn.Exn failure=>
        (Claim.retry claim;Exn.reraise failure)end);
  fun physical development=
    let fun walk depth current=if depth>=256 then error "Search context alias depth bound"
          else case P.alias_parent current of NONE=>current | SOME parent=>walk(depth+1)parent
    in walk 0 development end;
  (* Private binder. Fresh construction owns a development; restored construction
     owns an exclusive verified lease, so shared logical aliases are not freed by
     P.release. Only protected Q/native producer or V can reach this binder. *)
  fun bind request development consequence expected_wire dispose=
    let val _=require(Q.live request) "Search original request unavailable";
      val child=case Q.native_scope request of SOME child=>child
        | NONE=>error "Deployed search proof requires an actual typed request child";
      val parent=Scope.parent child;
      val ids=Scope.allocator parent;
      val receiver=Q.receiver request;
      val receiver_gen=P.generation receiver;
      val target=Q.target request;
      val parent_policy=Scope.policy parent;
      val _=require(Context.eq_thy(A.policy_theory parent_policy,
        Proof_Context.theory_of(R.context receiver_gen)))
        "Search first profile requires the parent-authorized exact receiver policy";
      val source=Q.source request;
      val slice=Q.slice request;
      val _=require(Scope.child_live child andalso I.workspace ids=P.development_workspace receiver andalso
        P.workspace consequence=I.workspace ids andalso
        P.owns_input source(L.owner(Scope.source child)) andalso
        L.same_input(L.owner slice,L.owner(Scope.source child)) andalso
        L.offsets slice=L.offsets(Scope.source child)) "Search original child/source association differs";
      val proof_gen=P.generation development;
      val _=require(P.is_live consequence andalso
        R.same_generation(P.generation(P.consequence_development consequence),proof_gen))
        "Search source consequence belongs to another development";
      val _=require(Context.eq_thy(Proof_Context.theory_of(R.context receiver_gen),
        Proof_Context.theory_of(R.context proof_gen))) "Search proof changed the actual native receiver theory";
      val _=case P.context_parents development of [actual_parent]=>
        require(R.same_generation(P.generation actual_parent,receiver_gen))
          "Search logical proof ancestry differs from original receiver"
        | _=>error "Search proof must have exactly the original logical receiver parent";
      val recipe=case P.proof_recipe(physical development) of SOME recipe=>recipe
        | NONE=>error "Search result has no native original-source proof recipe";
      val _=require(R.same_generation(P.generation(#parent recipe),P.generation(physical receiver)) andalso
        P.owns_input (#source recipe)(L.owner slice) andalso
        P.source_identity(#source recipe)=P.source_identity source andalso
        L.same_input(L.owner(#slice recipe),L.owner slice) andalso
        L.offsets(#slice recipe)=L.offsets slice andalso L.original(#slice recipe)=L.original slice andalso
        (case expected_wire of NONE=>true | SOME wire=> #wire recipe=wire))
        "Search proof recipe differs from original receiver/source/wire";
      val source_accepted=P.accepted consequence;
      val theorem=A.theorem source_accepted;
      val _=require(R.same_generation(A.generation source_accepted,proof_gen) andalso
        null(Thm.hyps_of theorem) andalso Thm.nprems_of theorem=0 andalso
        null(Thm.shyps_of theorem) andalso null(Thm.tpairs_of theorem) andalso
        null(A.observed_oracles source_accepted) andalso
        Thm.prop_of theorem aconv Thm.term_of target andalso
        Thm.term_of(A.target source_accepted) aconv Thm.term_of target)
        "Search first profile requires the exact whole target with no external hypotheses, meta-premises, sort assumptions or oracles";
      val _=require(Context.eq_thy(A.policy_theory(A.acceptance_policy source_accepted),
        Proof_Context.theory_of(R.context receiver_gen))) "Search producer policy differs from actual receiver theory";
      val (handle_id,registry)=R.insert receiver_gen "fixed-search-receiver-proof"(R.Theorem theorem)R.empty;
      val admitted=case A.admit parent_policy receiver_gen registry handle_id A.Kernel
        {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=[]} of
          A.Accepted value=>value
        | A.Rejected reasons=>error("Search proof is not admitted in original receiver: " ^ space_implode "; " reasons);
      val sequent=Sequent.capture target(A.theorem admitted);
      val _=require(Sequent.encode sequent= #sequent recipe)
        "Search original-receiver admission changed the complete proof sequent";
      val receiver_semantic=I.generation_id ids receiver_gen;
      val proof_semantic=I.generation_id ids proof_gen;
      val dependencies=distinct(op =)(receiver_semantic::proof_semantic::
        Q.dependencies request @ P.dependencies consequence @ P.source_dependencies consequence);
      val input=L.owner slice;val{start,stop}=L.offsets slice;
      val saved={identity=Scope.identity child,receiver_semantic=receiver_semantic,
        proof_semantic=proof_semantic,target=Thm.term_of target,sequent=Sequent.encode sequent,
        encoding=L.encoding input,bytes=L.bytes input,start=start,stop=stop}:saved;
      val witness=Witness{view=Claim.create(),
        root=Synchronized.var "fixed_search_native_association"(1,SOME
        {request=request,child=child,receiver=receiver,saved=saved,development=development,consequence=consequence,
         accepted=admitted,registry=registry,sequent=sequent,release=dispose,
         projection={identity=Scope.identity child,receiver_semantic=receiver_semantic,
           proof_semantic=proof_semantic,dependencies=dependencies}})};
      val _=require(active_live witness) "Search revoked during original-receiver admission";
    in witness end;
  fun snapshot witness= #saved(checked witness);
  (* The caller allocates target before entering and drains it on abort. Native
     witness publication and exclusive V.claim are masked together with that
     fixed typed ownership handoff, never a caller cleanup callback. *)
  fun reconstruct_into target scope request wire=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val _=require(is_none(!target)) "Search proof cleanup target already occupied";
        val (development,consequence)=restore(fn()=>Q.prove_owned scope request wire)();
        val result=Exn.capture(restore(fn()=>bind request development consequence(SOME wire)
          (fn()=>P.release development)))();
      in case result of Exn.Res witness=>(target:=SOME witness;witness)
        | Exn.Exn failure=>(P.release development;Exn.reraise failure)end)();
  fun restore_into target request (saved:saved) verified=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val owned=Unsynchronized.ref(NONE:witness option);
        val result=Exn.capture(fn()=>
          let val _=require(is_none(!target)) "Search restored cleanup target already occupied";
            val consequence=V.consequence verified;
            val witness=restore(fn()=>bind request(P.consequence_development consequence)consequence NONE
              (fn()=>V.release verified))();
            val _=owned:=SOME witness;
            val actual=snapshot witness;
            val _=require(#identity actual= #identity saved andalso
              #receiver_semantic actual= #receiver_semantic saved andalso #proof_semantic actual= #proof_semantic saved andalso
              #target actual aconv #target saved andalso #sequent actual= #sequent saved andalso
              #encoding actual= #encoding saved andalso #bytes actual= #bytes saved andalso
              #start actual= #start saved andalso #stop actual= #stop saved)
              "Restored search native proof differs from exact original child/source/context association";
            val _=V.claim verified;
            val _=target:=SOME witness;
            val _=owned:=NONE;
          in witness end)();
      in case result of Exn.Res witness=>witness | Exn.Exn failure=>
        ((case !owned of SOME witness=>release witness | NONE=>V.release verified);Exn.reraise failure)end)();
end;
