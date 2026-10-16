(* Native lifetime/canonical catalogue view only. Current selection permission
   belongs to the one resident authority. There is no raw receiver constructor. *)
signature VERI7VN_SEARCH_RECEIVER_CONTEXT =
sig
  type context
  val allocator:context -> Veri7vn_Native_Identity_Allocator.allocator
  val development:context -> Veri7vn_Managed_Provenance.development
  val policy:context -> Veri7vn_Native_Admission.policy
  val semantic_generation:context -> IntInf.int
  val dependencies:context -> IntInf.int list
  val catalogue_owned:Veri7vn_Managed_Provenance.construction_scope -> context ->
    Thm_Name.T list -> Veri7vn_Managed_Provenance.consequence list
  val is_live:context -> bool
  val retain:context -> context
  val release:context -> unit
end;
