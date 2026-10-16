theory Native_Recovery_Tests
  imports Veri7vn_Admission.Veri7vn_Admission
begin
ML \<open>
local
  structure V=Veri7vn_Native_Recovery_Check;
  structure P=Veri7vn_Managed_Provenance;
  structure N=Veri7vn_Native_Descriptor;
  structure A=Veri7vn_Native_Admission;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure I=Veri7vn_Native_Identity_Allocator;
  fun assert b message=if b then () else error message;
  fun rejects f = case Exn.capture f () of Exn.Exn _=>() | Exn.Res _=>error "Expected recovery refusal";
  val workspace="123456789012345678901234567890ab";
  val allocator=I.install_host_block {workspace=workspace,first=1,past=10000};
  val policy=A.policy @{theory};
  (* Unit fixture for trusted boot constructor. Host tests must supply actual
     heap/build/source manifest; this string deliberately asserts no such test. *)
  val image=V.install_host_image policy "unit-test-installed-public-image-v1";
  val development=P.public_image allocator policy;
  val consequence=P.public_theorem development ("HOL.mp",0);
  val native=N.register_produced allocator consequence;
  val projection=N.project native;
  val th=A.theorem (N.accepted native);
  val (assumptions,sorts)=chop (length (Thm.hyps_of th @ Thm.prems_of th)) (#premises projection);
  val evidence=I.allocate allocator;
  val saved={workspace=workspace,evidence_id=evidence,projection=projection,
    assumption_ids=assumptions,sort_ids=sorts};
  val artifact=V.qualify allocator image consequence saved;
  fun digest b=Message_Digest.rep (SHA256.digest b);
  fun manifest (art:V.artifacts)=Veri7vn_Recovery_Manifest.encode
    {profile=Veri7vn_Recovery_Manifest.KernelEvidence,workspace=workspace,association=evidence,semantic_generation= #semantic_generation projection,
     projection=digest (#projection art),sequent=digest (#sequent art),
     context_closure=digest (#context_closure art),payload=digest (#reconstruction art),
     reconstruction=Veri7vn_Recovery_Manifest.Fixed_Certificate,executable=NONE};
  fun material (art:V.artifacts)={workspace=workspace,journal_sequence=1,association=evidence,
    semantic_generation= #semantic_generation projection,checkpoint="unit-fixture-checkpoint",
    manifest=manifest art,projection= #projection art,sequent= #sequent art,
    context_closure= #context_closure art,reconstruction= #reconstruction art};
  val original_locator=Veri7vn_Native_Registry.generation_locator(A.generation(N.accepted native));
  val other=P.public_theorem development ("HOL.refl",0);
  val other_a=P.accepted other;
  val other_sequent=Veri7vn_Native_Sequent.encode
    (Veri7vn_Native_Sequent.capture (A.target other_a) (A.theorem other_a));
  val committed=C.install_committed_host (material artifact);
  val _=P.release development;
  val verified=V.recheck allocator image committed;
  val restored=N.restore allocator verified;
  val _=assert (N.project restored=projection) "Saved durable native projection changed";
  val _=assert(N.semantic_generation_id allocator (A.generation(N.accepted restored))=
    #semantic_generation projection) "Restored generation was assigned another durable ID";
  val _=assert (original_locator <>
    Veri7vn_Native_Registry.generation_locator (A.generation (N.accepted restored)))
    "Recovery reused native generation handle";
  val _=rejects (fn()=>N.restore allocator verified);
  val changed_image=V.install_host_image policy "changed-unit-image";
  val _=rejects (fn()=>V.recheck allocator changed_image committed);
  val foreign=I.install_host_block {workspace="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",first=1,past=100};
  val _=rejects (fn()=>V.recheck foreign image committed);
  val _=rejects (fn()=>V.decode_projection (#projection artifact ^ "x"));
  val wrong_sequent={projection= #projection artifact,
    sequent=other_sequent,
    context_closure= #context_closure artifact,reconstruction= #reconstruction artifact};
  val wrong_committed=C.install_committed_host (material wrong_sequent);
  val _=rejects (fn()=>V.recheck allocator image wrong_committed);
  val _=C.release wrong_committed;
  val bad_digest_material={workspace=workspace,journal_sequence=1,association=evidence,
    semantic_generation= #semantic_generation projection,checkpoint="unit-fixture-checkpoint",
    manifest=manifest artifact,projection= #projection artifact ^ "x",sequent= #sequent artifact,
    context_closure= #context_closure artifact,reconstruction= #reconstruction artifact};
  val bad_digest=C.install_committed_host bad_digest_material;
  val _=rejects (fn()=>V.recheck allocator image bad_digest);
  val _=C.release bad_digest;
  val _=N.release restored;
  val _=assert (not (N.is_live restored)) "Restored native payload survived release";
  val _=rejects (fn()=>P.accepted (V.consequence verified));
  val _=C.release committed;
  val _=rejects (fn()=>V.recheck allocator image committed);
  val _=P.release development;
  val private_base=P.public_image allocator policy;
  val private_base_id=I.generation_id allocator(P.generation private_base);
  val source_input=Veri7vn_Native_Literals.input {bytes="42 :: nat",encoding="UTF-8"};
  val source_owner=P.install_host_source allocator source_input;
  val source_slice=Veri7vn_Native_Literals.slice source_input
    {start=0,stop=9,expected="42 :: nat"};
  val (private_dev,private_constant,private_fact)=P.define_from_slice private_base source_owner
    (Binding.name "recovery_private_value") source_slice;
  val private_native=N.register_produced allocator private_fact;
  val pp=N.project private_native;
  val private_th=A.theorem(N.accepted private_native);
  val (pa,ps)=chop(length(Thm.hyps_of private_th @ Thm.prems_of private_th)) (#premises pp);
  val private_id=I.allocate allocator;
  val private_artifact=V.qualify allocator image private_fact
    {workspace=workspace,evidence_id=private_id,projection=pp,assumption_ids=pa,sort_ids=ps};
  val private_manifest=Veri7vn_Recovery_Manifest.encode
    {profile=Veri7vn_Recovery_Manifest.KernelEvidence,workspace=workspace,association=private_id,semantic_generation= #semantic_generation pp,
     projection=digest(#projection private_artifact),sequent=digest(#sequent private_artifact),
     context_closure=digest(#context_closure private_artifact),payload=digest(#reconstruction private_artifact),
     reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,executable=NONE};
  val private_committed=C.install_committed_host
    {workspace=workspace,journal_sequence=2,association=private_id,semantic_generation= #semantic_generation pp,
     checkpoint="unit-private-checkpoint",manifest=private_manifest,
     projection= #projection private_artifact,sequent= #sequent private_artifact,
     context_closure= #context_closure private_artifact,reconstruction= #reconstruction private_artifact};
  (* Different facts in ancestor/child contexts must compose after one shared
     replay; two equal-looking sibling theories do not establish this. *)
  fun artifact_for fact native evidence =
    let val p=N.project native val th=A.theorem(N.accepted native)
      val(assumptions,sorts)=chop(length(Thm.hyps_of th@Thm.prems_of th))(#premises p)
    in V.qualify allocator image fact{workspace=workspace,evidence_id=evidence,projection=p,
      assumption_ids=assumptions,sort_ids=sorts}end;
  fun protect_native evidence generation (art:V.artifacts)=
    let val envelope=Veri7vn_Recovery_Manifest.encode
      {profile=Veri7vn_Recovery_Manifest.KernelEvidence,workspace=workspace,association=evidence,
       semantic_generation=generation,projection=digest(#projection art),sequent=digest(#sequent art),
       context_closure=digest(#context_closure art),payload=digest(#reconstruction art),
       reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,executable=NONE}
    in C.install_committed_host{workspace=workspace,journal_sequence=3,association=evidence,
      semantic_generation=generation,checkpoint="unit-multifact-checkpoint",manifest=envelope,
      projection= #projection art,sequent= #sequent art,context_closure= #context_closure art,
      reconstruction= #reconstruction art}end;
  val second_native=N.register_produced allocator private_fact;
  val second_id=I.allocate allocator;
  val second_material=protect_native second_id (#semantic_generation(N.project second_native))
    (artifact_for private_fact second_native second_id);
  val child_bytes=Syntax.string_of_term (Veri7vn_Native_Registry.context(P.generation private_dev)) private_constant |> YXML.parse_body |> XML.content_of;
  val child_input=Veri7vn_Native_Literals.input{bytes=child_bytes,encoding="UTF-8"};
  val child_owner=P.install_host_source allocator child_input;
  val child_slice=Veri7vn_Native_Literals.slice child_input{start=0,stop=size child_bytes,expected=child_bytes};
  val(_,_,child_fact)=P.define_from_slice private_dev child_owner
    (Binding.name "recovery_private_copy")child_slice;
  val child_native=N.register_produced allocator child_fact;
  val child_id=I.allocate allocator;
  val child_material=protect_native child_id (#semantic_generation(N.project child_native))
    (artifact_for child_fact child_native child_id);
  val alternate_dev=P.context_alias private_dev;
  val alternate_fact=P.restate alternate_dev private_fact;
  val alternate_native=N.register_produced allocator alternate_fact;
  val alternate_id=I.allocate allocator;
  val alternate_projection=N.project alternate_native;
  val _=assert(not(member(op =)(#dependencies alternate_projection)(#semantic_generation pp)))
    "Physical cache ownership leaked into logical alias dependencies";
  val alternate_material=protect_native alternate_id (#semantic_generation alternate_projection)
    (artifact_for alternate_fact alternate_native alternate_id);
  val _=P.release private_base;
  val _=Veri7vn_Native_Literals.forget_input source_input;
  val _=I.release_disposed_input source_input;
  val _=Veri7vn_Native_Literals.forget_input child_input;
  val _=I.release_disposed_input child_input;
  val independent_input=Veri7vn_Native_Literals.input{bytes="42 :: nat",encoding="UTF-8"};
  val source_batch=Veri7vn_Native_Recovery_Source.batch();
  val recovered_once=hd(Veri7vn_Native_Recovery_Source.recover_all allocator source_batch private_committed);
  val recovered_twice=hd(Veri7vn_Native_Recovery_Source.recover_all allocator source_batch private_committed);
  val _=assert(Veri7vn_Native_Literals.same_input
    (Veri7vn_Native_Recovery_Source.input recovered_once,Veri7vn_Native_Recovery_Source.input recovered_twice))
    "Repeated durable source ID produced different physical inputs in one batch";
  structure StagedContexts=Veri7vn_Checked_Generation_Reassociation(struct
    type verified={workspace:string,generation:Veri7vn_Native_Registry.generation,
      semantic_generation:IntInf.int}list
    fun bindings entries=entries
  end);
  val source_stage=P.staged_public_image allocator policy private_committed;
  val stage_owner=P.restore_source recovered_once;
  val stage_input=P.source_input stage_owner;
  val stage_slice=Veri7vn_Native_Literals.slice stage_input{start=0,stop=9,expected="42 :: nat"};
  val(stage_development,_,stage_fact)=P.define_from_slice source_stage stage_owner
    (Binding.name "recovery_source_stage")stage_slice;
  val generation_only=map(fn generation=>{workspace=workspace,generation=generation,
    semantic_generation=I.allocate allocator})(P.context_lineage stage_development);
  val _=I.install_fragments allocator[StagedContexts.fragment generation_only];
  val _=assert(not(P.is_live stage_fact)) "Generation-only install published an unbound source identity";
  val _=rejects(fn()=>N.register_produced allocator stage_fact);
  val _=assert(is_none(I.lookup_input_identity allocator stage_input))
    "Rejected source publication allocated an arbitrary input identity";
  val _=I.install_fragments allocator[Veri7vn_Native_Recovery_Source.fragment source_batch];
  val _=assert(P.is_live stage_fact) "Checked source fragment did not complete native publication";
  val _=P.release source_stage;
  val _=Veri7vn_Native_Recovery_Source.release source_batch;
  val _=rejects(fn()=>Veri7vn_Native_Recovery_Source.input recovered_once);
  val private_verified=V.recheck allocator image private_committed;
  val private_restored=N.restore allocator private_verified;
  val _=assert(N.project private_restored=pp) "Private durable projection changed";
  val restored_development=P.consequence_development(V.consequence private_verified);
  val restored_recipe=the(P.definition_recipe(the(P.alias_parent restored_development)));
  val recovered_source=P.source_input(#source restored_recipe);
  val _=assert(P.source_identity(#source restored_recipe)=P.source_identity source_owner)
    "Recovered private source owner ID changed";
  val _=assert(not(Veri7vn_Native_Literals.same_input(source_input,recovered_source)))
    "Private recovery reused original physical input";
  val _=N.release private_restored;
  val _=assert(not(Veri7vn_Native_Literals.retained recovered_source))
    "Released private recovery retained source payload";
  val _=assert(Veri7vn_Native_Literals.retained independent_input)
    "Private recovery release forgot an independent equal-byte source";
  val group=V.restore_batch();
  val first_checked=V.recheck_in group allocator image private_committed;
  val _=rejects(fn()=>N.restore allocator first_checked);
  val _=rejects(fn()=>N.register_produced allocator(V.consequence first_checked));
  val _=assert(is_none(I.lookup_generation_id allocator(A.generation(P.accepted(V.consequence first_checked)))))
    "Rejected staged publication allocated a fresh context identity";
  val temporary_checked=V.recheck_in group allocator image private_committed;
  val second_checked=V.recheck_in group allocator image second_material;
  val child_checked=V.recheck_in group allocator image child_material;
  val alternate_checked=V.recheck_in group allocator image alternate_material;
  val group_witness=V.seal_batch group;
  val _=I.install_fragments allocator[V.fragment group_witness];
  val _=V.release temporary_checked;
  val _=rejects(fn()=>N.restore allocator temporary_checked);
  val first_restored=N.restore allocator first_checked;
  val second_restored=N.restore allocator second_checked;
  val child_restored=N.restore allocator child_checked;
  val alternate_restored=N.restore allocator alternate_checked;
  val ancestor_lease=the(V.retain_context_for child_checked private_base_id);
  val ancestor_generation=V.retained_generation ancestor_lease;
  val _=assert(Context.eq_thy(Proof_Context.theory_of(Veri7vn_Native_Registry.context ancestor_generation),
    A.policy_theory policy)) "Verified public ancestor changed its actual approved boot context";
  val _=assert(is_none(V.retain_context_for child_checked (#semantic_generation alternate_projection)))
    "Ancestor lookup exposed a sibling association outside the checked construction closure";
  val first_a=N.accepted first_restored;
  val second_a=N.accepted second_restored;
  val child_a=N.accepted child_restored;
  val alternate_a=N.accepted alternate_restored;
  val _=assert(Veri7vn_Native_Registry.same_generation(A.generation first_a,A.generation second_a))
    "One saved generation was reconstructed with separate native wrappers";
  val _=assert(not(Veri7vn_Native_Registry.same_generation(A.generation first_a,A.generation alternate_a)))
    "Distinct historical semantic IDs merged into one native wrapper";
  val _=assert(Context.eq_thy(Thm.theory_of_thm(A.theorem first_a),Thm.theory_of_thm(A.theorem alternate_a)))
    "Exact shared construction failed to reuse its actual native context";
  val child_theory=Thm.theory_of_thm(A.theorem child_a);
  val composed=Thm.transitive(A.theorem child_a)(Thm.transfer child_theory(A.theorem first_a));
  val child_constant= #1(Logic.dest_equals(Thm.prop_of(A.theorem child_a)));
  val expected_composition=Logic.mk_equals(child_constant,@{term "42 :: nat"});
  val _=assert(Thm.prop_of composed aconv expected_composition)
    "Recovered composition did not prove the exact y == (42 :: nat) proposition";
  val _=assert(null(Thm.hyps_of composed)andalso null(Thm.prems_of composed)andalso
    null(Thm_Deps.all_oracles[composed])) "Recovered context composition introduced assumptions/oracles";
  val child_recipe=the(P.definition_recipe(the(P.alias_parent(P.consequence_development(V.consequence child_checked)))));
  val recovered_child_input=P.source_input(#source child_recipe);
  val _=N.release first_restored;
  val _=assert(N.is_live second_restored andalso N.is_live child_restored) "First shared lease retired other facts";
  val _=N.release second_restored;
  val _=assert(N.is_live child_restored) "Parent fact release retired a live child context";
  val _=N.release child_restored;
  val _=assert(not(Veri7vn_Native_Literals.retained recovered_child_input)) "Unused child source cache survived pruning";
  val _=assert(N.is_live alternate_restored) "Independent logical alias retired with another historical context ID";
  val retained=V.retain_context alternate_checked;
  val retained_generation=V.retained_generation retained;
  val _=N.release alternate_restored;
  val _=assert(I.lookup_generation_id allocator retained_generation=SOME(#semantic_generation alternate_projection))
    "Kernel release detached a retained cross-family context identity";
  val _=assert(Veri7vn_Native_Registry.same_generation
    (retained_generation,V.retained_generation retained)) "Retained context changed native generation";
  val _=V.release_context retained;
  val _=assert(is_none(I.lookup_generation_id allocator retained_generation))
    "Final retained context release left the generation association live";
  val _=rejects(fn()=>V.retained_generation retained);
  val _=assert(I.lookup_generation_id allocator ancestor_generation=SOME private_base_id)
    "Last private descriptor release detached its independently retained public ancestor";
  val _=V.release_context ancestor_lease;
  val _=assert(is_none(I.lookup_generation_id allocator ancestor_generation))
    "Last ancestor lease release failed to detach the public context identity";
  val _=rejects(fn()=>V.retained_generation ancestor_lease);
  val _=V.abort_batch group;
  val _=List.app C.release[second_material,child_material,alternate_material];
  val _=Veri7vn_Native_Literals.forget_input child_input;
  val _=writeln "RECOVERY shared_context_multifact_composition PASS";
  val _=C.release private_committed;
  val _=P.release private_base;
  val _=Veri7vn_Native_Literals.forget_input source_input;
  val _=Veri7vn_Native_Literals.forget_input independent_input;
  val _=writeln "RECOVERY private_definition_source_recheck PASS";
  (* The test-only checker is explicit trusted fixture ML, not resident ingress. *)
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure FixtureInputs=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified={workspace:string,identity:IntInf.int,bytes:string,encoding:string}
    fun binding value=value
  end);
  val input_pool=Pool.create allocator;
  val pool_id=I.allocate allocator;
  val equal_id=I.allocate allocator;
  val checked_input={workspace=workspace,identity=pool_id,bytes="same bytes",encoding="UTF-8"};
  val first_input=FixtureInputs.acquire input_pool checked_input;
  val second_input=FixtureInputs.acquire input_pool checked_input;
  val actual_input=Pool.input first_input;
  val _=assert(Veri7vn_Native_Literals.same_input(actual_input,Pool.input second_input))
    "One saved source ID acquired different physical owners";
  val _=rejects(fn()=>FixtureInputs.acquire input_pool
    {workspace=workspace,identity=pool_id,bytes="different bytes",encoding="UTF-8"});
  val _=rejects(fn()=>FixtureInputs.acquire input_pool
    {workspace=workspace,identity=pool_id,bytes="same bytes",encoding="other"});
  val separate_input=FixtureInputs.acquire input_pool
    {workspace=workspace,identity=equal_id,bytes="same bytes",encoding="UTF-8"};
  val _=assert(not(Veri7vn_Native_Literals.same_input(actual_input,Pool.input separate_input)))
    "Equal bytes merged distinct source origins";
  val _=I.install_fragments allocator[Pool.fragment first_input,Pool.fragment second_input,
    Pool.fragment separate_input];
  val _=Pool.release first_input;
  val _=assert(Veri7vn_Native_Literals.bytes(Pool.input second_input)="same bytes")
    "Releasing one source consumer invalidated another";
  val unit_generation=Veri7vn_Native_Registry.generation(Proof_Context.init_global(A.policy_theory policy))
    {packages=[],runtime="unit-fixture",policy="kernel",sources=[],interpretation="source lease test"};
  val input_unit=Veri7vn_Managed_Native_Unit.create{generation=unit_generation,
    inputs=[actual_input],objects=[]}Veri7vn_Native_Registry.empty;
  val _=Pool.release second_input;
  val reacquired=FixtureInputs.acquire input_pool checked_input;
  val _=assert(Veri7vn_Native_Literals.same_input(actual_input,Pool.input reacquired))
    "Pool lost canonical input owner while a managed native unit retained it";
  val _=Pool.close input_pool;
  val _=Pool.release reacquired;
  val _=assert(Veri7vn_Native_Literals.retained actual_input)
    "Pool transfer dropped an active native-unit consumer";
  val _=ignore(Veri7vn_Managed_Native_Unit.release input_unit);
  val _=I.release_disposed_input actual_input;
  val _=assert(Veri7vn_Native_Literals.disposed actual_input andalso
    is_none(I.lookup_input_identity allocator actual_input)) "Last input consumer failed to dispose canonical identity";
  val _=Pool.release separate_input;
  val _=Pool.abort input_pool;
  val _=writeln "RECOVERY shared_input_owner_and_release PASS";
  val _=writeln "RECOVERY public_native_recheck_and_release PASS";
in end
\<close>
end
