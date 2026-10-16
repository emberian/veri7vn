(* Fixed package source transfer. Metadata is an inert original-source association;
   only the service's governed host bridge may open a transfer. Finish invokes the
   ONE installed PackageModel parser on its OWN retained descriptor bytes. It never
   accepts parsed export names in the public transfer protocol. No source ML runs. *)
signature VERI7VN_NATIVE_PACKAGE_INPUTS =
sig
  type pool
  type transfer
  type prepared_input
  datatype part=Descriptor | Theory
  type metadata={upload_nonce:string,revision:string,manifest:string,descriptor_path:string,theory_path:string,
    descriptor_size:int,theory_size:int,descriptor_sha256:string,theory_sha256:string,
    parents:IntInf.int list}
  type expectation={package_id:string,package_version:string,session:string,
    theories:string list,files:(string * string) list,dependencies:(string * string) list,
    capabilities:Veri7vn_Native_Export_Intent.capability list}
  type binding={metadata:metadata,expectation:expectation,
    descriptor_source:Veri7vn_Managed_Provenance.source_owner,
    descriptor_slice:Veri7vn_Native_Literals.slice,
    theory_source:Veri7vn_Managed_Provenance.source_owner,
    theory_slice:Veri7vn_Native_Literals.slice,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int}
  val encode_metadata:metadata -> string
  val decode_metadata:string -> metadata
  val interpret_descriptor:Veri7vn_Managed_Provenance.source_owner ->
    Veri7vn_Native_Literals.slice -> expectation
  val create:Veri7vn_Native_Identity_Allocator.allocator -> pool
  val begin_input:pool -> string -> transfer
  val invalidate_sources:prepared_input -> IntInf.int list -> bool
  val forget_sources:prepared_input -> IntInf.int list -> bool
  val restored_plan:prepared_input -> Veri7vn_Native_Deferred_Build_Types.plan option
  val transfer_metadata:transfer -> metadata
  val transfer_key:transfer -> int
  val discard_nonce:pool -> string -> unit
  val accept_nonce:pool -> string -> prepared_input
  val settle_nonce:pool -> string -> unit
  val write:transfer -> part -> int -> Bytes.T -> unit
  val abort:transfer -> unit
  val discard:transfer -> unit
  val close:pool -> unit
  val finish_owned:Veri7vn_Managed_Provenance.construction_scope -> transfer -> prepared_input
  val binding:prepared_input -> binding
  val owner_key:prepared_input -> int
  val is_live:prepared_input -> bool
  val retain_owned:Veri7vn_Managed_Provenance.construction_scope -> prepared_input -> prepared_input
  val release:prepared_input -> unit
  val intent_owned:Veri7vn_Managed_Provenance.construction_scope -> prepared_input ->
    Veri7vn_Native_Export_Intent.intent
end;
(* Fixed trusted module load only. The final shadow seal below removes this
   construction structure's name after the fixed recovery functor has captured
   it. A failed ML_file load must prevent resident startup. *)
