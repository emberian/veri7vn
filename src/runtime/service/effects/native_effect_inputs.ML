(* D69: one opaque installed configuration, independently uploaded request packets.
   Native IDs originate only from actual P.source_owner installation. *)
signature VERI7VN_NATIVE_EFFECT_INPUTS =
sig
  type pool type transfer type configuration type prepared
  type source_data={draft:string,head:string,member:string,sha256:string,size:int}
  type metadata={nonce:string,configuration:source_data,packet:source_data}
  type binding={metadata:metadata,configuration_owner:configuration,
    configuration:Veri7vn_Managed_Provenance.source_owner,packet:Veri7vn_Managed_Provenance.source_owner}
  datatype result=InstalledConfiguration of configuration|PreparedPacket of prepared
  val create:Veri7vn_Native_Identity_Allocator.allocator->pool
  val begin_configuration:pool->string->source_data->IntInf.int->transfer
  val begin_packet:pool->configuration->string->source_data->transfer
  val transfer_key:transfer->serial val write:transfer->int->Bytes.T->unit val finish:transfer->result
  val accept_nonce:pool->string->result val discard_nonce:pool->string->unit val settle_nonce:pool->string->unit
  val configuration_key:configuration->serial val configuration_live:configuration->bool
  val configuration_source:configuration->Veri7vn_Managed_Provenance.source_owner
  val configuration_epoch:configuration->IntInf.int
  val configuration_data:configuration->source_data val release_configuration:configuration->unit
  val prepared_key:prepared->serial
  val binding:prepared->binding val live:prepared->bool val release:prepared->unit val close:pool->unit
