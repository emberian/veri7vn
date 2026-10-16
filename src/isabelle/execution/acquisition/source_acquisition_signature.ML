(* Internal fixed observer seam; this is not a recipient source-data API. *)
signature VERI7VN_COMMON_SOURCE_OWNER =
sig
  type declaration type reservation type snapshot type input_witness
  type limits={input_bytes:int,rows:int,metadata_bytes:int,seconds:int}
  type acquisition_payload={executable:Veri7vn_Executable_Identity.pin,reservation:reservation,input:Veri7vn_Native_Literals.input,
    manifest_input:Veri7vn_Native_Literals.input,
    source_owner:Veri7vn_Managed_Provenance.source_owner,
    manifest_owner:Veri7vn_Managed_Provenance.source_owner}
  type declaration_payload={development:Veri7vn_Managed_Provenance.development,
    owner:Veri7vn_Managed_Provenance.source_owner,source:Veri7vn_Native_Literals.slice,
    limits:limits}
  val declare:declaration_payload->declaration
  val declare_into:declaration_payload->declaration option Unsynchronized.ref->declaration
  val retire_declaration:declaration->unit
  val reserve:{declaration:declaration,child:Veri7vn_Native_Request_Scope.child}->reservation
  val reserve_into:{declaration:declaration,child:Veri7vn_Native_Request_Scope.child}->reservation option Unsynchronized.ref->reservation
  val reservation_identity:reservation->{request:IntInf.int,slot:IntInf.int,target:IntInf.int,
    attempt:IntInf.int,source_binding:IntInf.int,semantic_generation:IntInf.int}
  val executable:unit->Veri7vn_Executable_Identity.pin
  val modeled_cost:reservation->IntInf.int
  val release_reservation:reservation->unit
  val release_snapshot:snapshot->unit
  val transfer:snapshot->input_witness
  val transfer_into:snapshot->input_witness option Unsynchronized.ref->input_witness
  val clone_witness:input_witness->input_witness
  val release_witness:input_witness->unit
  val witness_live:input_witness->bool
  val same_witness:input_witness*input_witness->bool
  val association:input_witness->Veri7vn_Source_Acquisition_Kernel.association
  val native_association:input_witness->cterm
  val native_observation:input_witness->cterm
  val association_meaning:input_witness->thm
  val acquisition_meaning:input_witness->thm
  val acquisition_qualification:input_witness->Veri7vn_Native_Admission.accepted
  val observation_projection:input_witness->thm
  val generation:input_witness->Veri7vn_Native_Registry.generation
  val policy:input_witness->Veri7vn_Native_Admission.policy
  val dependencies:input_witness->IntInf.int list
  val child:input_witness->Veri7vn_Native_Request_Scope.child
  val receipt_binding:input_witness->{workspace:string,request:IntInf.int,
    semantic_generation:IntInf.int,inputs:IntInf.int list}
end;
