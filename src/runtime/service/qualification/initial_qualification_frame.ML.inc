(* Splice inside Veri7vn_Metadata_Frame's existing ML block. Do not load this
   fragment as a second generated-code universe. All inputs here are projections
   produced by the closed opaque owner; none is an RPC decoder entry point. *)
val initial_qualification_policy = @{code initial_service_policy};
val initial_qualification_reserve = @{code initial_service_reserve};
val initial_qualification_start = @{code initial_service_start};
val initial_qualification_evidence = @{code initial_service_evidence};
val initial_qualification_output = @{code initial_service_output};
val initial_qualification_record = @{code initial_service_qualify};
val initial_qualification_publication = @{code initial_service_publish};
val initial_qualification_reservation_matches = @{code initial_admission_reservation_matches};
val initial_qualification_observation_current = @{code initial_admission_current};

(* The parent consumes the exact ExposeQualification reservation/epoch only
   after its durable checkpoint. Then it runs InitialOwner.measure_started once
   outside the Owner lock. An authenticated result role must exist at the first
   durable AttachEvidence checkpoint, before paid StageOutput. StageOutput uses
   QualificationOrigin, never a second ExecutePure. StageQualification follows
   that exact assigned binding; publication follows its own durable ack.
   On restore Started without measured material is interrupted, not reexecuted.
   PublishedContext is minted only after the exact publication is visible in
   committed state and current authority permits the selected native exports. *)
