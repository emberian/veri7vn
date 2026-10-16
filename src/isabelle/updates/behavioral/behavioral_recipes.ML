(* Fixed recipe observer. Private assembly supplies the real candidate lease
   owner and calls this worker only after durable paid qualification start. *)
signature VERI7VN_BEHAVIORAL_RECIPES =
sig
  type candidate_projection
  type lease
  type pending type qualified type job
  type capture
  type run_context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,
    attempt:IntInf.int,run_spec:IntInf.int,observation:IntInf.int,contract:IntInf.int,
    policy:IntInf.int,policy_resource:IntInf.int,exposure:IntInf.int,
    observer_semantic_generation:IntInf.int,executable_generation:IntInf.int}
  datatype progress = Unstarted | Preparing | Measuring of {index:int,side:string}
    | Finished | Failed | Interrupted
  type subjects={candidate:candidate_projection,baseline:candidate_projection}
  type snapshot={subjects:subjects,source:IntInf.int,start:int,stop:int,original:string,
    candidate_definition:Thm_Name.T,baseline_definition:Thm_Name.T,work:int,profile:string}
  val profile:string
  val executable:Veri7vn_Executable_Identity.pin
  val observer_generation:Veri7vn_Native_Registry.generation
  val prepare:{candidate:lease,baseline:lease,
    candidate_definition:Thm_Name.T,baseline_definition:Thm_Name.T,
    instance:Veri7vn_Mathematics_Execution.instance,
    source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
    work:int} -> pending
  (* Fixed checked recovery may reconstruct an interrupted started attempt. It
     does not acquire a fresh attempt or make measure_started callable again. *)
  val prepare_interrupted:{candidate:lease,baseline:lease,
    candidate_definition:Thm_Name.T,baseline_definition:Thm_Name.T,
    instance:Veri7vn_Mathematics_Execution.instance,
    source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
    work:int} -> pending
  val subjects:pending -> subjects
  val snapshot:pending -> snapshot
  val subject_generations:pending -> {candidate:Veri7vn_Native_Registry.generation,
    baseline:Veri7vn_Native_Registry.generation}
  val interpreter:pending -> Veri7vn_Executable_Identity.pin
  val interpreter_contract:pending -> Veri7vn_Native_Admission.accepted
  val source:pending -> Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice
  val dependencies:pending -> IntInf.int list
  val progress:pending -> progress
  val partial:pending -> Veri7vn_Behavioral_Metrics.row list
  val partial_side:pending -> {index:int,side:string,measurement:Veri7vn_Behavioral_Metrics.measured} option
  val measure_started:pending -> qualified
  val start_after_ack:pending -> job
  val cancel:job -> unit
  val join:job -> qualified Exn.result
  val finished:job -> bool
  val result:qualified -> Veri7vn_Behavioral_Metrics.row list * Veri7vn_Behavioral_Metrics.summary
  (* Original temporal capture, not a theorem or decoded-row constructor. The
     shared state owner authenticates run_context against the exact paid start. *)
  val capture_result:Veri7vn_Native_Identity_Allocator.allocator -> run_context -> qualified -> capture
  val capture_source:capture -> Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice
  val capture_context:capture -> run_context
  val capture_dependencies:capture -> IntInf.int list
  val capture_live:capture -> bool
  val release_capture:capture -> unit
  val is_live:pending -> bool
  val failed:pending -> bool
  val release:pending -> unit
end;

