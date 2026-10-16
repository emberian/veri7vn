(* Fixed checked source witnesses select identities. This pool owns only native
   input lifetimes and exact byte correspondence, never logical authority. *)
signature VERI7VN_NATIVE_RECOVERY_INPUTS =
sig
  type pool
  type lease
  val create:Veri7vn_Native_Identity_Allocator.allocator->pool
  val pool_workspace:pool->string
  val input:lease->Veri7vn_Native_Literals.input
  val identity:lease->IntInf.int
  val workspace:lease->string
  val retain:lease->lease
  val release:lease->unit
  val fragment:lease->Veri7vn_Native_Identity_Allocator.fragment
  val close:pool->unit
  val abort:pool->unit
end;
signature VERI7VN_CHECKED_RECOVERY_INPUT =
sig
  type verified
  val binding:verified->{workspace:string,identity:IntInf.int,bytes:string,encoding:string}
end;
local
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  type entry={identity:IntInf.int,input:L.input,refs:int,base:bool};
  type pool_state={open_pool:bool,aborted:bool,entries:entry list,retired:IntInf.int list};
  datatype input_pool=Pool of {allocator:I.allocator,state:pool_state Synchronized.var};
  datatype input_lease=Lease of {pool:input_pool,identity:IntInf.int,input:L.input,
    owner:L.lease,active:bool Synchronized.var};
  fun pool_ids(Pool{allocator,...})=allocator;
  fun pool_workspace pool=I.workspace(pool_ids pool);
  fun dispose _ input=if L.disposed input then I.release_disposed_input input else ();
  fun acquire (pool as Pool{allocator,state}) {workspace,identity,bytes,encoding} =
    Thread_Attributes.uninterruptible_body(fn _=>
    let val _=if workspace=I.workspace allocator andalso identity>0 andalso
        size(IntInf.toString identity)<=128 andalso encoding="UTF-8" andalso size bytes<=1048576
      then () else error "Checked recovery input bounds/workspace"
      val (input,owner)=Synchronized.change_result state
        (fn {open_pool,aborted,entries,retired}=>
          let val _=if open_pool andalso not aborted then () else error "Recovery input pool is closed"
            val _=if member(op =)retired identity then error "Recovery input identity already retired in this pool" else ()
            val (input,base,rest)=case List.partition(fn(e:entry)=> #identity e=identity)entries of
              ([],_)=>if length entries+length retired<8192 then
                  (L.input{bytes=bytes,encoding=encoding},true,entries)
                else error "Recovery input pool object bound"
            | ([entry],rest)=>if L.bytes(#input entry)=bytes andalso L.encoding(#input entry)=encoding
                then (#input entry,#base entry,rest)
                else error "Conflicting saved input bytes/encoding"
            | _=>error "Recovery input pool identity invariant"
            val prior=case find_first(fn(e:entry)=> #identity e=identity)entries of NONE=>0|SOME e=> #refs e
            val owner=L.retain input
            val entry={identity=identity,input=input,refs=prior+1,base=base}:entry
          in ((input,owner),{open_pool=open_pool,aborted=aborted,entries=entry::rest,retired=retired})end)
    in Lease{pool=pool,identity=identity,input=input,owner=owner,
      active=Synchronized.var "veri7vn_recovery_input_lease" true}end);
in
structure Veri7vn_Native_Recovery_Inputs :> VERI7VN_NATIVE_RECOVERY_INPUTS
  where type pool=input_pool and type lease=input_lease =
struct
  type pool=input_pool;
  type lease=input_lease;
  fun create allocator=Pool{allocator=allocator,state=Synchronized.var "veri7vn_recovery_input_pool"
    {open_pool=true,aborted=false,entries=[],retired=[]}};
  val pool_workspace=pool_workspace;
  fun input(Lease{pool=Pool{state,...},input,active,...})=
    if Synchronized.value active andalso not(#aborted(Synchronized.value state)) andalso L.retained input
    then input else error "Recovery input lease is unavailable";
  fun identity(lease as Lease{identity,...})=(ignore(input lease);identity);
  fun workspace(lease as Lease{pool,...})=(ignore(input lease);pool_workspace pool);
  fun retain(lease as Lease{pool=(pool as Pool{state,...}),identity,input=actual,active,...})=
    Synchronized.change_result active(fn live=>
      if not live then error "Recovery input lease released"
      else let val _=if L.retained actual then () else error "Recovery input was invalidated"
        val owner=Synchronized.change_result state(fn {open_pool,aborted,entries,retired}=>
          let val _=if aborted then error "Recovery input pool aborted" else ()
            val entry=the(find_first(fn(e:entry)=> #identity e=identity)entries)
            val owner=L.retain actual
            val updated={identity=identity,input=actual,refs= #refs entry+1,base= #base entry}:entry
          in(owner,{open_pool=open_pool,aborted=aborted,entries=updated::filter
            (fn(e:entry)=> #identity e<>identity)entries,retired=retired})end)
      in(Lease{pool=pool,identity=identity,input=actual,owner=owner,
        active=Synchronized.var "veri7vn_recovery_input_lease" true},live)end);
  fun release(Lease{pool=Pool{allocator,state},identity,input,owner,active})=
    Synchronized.change active(fn live=>if not live then false else
      let val drop=Synchronized.change_result state(fn {open_pool,aborted,entries,retired}=>
          case find_first(fn(e:entry)=> #identity e=identity)entries of
            NONE=>(false,{open_pool=open_pool,aborted=aborted,entries=entries,retired=retired})
          | SOME entry=>let val refs= #refs entry-1
              val updated={identity=identity,input=input,refs=refs,
                base= #base entry andalso refs>0}:entry
            in (#base entry andalso refs=0,{open_pool=open_pool,aborted=aborted,
              entries=updated::filter(fn(e:entry)=> #identity e<>identity)entries,retired=retired})end)
        val _=Option.app I.release_disposed_input (L.release owner)
        val _=if drop then Option.app I.release_disposed_input (L.drop_base input) else ()
        val _=if L.disposed input then Synchronized.change state
          (fn {open_pool,aborted,entries,retired}=>
            {open_pool=open_pool,aborted=aborted,
              entries=filter(fn(e:entry)=> #identity e<>identity)entries,
              retired=insert(op =)identity retired})else()
      in false end);
  structure Reassociation=Veri7vn_Checked_Input_Reassociation(struct
    type verified=lease
    fun bindings lease=[{workspace=workspace lease,input=input lease,input_identity=identity lease}]
  end);
  val fragment=Reassociation.fragment;
  fun close(Pool{allocator,state})=Thread_Attributes.uninterruptible_body(fn _=>
    let val inputs=Synchronized.change_result state(fn {open_pool,aborted,entries,retired}=>
      let val drop=map #input(filter #base entries)
        val updated=map(fn(e:entry)=>{identity= #identity e,input= #input e,refs= #refs e,base=false}:entry)entries
      in(drop,{open_pool=false,aborted=aborted,entries=updated,retired=retired})end)
    in List.app(fn input=>(ignore(L.drop_base input);dispose allocator input))inputs end);
  fun abort(Pool{allocator,state})=Thread_Attributes.uninterruptible_body(fn _=>
    let val inputs=Synchronized.change_result state(fn {entries,retired,...}=>
      (map #input entries,{open_pool=false,aborted=true,entries=entries,retired=retired}))
    in List.app(fn input=>(L.invalidate input;ignore(L.drop_base input);dispose allocator input))inputs end);
end;
structure Veri7vn_Recovery_Input_Private :
sig val acquire:Veri7vn_Native_Recovery_Inputs.pool->
  {workspace:string,identity:IntInf.int,bytes:string,encoding:string}->Veri7vn_Native_Recovery_Inputs.lease end =
struct val acquire=acquire end;
end;
functor Veri7vn_Checked_Recovery_Input_Pool(Check:VERI7VN_CHECKED_RECOVERY_INPUT) :
sig val acquire:Veri7vn_Native_Recovery_Inputs.pool->Check.verified->Veri7vn_Native_Recovery_Inputs.lease end =
struct
  val acquire=fn pool=>fn verified=>Veri7vn_Recovery_Input_Private.acquire pool(Check.binding verified);
end;
structure Veri7vn_Recovery_Input_Private=struct end;
