theory Native_Linkage_Probe
  imports "Native_Linkage_Base.Native_Linkage_Base"
begin

text \<open>Controlled definition elaboration: the accepted recipe is a bounded natural
shift, constructed as a typed term. No worker command text is evaluated.\<close>
local_setup \<open>fn lthy =>
  let
    val offset = 2;
    val _ = if offset >= 0 andalso offset <= 1000 then () else error "recipe bound";
    val rhs = Abs ("n", HOLogic.natT,
      @{term "(+) :: nat \<Rightarrow> nat \<Rightarrow> nat"} $ Bound 0 $ HOLogic.mk_number HOLogic.natT offset);
    val ((_, (_, th)), lthy') = Local_Theory.define
      ((Binding.name "recipe_shift", NoSyn), ((Binding.name "recipe_shift_def", []), rhs)) lthy;
    val _ = if Thm.nprems_of th = 0 then () else error "recipe definition obligations";
  in lthy' end\<close>
lemma recipe_shift_semantics: "recipe_shift n = n + 2"
  by (simp add: recipe_shift_def)


ML \<open>
(* The parent session's checked observations travel with its pinned heap.
   Re-emission is explicit, not a fresh timing run after a cached parent build. *)
val _ = writeln ("LINKAGE BASE_HEAP_REPLAY measured_at_epoch=" ^ Linkage_Probe.measured_at);
val _ = List.app writeln (rev (!Linkage_Probe.observations));
val _ = Linkage_Probe.assert "controlled_definition"
  (null (Thm.hyps_of @{thm recipe_shift_def}) andalso
   Thm.nprems_of @{thm recipe_shift_def} = 0 andalso
   null (Thm_Deps.all_oracles [@{thm recipe_shift_def}]));
val linkage_receiver = @{theory};
val _ = Linkage_Probe.assert "proof_recording" (Proofterm.get_proofs_level () = 2);
\<close>
lemma worker_private: "(n::nat) = n" by (rule refl)
lemma worker_export: "(n::nat) = n" by (rule worker_private)
setup \<open>fn thy =>
  let
    val p = Thm.global_cterm_of thy (Free ("P", propT));
    val private0 = Thm.forall_intr p (Thm.implies_intr p (Thm.assume p));
    val (private, thy1) = Global_Theory.add_thm
      ((Binding.name "worker_imp_private", private0), []) thy;
    val exported = Thm.forall_intr p (Thm.forall_elim p private);
    val (_, thy2) = Global_Theory.add_thm
      ((Binding.name "worker_imp_export", exported), []) thy1;
  in thy2 end\<close>

ML \<open>
local
  open Proofterm;
  fun shape label p =
    let
      fun add s = AList.map_default (op =) (s, 0) (fn n => n + 1);
      fun walk MinProof = add "MinProof"
        | walk (Abst (_, T, q)) =
            (if is_none T then add "Abst_missing_type" else I) #> walk q
        | walk (AbsP (_, t, q)) =
            (if is_none t then add "AbsP_missing_term" else I) #> walk q
        | walk (q % t) =
            (if is_none t then add "application_missing_term" else I) #> walk q
        | walk (q %% r) = walk q #> walk r
        | walk (PAxm (_, _, Ts)) =
            (if is_none Ts then add "axiom_missing_types" else I)
        | walk (PThm ({thm_name, types, ...}, _)) =
            (if is_none types then add "theorem_missing_types" else I) #>
            (if Thm_Name.is_empty (#1 thm_name) then add "anonymous_reference" else I)
        | walk (Oracle _) = add "Oracle"
        | walk (Hyp _) = add "Hyp"
        | walk _ = I;
      val counts = walk p [];
    in writeln ("LINKAGE SHAPE " ^ label ^ " " ^
      commas (map (fn (s, n) => s ^ "=" ^ string_of_int n) counts)) end;
  val target = Thm.prop_of @{thm worker_export};
  val source = Thm.reconstruct_proof_of @{thm worker_export};
  val _ = shape "source" source;
  val approved_names = Thm_Name.Table.build
    (Global_Theory.all_thms_of linkage_receiver true |> fold_rev Thm_Name.Table.update);
  fun header_text ({serial, theory_name, thm_name, prop, ...}: thm_header) =
    "serial=" ^ string_of_int serial ^ " theory=" ^ theory_name ^
    " name=" ^ Thm_Name.print (#1 thm_name) ^ " prop=" ^
    Syntax.string_of_term @{context} prop;
  fun available ({thm_name, ...}: thm_header) =
    Thm_Name.Table.defined approved_names (#1 thm_name);
  fun inspect_missing p =
    let
      fun walk (Abst (_, _, q)) seen = walk q seen
        | walk (AbsP (_, _, q)) seen = walk q seen
        | walk (q % _) seen = walk q seen
        | walk (q %% r) seen = walk r (walk q seen)
        | walk (PThm (header, body)) seen =
            if available header orelse member (op =) seen (#serial header) then seen
            else let val body_proof = thm_body_proof_open body;
              val _ = writeln ("LINKAGE MISSING_BODY " ^ header_text header);
              val _ = shape ("body_serial=" ^ string_of_int (#serial header)) body_proof;
            in walk body_proof (#serial header :: seen) end
        | walk _ seen = seen;
    in ignore (walk p []) end;
  val _ = inspect_missing source;
  fun local_name header =
    if available header then NONE
    else (writeln ("LINKAGE EXPAND " ^ header_text header); SOME Thm_Name.none);
  val expansion_timer = Timing.start ();
  val expanded = expand_proof @{theory} local_name source
    |> reconstruct_proof @{theory} target |> no_thm_proofs;
  val expansion_timing = Timing.result expansion_timer;
  val _ = shape "expanded" expanded;
  val xml = encode @{theory} expanded;
  val wire = YXML.string_of_body xml;
  (* Parse only after a byte bound; production framing must enforce it before allocation. *)
  fun receive max_bytes expected bytes =
    if size bytes > max_bytes then error "proof byte bound"
    else Timeout.apply (Time.fromSeconds 5) (fn () =>
      let
        val p = decode linkage_receiver (YXML.parse_body bytes);
        val _ = shape "decoded" p;
        val _ = fold_proof_atoms true (fn Hyp _ => K (error "hypothesis forbidden")
          | Oracle _ => K (error "oracle forbidden") | _ => I) [p] ();
        val th = Proof_Checker.thm_of_proof linkage_receiver p;
        val _ = if Thm.prop_of th aconv expected andalso null (Thm.hyps_of th)
          andalso Thm.nprems_of th = length (Logic.strip_imp_prems expected) andalso
          null (Thm_Deps.all_oracles [th])
          then () else error "target or sequent mismatch";
      in th end) ();
  fun rejected f = (case Exn.capture f () of Exn.Exn _ => true | _ => false);
  val timer = Timing.start ();
  val transported = Exn.capture (receive 100000 target) wire;
  val timing = Timing.result timer;
  val _ = (case transported of
      Exn.Res received => Linkage_Probe.assert "private_expansion_transport"
        (Thm.prop_of received aconv target)
    | Exn.Exn exn => writeln ("LINKAGE PRIVATE_TRANSPORT UNSUPPORTED " ^ Runtime.exn_message exn));
  val implication_target = Thm.prop_of @{thm worker_imp_export};
  val implication_source = Thm.reconstruct_proof_of @{thm worker_imp_export};
  val _ = shape "implication_source" implication_source;
  val _ = inspect_missing implication_source;
  val implication_timer = Timing.start ();
  val implication_proof = expand_proof @{theory} local_name implication_source
    |> reconstruct_proof @{theory} implication_target |> no_thm_proofs;
  val _ = shape "implication_expanded" implication_proof;
  val implication_wire = encode @{theory} implication_proof |> YXML.string_of_body;
  val implication_received = receive 100000 implication_target implication_wire;
  val implication_timing = Timing.result implication_timer;
  val _ = Linkage_Probe.assert "private_implication_transport"
    (Thm.prop_of implication_received aconv implication_target andalso
      Thm.nprems_of implication_received = 0);
  val _ = writeln ("LINKAGE PRIVATE_IMPLICATION bytes=" ^ string_of_int (size implication_wire) ^
    " total_ms=" ^ Real.toString (Time.toReal (#elapsed implication_timing) * 1000.0));
  (* Strict repair for concrete anonymous class evidence already true in the
     RECEIVER. The native checker independently executes its PClass rule. *)
  fun normalize_class_atoms prf =
    (case prf of
      Abst (s,T,p) => Abst (s,T,normalize_class_atoms p)
    | AbsP (s,t,p) => AbsP (s,t,normalize_class_atoms p)
    | p % t => normalize_class_atoms p % t
    | p %% q => normalize_class_atoms p %% normalize_class_atoms q
    | p as PThm (header as {types,prop,...},body) =>
        if available header then p else
        (case try Logic.dest_of_class prop of
          SOME (T,c) =>
            if types = SOME [] andalso null (Term.add_tvars prop []) andalso
              null (Term.add_tfrees prop []) andalso null (Term.add_vars prop []) andalso
              null (Term.add_frees prop []) andalso Sign.of_sort linkage_receiver (T,[c])
            then (writeln ("LINKAGE NORMALIZE_CLASS " ^ header_text header); PClass (T,c))
            else p
        | NONE =>
            let val normalized_body = thm_body_proof_open body
              |> reconstruct_proof @{theory} prop |> normalize_class_atoms;
            in PThm (header, thm_body (no_proof_body ZTerm.ZNop normalized_body)) end)
    | p => p);
  val normalized_timer = Timing.start ();
  val normalized = normalize_class_atoms source
    |> expand_proof @{theory} local_name
    |> reconstruct_proof @{theory} target |> no_thm_proofs;
  val _ = shape "class_normalized" normalized;
  val normalized_wire = encode @{theory} normalized |> YXML.string_of_body;
  val normalized_th = receive 100000 target normalized_wire;
  val normalized_timing = Timing.result normalized_timer;
  val _ = Linkage_Probe.assert "class_normalized_private_transport"
    (Thm.prop_of normalized_th aconv target);
  val _ = writeln ("LINKAGE NORMALIZED_PRIVATE bytes=" ^ string_of_int (size normalized_wire) ^
    " total_ms=" ^ Real.toString (Time.toReal (#elapsed normalized_timing) * 1000.0));
  (* Approved named references do not require unavailable ancestor proof bodies. *)
  val reference_target = Thm.prop_of @{thm TrueI};
  val reference_wire = Thm.reconstruct_proof_of @{thm TrueI}
    |> no_thm_proofs |> encode @{theory} |> YXML.string_of_body;
  val reference_received = receive 100000 reference_target reference_wire;
  val _ = Linkage_Probe.assert "approved_reference_transport"
    (Thm.prop_of reference_received aconv reference_target);
  val _ = Linkage_Probe.assert "unexpanded_private_rejected"
    (rejected (fn () => receive 100000 target (YXML.string_of_body (encode @{theory} (no_thm_proofs source)))));
  val _ = Linkage_Probe.assert "wrong_target_rejected"
    (rejected (fn () => receive 100000 @{prop False} reference_wire));
  val _ = Linkage_Probe.assert "oversize_rejected" (rejected (fn () => receive 1 target wire));
  val _ = Linkage_Probe.assert "oracle_node_rejected"
    (rejected (fn () => receive 100000 @{prop False}
      (YXML.string_of_body (encode @{theory} (Oracle ("worker", @{prop False}, SOME []))))));
  val _ = Linkage_Probe.assert "hypothesis_rejected"
    (rejected (fn () => receive 100000 @{prop False}
      (YXML.string_of_body (encode @{theory} (Hyp @{prop False})))));
  val _ = writeln ("LINKAGE TRANSPORT bytes=" ^ string_of_int (size wire) ^
    " expansion_ms=" ^ Real.toString (Time.toReal (#elapsed expansion_timing) * 1000.0) ^
    " receiver_ms=" ^ Real.toString (Time.toReal (#elapsed timing) * 1000.0));

  val _ = Linkage_Probe.assert "feasibility_complete" true;
in end;
\<close>
end