end;
structure Veri7vn_Native_Effect_Inputs :> VERI7VN_NATIVE_EFFECT_INPUTS =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  type source_data={draft:string,head:string,member:string,sha256:string,size:int};
  type metadata={nonce:string,configuration:source_data,packet:source_data};
  datatype configuration=Configuration of {key:serial,pool:serial,data:source_data,epoch:IntInf.int,source:P.source_owner,
    lease:L.lease,active:bool Synchronized.var};
  type binding={metadata:metadata,configuration_owner:configuration,configuration:P.source_owner,packet:P.source_owner};
  datatype prepared=Prepared of {key:serial,data:binding,lease:L.lease,active:bool Synchronized.var};
  datatype result=InstalledConfiguration of configuration|PreparedPacket of prepared;
  datatype kind=ConfigurationInput of IntInf.int|PacketInput of configuration;
  datatype pool=Pool of {key:serial,allocator:I.allocator,state:pool_state Synchronized.var}
  and transfer=Transfer of {key:serial,pool:pool,nonce:string,data:source_data,kind:kind,bytes:Word8Array.array,
    offset:int Unsynchronized.ref,published:result option Unsynchronized.ref,
    accepted:bool Unsynchronized.ref,discarded:bool Unsynchronized.ref}
  withtype pool_state={open_pool:bool,transfers:transfer list,configs:configuration list,
    packets:prepared list,abandoned:string list};
  fun require true _=()|require false text=error text;
  fun digest s=size s=64 andalso forall(fn c=>Char.isDigit c orelse (#"a"<=c andalso c<= #"f"))(String.explode s);
  fun nonce s=size s>=16 andalso size s<=128 andalso forall Char.isAlphaNum(String.explode s);
  fun valid({draft,head,member,sha256,size=n}:source_data)=size draft>0 andalso size draft<=256
    andalso digest head andalso digest member andalso member=sha256 andalso n>0 andalso n<=65536;
  fun create allocator=Pool{key=serial(),allocator=allocator,state=Synchronized.var "effect_inputs"
    {open_pool=true,transfers=[],configs=[],packets=[],abandoned=[]}};
  fun configuration_key(Configuration{key,...})=key;
  fun configuration_live(Configuration{active,lease,...})=Synchronized.value active andalso can L.lease_input lease;
  fun configuration_data(Configuration{data,...})=data;
  fun configuration_epoch(Configuration{epoch,...})=epoch;
  fun configuration_source(value as Configuration{source,...})=
    (require(configuration_live value) "Effect configuration released";source);
  fun prepared_key(Prepared{key,...})=key;
  fun live(Prepared{active,data,lease,...})=Synchronized.value active andalso
    configuration_live(#configuration_owner data) andalso can L.lease_input lease;
  fun binding(value as Prepared{data,...})=(require(live value) "Effect packet released";data);
  (* Capacity follows physical payloads, including producer-released sources
     retained by an entry. Releasing a view cannot refund another owner's bytes. *)
  fun config_allocated(Configuration{source,...})=not(L.disposed(P.source_input source));
  fun packet_allocated(Prepared{data,...})=not(L.disposed(P.source_input(#packet data)));
  fun packet_size(Prepared{data,...})= #size(#packet(#metadata data));
  fun release(Prepared{active,lease,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn old=>(if old then Option.app I.release_disposed_input(L.release lease)else();false)));
  fun release_configuration(Configuration{active,lease,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn old=>(if old then Option.app I.release_disposed_input(L.release lease)else();false)));
  fun result_live(InstalledConfiguration c)=configuration_live c|result_live(PreparedPacket p)=live p;
  fun release_result(InstalledConfiguration c)=release_configuration c|release_result(PreparedPacket p)=release p;
  fun kind_live(ConfigurationInput epoch)=epoch>=0 andalso size(IntInf.toString epoch)<=128|kind_live(PacketInput c)=configuration_live c;
  fun same_kind(ConfigurationInput a,ConfigurationInput b)=a=b
    |same_kind(PacketInput a,PacketInput b)=configuration_key a=configuration_key b|same_kind _=false;
  fun transfer_key(Transfer{key,...})=key;
  fun transfer_nonce(Transfer{nonce,...})=nonce;
  fun wipe(Transfer{bytes,...})=Word8Array.modify(K 0w0)bytes;
  fun begin_source(pool as Pool{key,state,...}) kind correlation data=
    Synchronized.change_result state(fn old as {open_pool,transfers,configs,packets,abandoned}=>
      let val _=require(open_pool andalso nonce correlation andalso valid data andalso kind_live kind
          andalso not(member(op =)abandoned correlation)) "Effect source metadata/nonce unavailable"
        val _=case kind of ConfigurationInput _=>()|PacketInput(Configuration{pool=saved,...})=>
          require(saved=key) "Effect configuration belongs to another pool"
      in case find_first(fn t=>transfer_nonce t=correlation)transfers of
        SOME(t as Transfer{data=saved,kind=prior,...})=>
          (require(saved=data andalso same_kind(prior,kind)) "Effect nonce rebound";(t,old))
      |NONE=>let val _=require(length transfers<2) "Effect staging capacity"
          val t=Transfer{key=serial(),pool=pool,nonce=correlation,data=data,kind=kind,
            bytes=Word8Array.array(#size data,0w0),offset=Unsynchronized.ref 0,published=Unsynchronized.ref NONE,
            accepted=Unsynchronized.ref false,discarded=Unsynchronized.ref false}
        in(t,{open_pool=open_pool,transfers=t::transfers,configs=configs,packets=packets,abandoned=abandoned})end end);
  fun begin_configuration pool correlation data epoch=begin_source pool(ConfigurationInput epoch)correlation data;
  fun begin_packet pool config correlation data=begin_source pool(PacketInput config)correlation data;
  fun write(Transfer{pool=Pool{state,...},bytes,offset=position,published,discarded,kind,...})offset chunk=
    Synchronized.change state(fn old as {open_pool,...}=>
      let val _=require(open_pool andalso kind_live kind andalso not(!discarded) andalso is_none(!published)
          andalso Bytes.size chunk>0 andalso Bytes.size chunk<=65536) "Effect write unavailable/bound"
        val _=require(offset= !position andalso Bytes.size chunk<=Word8Array.length bytes-offset) "Effect chunk offset/bound"
        val raw=Bytes.content chunk
        val _=CharVector.appi(fn(i,c)=>Word8Array.update(bytes,offset+i,Word8.fromInt(Char.ord c)))raw
        val _=position:=offset+size raw
      in old end);
  fun finish(t as Transfer{pool=Pool{key,allocator,state},nonce=correlation,data,kind,bytes,offset,published,discarded,...})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result state
      (fn old as {open_pool,transfers,configs,packets,abandoned}=>
      let val _=require(open_pool andalso kind_live kind andalso not(!discarded)) "Effect source discarded"
      in case !published of SOME value=>(require(result_live value) "Effect publication released";(value,old))
      |NONE=>let val _=require(!offset=Word8Array.length bytes) "Effect source incomplete"
          val raw=Byte.bytesToString(Word8Array.vector bytes)
          val _=require(Message_Digest.rep(SHA256.digest raw)= #sha256 data) "Effect source hash mismatch"
          val cs=filter config_allocated configs
          val ps=filter packet_allocated packets
          val total=fold(fn c=>fn n=> #size(configuration_data c)+n)cs
            (fold(fn p=>fn n=>packet_size p+n)ps 0)
          val _=require(length cs+length ps<64 andalso total+size raw<=8388608) "Effect source prepared capacity"
          val input=L.input{bytes=raw,encoding="UTF-8"}
          val held=Unsynchronized.ref(NONE:L.lease option)
          val result=Exn.capture(fn()=>let val source=P.install_host_source allocator input
              val lease=L.retain input val _=held:=SOME lease val _=ignore(L.drop_base input)
            in case kind of ConfigurationInput epoch=>InstalledConfiguration(Configuration{key=serial(),pool=key,
                data=data,epoch=epoch,source=source,lease=lease,active=Synchronized.var "effect_config_live" true})
              |PacketInput c=>PreparedPacket(Prepared{key=serial(),data={metadata={nonce=correlation,
                  configuration=configuration_data c,packet=data},configuration_owner=c,
                  configuration=configuration_source c,packet=source},lease=lease,
                active=Synchronized.var "effect_packet_live" true})end)()
          val _=wipe t
        in case result of Exn.Res value=>let val _=published:=SOME value
              val cs'=case value of InstalledConfiguration c=>c::cs|_=>cs
              val ps'=case value of PreparedPacket p=>p::ps|_=>ps
            in(value,{open_pool=open_pool,transfers=transfers,configs=cs',packets=ps',abandoned=abandoned})end
          |Exn.Exn failure=>(Option.app I.release_disposed_input(L.drop_base input);
              Option.app(fn lease=>Option.app I.release_disposed_input(L.release lease))(!held);Exn.reraise failure)end end));
  fun accept_nonce(Pool{state,...})key=Synchronized.change_result state(fn old as {open_pool,transfers,abandoned,...}=>
    let val _=require(open_pool andalso nonce key andalso not(member(op =)abandoned key)) "Effect nonce discarded"
      val Transfer{published,accepted,discarded,...}=the(find_first(fn t=>transfer_nonce t=key)transfers)
      val value=the(!published) val _=require(not(!discarded) andalso result_live value) "Effect acceptance unavailable"
      val _=accepted:=true
    in(value,old)end);
  fun discard_nonce(Pool{state,...})key=Synchronized.change state(fn {open_pool,transfers,configs,packets,abandoned}=>
    let val _=require(nonce key andalso(member(op =)abandoned key orelse length abandoned<2)) "Effect cancellation bound"
      val _=List.app(fn t as Transfer{discarded,published,...}=>if transfer_nonce t=key then
        (discarded:=true;Option.app release_result(!published);published:=NONE;wipe t)else())transfers
    in{open_pool=open_pool,transfers=transfers,configs=configs,packets=packets,abandoned=insert(op =)key abandoned}end);
  (* Host calls only after tracked transfer termination and FIFO control barrier. *)
  fun settle_nonce(Pool{state,...})key=Synchronized.change state(fn {open_pool,transfers,configs,packets,abandoned}=>
    let val _=require(nonce key) "Effect settlement nonce"
      val _=List.app(fn t as Transfer{accepted,discarded,...}=>if transfer_nonce t=key then
        (require(!accepted orelse !discarded) "Effect publication unsettled";wipe t)else())transfers
    in{open_pool=open_pool,transfers=filter_out(fn t=>transfer_nonce t=key)transfers,
      configs=configs,packets=packets,abandoned=remove(op =)key abandoned}end);
  fun close(Pool{state,...})=Synchronized.change state(fn {transfers,configs,packets,...}=>
    (List.app wipe transfers;List.app release packets;List.app release_configuration configs;
     {open_pool=false,transfers=[],configs=[],packets=[],abandoned=[]}));
end;
