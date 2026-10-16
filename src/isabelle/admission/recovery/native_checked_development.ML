(* Fixed checked-deployment lifetime view. Implementations belong to the pinned
   native recovery image: this signature does not validate arbitrary ML modules.
   Saved numeric fields are metadata checked against protected material; actual
   source and context ownership comes only from the opaque restored graph lease. *)
signature VERI7VN_CHECKED_DEVELOPMENT_VIEW =
sig
  type checked_development
  type export_intent
  type binding = {
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,
    slice:Veri7vn_Native_Literals.slice,
    parents:(IntInf.int option * string * Veri7vn_Managed_Provenance.development) list,
    template:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
    candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    charged_generation:IntInf.int,semantic_generation:IntInf.int,
    exports:Thm_Name.T list,input_bindings:IntInf.int list,dependencies:IntInf.int list}
  val original_intent: checked_development -> export_intent
  val binding: checked_development -> binding
  val consequences: checked_development -> Veri7vn_Managed_Provenance.consequence list
  val executable: checked_development -> Veri7vn_Executable_Identity.pin
  val is_available: checked_development -> bool
  val is_live: checked_development -> bool
  val retain: checked_development -> checked_development
  val release: checked_development -> unit
end;
