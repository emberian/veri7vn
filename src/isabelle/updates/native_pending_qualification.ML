(* Pending qualification is a request owner, never measured evidence. Its phase
   is derived by the fixed Frame checker from the current protected checkpoint. *)
structure Veri7vn_Pending_Qualification_Types =
struct
  structure T=Veri7vn_Qualification_Recovery_Types;
  datatype phase=RequestPrepared | QualificationReserved | QualificationStarted;
  type initial={request_slot:IntInf.int,context:T.initial_context,names:T.names,
    candidate:T.candidate_pin,profile:string,dependencies:IntInf.int list};
  type update={request_slot:IntInf.int,context:T.update_context,names:T.names,
    candidate:T.candidate_pin,baseline:T.candidate_pin,profile:string,
    dependencies:IntInf.int list,expected_exports:T.sequents};
end;

structure Veri7vn_Pending_Qualification_Codec =
struct
  structure T=Veri7vn_Pending_Qualification_Types;
  structure W=Veri7vn_Qualification_Codec;
  fun encode_initial({request_slot,context,names,candidate,profile,dependencies}:T.initial)=
    let val _=W.require(request_slot= #request_slot context andalso request_slot<> #slot context) "Initial pending slot mismatch"
      val _=W.require(profile=W.initial_profile) "Initial pending profile"
      val raw=YXML.string_of_body[XML.Elem(("initial-qualification-request",
        [("version","2"),("variant","bound"),("profile",profile),("slot",W.number request_slot)]),
        [W.strings "names"(W.names names),W.strings "context"(W.initial_context context),
         W.candidate "candidate" candidate,W.strings "dependencies"(W.ids dependencies)])]
      val _=W.framing raw
    in raw end;
  fun decode_initial raw=
    let val _=W.framing raw
      val result=case YXML.parse_body raw of
        [XML.Elem(("initial-qualification-request",[("version","2"),("variant","bound"),("profile",profile),("slot",slot)]),
          [names,context,candidate,dependencies])]=>
          {request_slot=W.positive slot,context=W.parse_initial(W.parse_strings "context" context),
           names=W.parse_names(W.parse_strings "names" names),candidate=W.parse_candidate "candidate" candidate,
           profile=profile,dependencies=W.parse_ids(W.parse_strings "dependencies" dependencies)}:T.initial
        | _=>error "Initial pending qualification schema"
      val _=W.require(encode_initial result=raw) "Noncanonical initial pending qualification"
    in result end;
  fun encode_update({request_slot,context,names,candidate,baseline,profile,dependencies,expected_exports}:T.update)=
    let val _=W.require(request_slot= #request_slot context andalso request_slot<> #slot context) "Update pending slot mismatch"
      val _=W.require(profile=W.update_profile) "Update pending profile"
      val raw=YXML.string_of_body[XML.Elem(("update-qualification-request",
        [("version","1"),("profile",profile),("slot",W.number request_slot)]),
        [W.strings "names"(W.names names),W.strings "context"(W.update_context context),
         W.candidate "candidate" candidate,W.candidate "baseline" baseline,
         W.strings "dependencies"(W.ids dependencies),W.sequents "expected" expected_exports])]
      val _=W.framing raw
    in raw end;
  fun decode_update raw=
    let val _=W.framing raw
      val result=case YXML.parse_body raw of
        [XML.Elem(("update-qualification-request",[("version","1"),("profile",profile),("slot",slot)]),
          [names,context,candidate,baseline,dependencies,expected])]=>
          {request_slot=W.positive slot,context=W.parse_update(W.parse_strings "context" context),
           names=W.parse_names(W.parse_strings "names" names),candidate=W.parse_candidate "candidate" candidate,
           baseline=W.parse_candidate "baseline" baseline,profile=profile,
           dependencies=W.parse_ids(W.parse_strings "dependencies" dependencies),
           expected_exports=W.parse_sequents "expected" expected}:T.update
        | _=>error "Update pending qualification schema"
      val _=W.require(encode_update result=raw) "Noncanonical update pending qualification"
    in result end;
end;

signature VERI7VN_PENDING_QUALIFICATION_CHECKPOINT =
sig
  val initial:string -> Veri7vn_Pending_Qualification_Types.initial ->
    Veri7vn_Pending_Qualification_Types.phase option
  val update:string -> Veri7vn_Pending_Qualification_Types.update ->
    Veri7vn_Pending_Qualification_Types.phase option
end;

signature VERI7VN_CHECKED_INITIAL_QUALIFICATION_REQUEST =
sig
  type candidate
  type intent
  type checked
  type binding={candidate:candidate,intent:intent,snapshot:Veri7vn_Pending_Qualification_Types.initial,
    phase:Veri7vn_Pending_Qualification_Types.phase}
  val binding:checked -> binding
  val executable:checked -> Veri7vn_Executable_Identity.pin
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;

signature VERI7VN_CHECKED_UPDATE_QUALIFICATION_REQUEST =
sig
  type candidate
  type checked
  type binding={candidate:candidate,baseline:candidate,snapshot:Veri7vn_Pending_Qualification_Types.update,
    phase:Veri7vn_Pending_Qualification_Types.phase}
  val binding:checked -> binding
  val executable:checked -> Veri7vn_Executable_Identity.pin
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val is_live:checked -> bool
  val retain:checked -> checked
  val release:checked -> unit
end;
