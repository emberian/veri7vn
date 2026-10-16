theory Behavioral_Recipes_Tests
  imports Behavioral_Evaluation_Tests
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure E=Veri7vn_Executable_Identity;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Mathematics_Execution;
  structure V=Veri7vn_Behavioral_Metrics;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure T=Veri7vn_Private_Operation_Tickets();
  val pin=Veri7vn_Native_Build_Image.executable;
  structure NoRecovery =
  struct
    type checked_development=unit type export_intent=Intent.intent
    type binding={development:P.development,source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option*string*P.development)list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,
      goal:IntInf.int,slot:IntInf.int,semantic_generation:IntInf.int,charged_generation:IntInf.int,
      input_bindings:IntInf.int list,dependencies:IntInf.int list,exports:Thm_Name.T list};
    fun binding(_:unit):binding=error "No recovered fixture development";
    fun original_intent(_:unit)=error "No recovered fixture intent":Intent.intent;
    fun consequences(_:unit)=[]:P.consequence list;
    fun executable(_:unit)=pin;
    fun is_available(_:unit)=false;
    fun is_live(_:unit)=false;fun retain(_:unit)=();fun release(_:unit)=();
  end;
  structure NoRequest =
  struct
    type checked_request=unit type export_intent=Intent.intent
    type failure=unit type control_plan=unit
    datatype phase=Plan | ObservedFailure of failure
    type binding={source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option*string*P.development)list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,
      goal:IntInf.int,slot:IntInf.int,charged_generation:IntInf.int,exports:Thm_Name.T list,
      input_bindings:IntInf.int list,dependencies:IntInf.int list};
    fun binding(_:unit):binding=error "No recovered fixture request";
    fun phase(_:unit)=Plan;
    fun control_plan(_:unit):control_plan option=NONE;
    fun original_intent(_:unit)=error "No recovered fixture intent":Intent.intent;
    fun executable(_:unit)=pin;
    fun is_live(_:unit)=false;fun retain(_:unit)=();fun release(_:unit)=();
  end;
  val ids=I.install_host_block{workspace="75757575757575757575757575757575",
    first=7500000000000000000000000000000,past=7500000000000000000000000010000};
  val parent=P.public_image ids(A.policy @{theory Growth_Native});
  val locator=Context.theory_name{long=true} @{theory Growth_Native};
  structure B=Veri7vn_Native_Build_Candidate(
    structure Tickets=T structure Intent=Intent structure Recovery=NoRecovery structure Request=NoRequest
    val executable=pin val cost=1 val max_source_bytes=1000000);
  (* The fixture's construction scope is the candidate root. Independent leases
     model the production dependency-table consumer lifetime; no ID constructor. *)
  structure Owner =
  struct
    datatype lease=Lease of B.candidate option Synchronized.var;
    fun create candidate=Lease(Synchronized.var "behavioral_fixture_candidate"(SOME candidate));
    fun candidate(Lease cell)=case Synchronized.value cell of SOME candidate=>candidate
      | NONE=>error "Fixture lease released";
    fun is_live lease=B.is_live(candidate lease)handle ERROR _=>false;
    fun retain lease=if is_live lease then create(candidate lease)else error "Fixture lease unavailable";
    fun release(Lease cell)=Synchronized.change cell(K NONE);
  end;
  val observer_pin=E.pin @{theory}{artifact="behavioral-recipes-fixture/1",
    compiler="Isabelle/PolyML",target="fixed-recipe-observer",serializers=[],foreign_primitives=[],settings=[]};
  structure Observer=Veri7vn_Behavioral_Recipes(
    structure Builder=B structure Owner=Owner val executable=observer_pin);
  fun installation step=B.install{template=1,profile=2,setup=3,operation=24,step=step,code_generation=23,
    installed_parents=[(locator,parent)]};
  val all_inputs=Unsynchronized.ref([]:L.input list);
  fun owned text=let val input=L.input{bytes=text,encoding="UTF-8"}
      val _=all_inputs:=input::(!all_inputs)
      val source=P.install_host_source ids input
      val slice=L.slice input{start=0,stop=size text,expected=text}
    in(source,slice)end;
  val scope=P.construction_scope();
  val issuer=T.new_issuer();
  val tickets=T.begin_scope issuer{owner_version=1,epoch=1};
  fun build id recipe=
    let val text="theory Behavioral_Recipe imports "^locator^" begin\n"^
        "definition recipe :: math_expr where \"recipe = "^recipe^"\"\nend";
      val(source,slice)=owned text;
      val(manifest,manifest_slice)=owned
        "{\"format\":\"veri7vn.package/0\",\"package\":{\"id\":\"test.behavioral\",\"version\":\"1.0.0\",\"title\":\"Behavioral\",\"description\":\"Exact recipe comparison\"},\"files\":[{\"path\":\"Behavioral_Recipe.thy\",\"role\":\"source\"}],\"requires\":[],\"native\":{\"session\":\"Behavioral_Recipe\",\"theories\":[\"Behavioral_Recipe\"]},\"capabilities\":[]}";
      val intent=Intent.capture_owned scope{source=manifest,slice=manifest_slice,
        source_revision=id+1,manifest=id+2,export_intent=id+3,capabilities=[]};
      val prepared=B.prepare(installation(id+10)){source=source,original_intent=intent,slice=slice,
        source_revision=id+1,manifest=id+2,parents=[B.Installed locator],exports=[],export_intent=id+3,
        candidate=id,request=id+4,goal=id+5,execution=id+6,slot=id+7,semantic_generation=id+8,input_bindings=[id+9]};
      val ticket=T.issue_pure tickets{execution=id+6,slot=id+7,operation={workspace=I.workspace ids,
        request=id+4,profile=2,code_generation=23,operation=24,step=id+10,cost=1,
        inputs=B.prepared_inputs prepared,owner_version=1,epoch=1,journal_sequence=id+11,
        semantic_generation=id+8,implementation_artifact= #artifact(E.manifest pin)}}prepared;
    in B.execute_owned scope ticket end;
  val baseline=build 100 "Parameter 0";
  val candidate=build 200 "Times (Parameter 0) (Rational 2)";
  val declining=build 300 "Divide (Rational 1) (Rational 0)";
  val instance=case M.attach{policy=A.policy @{theory Growth_Native},generation=P.generation parent,
    code_context=E.code_theory(M.executable()),limits={nodes=5000,depth=100,work=100,seconds=2}}of
      M.Ready instance=>instance | _=>error "Behavioral mathematics instance failed";
  val(panel_source,panel_slice)=owned
    "exact\t4\t1\t[(0,2::rat)]\ndecline\t-\t-\t[(0,0::rat)]\nunknown\t-\t-\t[(0,3::rat)]\n";
  val next_owner=Owner.create candidate;
  val base_owner=Owner.create baseline;
  fun config baseline source slice={candidate=next_owner,baseline=baseline,
    candidate_definition=("Behavioral_Recipe.recipe_def",0),
    baseline_definition=("Behavioral_Recipe.recipe_def",0),instance=instance,
    source=source,slice=slice,work=100};
  val pending=Observer.prepare(config base_owner panel_source panel_slice);
  val _=if Observer.progress pending=Observer.Unstarted andalso null(Observer.partial pending)
    then ()else error "Behavioral execution happened before start";
  (* This fixture exercises the fixed native worker. The resident service must
     supply the durable paid start; this unit fixture does not claim that join. *)
  val measured=Observer.measure_started pending;
  val(rows,result)=Observer.result measured;
  val _=if length rows=3 andalso #gain result=1 andalso #unknown result=1 andalso
    #wrong(#baseline result)=1 andalso #wrong(#candidate result)=0 andalso
    #false_assertions(#candidate result)=1 andalso #general result=0 andalso #identity result=0
    then ()else error "Actual paired candidate execution/scoring lost outcome";
  val _=case (#reply(#baseline(hd rows)),#reply(#candidate(hd rows)))of
    (V.Asserted_Rational(2,1),V.Asserted_Rational(4,1))=>()
    | _=>error "Observer measured metadata instead of the actual candidates";
  val _=case Exn.capture Observer.measure_started pending of Exn.Exn _=>()
    | _=>error "Behavioral attempt ran twice";
  val run_context:Observer.run_context={request=400,goal=401,request_slot=402,
    attempt=403,run_spec=404,observation=405,contract=406,policy=407,policy_resource=408,
    exposure=409,observer_semantic_generation=Veri7vn_Native_Descriptor.semantic_generation_id
      ids Observer.observer_generation,executable_generation=410};
  val captured=Observer.capture_result ids run_context measured;
  val(run_source,run_slice)=Observer.capture_source captured;
  val _=if Observer.capture_live captured andalso Observer.capture_context captured=run_context andalso
    P.owns_input run_source(L.owner run_slice) andalso
    member(op =)(Observer.capture_dependencies captured)(P.source_identity panel_source) andalso
    String.isSubstring "integer-microseconds"(L.original run_slice)
    then ()else error "Original temporal run capture lost source/context/panel ownership";
  val restored=Observer.prepare_interrupted(config base_owner panel_source panel_slice);
  val _=if Observer.failed restored andalso Observer.progress restored=Observer.Interrupted then ()
    else error "Restored started attempt was not interrupted";
  val _=case Exn.capture Observer.measure_started restored of Exn.Exn _=>()
    | _=>error "Restored attempt reran measurement for free";
  val _=Observer.release restored;
  val decline_owner=Owner.create declining;
  val regression=Observer.prepare(config decline_owner panel_source panel_slice);
  val(_,regressed)=Observer.result(Observer.measure_started regression);
  val policy:V.policy={minimum_gain=0,maximum_wrong=2,maximum_general_taken=0,
    require_general=true,require_identity=true,maximum_p50_us=10000000};
  val reasons=V.failures policy regressed;
  val _=if member(op =)reasons "False assertions increased" andalso
    member(op =)reasons "General interception unmeasured"then ()else
      error "Actual candidate false assertion/unmeasured routing passed";
  val _=Observer.release regression;
  val _=Owner.release decline_owner;
  val _=L.invalidate(L.owner panel_slice);
  val _=if Observer.is_live pending orelse can Observer.result measured orelse
      Observer.capture_live captured orelse can Observer.capture_source captured then
    error "Forgotten panel retained usable measurement"else();
  val _=Observer.release_capture captured;
  val _=Observer.release pending;
  val _=Owner.release base_owner;val _=Owner.release next_owner;
  val _=List.app B.release[baseline,candidate,declining];
  val _=M.release_instance instance;val _=T.close_scope tickets;
  val _=P.abort_scope scope;val _=P.release parent;
  val _=List.app(fn input=>Option.app I.release_disposed_input(L.drop_base input))(!all_inputs);
in val _=writeln "BEHAVIORAL actual_recipe_pair_unknown_falseassertion_interrupted_forget PASS"end
\<close>
end
