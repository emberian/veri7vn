theory Installed_Roots_Tests
  imports Veri7vn_Admission.Veri7vn_Admission
begin
ML \<open>
local
  structure Roots=Veri7vn_Native_Installed_Roots;
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure N=Veri7vn_Native_Descriptor;
  structure M=Veri7vn_Recovery_Manifest;
  structure C=Veri7vn_Committed_Native_Recovery;
  fun require true _=()|require false message=error message;
  fun rejects f=case Exn.capture f()of Exn.Exn(ERROR _)=>()
    | Exn.Exn exn=>Exn.reraise exn|Exn.Res _=>error "Expected fixed-root refusal";
  val lower=@{theory Main};
  val boot=@{theory Veri7vn_Admission};
  val locator=Context.theory_name{long=true}lower;
  val roots=Roots.capture_setup_with_imports
    {roots=[(locator,A.policy lower)],imports=[("Main",locator)],context=boot};
  val _=require(Roots.resolve_import roots "Main"=locator) "Fixed source alias lost canonical lower root";
  val _=require(not(Context.eq_thy(lower,boot))) "Root fixture must use distinct lower and boot theories";
  val _=require(Roots.matches roots locator lower andalso not(Roots.matches roots locator boot))
    "Installed locator accepted stronger boot theory";
  val _=rejects(fn()=>Roots.capture_setup[(locator,A.policy boot)]);
  val _=rejects(fn()=>Roots.capture_setup[(locator,A.policy lower),(locator,A.policy lower)]);
  val _=rejects(fn()=>Roots.policy roots "uninstalled-root");
  val _=rejects(fn()=>Roots.capture_setup_with_imports
    {roots=[(Context.theory_name{long=true}boot,A.policy boot)],
     imports=[("Main",Context.theory_name{long=true}boot)],context=boot});
  val ids=I.install_host_block{workspace="999999999999999999999999999999ac",first=1,past=1000};
  val image=V.install_host_image_with_roots roots(A.policy boot) "installed-roots-test-image";
  val development=P.public_image ids(Roots.policy roots locator);
  val _=require(Context.eq_thy(Proof_Context.theory_of(R.context(P.generation development)),lower))
    "Installed public image changed exact lower native theory";
  val public_fact=P.public_theorem development("HOL.sym",0);
  val definition_input=L.input{bytes="(0::nat)",encoding="UTF-8"};
  val definition_owner=P.install_host_source ids definition_input;
  val definition_slice=L.slice definition_input{start=0,stop=8,expected="(0::nat)"};
  val(_,_,definition_fact)=P.define_from_slice development definition_owner
    (Binding.name "installed_recovery_value")definition_slice;
  val source="theory Recovery_Installed_Lower imports Main begin\nlemma installed_truth: \"True\" by simp\nend";
  val input=L.input{bytes=source,encoding="UTF-8"};
  val owner=P.install_host_source ids input;
  val span=L.slice input{start=0,stop=size source,expected=source};
  val child=P.replay_source[("Main",development)]owner span;
  val fact=P.named_theorem child("Recovery_Installed_Lower.installed_truth",0);
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun protect fact=
    let val native=N.register_produced ids fact val projection=N.project native
      val theorem=A.theorem(N.accepted native)
      val(assumptions,sorts)=chop(length(Thm.hyps_of theorem@Thm.prems_of theorem))(#premises projection)
      val evidence=I.allocate ids
      val artifact=V.qualify ids image fact{workspace=I.workspace ids,evidence_id=evidence,
        projection=projection,assumption_ids=assumptions,sort_ids=sorts}
      val envelope=M.encode{profile=M.KernelEvidence,workspace=I.workspace ids,association=evidence,
        semantic_generation= #semantic_generation projection,projection=digest(#projection artifact),
        sequent=digest(#sequent artifact),context_closure=digest(#context_closure artifact),
        payload=digest(#reconstruction artifact),reconstruction=M.Controlled_Recipe,executable=NONE}
      val committed=C.install_committed_host{workspace=I.workspace ids,journal_sequence=1,association=evidence,
        semantic_generation= #semantic_generation projection,checkpoint="installed-roots-checkpoint",
        manifest=envelope,projection= #projection artifact,sequent= #sequent artifact,
        context_closure= #context_closure artifact,reconstruction= #reconstruction artifact}
      val _=require(case YXML.parse_body(#reconstruction artifact)of
        [XML.Elem((_,("version","3")::_),_)]=>true|_=>false) "Installed root recipe requires explicit version3"
    in(native,projection,committed)end;
  val originals=map protect[public_fact,definition_fact,fact];
  val _=List.app(fn(native,_,_)=>N.release native)originals;
  val _=P.release development;
  val batch=Veri7vn_Native_Recovery_Graph.create_roots roots;
  val verified=map(fn(_,_,committed)=>V.recheck_in batch ids image committed)originals;
  val _=I.install_fragments ids[V.fragment(V.seal_batch batch)];
  val restored=map(N.restore ids)verified;
  val _=List.app(fn(native,(_,projection,_))=>require(N.project native=projection)
    "Installed root restore changed durable native identities")(restored~~originals);
  val parent=case P.context_parents(P.consequence_development(V.consequence(List.last verified)))of
    [parent]=>parent|_=>error "Installed source parent arity";
  val _=require(Context.eq_thy(Proof_Context.theory_of(R.context(P.generation parent)),lower))
    "Restart substituted stronger boot context for lower imported root";
  val _=require(R.same_generation(P.generation parent,
      P.generation(P.consequence_development(V.consequence(hd verified)))))
    "Public and private lower-root facts failed to share the same restored alias";
  val _=List.app N.release restored;
  val _=List.app V.release verified;
  val _=List.app(fn(_,_,committed)=>C.release committed)originals;
  val _=List.app(fn input=>(L.forget_input input;I.release_disposed_input input))[input,definition_input];
  val _=require(L.disposed input andalso L.disposed definition_input) "Installed-root fixtures retained source owners";
in
  val _=writeln "RECOVERY installed_lower_root_identity PASS";
end
\<close>
end
