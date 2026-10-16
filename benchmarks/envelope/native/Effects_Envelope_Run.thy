theory Effects_Envelope_Run imports Effects_Envelope begin
ML \<open>
(* One bounded pilot observation per shape/size, no tail-latency claim.
   Only steward runs this session; no application service or corpora involved. *)
val _ = List.app (fn shape => List.app (Veri7vn_Effects_Envelope.sample shape)
  [16,64,256,1024]) [0,1,2,3,4,5];
val _ = writeln "EFFECTS_ENVELOPE pilot_complete PASS";
\<close>
end
