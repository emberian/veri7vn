theory Registry_Tests imports Veri7vn_Registry begin
ML \<open>
local
  structure R = Veri7vn_Native_Registry;
  val deps = {packages=["test"], runtime="test", policy="test", sources=[], interpretation="test"};
  val g = R.generation @{context} deps;
  val h = R.generation @{context} deps;
  val (ct, r1) = R.insert g "target" (R.Certified @{cterm "True"}) R.empty;
  val (th, r2) = R.insert g "proof" (R.Theorem @{thm TrueI}) r1;
  fun reject f = (case Exn.capture f () of Exn.Exn _ => true | _ => false);
  fun check name b = if b then writeln ("REGISTRY " ^ name ^ " PASS") else error name;
  val _ = check "native_objects" (case R.lookup g th r2 of R.Theorem t => Thm.eq_thm_prop (t, @{thm TrueI}) | _ => false);
  val _ = check "immutable_snapshot" (is_none (R.named g "proof" r1));
  val _ = check "non_rebinding" (reject (fn () => R.insert g "proof" (R.Theorem @{thm TrueI}) r2));
  val _ = check "generation_guard" (reject (fn () => R.lookup h ct r2));
  val _ = check "missing_snapshot_handle" (reject (fn () => R.lookup g th r1));
  val (ctx_handle, rctx) = R.insert g "context" (R.Context @{context}) r2;
  val _ = check "native_context" (case R.lookup g ctx_handle rctx of
    R.Context ctxt => Context.eq_thy (Proof_Context.theory_of ctxt, @{theory}) | _ => false);
  val (_, trimmed_store) = R.insert g "trimmed-theorem" (R.Theorem (Thm.trim_context @{thm TrueI})) r2;
  val (_, _) = R.insert g "trimmed-cterm" (R.Certified (Thm.trim_context_cterm @{cterm True})) trimmed_store;
  val _ = check "trimmed_native_certificates" true;
  val assumed = Thm.assume @{cprop False};
  val (candidate, r3) = R.insert g "candidate" (R.Theorem assumed) r2;
  val _ = check "candidate_not_admission" (case R.lookup g candidate r3 of
    R.Theorem t => not (null (Thm.hyps_of t)) | _ => false);
  structure P = Veri7vn_Native_Profiles;
  val profile = P.declare g {carrier = @{typ "nat => bool"}, representation = NONE,
    numeric = P.Exact, shape = @{cterm True}, scope = P.Complete,
    literal_policy = "case-sensitive-original-bytes", display_projection = NONE,
    materialization_limit = NONE, dependencies = [th]};
  val _ = check "proof_only_open_carrier" (is_none (#representation (P.inspect profile)));
  val literal_input = Veri7vn_Native_Literals.input {bytes="A  B\nC", encoding="raw"};
  val literal = {source = Veri7vn_Native_Literals.slice literal_input {start=0, stop=6, expected="A  B\nC"}, encoding = P.Bytes, case_policy = P.Case_Sensitive,
    normalization = "none", escaping = "none"};
  val _ = check "lossless_literal" (P.original_literal (P.retain_literal literal) = "A  B\nC");
  structure L = Veri7vn_Native_Literals;
  val input = L.input {bytes = "a\nA  B", encoding = "UTF-8-unvalidated"};
  val slice = L.slice input {start=2, stop=6, expected="A  B"};
  val _ = check "literal_ownership" (L.same_input (input, L.owner slice) andalso L.original slice = "A  B");
  val _ = check "literal_wrong_slice" (reject (fn () => L.slice input {start=2, stop=6, expected="a b"}));
  val _ = check "literal_bounds" (reject (fn () => L.slice input {start=0, stop=7, expected=""}));
  structure E = Veri7vn_Executable_Identity;
  val manifest = {artifact="test", compiler="Isabelle-codegen-SML", target="SML",
    serializers=[], foreign_primitives=[], settings=[]};
  val executable = E.pin @{theory} manifest;
  val another = E.pin @{theory} manifest;
  val _ = check "executable_identity" (not (E.same (executable, another)) andalso
    E.exact_code_context executable @{theory});
  val changed = Code.declare_unimplemented_global @{const_name Not} @{theory};
  val _ = check "code_setup_identity" (not (E.exact_code_context executable changed));
  structure Values = Veri7vn_Typed_Runtime_Store (struct
    type value = Word8Vector.vector;
    type continuation = int list;
    val executable = executable;
  end);
  val bulk = Word8Vector.tabulate (100000, fn i => Word8.fromInt (i mod 256));
  val (vh, values) = Values.put_value bulk Values.empty;
  val (kh, values2) = Values.put_continuation [1,2,3] values;
  val _ = check "typed_bulk_retention" (Word8Vector.length (Values.value executable vh values2) = 100000);
  val _ = check "continuation_retention" (Values.continuation executable kh values2 = [1,2,3]);
  val _ = check "runtime_generation_guard" (reject (fn () => Values.value another vh values2));
  val _ = check "continuation_generation_guard" (reject (fn () => Values.continuation another kh values2));
  val _ = check "runtime_snapshot_guard" (reject (fn () => Values.value executable vh Values.empty));
  val released = values2 |> Values.remove_value vh |> Values.remove_continuation kh;
  val _ = check "runtime_release" (reject (fn () => Values.value executable vh released) andalso
    reject (fn () => Values.continuation executable kh released));
  val _ = check "release_preserves_other_kind" (Values.continuation executable kh (Values.remove_value vh values2) = [1,2,3]);
  structure Recovery = Veri7vn_Recovery_Manifest;
  val digest = implode (replicate 64 "a");
  val manifest: Recovery.manifest = {profile=Recovery.KernelEvidence,workspace=implode (replicate 32 "b"),association=42,semantic_generation=7,
    projection=digest,sequent=digest,context_closure=digest,
    reconstruction=Recovery.Fixed_Certificate,payload=digest,executable=NONE};
  val envelope = Recovery.encode manifest;
  val recovered = Recovery.decode {max_bytes=8192} envelope;
  val _ = check "recovery_locator_roundtrip" (#association recovered=42 andalso #workspace recovered = #workspace manifest);
  val _ = check "recovery_envelope_bound" (reject (fn () => Recovery.decode {max_bytes=10} envelope));
  val removed_native = R.remove_object g th r2;
  val _ = check "native_object_release" (is_none (R.named g "proof" removed_native) andalso
    reject (fn () => R.lookup g th removed_native));
  val dropped_native = R.drop_generation g r2;
  val _ = check "native_generation_release" (is_none (R.named g "target" dropped_native) andalso
    reject (fn () => R.lookup g ct dropped_native));
  val hostile_envelope = YXML.string_of_body [XML.Elem (("x",[]),[XML.Elem (("y",[]),[])])];
  val _ = check "recovery_depth_guard" (reject (fn () => Recovery.decode {max_bytes=8192} hostile_envelope));
  structure Sequent = Veri7vn_Native_Sequent;
  val saved_sequent = Sequent.capture @{cprop True} @{thm TrueI};
  val sequent_bytes = Sequent.encode saved_sequent;
  val decoded_sequent = Sequent.decode {max_bytes=1048576,max_depth=256,max_nodes=100000} sequent_bytes;
  val _ = check "native_sequent_roundtrip" (Sequent.matches decoded_sequent @{cprop True} @{thm TrueI});
  val _ = check "native_sequent_target_certification" (Thm.term_of (Sequent.certify_target @{context} decoded_sequent) aconv @{prop True});
  val _ = check "native_sequent_wrong_meaning" (not (Sequent.matches decoded_sequent @{cprop False} @{thm TrueI}));
  val _ = check "native_sequent_conditionality" (not (Sequent.matches decoded_sequent @{cprop True} (Thm.weaken @{cprop False} @{thm TrueI})));
  val _ = check "native_sequent_byte_bound" (reject (fn () => Sequent.decode {max_bytes=10,max_depth=256,max_nodes=100000} sequent_bytes));
  val _ = check "native_sequent_depth_bound" (reject (fn () => Sequent.decode {max_bytes=1048576,max_depth=1,max_nodes=100000} sequent_bytes));
  val _ = check "native_sequent_node_bound" (reject (fn () => Sequent.decode {max_bytes=1048576,max_depth=256,max_nodes=1} sequent_bytes));
  val forgotten_input = L.input {bytes="private",encoding="raw"};
  val forgotten_slice = L.slice forgotten_input {start=0,stop=7,expected="private"};
  val _ = L.forget_input forgotten_input;
  val _ = check "forgotten_literal_release" (not (L.retained forgotten_input) andalso
    reject (fn () => L.bytes forgotten_input) andalso reject (fn () => L.original forgotten_slice));
  structure Managed = Veri7vn_Managed_Native_Unit;
  val shared_input = L.input {bytes="shared",encoding="raw"};
  val unit_a = Managed.create {generation=g,inputs=[shared_input],objects=[ct,th]} r2;
  val unit_b = Managed.create {generation=g,inputs=[shared_input],objects=[ct]} r2;
  val unit_alias = unit_a;
  val detached_unit = Managed.release unit_a;
  val _ = check "managed_unit_alias_release" (is_some detached_unit andalso
    is_none (Managed.inspect unit_alias) andalso is_none (Managed.release unit_alias));
  val _ = check "managed_unit_shared_input_preserved" (is_some (Managed.inspect unit_b) andalso
    L.bytes shared_input="shared");
  val _ = check "managed_unit_owner_guard" (reject (fn () => Managed.create {generation=h,inputs=[],objects=[ct]} r2));
  val equal_bytes_input = L.input {bytes="shared",encoding="raw"};
  val _ = check "input_locator_noncontent" (L.input_locator shared_input <> L.input_locator equal_bytes_input andalso
    not (L.same_input (shared_input,equal_bytes_input)));
  val _ = check "recovery_positive_ids" (reject (fn () => Recovery.encode
    {profile=Recovery.KernelEvidence,workspace= #workspace manifest,association=0,semantic_generation=7,
      projection=digest,sequent=digest,context_closure=digest,
      reconstruction=Recovery.Fixed_Certificate,payload=digest,executable=NONE}));
  val too_large_id = the (IntInf.fromString ("1" ^ implode (replicate 128 "0")));
  val _ = check "recovery_id_digit_bound" (reject (fn () => Recovery.encode
    {profile=Recovery.KernelEvidence,workspace= #workspace manifest,association=too_large_id,semantic_generation=7,
      projection=digest,sequent=digest,context_closure=digest,
      reconstruction=Recovery.Fixed_Certificate,payload=digest,executable=NONE}));
  fun role_manifest profile executable reconstruction: Recovery.manifest =
    {profile=profile,workspace= #workspace manifest,association=42,semantic_generation=7,
      projection=digest,sequent=digest,context_closure=digest,
      reconstruction=reconstruction,payload=digest,executable=executable};
  val math_request_manifest=role_manifest Recovery.MathRequest (SOME digest) Recovery.Controlled_Recipe;
  val math_output_manifest=role_manifest Recovery.MathOutput (SOME digest) Recovery.Controlled_Recipe;
  val decoded_request_manifest=Recovery.decode {max_bytes=8192} (Recovery.encode math_request_manifest);
  val decoded_output_manifest=Recovery.decode {max_bytes=8192} (Recovery.encode math_output_manifest);
  val _=check "recovery_v2_roles" (#profile recovered=Recovery.KernelEvidence andalso
    decoded_request_manifest=math_request_manifest andalso decoded_output_manifest=math_output_manifest);
  val _=check "recovery_cross_profile_guard" (reject (fn () => Recovery.require_profile Recovery.KernelEvidence decoded_output_manifest));
  val _=check "recovery_math_requires_code" (reject (fn () => Recovery.encode (role_manifest Recovery.MathRequest NONE Recovery.Controlled_Recipe)));
  val _=check "recovery_kernel_no_code_coercion" (reject (fn () => Recovery.encode (role_manifest Recovery.KernelEvidence (SOME digest) Recovery.Native_Proof)));
  val _=check "recovery_math_no_kernel_proof" (reject (fn () => Recovery.encode (role_manifest Recovery.MathOutput (SOME digest) Recovery.Native_Proof)));
  fun altered_envelope edits = (case YXML.parse_body envelope of
    [XML.Elem ((name,attrs),body)] => YXML.string_of_body [XML.Elem
      ((name,fold (fn (key,value) => AList.update (op =) (key,value)) edits attrs),body)]
    | _ => error "test envelope");
  val _=check "recovery_unknown_version" (reject (fn () => Recovery.decode {max_bytes=8192} (altered_envelope [("version","3")])));
  val legacy_envelope=(case YXML.parse_body (altered_envelope [("version","1")]) of
    [XML.Elem ((name,attrs),body)]=>YXML.string_of_body [XML.Elem
      ((name,filter (fn (key,_)=>key<>"profile" andalso key<>"role") attrs),body)]
    | _=>error "test legacy envelope");
  val _=check "recovery_v1_not_reinterpreted" (reject (fn () => Recovery.decode {max_bytes=8192} legacy_envelope));
  val _=check "recovery_unknown_profile" (reject (fn () => Recovery.decode {max_bytes=8192} (altered_envelope [("profile","native-kernel/2")])));
  val _=check "recovery_unknown_role" (reject (fn () => Recovery.decode {max_bytes=8192} (altered_envelope [("role","kernel-result")])));
  val _=check "recovery_mixed_profile_role" (reject (fn () => Recovery.decode {max_bytes=8192} (altered_envelope [("role","math-output")])));
  val leased_input=L.input {bytes="shared-private",encoding="raw"};
  val p_lease=L.retain leased_input;
  val r_lease=L.retain leased_input;
  val leased_unit_a=Managed.create {generation=g,inputs=[leased_input,leased_input],objects=[]} r2;
  val leased_unit_b=Managed.create {generation=g,inputs=[leased_input],objects=[]} r2;
  val _=check "literal_base_transfer" (is_none (L.drop_base leased_input) andalso not (L.disposed leased_input));
  val _=check "literal_independent_consumer_release" (is_none (L.release p_lease) andalso
    L.bytes leased_input="shared-private" andalso L.same_input (L.lease_input r_lease,leased_input));
  val _=check "literal_lease_release_idempotent" (is_none (L.release p_lease) andalso
    reject (fn()=>L.lease_input p_lease));
  val _=ignore (L.release r_lease);
  val _=ignore (Managed.release leased_unit_a);
  val _=check "managed_unit_independent_lease" (L.bytes leased_input="shared-private");
  val _=ignore (Managed.release leased_unit_b);
  val _=check "managed_unit_last_owner_disposes" (L.disposed leased_input andalso
    is_none (L.drop_base leased_input) andalso reject (fn()=>L.bytes leased_input));
  val invalidated_input=L.input {bytes="cancelled",encoding="raw"};
  val invalidated_lease=L.retain invalidated_input;
  val _=ignore (L.drop_base invalidated_input);
  val _=L.invalidate invalidated_input;
  val _=check "literal_invalidation_before_drain" (not (L.retained invalidated_input) andalso
    not (L.disposed invalidated_input) andalso reject (fn()=>L.bytes invalidated_input) andalso
    reject (fn()=>L.retain invalidated_input) andalso reject (fn()=>L.lease_input invalidated_lease));
  val final_disposer=L.release invalidated_lease;
  val _=check "literal_final_disposal_winner" (case final_disposer of SOME input=>
    L.same_input (input,invalidated_input) andalso L.disposed input andalso
    is_none (L.release invalidated_lease) | NONE=>false);
  val rollback_input=L.input {bytes="rollback",encoding="raw"};
  val unusable_input=L.input {bytes="unusable",encoding="raw"};
  val _=L.invalidate unusable_input;
  val _=check "managed_unit_partial_retain_rollback" (reject (fn()=>Managed.create
    {generation=g,inputs=[rollback_input,unusable_input],objects=[]} r2) andalso
    is_some (L.drop_base rollback_input) andalso L.disposed rollback_input);
  val _=ignore (L.drop_base unusable_input);
  val base_only=L.input {bytes="base",encoding="raw"};
  val _=check "literal_base_disposal_idempotent" (is_some (L.drop_base base_only) andalso
    is_none (L.drop_base base_only) andalso L.disposed base_only);
  val interrupt_input=L.input {bytes="interrupt-boundary",encoding="raw"};
  val interrupt_unit=Managed.create {generation=g,inputs=[interrupt_input],objects=[]} r2;
  val _=ignore (L.drop_base interrupt_input);
  val interrupted_cleanup=Exn.capture (fn () => Thread_Attributes.uninterruptible_body (fn restore =>
    let
      val _=Thread.Thread.interrupt (Thread.Thread.self ());
      val _=ignore (Managed.release interrupt_unit);
    in restore Thread.Thread.testInterrupt () end)) ();
  val _=check "literal_pending_interrupt_cleanup" ((case interrupted_cleanup of
    Exn.Exn exn=>Exn.is_interrupt exn | _=>false) andalso L.disposed interrupt_input andalso
    is_none (Managed.inspect interrupt_unit) andalso is_none (Managed.release interrupt_unit));
  val forget_base=L.input {bytes="forget-base",encoding="raw"};
  val _=L.forget_input forget_base;
  val _=check "literal_forget_final_base" (L.disposed forget_base andalso
    not (L.retained forget_base) andalso is_none (L.drop_base forget_base));
  val forget_shared=L.input {bytes="forget-shared",encoding="raw"};
  val forget_lease_a=L.retain forget_shared;
  val forget_lease_b=L.retain forget_shared;
  val _=L.forget_input forget_shared;
  val _=check "literal_forget_sibling_drain" (not (L.retained forget_shared) andalso
    not (L.disposed forget_shared) andalso is_none (L.release forget_lease_a) andalso
    not (L.disposed forget_shared) andalso is_some (L.release forget_lease_b) andalso
    L.disposed forget_shared andalso is_none (L.drop_base forget_shared));
in end;
\<close>
end
