local
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  val ctxt = @{context};
  val thy = @{theory};
  val gen = R.generation ctxt {packages=[],runtime="test",policy="test",sources=[],interpretation="test"};
  val pol = A.policy thy;
  val ids = Veri7vn_Native_Identity_Allocator.install_host_block
    {workspace="00000000000000000000000000000000",first=1000000000000000000000000000000,
      past=1000000000000000000000000060000};
  
  fun check name b = if b then writeln ("ADMISSION " ^ name ^ " PASS") else error name;
  structure I = Veri7vn_Native_Identity_Allocator;
  (* Test-image checker exercises map transactions; production instantiates only
     fixed opaque semantic verifiers, never this transparent fixture. *)
  structure Checked_Map_Fixture =
  struct
    type verified = {workspace:string,generation:R.generation,
      semantic_generation:IntInf.int} list;
    fun bindings (verified:verified)=verified;
  end;
  structure Map_Fixture = Veri7vn_Checked_Generation_Reassociation(Checked_Map_Fixture);
  val map_gen1=R.generation ctxt {packages=[],runtime="map1",policy="test",sources=[],interpretation="test"};
  val map_gen2=R.generation ctxt {packages=[],runtime="map2",policy="test",sources=[],interpretation="test"};
  val _=I.mark_staged_generation ids map_gen1;
  val _=I.mark_staged_generation ids map_gen2;
  fun map_fragment generation id=Map_Fixture.fragment
    [{workspace=I.workspace ids,generation=generation,semantic_generation=id}];
  val map_id1=I.allocate ids;
  val map_id2=I.allocate ids;
  val _=check "generation_batch_reverse_conflict" (case Exn.capture
    (fn()=>I.install_fragments ids [map_fragment map_gen1 map_id1,
      map_fragment map_gen2 map_id1]) () of Exn.Exn _=>true | _=>false);
  val _=check "generation_batch_conflict_atomic"
    (is_none(I.lookup_generation_id ids map_gen1) andalso
     is_none(I.lookup_generation_id ids map_gen2));
  val _=I.install_fragments ids [map_fragment map_gen1 map_id1,map_fragment map_gen2 map_id2];
  val _=check "generation_batch_checked_install"
    (I.lookup_generation_id ids map_gen1=SOME map_id1 andalso
     I.lookup_generation_id ids map_gen2=SOME map_id2);
  val map_gen3=R.generation ctxt {packages=[],runtime="map3",policy="test",sources=[],interpretation="test"};
  val _=I.mark_staged_generation ids map_gen3;
  val _=check "generation_existing_reverse_conflict" (case Exn.capture
    (fn()=>I.install_fragments ids [map_fragment map_gen3 map_id1]) () of
      Exn.Exn _=>is_none(I.lookup_generation_id ids map_gen3) | _=>false);
  val _=I.release_generation ids map_gen1;
  val _=I.install_fragments ids [map_fragment map_gen3 map_id1];
  val _=check "generation_owner_teardown_reassociation"
    (is_none(I.lookup_generation_id ids map_gen1) andalso
     I.lookup_generation_id ids map_gen3=SOME map_id1 andalso
     I.lookup_generation_id ids map_gen2=SOME map_id2);
  fun request ct hyps prems = {claim=A.exact_claim ct,hypotheses=hyps,premises=prems,sorts=[]};
  fun run th req = let val (h,r) = R.insert gen "candidate" (R.Theorem th) R.empty
    in A.admit pol gen r h A.Kernel req end;
  fun rejected (A.Rejected _) = true | rejected _ = false;
  val _ = check "scope_upgrade_rejected" (not
    (A.propose_scope (A.exact_claim @{cprop True})
      {modality="world probability",domain="all worlds",coverage="optimal and complete"}));
  val true_th = @{thm TrueI};
  val accepted = run true_th (request @{cprop True} [] []);
  val _ = check "actual_theorem" (case accepted of A.Accepted a =>
    Thm.prop_of (A.theorem a) aconv @{prop True} | _ => false);
  val _ = check "native_descriptor_association" (case accepted of
    A.Accepted a => let
      val d = Veri7vn_Native_Descriptor.register ids a;
      val p = Veri7vn_Native_Descriptor.project d;
    in case Veri7vn_Native_Descriptor.resolve_target d (#target_id p) of
      SOME ct => Thm.term_of ct aconv @{prop True} andalso
        not (#conditional p) andalso
        forall (member (op =) (Veri7vn_Native_Descriptor.native_object_dependencies d))
          [#claim_id p,#target_id p,#interpretation_id p,#semantic_generation p]
    | NONE => false end | _ => false);
  val _ = check "descriptor_release" (case accepted of A.Accepted a =>
    let val d=Veri7vn_Native_Descriptor.register ids a;
      val target_id = #target_id (Veri7vn_Native_Descriptor.project d);
      val _ = Veri7vn_Native_Descriptor.release d;
    in not (Veri7vn_Native_Descriptor.is_live d) andalso
      is_none (Veri7vn_Native_Descriptor.resolve_target d target_id) andalso
      (case Exn.capture Veri7vn_Native_Descriptor.accepted d of Exn.Exn _ => true | _ => false)
    end | _ => false);
  val _ = check "wrong_target" (rejected (run true_th (request @{cprop False} [] [])));
  val _ = check "sort_conditions" (rejected (run true_th
    {claim=A.exact_claim @{cprop True},hypotheses=[],premises=[],sorts=[["HOL.type"]]}));
  val _ = check "nonproposition_target" (rejected
    (run true_th (request @{cterm "0::nat"} [] [])));
  val _ = check "hidden_false" (rejected
    (run (Thm.weaken @{cprop False} true_th) (request @{cprop True} [] [])));
  val _ = check "scoped_hypothesis" (case run (Thm.assume @{cprop False})
    (request @{cprop False} [@{prop False}] []) of A.Accepted _ => true | _ => false);
  val _ = check "undeclared_premise" (rejected
    (run @{thm impI} (request (Thm.cprop_of @{thm impI}) [] [])));
  val _ = check "proof_skipping_rejected" (rejected
    (run (Skip_Proof.make_thm thy @{prop True}) (request @{cprop True} [] [])));
  val _ = check "inert_certificate" (case
    Veri7vn_Family_Certificate.count_flags pol gen {flags=[true,false,true],expected=2}
    of A.Accepted _ => true | A.Rejected messages => error (space_implode "; " messages));
  val proof_wire = Veri7vn_Proof_Transport.export thy thy true_th;
  val _ = check "inert_proofterm" (case Veri7vn_Proof_Transport.receive pol gen
    (request @{cprop True} [] []) proof_wire of A.Accepted _ => true
    | A.Rejected messages => error (space_implode "; " messages));
  val _ = check "proofterm_wrong_target" (rejected (Veri7vn_Proof_Transport.receive pol gen
    (request @{cprop False} [] []) proof_wire));
  val _ = check "proofterm_oversize" (rejected (Veri7vn_Proof_Transport.receive pol gen
    (request @{cprop True} [] []) (String.implode (replicate 100001 #"x"))));
  val _ = check "proofterm_hidden_hypothesis" (rejected (Veri7vn_Proof_Transport.receive pol gen
    (request @{cprop False} [] []) (Proofterm.encode thy (Proofterm.Hyp @{prop False})
      |> YXML.string_of_body)));
  val _ = check "wrong_certificate" (rejected
    (Veri7vn_Family_Certificate.count_flags pol gen {flags=[true,false,true],expected=3}));
  val _ = check "bounded_certificate" (rejected
    (Veri7vn_Family_Certificate.count_flags pol gen {flags=replicate 1001 true,expected=1001}));
  val ((oracle_name, oracle), oracle_thy) = Thm.add_oracle
    (Binding.name "admission_negative_only", fn () => @{cprop True}) thy;
  val oracle_ctxt = Proof_Context.init_global oracle_thy;
  val oracle_gen = R.generation oracle_ctxt
    {packages=[],runtime="test",policy="test",sources=[],interpretation="test"};
  val oracle_th = oracle () |> Thm.transfer oracle_thy;
  val (oh,orr) = R.insert oracle_gen "oracle-candidate" (R.Theorem oracle_th) R.empty;
  val _ = check "forbidden_oracle" (rejected (A.admit pol oracle_gen orr oh A.Kernel
    (request @{cprop True} [] [])));
  val derived_oracle = @{thm conjI} OF [oracle_th,true_th];
  val (doh,dor) = R.insert oracle_gen "derived-oracle" (R.Theorem derived_oracle) R.empty;
  val _ = check "transitive_oracle" (rejected
    (A.admit pol oracle_gen dor doh A.Kernel (request (Thm.cprop_of derived_oracle) [] [])));
  val explicit_oracle_policy = A.policy_with_oracles oracle_thy [oracle_name];
  val _ = check "explicit_oracle_route" (case
    A.admit explicit_oracle_policy oracle_gen orr oh (A.Oracle [oracle_name])
      (request @{cprop True} [] []) of A.Accepted a =>
        (case A.route a of A.Oracle _ => true | _ => false) | _ => false);
  val _ = check "caller_oracle_allowlist_rejected" (rejected
    (A.admit pol oracle_gen orr oh (A.Oracle [oracle_name]) (request @{cprop True} [] [])));
  val forbidden_thy = Theory.add_axiom ctxt
    (Binding.name "admission_forbidden_axiom", @{prop False}) thy;
  val _ = check "policy_advance_forbidden_axiom" (case
    Exn.capture (A.advance pol) forbidden_thy of Exn.Exn _ => true | _ => false);
  val harmless_policy = A.advance pol oracle_thy;
  val _ = check "policy_advance_keeps_oracle_policy" (rejected
    (A.admit harmless_policy oracle_gen orr oh (A.Oracle [oracle_name])
      (request @{cprop True} [] [])));
  val forbidden_gen = R.generation (Proof_Context.init_global forbidden_thy)
    {packages=[],runtime="test",policy="test",sources=[],interpretation="test"};
  val (fh,fr) = R.insert forbidden_gen "old-true" (R.Theorem true_th) R.empty;
  val _ = check "unused_forbidden_axiom" (rejected
    (A.admit pol forbidden_gen fr fh A.Kernel (request @{cprop True} [] [])));
  val (defined_policy,_,defined_th,defined_thy) = A.define pol
    (Binding.name "admission_controlled_constant") @{cterm "True"};
  val defined_gen = R.generation (Proof_Context.init_global defined_thy)
    {packages=[],runtime="test",policy="test",sources=[],interpretation="test"};
  val (dh,dr) = R.insert defined_gen "definition" (R.Theorem defined_th) R.empty;
  val _ = check "controlled_definition" (case A.admit defined_policy defined_gen dr dh A.Kernel
    (request (Thm.cprop_of defined_th) [] []) of A.Accepted _ => true | _ => false);
  structure P = Veri7vn_Managed_Provenance;
  structure L = Veri7vn_Native_Literals;
  structure N = Veri7vn_Native_Descriptor;
  val public_development=P.public_image ids pol;
  val public_fact=P.public_theorem public_development ("HOL.TrueI",0);
  val public_descriptor=N.register_produced ids public_fact;
  val _=check "public_producer" (N.provenance_complete public_descriptor andalso
    Thm.prop_of (A.theorem (N.accepted public_descriptor)) aconv @{prop True});
  val input=L.input {bytes="True",encoding="UTF-8"};
  val owner=P.install_host_source ids input;
  val owner_again=P.install_host_source ids input;
  val _=check "source_identity" (P.source_identity owner=P.source_identity owner_again);
  val slice=L.slice input {start=0,stop=4,expected="True"};
  val (development,_,consequence)=P.define_from_slice public_development owner
    (Binding.name "admission_owned_constant") slice;
  val produced=N.register_produced ids consequence;
  val parent_context=the (Veri7vn_Native_Identity_Allocator.lookup_generation_id ids
    (P.generation public_development));
  val _=check "parent_context_dependency"
    (member (op =) (#dependencies (N.project produced)) parent_context);
  val _=check "owned_definition_producer" (N.provenance_complete produced andalso
    member (op =) (#dependencies (N.project produced)) (P.source_identity owner));
  val other=L.input {bytes="True",encoding="UTF-8"};
  val _=check "producer_owner_mismatch" (case Exn.capture
    (fn () => P.define_from_slice public_development owner
      (Binding.name "unowned_constant")
      (L.slice other {start=0,stop=4,expected="True"})) () of
      Exn.Exn _ => true | _ => false);
  val embedded=L.input {bytes="\"True\"",encoding="UTF-8"};
  val embedded_owner=P.install_host_source ids embedded;
  val (embedded_dev,_,embedded_fact)=P.define_from_embedded_slice public_development
    embedded_owner (Binding.name "admission_embedded_constant")
    (L.slice embedded {start=0,stop=6,expected="\"True\""});
  val _=check "embedded_definition_producer" (P.is_live embedded_fact);
  val _=P.release embedded_dev;
  val shared_input=L.input{bytes="True",encoding="UTF-8"};
  val shared_identity=I.input_identity ids shared_input;
  val shared_owner=P.install_host_source ids shared_input;
  val _=check "shared_input_canonical_identity"
    (P.source_identity shared_owner=shared_identity);
  val independent_equal=L.input{bytes="True",encoding="UTF-8"};
  val _=check "equal_bytes_distinct_input_identity"
    (I.input_identity ids independent_equal<>shared_identity);
  val request_lease=L.retain shared_input;
  val (shared_development,_,shared_fact)=P.define_from_slice public_development
    shared_owner (Binding.name "admission_shared_owner_constant")
    (L.slice shared_input{start=0,stop=4,expected="True"});
  val _=ignore(L.drop_base shared_input);
  val _=ignore(L.release request_lease);
  val _=check "independent_request_release_preserves_producer"
    (P.is_live shared_fact andalso L.retained shared_input andalso
     I.lookup_input_identity ids shared_input=SOME shared_identity);
  val _=P.release shared_development;
  val _=check "final_input_teardown_detaches_identity"
    (L.disposed shared_input andalso is_none(I.lookup_input_identity ids shared_input)
     andalso L.retained independent_equal);
  val aborted_scope=P.construction_scope();
  val (scoped_development,_,scoped_fact)=P.define_from_slice_owned aborted_scope
    public_development owner(Binding.name "admission_scoped_constant")slice;
  val scoped_generation=P.generation scoped_development;
  val scoped_descriptor=N.register_produced ids scoped_fact;
  val _=P.abort_scope aborted_scope;
  val _=P.abort_scope aborted_scope;
  val _=check "construction_scope_abort_fresh_only"
    (not(N.is_live scoped_descriptor) andalso
     is_none(I.lookup_generation_id ids scoped_generation) andalso
     N.is_live public_descriptor andalso L.retained input);
  val _=check "closed_construction_scope_refuses_publication" (case Exn.capture(fn()=>
    P.define_from_slice_owned aborted_scope public_development owner
      (Binding.name "admission_closed_scope_constant")slice)()of
      Exn.Exn _=>true | _=>false);
  val committed_scope=P.construction_scope();
  val (committed_development,_,committed_fact)=P.define_from_slice_owned committed_scope
    public_development owner(Binding.name "admission_transferred_constant")slice;
  val _=P.commit_scope committed_scope;
  val _=P.abort_scope committed_scope;
  val _=check "construction_scope_commit_transfers"
    (P.is_live committed_fact andalso N.is_live public_descriptor);
  val _=P.release committed_development;
  val exhausted_ids=I.install_host_block
    {workspace="22222222222222222222222222222222",first=1,past=3};
  val exhausted_parent=P.public_image exhausted_ids (A.policy thy);
  val exhausted_input=L.input{bytes="True",encoding="UTF-8"};
  val exhausted_owner=P.install_host_source exhausted_ids exhausted_input;
  val _=check "producer_id_exhaustion_refused" (case Exn.capture(fn()=>
    P.define_from_slice exhausted_parent exhausted_owner
      (Binding.name "admission_exhausted_constant")
      (L.slice exhausted_input{start=0,stop=4,expected="True"}))()of
      Exn.Exn _=>true | _=>false);
  val disposed= L.drop_base exhausted_input;
  val _=Option.app I.release_disposed_input disposed;
  val _=check "producer_id_exhaustion_no_stranded_lease"
    (L.disposed exhausted_input andalso
     is_none(I.lookup_input_identity exhausted_ids exhausted_input) andalso
     is_some(I.lookup_generation_id exhausted_ids(P.generation exhausted_parent)));
  val _=P.release exhausted_parent;
  val owned_generation=P.generation development;
  val _=P.release development;
  val _=P.release development;
  val _=check "producer_teardown_map_idempotent"
    (is_none(I.lookup_generation_id ids owned_generation) andalso
     I.lookup_generation_id ids (P.generation public_development)=SOME parent_context);
  val _=check "producer_release" (not (N.is_live produced) andalso
    N.is_live public_descriptor andalso L.retained input);
  val (last_child,_,last_fact)=P.define_from_slice public_development owner
    (Binding.name "admission_parent_release_child") slice;
  val last_descriptor=N.register_produced ids last_fact;
  val _=P.release public_development;
  val _=check "parent_context_release_denies_child"
    (not (N.is_live last_descriptor) andalso not (N.is_live public_descriptor));
in end
