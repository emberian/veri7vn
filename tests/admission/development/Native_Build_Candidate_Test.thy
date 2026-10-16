theory Native_Build_Candidate_Test
  imports "Veri7vn_Native_Build_Metadata.Build_Service_Metadata"
begin
definition native_build_retained :: "nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "native_build_retained rid identity deps = \<lparr>retained_id=identity,
    retained_owner=RequestLocal rid,retained_dependencies=deps,retained_read_dependencies=[],
    retained_access_requirements=[],retained_payload=identity\<rparr>"
definition native_build_requirement :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> artifact_requirement" where
  "native_build_requirement source revision manifest parents exports =
    \<lparr>artifact_template=1,artifact_source=source,artifact_revision=revision,
      artifact_manifest=manifest,artifact_parents=map KnownInput parents,
      artifact_profile=2,artifact_setup=3,artifact_exports=exports\<rparr>"
definition native_build_parent :: "build_service_control \<Rightarrow> subgoal \<Rightarrow> nat list \<Rightarrow> request" where
  "native_build_parent n original shared = \<lparr>request_id=bsc_request n,
    request_generation=bsc_generation n,request_code_generation=bsc_code n,request_prestate=0,
    request_dependencies=shared,allowed_routes=[],permitted_effects=[],request_goals=[original],
    request_blockers=[],request_cancelled=False,request_fuel=1,request_session=None,
    request_observation=StateTimeUnused,request_retention_scopes=[RequestLocal (bsc_request n)]\<rparr>"
definition native_build_output_rows :: "build_service_control \<Rightarrow> artifact_requirement \<Rightarrow>
    nat \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> retained_value list" where
  "native_build_output_rows n required generation closure inputs shared =
    (let original=build_service_child (build_service_plan n 61 62 24 2)
       (required\<lparr>artifact_parents:=map (\<lambda>_. ReservedOutput 21) (artifact_parents required)\<rparr>) []
     in case build_service_artifact n (native_build_parent n original shared) original required generation closure inputs (RequestLocal (bsc_request n)) [] of
      StageOutput _ (ArtifactOutput a) None \<Rightarrow> artifact_assigned_retained a | _ \<Rightarrow> [])"
