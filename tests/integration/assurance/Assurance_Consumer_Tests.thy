theory Assurance_Consumer_Tests
  imports Veri7vn_Admission.Veri7vn_Admission
begin

text \<open>Exercise the real inert proof producer, admission gate, native descriptor
and durable sequent comparator together. True is deliberately a retained local
hypothesis: its acceptance must never be confused with an unconditional theorem.\<close>

ML \<open>
local
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  structure D = Veri7vn_Native_Descriptor;
  structure S = Veri7vn_Native_Sequent;
  val thy = @{theory};
  val gen = R.generation @{context}
    {packages=[],runtime="assurance-consumer",policy="kernel",sources=[],interpretation="exact"};
  val pol = A.policy thy;
  val ids = Veri7vn_Native_Identity_Allocator.install_host_block
    {workspace="000000000000000000000000000000a4",first=4000000000,past=4000010000};
  fun check name yes = if yes then writeln ("ASSURANCE " ^ name ^ " PASS") else error name;
  fun rejected (A.Rejected _) = true | rejected _ = false;
  fun receive th hyps prems target = Veri7vn_Proof_Transport.receive pol gen
    {claim=A.exact_claim target,hypotheses=hyps,premises=prems,sorts=Thm.shyps_of th}
    (Veri7vn_Proof_Transport.export thy thy th);
  fun accepted (A.Accepted a) = a
    | accepted (A.Rejected messages) = error (space_implode "; " messages);
  val conditional = Thm.assume @{cprop True};
  val a = accepted (receive conditional [@{prop True}] [] @{cprop True});
  val d = D.register ids a;
  val p = D.project d;
  val _ = check "transport_descriptor_retains_hypothesis"
    (#conditional p andalso length (#premises p)=1 andalso
      (case D.resolve_premise d (hd (#premises p)) of
        SOME t => t aconv @{prop True} | NONE => false));
  val _ = check "transport_cannot_erase_hypothesis"
    (rejected (receive conditional [] [] @{cprop True}));
  val _ = check "transport_cannot_strengthen_target"
    (rejected (receive conditional [@{prop True}] [] @{cprop False}));
  val premise_th = Thm.implies_intr @{cprop False} (Thm.assume @{cprop False});
  val b = accepted (receive premise_th [] [@{prop False}] (Thm.cprop_of premise_th));
  val e = D.register ids b;
  val q = D.project e;
  val _ = check "transport_descriptor_retains_explicit_premise"
    (#conditional q andalso length (#premises q)=1 andalso
      (case D.resolve_premise e (hd (#premises q)) of
        SOME t => t aconv @{prop False} | NONE => false));
  val _ = check "transport_cannot_erase_explicit_premise"
    (rejected (receive premise_th [] [] (Thm.cprop_of premise_th)));
  val snapshot = S.capture (A.target a) (A.theorem a) |> S.encode |>
    S.decode {max_bytes=1048576,max_depth=128,max_nodes=20000};
  val _ = check "accepted_sequent_roundtrip"
    (S.matches snapshot (A.target a) (A.theorem (D.accepted d)));
  val _ = check "durable_sequent_rejects_hypothesis_erasure"
    (not (S.matches snapshot @{cprop True} @{thm TrueI}));
  val _ = check "descriptor_has_no_source_provenance_by_receipt"
    (not (D.provenance_complete d));
  structure P = Veri7vn_Managed_Provenance;
  structure L = Veri7vn_Native_Literals;
  val root = P.public_image ids pol;
  val input = L.input {bytes="True",encoding="UTF-8"};
  val owner = P.install_host_source ids input;
  val slice = L.slice input {start=0,stop=4,expected="True"};
  val wire = Veri7vn_Proof_Transport.export thy thy conditional;
  fun refused make =
    let val scope=P.construction_scope();
      val result=Exn.capture (fn()=>make scope) ();
      val _=P.abort_scope scope;
    in case result of Exn.Exn _=>true | Exn.Res _=>false end;
  val _=check "managed_producer_rejects_undeclared_hypothesis"
    (refused (fn scope=>P.prove_from_slice_owned scope root owner slice wire));
  val erased=S.capture @{cprop True} @{thm TrueI};
  val _=check "managed_producer_rejects_erased_expected_sequent"
    (refused (fn scope=>P.prove_from_slice_sequent_owned scope root owner slice erased wire));
  val scope=P.construction_scope();
  val (development,fact)=P.prove_from_slice_sequent_owned scope root owner slice snapshot wire;
  val _=P.commit_scope scope;
  val managed=D.register_produced ids fact;
  val mp=D.project managed;
  val _=check "managed_producer_descriptor_retains_conditions_and_source"
    (D.provenance_complete managed andalso #conditional mp andalso
      length(#premises mp)=1 andalso
      member (op =) (P.source_dependencies fact) (P.source_identity owner) andalso
      S.matches snapshot (A.target(D.accepted managed)) (A.theorem(D.accepted managed)));
  val recipe=the(P.proof_recipe development);
  val saved=S.decode {max_bytes=1048576,max_depth=128,max_nodes=20000} (#sequent recipe);
  val _=check "managed_retained_recipe_keeps_full_sequent"
    (#wire recipe=wire andalso S.matches saved (A.target(P.accepted fact)) (A.theorem(P.accepted fact))
      andalso not(S.matches saved @{cprop True} @{thm TrueI}));
  val _=P.release development;
  val _=check "managed_retirement_revokes_descriptor"
    (not(D.is_live managed) andalso is_none(D.resolve_target managed (#target_id mp)));
  val _=D.release managed;
  val _=P.release root;
  val _ = D.release d;
  val _ = check "released_descriptor_has_no_native_authority"
    (not (D.is_live d) andalso is_none (D.resolve_target d (#target_id p)) andalso
      is_none (D.resolve_premise d (hd (#premises p))));
  val _ = D.release e;
in end
\<close>
end
