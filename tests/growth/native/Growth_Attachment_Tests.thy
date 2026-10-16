theory Growth_Attachment_Tests
  imports Growth_Native_Tests
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure Bindings=Veri7vn_Growth_Bindings;
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

  val ids=I.install_host_block{workspace="74747474747474747474747474747474",
    first=7400000000000000000000000000000,past=7400000000000000000000000010000};
  val parent=P.public_image ids(A.policy @{theory Growth_Native});
  val locator=Context.theory_name{long=true} @{theory Growth_Native};
  structure Builder=Veri7vn_Native_Build_Candidate(
    structure Tickets=T structure Intent=Intent structure Recovery=NoRecovery structure Request=NoRequest
    val executable=pin val cost=1 val max_source_bytes=1000000);
  structure Attachment=Veri7vn_Growth_Attachment_Fn(Builder);
  structure Library=Veri7vn_Growth_Library_Fn(Builder);
  structure Worker=Veri7vn_Math_Ticket_Execution_Fn(structure Mathematics=M structure Tickets=T);
  val installation=Builder.install{template=1,profile=2,setup=3,operation=24,step=25,code_generation=23,
    installed_parents=[(locator,parent)]};
  val source="theory Growth_Recipe imports "^locator^" begin\n"^
    "definition recipe :: math_expr where \"recipe = Times (Parameter 0) (Rational 2)\"\n"^
    "definition unrelated :: nat where \"unrelated = 0\"\nend";
  val all_inputs=Unsynchronized.ref([]:L.input list);
  fun owned text=let val input=L.input{bytes=text,encoding="UTF-8"}
      val _=all_inputs:=input::(!all_inputs)
      val source=P.install_host_source ids input
      val slice=L.slice input{start=0,stop=size text,expected=text}
    in(source,slice)end;
  val(owner,slice)=owned source;
  val manifest="{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.growth\",\"version\":\"1.0.0\",\"title\":\"Growth\",\"description\":\"Zero-export native recipe\"},\"files\":[{\"path\":\"Growth_Recipe.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Growth_Recipe\",\"theories\":[\"Growth_Recipe\"]},\"capabilities\":[]}";
  val(intent_source,intent_slice)=owned manifest;
  val intent_scope=P.construction_scope();
  val intent=Intent.capture_owned intent_scope{source=intent_source,slice=intent_slice,
    source_revision=10,manifest=11,export_intent=13,capabilities=[]};
  val prepared=Builder.prepare installation{source=owner,original_intent=intent,slice=slice,
    source_revision=10,manifest=11,parents=[Builder.Installed locator],exports=[],export_intent=13,
    candidate=14,request=22,goal=28,execution=20,slot=21,semantic_generation=27,input_bindings=[40]};
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  val build_ticket=T.issue_pure tickets{execution=20,slot=21,operation={workspace=I.workspace ids,
    request=22,profile=2,code_generation=23,operation=24,step=25,cost=1,
    inputs=Builder.prepared_inputs prepared,owner_version=1,epoch=1,journal_sequence=26,
    semantic_generation=27,implementation_artifact= #artifact(E.manifest pin)}}prepared;
  val build_scope=P.construction_scope();
  val candidate=Builder.execute_owned build_scope build_ticket;
  val instance=case M.attach{policy=A.policy @{theory Growth_Native},generation=P.generation parent,
      code_context=E.code_theory(M.executable()),limits={nodes=5000,depth=100,work=100,seconds=2}}of
    M.Ready instance=>instance | _=>error "Growth attachment mathematics instance failed";
  val library=Library.inspect "recipe" [(candidate,[("Growth_Recipe.recipe_def",0)])];
  val _=case library of [{candidate=14,source_revision=10,relevance,...}]=>
      if relevance>0 then ()else error "Actual retained library ranking lost declared name"
    | _=>error "Retained library inspection lost actual candidate provenance";
  val attachment=Attachment.attach candidate instance{definition=("Growth_Recipe.recipe_def",0)};
  val bridge=Attachment.bridge attachment;
  val _=if null(Builder.exports candidate) andalso null(Builder.declared_exports candidate) andalso
      null(Thm.hyps_of(A.theorem bridge)) andalso Thm.nprems_of(A.theorem bridge)=0 andalso
      null(A.observed_oracles bridge) andalso E.same(Attachment.executable attachment,M.executable())
      then () else error "Recipe attachment invented exports, samples or executable generation";
  val bindings=Bindings.parse(owned "[(0,3::rat)]");
  val application=Attachment.apply attachment{bindings=bindings,work=100};
  val _=Bindings.release bindings;
  val _=if Attachment.application_live application andalso
      Thm.nprems_of(Attachment.application_bridge application)=1 then ()
    else error "Application failed independent source ownership/universal bridge";
  val request=Attachment.input application;
  val cost=Attachment.application_cost application;
  val math_ticket=T.issue_pure tickets{execution=50,slot=51,operation={workspace=I.workspace ids,
    request=52,profile=53,code_generation=54,operation=55,step=56,cost=cost,
    inputs=Attachment.application_dependencies application,owner_version=1,epoch=1,journal_sequence=57,
    semantic_generation=58,implementation_artifact= #artifact(E.manifest(M.executable()))}}
    {instance=instance,request=request,operation=M.operation instance,executable=M.executable()};
  val job=case Worker.start math_ticket of Worker.Ready job=>job | _=>error "Growth attached worker start";
  val output=case Worker.collect job of Worker.Ready output=>output | _=>error "Growth attached worker collect";
  val native=case Worker.native_output output of Worker.Ready native=>native | _=>error "Growth attached output";
  val _=if M.belongs_to request native then () else error "Attached output lost recipe request";
  val _=case M.output_view native of M.Ready(M.Exact_Rational(6,1))=>()
    | _=>error "Real candidate formula did not execute through existing interpreter";
  val _=Worker.release_output output;
  val _=Attachment.release_application application;
  val invalid=Exn.capture(fn()=>Attachment.attach candidate instance{definition=("Growth_Recipe.unrelated_def",0)})();
  val _=case invalid of Exn.Exn _=>() | Exn.Res other=>(Attachment.release other;
    error "Non-mathematical definition obtained executable attachment");
  val _=Builder.release candidate;
  val _=if Attachment.live attachment then error "Released candidate retained executable attachment" else ();
  val _=Attachment.release attachment;
  val _=M.release_instance instance;
  val _=T.close_scope tickets;
  val _=P.abort_scope build_scope;
  val _=P.abort_scope intent_scope;
  val _=P.release parent;
  val _=List.app(fn input=>Option.app I.release_disposed_input(L.drop_base input))(!all_inputs);
in val _=writeln "GROWTH native_recipe_universal_bridge_same_interpreter PASS" end
\<close>
end
