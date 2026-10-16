(* Inert shared shapes only. None of these records constructs a native object,
   condition, preserved identity, proof or service authority. *)
structure Veri7vn_Domain_Saved_Types =
struct
  datatype role=InputCondition | IdealSpringModel;
  type condition_snapshot={identity:IntInf.int,owner_identity:IntInf.int,
    role:role,proposition:term,source_span:int*int,dependencies:IntInf.int list};
  type request_saved={workspace:string,input_identity:IntInf.int,input:term,template:term,
    bytes:string,encoding:string,input_source_span:int*int,context_dependencies:IntInf.int list,
    owners:(IntInf.int*string*string)list,conditions:condition_snapshot list,
    implementation:term,model_contract:term option};
  type output_saved={request:request_saved,output:term,target:term,
    implementation:term,model_contract:term option,rendering_contract:term,statement_html:string};
  type request_envelope={association:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    semantic_generation:IntInf.int,code_generation:IntInf.int,operation:IntInf.int,saved:request_saved};
  type output_envelope={association:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    interpretation:IntInf.int,claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,output:IntInf.int,
    execution:IntInf.int,batch:IntInf.int,semantic_generation:IntInf.int,
    code_generation:IntInf.int,operation:IntInf.int,saved:output_saved};
end;
