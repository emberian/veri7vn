(* Closed charged observer. No payload constructor, batch accessor, issuer or
   publication constructor is exported. The fixed SourceDomain bridge consumes
   only the opaque qualified-cell interface below. *)
functor Veri7vn_Source_Cell_Producer_Fn
  (structure Source:VERI7VN_COMMON_SOURCE_OWNER
   structure Tickets:VERI7VN_OPERATION_TICKET_VIEW) :>
sig
  include VERI7VN_QUALIFIED_SOURCE_CELL
  type request
  type snapshot=Source.snapshot
  datatype refusal=SelectionRefused of Veri7vn_Source_Cell_Code.source_cell_refusal
    | ResourceBound
  datatype result=Selected of qualified_cell | Refused of refusal
  type ticket_payload={executable:Veri7vn_Executable_Identity.pin,request:request}
  val prepare:{snapshot:snapshot,child:Veri7vn_Native_Request_Scope.child,
    owner:Veri7vn_Managed_Provenance.source_owner}->request
  val prepare_into:{snapshot:snapshot,child:Veri7vn_Native_Request_Scope.child,
    owner:Veri7vn_Managed_Provenance.source_owner}->request option Unsynchronized.ref->request
  val execute_into:ticket_payload Tickets.pure_ticket->qualified_cell option Unsynchronized.ref->result
  val modeled_cost:request->IntInf.int
  val executable:unit->Veri7vn_Executable_Identity.pin
  val execute:ticket_payload Tickets.pure_ticket->result
  val release_request:request->unit
