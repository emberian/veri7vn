theory Source_Quantity_Protected_Tests
  imports Veri7vn_Source_Quantity_Consumer.Source_Quantity_Consumer
    Veri7vn_Source_Cell_Producer.Source_Cell_Producer
begin

external_file "fixtures/centimetres.bin"
external_file "fixtures/stiffness.bin"
external_file "fixtures/metres.bin"
external_file "fixtures/unit-missing.bin"
external_file "fixtures/null.bin"

definition quantity_acquisition_settings where
 "quantity_acquisition_settings source config =
  \<lparr>settings_format_version=1,settings_source_key=source,settings_encoding=''UTF-8'',settings_schema=''source-row/1'',
   settings_version=AnyVersion,settings_origin=Measured,settings_configuration=config,
   settings_quality=''retain-source-status'',settings_calibration=None,
   settings_recipe=''source-row-codec/1'',settings_selection=''ordered rows'',
   settings_byte_limit=4096,settings_row_limit=8\<rparr>"
definition quantity_body where
 "quantity_body value = encode_wire (Source_Batch 1 [[Cell_Integer False [value]]] True)"
definition quantity_null_body where
 "quantity_null_body = encode_wire (Source_Batch 1 [[Cell_Null]] True)"
definition source_force_response :: "rat => rat => rat" where
 "source_force_response k x = k*x"
definition source_energy_response :: "rat => rat => rat" where
 "source_energy_response k x = k*x*x/2"