definition native_build_parameter_rows :: "build_service_control \<Rightarrow> artifact_requirement \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> retained_value list" where
  "native_build_parameter_rows n required closure reads shared =
    (let original=build_service_child (build_service_plan n 61 62 24 2)
       required []
     in case build_service_parameter n (native_build_parent n original shared) original closure reads [] of
    RegisterManaged v \<Rightarrow> [v] | _ \<Rightarrow> [])"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure T=Veri7vn_Private_Operation_Tickets();
  val pin=Veri7vn_Native_Build_Image.executable;
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
    datatype phase=Plan|ObservedFailure of failure;
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
  val installation=B.install{template=1,profile=2,setup=3,operation=24,step=2,code_generation=23,installed_parents=[(locator,parent)]};
  val source=File.read(Path.append(Resources.master_directory @{theory})
    (Path.explode "Provenance_Specialist.thy"));
  val input=L.input{bytes=source,encoding="UTF-8"};
  val owner=P.install_host_source ids input;
  val slice=L.slice input{start=0,stop=size source,expected=source};
  fun captured_intent revision manifest id theory =
    let val scope=P.construction_scope()
      val original="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.native\",\"version\":\"1.0.0\",\"title\":\"Native\",\"description\":\"Original expectation\"},\"files\":[{\"path\":\"" ^ theory ^ ".thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Native_Test\",\"theories\":[\"" ^ theory ^ "\"]},\"capabilities\":[{\"id\":\"selection\",\"title\":\"Selection\",\"specification\":{\"theory\":\"" ^ theory ^ "\",\"name\":\"" ^ theory ^ ".classified_observations\"},\"contracts\":[]}]}"
      val input=L.input{bytes=original,encoding="UTF-8"}
      val owner=P.install_host_source ids input
      val slice=L.slice input{start=0,stop=size original,expected=original}
      val intent=Intent.capture_owned scope{source=owner,slice=slice,source_revision=revision,
        manifest=manifest,export_intent=id,capabilities=[{id="selection",
          specification={theory=theory,name=theory ^ ".classified_observations"},contracts=[],executable=NONE}]}
      val _=Option.app I.release_disposed_input(L.drop_base input)
      val _=P.commit_scope scope
    in intent end;
  val original_intent=captured_intent 10 11 13 "Provenance_Specialist";
  fun prepared exports=B.prepare installation{source=owner,original_intent=original_intent,slice=slice,source_revision=10,manifest=11,
    parents=[B.Installed locator],exports=exports,export_intent=13,candidate=14,request=22,goal=28,execution=20,slot=21,semantic_generation=27,input_bindings=[40]};
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  fun issue_inputs inputs p cost semantic operation code profile execution slot request=T.issue_pure tickets
    {execution=execution,slot=slot,operation={workspace=P.source_workspace owner,request=request,
      profile=profile,code_generation=code,operation=operation,step=25,cost=cost,
      inputs=inputs,owner_version=1,epoch=1,
      journal_sequence=26,semantic_generation=semantic,implementation_artifact= #artifact(E.manifest pin)}} p;
  fun issue p=issue_inputs(B.prepared_inputs p)p;
  fun ticket p cost=issue p cost 27 24 23 2 20 21 22;
  fun rejects f=case Exn.capture f () of Exn.Exn _=>() | Exn.Res _=>error "Expected build candidate rejection";
  val scope=P.construction_scope();
  val p=prepared [];
  val t=ticket p 1;
  val candidate=B.execute_owned scope t;
  val _=if null(B.exports candidate) andalso null(B.declared_exports candidate) andalso
      not(null(Intent.theorem_names(B.original_intent candidate))) andalso
      #candidate(B.projection candidate)=14 andalso #lineage(B.projection candidate)=20 andalso
      L.original(#slice(B.recipe candidate))=source then ()
    else error "Nonassertional candidate lost exact source/charged lineage";
  val child_source="theory Candidate_Child imports Provenance_Specialist begin\n" ^
    "definition child_value :: nat where \"child_value = 1\"\nend";
  val child_input=L.input{bytes=child_source,encoding="UTF-8"};
  val child_owner=P.install_host_source ids child_input;
  val child_slice=L.slice child_input{start=0,stop=size child_source,expected=child_source};
  val child_intent=captured_intent 55 56 53 "Candidate_Child";
  val child_prepared=B.prepare installation{source=child_owner,original_intent=child_intent,
    slice=child_slice,source_revision=55,manifest=56,
    parents=[B.Candidate(14,"Provenance_Specialist",B.development candidate)],exports=[],
    export_intent=53,candidate=54,request=22,goal=58,execution=50,slot=51,
    semantic_generation=57,input_bindings=[60,14]};
  val child=B.execute_owned scope(issue_inputs[60,14]child_prepared 1 57 24 23 2 50 51 22);
  val nat= Veri7vn_Numerals.nat_of_integer;
  val integer= Veri7vn_Numerals.integer_of_nat;
  fun closure dependencies seed=
    case @{code forget_closure}
      [@{code native_build_retained}(nat 22)(nat 54)(map nat dependencies)] [nat seed]of
      SOME removed=>map integer removed | NONE=>error "Native candidate Forget closure failed";
  val _=if not(member(op =)(closure(#dependencies(B.projection child))14)54) andalso
      member(op =)(closure(B.retention_dependencies child)14)54 andalso
      member(op =)(closure(B.retention_dependencies child)60)54 andalso
      member(op =)(B.prepared_parent_dependencies child_prepared)14 then()
    else error "RequestLocal native candidate omitted actual parent/source-parameter Forget edge";
  val child_projection=B.projection child;
  val control= @{code build_service_control}(nat 22)(nat 58)(nat 51)(nat 60)
    (nat 57)(nat 23)(nat 54)(nat 50);
  val required= @{code native_build_requirement}(nat(#source_owner child_projection))
    (nat(#source_revision child_projection))(nat(#manifest child_projection))
    (map nat(#parents child_projection))(nat(#export_intent child_projection));
  val native_generation=the(I.lookup_generation_id ids(B.native_generation child));
  val rows= @{code native_build_output_rows} control required(nat native_generation)
      (map nat(B.retention_dependencies child))(map nat(B.prepared_inputs child_prepared))
      (map nat(B.retention_dependencies candidate)) @
    @{code native_build_parameter_rows} control required(map nat(B.prepared_parent_dependencies child_prepared))
      [nat(P.source_identity child_owner),nat 14](map nat(B.retention_dependencies candidate));
  fun removed seed=map integer(the(@{code forget_closure}rows[nat seed]));
  val _=if forall(fn seed=>member(op =)(removed seed)54)[14,60,22,21,61,62,40] andalso
      member(op =)(removed 22)60 then()
    else error "Fixed native build metadata left a retained orphan after Forget";
  val _=B.release child;
  val _=Intent.release child_intent;
  val _=L.forget_input child_input;
  val _=if L.disposed child_input then I.release_disposed_input child_input else();
  val _=writeln "native_build_parent_parameter_forget_edges_ok";
  val _=rejects(fn()=>B.execute_owned scope t);
  val _=rejects(fn()=>B.execute_owned scope(ticket p 0));
  val _=List.app(fn t=>rejects(fn()=>B.execute_owned scope t))
    [issue p 1 28 24 23 2 20 21 22,issue p 1 27 25 23 2 20 21 22,
     issue p 1 27 24 24 2 20 21 22,issue p 1 27 24 23 3 20 21 22,
     issue p 1 27 24 23 2 21 21 22,issue p 1 27 24 23 2 20 22 22,
     issue p 1 27 24 23 2 20 21 23];
  val _=List.app(fn inputs=>rejects(fn()=>B.execute_owned scope
    (issue_inputs inputs p 1 27 24 23 2 20 21 22)))
    [[41],[40,41],#dependencies(B.prepared_projection p)];
  val false_source="theory False_Candidate imports " ^ locator ^
    " begin lemma false_claim: \"False\" by simp end";
  val false_prefix="retained original prefix\n";
  val false_input=L.input{bytes=false_prefix ^ false_source ^ "\nretained suffix",encoding="UTF-8"};
  val false_owner=P.install_host_source ids false_input;
  val false_slice=L.slice false_input{start=size false_prefix,stop=size false_prefix+size false_source,expected=false_source};
  val false_intent=captured_intent 30 31 32 "False_Candidate";
  val false_prepared=B.prepare installation{source=false_owner,original_intent=false_intent,slice=false_slice,source_revision=30,manifest=31,
    parents=[B.Installed locator],exports=[],export_intent=32,candidate=33,
    request=22,goal=28,execution=20,slot=21,semantic_generation=27,input_bindings=[40]};
  val false_scope=P.construction_scope();
  val failed_ticket=ticket false_prepared 1;
  val _=(case Exn.capture(fn()=>B.execute_owned false_scope failed_ticket)() of
      Exn.Exn(B.Build_Failure{phase,source_revision,span=SOME{start,stop},...})=>
        if phase=B.NativeReplay andalso source_revision=30 andalso
          String.isPrefix "lemma false_claim" (String.substring(L.bytes false_input,start,stop-start))
        then () else error "Native diagnostic did not retain original declaration span"
    | _=>error "Expected source-owned false-theorem diagnostic");
  val _=rejects(fn()=>B.execute_owned false_scope failed_ticket);
  val _=P.abort_scope false_scope;
  val _=L.forget_input false_input;
  val _=Intent.release false_intent;
  val failed=P.construction_scope();
  val _=rejects(fn()=>B.execute_owned failed(ticket(prepared[("missing_export",0)])1));
  val _=P.abort_scope failed;
  val _=if B.is_live candidate andalso P.development_live parent then ()
    else error "Failed replay/export rollback released existing owner";
  val _=P.commit_scope scope;
  val _=Intent.release original_intent;
  val _=if Intent.is_live(B.original_intent candidate) then () else error "Candidate did not retain original intent";
  val _=L.forget_input input;
  val _=if not(B.is_live candidate) then () else error "Forget left candidate usable";
  val _=rejects(fn()=>B.recipe candidate);
  val _=B.release candidate;
  val _=P.release parent;
  val _=T.close_scope tickets;
  val _=writeln "Native build candidate: zero-export replay, one-use charge, rollback and Forget passed";
in end
\<close>
end
