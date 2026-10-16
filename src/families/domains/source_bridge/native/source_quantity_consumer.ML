(* Closed internal ingress. Only the source owner's actual opaque cell producer
   can instantiate this view. It owns no issuer, registry or publication machine.
   Assembly must retain this wrapper, rather than publish through an extracted D. *)
functor Veri7vn_Source_Quantity_Consumer_Fn
  (Cell: VERI7VN_QUALIFIED_SOURCE_CELL) :>
sig
  type request
  type cell = Cell.qualified_cell
  datatype unit_profile = Metres | Centimetres | Millimetres | Newtons |
    NewtonsPerMetre | Kilograms | Grams
  datatype refusal = SourceUnavailable | UnitMismatch of {expected:string,reported:string}
    | InvalidAssociation of string
  datatype prepared = Prepared of request | Refused of refusal
  type preparation = {child:Veri7vn_Native_Request_Scope.child,
    instance:Veri7vn_Domain_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    operation_source:Veri7vn_Managed_Provenance.source_owner,
    operation:cterm,
    cells:(cell * unit_profile) list,
    conditions:Veri7vn_Domain_Conditions.condition list}
  val prepare_child: preparation -> prepared
  val prepare_child_into: preparation -> request option Unsynchronized.ref -> prepared
  val prepare: preparation -> prepared
  val prepare_into: preparation -> request option Unsynchronized.ref -> prepared
  type saved_source={integer:IntInf.int,metadata:Cell.metadata,
    coordinates:{row:IntInf.int,column:IntInf.int},profile:string,
    native_input:term,requirement:term,observation:term,acquisition:term,associated:term,quantity_fact:term,
    dependencies:IntInf.int list}
  type saved={domain:Veri7vn_Domain_Request.saved,sources:saved_source list,
    operation:term,operation_source:IntInf.int,operation_bytes:string,
    operation_encoding:string,operation_span:int*int,
    child_identity:Veri7vn_Native_Request_Scope.identity,dependencies:IntInf.int list}
  val snapshot: request -> saved
  val matches_snapshot: request -> saved -> bool
  val reconstruct: preparation ->
    {derivative_source:Veri7vn_Managed_Provenance.source_owner,saved:saved} -> prepared
  val reconstruct_into: preparation ->
    {derivative_source:Veri7vn_Managed_Provenance.source_owner,saved:saved} ->
    request option Unsynchronized.ref -> prepared
  val child: request -> Veri7vn_Native_Request_Scope.child
  val derivative_source: request -> Veri7vn_Managed_Provenance.source_owner
  val live: request -> bool
  val managed_dependencies: request -> IntInf.int list
  val input: request -> cterm
  type source_view = {metadata:Cell.metadata,coordinates:{row:IntInf.int,column:IntInf.int},
    observation:cterm,selection:cterm,acquisition:cterm,associated:cterm,
    unit_profile:cterm,value:cterm}
  val source_views: request -> source_view list
  val source_bindings: request -> Cell.native_binding list
  val source_quantity_facts: request -> thm list
  val condition_associations: request -> Veri7vn_Domain_Conditions.condition list
  (* Fixed owner-only execution access. This raw bundle request is no authority
     for publication: specialize/result_view below recheck the complete wrapper. *)
  val instance: request -> Veri7vn_Domain_Execution.instance
  val family_request: request -> Veri7vn_Domain_Execution.request
  type result_view = {domain:Veri7vn_Domain_Request.result_view,sources:source_view list}
  val result_view: request -> Veri7vn_Domain_Execution.output -> result_view
  val specialize: request -> Veri7vn_Domain_Execution.output -> cterm
  structure Gate: VERI7VN_SOURCE_DOMAIN_GATE
    where type request=request and type request_saved=saved and type source_view=source_view
  val retain: request -> request
  val release: request -> unit
