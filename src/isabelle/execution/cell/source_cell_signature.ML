(* Internal fixed native consumer view. Constructors and charged execution remain
   with the source owner. Cterms below are exact owner-produced specializations,
   never caller-provided alternatives or independent theorem bags. *)
signature VERI7VN_QUALIFIED_SOURCE_CELL =
sig
  type qualified_cell
  type lease
  type native_binding
  type metadata = {reported_unit:string,source_key:string,source_schema:string,
    configuration:string,source_version:string option}
  val integer: qualified_cell -> IntInf.int
  val metadata: qualified_cell -> metadata
  val native_binding: qualified_cell -> native_binding
  (* native_input is exactly (obs,row,column); native_requirement is the closed
     source_cell_selection_meaning obs row column value unit proposition.
     specialization proves that exact proposition using the SAME qualified
     acquisition association, not a theorem selected by the recipient. *)
  val coordinates: qualified_cell -> {row:IntInf.int,column:IntInf.int}
  val native_input: native_binding -> cterm
  val native_requirement: native_binding -> cterm
  val native_observation: native_binding -> cterm
  val specialization: native_binding -> Veri7vn_Native_Admission.accepted
  (* These exact associated judgments remain alongside the selection fact. *)
  val acquisition_qualification: native_binding -> Veri7vn_Native_Admission.accepted
  val associated_specialization: native_binding -> Veri7vn_Native_Admission.accepted
  val generation: native_binding -> Veri7vn_Native_Registry.generation
  val dependencies: qualified_cell -> IntInf.int list
  val scope_child: qualified_cell -> Veri7vn_Native_Request_Scope.child
  val is_live: qualified_cell -> bool
  val same_cell: qualified_cell * qualified_cell -> bool
  (* A lease owns an independent cell view. Ordinary release of the producer
     handle preserves that view; source/occurrence retirement denies all views.
     Storage retention grants no new execution or publication authority. *)
  val retain: qualified_cell -> lease
  val retained_cell: lease -> qualified_cell
  val release_lease: lease -> unit
  val release: qualified_cell -> unit
end;
