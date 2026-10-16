(* Inert snapshots for the fixed deferred native owner/recovery codec. A Reserved
   output denotes its actual predecessor slot, never a prospective candidate ID. *)
structure Veri7vn_Native_Deferred_Build_Types =
struct
  datatype parent = Installed of {locator:string,root:string}
    | KnownCandidate of {locator:string,candidate:IntInf.int,context:IntInf.int,slot:IntInf.int}
    | ReservedOutput of {locator:string,goal:IntInf.int,slot:IntInf.int,
        source_owner:IntInf.int,start:int,stop:int};
  type source={source_owner:IntInf.int,start:int,stop:int,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int,descriptor_source:IntInf.int,
    descriptor_start:int,descriptor_stop:int};
  type plan={original_input:Veri7vn_Native_Package_Input_Types.metadata,prepared_input:IntInf.int,
    workspace:string,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    interpretation:IntInf.int,decision:IntInf.int,parameter:IntInf.int,
    candidate:IntInf.int,execution:IntInf.int,template:IntInf.int,profile:IntInf.int,
    setup:IntInf.int,capability:IntInf.int,operation:IntInf.int,code_generation:IntInf.int,
    operation_generation:IntInf.int,step:IntInf.int,source:source,parents:parent list,
    exports:Thm_Name.T list,dependencies:IntInf.int list};
end;
