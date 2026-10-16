theory Authority_Codec_Tests
  imports Veri7vn_Authority_Codec.Authority_Codec
begin

fun truncate_metadata :: "authority_wire \<Rightarrow> authority_wire" where
  "truncate_metadata (WireNat n) = WireNat n" |
  "truncate_metadata (WireNode tag wire_children) = WireNode tag []"

lemma exact_checkpoint_roundtrip:
  "decode_checkpoint (encode_checkpoint s) = Some s"
  by simp
lemma exact_event_roundtrip:
  "decode_event (encode_event e) = Some e"
  by simp
lemma exact_command_roundtrip:
  "decode_command (encode_command c) = Some c"
  by simp
lemma truncated_checkpoint_rejected:
  "decode_authority_state (truncate_metadata (encode_authority_state s)) = None"
  by (simp add: encode_authority_state_def decode_authority_state_def)
lemma unknown_event_rejected:
  "decode_event (WireNode 9999 []) = None"
  by (simp add: decode_event_def)
lemma malformed_ack_rejected:
  "decode_event (truncate_metadata (encode_event (DurableAck a b c))) = None"
  by (simp add: decode_event_def)
lemma wrong_schema_rejected:
  "decode_checkpoint (WireNode 3 [WireNat (Suc metadata_schema_identity), body]) = None"
  by (simp add: decode_checkpoint_def open_metadata_def)
lemma malformed_boolean_rejected:
  "decode_bool (WireNat 2) = None"
  by simp
lemma negative_zero_rejected:
  "decode_int (WireNode 4 [WireNat 1, WireNat 0]) = None"
  by (simp add: decode_int_def)
lemma oversized_character_rejected:
  "decode_char (WireNat 256) = None"
  by (simp add: decode_char_def)
lemma exact_negative_metric_roundtrip:
  "decode_metric_value (encode_metric_value (ExactMetricValue (- (10^40)) 1000)) = Some (ExactMetricValue (- (10^40)) 1000)"
  by (rule decode_encode_metric_value)
lemma malformed_list_rejected:
  "decode_list decode_nat (WireNode 3 [WireNat 1]) = None"
  by simp

text \<open>The generated decoder returns event data, not an authorization grant.
These examples intentionally encode privileged events; only the separately
protected native event-token boundary may choose to execute such data.\<close>
ML \<open>
  val base = @{code initial_state};
  val checkpoint = @{code encode_checkpoint} base;
  val _ = (case @{code decode_checkpoint} checkpoint of
    NONE => error "checkpoint roundtrip failed" | SOME _ => ());
  val n = @{code nat_of_integer} 17;
  val e = @{code RetireCapability} n;
  val wire = @{code encode_event_frame} e;
  val restored = (case @{code decode_event_frame} wire of
    NONE => error "event roundtrip failed" | SOME x => x);
  val (next, _) = @{code step} base restored;
  val _ = if @{code retired_capabilities} next = [n] then ()
    else error "decoded data does not match generated step";
  val ack_wire = @{code encode_event} (@{code DurableAck} (n,n,n));
  val malformed = @{code truncate_metadata} ack_wire;
  val _ = (case @{code decode_event} malformed of NONE => ()
    | SOME _ => error "truncated acknowledgement accepted");
  val large_negative = @{code int_of_integer} (~ (IntInf.pow (10, 40)));
  val negative_wire = @{code encode_int} large_negative;
  val _ = (case @{code decode_int} negative_wire of SOME z =>
      if z = large_negative then () else error "signed integer changed"
    | NONE => error "exact negative integer rejected");
  val _ = writeln "VERI7VN_MODEL metadata_codec PASS";
\<close>

lemma forget_roots_roundtrip:
  "decode_event (encode_event (ForgetRoots roots)) = Some (ForgetRoots roots)"
  by (rule decode_encode_event)
lemma malformed_forget_roots_rejected:
  "decode_event (truncate_metadata (encode_event (ForgetRoots roots))) = None"
  by (simp add: decode_event_def)

ML \<open>
  val roots = [@{code nat_of_integer} 17, @{code nat_of_integer} 18];
  val original = @{code ForgetRoots} roots;
  val restored = (case @{code decode_event_frame} (@{code encode_event_frame} original) of
    SOME event => event | NONE => error "List-root forget codec rejected exact event");
  val (forgotten, commands) = @{code step} @{code initial_state} restored;
  val _ = if forall (fn root => member (op =) (@{code forgotten_objects} forgotten) root) roots
    andalso @{code authority_epoch} forgotten = @{code nat_of_integer} 1
    andalso length commands = 3 then () else error "List-root forget was not one transition";
  val (empty, rejected) = @{code step} @{code initial_state} (@{code ForgetRoots} []);
  val _ = if empty = @{code initial_state} andalso length rejected = 1 then ()
    else error "Empty list-root forget changed authority";
  val _ = if @{code step} @{code initial_state} (@{code ForgetRoots} [hd roots,hd roots,hd(tl roots)]) =
      @{code step} @{code initial_state} original then ()
    else error "Duplicate roots changed atomic removal commands";
  val (revoked, _) = @{code step} @{code initial_state} (@{code Revoke} (hd roots));
  val (erased, _) = @{code step} revoked (@{code ForgetRoots} [hd roots]);
  val _ = if null (@{code new_revoked_objects} revoked erased) andalso
      @{code new_forgotten_objects} revoked erased = [hd roots] then ()
    else error "Revoke then Forget lost category-specific erasure delta";
  val (again, _) = @{code step} erased (@{code ForgetRoots} [hd roots]);
  val _ = if null (@{code new_forgotten_objects} erased again) then ()
    else error "Repeated Forget replayed cumulative erasure delta";
  val _ = writeln "VERI7VN_MODEL forget_roots_codec PASS";
\<close>

end