functor Veri7vn_Behavioral_Recipes
  (structure Builder:VERI7VN_NATIVE_BUILD_CANDIDATE
   structure Owner:sig
     type lease
     val candidate:lease -> Builder.candidate
     val is_live:lease -> bool
     val retain:lease -> lease
     val release:lease -> unit
   end
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_BEHAVIORAL_RECIPES where type candidate_projection=Builder.projection
    and type lease=Owner.lease =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure M=Veri7vn_Mathematics_Execution;
  structure V=Veri7vn_Behavioral_Metrics;
  structure Attachment=Veri7vn_Growth_Attachment_Fn(Builder);
  structure Panel=Veri7vn_Behavioral_Panel(Veri7vn_Growth_Bindings);
  type candidate_projection=Builder.projection;
  type lease=Owner.lease;
  val profile="recipe-math-behavior/1";
  val executable=executable;
  val _=V.require(Context.subthy(@{theory},E.code_theory executable))
    "Behavioral observer code context missing";
  val observer_generation=R.generation(Proof_Context.init_global(E.code_theory executable))
    {packages=[profile],runtime= #artifact(E.manifest executable),
      policy="fixed-recipe-math-observation/1",sources=[],interpretation=profile};
  datatype progress=Unstarted | Preparing | Measuring of {index:int,side:string} | Finished | Failed | Interrupted;
  type subjects={candidate:Builder.projection,baseline:Builder.projection};
  type snapshot={subjects:subjects,source:IntInf.int,start:int,stop:int,original:string,
    candidate_definition:Thm_Name.T,baseline_definition:Thm_Name.T,work:int,profile:string};
  type input={candidate:Owner.lease,baseline:Owner.lease,
    candidate_definition:Thm_Name.T,baseline_definition:Thm_Name.T,
    instance:M.instance,source:P.source_owner,slice:L.slice,work:int,
    lease:L.lease,progress:progress Synchronized.var,rows:V.row list Synchronized.var,
    partial_side:{index:int,side:string,measurement:V.measured} option Synchronized.var};
  type observed={input:input,rows:V.row list,summary:V.summary};
  type run_context={request:IntInf.int,goal:IntInf.int,request_slot:IntInf.int,
    attempt:IntInf.int,run_spec:IntInf.int,observation:IntInf.int,contract:IntInf.int,
    policy:IntInf.int,policy_resource:IntInf.int,exposure:IntInf.int,
    observer_semantic_generation:IntInf.int,executable_generation:IntInf.int};
  type captured={input:input,source:P.source_owner,slice:L.slice,lease:L.lease,
    context:run_context,dependencies:IntInf.int list};
  datatype capture=Capture of captured option Synchronized.var;
  fun input_live({candidate,baseline,source,slice,lease,instance,...}:input)=
    (ignore(L.lease_input lease);Owner.is_live candidate andalso Owner.is_live baseline andalso
      P.owns_input source(L.owner slice) andalso can M.operation instance)handle ERROR _=>false;
  fun release_input({candidate,baseline,lease,...}:input)=
    (Owner.release candidate;Owner.release baseline;Option.app I.release_disposed_input(L.release lease));
  fun failure M.Wrong_Executable="wrong-executable"
    | failure M.Wrong_Generation="wrong-generation"
    | failure(M.Invalid_Contract _)="invalid-contract"
    | failure M.Request_Bound="request-bound" | failure M.Unsupported_Input="unsupported-input"
    | failure M.Execution_Budget="execution-budget" | failure M.Released="released"
    | failure(M.Runtime_Error _)="runtime-error";
  fun reply(M.Exact_Rational pair)=V.Asserted_Rational pair
    | reply M.Undefined_Arithmetic=V.Declined
    | reply(M.Missing_Parameters _)=V.Measurement_Failed "missing-parameters"
    | reply M.Invalid_Syntax=V.Measurement_Failed "invalid-syntax"
    | reply M.Exhausted_Budget=V.Measurement_Failed "execution-budget";
  fun side attachment bindings work=
    let
      val timing=Timing.start();
      val applications=Unsynchronized.ref([]:Attachment.application list);
      val outputs=Unsynchronized.ref([]:M.output list);
      fun cleanup()=Thread_Attributes.uninterruptible_body(fn _=>
        (List.app M.release_output(!outputs);List.app Attachment.release_application(!applications)));
      val attempted=Exn.capture(fn()=>
        let
          val application=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let val application=restore(Attachment.apply attachment){bindings=bindings,work=work}
              val _=applications:=[application]
            in application end)();
          val request=Attachment.input application;
          val native=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            case restore(M.execute(Attachment.executable attachment)(Attachment.instance attachment))request of
              M.Refused reason=>M.Refused reason
            | M.Ready output=>(outputs:=[output];M.Ready output))();
        in case native of M.Refused reason=>V.Measurement_Failed(failure reason)
          | M.Ready output=>if not(M.belongs_to request output)then
              V.Measurement_Failed "output-request-mismatch"
            else(case M.output_view output of M.Refused reason=>V.Measurement_Failed(failure reason)
              | M.Ready view=>reply view)
        end)();
      val _=cleanup();
      val elapsed=Time.toMicroseconds(#elapsed(Timing.result timing));
    in case attempted of Exn.Res result=>{reply=result,elapsed_us=elapsed}:V.measured
      | Exn.Exn exn=>if Exn.is_interrupt exn then Exn.reraise exn
        else {reply=V.Measurement_Failed "application-preparation",elapsed_us=elapsed}end;
  fun measure(input as {candidate,baseline,candidate_definition,baseline_definition,
      instance,source,slice,work,progress,rows,partial_side,...}:input):observed=
    let
      val panel=Unsynchronized.ref(NONE:Panel.panel option);
      val attachments=Unsynchronized.ref([]:Attachment.attachment list);
      fun cleanup()=Thread_Attributes.uninterruptible_body(fn _=>
        (List.app Attachment.release(!attachments);Option.app Panel.release(!panel)));
      val _=Synchronized.change progress(K Preparing);
      val attempted=Exn.capture(fn()=>
        let
          val parsed=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let val value=restore Panel.parse(source,slice)
            in panel:=SOME value;value end)();
          fun attach lease definition=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let val value=restore(Attachment.attach(Owner.candidate lease)instance){definition=definition}
            in attachments:=value::(!attachments);value end)();
          val base=attach baseline baseline_definition;
          val next=attach candidate candidate_definition;
          fun run({index,expected,bindings}:Panel.row)=
            Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let
              val _=V.require(input_live input andalso Panel.live parsed)"Behavioral inputs changed";
              val _=Synchronized.change progress(K(Measuring{index=index,side="baseline"}));
              val base_reply=restore(side base bindings)work;
              val _=Synchronized.change partial_side(K(SOME{index=index,side="baseline",measurement=base_reply}));
              val _=Synchronized.change progress(K(Measuring{index=index,side="candidate"}));
              val next_reply=restore(side next bindings)work;
              val row:V.row={index=index,role=V.Domain,expected=expected,baseline=base_reply,candidate=next_reply};
              val _=Synchronized.change rows(fn existing=>row::existing);
              val _=Synchronized.change partial_side(K NONE);
            in row end)();
          val measured=map run(Panel.rows parsed);
          val _=V.require(input_live input andalso Panel.live parsed)"Behavioral inputs changed";
          val result={input=input,rows=measured,summary=V.summarize measured};
          val _=Synchronized.change progress(K Finished);
        in result end)();
      val _=cleanup();
    in case attempted of Exn.Res result=>result | Exn.Exn exn=>
      (Synchronized.change progress(K(if Exn.is_interrupt exn then Interrupted else Failed));Exn.reraise exn)end;
  structure Worker=Veri7vn_Qualification_Worker(
    type input=input type observation=observed
    val input_live=input_live val observation_live=fn({input,...}:observed)=>input_live input
    val measure=measure val release_input=release_input val release_observation=fn _=>());
  type pending=Worker.pending; type qualified=Worker.qualified; type job=Worker.job;
  fun create interrupted {candidate,baseline,candidate_definition,baseline_definition,
      instance,source,slice,work}=
    let
      val _=V.require(Owner.is_live candidate andalso Owner.is_live baseline andalso
        P.owns_input source(L.owner slice) andalso L.encoding(L.owner slice)="UTF-8" andalso
        size(L.original slice)>0 andalso size(L.original slice)<=65536 andalso
        work>0 andalso work<=4096)"Behavioral input/source bounds";
      fun valid_name(name,index)=size name>0 andalso size name<=4096 andalso index>=0 andalso index<256;
      val _=V.require(valid_name candidate_definition andalso valid_name baseline_definition)
        "Behavioral definition name bounds";
      val next=Owner.candidate candidate; val base=Owner.candidate baseline;
      val _=V.require(#candidate(Builder.projection next)<> #candidate(Builder.projection base))
        "Behavioral comparison requires distinct candidates";
      val workspace=P.source_workspace source;
      val _=V.require(workspace=P.development_workspace(Builder.development next) andalso
        workspace=P.development_workspace(Builder.development base))"Behavioral subject workspace mismatch";
      val retained=Unsynchronized.ref([]:Owner.lease list);
      val lease=Unsynchronized.ref(NONE:L.lease option);
      val attempted=Exn.capture(fn()=>Thread_Attributes.uninterruptible_body(fn _=>
        let fun retain owner=let val value=Owner.retain owner
              in retained:=value::(!retained);value end;
          val next=retain candidate; val base=retain baseline;
          val held=L.retain(L.owner slice); val _=lease:=SOME held;
          val input:input={candidate=next,baseline=base,candidate_definition=candidate_definition,
            baseline_definition=baseline_definition,instance=instance,source=source,slice=slice,work=work,
            lease=held,progress=Synchronized.var "behavioral_progress"(if interrupted then Interrupted else Unstarted),
            rows=Synchronized.var "behavioral_partial_rows"[],
            partial_side=Synchronized.var "behavioral_partial_side"NONE};
        in if interrupted then Worker.create_interrupted input else Worker.create input end))();
    in case attempted of Exn.Res pending=>pending | Exn.Exn exn=>
      (List.app Owner.release(!retained);Option.app(fn held=>Option.app I.release_disposed_input(L.release held))(!lease);
       Exn.reraise exn)end;
  val prepare=create false; val prepare_interrupted=create true;
  fun subjects pending=let val{candidate,baseline,...}=Worker.input pending
    in {candidate=Builder.projection(Owner.candidate candidate),
      baseline=Builder.projection(Owner.candidate baseline)}:subjects end;
  fun source pending=let val{source,slice,...}=Worker.input pending in(source,slice)end;
  fun snapshot pending=
    let val{source,slice,candidate_definition,baseline_definition,work,...}=Worker.input pending
      val{start,stop}=L.offsets slice
    in {subjects=subjects pending,source=P.source_identity source,start=start,stop=stop,
      original=L.original slice,candidate_definition=candidate_definition,
      baseline_definition=baseline_definition,work=work,profile=profile}:snapshot end;
  fun subject_generations pending=let val{candidate,baseline,...}=Worker.input pending
    in {candidate=Builder.native_generation(Owner.candidate candidate),
      baseline=Builder.native_generation(Owner.candidate baseline)}end;
  fun interpreter pending=(ignore(Worker.input pending);M.executable());
  fun interpreter_contract pending=M.contract(#instance(Worker.input pending));
  fun dependencies pending=let val subjects=subjects pending
    in distinct(op =)(P.source_identity(fst(source pending))::
      #candidate(#candidate subjects):: #candidate(#baseline subjects)::
      (#dependencies(#candidate subjects) @ #dependencies(#baseline subjects)))end;
  fun progress pending=Synchronized.value(#progress(Worker.input pending));
  fun partial pending=rev(Synchronized.value(#rows(Worker.input pending)));
  fun partial_side pending=Synchronized.value(#partial_side(Worker.input pending));
  val measure_started=Worker.measure_started; val start_after_ack=Worker.start_after_ack;
  val cancel=Worker.cancel; val join=Worker.join; val finished=Worker.finished;
  fun result qualified=let val(_,observed)=Worker.result qualified
    in(#rows observed,#summary observed)end;
  fun get_capture(Capture cell)=case Synchronized.value cell of SOME value=>value
    | NONE=>error "Behavioral original run capture released";
  fun capture_live capture=(let val{input,source,slice,lease,...}=get_capture capture
    in ignore(L.lease_input lease);input_live input andalso P.owns_input source(L.owner slice)end)
    handle ERROR _=>false;
  fun checked_capture capture=(V.require(capture_live capture)"Behavioral original run capture unavailable";
    get_capture capture);
  fun capture_source capture=let val{source,slice,...}=checked_capture capture in(source,slice)end;
  fun capture_context capture= #context(checked_capture capture);
  fun capture_dependencies capture= #dependencies(checked_capture capture);
  fun release_capture(Capture cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change cell(fn NONE=>NONE
    | SOME{input,lease,...}=>(release_input input;Option.app I.release_disposed_input(L.release lease);NONE)));
  fun context_ids(c:run_context)=[#request c,#goal c,#request_slot c,#attempt c,#run_spec c,
    #observation c,#contract c,#policy c,#policy_resource c,#exposure c,
    #observer_semantic_generation c,#executable_generation c];
  fun capture_result allocator context qualified=
    let
      val(input,observed)=Worker.result qualified;
      val _=V.require(I.workspace allocator=P.source_workspace(#source input))"Behavioral capture workspace";
      val identities=context_ids context;
      val _=V.require(forall(fn n=>n>0 andalso size(IntInf.toString n)<=128)identities)
        "Behavioral run context identity bounds";
      val _=V.require(#observer_semantic_generation context=
        Veri7vn_Native_Descriptor.semantic_generation_id allocator observer_generation)
        "Behavioral capture observer semantic context mismatch";
      fun node name body=XML.Elem((name,[]),body);
      fun text value=(V.require(size value<=1000000 andalso
          not(String.isSubstring "\005" value orelse String.isSubstring "\006" value))
          "Behavioral capture text bound/framing";XML.Text value);
      fun number n=node "integer"[text(IntInf.toString n)];
      fun numbers values=map number values;
      fun strings name values=node name(map(fn value=>node "string"[text value])values);
      fun manifest name pin=
        let val{artifact,compiler,target,serializers,foreign_primitives,settings}=E.manifest pin
        in node name[strings "identity"[artifact,compiler,target],strings "serializers" serializers,
          strings "foreign-primitives" foreign_primitives,strings "settings" settings]end;
      fun projection name(p:Builder.projection)=node name[
        node "identity"(numbers[#template p,#source_owner p,#source_revision p,#manifest p,
          #profile p,#setup p,#export_intent p,#candidate p,#lineage p]),
        node "parents"(numbers(#parents p)),node "dependencies"(numbers(#dependencies p))];
      fun expected(V.Expected_Rational(n,d))=node "exact"[number n,number d]
        | expected V.Must_Decline=node "must-decline"[] | expected V.Unknown=node "unknown"[];
      fun reply(V.Asserted_Rational(n,d))=node "asserted-rational"[number n,number d]
        | reply V.Declined=node "declined"[] | reply V.Not_Taken=node "not-taken"[]
        | reply V.Guarded=node "guarded"[] | reply(V.Measurement_Failed reason)=node "measurement-failed"[text reason];
      fun measured name({reply=value,elapsed_us}:V.measured)=node name[reply value,number elapsed_us];
      fun row({index,role,expected=value,baseline,candidate}:V.row)=
        node "row"[number(IntInf.fromInt index),text(case role of V.Domain=>"domain" |
          V.General=>"general" | V.Identity=>"identity"),expected value,
          measured "baseline" baseline,measured "candidate" candidate];
      val next=Owner.candidate(#candidate input);val base=Owner.candidate(#baseline input);
      val generations=map(Veri7vn_Native_Descriptor.semantic_generation_id allocator)
        [observer_generation,Builder.native_generation next,Builder.native_generation base,
         Veri7vn_Native_Admission.generation(M.contract(#instance input))];
      val{start,stop}=L.offsets(#slice input);
      val(names,indices)=((fst(#candidate_definition input),fst(#baseline_definition input)),
        (snd(#candidate_definition input),snd(#baseline_definition input)));
      val contract=M.contract(#instance input);
      val contract_sequent=Veri7vn_Native_Sequent.encode(Veri7vn_Native_Sequent.capture
        (Veri7vn_Native_Admission.target contract)(Veri7vn_Native_Admission.theorem contract));
      val _=V.require(size contract_sequent<=65536)"Behavioral interpreter sequent byte bound";
      val contract_bytes=Bytes.content(Base64.encode(Bytes.string contract_sequent));
      val raw=YXML.string_of_body[node "behavioral-original-run-v1"[
        text profile,node "run-context"(numbers identities),node "native-generations"(numbers generations),
        projection "candidate"(Builder.projection next),projection "baseline"(Builder.projection base),
        node "panel"[number(P.source_identity(#source input)),number(IntInf.fromInt start),
          number(IntInf.fromInt stop),text(L.original(#slice input))],
        node "definitions"[text(fst names),number(IntInf.fromInt(fst indices)),
          text(snd names),number(IntInf.fromInt(snd indices))],number(IntInf.fromInt(#work input)),
        manifest "observer-executable" executable,manifest "interpreter-executable"(M.executable()),
        (* The sequent codec is already YXML; embed bounded canonical base64,
           never splice its control bytes into this receipt's framing. *)
        strings "interpreter-contract-base64"[contract_bytes],
        strings "measurement-profile"["serial-baseline-then-candidate","Timing.elapsed",
          "integer-microseconds","application-preparation+execution+projection+cleanup",
          "first/warm-state-unclassified","routing-unmeasured"],
        node "rows"(map row(#rows observed))]];
      val _=V.require(size raw<=1000000)"Behavioral original run capture byte bound";
      val retained=Unsynchronized.ref([]:Owner.lease list);
      val leases=Unsynchronized.ref([]:L.lease list);
      val fresh=Unsynchronized.ref(NONE:L.input option);
      fun cleanup()=(List.app Owner.release(!retained);
        List.app(fn lease=>Option.app I.release_disposed_input(L.release lease))(!leases);
        Option.app(fn input=>Option.app I.release_disposed_input(L.drop_base input))(!fresh));
      val attempted=Exn.capture(fn()=>Thread_Attributes.uninterruptible_body(fn _=>
        let fun retain owner=let val value=Owner.retain owner in retained:=value::(!retained);value end;
          val candidate=retain(#candidate input);val baseline=retain(#baseline input);
          val panel_lease=L.retain(L.owner(#slice input));val _=leases:=panel_lease::(!leases);
          val bytes=L.input{bytes=raw,encoding="UTF-8"};val _=fresh:=SOME bytes;
          val source=P.install_host_source allocator bytes;
          val slice=L.slice bytes{start=0,stop=size raw,expected=raw};
          val lease=L.retain bytes;val _=leases:=lease::(!leases);
          val _=Option.app I.release_disposed_input(L.drop_base bytes);val _=fresh:=NONE;
          val held:input={candidate=candidate,baseline=baseline,candidate_definition= #candidate_definition input,
            baseline_definition= #baseline_definition input,instance= #instance input,source= #source input,
            slice= #slice input,work= #work input,lease=panel_lease,
            progress=Synchronized.var "captured_behavioral_progress" Finished,
            rows=Synchronized.var "captured_behavioral_rows"(rev(#rows observed)),
            partial_side=Synchronized.var "captured_behavioral_partial_side"NONE};
          val dependencies=distinct(op =)(P.source_identity source::P.source_identity(#source input)::
            #candidate(Builder.projection next):: #candidate(Builder.projection base)::
            ([#request_slot context,#run_spec context,#observation context,#contract context,
              #policy context,#policy_resource context,#exposure context,
              #observer_semantic_generation context,#executable_generation context] @
             generations @ #dependencies(Builder.projection next) @ #dependencies(Builder.projection base)));
          val _=V.require(length dependencies<=8192 andalso input_live held)"Behavioral capture closure bound/liveness";
        in Capture(Synchronized.var "behavioral_original_run"(SOME{input=held,source=source,
          slice=slice,lease=lease,context=context,dependencies=dependencies}))end))();
    in case attempted of Exn.Res captured=>captured | Exn.Exn exn=>(cleanup();Exn.reraise exn)end;
  val is_live=Worker.is_live;val failed=Worker.failed;val release=Worker.release;
end;
