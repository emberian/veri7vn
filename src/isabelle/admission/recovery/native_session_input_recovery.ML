(* Fixed D65 historical source reconstruction. The static generated matcher
   validates the exact SessionLocal row and returns its ACTUAL pending/recorded
   phase. No decoded source identity, row or clock can create an owner alone. *)
functor Veri7vn_Native_Session_Input_Recovery
  (structure Checkpoint:sig
     val matches:Veri7vn_Committed_Native_Recovery.committed ->
       Veri7vn_Session_Input_Codec.metadata -> {recorded:bool} option
   end
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  structure View:VERI7VN_CHECKED_SESSION_INPUT_VIEW
  type installation
  val install:Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Native_Installed_Roots.registry -> installation
  type batch
  val batch:installation -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Graph.batch -> Veri7vn_Native_Recovery_Inputs.pool -> batch
  val check:batch -> Veri7vn_Committed_Native_Recovery.committed -> View.checked
  val fragment:View.checked -> Veri7vn_Native_Identity_Allocator.fragment
  val close:batch -> unit
end =
struct
  structure Codec=Veri7vn_Session_Input_Codec;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  structure Roots=Veri7vn_Native_Installed_Roots;
  structure E=Veri7vn_Executable_Identity;
  structure A=Veri7vn_Native_Admission;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure G=Veri7vn_Native_Recovery_Graph;
  fun require true _=()|require false message=error message;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  datatype installation=Installation of {image:V.image,roots:Roots.registry,policy:A.policy};
  fun install image roots=
    let val policy=V.image_policy image
      val _=require(Context.subthy(E.code_theory executable,A.policy_theory policy) andalso
        forall(fn locator=>Context.subthy(A.policy_theory(Roots.policy roots locator),A.policy_theory policy))
          (Roots.locators roots)) "Session source code/root is outside installed native image"
    in Installation{image=image,roots=roots,policy=policy}end;
  datatype source_check=Source_Check of Codec.metadata;
  structure Inputs=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified=source_check
    fun binding(Source_Check m)={workspace= #workspace m,identity= #utterance m,
      encoding= #input_encoding m,bytes= #input_bytes m}
  end);
  type payload={allocator:I.allocator,metadata:Codec.metadata,recorded:bool,
    source:Pool.lease,context:G.lease};
  datatype status=Live of payload|Releasing of payload|Retry of payload|Released;
  datatype checked=Checked of status Synchronized.var;
  fun checked_data(Checked cell)=
    let val data=case Synchronized.value cell of Live data=>data|_=>error "Session source witness released or releasing"
      val _=ignore(Pool.input(#source data))
      val _=ignore(G.development(#context data))
    in data end;
  fun release(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Synchronized.change_result cell(fn Live p=>(SOME p,Releasing p)
          |Retry p=>(SOME p,Releasing p)|state=>(NONE,state))
    in case owned of NONE=>()|SOME data=>
      (case Exn.capture(fn()=>(Pool.release(#source data);G.release(#context data)))()of
        Exn.Res()=>Synchronized.change cell(K Released)
      |Exn.Exn failure=>(Synchronized.change cell(K(Retry data));Exn.reraise failure))end);
  fun retain(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result cell(fn Live(data:payload)=>
      let val source=Pool.retain(#source data)
        val result=Exn.capture(fn()=>
          let val context=G.retain(#context data)
            val copy={allocator= #allocator data,metadata= #metadata data,recorded= #recorded data,
              source=source,context=context}:payload
          in Checked(Synchronized.var "checked_session_source"(Live copy))end)()
      in case result of Exn.Res copy=>(copy,Live data)
        |Exn.Exn failure=>(Pool.release source;Exn.reraise failure)end
    |_=>error "Session source witness released or releasing"));
  fun registered witness=
    let val data=checked_data witness val m= #metadata data
      val development=G.development(#context data)
      val dependencies=P.development_dependencies development
      val _=require(P.development_workspace development= #workspace m andalso
        I.lookup_generation_id(#allocator data)(P.generation development)=SOME(#source_generation m) andalso
        I.lookup_input_identity(#allocator data)(Pool.input(#source data))=SOME(#utterance m) andalso
        length dependencies=length(#source_dependencies m) andalso
        forall(fn id=>member(op =)(#source_dependencies m)id)dependencies)
        "Session original native source correspondence has not been atomically registered"
    in()end;
  structure View:VERI7VN_CHECKED_SESSION_INPUT_VIEW where type checked=checked =
  struct
    type checked=checked;
    fun metadata witness= #metadata(checked_data witness);
    fun input witness=Pool.input(#source(checked_data witness));
    fun development witness=G.development(#context(checked_data witness));
    fun recorded witness= #recorded(checked_data witness);
    val validate_registered=registered;
    val live=can registered;
    val retain=retain;
    val release=release;
  end;
  datatype batch=Batch of {installation:installation,allocator:I.allocator,graph:G.batch,pool:Pool.pool,
    roots:checked list option Synchronized.var};
  fun batch(installation as Installation{roots,...}) allocator graph pool=
    (require(Pool.pool_workspace pool=I.workspace allocator andalso G.uses_roots graph roots)
      "Session source restore batch identity/installed roots";
     Batch{installation=installation,allocator=allocator,graph=graph,pool=pool,
       roots=Synchronized.var "session_source_roots"(SOME [])});
  fun close(Batch{roots,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change roots(fn NONE=>NONE|SOME owned=>(List.app release owned;NONE)));
  fun check(Batch{installation=Installation{image,policy,...},allocator,graph,pool,roots})committed=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let val source=Unsynchronized.ref(NONE:Pool.lease option)
      val context=Unsynchronized.ref(NONE:G.lease option)
      val installed=Unsynchronized.ref false
      val result=Exn.capture(fn()=>
        let val material=C.materials committed
          val manifest=M.decode{max_bytes=8192}(#manifest material)
          val _=M.require_profile M.SessionInput manifest
          val _=require(#reconstruction manifest=M.Controlled_Recipe andalso #sequent material="" andalso
            #executable manifest=SOME(Pin.digest executable)) "Session source role/fixed executable mismatch"
          val _=List.app(fn(expected,bytes)=>require(expected=digest bytes) "Session source slot integrity")
            [(#projection manifest,#projection material),(#sequent manifest,#sequent material),
             (#context_closure manifest,#context_closure material),(#payload manifest,#reconstruction material)]
          val metadata=Codec.decode_projection(#projection material)
          val payload=Codec.decode_payload(#reconstruction material)
          val _=Codec.check_graph metadata payload
          val _=require(#workspace metadata=I.workspace allocator andalso #workspace material= #workspace metadata andalso
            #association material= #utterance metadata andalso #semantic_generation material= #source_generation metadata)
            "Session source workspace/original input/native head association"
          val phase=case Checkpoint.matches committed metadata of SOME phase=>phase
            |NONE=>error "Session source does not match current exact original source row"
          val closure=Q.decode(#context_closure material)
          val _=require(#image closure=V.context_closure image andalso
            map #id(#sources closure)=Codec.graph_sources payload)
            "Session source image/exact native code-source closure mismatch"
          val lease=Thread_Attributes.with_attributes original(fn _=>G.acquire_graph graph allocator policy
            (V.context_closure image)committed(#graph payload))
          val _=context:=SOME lease
          val input=Inputs.acquire pool(Source_Check metadata)
          val _=source:=SOME input
          val _=G.checked lease
          val witness=Checked(Synchronized.var "checked_session_source"(Live
            {allocator=allocator,metadata=metadata,recorded= #recorded phase,source=input,context=lease}))
          val _=Synchronized.change roots(fn NONE=>error "Session source restore batch closed"
            |SOME prior=>(require(length prior<8192) "Session source restore object bound";SOME(witness::prior)))
          val _=installed:=true
        in witness end)()
    in case result of Exn.Res witness=>witness
      |Exn.Exn failure=>(if !installed then()else
        (Option.app Pool.release(!source);Option.app G.release(!context));Exn.reraise failure)end);
  fun fragment witness=Pool.fragment(#source(checked_data witness));
end;
