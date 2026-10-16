(* Inert bounded source closure plus protected physical source reassociation.
   A source token establishes committed origin/ownership, never logical truth. *)
signature VERI7VN_NATIVE_RECOVERY_SOURCE =
sig
  type source_record={id:IntInf.int,encoding:string,bytes:string}
  type closure={image:string,sources:source_record list}
  val encode: closure -> string
  val decode: string -> closure
  type batch
  type source
  val batch: unit -> batch
  val batch_with: Veri7vn_Native_Recovery_Inputs.pool -> batch
  val close: batch -> unit
  val fragment: batch -> Veri7vn_Native_Identity_Allocator.fragment
  val recover_all: Veri7vn_Native_Identity_Allocator.allocator -> batch -> Veri7vn_Committed_Native_Recovery.committed -> source list
  val recover: Veri7vn_Native_Identity_Allocator.allocator -> batch -> Veri7vn_Committed_Native_Recovery.committed -> IntInf.int -> source
  val identity: source -> IntInf.int
  val workspace: source -> string
  val input: source -> Veri7vn_Native_Literals.input
  val forget_unused: batch -> (string * IntInf.int) list -> unit
  val release: batch -> unit
end;
structure Veri7vn_Native_Recovery_Source :> VERI7VN_NATIVE_RECOVERY_SOURCE =
struct
  structure C=Veri7vn_Committed_Native_Recovery;
  structure L=Veri7vn_Native_Literals;
  type source_record={id:IntInf.int,encoding:string,bytes:string};
  type closure={image:string,sources:source_record list};
  fun id_string n=if n>0 andalso size(IntInf.toString n)<=128 then IntInf.toString n
    else error "Recovery source ID bound";
  fun read_id s=if size s>128 then error "Recovery source ID digit bound"
    else case IntInf.fromString s of SOME n=>if id_string n=s then n
      else error "Recovery source ID canonical form" | NONE=>error "Recovery source ID";
  val enc=XML.Encode.pair XML.Encode.string (XML.Encode.list
    (XML.Encode.triple XML.Encode.string XML.Encode.string XML.Encode.string));
  val dec=XML.Decode.pair XML.Decode.string (XML.Decode.list
    (XML.Decode.triple XML.Decode.string XML.Decode.string XML.Decode.string));
  fun encode ({image,sources}:closure)=
    let val _=if size image<=1048576 andalso length sources<=8192 andalso
      length(distinct(op =)(map #id sources))=length sources andalso
      forall (fn {encoding,bytes,...}:source_record=>encoding="UTF-8" andalso size bytes<=1048576) sources
      then () else error "Recovery source closure bounds/duplicates"
      val bytes=YXML.string_of_body [XML.Elem (("veri7vn-controlled-source-closure",[("version","1")]),
        enc (Bytes.content(Base64.encode(Bytes.string image)),map (fn {id,encoding,bytes}=>(id_string id,encoding,Bytes.content(Base64.encode(Bytes.string bytes)))) sources))]
    in if size bytes<=16777216 then bytes else error "Recovery source closure byte bound" end;
  fun framing bytes=
    let val n=size bytes
      fun scan i depth nodes=if i>=n then if depth=0 then () else error "Recovery source framing"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then if depth>0 then scan(i+3)(depth-1)nodes else error "Recovery source closing frame"
          else if depth<64 andalso nodes<100000 then scan(i+2)(depth+1)(nodes+1)
          else error "Recovery source framing bounds"
        else scan(i+1)depth nodes
    in if n<=16777216 then scan 0 0 0 else error "Recovery source bytes" end;
  fun decode bytes=
    let val _=framing bytes
      val (image,rows)=case YXML.parse_body bytes of
        [XML.Elem (("veri7vn-controlled-source-closure",[("version","1")]),body)]=>dec body
      | _=>error "Recovery source closure schema"
      val closure={image=Bytes.content(Base64.decode(Bytes.string image)),sources=map(fn(id,encoding,bytes)=>
        {id=read_id id,encoding=encoding,bytes=Bytes.content(Base64.decode(Bytes.string bytes))}) rows}
      val _=if encode closure=bytes then () else error "Noncanonical recovery source closure"
    in closure end;
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure I=Veri7vn_Native_Identity_Allocator;
  datatype checked_source=Checked_Source of {committed:C.committed,record:source_record};
  structure CheckedPool=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified=checked_source
    fun binding(Checked_Source{committed,record})=
      {workspace= #workspace(C.materials committed),identity= #id record,
        bytes= #bytes record,encoding= #encoding record}
  end);
  datatype source=Source of Pool.lease;
  datatype batch=Batch of {sources:source list option Synchronized.var,
    pool:Pool.pool option Synchronized.var,owns_pool:bool};
  fun batch()=Batch{sources=Synchronized.var "veri7vn_recovery_sources" (SOME []),
    pool=Synchronized.var "veri7vn_recovery_source_pool" NONE,owns_pool=true};
  fun batch_with pool=Batch{sources=Synchronized.var "veri7vn_recovery_sources" (SOME []),
    pool=Synchronized.var "veri7vn_recovery_source_pool" (SOME pool),owns_pool=false};
  fun identity(Source lease)=Pool.identity lease;
  fun workspace(Source lease)=Pool.workspace lease;
  fun input(Source lease)=Pool.input lease;
  fun source_pool allocator(Batch{pool,...})=Synchronized.change_result pool(fn old=>
    let val actual=case old of SOME existing=>existing|NONE=>Pool.create allocator
      val _=if Pool.pool_workspace actual=I.workspace allocator then()else error "Recovery source pool workspace"
    in(actual,SOME actual)end);
  fun recover_all allocator (batch as Batch{sources,...}) committed =
    let val m=C.materials committed
      val manifest=Veri7vn_Recovery_Manifest.decode {max_bytes=8192} (#manifest m)
      val _=Veri7vn_Recovery_Manifest.require_profile Veri7vn_Recovery_Manifest.KernelEvidence manifest
      val _=if Message_Digest.rep(SHA256.digest(#context_closure m))= #context_closure manifest
        then () else error "Committed recovery source slot integrity"
      val closure=decode(#context_closure m)
      val pool=source_pool allocator batch
      val acquired=Unsynchronized.ref([]:Pool.lease list)
      fun install (record:source_record) sources =
        (case find_first(fn s=>identity s= #id record andalso workspace s= #workspace m) sources of
          SOME s=>if L.encoding(input s)= #encoding record andalso L.bytes(input s)= #bytes record
            then(s,sources)else error "Conflicting durable source meanings"
        | NONE=>let val lease=CheckedPool.acquire pool(Checked_Source{committed=committed,record=record})
            val _=acquired:=lease::(!acquired) val s=Source lease
          in(s,s::sources)end)
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val result=Exn.capture(fn()=>Synchronized.change_result sources(fn NONE=>error "Recovery source batch released"
        | SOME old=>let val(selected,next)=fold_map install (#sources closure)old
          in(selected,SOME next)end))()
    in case result of Exn.Res selected=>selected
      | Exn.Exn exn=>(List.app Pool.release (!acquired);Exn.reraise exn)end)end;
  fun recover allocator batch committed id=
    (case find_first(fn s=>identity s=id)(recover_all allocator batch committed)of SOME source=>source
    | NONE=>error "Source ID absent from committed reconstruction closure");
  fun forget_unused(Batch{sources,...})needed=Thread_Attributes.uninterruptible_body(fn _=>
    let val removed=Synchronized.change_result sources(fn NONE=>([],NONE)
      | SOME old=>let val(keep,drop)=List.partition
          (fn s=>member(op =)needed(workspace s,identity s))old
        in(drop,SOME keep)end)
    in List.app(fn Source lease=>Pool.release lease)removed end);
  fun close(Batch{pool,owns_pool,...})=if owns_pool then Option.app Pool.close(Synchronized.value pool)else();
  fun fragment(Batch{sources,...})=I.combine_fragments(map(fn Source lease=>Pool.fragment lease)
    (case Synchronized.value sources of SOME old=>old|NONE=>error "Recovery source batch released"));
  fun release(Batch{sources,pool,owns_pool})=Thread_Attributes.uninterruptible_body(fn _=>
    (case Synchronized.change_result sources(fn old=>(old,NONE))of NONE=>()
    | SOME old=>(List.app(fn Source lease=>Pool.release lease)old;
        if owns_pool then Option.app Pool.abort(Synchronized.change_result pool(fn old=>(old,NONE)))else())));
end;
