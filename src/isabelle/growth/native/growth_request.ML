(* Source-owned preparation only. Durable candidate construction/retention is
   owned by D43; this module cannot issue a ticket, execute, admit or activate. *)
structure Veri7vn_Growth_Preparation :>
sig
  type request
  datatype observation = Observation of {sample:int,expected:term,
    actual:Veri7vn_Mathematics_Execution.view,agrees:bool}
  val prepare: Veri7vn_Mathematics_Execution.instance ->
    {parent:Veri7vn_Managed_Provenance.development,
     expression:Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice,
     samples:(Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice) list,
     work:int} -> request
  val prepare_definition: Veri7vn_Mathematics_Execution.instance ->
    {development:Veri7vn_Managed_Provenance.development,
     definition:Veri7vn_Managed_Provenance.consequence,
     source:Veri7vn_Managed_Provenance.source_owner,
     slice:Veri7vn_Native_Literals.slice,
     samples:(Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice) list,
     work:int} -> request
  val live: request -> bool
  val dependencies: request -> IntInf.int list
  val inputs: request -> Veri7vn_Mathematics_Execution.request list
  val closures: request -> thm list
  val meanings: request -> cterm list
  val costs: request -> IntInf.int list
  val source_spans: request -> {source:IntInf.int,bytes:string,start:int,stop:int} list
  val observe: request -> int -> Veri7vn_Mathematics_Execution.output -> observation
  val release: request -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure I=Veri7vn_Native_Identity_Allocator;
  datatype observation=Observation of {sample:int,expected:term,actual:M.view,agrees:bool};
  type payload={scope:P.construction_scope,parent:P.development,development:P.development,
    sources:P.source_owner list,spans:(P.source_owner * L.slice) list,leases:L.lease list,instance:M.instance,
    inputs:M.request list,costs:IntInf.int list,closures:thm list,meanings:cterm list,expected:(term * (IntInf.int * IntInf.int) option) list};
  datatype request=Request of payload option Synchronized.var;
  fun require true _=() | require false message=error message;
  fun get(Request cell)=case Synchronized.value cell of SOME p=>p
    | NONE=>error "Growth preparation released";
  structure Syntax_Check=Veri7vn_Growth_Syntax;
  val rational=Syntax_Check.rational;
  val expression=Syntax_Check.expression;
  fun live request=(let val{parent,development,sources,leases,instance,...}=get request
      val _=List.app(fn lease=>ignore(L.lease_input lease))leases
    in P.development_live parent andalso P.development_live development andalso
      forall(fn source=>L.retained(P.source_input source))sources andalso
      can M.operation instance end) handle ERROR _=>false;
  fun checked request=(require(live request)"Growth native/source owner unavailable";get request);
  fun inputs request= #inputs(checked request);
  fun closures request= #closures(checked request);
  fun meanings request= #meanings(checked request);
  fun costs request= #costs(checked request);
  fun source_spans request=map(fn(source,slice)=>
    let val{start,stop}=L.offsets slice
    in {source=P.source_identity source,bytes=L.bytes(L.owner slice),start=start,stop=stop} end)
    (#spans(checked request));
  fun dependencies request=let val{development,sources,...}=checked request
    in distinct(op =)(P.development_dependencies development @ map P.source_identity sources) end;
  fun release(Request cell)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Synchronized.change cell(fn NONE=>NONE | SOME {scope,leases,inputs,sources,...}=>
      (List.app M.release_request inputs;
       List.app(fn lease=>ignore(L.release lease))leases;
       P.abort_scope scope;
       List.app(fn source=>let val input=P.source_input source
         in if L.disposed input then I.release_disposed_input input else ()end)sources;
       NONE)))();
  fun prepare_internal definition instance {parent,expression=(source,slice),samples,work} =
    let
      val _=require(P.development_live parent)"Growth parent unavailable";
      val _=require(work>0 andalso work<=4096)"Growth work bound";
      val _=require(not(null samples) andalso length samples<=32)"Growth sample count bound";
      fun owned(s,span)=
        (require(P.owns_input s(L.owner span))"Growth source ownership mismatch";
         require(P.source_workspace s=P.development_workspace parent)"Growth workspace mismatch";
         require(L.encoding(L.owner span)="UTF-8" andalso size(L.original span)<=16384)
           "Growth source encoding/byte bound");
      val _=List.app owned ((source,slice)::samples);
      val scope=P.construction_scope();
      val leases=Unsynchronized.ref([]:L.lease list);
      val prepared=Unsynchronized.ref([]:M.request list);
      fun cleanup()=Thread_Attributes.uninterruptible(fn _=>fn()=>
        (List.app M.release_request(!prepared);
        List.app(fn lease=>Option.app I.release_disposed_input(L.release lease))(!leases);
        P.abort_scope scope))();
      val attempted=Exn.capture(fn()=>
        let
          val _=List.app(fn(s,_)=>Thread_Attributes.uninterruptible(fn _=>fn()=>
            leases:=L.retain(P.source_input s)::(!leases))())((source,slice)::samples);
          val ctxt=R.context(P.generation parent);
          val raw=case definition of NONE =>
              (Syntax.read_term ctxt(L.original slice)
                |> Type.constraint @{typ math_expr} |> Syntax.check_term ctxt)
            | SOME fact =>
              let val _=require(P.is_live fact andalso
                    member(op =)(P.source_dependencies fact)(P.source_identity source))
                    "Growth definition lacks exact source dependency";
                val _=require(forall (member(op =)(P.development_dependencies parent))
                  (P.dependencies fact))"Growth definition outside native owner closure";
                val theorem=A.theorem(P.accepted fact);
                val _=require(null(Thm.hyps_of theorem) andalso Thm.nprems_of theorem=0)
                  "Growth definition has assumptions";
                val(_,rhs)=Logic.dest_equals(Thm.prop_of theorem)
              in rhs end;
          val _=require(fastype_of raw = @{typ math_expr} andalso
            Term.size_of_term raw<=2048)"Growth expression type/node bound";
          val _=expression 0 raw;
          val development=case definition of SOME _=>parent | NONE=>
            let val(development,_,fact)=P.define_from_slice_owned scope parent source
                  (Binding.name("growth_candidate_"^string_of_int(serial())))slice;
              val(_,rhs)=Logic.dest_equals(Thm.prop_of(A.theorem(P.accepted fact)))
              val _=require(rhs aconv raw)"Growth definition differs from original expression"
            in development end;
          val native_ctxt=R.context(P.generation development);
          val simp_ctxt=put_simpset HOL_ss native_ctxt addsimps @{thms close_expression.simps};
          fun sample(s,span)=
            let val packet=Syntax.read_term native_ctxt(L.original span)
                  |> Type.constraint @{typ "(nat * rat) list * rat option"}
                  |> Syntax.check_term native_ctxt;
              val _=require(Term.size_of_term packet<=4096)"Growth sample node bound";
              val(bindings,expected)=HOLogic.dest_prod packet;
              val _=Syntax_Check.bindings bindings;
              val expectation=(case expected of Const(name,_)=>
                  if name= @{const_name None} then NONE else error "Expected optional rational"
                | Const(name,_) $ q=>if name= @{const_name Some} then SOME(rational q)
                  else error "Expected optional rational"
                | _=>error "Expected optional rational");
              val close = @{term close_expression} $ bindings $ raw;
              val equality=Simplifier.rewrite simp_ctxt(Thm.cterm_of native_ctxt close);
              val closed=case Thm.term_of(Thm.rhs_of equality) of
                  Const(name,_) $ value=>if name= @{const_name Some} then value
                    else error "Growth sample closure failed"
                | _=>error "Growth sample missing parameter";
              val input = @{term closed_expression_run} $ HOLogic.mk_number @{typ nat} work $ closed;
              val request=Thread_Attributes.uninterruptible(fn _=>fn()=>
                let val request=case M.prepare(M.executable())instance
                      (Thm.cterm_of (Proof_Context.init_global
                        (Veri7vn_Executable_Identity.code_theory(M.executable()))) input) of
                    M.Ready request=>request
                  | M.Refused _=>error "Installed mathematics refused growth input"
                  val _=prepared:=request::(!prepared)
                in request end)();
              val meaning=Thm.cterm_of native_ctxt (HOLogic.mk_Trueprop
                (@{term closed_expression_meaning} $ HOLogic.mk_number @{typ nat} work $
                  closed $ input))
              val cost=case M.modeled_cost request of M.Ready cost=>cost
                | _=>error "Growth modeled cost unavailable"
            in (request,(expected,expectation),equality,meaning,cost) end;
          val results=map sample samples;
        in Request(Synchronized.var "growth_preparation"(SOME{scope=scope,parent=parent,
          development=development,sources=map fst((source,slice)::samples),spans=(source,slice)::samples,leases= !leases,
          instance=instance,inputs=map #1 results,expected=map #2 results,
          closures=map #3 results,meanings=map #4 results,costs=map #5 results})) end)();
    in case attempted of Exn.Res request=>request | Exn.Exn exn=>(cleanup();Exn.reraise exn) end;
  fun prepare instance args=prepare_internal NONE instance args;
  fun prepare_definition instance {development,definition,source,slice,samples,work}=
    prepare_internal (SOME definition) instance {parent=development,
      expression=(source,slice),samples=samples,work=work};
  fun observe request index output =
    let val{inputs,expected,...}=checked request;
      val _=require(index>=0 andalso index<length inputs)"Growth sample index bound";
      val input=nth inputs index;
      val _=require(M.belongs_to input output)"Growth output belongs to another sample";
      val(expected_term,wanted)=nth expected index;
      val actual=case M.output_view output of M.Ready value=>value
        | M.Refused _=>error "Growth output unavailable";
      val agrees=case(actual,wanted)of
          (M.Exact_Rational(n,d),SOME(a,b))=>n*b=a*d
        | (M.Undefined_Arithmetic,NONE)=>true | _=>false;
    in ignore(checked request);
      Observation{sample=index,expected=expected_term,actual=actual,agrees=agrees} end;
end;

(* The private service instantiates this functor with its actual D43 producer.
   There is no constructor from a candidate number or metadata document. *)
functor Veri7vn_Growth_Candidate_Fn(Builder:VERI7VN_NATIVE_BUILD_CANDIDATE) :>
sig
  type request
  val prepare: Builder.candidate -> Veri7vn_Mathematics_Execution.instance ->
    {definition:Thm_Name.T,
     samples:(Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice) list,
     work:int} -> request
  val candidate: request -> Builder.candidate
  val preparation: request -> Veri7vn_Growth_Preparation.request
  val live: request -> bool
  val dependencies: request -> IntInf.int list
  val release: request -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure G=Veri7vn_Growth_Preparation;
  datatype request=Request of {candidate:Builder.candidate,preparation:G.request,scope:P.construction_scope};
  fun live(Request{candidate,preparation,...})=Builder.is_live candidate andalso G.live preparation;
  fun check request=if live request then () else error "Growth candidate unavailable";
  fun candidate(request as Request{candidate,...})=(check request;candidate);
  fun preparation(request as Request{preparation,...})=(check request;preparation);
  fun dependencies(request as Request{candidate,preparation,...})=
    (check request;distinct(op =)(#candidate(Builder.projection candidate) ::
      Builder.retention_dependencies candidate @ G.dependencies preparation));
  fun release(Request{preparation,scope,...})=(G.release preparation;P.abort_scope scope);
  fun prepare candidate instance {definition,samples,work}=
    let val _=if Builder.is_live candidate then () else error "Growth candidate released";
      val development=Builder.development candidate;
      val{source,slice,...}=Builder.recipe candidate;
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val scope=P.construction_scope()
        val attempt=Exn.capture(fn()=>
          let val fact=P.named_theorem_owned scope development definition
            val preparation=restore(G.prepare_definition instance)
              {development=development,definition=fact,source=source,slice=slice,samples=samples,work=work}
          in Request{candidate=candidate,preparation=preparation,scope=scope}end)()
      in case attempt of Exn.Res request=>request | Exn.Exn exn=>
        (P.abort_scope scope;Exn.reraise exn)end)() end;
end;
