theory Package_Qualification_Test
  imports "Veri7vn_Native_Build_Candidate.Native_Build_Candidate"
begin
ML_file "../../src/isabelle/updates/native_package_qualification.ML"
ML_file "../../src/isabelle/updates/native_qualification_worker.ML"
ML_file "../../src/isabelle/updates/native_initial_admission.ML"
ML_file "../../src/isabelle/updates/native_checked_qualification.ML"
ML_file "../../src/isabelle/updates/native_qualification_codec.ML"
ML_file "../../src/isabelle/updates/native_pending_qualification.ML"
ML_file "../../src/isabelle/updates/native_initial_package.ML"
ML_file "../../src/isabelle/updates/native_package_update.ML"
ML_file "../../src/isabelle/updates/native_qualification_restore.ML"
ML_file "../../src/isabelle/updates/native_qualification_check.ML"
ML_file "../../src/isabelle/updates/native_pending_qualification_check.ML"
ML_file "../../src/isabelle/updates/native_initial_template_types.ML"
ML_file "../../src/isabelle/updates/native_initial_template_codec.ML"
ML_file "../../src/isabelle/updates/native_initial_template_check.ML"
ML_file "../../src/isabelle/updates/native_initial_template.ML"
ML_file "../../src/isabelle/updates/native_qualification_export.ML"
ML_file "../../src/isabelle/updates/native_initial_admitted_context.ML"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure T=Veri7vn_Private_Operation_Tickets();
  val pin=E.pin @{theory} {artifact="package-updates-test-builder",compiler="Isabelle/PolyML",
    target="controlled-source-replay",serializers=[],foreign_primitives=[],settings=[]};
  structure NoRecovery =
  struct
    type checked_development=unit
    type export_intent=Intent.intent
    type binding= {development:P.development,source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option * string * P.development) list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,semantic_generation:IntInf.int,charged_generation:IntInf.int,input_bindings:IntInf.int list,dependencies:IntInf.int list,exports:Thm_Name.T list}
    fun binding(_:unit):binding=error "No recovery witness in this fixture"
    fun original_intent(_:unit):export_intent=error "No restored intent"
    fun consequences(_:unit)=[]:P.consequence list
    fun executable(_:unit)=pin
    fun is_live(_:unit)=false
    fun is_available(_:unit)=false
    fun retain(_:unit)=()
    fun release(_:unit)=()
  end;
  structure NoRequest =
  struct
    type checked_request=unit;
    type export_intent=Intent.intent;
    type failure=unit;
    type control_plan=unit;
    datatype phase=Plan | ObservedFailure of failure;
    fun phase(_:unit)=Plan;
    fun control_plan(_:unit):control_plan option=NONE;
    type binding={source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option*string*P.development)list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,
      goal:IntInf.int,slot:IntInf.int,charged_generation:IntInf.int,exports:Thm_Name.T list,
      input_bindings:IntInf.int list,dependencies:IntInf.int list};
    fun binding(_:unit):binding=error "No recovered request in this fixture";
    fun original_intent(_:unit):export_intent=error "No recovered request intent";
    fun executable(_:unit)=pin;
    fun is_live(_:unit)=false;
    fun retain(_:unit)=();
    fun release(_:unit)=();
  end;
  val ids=I.install_host_block{workspace="0123456789abcdef0123456789abcdef",first=1,past=60000};
  val parent=P.public_image ids (Veri7vn_Native_Admission.policy @{theory Veri7vn_Admission});
  val locator=Context.theory_name{long=true} @{theory Veri7vn_Admission};
  structure B=Veri7vn_Native_Build_Candidate(
    structure Tickets=T structure Intent=Intent structure Recovery=NoRecovery structure Request=NoRequest val executable=pin val cost=1 val max_source_bytes=1000000);
  val installation=B.install{template=1,profile=2,setup=3,operation=24,step=25,code_generation=23,installed_parents=[(locator,parent)]};
  structure Q=Veri7vn_Package_Qualification(structure Builder=B val executable=pin);
  structure NoUpdateRequest =
  struct
    type candidate=B.candidate type checked=unit
    type binding={candidate:candidate,baseline:candidate,snapshot:Veri7vn_Pending_Qualification_Types.update,
      phase:Veri7vn_Pending_Qualification_Types.phase}
    fun binding(_:unit):binding=error "No pending update request in fresh fixture"
    fun executable(_:unit)=pin
    fun fragment(_:unit)=I.combine_fragments[]
    fun is_live(_:unit)=false
    fun retain(_:unit)=()
    fun release(_:unit)=()
  end;
  structure NoInitialRequest =
  struct
    type candidate=B.candidate type intent=Intent.intent type checked=unit
    type binding={candidate:candidate,intent:intent,snapshot:Veri7vn_Pending_Qualification_Types.initial,
      phase:Veri7vn_Pending_Qualification_Types.phase}
    fun binding(_:unit):binding=error "No pending initial request in fresh fixture"
    fun executable(_:unit)=pin
    fun fragment(_:unit)=I.combine_fragments[]
    fun is_live(_:unit)=false
    fun retain(_:unit)=()
    fun release(_:unit)=()
  end;
  structure U=Veri7vn_Native_Package_Update(structure Builder=B structure Qualification=Q structure Recovery=NoUpdateRequest);
  structure Initial=Veri7vn_Initial_Package_Admission(structure Intent=Intent structure Builder=B val executable=pin);
  structure InitialOwner=Veri7vn_Native_Initial_Package(structure Intent=Intent structure Builder=B structure Admission=Initial structure Recovery=NoInitialRequest);
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  val scope=P.construction_scope();
  fun captured_intent revision manifest intent_id expected executable=
    let
      val original="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.compatibility\",\"version\":\"1.0.0\",\"title\":\"Compatibility\",\"description\":\"Original intent\"},\"files\":[{\"path\":\"Compatibility_Specialist.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Compatibility\",\"theories\":[\"Compatibility_Specialist\"]},\"capabilities\":[{\"id\":\"logical\",\"title\":\"Logical\",\"specification\":{\"theory\":\"Compatibility_Specialist\",\"name\":\""^expected^"\"},\"contracts\":[]}]}";
      val input=L.input{bytes=original,encoding="UTF-8"};
      val source=P.install_host_source ids input;
      val slice=L.slice input{start=0,stop=size original,expected=original};
      val intent=Intent.capture_owned scope{source=source,slice=slice,source_revision=revision,
        manifest=manifest,export_intent=intent_id,capabilities=[{id="logical",
          specification={theory="Compatibility_Specialist",name=expected},contracts=[],executable=executable}]};
      val _=Option.app I.release_disposed_input(L.drop_base input);
    in intent end;
  fun prepare_selected id proposition name definition expected selected executable=
    let
      val source="theory Compatibility_Specialist imports \""^locator^
        "\" begin "^definition^" lemma "^name^": \""^proposition^"\" by simp end";
      val input=L.input{bytes=source,encoding="UTF-8"};
      val owner=P.install_host_source ids input;
      val slice=L.slice input{start=0,stop=size source,expected=source};
      val original_intent=captured_intent(id+1)(id+2)(id+3)expected executable;
      val prepared=B.prepare installation{source=owner,original_intent=original_intent,slice=slice,source_revision=id+1,manifest=id+2,
        parents=[B.Installed locator],exports=selected,
        export_intent=id+3,candidate=id,request=22,goal=28,execution=id+4,slot=id+5,semantic_generation=27,input_bindings=[id+6]};
    in (prepared,input) end;
  fun execute_prepared prepared=
    let val plan=B.prepared_plan prepared
      val ticket=T.issue_pure tickets
        {execution= #execution plan,slot= #slot plan,operation={workspace=Intent.workspace(B.prepared_original_intent prepared),
          request= #request plan,profile=2,code_generation=23,operation=24,step=25,cost=1,
          inputs=B.prepared_inputs prepared,owner_version=1,epoch=1,
          journal_sequence=26,semantic_generation= #semantic_generation plan,implementation_artifact="package-updates-test-builder"}} prepared
    in B.execute_owned scope ticket end;
  fun build_selected id proposition name definition expected selected executable=
    let val (prepared,input)=prepare_selected id proposition name definition expected selected executable
    in (execute_prepared prepared,input) end;
  fun build id proposition name definition=build_selected id proposition name definition
    ("Compatibility_Specialist."^name)[("Compatibility_Specialist."^name,0)]NONE;
  fun rejects f=case Exn.capture f () of Exn.Exn _=>() | Exn.Res _=>error "Expected qualification rejection";
  val (baseline,_)=build 100 "True" "exported" "";
  val contract=Q.retain_baseline_contract baseline;
  val (compatible,input)=build 200 "True" "exported" "";
  val observation=Q.measure contract compatible;
  val _=if Q.count observation=1 andalso Q.is_live observation then ()
    else error "Compatible native export not measured";
  val (wrong,_)=build 300 "True \\<and> True" "exported" "";
  val _=rejects(fn()=>Q.measure contract wrong);
  val (assumptions,_)=build 400 "P \\<Longrightarrow> P" "exported" "";
  val _=rejects(fn()=>Q.measure contract assumptions);
  val (missing,_)=build 500 "True" "other" "";
  val _=rejects(fn()=>Q.measure contract missing);
  val _=if Q.is_live observation andalso B.is_live baseline then ()
    else error "Failed qualification changed the retained baseline";
  val (old_meaning,_)=build 600 "value = value" "exported"
    "definition value :: nat where \"value = 1\"";
  val structural_contract=Q.retain_baseline_contract old_meaning;
  val (new_meaning,_)=build 700 "value = value" "exported"
    "definition value :: nat where \"value = 2\"";
  val structural=Q.measure structural_contract new_meaning;
  val _=if Q.is_live structural andalso not(Q.semantic_reuse_permitted structural) then ()
    else error "Structural equality licensed semantic reuse across changed definitions";
  val _=Q.release structural;
  val _=Q.release_contract structural_contract;
  val initial_observation=Initial.measure(B.original_intent compatible)compatible;
  val _=if Initial.count initial_observation=1 andalso not(Initial.semantic_reuse_permitted initial_observation)
    then () else error "Initial admission did not retain exact logical scope";
  val copied=captured_intent 201 202 203 "Compatibility_Specialist.exported" NONE;
  val _=rejects(fn()=>Initial.measure copied compatible);
  val (unfinished,_)=build_selected 800 "True" "exported" "definition value :: nat where \"value = 1\""
    "Compatibility_Specialist.value" [] NONE;
  val _=if B.is_live unfinished andalso null(B.exports unfinished) then ()
    else error "Unfinished zero-export development was rejected";
  val _=rejects(fn()=>Initial.measure(B.original_intent unfinished)unfinished);
  val (unmatched,_)=build_selected 900 "True" "exported" "definition value :: nat where \"value = 1\""
    "Compatibility_Specialist.value" [("Compatibility_Specialist.exported",0)] NONE;
  val _=rejects(fn()=>Initial.measure(B.original_intent unmatched)unmatched);
  val _=Initial.release initial_observation;
  val context:U.context={request=1001,goal=1002,request_slot=1201,interpretation=1003,run_spec=1004,
    policy=1005,policy_resource=1006,exposure=1007,structural_metric=1008,
    count_metric=1009,unit_id=1010,executable_generation=1011,slot=1012,previous=SOME 100};
  val _=rejects(fn()=>U.prepare ids context {candidate=baseline,baseline=baseline});
  val initial_context:InitialOwner.context={request=1101,goal=1102,request_slot=1200,interpretation=1103,run_spec=1104,
    policy=1105,policy_resource=1106,exposure=1107,acceptance_metric=1108,
    count_metric=1109,unit_id=1110,executable_generation=1111,slot=1112};
  val initial_pending=InitialOwner.prepare scope ids initial_context
    {candidate=compatible,intent=B.original_intent compatible};
  val initial_request_snapshot=InitialOwner.pending_snapshot initial_pending;
  val initial_job=InitialOwner.start_after_ack initial_pending;
  val initial_qualified=Exn.release(InitialOwner.join initial_job);
  val _=if InitialOwner.finished initial_job then () else error "Initial worker did not join";
  val _=if #2(InitialOwner.result initial_qualified)=1 then () else error "Initial owner lost actual admission";
  val _=rejects(fn()=>InitialOwner.measure_started initial_pending);
  fun snapshots consequences=map(fn consequence=>
    let val accepted=P.accepted consequence
    in (the(P.public_name consequence),Veri7vn_Native_Sequent.capture
      (Veri7vn_Native_Admission.target accepted)(Veri7vn_Native_Admission.theorem accepted)) end)consequences;
  structure Wire=Veri7vn_Qualification_Codec;
  val (initial_projection,initial_count)=InitialOwner.result initial_qualified;
  val initial_wire:Wire.initial={context= #context initial_projection,names= #names initial_projection,
    candidate= #candidate initial_projection,profile= #profile initial_projection,count=initial_count,
    dependencies= #dependencies initial_projection,exports=snapshots(InitialOwner.exports initial_qualified)};
  val initial_bytes=Wire.encode_initial initial_wire;
  val _=if Wire.encode_initial(Wire.decode_initial initial_bytes)=initial_bytes then ()
    else error "Initial role codec lost exact native snapshots";
  val _=rejects(fn()=>Wire.decode_update initial_bytes);
  val _=rejects(fn()=>Wire.decode_initial(initial_bytes^"trailing"));
  val pending=U.prepare ids context {candidate=compatible,baseline=baseline};
  val update_request_snapshot=U.pending_snapshot pending;
  val update_job=U.start_after_ack pending;
  val qualified=Exn.release(U.join update_job);
  val _=if U.finished update_job then () else error "Update worker did not join";
  val _=if #2(U.result qualified)=1 then () else error "Opaque update lost measured comparison";
  val (update_projection,update_count)=U.result qualified;
  val update_wire:Wire.update={context= #context update_projection,names= #names update_projection,
    candidate= #candidate update_projection,baseline= #baseline update_projection,
    profile= #profile update_projection,count=update_count,dependencies= #dependencies update_projection,
    expected_exports=U.expected_exports qualified,exports=snapshots(U.exports qualified)};
  val update_bytes=Wire.encode_update update_wire;
  val _=if Wire.encode_update(Wire.decode_update update_bytes)=update_bytes then ()
    else error "Update role codec lost exact expected/current native snapshots";
  (* Test-only privileged owner. It retains each complete B object until both
     producer and checked consumers drain; raw candidate refs are not leases. *)
  structure Lease =
  struct
    type candidate=B.candidate
    datatype lease=Lease of {root:(candidate*int)option Synchronized.var,active:bool Synchronized.var}
    fun create candidate=Lease{root=Synchronized.var "test_candidate_root"(SOME(candidate,1)),
      active=Synchronized.var "test_candidate_handle" true}
    fun candidate(Lease{root,active})=
      if not(Synchronized.value active) then error "Test lease released" else
      (case Synchronized.value root of SOME(candidate,_)=>candidate | NONE=>error "Test owner released")
    fun is_live lease=B.is_live(candidate lease) handle ERROR _=>false
    fun retain(lease as Lease{root,...})=
      (if is_live lease then () else error "Test lease unavailable";
       Synchronized.change root(fn SOME(candidate,n)=>SOME(candidate,n+1) | NONE=>error "Test owner released");
       Lease{root=root,active=Synchronized.var "test_retained_candidate" true})
    fun release(Lease{root,active})=Synchronized.change active(fn live=>if not live then false else
      (Synchronized.change root(fn NONE=>NONE | SOME(candidate,n)=>if n>1 then SOME(candidate,n-1)
        else (B.release candidate;NONE));false))
  end;
  structure Checkpoint =
  struct
    fun initial checkpoint wire=checkpoint="unit-started-initial" andalso Wire.encode_initial wire=initial_bytes
    fun update checkpoint wire=checkpoint="unit-started-update" andalso Wire.encode_update wire=update_bytes
  end;
  structure CheckedInitial=Veri7vn_Check_Initial_Qualification(
    structure Intent=Intent structure Builder=B structure Owner=Lease structure Admission=Initial
    structure Checkpoint=Checkpoint);
  structure CheckedUpdate=Veri7vn_Check_Update_Qualification(
    structure Builder=B structure Owner=Lease structure Qualification=Q structure Checkpoint=Checkpoint);
  structure Recovery=Veri7vn_Native_Recovery_Check;
  structure Manifest=Veri7vn_Recovery_Manifest;
  structure Material=Veri7vn_Qualification_Material_Check;
  structure Committed=Veri7vn_Committed_Native_Recovery;
  val image=Recovery.install_host_image(Veri7vn_Native_Admission.policy @{theory})
    "unit-package-qualifier-image-v1";
  (* This named host installer is a unit fixture for protected material. The
     production store authenticates its checkpoint and installed image first. *)
  fun committed_at association role marker checkpoint bytes (names:Veri7vn_Qualification_Recovery_Types.names)=
    let val closure=Material.closure image pin
      val manifest=Manifest.encode{profile=role,workspace=I.workspace ids,association=association,
        semantic_generation= #semantic_generation names,projection=Material.digest bytes,
        sequent=Material.digest "",context_closure=Material.digest closure,payload=Material.digest marker,
        reconstruction=Manifest.Controlled_Recipe,executable=SOME(Veri7vn_Native_Recovery_Pin.digest pin)}
    in Committed.install_committed_host{workspace=I.workspace ids,journal_sequence=1,
      association=association,semantic_generation= #semantic_generation names,checkpoint=checkpoint,
      manifest=manifest,projection=bytes,sequent="",context_closure=closure,reconstruction=marker} end;
  fun committed role marker checkpoint bytes (names:Veri7vn_Qualification_Recovery_Types.names)=
    committed_at (#evidence names) role marker checkpoint bytes names;
  val candidate_lease=Lease.create compatible;
  val baseline_lease=Lease.create baseline;
  structure InitialExportOwner =
  struct
    type value=InitialOwner.qualified
    structure Root=Veri7vn_Checked_Qualification_Root(type payload=value
      val live=fn _=>InitialOwner.is_live initial_pending
      val dispose=fn _=>InitialOwner.release initial_pending)
    type lease=Root.checked
    val create=Root.create val value=Root.read val is_live=Root.is_live
    val retain=Root.retain val release=Root.release
    fun workspace lease=(ignore(value lease);I.workspace ids)
  end;
  structure InitialExporter=Veri7vn_Export_Initial_Qualification(structure Owner=InitialExportOwner
    val result=InitialOwner.result val exports=InitialOwner.exports val executable=pin);
  structure InitialPendingExportOwner =
  struct
    type value=InitialOwner.pending type lease=InitialExportOwner.lease
    fun value lease=(ignore(InitialExportOwner.value lease);initial_pending)
    val workspace=InitialExportOwner.workspace val is_live=InitialExportOwner.is_live
    val retain=InitialExportOwner.retain val release=InitialExportOwner.release
  end;
  structure InitialPendingExporter=Veri7vn_Export_Initial_Qualification_Request(
    structure Owner=InitialPendingExportOwner val snapshot=InitialOwner.pending_snapshot val executable=pin);
  structure AdmittedContext=Veri7vn_Initial_Admitted_Context(
    structure Intent=Intent structure Builder=B structure CandidateOwner=Lease
    structure FreshOwner=InitialExportOwner structure Checked=CheckedInitial
    val result=InitialOwner.result val exports=InitialOwner.exports val executable=pin
    val observer_generation=Initial.observer_generation);
  val initial_export_lease=InitialExportOwner.create initial_qualified;
  val initial_export=InitialExporter.export image initial_export_lease;
  val initial_pending_export=InitialPendingExporter.export image initial_export_lease;
  val admitted_context=AdmittedContext.create ids initial_export_lease candidate_lease;
  val retained_admitted_context=AdmittedContext.retain admitted_context;
  val _=AdmittedContext.release admitted_context;
  val _=rejects(fn()=>AdmittedContext.create ids initial_export_lease baseline_lease);
  val _=InitialExportOwner.release initial_export_lease;
  fun commit_export checkpoint (a:Veri7vn_Qualification_Export_Types.artifacts)=
    Committed.install_committed_host{workspace= #workspace a,journal_sequence=1,association= #association a,
      semantic_generation= #semantic_generation a,checkpoint=checkpoint,manifest= #manifest a,
      projection= #projection a,sequent= #sequent a,context_closure= #context_closure a,reconstruction= #reconstruction a};
  val initial_artifacts=InitialExporter.artifacts initial_export;
  val _=if #projection initial_artifacts=initial_bytes andalso #sequent initial_artifacts="" andalso
    #association initial_artifacts= #evidence(#names initial_projection) then ()
    else error "Actual initial exporter changed role/association/native snapshots";
  val initial_material=commit_export "unit-started-initial" initial_artifacts;
  val checked_initial=CheckedInitial.check ids image initial_material candidate_lease;
  val retained_initial=CheckedInitial.retain checked_initial;
  val restored_admitted_context=AdmittedContext.restore ids checked_initial candidate_lease;
  val _=rejects(fn()=>AdmittedContext.restore ids checked_initial baseline_lease);
  val _=if AdmittedContext.semantic_generation retained_admitted_context=
      AdmittedContext.semantic_generation restored_admitted_context andalso
    Context.eq_thy(Veri7vn_Native_Admission.policy_theory(AdmittedContext.policy retained_admitted_context),
      Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation(AdmittedContext.development retained_admitted_context)))) andalso
    length(AdmittedContext.logical_exports restored_admitted_context)=1 andalso
    member(op =)(AdmittedContext.dependencies restored_admitted_context)(#evidence(#names initial_projection)) then ()
    else error "Fresh/restored admitted context lost actual policy/export/assurance connection";
  val _=CheckedInitial.release checked_initial;
  val _=if CheckedInitial.is_live retained_initial andalso
    #names(CheckedInitial.binding retained_initial)= #names initial_projection then ()
    else error "Checked initial role lost saved IDs or retained native owner";
  val changed_image=Recovery.install_host_image(Veri7vn_Native_Admission.policy @{theory})
    "unit-package-qualifier-image-v2";
  val _=rejects(fn()=>CheckedInitial.check ids changed_image initial_material candidate_lease);
  structure UpdateExportOwner =
  struct
    type value=U.qualified
    structure Root=Veri7vn_Checked_Qualification_Root(type payload=value
      val live=fn _=>U.is_live pending val dispose=fn _=>U.release pending)
    type lease=Root.checked
    val create=Root.create val value=Root.read val is_live=Root.is_live
    val retain=Root.retain val release=Root.release
    fun workspace lease=(ignore(value lease);I.workspace ids)
  end;
  structure UpdateExporter=Veri7vn_Export_Update_Qualification(structure Owner=UpdateExportOwner
    val result=U.result val expected_exports=U.expected_exports val exports=U.exports val executable=pin);
  val update_export_lease=UpdateExportOwner.create qualified;
  val update_export=UpdateExporter.export image update_export_lease;
  val _=UpdateExportOwner.release update_export_lease;
  val update_artifacts=UpdateExporter.artifacts update_export;
  val _=if #projection update_artifacts=update_bytes andalso #sequent update_artifacts="" andalso
    #association update_artifacts= #evidence(#names update_projection) then ()
    else error "Actual update exporter lost captured baseline contract";
  val update_material=commit_export "unit-started-update" update_artifacts;
  val checked_update=CheckedUpdate.check ids image update_material
    {candidate=candidate_lease,baseline=baseline_lease};
  val _=if CheckedUpdate.is_live checked_update andalso
    #names(CheckedUpdate.binding checked_update)= #names update_projection then ()
    else error "Checked update role lost saved IDs/native comparison";
  structure PendingWire=Veri7vn_Pending_Qualification_Codec;
  structure PendingTypes=Veri7vn_Pending_Qualification_Types;
  val pending_initial_bytes=PendingWire.encode_initial initial_request_snapshot;
  val pending_update_bytes=PendingWire.encode_update update_request_snapshot;
  val pending_exported=InitialPendingExporter.artifacts initial_pending_export;
  val _=if #projection pending_exported=pending_initial_bytes andalso #association pending_exported=1200 then ()
    else error "Actual pending exporter used publication/evidence slot";
  val _=if PendingWire.encode_initial(PendingWire.decode_initial pending_initial_bytes)=pending_initial_bytes andalso
    PendingWire.encode_update(PendingWire.decode_update pending_update_bytes)=pending_update_bytes then ()
    else error "Pending qualification codec roundtrip";
  val _=rejects(fn()=>PendingWire.decode_initial initial_bytes);
  val _=rejects(fn()=>PendingWire.decode_update pending_initial_bytes);
  structure PendingCheckpoint =
  struct
    fun initial checkpoint wire=if PendingWire.encode_initial wire<>pending_initial_bytes then NONE else
      (case checkpoint of "unit-prepared-initial"=>SOME PendingTypes.RequestPrepared
       | "unit-started-request-initial"=>SOME PendingTypes.QualificationStarted | _=>NONE)
    fun update checkpoint wire=if PendingWire.encode_update wire=pending_update_bytes andalso
      checkpoint="unit-reserved-update" then SOME PendingTypes.QualificationReserved else NONE
  end;
  structure CheckedInitialRequest=Veri7vn_Check_Initial_Qualification_Request(
    structure Intent=Intent structure Builder=B structure Owner=Lease structure Admission=Initial
    structure Checkpoint=PendingCheckpoint);
  structure CheckedUpdateRequest=Veri7vn_Check_Update_Qualification_Request(
    structure Builder=B structure Owner=Lease structure Qualification=Q structure Checkpoint=PendingCheckpoint);
  structure RestoredInitial=Veri7vn_Native_Initial_Package(
    structure Intent=Intent structure Builder=B structure Admission=Initial structure Recovery=CheckedInitialRequest);
  structure RestoredUpdate=Veri7vn_Native_Package_Update(
    structure Builder=B structure Qualification=Q structure Recovery=CheckedUpdateRequest);
  val initial_request_material=committed_at 1200 Manifest.InitialQualificationRequest
    "initial-qualification-request/2" "unit-prepared-initial" pending_initial_bytes (#names initial_projection);
  val initial_started_material=committed_at 1200 Manifest.InitialQualificationRequest
    "initial-qualification-request/2" "unit-started-request-initial" pending_initial_bytes (#names initial_projection);
  val update_request_material=committed_at 1201 Manifest.UpdateQualificationRequest
    "update-qualification-request/1" "unit-reserved-update" pending_update_bytes (#names update_projection);
  val checked_initial_request=CheckedInitialRequest.check ids image initial_request_material candidate_lease;
  val checked_initial_started=CheckedInitialRequest.check ids image initial_started_material candidate_lease;
  val checked_update_request=CheckedUpdateRequest.check ids image update_request_material
    {candidate=candidate_lease,baseline=baseline_lease};
  val restored_prepared=RestoredInitial.restore scope checked_initial_request;
  val restored_started=RestoredInitial.restore scope checked_initial_started;
  val restored_reserved=RestoredUpdate.restore checked_update_request;
  val _=if #names(RestoredInitial.reservation restored_prepared)= #names initial_projection andalso
    not(RestoredInitial.failed restored_prepared) andalso RestoredInitial.failed restored_started andalso
    #names(RestoredUpdate.reservation restored_reserved)= #names update_projection andalso
    not(RestoredUpdate.failed restored_reserved) then ()
    else error "Pending reconstruction changed IDs/phase or invented completed observation";
  val _=rejects(fn()=>RestoredInitial.measure_started restored_started);
  val _=RestoredInitial.release restored_prepared;
  val _=RestoredInitial.release restored_started;
  val _=RestoredUpdate.release restored_reserved;
  val _=CheckedInitialRequest.release checked_initial_request;
  val _=CheckedInitialRequest.release checked_initial_started;
  val _=CheckedUpdateRequest.release checked_update_request;
  (* Native unit owner scopes below check template identity/lifetime. The real
     service additionally supplies durable artifact-ack and Frame membership. *)
  structure PreparedLease =
  struct
    type prepared=B.prepared
    structure Root=Veri7vn_Checked_Qualification_Root(type payload=prepared
      val live=B.prepared_live val dispose=fn _=>())
    type lease=Root.checked
    val create=Root.create val prepared=Root.read val is_live=Root.is_live
    val retain=Root.retain val release=Root.release
  end;
  structure TestOutputOwner =
  struct
    type candidate=B.candidate type lease=Lease.lease
    val candidate=Lease.candidate val is_live=Lease.is_live val retain=Lease.retain val release=Lease.release
    fun assigned_slot lease= #slot(B.execution_plan(candidate lease))
  end;
  structure NoTemplateRecovery =
  struct
    type prepared=B.prepared type intent=Intent.intent type checked=unit
    type binding={prepared:prepared,intent:intent,snapshot:Veri7vn_Initial_Qualification_Template_Types.snapshot}
    fun binding(_:unit):binding=error "No saved template in fresh fixture"
    fun executable(_:unit)=pin fun fragment(_:unit)=I.combine_fragments[]
    fun is_live(_:unit)=false fun retain(_:unit)=() fun release(_:unit)=()
  end;
  structure FreshTemplate=Veri7vn_Initial_Qualification_Template(
    structure Intent=Intent structure Builder=B structure PreparedOwner=PreparedLease
    structure OutputOwner=TestOutputOwner structure Admission=Initial structure Recovery=NoTemplateRecovery);
  val (future_build,future_input)=prepare_selected 10000 "True" "exported" ""
    "Compatibility_Specialist.exported" [("Compatibility_Specialist.exported",0)] NONE;
  val future_owner=PreparedLease.create future_build;
  val template_context:Veri7vn_Qualification_Recovery_Types.initial_context=
    {request=22,goal=29,request_slot=1300,interpretation=1301,run_spec=1302,policy=1303,
      policy_resource=1304,exposure=1305,acceptance_metric=1306,count_metric=1307,unit_id=1308,
      executable_generation=1309,slot=1400};
  val template=FreshTemplate.prepare ids template_context future_owner;
  val original_template=FreshTemplate.snapshot template;
  structure TemplateWire=Veri7vn_Initial_Template_Codec;
  val template_bytes=TemplateWire.encode original_template;
  val _=if TemplateWire.encode(TemplateWire.decode template_bytes)=template_bytes andalso
    TemplateWire.variant template_bytes=TemplateWire.Template andalso
    TemplateWire.variant pending_initial_bytes=TemplateWire.Bound then ()
    else error "Initial template/bound v2 codec distinction failed";
  val _=rejects(fn()=>PendingWire.decode_initial template_bytes);
  val legacy_pending=case YXML.parse_body pending_initial_bytes of
    [XML.Elem((name,_),body)]=>YXML.string_of_body[XML.Elem((name,
      [("version","1"),("profile",Initial.profile),("slot","1200")]),body)]
    | _=>error "Fixture pending shape";
  val _=rejects(fn()=>PendingWire.decode_initial legacy_pending);
  val _=rejects(fn()=>TemplateWire.variant legacy_pending);
  structure TemplateCheckpoint =
  struct
    fun template checkpoint wire=TemplateWire.encode wire=template_bytes andalso
      (checkpoint="unit-before-build" orelse checkpoint="unit-after-build-before-Q")
  end;
  structure CheckedTemplate=Veri7vn_Check_Initial_Qualification_Template(
    structure Intent=Intent structure Builder=B structure PreparedOwner=PreparedLease
    structure Admission=Initial structure Checkpoint=TemplateCheckpoint);
  structure RecoveredTemplate=Veri7vn_Initial_Qualification_Template(
    structure Intent=Intent structure Builder=B structure PreparedOwner=PreparedLease
    structure OutputOwner=TestOutputOwner structure Admission=Initial structure Recovery=CheckedTemplate);
  structure TemplateExportOwner =
  struct
    type value=FreshTemplate.template type lease=value
    fun value lease=(ignore(FreshTemplate.snapshot lease);lease)
    fun workspace lease=(ignore(value lease);I.workspace ids)
    val is_live=FreshTemplate.template_live val retain=FreshTemplate.retain_template val release=FreshTemplate.release_template
  end;
  structure TemplateExporter=Veri7vn_Export_Initial_Qualification_Template(
    structure Owner=TemplateExportOwner val snapshot=FreshTemplate.snapshot val executable=pin);
  val template_export=TemplateExporter.export image template;
  val template_artifacts=TemplateExporter.artifacts template_export;
  val _=if #projection template_artifacts=template_bytes andalso #association template_artifacts=1300 then ()
    else error "Actual template exporter lost immutable prepared Build edge";
  val template_material=commit_export "unit-before-build" template_artifacts;
  val checked_template=CheckedTemplate.check ids image template_material future_owner;
  val recovered_template=RecoveredTemplate.restore_template checked_template;
  val _=if #names(RecoveredTemplate.snapshot recovered_template)= #names original_template then ()
    else error "Template restart before build changed preallocated Q IDs";
  val _=rejects(fn()=>RecoveredTemplate.bind ids recovered_template candidate_lease);
  val future_candidate=execute_prepared future_build;
  val future_output=Lease.create future_candidate;
  val after_build_material=committed_at 1300 Manifest.InitialQualificationRequest "initial-qualification-request/2"
    "unit-after-build-before-Q" template_bytes (#names original_template);
  val after_build_checked=CheckedTemplate.check ids image after_build_material future_owner;
  val after_build_template=RecoveredTemplate.restore_template after_build_checked;
  val bound_template=RecoveredTemplate.bind ids after_build_template future_output;
  structure TemplateInitialOwner=Veri7vn_Native_Initial_Package(
    structure Intent=Intent structure Builder=B structure Admission=Initial structure Recovery=RecoveredTemplate);
  val specialized_pending=TemplateInitialOwner.restore scope bound_template;
  val _=if #names(TemplateInitialOwner.reservation specialized_pending)= #names original_template andalso
    not(TemplateInitialOwner.failed specialized_pending) then ()
    else error "Exact build output specialization lost Q identity or invented terminal phase";
  val _=TemplateInitialOwner.release specialized_pending;
  val _=RecoveredTemplate.release bound_template;
  val _=RecoveredTemplate.release_template after_build_template;
  val _=CheckedTemplate.release after_build_checked;
  val _=RecoveredTemplate.release_template recovered_template;
  val _=CheckedTemplate.release checked_template;
  val _=FreshTemplate.release_template template;
  val _=if #projection(TemplateExporter.artifacts template_export)=template_bytes then ()
    else error "Template exporter lost native lease before durable writer completed";
  val _=TemplateExporter.release template_export;
  val _=PreparedLease.release future_owner;
  val _=Lease.release future_output;
  val _=Committed.release template_material;
  val _=Committed.release after_build_material;
  val _=Committed.release initial_request_material;
  val _=Committed.release initial_started_material;
  val _=Committed.release update_request_material;
  val _=rejects(fn()=>CheckedInitial.check ids image initial_material baseline_lease);
  val wrong_pin=E.pin @{theory} {artifact="wrong-qualifier-code",compiler="Isabelle/PolyML",
    target="controlled-source-replay",serializers=[],foreign_primitives=[],settings=[]};
  structure WrongInitial=Veri7vn_Initial_Package_Admission(structure Intent=Intent structure Builder=B val executable=wrong_pin);
  structure WrongChecked=Veri7vn_Check_Initial_Qualification(
    structure Intent=Intent structure Builder=B structure Owner=Lease structure Admission=WrongInitial
    structure Checkpoint=Checkpoint);
  val _=rejects(fn()=>WrongChecked.check ids image initial_material candidate_lease);
  structure ReinstalledInitial=Veri7vn_Initial_Package_Admission(structure Intent=Intent structure Builder=B val executable=pin);
  structure ReinstalledChecked=Veri7vn_Check_Initial_Qualification(
    structure Intent=Intent structure Builder=B structure Owner=Lease structure Admission=ReinstalledInitial
    structure Checkpoint=Checkpoint);
  val observer_restored=ReinstalledChecked.check ids image initial_material candidate_lease;
  val _=I.install_fragments ids[ReinstalledChecked.fragment observer_restored];
  val _=if I.lookup_generation_id ids ReinstalledInitial.observer_generation=
    SOME(#semantic_generation(#names initial_projection)) then ()
    else error "Checked observer alias did not preserve old native semantic ID";
  val _=ReinstalledChecked.release observer_restored;
  val _=Committed.release initial_material;
  val _=Committed.release update_material;
  val _=rejects(fn()=>Wire.decode_initial update_bytes);
  val _=rejects(fn()=>Wire.decode_update(String.substring(update_bytes,0,size update_bytes-1)));
  val _=rejects(fn()=>U.measure_started pending);
  val _=rejects(fn()=>U.prepare ids context {candidate=compatible,baseline=wrong});
  val failed=U.prepare ids context {candidate=wrong,baseline=baseline};
  val _=rejects(fn()=>U.measure_started failed);
  val _=if U.failed failed andalso B.is_live baseline then ()
    else error "Failed update did not preserve baseline owner";
  val _=U.release failed;
  val _=InitialPendingExporter.release initial_pending_export;
  val _=InitialExporter.release initial_export;
  val _=UpdateExporter.release update_export;
  val _=U.release pending;
  val _=if AdmittedContext.is_live retained_admitted_context andalso AdmittedContext.is_live restored_admitted_context then ()
    else error "Admitted context did not independently retain native roots after execution/export cleanup";
  val _=L.forget_input input;
  val _=if not(Q.is_live observation) then () else error "Forgotten candidate observation remained live";
  val _=rejects(fn()=>Q.count observation);
  val _=if not(CheckedInitial.is_live retained_initial) andalso
    not(CheckedUpdate.is_live checked_update) andalso B.is_live baseline then ()
    else error "Forget did not invalidate retained qualification roles or harmed baseline";
  val _=if not(AdmittedContext.is_live retained_admitted_context) andalso
    not(AdmittedContext.is_live restored_admitted_context) then ()
    else error "Forgotten candidate remained live through admitted context lease";
  val _=AdmittedContext.release retained_admitted_context;
  val _=AdmittedContext.release restored_admitted_context;
  val _=CheckedUpdate.release checked_update;
  val _=CheckedInitial.release retained_initial;
  val _=Q.release observation;
  val _=Q.release_contract contract;
  val _=Lease.release candidate_lease;
  val _=Lease.release baseline_lease;
  val _=P.abort_scope scope;
  val _=P.release parent;
  val _=T.close_scope tickets;
  val _=writeln "Package qualification: exact sequents, altered assumptions, missing exports and Forget passed";
in end
\<close>
end
