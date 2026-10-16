(* The sole fixed checkpoint/source factory implements this view. The signature
   itself validates no module; it is never a worker callback registration API. *)
signature VERI7VN_CHECKED_REQUEST_SCOPE_VIEW =
sig
  type checked
  val saved:checked -> Veri7vn_Native_Scope_Saved.parent
  val required:checked -> Veri7vn_Native_Scope_Saved.required
  val sources:checked -> (IntInf.int * Veri7vn_Native_Literals.input) list
  val parent_active:checked -> bool
  val policy:checked -> Veri7vn_Native_Admission.policy
  val live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;
