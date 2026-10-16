(* Bindings can only originate in the fixed source parser. A caller-created
   cterm is not a source interpretation or an application authorization. *)
structure Veri7vn_Growth_Bindings :>
sig
  type bindings
  val parse: Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice -> bindings
  val source: bindings -> Veri7vn_Managed_Provenance.source_owner
  val slice: bindings -> Veri7vn_Native_Literals.slice
  val term: bindings -> cterm
  val live: bindings -> bool
  val release: bindings -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  type payload={source:P.source_owner,slice:L.slice,term:cterm,lease:L.lease};
  datatype bindings=Bindings of payload option Synchronized.var;
  fun get(Bindings cell)=case Synchronized.value cell of SOME p=>p
    | NONE=>error "Growth bindings released";
  fun live bindings=(let val{source,slice,lease,...}=get bindings
    in ignore(L.lease_input lease);P.owns_input source(L.owner slice) end)
    handle ERROR _=>false;
  fun checked bindings=if live bindings then get bindings else error "Growth bindings unavailable";
  fun source bindings= #source(checked bindings);
  fun slice bindings= #slice(checked bindings);
  fun term bindings= #term(checked bindings);
  fun release(Bindings cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Synchronized.change cell(fn NONE=>NONE | SOME {source,lease,...}=>
      (ignore(L.release lease);
       if L.disposed(P.source_input source) then I.release_disposed_input(P.source_input source) else ();
       NONE)))();
  fun parse(source,slice)=
    let val input=L.owner slice
      val _=if P.owns_input source input andalso L.encoding input="UTF-8" andalso
        size(L.original slice)<=16384 then () else error "Growth bindings source/byte bound"
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val lease=L.retain input
      val result=Exn.capture(restore(fn()=>Timeout.apply(Time.fromSeconds 5)(fn()=>
        let val bindings=Syntax.read_term @{context}(L.original slice)
              |> Type.constraint @{typ "(nat * rat) list"} |> Syntax.check_term @{context}
          val _=if Term.size_of_term bindings<=4096 then () else error "Growth bindings node bound"
          val _=Veri7vn_Growth_Syntax.bindings bindings
          val _=ignore(L.lease_input lease)
        in Bindings(Synchronized.var "growth_source_bindings"
          (SOME{source=source,slice=slice,term=Thm.cterm_of @{context} bindings,lease=lease})) end)()))()
    in case result of Exn.Res bindings=>bindings | Exn.Exn exn=>
      (Option.app I.release_disposed_input(L.release lease);Exn.reraise exn) end)() end;
end;

(* Static service assembly supplies its one actual D43 builder. The attachment
   is a universally checked recipe bridge, not active publication or sample proof. *)
