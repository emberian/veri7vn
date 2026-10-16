(* Fixed authenticated Scope reconstruction. Decoding remains inert; only this
   factory's private checked input can enter the shared physical source pool.
   The common checkpoint query establishes plan membership, while each family
   still validates its nested payload and exact requirement before publication. *)
structure Veri7vn_Native_Scope_Recovery :>
sig
  structure View:VERI7VN_CHECKED_REQUEST_SCOPE_VIEW
  type pins={math:Veri7vn_Executable_Identity.pin option,
    build:Veri7vn_Executable_Identity.pin option,
    initial:Veri7vn_Executable_Identity.pin option,
    update:Veri7vn_Executable_Identity.pin option,
    domain:Veri7vn_Executable_Identity.pin option,source_domain:Veri7vn_Executable_Identity.pin option,search:Veri7vn_Executable_Identity.pin option}
  type installation
  val install:Veri7vn_Native_Recovery_Check.image ->
    Veri7vn_Native_Installed_Roots.registry -> pins -> installation
  type batch
  val batch:installation -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Inputs.pool -> batch
  val check:batch -> Veri7vn_Committed_Native_Recovery.committed -> View.checked
  val fragment:View.checked -> Veri7vn_Native_Identity_Allocator.fragment
  val close:batch -> unit