end =
struct
  structure K=Veri7vn_Source_Cell_Kernel;
  structure C=Veri7vn_Source_Cell_Code;
  structure Q=Veri7vn_Source_Acquisition_Code;
  structure AK=Veri7vn_Source_Acquisition_Kernel;
  structure S=Veri7vn_Native_Request_Scope;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  type snapshot=Source.snapshot;
  type metadata={reported_unit:string,source_key:string,source_schema:string,
    configuration:string,source_version:string option};
  type preparation={witness:Source.input_witness,child:S.child,owner:P.source_owner,
    lease:L.lease,request:K.request,row:IntInf.int,column:IntInf.int,request_binding:thm};
  datatype request=Request of {key:serial,root:preparation option Synchronized.var};
  type selected={preparation:preparation,integer:IntInf.int,metadata:metadata,
    input:cterm,requirement:cterm,observation:cterm,specialization:A.accepted,
    associated:A.accepted};
  datatype qualified_cell=Cell of {key:serial,root:selected option Synchronized.var};
  datatype native_binding=Binding of qualified_cell;
  datatype lease=Lease of qualified_cell option Synchronized.var;
  datatype refusal=SelectionRefused of C.source_cell_refusal | ResourceBound;
  datatype result=Selected of qualified_cell | Refused of refusal;
  type ticket_payload={executable:E.pin,request:request};
  fun require true _=() | require false text=error text;
  fun preparation_live({witness,child,owner,lease,...}:preparation)=
    Source.witness_live witness andalso S.child_live child andalso
    (case try L.lease_input lease of NONE=>false | SOME input=>P.owns_input owner input);
  fun request_view(Request{root,...})=(case Synchronized.value root of NONE=>
    error "SourceCell request released" | SOME p=>
      (require(preparation_live p) "SourceCell ancestry unavailable";p));
  fun selected_view(Cell{root,...})=(case Synchronized.value root of NONE=>
    error "SourceCell handle released" | SOME p=>
      (require(preparation_live(#preparation p)) "SourceCell ancestry unavailable";p));
  fun natural n=HOLogic.mk_number HOLogic.natT (IntInf.toInt n);
  fun reprove ctxt proposition=
    Timeout.apply(Time.fromSeconds 5)(fn()=>
      Goal.prove ctxt [] [] (HOLogic.mk_Trueprop proposition)
        (fn {context,...}=>HEADGOAL(Code_Simp.dynamic_tac context)))();
  fun clone_preparation(p:preparation)=Thread_Attributes.uninterruptible_body(fn _=>
    let val witness=Source.clone_witness(#witness p);
      val result=Exn.capture L.retain (L.lease_input(#lease p))
    in case result of Exn.Exn failure=>(Source.release_witness witness;Exn.reraise failure)
      | Exn.Res lease=>
        let val child=(case Exn.capture S.retain_child (#child p) of Exn.Res child=>child
          | Exn.Exn failure=>(Source.release_witness witness;
            Option.app I.release_disposed_input(L.release lease);Exn.reraise failure))
        in {witness=witness,child=child,owner= #owner p,lease=lease,
        request= #request p,row= #row p,column= #column p,request_binding= #request_binding p} end end);
  fun dispose(p:preparation)=Thread_Attributes.uninterruptible_body(fn _=>
    (Source.release_witness(#witness p);S.release_child(#child p);
      Option.app I.release_disposed_input(L.release(#lease p))));
  fun prepare_into {snapshot,child,owner} cleanup=
    let val witness_root=Unsynchronized.ref(NONE:Source.input_witness option);
      val acquired=Exn.capture(fn()=>Source.transfer_into snapshot witness_root)();
      val witness=(case acquired of Exn.Res witness=>witness | Exn.Exn failure=>
        (Option.app Source.release_witness(!witness_root);Exn.reraise failure));
      val result=Exn.capture(fn()=>
        let val original=S.source child;
          val input=L.owner original;
          val ctxt=R.context(Source.generation witness);
          val text=L.original original;
          val _=require(S.child_live child andalso
            S.same_parent(S.parent child,S.parent(Source.child witness)) andalso
            exists(fn predecessor=>S.same_child(predecessor,Source.child witness))(S.predecessors child) andalso
            P.source_workspace owner=I.workspace(S.allocator(S.parent child)) andalso
            P.owns_input owner input andalso size text<=4096 andalso
            Context.subthy(K.theory,Proof_Context.theory_of ctxt)) "SourceCell protected child/source mismatch";
          val term=Term_XML.Decode.term_raw(YXML.parse_body text);
          val _=require(fastype_of term= @{typ source_cell_request} andalso
            null(Term.add_frees term []) andalso null(Term.add_vars term []) andalso
            YXML.string_of_body(Term_XML.Encode.term_raw term)=text) "SourceCell exact canonical request";
          val request=the(K.decode_request ctxt term);
          val C.SourceCellRequest(raw_row,raw_column)=request;
          val row=AK.integer_of_nat raw_row;
          val column=AK.integer_of_nat raw_column;
          val binding=reprove ctxt(HOLogic.mk_eq(term,@{term SourceCellRequest}$natural row$natural column));
        in Thread_Attributes.uninterruptible_body(fn _=>let
          val lease=L.retain input;
          val held_child=(case Exn.capture S.retain_child child of Exn.Res held=>held
            | Exn.Exn failure=>(Option.app I.release_disposed_input(L.release lease);Exn.reraise failure));
          val made=Exn.capture(fn()=>
            let val p={witness=witness,child=held_child,owner=owner,lease=lease,request=request,
              row=row,column=column,request_binding=binding};
              val _=S.claim child;
              val request=Request{key=serial(),root=Synchronized.var "source_cell_request"(SOME p)};
              val _=cleanup:=SOME request
            in request end)()
        in case made of Exn.Res prepared=>prepared
          | Exn.Exn failure=>(S.release_child held_child;Option.app I.release_disposed_input(L.release lease);Exn.reraise failure)
        end) end)()
    in case result of Exn.Res prepared=>prepared
      | Exn.Exn failure=>(Source.release_witness witness;Exn.reraise failure) end;
  fun prepare args=prepare_into args(Unsynchronized.ref NONE);
  fun executable()=K.executable;
  fun modeled_cost request=
    let val p=request_view request; val a=Source.association(#witness p)
      val rows=AK.integer_of_nat(Q.association_rows a)
      val columns=AK.integer_of_nat(Q.association_columns a)
      val payload=AK.integer_of_nat(Q.association_payload_bytes a)
    in 1+32*(payload+(rows+1)*(columns+1)) end;
  fun admit witness theorem=
    let val generation=Source.generation witness;
      val ctxt=R.context generation;
      val(h,registry)=R.insert generation "fixed-associated-source-cell"(R.Theorem theorem)R.empty
    in case A.admit(Source.policy witness)generation registry h A.Kernel
      {claim=A.exact_claim(Thm.cterm_of ctxt(Thm.prop_of theorem)),hypotheses=[],premises=[],sorts=Thm.shyps_of theorem} of
      A.Accepted accepted=>accepted | A.Rejected reasons=>error(space_implode "; " reasons) end;
  fun normalize ctxt term=Thm.rhs_of(Code_Simp.dynamic_conv ctxt(Thm.cterm_of ctxt term));
  fun native_string ctxt term=HOLogic.dest_string(Thm.term_of(normalize ctxt term));
  fun execute_into ticket cleanup=
    let val(identity,{executable,request}:ticket_payload)=Tickets.consume_pure ticket;
      val p=request_view request;
      val witness= #witness p;
      val child_id=S.identity(#child p);
      val binding=Source.receipt_binding witness;
      val operation= #operation identity;
      val support=distinct(op =)(P.source_identity(#owner p)::Source.dependencies witness);
      val _=require(E.same(executable,K.executable) andalso
        #implementation_artifact operation= #artifact(E.manifest K.executable) andalso
        #cost operation=modeled_cost request andalso #request operation= #request child_id andalso
        #slot identity= #slot child_id andalso #workspace operation= #workspace binding andalso
        #semantic_generation operation= #semantic_generation binding andalso
        List.all(member(op =)(#inputs operation))support) "SourceCell charged operation binding mismatch";
      val association=Source.association witness;
      val maxcell=AK.integer_of_nat(Q.association_max_cell_payload_bytes association);
    in if modeled_cost request>10000000 orelse maxcell>8192 then Refused ResourceBound
      else case Timeout.apply(Time.fromSeconds 5)(fn()=>K.run(#request p)association)() of
        C.SourceCellRefused reason=>Refused(SelectionRefused reason)
      | projected=>
        let val ctxt=R.context(Source.generation witness);
          val obs=Source.native_observation witness;
          val row=natural(#row p); val column=natural(#column p);
          val query= @{term project_source_cell}$Thm.term_of obs$row$column;
          val conversion=Timeout.apply(Time.fromSeconds 5)(Code_Simp.dynamic_conv ctxt)(Thm.cterm_of ctxt query);
          val native_result=Thm.rhs_of conversion;
          val actual_term= @{code "Code_Evaluation.term_of :: source_cell_projection => term"} projected;
          val actual_normal=normalize ctxt actual_term;
          val _=require(Thm.term_of native_result aconv Thm.term_of actual_normal) "SourceCell runtime/native projection disagreement";
          val(_,arguments)=strip_comb(Thm.term_of native_result);
          val(value,unit)=(case arguments of [value,unit]=>(value,unit)|_=>error "SourceCell success shape");
          val exact=IntInf.fromInt(#2(HOLogic.dest_number value));
          val reported_unit=HOLogic.dest_string unit;
          val projection_fact=HOLogic.mk_obj_eq conversion;
          val refinement=Drule.infer_instantiate ctxt
            [(("a",0),Source.native_association witness),(("obs",0),obs),
             (("row",0),Thm.cterm_of ctxt row),(("column",0),Thm.cterm_of ctxt column),
             (("value",0),Thm.cterm_of ctxt value),(("unit",0),Thm.cterm_of ctxt unit)]
            @{thm associated_source_cell_refinement};
          val facts=refinement |> (fn th=>Thm.implies_elim th(Source.association_meaning witness))
            |> (fn th=>Thm.implies_elim th(Source.observation_projection witness))
            |> (fn th=>Thm.implies_elim th projection_fact);
          val associated=facts RS @{thm conjunct1};
          val selected=facts RS @{thm conjunct2};
          val requirement=Thm.cterm_of ctxt(Thm.prop_of selected);
          val native_input=Thm.cterm_of ctxt(HOLogic.mk_prod(Thm.term_of obs,HOLogic.mk_prod(row,column)));
          val manifest= @{term association_manifest}$Thm.term_of(Source.native_association witness);
          val version=normalize ctxt(@{term source_version_known}$manifest);
          val version=(case strip_comb(Thm.term_of version)of(Const(name,_),[])=>
              if name= @{const_name None} then NONE else error "Source version shape"
            |(Const(name,_),[v])=>if name= @{const_name Some} then SOME(HOLogic.dest_string v)
              else error "Source version shape" | _=>error "Source version shape");
          val metadata={reported_unit=reported_unit,
            source_key=native_string ctxt(@{term "source_id :: qualified_batch_observation => string"}$Thm.term_of obs),
            source_schema=native_string ctxt(@{term "schema_version :: qualified_batch_observation => string"}$Thm.term_of obs),
            configuration=native_string ctxt(@{term "configuration :: qualified_batch_observation => string"}$Thm.term_of obs),
            source_version=version};
          val accepted=admit witness selected;
          val associated_accepted=admit witness associated;
        in Thread_Attributes.uninterruptible_body(fn _=>let
          val held=clone_preparation p;
          val built=Exn.capture(fn()=>Cell{key=serial(),root=Synchronized.var "qualified_source_cell"(SOME
            {preparation=held,integer=exact,metadata=metadata,input=native_input,requirement=requirement,
             observation=obs,specialization=accepted,associated=associated_accepted})})();
          val cell=(case built of Exn.Res cell=>cell|Exn.Exn failure=>(dispose held;Exn.reraise failure));
          val _=cleanup:=SOME cell;
        in if preparation_live held then Selected cell else
          (dispose held;cleanup:=NONE;error "SourceCell retired during projection") end) end
    end;
  fun execute ticket=execute_into ticket(Unsynchronized.ref NONE);
  fun release_request(Request{root,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app dispose(Synchronized.change_result root(fn p=>(p,NONE))));
  fun integer cell= #integer(selected_view cell);
  fun metadata cell= #metadata(selected_view cell);
  fun coordinates cell=let val p= #preparation(selected_view cell)
    in {row= #row p,column= #column p} end;
  fun native_binding cell=(ignore(selected_view cell);Binding cell);
  fun native_input(Binding cell)= #input(selected_view cell);
  fun native_requirement(Binding cell)= #requirement(selected_view cell);
  fun native_observation(Binding cell)= #observation(selected_view cell);
  fun specialization(Binding cell)= #specialization(selected_view cell);
  fun acquisition_qualification(Binding cell)=Source.acquisition_qualification
    (#witness(#preparation(selected_view cell)));
  fun associated_specialization(Binding cell)= #associated(selected_view cell);
  fun generation(Binding cell)=Source.generation(#witness(#preparation(selected_view cell)));
  fun dependencies cell=let val p= #preparation(selected_view cell)
    in distinct(op =)(P.source_identity(#owner p)::Source.dependencies(#witness p)) end;
  fun scope_child cell= #child(#preparation(selected_view cell));
  fun is_live cell=is_some(try selected_view cell);
  fun same_cell(Cell{key=a,...},Cell{key=b,...})=a=b;
  fun release(Cell{root,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app(fn p:selected=>dispose(#preparation p))(Synchronized.change_result root(fn p=>(p,NONE))));
  fun retain(cell as Cell{key,...})=Thread_Attributes.uninterruptible_body(fn _=>
    let val p=selected_view cell; val held=clone_preparation(#preparation p)
      val child=Cell{key=key,root=Synchronized.var "retained_source_cell"(SOME
        {preparation=held,integer= #integer p,metadata= #metadata p,input= #input p,
         requirement= #requirement p,observation= #observation p,
         specialization= #specialization p,associated= #associated p})}
    in Lease(Synchronized.var "source_cell_lease"(SOME child)) end);
  fun retained_cell(Lease root)=(case Synchronized.value root of SOME cell=>
      (ignore(selected_view cell);cell)|NONE=>error "SourceCell lease released");
  fun release_lease(Lease root)=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app release(Synchronized.change_result root(fn p=>(p,NONE))));
end;
