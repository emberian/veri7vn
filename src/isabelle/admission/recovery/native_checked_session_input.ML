(* The sole fixed SessionInput factory implements this view. A restored source
   owns historical attribution; it is not a new observation or dispatch pin. *)
signature VERI7VN_CHECKED_SESSION_INPUT_VIEW =
sig
  type checked
  val metadata:checked -> Veri7vn_Session_Input_Codec.metadata
  val input:checked -> Veri7vn_Native_Literals.input
  val development:checked -> Veri7vn_Managed_Provenance.development
  val recorded:checked -> bool
  val validate_registered:checked -> unit
  val live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;