functor Veri7vn_Growth_Attachment_Fn(Builder:VERI7VN_NATIVE_BUILD_CANDIDATE) :>
sig
  type attachment
  type application
  val attach: Builder.candidate -> Veri7vn_Mathematics_Execution.instance ->
    {definition:Thm_Name.T} -> attachment
  val candidate: attachment -> Builder.candidate
  val bridge: attachment -> Veri7vn_Native_Admission.accepted
  val definition: attachment -> Veri7vn_Managed_Provenance.consequence
  val executable: attachment -> Veri7vn_Executable_Identity.pin
  val instance: attachment -> Veri7vn_Mathematics_Execution.instance
  val generation: attachment -> Veri7vn_Native_Registry.generation
  val dependencies: attachment -> IntInf.int list
  val live: attachment -> bool
  val release: attachment -> unit
  val apply: attachment -> {bindings:Veri7vn_Growth_Bindings.bindings,work:int} -> application
  val input: application -> Veri7vn_Mathematics_Execution.request
  val closure: application -> thm
  val meaning: application -> cterm
  val application_bridge: application -> thm
  val application_dependencies: application -> IntInf.int list
  val application_source: application -> Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice
  val application_cost: application -> IntInf.int
  val application_live: application -> bool
  val release_application: application -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure M=Veri7vn_Mathematics_Execution;
  structure B=Veri7vn_Growth_Bindings;
  type payload={candidate:Builder.candidate,instance:M.instance,definition:P.consequence,
    constant:term,recipe:term,bridge:A.accepted,policy:A.policy,generation:R.generation,scope:P.construction_scope,
    source:P.source_owner,slice:L.slice,lease:L.lease};
  datatype attachment=Attachment of payload option Synchronized.var;
  type applied={attachment:attachment,request:M.request,closure:thm,meaning:cterm,
    bridge:thm,cost:IntInf.int,source:P.source_owner,slice:L.slice,lease:L.lease};
  datatype application=Application of applied option Synchronized.var;
  fun require true _=() | require false message=error message;
  fun get(Attachment cell)=case Synchronized.value cell of SOME p=>p
    | NONE=>error "Growth attachment released";
  fun live attachment=(let val{candidate,instance,definition,source,slice,lease,...}=get attachment
    in ignore(L.lease_input lease);Builder.is_live candidate andalso P.is_live definition andalso
      P.owns_input source(L.owner slice) andalso can M.operation instance end)handle ERROR _=>false;
  fun checked attachment=(require(live attachment)"Growth attachment unavailable";get attachment);
  fun candidate attachment= #candidate(checked attachment);
  fun bridge attachment= #bridge(checked attachment);
  fun definition attachment= #definition(checked attachment);
  fun executable attachment=(ignore(checked attachment);M.executable());
  fun instance attachment= #instance(checked attachment);
  fun generation attachment=Builder.native_generation(candidate attachment);
  fun dependencies attachment=let val retained=candidate attachment
    in distinct(op =)(#candidate(Builder.projection retained) :: Builder.retention_dependencies retained)end;
  fun release(Attachment cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Synchronized.change cell(fn NONE=>NONE | SOME {scope,lease,policy,generation,source,...}=>
      (P.abort_scope scope;A.clear_cached_generation policy generation;
       ignore(L.release lease);
       if L.disposed(P.source_input source) then I.release_disposed_input(P.source_input source) else ();
       NONE)))();
  fun attach candidate instance {definition=name}=
    let val _=require(Builder.is_live candidate)"Growth candidate unavailable"
      val development=Builder.development candidate
      val generation=P.generation development
      val ctxt=R.context generation
      val{source,slice,...}=Builder.recipe candidate
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val scope=P.construction_scope()
      val lease=L.retain(L.owner slice)
      val policy=A.policy(Proof_Context.theory_of ctxt)
      val attempted=Exn.capture(restore(fn()=>
        let val definition=P.named_theorem_owned scope development name
          val _=require(member(op =)(P.source_dependencies definition)(P.source_identity source))
            "Growth candidate definition lacks original source"
          val theorem=A.theorem(P.accepted definition)
          val _=require(null(Thm.hyps_of theorem) andalso Thm.nprems_of theorem=0)
            "Growth candidate definition has assumptions"
          val(constant,recipe)=Logic.dest_equals(Thm.prop_of theorem)
          val _=require(fastype_of constant= @{typ math_expr} andalso
            Term.size_of_term recipe<=2048)"Growth attachment type/node bound"
          val _=case constant of Const _=>() | _=>error "Growth attachment requires native definition"
          val _=Veri7vn_Growth_Syntax.expression 0 recipe
          val linked=Drule.infer_instantiate ctxt
            [(("expression",0),Thm.cterm_of ctxt constant)] @{thm growth_recipe_refinement}
          val(handle_,registry)=R.insert generation "growth.recipe-bridge"(R.Theorem linked)R.empty
          val target=Thm.cterm_of ctxt(Thm.prop_of linked)
          val accepted=case A.admit policy generation registry handle_ A.Kernel
              {claim=A.exact_claim target,hypotheses=[],premises=Thm.prems_of linked,
                sorts=Thm.shyps_of linked} of
            A.Accepted accepted=>accepted
          | A.Rejected messages=>error("Growth recipe bridge admission: "^commas messages)
          val _=require(Builder.is_live candidate andalso P.is_live definition andalso
            can M.operation instance)"Growth candidate changed during attachment"
        in Attachment(Synchronized.var "growth_recipe_attachment"(SOME{candidate=candidate,
          instance=instance,definition=definition,constant=constant,recipe=recipe,
          bridge=accepted,scope=scope,policy=policy,generation=generation,source=source,slice=slice,lease=lease})) end))()
    in case attempted of Exn.Res attachment=>attachment | Exn.Exn exn=>
      (P.abort_scope scope;A.clear_cached_generation policy generation;
        Option.app I.release_disposed_input(L.release lease);Exn.reraise exn) end)() end;
  fun get_application(Application cell)=case Synchronized.value cell of SOME p=>p
    | NONE=>error "Growth application released";
  fun application_live application=(let val{attachment,source,slice,lease,...}=get_application application
    in ignore(L.lease_input lease);live attachment andalso P.owns_input source(L.owner slice)end)
    handle ERROR _=>false;
  fun checked_application application=(require(application_live application)
    "Growth application unavailable";get_application application);
  fun input application= #request(checked_application application);
  fun closure application= #closure(checked_application application);
  fun meaning application= #meaning(checked_application application);
  fun application_bridge application= #bridge(checked_application application);
  fun application_dependencies application=let val{attachment,source,...}=checked_application application
    in distinct(op =)(P.source_identity source::dependencies attachment)end;
  fun application_source application=let val{source,slice,...}=checked_application application
    in(source,slice)end;
  fun application_cost application= #cost(checked_application application);
  fun release_application(Application cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Synchronized.change cell(fn NONE=>NONE | SOME {request,lease,source,...}=>
      (M.release_request request;ignore(L.release lease);
       if L.disposed(P.source_input source) then I.release_disposed_input(P.source_input source) else ();
       NONE)))();
  fun apply attachment {bindings,work}=
    let val{candidate,instance,definition,constant,...}=checked attachment
      val source=B.source bindings
      val slice=B.slice bindings
      val _=require(P.source_workspace source=P.development_workspace(Builder.development candidate))
        "Growth application bindings workspace mismatch"
      val _=require(work>0 andalso work<=4096)"Growth application work bound"
      val ctxt=R.context(generation attachment)
      val parsed=Thm.term_of(B.term bindings)
      val close= @{term close_expression} $ parsed $ constant
      val simp_ctxt=put_simpset HOL_ss ctxt addsimps
        (A.theorem(P.accepted definition):: @{thms close_expression.simps})
      val equality=Timeout.apply(Time.fromSeconds 5)
        (Simplifier.rewrite simp_ctxt)(Thm.cterm_of ctxt close)
      val closed=case Thm.term_of(Thm.rhs_of equality)of Const(name,_) $ closed=>
          if name= @{const_name Some} then closed else error "Growth closure missing parameter"
        | _=>error "Growth closure missing parameter"
      val input_term= @{term closed_expression_run} $ HOLogic.mk_number @{typ nat} work $ closed
      val code_ctxt=Proof_Context.init_global(E.code_theory(M.executable()))
    in Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val lease=L.retain(L.owner slice)
      val owned=Unsynchronized.ref(NONE:M.request option)
      val attempted=Exn.capture(fn()=>
        let val request=case M.prepare(M.executable())instance(Thm.cterm_of code_ctxt input_term)of
              M.Ready request=>request | _=>error "Installed mathematics refused growth application"
          val _=owned:=SOME request
          val some= @{term "Some :: math_expr => math_expr option"} $ closed
          val closure_proposition=HOLogic.mk_Trueprop(HOLogic.mk_eq(close,some))
          val closure= @{thm meta_eq_to_obj_eq} OF [equality]
          val _=require(Thm.prop_of closure aconv closure_proposition)
            "Growth closure proposition mismatch"
          val linked=Drule.infer_instantiate ctxt
            [(("bindings",0),Thm.cterm_of ctxt parsed),(("expression",0),Thm.cterm_of ctxt constant),
             (("closed",0),Thm.cterm_of ctxt closed),(("bound",0),Thm.cterm_of ctxt
               (HOLogic.mk_number @{typ nat} work))] @{thm growth_closed_answer_bridge}
          val bridge=Thm.implies_elim linked closure
          val meaning=Thm.cterm_of ctxt(HOLogic.mk_Trueprop
            (@{term closed_expression_meaning} $ HOLogic.mk_number @{typ nat} work $ closed $ input_term))
          val cost=case M.modeled_cost request of M.Ready cost=>cost
            | _=>error "Growth application cost unavailable"
          val _=require(live attachment andalso B.live bindings)"Growth source changed during application"
        in Application(Synchronized.var "growth_recipe_application"(SOME{attachment=attachment,
          request=request,closure=closure,meaning=meaning,bridge=bridge,cost=cost,source=source,slice=slice,lease=lease}))end)()
    in case attempted of Exn.Res application=>application | Exn.Exn exn=>
      (Option.app M.release_request(!owned);
        Option.app I.release_disposed_input(L.release lease);Exn.reraise exn) end)() end;
end;
