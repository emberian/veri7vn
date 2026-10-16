(* Loaded after the single host-owned generated metadata universe. The closure
   retains the actual generated claim; there is no external frame constructor. *)
signature VERI7VN_NATIVE_AUTHORITY_DESCRIPTOR =
sig
  type descriptor
  val register: Veri7vn_Native_Descriptor.descriptor -> descriptor
  val restore: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Check.verified -> descriptor
  val native: descriptor -> Veri7vn_Native_Descriptor.descriptor
  val evidence_id: descriptor -> IntInf.int
  val event_frame: descriptor -> string
  val is_live: descriptor -> bool
  val release: descriptor -> unit
end;
structure Veri7vn_Native_Authority_Descriptor :> VERI7VN_NATIVE_AUTHORITY_DESCRIPTOR =
struct
  structure N = Veri7vn_Native_Descriptor;
  structure F = Veri7vn_Metadata_Frame;
  datatype descriptor = Descriptor of {native: N.descriptor,
    evidence_id: IntInf.int, frame: unit -> string};
  fun register native =
    let
      val _ = if N.provenance_complete native then ()
        else error "Persistent native evidence requires controlled producer provenance";
      val projection = N.project native;
      val generated_claim = F.make_native_claim projection;
      val evidence_id = N.allocate_related_identity native;
      (* Actual generated native-claim object is captured here, not reconstructed
         from client-selected IDs/kind/route/scope fields on later use. *)
      fun frame () = F.encode_event
        (F.make_attach_native_evidence (evidence_id,generated_claim,N.native_object_dependencies native));
    in Descriptor {native=native,evidence_id=evidence_id,frame=frame} end;
  fun restore allocator verified =
    let val saved=Veri7vn_Native_Recovery_Check.saved verified
      val native=N.restore allocator verified
      fun construct () =
        let val generated_claim=F.make_native_claim (N.project native)
          val evidence_id= #evidence_id saved
          fun frame ()=F.encode_event (F.make_attach_native_evidence (evidence_id,generated_claim,N.native_object_dependencies native))
          val _=ignore (frame ())
        in Descriptor {native=native,evidence_id=evidence_id,frame=frame} end
      val result=Exn.capture construct ()
    in case result of Exn.Res descriptor=>descriptor
      | Exn.Exn exn=>(N.release native;Exn.reraise exn) end;
  fun native (Descriptor {native,...}) = native;
  fun evidence_id (Descriptor {evidence_id,...}) = evidence_id;
  fun is_live (Descriptor {native,...}) = N.is_live native;
  fun release (Descriptor {native,...}) = N.release native;
  fun event_frame (Descriptor {native,frame,...}) =
    if N.is_live native then frame () else error "Native evidence descriptor is unavailable";
end;