end =
struct
  structure S=Veri7vn_Native_Scope_Saved;
  structure E=Veri7vn_Executable_Identity;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  structure Envelope=Veri7vn_Native_Scope_Envelope;
  type pins={math:E.pin option,build:E.pin option,initial:E.pin option,
    update:E.pin option,domain:E.pin option,source_domain:E.pin option,search:E.pin option};
  datatype installation=Installation of {image:V.image,policy:A.policy,roots:Veri7vn_Native_Installed_Roots.registry,pins:pins};
  fun require true _=()|require false message=error message;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun install image roots(pins:pins)=
    let val policy=V.image_policy image
      val _=List.app(fn pin=>require(Context.subthy(E.code_theory pin,A.policy_theory policy))
        "Scope producer is outside actual installed image")
        (maps the_list [#math pins,#build pins,#initial pins,#update pins,#domain pins,#source_domain pins,#search pins])
      val _=List.app(fn locator=>require(Context.subthy(A.policy_theory
        (Veri7vn_Native_Installed_Roots.policy roots locator),A.policy_theory policy))
        "Scope installed receiver is outside actual boot image")
        (Veri7vn_Native_Installed_Roots.locators roots)
    in Installation{image=image,policy=policy,roots=roots,pins=pins}end;
  fun role_pin(pins:pins)role=
    case (case role of M.MathRequest=> #math pins |M.BuildRequest=> #build pins
      |M.InitialQualificationRequest=> #initial pins |M.UpdateQualificationRequest=> #update pins
      |M.DomainRequest=> #domain pins |M.SourceDomainRequest=> #source_domain pins |M.SearchRequest=> #search pins |_=>NONE)of
      SOME pin=>pin|NONE=>error "Scoped request role has no fixed installed producer";
  datatype checked_input=Checked_Input of {workspace:string,source:S.source};
  structure Input=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified=checked_input
    fun binding(Checked_Input{workspace,source})=
      {workspace=workspace,identity= #identity source,bytes= #bytes source,encoding= #encoding source}
  end);
  type payload={saved:S.parent,required:S.required,policy:A.policy,parent_active:bool,
    leases:Pool.lease list};
  datatype status=Live of payload|Releasing of payload|Retry of payload|Released;
  datatype checked=Checked of status Synchronized.var;
  fun checked_data(Checked cell)=
    let val data=case Synchronized.value cell of Live data=>data
          |_=>error "Checked Scope witness released or releasing"
      val _=List.app(fn lease=>ignore(Pool.input lease))(#leases data)
    in data end;
  fun release(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Synchronized.change_result cell(fn Live p=>(SOME p,Releasing p)
          |Retry p=>(SOME p,Releasing p)|state=>(NONE,state))
    in case owned of NONE=>()|SOME data=>
      (case Exn.capture(fn()=>List.app Pool.release(#leases data))()of
        Exn.Res()=>Synchronized.change cell(K Released)
      |Exn.Exn failure=>(Synchronized.change cell(K(Retry data));Exn.reraise failure))end);
  fun retain(Checked cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result cell(fn Live(data:payload)=>
      let val owned=Unsynchronized.ref([]:Pool.lease list)
        val result=Exn.capture(fn()=>
          let val copies=map(fn lease=>let val copy=Pool.retain lease
                val _=owned:=copy:: !owned in copy end)(#leases data)
            val copy={saved= #saved data,required= #required data,policy= #policy data,
              parent_active= #parent_active data,leases=copies}:payload
          in Checked(Synchronized.var "checked_scope_owner"(Live copy))end)()
      in case result of Exn.Res copy=>(copy,Live data)
        |Exn.Exn failure=>(List.app Pool.release(!owned);Exn.reraise failure)end
    |_=>error "Checked Scope witness released or releasing"));
  structure View:VERI7VN_CHECKED_REQUEST_SCOPE_VIEW where type checked=checked =
  struct
    type checked=checked;
    fun saved witness= #saved(checked_data witness);
    fun required witness= #required(checked_data witness);
    fun sources witness=map(fn lease=>(Pool.identity lease,Pool.input lease)) (#leases(checked_data witness));
    fun policy witness= #policy(checked_data witness);
    fun parent_active witness= #parent_active(checked_data witness);
    val live=can checked_data;
    val retain=retain;
    val release=release;
  end;
  datatype batch=Batch of {installation:installation,allocator:I.allocator,pool:Pool.pool,
    roots:checked list option Synchronized.var};
  fun batch installation allocator pool=
    (require(Pool.pool_workspace pool=I.workspace allocator) "Scope recovery pool workspace";
     Batch{installation=installation,allocator=allocator,pool=pool,
       roots=Synchronized.var "scope_recovery_batch"(SOME [])});
  fun close(Batch{roots,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change roots(fn NONE=>NONE|SOME owned=>(List.app release owned;NONE)));
  fun check(Batch{installation=Installation{image,policy=boot_policy,roots=installed_roots,pins},allocator,pool,roots})committed=
    let val material=C.materials committed
      val manifest=M.decode{max_bytes=8192}(#manifest material)
      val pin=role_pin pins(#profile manifest)
      val sequent_shape=case #profile manifest of M.MathRequest=> #sequent material<>""
        |_=> #sequent material=""
      val _=require(#reconstruction manifest=M.Controlled_Recipe andalso sequent_shape andalso
        #executable manifest=SOME(Pin.digest pin)) "Scope role/fixed executable mismatch"
      val _=List.app(fn(expected,bytes)=>require(expected=digest bytes) "Scope role slot integrity")
        [(#projection manifest,#projection material),(#sequent manifest,#sequent material),
         (#context_closure manifest,#context_closure material),(#payload manifest,#reconstruction material)]
      val packet=Envelope.decode(#context_closure material)
      val policy=case #receiver packet of Envelope.Boot=>boot_policy
        |Envelope.Installed locator=>Veri7vn_Native_Installed_Roots.policy installed_roots locator
      val saved= #saved packet
      val required= #required packet
      val _=require(#workspace saved=I.workspace allocator andalso #workspace material= #workspace saved andalso
        #image packet=V.context_closure image andalso #executable packet=Pin.material pin)
        "Scope original workspace/image/code correspondence"
      val _=require(exists(fn(_,slot)=>slot= #association material)required)
        "Scoped material association is not a required child slot"
      val _=require(Veri7vn_Native_Scope_Checkpoint.matches(#checkpoint material)saved required)
        "Scope original plan/current required subset does not match authenticated checkpoint"
      val parent_active=Veri7vn_Native_Scope_Checkpoint.parent_active(#checkpoint material)saved
      (* Only a bounded native lifetime transfer is masked. All parsing, hashes,
         image checks and the generated checkpoint query have already finished. *)
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val acquired=Unsynchronized.ref([]:Pool.lease list)
        val result=Exn.capture(fn()=>Synchronized.change_result roots(fn NONE=>error "Scope recovery batch closed"
          |SOME old=>
            let val leases=map(fn source=>let val lease=Input.acquire pool
                  (Checked_Input{workspace= #workspace saved,source=source})
                  val _=acquired:=lease:: !acquired in lease end)(#sources saved)
              val witness=Checked(Synchronized.var "checked_scope_owner"(Live
                {saved=saved,required=required,policy=policy,parent_active=parent_active,leases=leases}))
            in(witness,SOME(witness::old))end))()
      in case result of Exn.Res witness=>witness
        |Exn.Exn failure=>(List.app Pool.release(!acquired);Exn.reraise failure)end)end;
  fun fragment witness=I.combine_fragments(map Pool.fragment(#leases(checked_data witness)));
end;
