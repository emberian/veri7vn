(* Proposed owner-specific recovery views. No implementation or raw-ID constructor
   is supplied here. Only a fixed native recovery adapter checking exact current
   checkpoint membership, graph/source owners and observation correspondence may
   implement them. They are not native theorem views. *)
structure Veri7vn_Qualification_Recovery_Types =
struct
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,contract:IntInf.int,
    attempt:IntInf.int,qualification:IntInf.int,observation:IntInf.int,semantic_generation:IntInf.int};
  type candidate_pin={template:IntInf.int,source_owner:IntInf.int,source_revision:IntInf.int,
    manifest:IntInf.int,parents:IntInf.int list,profile:IntInf.int,setup:IntInf.int,
    export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,dependencies:IntInf.int list};
  type initial_context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,exposure:IntInf.int,
    acceptance_metric:IntInf.int,count_metric:IntInf.int,unit_id:IntInf.int,
    executable_generation:IntInf.int,slot:IntInf.int};
  type update_context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,interpretation:IntInf.int,
    run_spec:IntInf.int,policy:IntInf.int,policy_resource:IntInf.int,
    exposure:IntInf.int,structural_metric:IntInf.int,count_metric:IntInf.int,
    unit_id:IntInf.int,executable_generation:IntInf.int,slot:IntInf.int,previous:IntInf.int option};
  type sequents=(Thm_Name.T * Veri7vn_Native_Sequent.snapshot) list;
end;

signature VERI7VN_CHECKED_INITIAL_QUALIFICATION =
sig
  type candidate
  type intent
  type checked
  type binding={candidate:candidate,intent:intent,
    context:Veri7vn_Qualification_Recovery_Types.initial_context,
    names:Veri7vn_Qualification_Recovery_Types.names,
    candidate_pin:Veri7vn_Qualification_Recovery_Types.candidate_pin,
    profile:string,count:int,dependencies:IntInf.int list,
    exports:Veri7vn_Qualification_Recovery_Types.sequents}
  val binding:checked -> binding
  (* Actual installed fixed code pin; restore compares E.same, not numeric labels. *)
  val executable:checked -> Veri7vn_Executable_Identity.pin
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;

signature VERI7VN_CHECKED_UPDATE_QUALIFICATION =
sig
  type candidate
  type checked
  type binding={candidate:candidate,baseline:candidate,
    context:Veri7vn_Qualification_Recovery_Types.update_context,
    names:Veri7vn_Qualification_Recovery_Types.names,
    candidate_pin:Veri7vn_Qualification_Recovery_Types.candidate_pin,
    baseline_pin:Veri7vn_Qualification_Recovery_Types.candidate_pin,
    profile:string,count:int,dependencies:IntInf.int list,
    expected_exports:Veri7vn_Qualification_Recovery_Types.sequents,
    exports:Veri7vn_Qualification_Recovery_Types.sequents}
  val binding:checked -> binding
  val executable:checked -> Veri7vn_Executable_Identity.pin
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;

(* Implemented by the one lexical-private assembly association owner. Authority
   invalidation denies use independently of base/consumer reference counts. *)
signature VERI7VN_BUILD_CANDIDATE_LEASE =
sig
  type candidate
  type lease
  val candidate:lease -> candidate
  val is_live:lease -> bool
  val retain:lease -> lease
  val release:lease -> unit
end;
