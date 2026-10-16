(* Closed historical resource restoration. Checkpoint is instantiated with the
   parent's generated original-request/acquired-source matcher, never a client
   callback. No executor, Scope, session, permit or charge is reconstructed. *)
functor Veri7vn_Native_Effect_Recovery
  (structure Checkpoint:sig
     val matches:Veri7vn_Committed_Native_Recovery.committed->Veri7vn_Native_Effect_Codec.projection->bool
   end
   val request_profile:Veri7vn_Recovery_Manifest.payload_profile
   val observation_profile:Veri7vn_Recovery_Manifest.payload_profile
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  structure View:sig
    type checked
    val projection:checked->Veri7vn_Native_Effect_Codec.projection
    val configuration:checked->Veri7vn_Native_Literals.input
    val packet:checked->Veri7vn_Native_Literals.input
    val response:checked->Veri7vn_Native_Literals.input option
    val generation:checked->Veri7vn_Native_Registry.generation
    val incarnation:checked->serial
    val retain:checked->checked val release:checked->unit
  end
  type batch
  val batch:Veri7vn_Native_Recovery_Check.image->Veri7vn_Native_Identity_Allocator.allocator->
    Veri7vn_Native_Recovery_Graph.batch->Veri7vn_Native_Recovery_Inputs.pool->batch
  val check:batch->Veri7vn_Committed_Native_Recovery.committed->View.checked
  val fragment:View.checked->Veri7vn_Native_Identity_Allocator.fragment
  val close:batch->unit
end =
struct
  structure Codec=Veri7vn_Native_Effect_Codec;
  structure Check=Veri7vn_Native_Effect_Observation;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure E=Veri7vn_Executable_Identity;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  fun require true _=()|require false message=error message;
  datatype source_check=Source_Check of {workspace:string,identity:IntInf.int,bytes:string,encoding:string};
  structure Inputs=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified=source_check
    fun binding(Source_Check binding)=binding
  end);
  type data={projection:Codec.projection,configuration:Pool.lease,packet:Pool.lease,
    response:Pool.lease option,context:G.lease,incarnation:serial};
  datatype state=Live of data|Releasing of data|Retry of data|Released;
  datatype checked=Checked of state Synchronized.var;
  fun checked_data(Checked cell)=
    let val data=case Synchronized.value cell of Live data=>data|_=>error "Effect historical owner unavailable/releasing"
      val _=ignore(Pool.input(#configuration data)) val _=ignore(Pool.input(#packet data))
      val _=Option.app(ignore o Pool.input)(#response data)
      val _=ignore(G.development(#context data))
    in data end;
  fun release_data(data:data)=
    (Option.app Pool.release(#response data);Pool.release(#packet data);Pool.release(#configuration data);G.release(#context data));
  fun release(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Synchronized.change_result cell(fn Live data=>(SOME data,Releasing data)
          |Retry data=>(SOME data,Releasing data)|state=>(NONE,state))
    in case owned of NONE=>()|SOME data=>
      (case Exn.capture release_data data of Exn.Res()=>Synchronized.change cell(K Released)
      |Exn.Exn failure=>(Synchronized.change cell(K(Retry data));Exn.reraise failure))end);
  fun retain(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result cell(fn Live(data:data)=>
      let val held=Unsynchronized.ref([]:Pool.lease list)
        val context=Unsynchronized.ref(NONE:G.lease option)
        fun keep source=let val copy=Pool.retain source in held:=copy:: !held;copy end
        val result=Exn.capture(fn()=>
          let val configuration=keep(#configuration data) val packet=keep(#packet data)
            val response=Option.map keep(#response data)
            val native=G.retain(#context data) val _=context:=SOME native
          in Checked(Synchronized.var "effect_historical_copy"(Live{projection= #projection data,
            configuration=configuration,packet=packet,response=response,context=native,incarnation=serial()}))end)()
      in case result of Exn.Res copy=>(copy,Live data)|Exn.Exn failure=>
        (List.app Pool.release(!held);Option.app G.release(!context);Exn.reraise failure)end
      |_=>error "Effect historical retain after release"));
  structure View=
  struct
    type checked=checked
    fun projection value= #projection(checked_data value)
    fun configuration value=Pool.input(#configuration(checked_data value))
    fun packet value=Pool.input(#packet(checked_data value))
    fun response value=Option.map Pool.input(#response(checked_data value))
    fun generation value=P.generation(G.development(#context(checked_data value)))
    fun incarnation value= #incarnation(checked_data value)
    val retain=retain val release=release
  end;
  datatype batch_roots=Open of checked list|Closing of checked list|RetryClose of checked list|Closed;
  datatype batch=Batch of {image:V.image,allocator:I.allocator,graph:G.batch,pool:Pool.pool,
    roots:batch_roots Synchronized.var};
  fun batch image allocator graph pool=
    (require(Pool.pool_workspace pool=I.workspace allocator andalso G.is_open graph andalso
      Context.subthy(E.code_theory executable,A.policy_theory(V.image_policy image)))
      "Effect recovery batch image/workspace mismatch";
     Batch{image=image,allocator=allocator,graph=graph,pool=pool,
       roots=Synchronized.var "effect_recovery_roots"(Open [])});
  fun check(Batch{image,allocator,graph,pool,roots}) committed=
    Thread_Attributes.uninterruptible_body(fn _=>
    let val material=C.materials committed
      val projection=Codec.decode(#projection material)
      val original=Codec.original projection
      val n= #names original
      val context=Codec.decode_context original(#context_closure material)
      val manifest=M.decode{max_bytes=16384}(#manifest material)
      val profile=case projection of Codec.Request _=>request_profile|Codec.Observation _=>observation_profile
      val association=case projection of Codec.Request _=> #request n|Codec.Observation{response,...}=>response
      val _=M.require_profile profile manifest
      val _=require(#workspace material=I.workspace allocator andalso #workspace original= #workspace material andalso
        #association material=association andalso #semantic_generation material= #generation n andalso
        #association manifest=association andalso #semantic_generation manifest= #generation n andalso
        #workspace manifest= #workspace material andalso #reconstruction manifest=M.Controlled_Recipe andalso
        #executable manifest=SOME(Veri7vn_Native_Recovery_Pin.digest executable) andalso
        #sequent material="" andalso
        #projection manifest=Codec.digest(#projection material) andalso #sequent manifest=Codec.digest "" andalso
        #context_closure manifest=Codec.digest(#context_closure material) andalso
        #payload manifest=Codec.digest(#reconstruction material)) "Effect committed material/role/pin mismatch"
      (* This call precedes every Pool/G acquisition. It checks the original
         invariant request fields/optional ledger or exact acquired association,
         never the live execution-context predicate for inert history. *)
      val _=require(Checkpoint.matches committed projection) "Effect material not required by exact current checkpoint"
      val _=require(#image context=V.context_closure image) "Effect installed native context image differs"
      val _=case #nodes(#graph context) of [{context_id,parents=[],construction=G.Public}]=>
          require(context_id= #generation n andalso #head(#graph context)=context_id)
            "Effect public graph semantic association mismatch"
        |_=>error "Effect historical recipe is not the fixed public native image"
      val _=case projection of Codec.Request _=>
          require(#reconstruction material="veri7vn-effect-request/2" andalso is_none(#witness context))
            "Effect request inert reconstruction differs"
        |Codec.Observation{epoch,rejected,receipt,schema,...}=>
          let val expected={workspace= #workspace original,attempt= #attempt n,request= #request n,
              capability= #capability n,operation= #operation original,configuration= #configuration original,
              configuration_epoch= #configuration_epoch original,configuration_source= #configuration_source original,
              packet_source= #packet_source original}:Check.expected
            val witness=case #witness context of SOME value=>value|NONE=>error "Effect response encoding witness absent"
            val checked=Check.check_record expected(#reconstruction material)witness
            val actual_rejected=case Check.representation_status checked of Check.RejectedResponse=>true|_=>false
          in require(actual_rejected=rejected andalso Check.representation_receipt checked=receipt andalso
            Check.representation_schema checked=schema andalso epoch>=0) "Effect response representation/projection differs"end
      val held=Unsynchronized.ref([]:Pool.lease list)
      val native=Unsynchronized.ref(NONE:G.lease option)
      val installed=Unsynchronized.ref false
      fun keep identity raw=let val lease=Inputs.acquire pool(Source_Check{workspace= #workspace original,
          identity=identity,encoding="UTF-8",bytes=raw})in held:=lease:: !held;lease end
      val result=Exn.capture(fn()=>
        let val configuration=keep(#configuration original)(#configuration(#originals context))
          val packet=keep(#packet original)(#packet(#originals context))
          val response=case projection of Codec.Request _=>NONE
            |Codec.Observation{response,...}=>SOME(keep response(#reconstruction material))
          val actual=G.acquire_graph graph allocator(V.image_policy image)(V.context_closure image)committed(#graph context)
          val _=native:=SOME actual val _=G.checked actual
          val witness=Checked(Synchronized.var "checked_effect_history"(Live{projection=projection,
            configuration=configuration,packet=packet,response=response,context=actual,incarnation=serial()}))
          val _=Synchronized.change roots(fn Open previous=>(require(length previous<8192)
            "Effect restore owner bound";Open(witness::previous))|_=>error "Effect restore batch closed")
          val _=installed:=true
        in witness end)()
    in case result of Exn.Res value=>value|Exn.Exn failure=>
      (if !installed then()else(List.app Pool.release(!held);Option.app G.release(!native));Exn.reraise failure)end);
  fun fragment value=
    let val data=checked_data value
    in I.combine_fragments(map Pool.fragment([#configuration data,#packet data]@the_list(#response data)))end;
  fun close(Batch{roots,...})=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Synchronized.change_result roots(fn Open previous=>(SOME previous,Closing previous)
          |RetryClose previous=>(SOME previous,Closing previous)|state=>(NONE,state))
    in case owned of NONE=>()|SOME previous=>
      (case Exn.capture(List.app release)previous of Exn.Res()=>Synchronized.change roots(K Closed)
      |Exn.Exn failure=>(Synchronized.change roots(K(RetryClose previous));Exn.reraise failure))end);
end;
