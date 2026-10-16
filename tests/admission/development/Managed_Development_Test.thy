theory Managed_Development_Test
  imports "Veri7vn_Admission.Veri7vn_Admission"
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Descriptor;
  val allocator=I.install_host_block
    {workspace="abcdef0123456789abcdef0123456789",first=1,past=60000};
  val parent_policy=A.policy @{theory Veri7vn_Admission};
  val developments=Unsynchronized.ref ([]:P.development list);
  val descriptors=Unsynchronized.ref ([]:N.descriptor list);
  val inputs=Unsynchronized.ref ([]:L.input list);
  fun own_dev d=(developments:=d:: !developments;d);
  fun own_descriptor d=(descriptors:=d:: !descriptors;d);
  fun own_input i=(inputs:=i:: !inputs;i);
  fun own_public ()=
    let val scope=P.construction_scope()
      val result=Exn.capture (Thread_Attributes.uninterruptible(fn _=>fn()=>
        let val parent=P.public_image_owned scope allocator parent_policy
          val _=own_dev parent
          val _=P.commit_scope scope
        in parent end)) ()
    in case result of Exn.Res parent=>parent
      | Exn.Exn failure=>(P.abort_scope scope;Exn.reraise failure) end;
  fun build parents owner slice name=
    let val scope=P.construction_scope()
      val result=Exn.capture (fn()=>Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
        let
          (* Replay and native proof checking remain interruptible; the scope
             owns a published context before its producer unmasks/returns. *)
          val development=Thread_Attributes.with_attributes original
            (fn _=>P.replay_source_owned scope parents owner slice)
          val fact=Thread_Attributes.with_attributes original
            (fn _=>P.named_theorem development name)
          (* Fixed descriptor allocation plus caller handoff is bounded and
             masked. The fresh context remains rollback-owned until both roots
             have been installed by the caller. *)
          val descriptor=N.register_produced allocator fact
          val _=own_descriptor descriptor
          val _=own_dev development
          val _=P.commit_scope scope
        in (development,fact,descriptor) end)) ()
    in case result of Exn.Res triple=>triple
      | Exn.Exn failure=>(P.abort_scope scope;Exn.reraise failure) end;
  fun checks ()=let
  val parent=own_public ();
  val import=Context.theory_name {long=true} (A.policy_theory parent_policy);
  val source=File.read(Path.append(Resources.master_directory @{theory})
    (Path.explode "Provenance_Specialist.thy"));
  val prefix="retained package original\n";
  val input=own_input(L.input {bytes=prefix ^ source ^ "\nretained suffix",encoding="UTF-8"});
  val owner=P.install_host_source allocator input;
  val slice=L.slice input {start=size prefix,stop=size prefix+size source,expected=source};
  fun rejects f=case Exn.capture f () of Exn.Exn _=>() | Exn.Res _=>error "Expected managed development rejection";
  val (development,fact,descriptor)=build [(import,parent)] owner slice
    ("Provenance_Specialist.selected_origin_is_classified",0);
  val accepted=N.accepted descriptor;
  val thy=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation development));
  val expected=Global_Theory.get_thm thy "Provenance_Specialist.selected_origin_is_classified";
  val _=if Thm.prop_of(A.theorem accepted) aconv Thm.prop_of expected andalso
    N.provenance_complete descriptor andalso N.is_live descriptor then ()
    else error "Managed authored source did not produce the exact admitted native descriptor";
  val _=if member (op =) (P.source_dependencies fact) (P.source_identity owner) andalso
    member (op =) (#dependencies(N.project descriptor)) (P.source_identity owner) then ()
    else error "Managed authored source dependency disappeared";
  val _=case P.replay_recipe development of SOME {parents,source=retained,slice=kept}=>
    if length parents=1 andalso P.source_identity retained=P.source_identity owner andalso
      L.original kept=source then () else error "Wrong managed replay construction trace"
    | NONE=>error "Managed replay construction trace missing";
  val _=rejects(fn()=>P.named_theorem development ("selected_origin_is_classified",0));
  val unrelated=own_input(L.input{bytes=source,encoding="UTF-8"});
  val other=P.install_host_source allocator unrelated;
  val _=rejects(fn()=>build [(import,parent)] other slice
    ("Provenance_Specialist.selected_origin_is_classified",0));
  (* A failure after fresh replay must abort only its products. The shared
     approved parent and another existing descriptor remain usable. *)
  val _=rejects(fn()=>build [(import,parent)] owner slice ("missing_fact",0));
  val _=if N.is_live descriptor then () else error "Failed build released a preexisting shared product";
  val _=P.release parent;
  val _=if not(N.is_live descriptor) andalso not(P.is_live fact) then ()
    else error "Released authored parent left a usable descriptor";
  val _=rejects(fn()=>N.accepted descriptor);
  val live_parent=own_public ();
  val live_input=own_input(L.input{bytes=source,encoding="UTF-8"});
  val live_owner=P.install_host_source allocator live_input;
  val live_slice=L.slice live_input{start=0,stop=size source,expected=source};
  val (live_dev,live_fact,live_descriptor)=build [(import,live_parent)] live_owner live_slice
    ("Provenance_Specialist.selection_preserves_batches",0);
  val _=L.forget_input live_input;
  val _=if not(N.is_live live_descriptor) then () else error "Forgotten original source left native evidence live";
  val _=rejects(fn()=>N.accepted live_descriptor);
  val _=P.release live_dev;
  val _=P.release live_parent;
  val _=N.release live_descriptor;
  val _=P.release development;
  val _=N.release descriptor;
  val _=L.forget_input input;
  val _=L.forget_input unrelated;
  in () end;
  val result=Exn.capture checks ();
  (* Test-created roots are scoped even when an assertion fails; no shared owner
     outside this fixture is released. Preserve the original failing exception. *)
  val cleanup=Exn.capture (fn()=>
    (List.app N.release (!descriptors);List.app P.release (!developments);
     List.app L.forget_input (!inputs))) ();
  val _=Exn.release result;
  val _=Exn.release cleanup;
in
  val _=writeln "managed_native_development_descriptor_ok";
end;
\<close>
end