end =
struct
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  structure C=Veri7vn_Domain_Conditions;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure S=Veri7vn_Native_Request_Scope;
  type cell=Cell.qualified_cell;
  datatype unit_profile=Metres | Centimetres | Millimetres | Newtons |
    NewtonsPerMetre | Kilograms | Grams;
  datatype refusal=SourceUnavailable | UnitMismatch of {expected:string,reported:string}
    | InvalidAssociation of string;
  exception Rejected of refusal;
  datatype prepared=Prepared of request | Refused of refusal
  and request=Request of ((int * payload option) Synchronized.var) option Synchronized.var
  withtype held_cell={cell:cell,lease:Cell.lease,binding:Cell.native_binding,profile:unit_profile,fact:thm}
  and payload={domain:D.request,child:S.child,cells:held_cell list,operation_source:P.source_owner,
    derivative_source:P.source_owner,
    operation_owner:L.input,operation_lease:L.lease,derivative:L.input,derivative_owned:bool,
    operation:cterm,operation_slice:L.slice,dependencies:IntInf.int list};
  fun description Metres=("m",@{term SourceMetres},@{term Metre})
    | description Centimetres=("cm",@{term SourceCentimetres},@{term Centimetre})
    | description Millimetres=("mm",@{term SourceMillimetres},@{term Millimetre})
    | description Newtons=("N",@{term SourceNewtons},@{term Newton})
    | description NewtonsPerMetre=("N/m",@{term SourceNewtonsPerMetre},@{term NewtonPerMetre})
    | description Kilograms=("kg",@{term SourceKilograms},@{term Kilogram})
    | description Grams=("g",@{term SourceGrams},@{term Gram});
  fun numeral ctxt typ n=
    let val text=(if n<0 then "-" ^ IntInf.toString(~n) else IntInf.toString n)
    in Syntax.read_term ctxt ("(" ^ text ^ " :: " ^ typ ^ ")") end;
  fun nat ctxt n=if n<0 then error "Negative protected source coordinate" else numeral ctxt "nat" n;
  fun cell_value generation (cell,profile)=
    let
      val _=if Cell.is_live cell then () else raise Rejected SourceUnavailable;
      val binding=Cell.native_binding cell;
      val _=if R.same_generation(generation,Cell.generation binding) then ()
        else error "Source quantity source/domain native generations differ";
      val ctxt=R.context generation;
      val (name,profile_term,unit_term)=description profile;
      val actual= #reported_unit(Cell.metadata cell);
      val _=if actual=name then () else raise Rejected(UnitMismatch{expected=name,reported=actual});
      val {row,column}=Cell.coordinates cell;
      val row_term=nat ctxt row;
      val column_term=nat ctxt column;
      val exact_term=numeral ctxt "int" (Cell.integer cell);
      val observation=Thm.term_of(Cell.native_observation binding);
      val expected_input=HOLogic.mk_prod(observation,HOLogic.mk_prod(row_term,column_term));
      val expected_requirement=HOLogic.mk_Trueprop
        (@{term source_cell_selection_meaning} $ observation $ row_term $ column_term $
          exact_term $ HOLogic.mk_string name);
      val accepted=Cell.specialization binding;
      val _=if Thm.term_of(Cell.native_input binding) aconv expected_input andalso
        Thm.term_of(Cell.native_requirement binding) aconv expected_requirement andalso
        Thm.term_of(A.target accepted) aconv expected_requirement andalso
        forall(fn qualification=>R.same_generation(generation,A.generation qualification) andalso
          null(A.observed_oracles qualification) andalso
          null(Thm.hyps_of(A.theorem qualification)) andalso
          Thm.nprems_of(A.theorem qualification)=0)
          [accepted,Cell.acquisition_qualification binding,Cell.associated_specialization binding] then ()
        else error "Protected source cell getters differ from exact selected-cell judgment";
      val bridge=Drule.infer_instantiate ctxt
        [(("obs",0),Thm.cterm_of ctxt observation),(("row",0),Thm.cterm_of ctxt row_term),
         (("column",0),Thm.cterm_of ctxt column_term),(("exact",0),Thm.cterm_of ctxt exact_term),
         (("unit",0),Thm.cterm_of ctxt profile_term)] @{thm source_cell_quantity_bridge}
        |> Simplifier.simplify (fold Simplifier.add_simp
          @{thms source_unit_name.simps source_linear_unit.simps} (put_simpset HOL_basic_ss ctxt));
      val fact=Thm.implies_elim bridge (A.theorem accepted);
      val magnitude= @{term "of_int :: int => rat"} $ exact_term;
      val value= @{term LinearValue} $ unit_term $ magnitude;
    in (value,fact) end;
  fun get(Request root)=(case Synchronized.value root of
      SOME shared=>(case #2(Synchronized.value shared)of SOME p=>p
        | NONE=>error "Source quantity consumer disposed")
    | NONE=>error "Source quantity consumer released");
  fun new_request payload=Request(Synchronized.var "source_quantity_view"
    (SOME(Synchronized.var "source_quantity_shared"(1,SOME payload))));
  fun retain(Request root)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result root(fn current=>case current of NONE=>
        error "Source quantity consumer released"
      | SOME shared=>let
          val view=Request(Synchronized.var "source_quantity_view"(SOME shared));
          val _=Synchronized.change shared(fn(count,payload)=>case payload of
            NONE=>error "Source quantity consumer disposed"
          | SOME _=>(count+1,payload));
        in(view,current)end));
  fun live r=(let val{domain,child,cells,operation_source,operation_owner,operation_lease,...}=get r
      val _=ignore(L.lease_input operation_lease)
    in S.child_live child andalso D.live domain andalso P.owns_input operation_source operation_owner andalso
      forall(fn{cell,lease,...}:held_cell=>Cell.is_live cell andalso
        Cell.same_cell(cell,Cell.retained_cell lease))cells end) handle ERROR _=>false;
  fun checked r=if live r then get r else error "Source quantity ancestry unavailable";
  fun child r= #child(checked r);
  fun derivative_source r= #derivative_source(checked r);
  fun managed_dependencies r= #dependencies(checked r);
  fun input r=D.input(#domain(checked r));
  type source_view={metadata:Cell.metadata,coordinates:{row:IntInf.int,column:IntInf.int},
    observation:cterm,selection:cterm,acquisition:cterm,associated:cterm,
    unit_profile:cterm,value:cterm};
  type result_view={domain:D.result_view,sources:source_view list};
  fun source_bindings r=map #binding (#cells(checked r));
  fun source_quantity_facts r=map #fact (#cells(checked r));
  fun condition_associations r=D.condition_associations(#domain(checked r));
  fun source_views r=map(fn{cell,binding,profile,fact,...}:held_cell=>
    let val ctxt=R.context(Cell.generation binding);
      val (_,profile_term,_)=description profile;
      val args= #2(strip_comb(HOLogic.dest_Trueprop(Thm.prop_of fact)));
      val value=(case args of [_,_,_,_,quantity]=>Thm.cterm_of ctxt quantity
        | _=>error "Source quantity fact shape changed")
    in {metadata=Cell.metadata cell,coordinates=Cell.coordinates cell,
      observation=Cell.native_observation binding,selection=Cell.native_requirement binding,
      acquisition=A.target(Cell.acquisition_qualification binding),
      associated=A.target(Cell.associated_specialization binding),
      unit_profile=Thm.cterm_of ctxt profile_term,value=value}:source_view end)(#cells(checked r));
  fun instance r=D.instance(#domain(checked r));
  fun family_request r=D.family_request(#domain(checked r));
  fun retain_cells [] held=rev held
    | retain_cells ((cell,profile,fact)::rest)held=
      (case Exn.capture (fn()=>
         let val lease=Cell.retain cell;
           val child=Exn.capture(fn()=>
             let val retained=Cell.retained_cell lease;
               val _=if Cell.same_cell(cell,retained)then () else error "Source cell lease changed selection";
             in {cell=retained,lease=lease,binding=Cell.native_binding retained,
               profile=profile,fact=fact}:held_cell end)()
         in case child of Exn.Res value=>value | Exn.Exn failure=>
           (Cell.release_lease lease;Exn.reraise failure) end)() of
         Exn.Res owned=>retain_cells rest(owned::held)
       | Exn.Exn failure=>(List.app(fn{lease,...}:held_cell=>Cell.release_lease lease)held;
           Exn.reraise failure));
  type preparation={child:S.child,instance:M.instance,development:P.development,
    operation_source:P.source_owner,operation:cterm,
    cells:(cell*unit_profile)list,conditions:C.condition list};
  fun prepare_internal derivative_source {child,instance,development,operation_source,
      operation,cells,conditions} owned=
    let
      val _=if is_none(!owned) then () else error "Source quantity caller ownership root is occupied";
      val generation=A.generation(M.contract instance);
      val ctxt=R.context generation;
      val parent=S.parent child;
      val allocator=S.allocator parent;
      val workspace=I.workspace allocator;
      val operation_slice=S.source child;
      val original=L.owner operation_slice;
      val _=if S.child_live child andalso forall(fn(cell,_)=>
          let val predecessor=Cell.scope_child cell
          in S.same_parent(parent,S.parent predecessor) andalso
            exists(fn prior=>S.same_child(prior,predecessor))(S.predecessors child) end)cells
        then () else error "SourceDomain child lost same-parent source-cell predecessors";
      val _=if length cells<=8192 andalso not(null cells) andalso
        P.development_live development andalso P.development_workspace development=workspace andalso
        P.source_workspace operation_source=workspace andalso P.owns_input operation_source original andalso
        R.same_generation(generation,P.generation development) then ()
        else error "Source quantity operation declaration ownership/context mismatch";
      val operation=Thm.transfer_cterm(Proof_Context.theory_of ctxt)operation;
      val t=Thm.term_of operation;
      val original_text=L.original operation_slice;
      val _=if size original_text<=65536 andalso Term.size_of_term t<=20000 andalso
        fastype_of t= @{typ domain_operation} andalso null(Term.add_frees t []) andalso
        null(Term.add_vars t []) then () else error "Source quantity operation declaration bound/type";
      val parsed=Timeout.apply(Time.fromSeconds 5)(Syntax.read_term ctxt)original_text;
      val _=if parsed aconv t then () else error "Source quantity operation differs from original declaration";
      val projected=map (cell_value generation) cells;
      val values=HOLogic.mk_list @{typ domain_value} (map fst projected);
      val condition_ids=map C.identity (filter(fn c=>C.role c=C.InputCondition)conditions);
      val models=filter(fn c=>C.role c=C.IdealSpringModel)conditions;
      val model=(case models of []=>@{term "None :: nat option"}
        | [c]=>@{term "Some :: nat => nat option"} $ nat ctxt(C.identity c)
        | _=>error "Multiple source quantity model declarations");
      val call= @{term registered_domain_dispatch} $
        (@{term DomainCall} $ t $ values $ HOLogic.mk_list @{typ nat}(map(nat ctxt)condition_ids) $ model);
      val call_ct=Thm.cterm_of ctxt call;
      val text=Syntax.string_of_term (Config.put show_types true ctxt)call;
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val derivative_owned=is_none derivative_source;
      val _=if derivative_owned then S.claim child else ();
      val derivative=(case derivative_source of NONE=>L.input{bytes=text,encoding="UTF-8"}
        | SOME restored=>P.source_input restored);
      fun dispose_derivative()=if derivative_owned
        then Option.app I.release_disposed_input(L.drop_base derivative) else ();
      val source=(case derivative_source of SOME restored=>
          if P.source_workspace restored=workspace andalso P.owns_input restored derivative andalso
            L.bytes derivative=text andalso L.encoding derivative="UTF-8"
          then restored else error "Restored derivative differs from reconstructed exact source call"
        | NONE=>(case Exn.capture (P.install_host_source allocator) derivative of
          Exn.Res owner=>owner | Exn.Exn failure=>(dispose_derivative();Exn.reraise failure)));
      val slice=L.slice derivative{start=0,stop=size text,expected=text};
      val leases=Exn.capture(fn()=>retain_cells
        (map (fn ((cell,profile),(_,fact))=>(cell,profile,fact)) (cells ~~ projected))[])();
      val held=(case leases of Exn.Res value=>value
        | Exn.Exn failure=>(dispose_derivative();Exn.reraise failure));
      val owner_lease=Exn.capture L.retain original;
      val op_lease=(case owner_lease of Exn.Res value=>value
        | Exn.Exn failure=>(List.app(fn{lease,...}:held_cell=>Cell.release_lease lease)held;
          dispose_derivative();Exn.reraise failure));
      val owned_child=(case Exn.capture S.retain_child child of Exn.Res value=>value
        | Exn.Exn failure=>(List.app(fn{lease,...}:held_cell=>Cell.release_lease lease)held;
          Option.app I.release_disposed_input(L.release op_lease);dispose_derivative();Exn.reraise failure));
      val domain_root=Unsynchronized.ref(NONE:D.request option);
      val built=Exn.capture(fn()=>
        let val domain=restore(fn()=>D.prepare_into
          {allocator=allocator,instance=instance,development=development,
           source=source,slice=slice,input=call_ct,conditions=conditions} domain_root)();
          val dependencies=distinct(op =)(P.source_identity operation_source::
            D.managed_dependencies domain @ maps(fn{cell,...}:held_cell=>Cell.dependencies cell)held)
        in new_request{domain=domain,child=owned_child,cells=held,derivative_source=source,
          operation_source=operation_source,operation_owner=original,operation_lease=op_lease,
          derivative=derivative,derivative_owned=derivative_owned,operation=operation,operation_slice=operation_slice,dependencies=dependencies} end)();
    in case built of Exn.Res r=>if live r then (owned:=SOME r;Prepared r)
        else (release r;Refused SourceUnavailable)
      | Exn.Exn failure=>(Option.app D.release (!domain_root);S.release_child owned_child;
          List.app(fn{lease,...}:held_cell=>Cell.release_lease lease)held;
          Option.app I.release_disposed_input(L.release op_lease);
          dispose_derivative();Exn.reraise failure)
      end)()
    end
  and release(Request root)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result root(fn previous=>(previous,NONE))of NONE=>()
    | SOME shared=>(case Synchronized.change_result shared(fn(count,payload)=>
        if count=1 then(payload,(0,NONE))else(NONE,(count-1,payload)))of NONE=>()
      | SOME{domain,child,cells,operation_lease,derivative,derivative_owned,...}=>
        (D.release domain;S.release_child child;
         List.app(fn{lease,...}:held_cell=>Cell.release_lease lease)cells;
         Option.app I.release_disposed_input(L.release operation_lease);
         if derivative_owned then Option.app I.release_disposed_input(L.drop_base derivative) else ())));
  fun prepare_into args owned=(prepare_internal NONE args owned handle Rejected reason=>Refused reason
    | ERROR text=>Refused(InvalidAssociation text)
    | THM(text,_,_)=>Refused(InvalidAssociation text));
  fun prepare args=prepare_into args(Unsynchronized.ref NONE);
  val prepare_child=prepare;
  val prepare_child_into=prepare_into;
  type saved_source={integer:IntInf.int,metadata:Cell.metadata,
    coordinates:{row:IntInf.int,column:IntInf.int},profile:string,
    native_input:term,requirement:term,observation:term,acquisition:term,associated:term,quantity_fact:term,
    dependencies:IntInf.int list};
  type saved={domain:D.saved,sources:saved_source list,
    operation:term,operation_source:IntInf.int,operation_bytes:string,
    operation_encoding:string,operation_span:int*int,child_identity:S.identity,dependencies:IntInf.int list};
  fun snapshot r=
    let val{domain,child,cells,operation,operation_source,operation_owner,operation_slice,dependencies,...}=checked r;
      fun source({cell,binding,profile,fact,...}:held_cell):saved_source=
        {integer=Cell.integer cell,metadata=Cell.metadata cell,coordinates=Cell.coordinates cell,
          profile= #1(description profile),native_input=Thm.term_of(Cell.native_input binding),
          requirement=Thm.term_of(Cell.native_requirement binding),
          observation=Thm.term_of(Cell.native_observation binding),
          acquisition=Thm.term_of(A.target(Cell.acquisition_qualification binding)),
          associated=Thm.term_of(A.target(Cell.associated_specialization binding)),quantity_fact=Thm.prop_of fact,
          dependencies=Cell.dependencies cell};
      val{start,stop}=L.offsets operation_slice;
    in {domain=D.snapshot domain,sources=map source cells,operation=Thm.term_of operation,
      operation_source=P.source_identity operation_source,operation_bytes=L.bytes operation_owner,
      operation_encoding=L.encoding operation_owner,operation_span=(start,stop),
      child_identity=S.identity child,dependencies=dependencies}:saved end;
  (* Saved terms and IDs never create a source cell or native request. Recovery
     must reconstruct both actual associations, call prepare, then compare. *)
  fun matches_snapshot r (saved:saved)=
    let val actual=snapshot r;
      fun same_source(a:saved_source,b:saved_source)=
        #integer a= #integer b andalso #metadata a= #metadata b andalso
        #coordinates a= #coordinates b andalso #profile a= #profile b andalso
        #native_input a aconv #native_input b andalso #requirement a aconv #requirement b andalso
        #observation a aconv #observation b andalso #acquisition a aconv #acquisition b andalso
        #associated a aconv #associated b andalso #quantity_fact a aconv #quantity_fact b andalso
        #dependencies a= #dependencies b
    in D.matches_snapshot(#domain(checked r))(#domain saved) andalso
      ListPair.allEq same_source(#sources actual,#sources saved) andalso
      #operation actual aconv #operation saved andalso
      #operation_source actual= #operation_source saved andalso
      #operation_bytes actual= #operation_bytes saved andalso
      #operation_encoding actual= #operation_encoding saved andalso
      #operation_span actual= #operation_span saved andalso
      #child_identity actual= #child_identity saved andalso
      #dependencies actual= #dependencies saved end handle ERROR _=>false;
  fun reconstruct_into args {derivative_source,saved} owned=
    ((case prepare_internal(SOME derivative_source)args owned of
      Prepared r=>if matches_snapshot r saved then Prepared r
        else Thread_Attributes.uninterruptible_body(fn _=>
          (release r;owned:=NONE;
           Refused(InvalidAssociation "Reconstructed source/domain correspondence differs")))
    | refused=>refused) handle Rejected reason=>Refused reason
      | ERROR text=>Refused(InvalidAssociation text)
      | THM(text,_,_)=>Refused(InvalidAssociation text));
  fun reconstruct args saved=reconstruct_into args saved(Unsynchronized.ref NONE);
  fun result_view r output=
    let val domain=D.result_view(#domain(checked r))output
    in {domain=domain,sources=source_views r}:result_view end;
  fun specialize r output=
    let val{domain,cells,...}=checked r;
      val domain_target=HOLogic.dest_Trueprop(Thm.term_of(D.specialize domain output));
      val facts=maps(fn{binding,fact,...}:held_cell=>
        [HOLogic.dest_Trueprop(Thm.term_of(A.target(Cell.acquisition_qualification binding))),
         HOLogic.dest_Trueprop(Thm.term_of(A.target(Cell.associated_specialization binding))),
         HOLogic.dest_Trueprop(Thm.prop_of fact)]) cells;
      val target=fold_rev (fn source_fact=>fn rest=>HOLogic.mk_conj(source_fact,rest)) facts domain_target;
      val generation=A.generation(M.contract(D.instance domain));
      val _=if live r then () else error "Source quantity ancestry changed during specialization";
    in Thm.cterm_of(R.context generation)(HOLogic.mk_Trueprop target) end;
  (* Fixed lexical gate factory: its D access never escapes the opaque Q API. *)
  structure Gate=Veri7vn_Source_Domain_Gate_Fn
    (struct
      type source_request=request;
      type request=source_request;
      type source_saved=saved;
      type saved=source_saved;
      type cell_source_view=source_view;
      type source_view=cell_source_view;
      val retain=retain;
      val release=release;
      val live=live;
      val family_request=family_request;
      val managed_dependencies=managed_dependencies;
      val source_views=source_views;
      val condition_associations=condition_associations;
      val specialize=specialize;
      val snapshot=snapshot;
      val matches_snapshot=matches_snapshot;
      fun domain_gate_into bridge request output owned=
        Veri7vn_Domain_Native_Gate.specialize_into bridge (#domain(checked request)) output owned;
    end);

end;
