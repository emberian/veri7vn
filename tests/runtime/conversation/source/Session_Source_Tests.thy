theory Session_Source_Tests
  imports Veri7vn_Session_Source.Session_Source
    Veri7vn_Original_Session_Source.Original_Session_Source
begin
ML \<open>
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Native_Observation_Pin;
  (* This finite lifetime fixture refuses every restoration. It uses the real
     fixed recovery factory; no fabricated checked source is supplied. *)
  val executable=Veri7vn_Executable_Identity.pin @{theory}
    {artifact="session-source-lifetime-fixture",compiler="Isabelle/ML",target="native",
     serializers=["native-session-input/1"],foreign_primitives=[],settings=[]};
  structure Recovery=Veri7vn_Native_Session_Input_Recovery(
    structure Checkpoint=struct
      fun matches (_:Veri7vn_Committed_Native_Recovery.committed)
        (_:Veri7vn_Session_Input_Codec.metadata)=NONE:{recorded:bool}option
    end
    val executable=executable);
  structure NativeContext=Context;
  structure Context=Veri7vn_Private_Session_Context();
  structure E=Veri7vn_Private_Session_Entry(structure Restored=Recovery.View structure Context=Context);
  structure Export=Veri7vn_Native_Session_Input_Export(structure Entry=E val executable=executable);
  structure M=Veri7vn_Managed_Provenance;
  structure D=Veri7vn_Native_Construction_Codec;
  structure W=Veri7vn_Session_Input_Codec;
  structure Original=Veri7vn_Original_Session_Source;
  fun ensure true _=()|ensure false text=error text;
  fun rejects action=ensure(Exn.is_exn(Exn.capture action())) "Expected session source rejection";
  fun rejects_with expected action=ensure(case Exn.capture action()of
      Exn.Exn(ERROR actual)=>actual=expected | _=>false) "Wrong session source rejection boundary";
  val ids=I.install_host_block{workspace="c0de0000000000000000000000000065",first=9000000,past=9065536};
  val lower_policy=Veri7vn_Native_Admission.policy @{theory Veri7vn_Admission};
  val roots=Veri7vn_Native_Installed_Roots.capture_setup
    [(NativeContext.theory_name{long=true} @{theory Veri7vn_Admission},lower_policy)];
  val image=Veri7vn_Native_Recovery_Check.install_host_image_with_roots roots
    (Veri7vn_Native_Admission.policy @{theory}) "session-source-unit-image";
  val context=Context.create ids lower_policy;
  val development=Context.development context;
  val generation=I.generation_id ids(M.generation development);
  val sid=I.allocate ids;
  val issuer=P.new_issuer();
  val observed={workspace=I.workspace ids,session=sid,version=0,
    evaluation_time=SOME{basis=P.SourceEvent "source-clock",ticks= ~9},reads=[]}:P.snapshot;
  val pin=P.mint issuer observed;
  val input=L.input{bytes="a  b\n",encoding="UTF-8"};
  val uid=I.input_identity ids input;
  val source_owner=M.install_host_source ids input;
  val child=L.retain input;
  val entry=E.capture ids{input=input,pin=pin,context=context,source=source_owner};
  val context_check=Context.retain context;
  val original_issuer=Original.new_issuer();
  val foreign_issuer=Original.new_issuer();
  val original_entry=E.retain entry;
  val attempts=Unsynchronized.ref 0;
  val original=Original.capture original_issuer{allocator=ids,input=E.input original_entry,pin=pin,
    source=source_owner,development=E.development original_entry,on_release=fn()=>
      (attempts:= !attempts+1;if !attempts=1 then error "Retry original Entry destructor"
       else E.release original_entry)};
  val original_copy=Original.retain original;
  val _=Original.release original;
  val _=ensure(Original.live original_copy andalso not(Original.live original) andalso
    Original.belongs original_issuer original_copy andalso not(Original.belongs foreign_issuer original_copy) andalso
    L.same_input(Original.input original_copy,input) andalso
    Original.dependencies original_copy=E.dependencies entry)
    "Original source capsule lost issuer/physical input/full Entry closure or independent view";
  val _=ignore(L.drop_base input);
  val _=ignore(L.release child);
  val _=P.release pin;
  val _=Context.release context;
  val source=E.snapshot entry;
  val _=ensure(#utterance(#identity source)=uid andalso #bytes source="a  b\n" andalso
    E.retained entry) "Child/producer release destroyed independent session source";
  val copy=E.retain entry;
  val _=E.release entry;
  val _=E.release entry;
  val _=ensure(not(E.retained entry) andalso E.retained copy andalso #bytes(E.snapshot copy)="a  b\n")
    "Independent session source view release failed";
  val(graph,_)=D.collect ids development;
  val metadata={version=1,workspace=I.workspace ids,session=sid,utterance=uid,
    source_generation=generation,source_dependencies=M.development_dependencies development,
    observation=observed,input_encoding= #encoding source,input_bytes= #bytes source}:W.metadata;
  val payload={graph=graph}:W.payload;
  val _=W.check_graph metadata payload;
  val exported=Export.qualify ids image roots copy;
  val _=ensure(W.decode_projection(#projection exported)=metadata andalso #sequent exported="")
    "Actual session source exporter lost original association or asserted a theorem";
  val _=ensure(Veri7vn_Native_Recovery_Pin.material executable= #executable exported)
    "Session source exporter lost its fixed executable pin";
  val projection=W.encode_projection metadata;
  val _=ensure(W.decode_projection projection=metadata) "Session source projection lost original context/bytes";
  val _=ensure(W.encode_payload(W.decode_payload(W.encode_payload payload))=W.encode_payload payload)
    "Session source graph changed";
  val binary={version=1,workspace=I.workspace ids,session=sid,utterance=uid,
    source_generation=generation,source_dependencies= #source_dependencies metadata,
    observation=observed,input_encoding="binary",input_bytes="\000\255"}:W.metadata;
  val _=ensure(#input_bytes(W.decode_projection(W.encode_projection binary))="\000\255")
    "Binary source bytes were relabelled or text-decoded";
  val _=rejects(fn()=>W.encode_projection{version=1,workspace=I.workspace ids,session=sid,utterance=uid,
    source_generation=generation,source_dependencies= #source_dependencies metadata,
    observation=observed,input_encoding="UTF-8",input_bytes="\255"});
  val unregistered=L.input{bytes="unregistered",encoding="UTF-8"};
  val second_pin=P.mint issuer observed;
  val _=rejects_with "Session utterance has no original native input identity"
    (fn()=>E.capture ids{input=unregistered,pin=second_pin,context=context_check,source=source_owner});
  val _=Option.app I.release_disposed_input(L.drop_base unregistered);
  val unknown=L.input{bytes="registered other physical input",encoding="UTF-8"};
  val unknown_owner=M.install_host_source ids unknown;
  val _=ensure(M.owns_input unknown_owner unknown andalso Context.is_live context_check)
    "Foreign physical source fixture was not independently live";
  val _=rejects_with "Session source original native context/source association"
    (fn()=>E.capture ids{input=unknown,pin=second_pin,context=context_check,source=source_owner});
  val failed_owner=E.retain copy;
  val failed_destructor=Unsynchronized.ref false;
  val _=rejects_with "Original source capsule differs from actual native source/context"
    (fn()=>Original.capture original_issuer{allocator=ids,input=unknown,pin=second_pin,
      source=source_owner,development=E.development failed_owner,on_release=fn()=>
        (failed_destructor:=true;E.release failed_owner)});
  val _=ensure(not(!failed_destructor) andalso E.retained failed_owner)
    "Failed capsule capture consumed its caller's actual Entry ownership";
  val _=E.release failed_owner;
  val _=Option.app I.release_disposed_input(L.drop_base unknown);
  val _=Context.release context_check;
  val _=P.release second_pin;
  val _=P.invalidate issuer pin;
  val _=ensure(not(E.retained copy) andalso not(Original.live original_copy))
    "Source entry/capsule ignored monotone pin invalidation";
  val _=rejects(fn()=>E.snapshot copy);
  val _=E.release copy;
  val _=rejects_with "Retry original Entry destructor" (fn()=>Original.release original_copy);
  val _=ensure(!attempts=1 andalso L.retained input andalso M.development_live development andalso
    not(Original.live original_copy)) "Failed final destructor resurrected a capsule or lost retry roots";
  val _=Original.release original_copy;
  val _=Original.release original_copy;
  val _=ensure(!attempts=2) "Completed original Entry destructor was repeated";
  val _=ensure(L.disposed input) "Final session source owner retained payload";
  val _=ensure(not(M.development_live development)) "Final session source context was retained";
in val _=writeln "CONVERSATION_SESSION_SOURCE_PASS independent_actual_source child_release retained_view original_context canonical_graph exact_binary_label malformed_utf8 unregistered_source foreign_live_source original_capsule private_issuer retry_final_destructor final_release" end
\<close>
end