structure Veri7vn_Package_Inputs_Load_Private =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Intent=Veri7vn_Native_Export_Intent;
  datatype part=Descriptor | Theory;
  type metadata=Veri7vn_Native_Package_Input_Types.metadata;
  type expectation=Veri7vn_Native_Package_Input_Types.expectation;
  type binding=Veri7vn_Native_Package_Input_Types.binding;
  type buffers={descriptor:Word8Array.array,theory:Word8Array.array,descriptor_offset:int,theory_offset:int,finishing:bool};
  datatype pool=Pool of {allocator:I.allocator,open_pool:bool Synchronized.var,
    transfers:transfer list Synchronized.var,abandoned:string list Synchronized.var}
  and transfer=Transfer of {identity:serial,pool:pool,metadata:metadata,payload:buffers option Synchronized.var,
    publication:{cancelled:bool,accepted:bool,published:prepared_input option} Synchronized.var}
  and prepared_input=Prepared of {identity:serial,payload:{binding:binding,descriptor_lease:L.lease,
    theory_lease:L.lease,original_intent:Intent.intent option,
    restored_plan:Veri7vn_Native_Deferred_Build_Types.plan option}option Synchronized.var};
  open Veri7vn_Native_Package_Input_Types;
  val decode_header=decode_metadata;
  fun locator a:Intent.locator=(exact["theory","name"]a;
    require(bounded(attr a "theory") andalso bounded(attr a "name")) "Package locator bound";
    {theory=attr a "theory",name=attr a "name"});
  fun decode_expectation raw:expectation=
    let val _=require(size raw<=65536) "Package descriptor adapter result bound"
      val (a,children)=case YXML.parse_body raw of
        [XML.Elem(("package-descriptor",a),c)]=>(a,c) | _=>error "Package descriptor adapter shape"
      val _=exact["version","id","package_version","session"]a
      val _=require(attr a "version"="1" andalso bounded(attr a "id") andalso
        bounded(attr a "package_version") andalso size(attr a "session")<=4096)
        "Package descriptor adapter metadata"
      fun decode_export (XML.Elem(("export",a),children))=
        let val _=exact["id"]a
          val _=require(bounded(attr a "id")) "Package export ID"
          val (spec,tail)=case children of XML.Elem(("specification",p),[])::tail=>(locator p,tail)
            | _=>error "Package export specification"
          fun contracts (XML.Elem(("contract",p),[])::rest) acc=contracts rest (locator p::acc)
            | contracts rest acc=(rev acc,rest)
          val (contracts,tail)=contracts tail []
          val executable=case tail of []=>NONE
            | [XML.Elem(("executable",p),[])]=>SOME(locator p)
            | _=>error "Package export executable"
        in {id=attr a "id",specification=spec,contracts=contracts,executable=executable}:Intent.capability end
        | decode_export _=error "Package export shape"
      fun split tag (node as XML.Elem((name,_),_))=name=tag | split _ _=false
      fun prefix predicate nodes=
        let val head=take_prefix predicate nodes in(head,drop(length head)nodes)end
      val (theory_nodes,tail)=prefix(split "theory")children
      val (file_nodes,tail)=prefix(split "file")tail
      val (dependency_nodes,export_nodes)=prefix(split "dependency")tail
      val theories=map(fn XML.Elem((_,a),[])=>
          (exact["name"]a;require(bounded(attr a "name")) "Package theory name";attr a "name")
        | _=>error "Package theory shape")theory_nodes
      val files=map(fn XML.Elem((_,a),[])=>
          (exact["path","role"]a;require(portable(attr a "path") andalso
            member(op =)["source","example","documentation","data"] (attr a "role"))
            "Package file entry";(attr a "path",attr a "role"))
        | _=>error "Package file shape")file_nodes
      val dependencies=map(fn XML.Elem((_,a),[])=>
          (exact["id","version"]a;require(bounded(attr a "id") andalso bounded(attr a "version"))
            "Package dependency entry";(attr a "id",attr a "version"))
        | _=>error "Package dependency shape")dependency_nodes
      val capabilities=map decode_export export_nodes
      val _=require(length theories<=256 andalso length files<=2048 andalso length dependencies<=256
        andalso length capabilities<=256 andalso length(distinct(op =)theories)=length theories
        andalso length(distinct(op =)(map #1 files))=length files andalso
        length(distinct(op =)(map #1 dependencies))=length dependencies andalso
        length(distinct(op =)(map #id capabilities))=length capabilities) "Package descriptor collection bounds"
    in {package_id=attr a "id",package_version=attr a "package_version",session=attr a "session",
      theories=theories,files=files,dependencies=dependencies,capabilities=capabilities}end;
  fun interpret_descriptor source slice=
    (require(P.owns_input source(L.owner slice) andalso L.retained(L.owner slice) andalso
      L.encoding(L.owner slice)="UTF-8" andalso size(L.original slice)<=1000000)
      "Descriptor interpretation source ownership/bounds";
     decode_expectation(Bytes.content(Scala.function1_bytes "veri7vn.package_descriptor_v1"
       (Bytes.string(L.original slice)))));
  fun create allocator=Pool{allocator=allocator,open_pool=Synchronized.var "package_input_pool" true,
    transfers=Synchronized.var "package_input_transfers" [],abandoned=Synchronized.var "package_input_abandoned" []};
  fun prepared_data(Prepared{payload,...})=case Synchronized.value payload of SOME data=>data
    |NONE=>error "Package input released";
  fun release_prepared(Prepared{payload,...})=Synchronized.change payload(fn NONE=>NONE
    |SOME data=>(Option.app Intent.release(#original_intent data);
      List.app(fn lease=>Option.app I.release_disposed_input(L.release lease))
        [#descriptor_lease data,#theory_lease data];NONE));
  fun wipe (buffers:buffers)=(Word8Array.modify(K 0w0)(#descriptor buffers);
    Word8Array.modify(K 0w0)(#theory buffers));
  fun wipe_stage(Transfer{payload,...})=Synchronized.change payload(fn current=>
    (Option.app wipe current;NONE));
  fun discard(transfer as Transfer{publication,...})=
    let val published=Synchronized.change_result publication(fn state as {accepted,published,...}=>
        if accepted then(NONE,state) else(published,{cancelled=true,accepted=false,published=published}))
      val _=Option.app release_prepared published
      val _=Synchronized.change publication(fn state as {accepted,...}=>
        if accepted then state else {cancelled=true,accepted=false,published=NONE})
    in wipe_stage transfer end;
  (* Legacy transfer abort is harmless after finish. Discard additionally drops
     a completed producer lease to reconcile an unknown/lost finish reply. *)
  fun abort(transfer as Transfer{publication,...})=
    let val _=Synchronized.change publication(fn state as {published,...}=>
        if is_some published then state else {cancelled=true,accepted=false,published=NONE})
    in wipe_stage transfer end;
  fun close(Pool{open_pool,transfers,abandoned,...})=
    (Synchronized.change open_pool(K false);List.app discard(Synchronized.value transfers);
     Synchronized.change transfers(K []);Synchronized.change abandoned(K []));
  fun transfer_metadata(Transfer{metadata,...})=metadata;
  fun transfer_key(Transfer{identity,...})=identity;
  fun discard_nonce(pool as Pool{transfers,abandoned,...}) key=
    let val _=require(nonce key) "Package input correlation nonce"
      val _=Synchronized.change abandoned(fn old=>if member(op =)old key then old
        else (require(length old<2) "Unsettled package input cancellation bound";key::old))
      val matching=filter(fn Transfer{metadata,...}=> #upload_nonce metadata=key)(Synchronized.value transfers)
    in List.app discard matching end;
  fun accept_nonce(Pool{transfers,abandoned,...}) key=
    let val _=require(nonce key andalso not(member(op =)(Synchronized.value abandoned)key))
        "Package input correlation already discarded"
      val transfer=the(find_first(fn Transfer{metadata,...}=> #upload_nonce metadata=key)
        (Synchronized.value transfers))
      val Transfer{publication,...}=transfer
    in Synchronized.change_result publication(fn {cancelled,accepted,published}=>
      let val _=require(not cancelled) "Package input discarded before acceptance"
        val prepared=the published
        val {descriptor_lease,theory_lease,...}=prepared_data prepared
        val _=require(can L.lease_input descriptor_lease andalso
          can L.lease_input theory_lease) "Package input producer released"
      in(prepared,{cancelled=false,accepted=true,published=published})end)end;
  (* Sole caller is the fixed host after its actual transfer worker joined AND
     the accept/discard/release control reply passed its FIFO transport barrier. *)
  fun settle_nonce(Pool{transfers,abandoned,...}) key=
    let val _=require(nonce key) "Package input settlement nonce"
      val _=Synchronized.change transfers(fn old=>
        let val matching=filter(fn Transfer{metadata,...}=> #upload_nonce metadata=key)old
          val _=List.app(fn Transfer{publication,...}=>
            let val {cancelled,accepted,...}=Synchronized.value publication
            in require(cancelled orelse accepted) "Package input correlation not terminal" end)matching
        in filter(fn Transfer{metadata,...}=> #upload_nonce metadata<>key)old end)
    in Synchronized.change abandoned(remove(op =)key)end;
  fun begin_input(pool as Pool{open_pool,transfers,abandoned,...}) raw=
    let val metadata=decode_header raw
    in Thread_Attributes.uninterruptible_body(fn _=>
      Synchronized.change_result transfers(fn old=>
        let val _=require(Synchronized.value open_pool andalso
            not(member(op =)(Synchronized.value abandoned)(#upload_nonce metadata)))
            "Package input pool closed or nonce abandoned"
        in case find_first(fn Transfer{metadata=prior,...}=> #upload_nonce prior= #upload_nonce metadata)old of
          SOME(existing as Transfer{metadata=prior,publication,...})=>
            (require(prior=metadata andalso not(#cancelled(Synchronized.value publication)))
               "Conflicting or discarded package input nonce";(existing,old))
        | NONE=>let val live=filter(fn Transfer{payload,...}=>is_some(Synchronized.value payload))old
            val _=require(length live<2 andalso length old<66) "Package input transfer/correlation bound"
            val buffers={descriptor=Word8Array.array(#descriptor_size metadata,0w0),
              theory=Word8Array.array(#theory_size metadata,0w0),descriptor_offset=0,theory_offset=0,finishing=false}
            val transfer=Transfer{identity=serial(),pool=pool,metadata=metadata,
              payload=Synchronized.var "package_input_transfer" (SOME buffers),
              publication=Synchronized.var "package_input_publication" {cancelled=false,accepted=false,published=NONE}}
          in(transfer,transfer::old)end end))end;
  fun write(Transfer{pool=Pool{open_pool,...},payload,...}) part offset chunk=
    (require(Bytes.size chunk>0 andalso Bytes.size chunk<=65536) "Package input chunk bound";
     Synchronized.change payload(fn current=>
      let val b=the current
        val _=require(Synchronized.value open_pool andalso not(#finishing b)) "Package input transfer not writable"
        val array=case part of Descriptor=> #descriptor b | Theory=> #theory b
        val expected=case part of Descriptor=> #descriptor_offset b | Theory=> #theory_offset b
        val _=require(offset=expected andalso Bytes.size chunk<=Word8Array.length array-offset)
          "Package input contiguous chunk"
        val raw=Bytes.content chunk
        val _=CharVector.appi(fn(i,c)=>Word8Array.update(array,offset+i,Word8.fromInt(Char.ord c)))raw
      in SOME{descriptor= #descriptor b,theory= #theory b,
        descriptor_offset=if part=Descriptor then offset+size raw else #descriptor_offset b,
        theory_offset=if part=Theory then offset+size raw else #theory_offset b,finishing=false}end));
  fun is_live(Prepared{payload,...})=case Synchronized.value payload of NONE=>false
    |SOME{binding={descriptor_source,theory_source,...},descriptor_lease,theory_lease,original_intent,...}=>
      can L.lease_input descriptor_lease andalso can L.lease_input theory_lease andalso
      L.retained(P.source_input descriptor_source) andalso L.retained(P.source_input theory_source) andalso
      forall Intent.is_live(the_list original_intent);
  fun owner_key(p as Prepared{identity,...})=(require(is_live p) "Package input released";identity);
  fun binding p=(require(is_live p) "Package input released";#binding(prepared_data p));
  fun restored_plan input=(ignore(binding input);#restored_plan(prepared_data input));
  fun source_action action(Prepared{payload,...})ids=
    case Synchronized.value payload of NONE=>false|SOME{binding,...}=>
      let val sources=filter(fn source=>member(op =)ids(P.source_identity source))
            [#descriptor_source binding,#theory_source binding]
        val _=List.app(fn source=>action(P.source_input source))sources
      in not(null sources)end;
  val invalidate_sources=source_action L.invalidate;
  val forget_sources=source_action L.forget_input;
  val release=release_prepared;
  fun own_input scope allocator raw=Thread_Attributes.uninterruptible_body(fn _=>
    let val input=L.input{bytes=raw,encoding="UTF-8"}
      val result=Exn.capture(fn()=>let val source=P.install_host_source allocator input
        val slice=L.slice input{start=0,stop=size raw,expected=raw}
        val lease=P.retain_source_owned scope source
        val _=Option.app I.release_disposed_input(L.drop_base input)
      in(source,slice,lease)end)()
    in case result of Exn.Res value=>value | Exn.Exn failure=>
      (L.forget_input input;if L.disposed input then I.release_disposed_input input else ();Exn.reraise failure)end);
  fun finish_owned scope (transfer as Transfer{pool=Pool{allocator,open_pool,...},metadata,payload,publication,...})=
    (case Synchronized.value publication of {cancelled=false,published=SOME prepared,...}=>
      (require(is_live prepared) "Package input producer released";prepared)
    | _=>let val outcome=Exn.capture(fn()=>
      let val (descriptor,theory)=Synchronized.change_result payload(fn current=>
      let val b=the current
        val _=require(Synchronized.value open_pool andalso not(#finishing b) andalso
          #descriptor_offset b= #descriptor_size metadata andalso #theory_offset b= #theory_size metadata)
          "Package input incomplete"
        fun content array=Byte.bytesToString(Word8Array.vector array)
      in ((content(#descriptor b),content(#theory b)),SOME{descriptor= #descriptor b,theory= #theory b,
        descriptor_offset= #descriptor_offset b,theory_offset= #theory_offset b,finishing=true})end)
          val hash=Message_Digest.rep o SHA256.digest
          val _=require(hash descriptor= #descriptor_sha256 metadata andalso hash theory= #theory_sha256 metadata)
            "Package original source hash mismatch"
          (* This is an explicit trusted host metadata adapter, never C02 evidence. *)
          val (descriptor_source,descriptor_slice,descriptor_lease)=own_input scope allocator descriptor
          val expectation=interpret_descriptor descriptor_source descriptor_slice
          val _=require(member(op =)(#files expectation)(#theory_path metadata,"source") andalso
            #session expectation<>"" andalso member(op =)(#theories expectation)
              (#1(#name(Thy_Header.read Position.none theory)))) "Package selected native theory not declared"
          val (theory_source,theory_slice,theory_lease)=own_input scope allocator theory
        in Thread_Attributes.uninterruptible_body(fn _=>
          Synchronized.change_result publication(fn {cancelled,accepted,published}=>
          let val _=require(not cancelled andalso is_none published andalso
              Synchronized.value open_pool andalso is_some(Synchronized.value payload))
              "Package input canceled during interpretation"
            val revision_id=I.allocate allocator
            val manifest_id=I.allocate allocator
            val intent_id=I.allocate allocator
            val data={metadata=metadata,expectation=expectation,descriptor_source=descriptor_source,
              descriptor_slice=descriptor_slice,theory_source=theory_source,theory_slice=theory_slice,
              source_revision=revision_id,manifest=manifest_id,export_intent=intent_id}:binding
            val prepared=Prepared{identity=serial(),payload=Synchronized.var "prepared_package_input"
              (SOME{binding=data,descriptor_lease=descriptor_lease,theory_lease=theory_lease,
                original_intent=NONE,restored_plan=NONE})}
          in (prepared,{cancelled=false,accepted=false,published=SOME prepared})end))end)()
      val _=Thread_Attributes.uninterruptible_body(fn _=>wipe_stage transfer)
    in Exn.release outcome end);
  fun retain_owned scope(original as Prepared{identity,payload})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result payload(fn current=>
      let val data=case current of SOME data=>data|NONE=>error "Package input released"
        val binding= #binding data
        val descriptor_lease=P.retain_source_owned scope (#descriptor_source binding)
        val theory_lease=P.retain_source_owned scope (#theory_source binding)
        val intent=Option.map(Intent.retain_owned scope)(#original_intent data)
        val retained=Prepared{identity=identity,payload=Synchronized.var "retained_package_input"
          (SOME{binding=binding,descriptor_lease=descriptor_lease,theory_lease=theory_lease,
            original_intent=intent,restored_plan= #restored_plan data})}
      in(retained,current)end));
  fun intent_owned scope(original as Prepared{payload,...})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result payload(fn current=>
      let val data=case current of SOME data=>data|NONE=>error "Package input released"
        val b= #binding data
        val intent=case #original_intent data of SOME intent=>Intent.retain_owned scope intent
          |NONE=>Intent.capture_owned scope{source= #descriptor_source b,slice= #descriptor_slice b,
            source_revision= #source_revision b,manifest= #manifest b,export_intent= #export_intent b,
            capabilities= #capabilities(#expectation b)}
      in(intent,current)end));
  (* Lexically private: only the fixed authenticated deferred checker below may
     adopt restored sources. This is not part of the public Inputs signature. *)
  fun adopt_restored_owned scope {binding=data:binding,original_intent,plan}=
    Thread_Attributes.uninterruptible_body(fn _=>
    let val expected=Intent.binding original_intent
      val metadata= #metadata data
      val _=ignore(encode_metadata metadata)
      fun pinned slice expected_size expected_digest=
        let val bytes=L.original slice
        in L.encoding(L.owner slice)="UTF-8" andalso size bytes=expected_size andalso
          Message_Digest.rep(SHA256.digest bytes)=expected_digest end
      val _=require(pinned(#descriptor_slice data)(#descriptor_size metadata)(#descriptor_sha256 metadata)
        andalso pinned(#theory_slice data)(#theory_size metadata)(#theory_sha256 metadata)
        andalso forall(fn id=>id>0)[#source_revision data,#manifest data,#export_intent data])
        "Restored input bytes differ from original metadata"
      val _=require(P.owns_input(#descriptor_source data)(L.owner(#descriptor_slice data)) andalso
        P.owns_input(#theory_source data)(L.owner(#theory_slice data)) andalso
        L.same_input(P.source_input(#source expected),P.source_input(#descriptor_source data)) andalso
        L.offsets(#slice expected)=L.offsets(#descriptor_slice data) andalso
        #source_revision expected= #source_revision data andalso #manifest expected= #manifest data andalso
        #export_intent expected= #export_intent data andalso
        #capabilities expected= #capabilities(#expectation data)) "Restored input/original intent mismatch"
      val descriptor_lease=P.retain_source_owned scope (#descriptor_source data)
      val theory_lease=P.retain_source_owned scope (#theory_source data)
      val intent=Intent.retain_owned scope original_intent
    in Prepared{identity=serial(),payload=Synchronized.var "restored_package_input"
      (SOME{binding=data,descriptor_lease=descriptor_lease,theory_lease=theory_lease,
        original_intent=SOME intent,restored_plan=SOME plan})}end);
end;
structure Veri7vn_Native_Package_Inputs :> VERI7VN_NATIVE_PACKAGE_INPUTS
  where type prepared_input=Veri7vn_Package_Inputs_Load_Private.prepared_input =
    Veri7vn_Package_Inputs_Load_Private;
(* FIXED_DEFERRED_RECOVERY_INSERTION: only this lexical region may use Veri7vn_Package_Inputs_Load_Private.adopt_restored_owned. *)
(* Fixed lexical deferred checker. The private input constructor is captured
   here; neither a raw saved-ID setter nor a caller-supplied validation guard is
   exported. Historical source ownership confers no dispatch permission. *)
functor Veri7vn_Native_Deferred_Build_Recovery
  (structure Checkpoint:sig
     val matches:Veri7vn_Committed_Native_Recovery.committed ->
       Veri7vn_Native_Deferred_Build_Types.plan -> bool
   end
   structure Known:sig
     type lease
     val lookup:IntInf.int -> lease option
     val candidate:lease -> IntInf.int
     val assigned_slot:lease -> IntInf.int
     val context:lease -> IntInf.int
     val development:lease -> Veri7vn_Managed_Provenance.development
     val is_live:lease -> bool
     val retain:lease -> lease
     val release:lease -> unit
   end
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  type checked type batch type installation
  type configuration={image:Veri7vn_Native_Recovery_Check.image,
    roots:Veri7vn_Native_Installed_Roots.registry,
    operation_generation:Veri7vn_Native_Registry.generation,
    template:IntInf.int,profile:IntInf.int,setup:IntInf.int,capability:IntInf.int,
    operation:IntInf.int,code_generation:IntInf.int,step:IntInf.int}
  val install:configuration -> installation
  val batch:installation -> Veri7vn_Native_Recovery_Graph.batch -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Inputs.pool -> batch
  val check:batch -> Veri7vn_Committed_Native_Recovery.committed -> checked
  val plan:checked -> Veri7vn_Native_Deferred_Build_Types.plan
  val input:checked -> Veri7vn_Native_Package_Inputs.prepared_input
  val operation_generation:checked -> Veri7vn_Native_Registry.generation
  val original_intent:checked -> Veri7vn_Native_Export_Intent.intent
  val known_parents:checked -> (string * Known.lease) list
  val scope:checked -> Veri7vn_Native_Scope_Recovery.View.checked
  val fragment:checked -> Veri7vn_Native_Identity_Allocator.fragment
  val validate_registered:checked -> unit
  val scope_adopted:checked -> Veri7vn_Native_Request_Scope.child -> unit
  val retain:checked -> checked
  val release:checked -> unit
  val close:batch -> unit
  val marker:string
  val source_ids:Veri7vn_Native_Deferred_Build_Types.plan -> IntInf.int list
end =
struct
  structure T=Veri7vn_Native_Deferred_Build_Types;
  structure Wire=Veri7vn_Native_Deferred_Build_Codec;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure R=Veri7vn_Native_Registry;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure Scope=Veri7vn_Native_Scope_Recovery;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  structure Claim=Veri7vn_Native_Release_Claim;
  type configuration={image:V.image,roots:Veri7vn_Native_Installed_Roots.registry,
    operation_generation:R.generation,template:IntInf.int,profile:IntInf.int,setup:IntInf.int,
    capability:IntInf.int,operation:IntInf.int,code_generation:IntInf.int,step:IntInf.int};
  datatype installation=Installation of {configuration:configuration,scope:Scope.installation};
  fun require true _=()|require false message=error message;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  fun install(c:configuration)=
    let val policy=V.image_policy(#image c)
      val _=require(Context.eq_thy(Proof_Context.theory_of(R.context(#operation_generation c)),
          A.policy_theory policy)) "Deferred fixed native operation context differs from installed boot"
      val scope=Scope.install(#image c)(#roots c){math=NONE,build=SOME executable,
        initial=NONE,update=NONE,domain=NONE,source_domain=NONE,search=NONE}
    in Installation{configuration=c,scope=scope}end;
  val marker="veri7vn-deferred-build-source/1";
  fun source_ids(p:T.plan)=distinct(op =)[#source_owner(#source p),#descriptor_source(#source p)];
  type payload={allocator:I.allocator,configuration:configuration,operation:G.lease,plan:T.plan,
    input:Veri7vn_Package_Inputs_Load_Private.prepared_input,intent:Intent.intent,known:(string*Known.lease)list,
    scope:Scope.View.checked option Synchronized.var,sources:Q.batch};
  datatype group_state=Open of int*payload|Closing of payload|RetryCleanup of payload|Closed;
  datatype group=Group of group_state Synchronized.var;
  datatype checked=Checked of {group:group,active:Claim.owner};
  fun group_data(Group cell)=
    let val p=case Synchronized.value cell of Open(_,p)=>p|_=>error "Deferred source owner retired or releasing"
      val _=require(Veri7vn_Package_Inputs_Load_Private.is_live(#input p) andalso Intent.is_live(#intent p) andalso
        forall(Known.is_live o snd)(#known p)) "Deferred source or known parent unavailable"
    in p end;
  fun data(Checked{group,active})=
    (require(Claim.is_live active) "Deferred checked source released or releasing";group_data group);
  fun drop_scope(p:payload)=Synchronized.change(#scope p)
    (fn NONE=>NONE|SOME checked=>(Scope.View.release checked;NONE));
  fun release(Checked{group=Group cell,active})=Thread_Attributes.uninterruptible_body(fn _=>
    case Claim.try_claim active of NONE=>
      require(Claim.is_done active) "Deferred cleanup is already in progress; retry disposal"
    |SOME claim=>
      let fun run()=
        let val action=Synchronized.change_result cell
          (fn Open(n,p)=>if n>1 then(NONE,Open(n-1,p))else(SOME p,Closing p)
            |RetryCleanup p=>(SOME p,Closing p)|Closed=>(NONE,Closed)
            |Closing _=>error "Deferred cleanup already claimed by another handle")
          val _=case action of NONE=>()|SOME p=>
            (drop_scope p;Veri7vn_Package_Inputs_Load_Private.release(#input p);Intent.release(#intent p);
             List.app(Known.release o snd)(#known p);G.release(#operation p);Q.release(#sources p);
             Synchronized.change cell(K Closed))
        in Claim.finish claim end
      in case Exn.capture run()of Exn.Res()=>()|Exn.Exn failure=>
        (Synchronized.change cell(fn Closing p=>RetryCleanup p|state=>state);
         Claim.retry claim;Exn.reraise failure)end);
  fun retain(Checked{group=group as Group cell,active})=Thread_Attributes.uninterruptible_body(fn _=>
    Claim.with_live active(fn()=>
      let val _=ignore(group_data group)
        val _=Synchronized.change cell(fn Open(n,p)=>Open(n+1,p)|_=>error "Deferred source releasing")
      in Checked{group=group,active=Claim.create()}end));
  fun plan c= #plan(data c);
  fun input c= #input(data c);
  fun operation_generation c=P.generation(G.development(#operation(data c)));
  fun original_intent c= #intent(data c);
  fun known_parents c= #known(data c);
  fun scope c=case Synchronized.value(#scope(data c))of SOME checked=>checked
    |NONE=>error "Deferred Scope source payload already transferred";

  (* Native context bindings are sealed once by the aggregate graph batch. *)
  fun fragment c=I.combine_fragments[Q.fragment(#sources(data c)),Scope.fragment(scope c)];
  fun validate_registered c=
    let val p=data c val m= #plan p val ids= #allocator p val binding=Veri7vn_Package_Inputs_Load_Private.binding(#input p)
      val _=require(I.lookup_generation_id ids(P.generation(G.development(#operation p)))=SOME(#operation_generation m) andalso
        I.lookup_input_identity ids(P.source_input(#theory_source binding))=SOME(#source_owner(#source m)) andalso
        I.lookup_input_identity ids(P.source_input(#descriptor_source binding))=SOME(#descriptor_source(#source m)))
        "Deferred source/context identities have not been atomically registered"
      val _=List.app(fn(_,lease)=>require(P.development_live(Known.development lease) andalso
        I.lookup_generation_id ids(P.generation(Known.development lease))=SOME(Known.context lease))
        "Deferred known native parent not registered") (#known p)
    in()end;
  fun scope_adopted c child=
    let val _=validate_registered c
      val p=data c val m= #plan p val id=Veri7vn_Native_Request_Scope.identity child
      val _=require(#request id= #request m andalso #goal id= #goal m andalso #slot id= #slot m andalso
        #interpretation id= #interpretation m andalso #decision id= #decision m andalso
        I.workspace(Veri7vn_Native_Request_Scope.allocator(Veri7vn_Native_Request_Scope.parent child))= #workspace m)
        "Deferred Scope publication is not its actual restored original child"
    in drop_scope p end;
  datatype batch=Batch of {installation:installation,allocator:I.allocator,
    pool:Veri7vn_Native_Recovery_Inputs.pool,scope:Scope.batch,
    graph:G.batch,roots:checked list option Synchronized.var};
  fun batch(installation as Installation{scope,configuration,...}) graph allocator pool=
    (require(G.uses_roots graph(#roots configuration)) "Deferred graph installed roots differ";
    Batch{installation=installation,allocator=allocator,pool=pool,scope=Scope.batch scope allocator pool,
      graph=graph,
      roots=Synchronized.var "deferred_source_roots"(SOME [])});
  fun close(Batch{roots,scope,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change roots(fn NONE=>NONE|SOME owned=>(List.app release owned;Scope.close scope;NONE)));
  fun check(Batch{installation=Installation{configuration,...},allocator,pool,scope=scope_batch,graph,roots})committed=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let val sources=Q.batch_with pool val construction=P.construction_scope()
      val owned_scope=Unsynchronized.ref(NONE:Scope.View.checked option)
      val owned_intent=Unsynchronized.ref(NONE:Intent.intent option)
      val owned_input=Unsynchronized.ref(NONE:Veri7vn_Package_Inputs_Load_Private.prepared_input option)
      val owned_operation=Unsynchronized.ref(NONE:G.lease option)
      val owned_known=Unsynchronized.ref([]:(string*Known.lease)list)
      val published=Unsynchronized.ref false
      fun run()=
        let val material=C.materials committed val manifest=M.decode{max_bytes=8192}(#manifest material)
          val _=M.require_profile M.BuildRequest manifest
          val _=require(#reconstruction manifest=M.Controlled_Recipe andalso #sequent material="" andalso
            #executable manifest=SOME(Pin.digest executable) andalso #reconstruction material=marker)
            "Deferred source role/marker/fixed producer mismatch"
          val _=List.app(fn(expected,bytes)=>require(expected=digest bytes) "Deferred source slot integrity")
            [(#projection manifest,#projection material),(#sequent manifest,#sequent material),
             (#context_closure manifest,#context_closure material),(#payload manifest,#reconstruction material)]
          val m=Wire.decode(#projection material)
          val _=require(#workspace m=I.workspace allocator andalso #workspace material= #workspace m andalso
            #association material= #slot m andalso #semantic_generation material= #operation_generation m andalso
            Checkpoint.matches committed m)
            "Deferred source does not match exact original current request/goal/slot/profile"
          val boot=V.image_policy(#image configuration)
          val thy=A.policy_theory boot
          val locator=Context.theory_name{long=true}thy
          val root=if member(op =)(Veri7vn_Native_Installed_Roots.locators(#roots configuration))locator
            then (require(Veri7vn_Native_Installed_Roots.matches(#roots configuration)locator thy)
              "Deferred installed boot root differs";G.Installed_Public locator)else G.Public
          val operation=G.acquire_graph graph allocator boot(V.context_closure(#image configuration))committed
            {head= #operation_generation m,nodes=[{context_id= #operation_generation m,parents=[],construction=root}]}
          val _=owned_operation:=SOME operation
          val _=G.checked operation
          val temporary=Scope.check scope_batch committed
          val checked_scope=Scope.View.retain temporary
          val _=owned_scope:=SOME checked_scope
          val _=Scope.View.release temporary
          val saved=Scope.View.saved checked_scope
          val child=case find_first(fn(c:Veri7vn_Native_Scope_Saved.child)=>
            #goal(#identity c)= #goal m andalso #slot(#identity c)= #slot m)(#children saved)of
              SOME child=>child|NONE=>error "Deferred original Scope child absent"
          val identity= #identity child val source= #source m
          val _=require(#request identity= #request m andalso #interpretation identity= #interpretation m andalso
            #decision identity= #decision m andalso #source(#source child)= #source_owner source andalso
            #start(#source child)= #start source andalso #stop(#source child)= #stop source andalso
            Context.eq_thy(A.policy_theory(Scope.View.policy checked_scope),A.policy_theory(V.image_policy(#image configuration))))
            "Deferred source differs from exact original Scope/native operation policy"
          fun parent(T.Installed{locator,root})=
                (require(Veri7vn_Native_Installed_Roots.resolve_import(#roots configuration)locator=root)
                  "Deferred installed import is not its fixed actual root";())
            |parent(T.KnownCandidate{locator,candidate,context,slot})=
                let val borrowed=case Known.lookup candidate of SOME lease=>lease
                      |NONE=>error "Deferred known native candidate absent"
                  val lease=Known.retain borrowed val _=owned_known:=(locator,lease):: !owned_known
                  val _=require(Known.candidate lease=candidate andalso Known.context lease=context andalso
                    Known.assigned_slot lease=slot andalso P.development_workspace(Known.development lease)= #workspace m)
                    "Deferred known parent/native head/original output association differs"
                in()end
            |parent(T.ReservedOutput{goal,slot,source_owner,start,stop,...})=
                let val _=require(member(op =)(#predecessors child)(goal,slot)) "Deferred reserved output is not an original predecessor"
                  val predecessor=the(find_first(fn(c:Veri7vn_Native_Scope_Saved.child)=>
                    (#goal(#identity c),#slot(#identity c))=(goal,slot)) (#children saved))
                in require(#source(#source predecessor)=source_owner andalso #start(#source predecessor)=start andalso
                  #stop(#source predecessor)=stop) "Deferred reserved source association differs"end
          val _=List.app parent(#parents m)
          val closure=Q.decode(#context_closure material)
          val _=require(#image closure=V.context_closure(#image configuration) andalso map #id(#sources closure)=source_ids m)
            "Deferred exact original source closure/image mismatch"
          val restored=Q.recover_all allocator sources committed
          fun owner id=P.restore_source(the(find_first(fn source=>Q.identity source=id)restored))
          val theory=owner(#source_owner source) val descriptor=owner(#descriptor_source source)
          fun slice owner start stop=
            let val input=P.source_input owner val bytes=L.bytes input
              val _=require(start>=0 andalso stop>=start andalso stop<=size bytes)
                "Deferred original physical source span"
            in L.slice input{start=start,stop=stop,expected=String.substring(bytes,start,stop-start)}end
          val theory_slice=slice theory(#start source)(#stop source)
          val descriptor_slice=slice descriptor(#descriptor_start source)(#descriptor_stop source)
          val expected=Thread_Attributes.with_attributes original(fn _=>Veri7vn_Package_Inputs_Load_Private.interpret_descriptor descriptor descriptor_slice)
          val intent=Intent.capture_owned construction{source=descriptor,slice=descriptor_slice,
            source_revision= #source_revision source,manifest= #manifest source,export_intent= #export_intent source,
            capabilities= #capabilities expected}
          val _=owned_intent:=SOME intent
          val binding={metadata= #original_input m,expectation=expected,descriptor_source=descriptor,
            descriptor_slice=descriptor_slice,theory_source=theory,theory_slice=theory_slice,
            source_revision= #source_revision source,manifest= #manifest source,export_intent= #export_intent source}:Veri7vn_Package_Inputs_Load_Private.binding
          val prepared=Veri7vn_Package_Inputs_Load_Private.adopt_restored_owned construction{binding=binding,original_intent=intent,plan=m}
          val _=owned_input:=SOME prepared
          val p={allocator=allocator,configuration=configuration,operation=operation,plan=m,input=prepared,intent=intent,
            known=rev(!owned_known),scope=Synchronized.var "deferred_scope_payload"(SOME checked_scope),sources=sources}:payload
          val checked=Checked{group=Group(Synchronized.var "deferred_checked_group"(Open(1,p))),
            active=Claim.create()}
          val _=Synchronized.change roots(fn NONE=>error "Deferred restore batch closed"
            |SOME old=>(require(length old<256) "Deferred source object bound";SOME(checked::old)))
          val _=P.commit_scope construction val _=published:=true
        in checked end
      val result=Exn.capture run()
    in case result of Exn.Res checked=>checked
      |Exn.Exn failure=>(if !published then()else
        (Option.app Veri7vn_Package_Inputs_Load_Private.release(!owned_input);Option.app Intent.release(!owned_intent);
         Option.app Scope.View.release(!owned_scope);List.app(Known.release o snd)(!owned_known);
         P.abort_scope construction;Option.app G.release(!owned_operation);Q.release sources);Exn.reraise failure)end);
end;

(* No raw adoption constructor remains nameable after successful trusted load. *)
structure Veri7vn_Package_Inputs_Load_Private :> sig end = struct end;
