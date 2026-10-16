(* Bounded inert response transport. A source owner is not delivery permission:
   the parent must use the generated StageEffectObservation gate and exact ack.
   Original source leases are independent of live executor/configuration views. *)
signature VERI7VN_NATIVE_EFFECT_RESPONSES =
sig
  type pool type transfer type response
  type origin={gate:string,incarnation:serial,permit:serial}
  type metadata={sha256:string,size:int}
  val create:Veri7vn_Native_Identity_Allocator.allocator->pool
  val begin_response:pool->Veri7vn_Native_Effect_Inputs.binding->origin->string->metadata->transfer
  val transfer_key:transfer->serial
  val write:transfer->int->Bytes.T->unit
  val finish:transfer->response
  val accept_nonce:pool->string->response
  val discard_nonce:pool->string->unit val settle_nonce:pool->string->unit
  val key:response->serial val live:response->bool
  val source:response->Veri7vn_Managed_Provenance.source_owner
  val originals:response->Veri7vn_Native_Effect_Inputs.binding
  val metadata:response->metadata val origin:response->origin
  val retain:response->response
  val release:response->unit val close:pool->unit
end;
structure Veri7vn_Native_Effect_Responses :> VERI7VN_NATIVE_EFFECT_RESPONSES =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  type origin={gate:string,incarnation:serial,permit:serial};
  type metadata={sha256:string,size:int};
  datatype response=Response of {key:serial,source:P.source_owner,
    originals:Veri7vn_Native_Effect_Inputs.binding,origin:origin,data:metadata,
    leases:L.lease list,active:bool Synchronized.var};
  datatype pool=Pool of {allocator:I.allocator,state:state Synchronized.var}
  and transfer=Transfer of {key:serial,nonce:string,pool:pool,data:metadata,
    originals:Veri7vn_Native_Effect_Inputs.binding,origin:origin,leases:L.lease list,
    bytes:Word8Array.array,offset:int Unsynchronized.ref,
    published:response option Unsynchronized.ref,accepted:bool Unsynchronized.ref,
    discarded:bool Unsynchronized.ref}
  withtype state={open_pool:bool,transfers:transfer list,responses:response list,abandoned:string list};
  fun require true _=()|require false s=error s;
  fun valid_nonce s=size s>=16 andalso size s<=128 andalso forall Char.isAlphaNum(String.explode s);
  fun digest s=size s=64 andalso forall(fn c=>Char.isDigit c orelse (#"a"<=c andalso c<= #"f"))(String.explode s);
  fun release_lease lease=Option.app I.release_disposed_input(L.release lease);
  fun create allocator=Pool{allocator=allocator,state=Synchronized.var "effect_responses"
    {open_pool=true,transfers=[],responses=[],abandoned=[]}};
  fun key(Response{key,...})=key;
  fun live(Response{active,leases,...})=Synchronized.value active andalso forall(can L.lease_input)leases;
  fun source(r as Response{source,...})=(require(live r) "Effect response source released";source);
  fun originals(r as Response{originals,...})=(require(live r) "Effect response originals released";originals);
  fun metadata(Response{data,...})=data;
  fun origin(Response{origin,...})=origin;
  fun allocated(Response{source,...})=not(L.disposed(P.source_input source));
  fun release(Response{active,leases,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn old=>(if old then List.app release_lease leases else();false)));
  (* Independent output/recovery roots survive release of an upload view. The
     pool still charges the original physical payload until its last lease ends. *)
  fun retain(r as Response{source,originals,origin,data,...})=
    Thread_Attributes.uninterruptible_body(fn _=>
      let val _=require(live r) "Effect response retain after release"
        val held=Unsynchronized.ref([]:L.lease list)
        fun keep input=let val lease=L.retain input in held:=lease:: !held;lease end
        val result=Exn.capture(fn()=>
          (ignore(keep(P.source_input source));ignore(keep(P.source_input(#configuration originals)));
           ignore(keep(P.source_input(#packet originals)));
           Response{key=serial(),source=source,originals=originals,origin=origin,data=data,
             leases= !held,active=Synchronized.var "effect_response_retained_live" true}))()
      in case result of Exn.Res value=>value|Exn.Exn failure=>
        (List.app release_lease(!held);Exn.reraise failure)end);
  fun transfer_key(Transfer{key,...})=key;
  fun transfer_nonce(Transfer{nonce,...})=nonce;
  fun wipe(Transfer{bytes,...})=Word8Array.modify(K 0w0)bytes;
  fun same_originals(a:Veri7vn_Native_Effect_Inputs.binding,b:Veri7vn_Native_Effect_Inputs.binding)=
    L.same_input(P.source_input(#configuration a),P.source_input(#configuration b)) andalso
    L.same_input(P.source_input(#packet a),P.source_input(#packet b));
  fun begin_response(pool as Pool{allocator,state}) originals (origin:origin) nonce (data:metadata)=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result state
      (fn old as {open_pool,transfers,responses,abandoned}=>
      let val _=require(open_pool andalso valid_nonce nonce andalso digest(#sha256 data)
          andalso size(#gate origin)>0 andalso size(#gate origin)<=256 andalso #incarnation origin>0
          andalso #permit origin>0 andalso #size data>0 andalso #size data<=65536 andalso not(member(op =)abandoned nonce))
          "Effect response metadata unavailable"
        val _=require(P.source_workspace(#configuration originals)=I.workspace allocator andalso
          P.source_workspace(#packet originals)=I.workspace allocator) "Effect response original workspace"
      in case find_first(fn t=>transfer_nonce t=nonce)transfers of
        SOME(t as Transfer{data=saved,originals=prior,origin=saved_origin,...})=>
          (require(saved=data andalso saved_origin=origin andalso same_originals(prior,originals)) "Effect response nonce rebound";(t,old))
      |NONE=>let val _=require(length transfers<2) "Effect response staging capacity"
          val buffer=Word8Array.array(#size data,0w0)
          val config=L.retain(P.source_input(#configuration originals))
          val packet=Exn.capture L.retain(P.source_input(#packet originals))
          val packet_lease=case packet of Exn.Res lease=>lease|Exn.Exn failure=>(release_lease config;Exn.reraise failure)
          val t=Transfer{key=serial(),nonce=nonce,pool=pool,data=data,originals=originals,origin=origin,
            leases=[config,packet_lease],bytes=buffer,offset=Unsynchronized.ref 0,
            published=Unsynchronized.ref NONE,accepted=Unsynchronized.ref false,discarded=Unsynchronized.ref false}
        in(t,{open_pool=true,transfers=t::transfers,responses=responses,abandoned=abandoned})end end));
  fun write(Transfer{pool=Pool{state,...},bytes,offset=position,published,discarded,...})offset chunk=
    Synchronized.change state(fn old as {open_pool,...}=>
      (require(open_pool andalso not(!discarded) andalso is_none(!published) andalso
        Bytes.size chunk>0 andalso Bytes.size chunk<=65536 andalso offset= !position andalso
        Bytes.size chunk<=Word8Array.length bytes-offset) "Effect response write unavailable/bound";
       CharVector.appi(fn(i,c)=>Word8Array.update(bytes,offset+i,Word8.fromInt(Char.ord c)))(Bytes.content chunk);
       position:=offset+Bytes.size chunk;old));
  fun finish(t as Transfer{pool=Pool{allocator,state},data,originals,origin,leases,bytes,offset,published,discarded,...})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result state
      (fn old as {open_pool,transfers,responses,abandoned}=>
      let val _=require(open_pool andalso not(!discarded)) "Effect response discarded"
      in case !published of SOME value=>(require(live value) "Effect response released";(value,old))
      |NONE=>let val _=require(!offset=Word8Array.length bytes) "Effect response incomplete"
          val raw=Byte.bytesToString(Word8Array.vector bytes)
          val _=require(Message_Digest.rep(SHA256.digest raw)= #sha256 data) "Effect response digest mismatch"
          val rs=filter allocated responses
          val _=require(length rs<64 andalso fold(fn r=>fn n=> #size(metadata r)+n)rs(size raw)<=4194304)
            "Effect response owner capacity"
          val input=L.input{bytes=raw,encoding="UTF-8"}
          val held=Unsynchronized.ref(NONE:L.lease option)
          val installed=Exn.capture(fn()=>let val source=P.install_host_source allocator input
              val lease=L.retain input val _=held:=SOME lease val _=ignore(L.drop_base input)
            in Response{key=serial(),source=source,originals=originals,origin=origin,data=data,
              leases=lease::leases,active=Synchronized.var "effect_response_live" true}end)()
        in case installed of Exn.Res r=>(published:=SOME r;wipe t;
              (r,{open_pool=true,transfers=transfers,responses=r::rs,abandoned=abandoned}))
          |Exn.Exn failure=>(Option.app I.release_disposed_input(L.drop_base input);
              Option.app release_lease(!held);Exn.reraise failure)end end));
  fun accept_nonce(Pool{state,...})nonce=Synchronized.change_result state(fn old as {open_pool,transfers,...}=>
    let val _=require open_pool "Effect response pool closed"
      val Transfer{published,accepted,discarded,...}=the(find_first(fn t=>transfer_nonce t=nonce)transfers)
      val r=the(!published) val _=require(not(!discarded) andalso live r) "Effect response acceptance unavailable"
      val _=accepted:=true
    in(r,old)end);
  fun discard_transfer(t as Transfer{published,discarded,leases,...})=
    if !discarded then () else (discarded:=true;
      (case !published of SOME r=>release r|NONE=>List.app release_lease leases);wipe t);
  fun discard_nonce(Pool{state,...})nonce=Synchronized.change state(fn {open_pool,transfers,responses,abandoned}=>
    (require(valid_nonce nonce andalso(member(op =)abandoned nonce orelse length abandoned<2)) "Effect response cancellation bound";
     List.app(fn t=>if transfer_nonce t=nonce then discard_transfer t else())transfers;
     {open_pool=open_pool,transfers=transfers,responses=responses,abandoned=insert(op =)nonce abandoned}));
  fun settle_nonce(Pool{state,...})nonce=Synchronized.change state(fn {open_pool,transfers,responses,abandoned}=>
    (List.app(fn t as Transfer{accepted,discarded,...}=>if transfer_nonce t=nonce then
      (require(!accepted orelse !discarded) "Effect response unsettled";wipe t)else())transfers;
     {open_pool=open_pool,transfers=filter_out(fn t=>transfer_nonce t=nonce)transfers,
       responses=responses,abandoned=remove(op =)nonce abandoned}));
  fun close(Pool{state,...})=Synchronized.change state(fn {transfers,responses,...}=>
    (List.app discard_transfer transfers;List.app release responses;
     {open_pool=false,transfers=[],responses=[],abandoned=[]}));
end;
