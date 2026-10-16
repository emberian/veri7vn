(* A prepared source request owns protected inputs/parents, not a completed
   build or a permission to replay a charged execution. *)
signature VERI7VN_CHECKED_BUILD_REQUEST_VIEW =
sig
  type checked_request
  type export_intent
  type failure
  type control_plan
  datatype phase = Plan | ObservedFailure of failure
  type binding={source:Veri7vn_Managed_Provenance.source_owner,
    slice:Veri7vn_Native_Literals.slice,
    parents:(IntInf.int option * string * Veri7vn_Managed_Provenance.development) list,
    template:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
    candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    charged_generation:IntInf.int,exports:Thm_Name.T list,
    input_bindings:IntInf.int list,dependencies:IntInf.int list}
  val binding:checked_request -> binding
  val phase:checked_request -> phase
  val control_plan:checked_request -> control_plan option
  val original_intent:checked_request -> export_intent
  val executable:checked_request -> Veri7vn_Executable_Identity.pin
  val is_live:checked_request -> bool
  val retain:checked_request -> checked_request
  val release:checked_request -> unit
end;
