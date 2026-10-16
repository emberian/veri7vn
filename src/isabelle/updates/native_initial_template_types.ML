(* An unresolved qualification template owns a real prepared build, not a
   prospective candidate or observation. Only an acknowledged native artifact
   output from that exact prepared build may specialize it. *)
structure Veri7vn_Initial_Qualification_Template_Types =
struct
  structure T=Veri7vn_Qualification_Recovery_Types;
  type prepared_pin={template:IntInf.int,source_owner:IntInf.int,source_revision:IntInf.int,
    manifest:IntInf.int,parents:IntInf.int list,profile:IntInf.int,setup:IntInf.int,
    export_intent:IntInf.int,candidate:IntInf.int,dependencies:IntInf.int list};
  type build_plan={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,execution:IntInf.int,
    semantic_generation:IntInf.int,input_bindings:IntInf.int list};
  type snapshot={context:T.initial_context,names:T.names,prepared:prepared_pin,
    build:build_plan,profile:string,dependencies:IntInf.int list};
end;

signature VERI7VN_BUILD_PREPARED_LEASE =
sig
  type prepared
  type lease
  val prepared:lease -> prepared
  val is_live:lease -> bool
  val retain:lease -> lease
  val release:lease -> unit
end;

(* Issued by the fixed artifact association owner only after its durable ack. *)
signature VERI7VN_QUALIFICATION_BUILD_OUTPUT_LEASE =
sig
  type candidate
  type lease
  val candidate:lease -> candidate
  val assigned_slot:lease -> IntInf.int
  val is_live:lease -> bool
  val retain:lease -> lease
  val release:lease -> unit
end;

signature VERI7VN_CHECKED_INITIAL_QUALIFICATION_TEMPLATE =
sig
  type prepared
  type intent
  type checked
  type binding={prepared:prepared,intent:intent,snapshot:Veri7vn_Initial_Qualification_Template_Types.snapshot}
  val binding:checked -> binding
  val executable:checked -> Veri7vn_Executable_Identity.pin
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;

signature VERI7VN_INITIAL_TEMPLATE_CHECKPOINT =
sig
  val template:string -> Veri7vn_Initial_Qualification_Template_Types.snapshot -> bool
end;