text \<open>This fixture calls the actual Common acquisition, SourceCell producer,
SourceDomain wrapper and charged domain worker. Private test tickets model already
charged commands; the generated resident reducer/journal is not exercised here.
Same-owner reconstruction is correspondence testing, not a restart or replay.\<close>
ML \<open>
local
 structure L=Veri7vn_Native_Literals;
 structure P=Veri7vn_Managed_Provenance;
 structure I=Veri7vn_Native_Identity_Allocator;
 structure A=Veri7vn_Native_Admission;
 structure R=Veri7vn_Native_Registry;
 structure N=Veri7vn_Native_Descriptor;
 structure E=Veri7vn_Executable_Identity;
 structure S=Veri7vn_Native_Request_Scope;
 structure C=Veri7vn_Domain_Conditions;
 structure M=Veri7vn_Domain_Execution;
 structure D=Veri7vn_Domain_Request;
 structure Private=Veri7vn_Private_Operation_Tickets();
 structure Common=Veri7vn_Common_Source_Fn(Private);
 structure Cells=Veri7vn_Source_Cell_Producer_Fn(structure Source=Common structure Tickets=Private);
 structure Q=Veri7vn_Source_Quantity_Consumer_Fn(Cells);
 structure Worker=Veri7vn_Domain_Ticket_Execution_Fn(structure Domain=M structure Tickets=Private);
 val ids=I.install_host_block{workspace="71717171717171717171717171717171",first=1,past=100000};
 val development=P.public_image ids(A.policy @{theory});
 val generation=P.generation development;
 val ctxt=R.context generation;
 val inputs=Unsynchronized.ref([]:L.input list);
 fun input bytes encoding=let val value=L.input{bytes=bytes,encoding=encoding}
   in inputs:=value:: !inputs;value end;
 fun owned bytes=let val value=input bytes "UTF-8" in(value,P.install_host_source ids value)end;
 fun slice value=L.slice value{start=0,stop=size(L.bytes value),expected=L.bytes value};
 fun canonical ct=YXML.string_of_body(Term_XML.Encode.term_raw(Thm.term_of ct));
 val settings_simp=fold Simplifier.add_simp @{thms quantity_acquisition_settings_def}
   (put_simpset HOL_basic_ss ctxt);
 fun settings ct=owned(canonical(Thm.rhs_of(Simplifier.rewrite settings_simp ct)));
 val cm_settings=settings @{cterm "quantity_acquisition_settings ''source-quantity-centimetres'' ''quantity-fixture/1:centimetres''"};
 val k_settings=settings @{cterm "quantity_acquisition_settings ''source-quantity-stiffness'' ''quantity-fixture/1:stiffness''"};
 val x_settings=settings @{cterm "quantity_acquisition_settings ''source-quantity-metres'' ''quantity-fixture/1:metres''"};
 val missing_settings=settings @{cterm "quantity_acquisition_settings ''source-quantity-unit-missing'' ''quantity-fixture/1:unit-missing''"};
 val null_settings=settings @{cterm "quantity_acquisition_settings ''source-quantity-null'' ''quantity-fixture/1:null''"};
 val query_text=canonical @{cterm "SourceCellRequest 0 0"};
 val(query_input,query_owner)=owned query_text;
 val op_convert="ConvertLinear Centimetre Metre";
 val op_spring="Spring SpringForce";
 val op_mismatch="ConvertLinear Centimetre Kilogram";
 val(op_input,op_owner)=owned(op_convert ^ "\n" ^ op_spring ^ "\n" ^ op_mismatch);
 val convert_slice=L.slice op_input{start=0,stop=size op_convert,expected=op_convert};
 val spring_slice=L.slice op_input{start=size op_convert+1,stop=size op_convert+1+size op_spring,expected=op_spring};
 val mismatch_slice=L.slice op_input{start=size op_convert+size op_spring+2,
   stop=size op_convert+size op_spring+2+size op_mismatch,expected=op_mismatch};
 val model_text="ideal_spring_model source_force_response source_energy_response";
 val(model_input,model_owner)=owned model_text;
 val model=C.prepare{allocator=ids,development=development,source=model_owner,slice=slice model_input,
   role=C.IdealSpringModel,proposition= @{cprop "ideal_spring_model source_force_response source_energy_response"}};
 val parent=S.new_parent{allocator=ids,policy=A.policy @{theory},observation=S.StateTimeUnused,
   inputs=map fst[cm_settings,k_settings,x_settings,missing_settings,null_settings]@[query_input,op_input,model_input]};
 val children=Unsynchronized.ref([]:S.child list);
 fun child original predecessors=let val value=S.new_child parent{source=original,predecessors=predecessors}
   in children:= !children@[value];value end;
 val issuer=Private.new_issuer();
 val ticket_scope=Private.begin_scope issuer{owner_version=1,epoch=1};
 fun operation request cost pin supports semantic :Private.operation_identity=
   {workspace=I.workspace ids,request=request,profile=1,code_generation=1,operation=1,step=1,
    cost=cost,inputs=supports,owner_version=1,epoch=1,journal_sequence=1,
    semantic_generation=semantic,implementation_artifact= #artifact(E.manifest pin)};
 val declarations=Unsynchronized.ref([]:Common.declaration list);
 val reservations=Unsynchronized.ref([]:Common.reservation list);
 val snapshots=Unsynchronized.ref([]:Common.snapshot list);
 val cell_requests=Unsynchronized.ref([]:Cells.request list);
 val cells=Unsynchronized.ref([]:Cells.qualified_cell list);
 val wrappers=Unsynchronized.ref([]:Q.request list);
 val jobs=Unsynchronized.ref([]:Worker.job list);
 val outputs=Unsynchronized.ref([]:Worker.output list);
 val serial_number=Unsynchronized.ref(1:IntInf.int);
 fun next()=let val n= !serial_number in serial_number:=n+1;n end;
 fun wire bytes=String.implode(map(Char.chr o IntInf.toInt)bytes);
 type selected_source={snapshot:Common.snapshot,request:Cells.request,cell:Cells.qualified_cell,
   query:S.child,body:L.input};
 (* Publish each actual producer-owned cleanup root before restoring interrupts.
    The restored action always returns unit, including typed cell refusals. *)
 fun publish make release remember=Thread_Attributes.uninterruptible(fn restore=>fn()=>
   let val root=Unsynchronized.ref NONE;
     val result=Unsynchronized.ref NONE;
     val outcome=Exn.capture(restore(fn()=>result:=SOME(make root)))();
   in case outcome of Exn.Res()=>
       (Option.app remember(!root);the(!result))
     | Exn.Exn exn=>(Option.app release(!root);Exn.reraise exn) end)();
 fun acquire (settings_input,settings_owner) manifest_name raw =
   let
     val declaration=publish (Common.declare_into{development=development,owner=settings_owner,source=slice settings_input,
       limits={input_bytes=4096,rows=8,metadata_bytes=100000,seconds=5}})
       Common.retire_declaration (fn value=>declarations:=value:: !declarations);
     val acq_child=child(slice settings_input)[];
     val reservation=publish (Common.reserve_into{declaration=declaration,child=acq_child})
       Common.release_reservation (fn value=>reservations:=value:: !reservations);
     val id=Common.reservation_identity reservation;
     val body=input raw "binary";
     val metadata=input(File.read(Path.append(Resources.master_directory @{theory})
       (Path.explode("fixtures/" ^ manifest_name ^ ".bin"))))"binary";
     val body_owner=P.install_host_source ids body;
     val metadata_owner=P.install_host_source ids metadata;
     val support=distinct(op =)(map P.source_identity[settings_owner,body_owner,metadata_owner]@
       P.development_dependencies development);
     val opid=operation(#request id)(Common.modeled_cost reservation)(Common.executable())support(#semantic_generation id);
     val receipt:Private.acquisition_identity={attempt= #attempt id,slot= #slot id,
       source_binding= #source_binding id,capability=1,target= #target id,sources=[#source_binding id],
       dependencies=[],protocol="native-protected-fixture",receipt="retained original source bytes",operation=opid};
     val snapshot=publish (Common.attach_into(Private.issue_acquisition ticket_scope receipt
       {executable=Common.executable(),reservation=reservation,input=body,manifest_input=metadata,
        source_owner=body_owner,manifest_owner=metadata_owner}))
       Common.release_snapshot (fn value=>snapshots:=value:: !snapshots);
     val query=child(slice query_input)[acq_child];
     val request=publish (Cells.prepare_into{snapshot=snapshot,child=query,owner=query_owner})
       Cells.release_request (fn value=>cell_requests:=value:: !cell_requests);
     val cid=S.identity query;
     val support=P.source_identity query_owner::support;
     val ticket=Private.issue_pure ticket_scope
       {execution=next(),slot= #slot cid,operation=operation(#request cid)(Cells.modeled_cost request)
         (Cells.executable())support(#semantic_generation id)}
       {executable=Cells.executable(),request=request};
   val result=publish (Cells.execute_into ticket) Cells.release
       (fn value=>cells:=value:: !cells);
   in (snapshot,request,result,query,body) end;
 fun selected (snapshot,request,Cells.Selected cell,query,body):selected_source=
     {snapshot=snapshot,request=request,cell=cell,query=query,body=body}
   | selected _=error "Actual acquired SourceCell did not select integer/unit";
 val instance=(case M.attach{policy=A.policy @{theory},generation=generation,
     code_context=E.code_theory(M.executable()),limits={nodes=10000,depth=256,seconds=5}}of
       M.Ready value=>value|_=>error "SourceDomain native instance failed");
 val display_bridge=Veri7vn_Domain_Display.attach
   {allocator=ids,policy=A.policy @{theory},instance=instance};
 val gates=Unsynchronized.ref([]:Q.Gate.witness list);
 fun prepare actual_child opterm values conditions=
   let val cleanup=Unsynchronized.ref(NONE:Q.request option);
     val result=Exn.capture(fn()=>Q.prepare_child_into
       {child=actual_child,instance=instance,development=development,operation_source=op_owner,
        operation=opterm,cells=values,conditions=conditions}cleanup)();
   in case result of Exn.Res(Q.Prepared r)=>(wrappers:=r:: !wrappers;r)
     | Exn.Res _=>error "Actual SourceDomain preparation refused"
     | Exn.Exn failure=>(Option.app Q.release(!cleanup);Exn.reraise failure) end;
 fun execute request=
   let val _=if Q.live request then ()else error "Dead SourceDomain dispatched";
     val family=Q.family_request request;
     val cost=(case M.modeled_cost family of M.Ready n=>n|_=>error "Domain cost unavailable");
     val cid=S.identity(Q.child request);
     val semantic=N.semantic_generation_id ids generation;
     val ticket=Private.issue_pure ticket_scope{execution=next(),slot= #slot cid,
       operation=operation(#request cid)cost(M.executable())(Q.managed_dependencies request)semantic}
       {executable=M.executable(),instance=instance,request=family,operation=M.operation instance};
     val job=(case Worker.start ticket of Worker.Ready value=>value
       | _=>error "Actual source-derived domain worker refused");
     val _=jobs:=job:: !jobs;
     val output=(case Worker.collect job of Worker.Ready value=>value
       | _=>error "Actual source-derived domain worker failed");
     val _=outputs:=output:: !outputs;
     val raw=(case Worker.native_output output of Worker.Ready value=>value
       | _=>error "Actual domain output unavailable");
   in (raw,Q.result_view request raw) end;
 fun evaluate term=Timeout.apply(Time.fromSeconds 5)(fn()=>
   Veri7vn_Bounded_Projection.materialize 20000
     (fn()=>Code_Evaluation.dynamic_value_strict @{context} term))();
 fun equal_value actual expected=
   let val test= @{term "(=) :: domain_value => domain_value => bool"} $ Thm.term_of actual $ expected;
     val expanded=Thm.rhs_of(Simplifier.rewrite
       (fold Simplifier.add_simp [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv}]
         (put_simpset HOL_basic_ss ctxt))(Thm.cterm_of ctxt test))
   in evaluate (Thm.term_of expanded) aconv @{term True} end;
 fun require true _=() | require false text=error text;
 fun refused action message=require(is_none(try action()))message;
 fun cleanup()=
   (List.app Q.Gate.release(!gates);
    List.app Worker.release_output(!outputs);List.app Worker.cancel(!jobs);
    List.app Q.release(!wrappers);List.app Cells.release(!cells);
    List.app Cells.release_request(!cell_requests);List.app Common.release_snapshot(!snapshots);
    List.app Common.release_reservation(!reservations);List.app Common.retire_declaration(!declarations);
    C.release model;S.deny parent;List.app S.release_child(!children);S.release_parent parent;
    Veri7vn_Domain_Display.release display_bridge;M.release_instance instance;P.release development;Private.close_scope ticket_scope;
    List.app(fn value=>Option.app I.release_disposed_input(L.drop_base value))(!inputs));
 val checked=Exn.capture(fn()=>
   let
     val cm=selected(acquire cm_settings "centimetres" (wire(@{code quantity_body}(Veri7vn_Numerals.nat_of_integer 100))));
     val stiffness=selected(acquire k_settings "stiffness" (wire(@{code quantity_body}(Veri7vn_Numerals.nat_of_integer 3))));
     val extension=selected(acquire x_settings "metres" (wire(@{code quantity_body}(Veri7vn_Numerals.nat_of_integer 2))));
     val(_,_,missing,_,_)=acquire missing_settings "unit-missing"
       (wire(@{code quantity_body}(Veri7vn_Numerals.nat_of_integer 100)));
     val _=(case missing of Cells.Refused(Cells.SelectionRefused Veri7vn_Source_Cell_Code.CellUnitMissing)=>()
       | _=>error "Actual missing source unit was not a typed refusal");
     val(_,_,null,_,_)=acquire null_settings "null" (wire @{code quantity_null_body});
     val _=(case null of Cells.Refused(Cells.SelectionRefused Veri7vn_Source_Cell_Code.CellNotInteger)=>()
       | _=>error "Actual NULL source cell became a rational");
     val foreign_parent=S.new_parent{allocator=ids,policy=A.policy @{theory},
       observation=S.StateTimeUnused,inputs=[op_input]};
     val foreign_child=S.new_child foreign_parent{source=convert_slice,predecessors=[]};
     val foreign=Q.prepare_child{child=foreign_child,instance=instance,development=development,
       operation_source=op_owner,operation= @{cterm "ConvertLinear Centimetre Metre"},
       cells=[(#cell cm,Q.Centimetres)],conditions=[]};
     val _=(case foreign of Q.Prepared r=>Q.release r|_=>());
     val _=S.deny foreign_parent;
     val _=S.release_child foreign_child;
     val _=S.release_parent foreign_parent;
     val _=(case foreign of Q.Refused(Q.InvalidAssociation _)=>()
       | _=>error "Source cell crossed into a foreign actual request parent");
     val length_child=child convert_slice[#query cm];
     val length_request=prepare length_child @{cterm "ConvertLinear Centimetre Metre"}
       [(#cell cm,Q.Centimetres)][];
     val(raw_length,{domain=length_view,sources=length_sources})=execute length_request;
     val _=(case length_view of D.Answer{value,...}=>
       require(equal_value value @{term "LinearValue Metre 1"})"Source100cm did not calculate exact1m"
       | _=>error "Source conversion was not a typed answer");
     val _=(case length_sources of [view]=>
       require(#reported_unit(#metadata view)="cm" andalso
         #configuration(#metadata view)="quantity-fixture/1:centimetres" andalso
         #source_key(#metadata view)="source-quantity-centimetres" andalso
         #coordinates view={row=0,column=0})"Original source/unit/config/selector lost"
       | _=>error "Source calculation lost inspectable original source");
     val length_gate=publish
       (Q.Gate.specialize_into display_bridge length_request raw_length)
       Q.Gate.release(fn value=>gates:=value:: !gates);
     val _=require(Thm.term_of(Q.Gate.target length_gate) aconv
       Thm.term_of(Q.specialize length_request raw_length))"Gate lost full source-qualified target";
     val _=require(length(#sources(Q.Gate.display length_gate))=1)
       "Gate omitted recipient source correspondence";
     val interrupted_gate_root=Unsynchronized.ref(NONE:Q.Gate.witness option);
     val gate_interrupt:unit Exn.result=Exn.capture(fn()=>
       Thread_Attributes.uninterruptible(fn restore=>fn()=>
         (restore(fn()=>ignore(Q.Gate.specialize_into display_bridge length_request
           raw_length interrupted_gate_root))();Exn.interrupt()))())();
     val _=Option.app Q.Gate.release(!interrupted_gate_root);
     val _=require(case gate_interrupt of Exn.Exn exn=>Exn.is_interrupt exn|_=>false)
       "Gate cancellation did not interrupt after actual publication";
     val _=require(Q.Gate.live length_gate andalso Q.live length_request)
       "Cancelled source gate destroyed independent live consumer";
     val saved=Q.snapshot length_request;
     val reconstruction=Unsynchronized.ref(NONE:Q.request option);
     val reconstructed=(case Q.reconstruct_into
       {child=length_child,instance=instance,development=development,operation_source=op_owner,
        operation= @{cterm "ConvertLinear Centimetre Metre"},cells=[(#cell cm,Q.Centimetres)],conditions=[]}
       {derivative_source=Q.derivative_source length_request,saved=saved}reconstruction of
         Q.Prepared r=>(wrappers:=r:: !wrappers;r)
       | _=>error "Same-owner native correspondence reconstruction failed");
     val _=require(Q.matches_snapshot reconstructed saved)"Reconstruction changed frozen source/domain correspondence";
     val _=refused(fn()=>Q.result_view reconstructed raw_length)
       "Output from another native request was substituted during reconstruction";
     val sibling_child=child convert_slice[#query cm];
     val _=(case Q.prepare_child{child=sibling_child,instance=instance,development=development,
       operation_source=op_owner,operation= @{cterm "ConvertLinear Centimetre Metre"},
       cells=[(#cell cm,Q.Metres)],conditions=[]}of
         Q.Refused(Q.UnitMismatch{expected="m",reported="cm"})=>()
       | _=>error "Reported source centimetres were relabeled as metres");
     val sibling=prepare sibling_child @{cterm "ConvertLinear Centimetre Metre"}[(#cell cm,Q.Centimetres)][];
     val(raw_sibling,_)=execute sibling;
     val _=(case Q.prepare_child{child=sibling_child,instance=instance,development=development,
       operation_source=op_owner,operation= @{cterm "ConvertLinear Centimetre Metre"},
       cells=[(#cell cm,Q.Centimetres)],conditions=[]}of
         Q.Refused(Q.InvalidAssociation _)=>()|_=>error "Scope child constructed twice");
     val mismatch=prepare(child mismatch_slice[#query cm])@{cterm "ConvertLinear Centimetre Kilogram"}
       [(#cell cm,Q.Centimetres)][];
     val _=(case #domain(#2(execute mismatch))of D.Rejected D.QuantityMismatch=>()
       | _=>error "Source length became incompatible mass");
     val spring_cells=[(#cell stiffness,Q.NewtonsPerMetre),(#cell extension,Q.Metres)];
     val spring_dependencies=[#query stiffness,#query extension];
     val unadopted=prepare(child spring_slice spring_dependencies)@{cterm "Spring SpringForce"}spring_cells[];
     val _=(case #domain(#2(execute unadopted))of D.NeedsIdealModel=>()
       | _=>error "Missing source physical model became an answer");
     val spring=prepare(child spring_slice spring_dependencies)@{cterm "Spring SpringForce"}spring_cells[model];
     val(raw_spring,{domain=spring_view,sources=spring_sources})=execute spring;
     val _=(case spring_view of D.Answer{value,conditions}=>
       require(equal_value value @{term "LinearValue Newton 6"} andalso length spring_sources=2 andalso
         length(C.checked_associations generation(Q.input spring)(Q.condition_associations spring))=1)
         "Source3N/m times2m lost exact6N/model/source provenance"
       | _=>error "Qualified source spring calculation failed");
     val interrupted_root=Unsynchronized.ref(NONE:Q.request option);
     val interrupted_output=Unsynchronized.ref(NONE:M.output option);
     val interrupt_child=child convert_slice[#query cm];
     val interrupted:unit Exn.result=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
       (restore(fn()=>case Q.prepare_child_into
          {child=interrupt_child,instance=instance,development=development,operation_source=op_owner,
           operation= @{cterm "ConvertLinear Centimetre Metre"},cells=[(#cell cm,Q.Centimetres)],conditions=[]}
          interrupted_root of Q.Prepared r=>(wrappers:=r:: !wrappers)
            | _=>error "Interrupt fixture source/domain request was not prepared")();
        restore(fn()=>let val(raw,_)=execute(the(!interrupted_root))
          in interrupted_output:=SOME raw end)();
        Exn.interrupt()))())();
     val _=require(case interrupted of Exn.Exn exn=>Exn.is_interrupt exn|_=>false)
       "Deterministic interruption fixture did not interrupt after computed output";
     val _=Option.app Q.release(!interrupted_root);
     val _=require(case M.project(M.executable())(the(!interrupted_output))of
         M.Refused M.Released=>true|_=>false)
       "Interrupted SourceDomain retained computed output after owner cleanup";
     val _=require(Q.live sibling andalso Q.live spring)
       "Interrupted SourceDomain cleanup retired independent consumers";
     val _=ignore(S.seal parent(!children));
     val _=List.app S.release_child(!children);
     val _=Q.release length_request;
     val _=Cells.release(#cell cm);
     val _=Cells.release_request(#request cm);
     val _=Common.release_snapshot(#snapshot cm);
     val _=S.release_parent parent;
     val _=Option.app I.release_disposed_input(L.drop_base(#body cm));
     val _=require(Q.live reconstructed andalso Q.live sibling andalso Q.live spring andalso Q.Gate.live length_gate)
       "Releasing producer handles destroyed independent source/domain consumers";
     val _=ignore(Q.result_view sibling raw_sibling);
     val _=L.invalidate(#body cm);
     val _=require(not(Q.live reconstructed) andalso not(Q.live sibling) andalso not(Q.Gate.live length_gate))
       "Source invalidation failed to deny derived source/domain requests";
     val _=refused(fn()=>Q.Gate.display length_gate)"Source-forgotten gate retained display";
     val _=refused(fn()=>Q.result_view sibling raw_sibling)"Late derived result escaped source Forget guard";
     val _=refused(fn()=>Q.specialize sibling raw_sibling)"Source-forgotten output retained native publication target";
     val _=require(Q.live spring)"Forgetting length source destroyed independent spring sources";
     val _=ignore(Q.result_view spring raw_spring);
   in () end)();
 val _=cleanup();
 val _=Exn.release checked;
in val _=writeln "INTEGRATION protected_source_cell_quantity_domain PASS" end;
\<close>
end
