theory Native_Build_Candidate
  imports "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets"
    "Veri7vn_Native_Request_Scope.Native_Request_Scope"
    "Veri7vn_Native_Lifetime.Native_Lifetime"
begin
ML_file "native_export_intent.ML"
ML_file "native_package_input_types.ML"
ML_file "native_build_terminal.ML"
ML_file "native_deferred_build_types.ML"
ML_file "../recovery/native_deferred_build_codec.ML"
ML_file "native_build_request_envelope.ML"
ML_file "native_package_inputs.ML"
ML_file "../recovery/native_development_recovery.ML"
ML_file "native_build_candidate.ML"
ML_file "native_build_recovery.ML"
ML \<open>
(* One shipped builder identity. The final owner registers this exact pin and
   passes it to its lexical-private Builder instance; worker labels never mint it. *)
structure Veri7vn_Native_Build_Image =
struct
  val executable=Veri7vn_Executable_Identity.pin @{theory}
    {artifact="veri7vn-native-controlled-source-builder-v1",
     compiler="Isabelle/PolyML",target="bounded-native-development-replay",
     serializers=["protected-source-slice-v1","ordered-managed-parent-v1"],
     foreign_primitives=["Scala.function1_bytes:veri7vn.package_descriptor_v1"],settings=["source-bytes<=1000000","parents<=64",
       "exports<=256","native-replay-timeout=10s","cost=one-build-attempt"]};
end;
\<close>
end
