(* Durable numeric identity is not native evidence. Only authenticated host ingress
   installs blocks already advanced in the existing durable workspace allocator. *)
signature VERI7VN_NATIVE_IDENTITY_ALLOCATOR =
sig
  type allocator
  type fragment
  val install_fragments: allocator -> fragment list -> unit
  val install_host_block: {workspace: string, first: IntInf.int, past: IntInf.int} -> allocator
  val allocate: allocator -> IntInf.int
  val workspace: allocator -> string
  val combine_fragments: fragment list -> fragment
  val input_identity: allocator -> Veri7vn_Native_Literals.input -> IntInf.int
  val lookup_input_identity: allocator -> Veri7vn_Native_Literals.input -> IntInf.int option
  val release_disposed_input: Veri7vn_Native_Literals.input -> unit
  val release_generation: allocator -> Veri7vn_Native_Registry.generation -> unit
  val mark_staged_generation: allocator -> Veri7vn_Native_Registry.generation -> unit
  val generation_id: allocator -> Veri7vn_Native_Registry.generation -> IntInf.int
  val lookup_generation_id: allocator -> Veri7vn_Native_Registry.generation -> IntInf.int option
end;
signature VERI7VN_CHECKED_GENERATION_CORRESPONDENCE =
sig
  type verified
  val bindings: verified -> {workspace:string,
    generation:Veri7vn_Native_Registry.generation,semantic_generation:IntInf.int} list
end;
signature VERI7VN_CHECKED_INPUT_CORRESPONDENCE =
sig
  type verified
  val bindings: verified -> {workspace:string,input:Veri7vn_Native_Literals.input,
    input_identity:IntInf.int} list
end;
(* The binder is captured only by fixed, trusted image functor instantiations.
   It is not a runtime callback/worker registration or public raw-ID setter. *)
local
  datatype native_fragment=Fragment of {generations:((string * int) * IntInf.int) list,
    inputs:((string * int) * IntInf.int) list};
  type generation_state = {generations:((string * int) * IntInf.int) list,
    inputs:((string * int) * IntInf.int) list,staged:(string * int) list};
  val identities=Synchronized.var "veri7vn_native_generation_identities"
    ({generations=[],inputs=[],staged=[]}:generation_state);
  fun input_key workspace input=(workspace,Veri7vn_Native_Literals.input_locator input);
  fun key workspace generation=(workspace,Veri7vn_Native_Registry.generation_locator generation);
  fun bind_entry ({workspace,generation,semantic_generation}:
      {workspace:string,generation:Veri7vn_Native_Registry.generation,semantic_generation:IntInf.int}) entries =
    if semantic_generation<=0 orelse size(IntInf.toString semantic_generation)>128 then
      error "Checked native generation ID bound"
    else case AList.lookup (op =) entries (key workspace generation) of
      NONE=>AList.update (op =) (key workspace generation,semantic_generation) entries
    | SOME old=>if old=semantic_generation then entries
      else error "Native generation already has another durable ID"
in
structure Veri7vn_Native_Identity_Allocator :> VERI7VN_NATIVE_IDENTITY_ALLOCATOR
  where type fragment = native_fragment =
struct
  type fragment=native_fragment;
  datatype allocator = Allocator of {workspace: string, past: IntInf.int,
    next: IntInf.int Synchronized.var};
  (* Non-content workspace numbers only; never generation/context objects. *)
  val high_water = Synchronized.var "veri7vn_native_id_high_water"
    ([]: (string * IntInf.int) list);
  fun valid_workspace s = size s=32 andalso forall (fn c =>
    Char.isDigit c orelse (#"a" <= c andalso c <= #"f")) (String.explode s);
  fun install_host_block {workspace,first,past} =
    let
      val _ = if valid_workspace workspace andalso first>0 andalso past>first
        andalso past-first<=65536 andalso size (IntInf.toString past)<=128 then ()
        else error "Invalid host native identity block";
      val _ = Synchronized.change high_water (fn entries =>
        let val previous=the_default 0 (AList.lookup (op =) entries workspace)
        in if first<previous then error "Host native identity block overlaps prior allocation"
          else AList.update (op =) (workspace,past) entries end);
    in Allocator {workspace=workspace,past=past,
      next=Synchronized.var "veri7vn_native_id_block" first} end;
  fun allocate (Allocator {past,next,...}) = Synchronized.change_result next (fn n =>
    if n>=past then error "Native identity block exhausted" else (n,n+1));
  fun workspace (Allocator {workspace,...}) = workspace;
  fun reverse_unique entries =
    length(distinct(op =)(map (fn ((w,_),id)=>(w,id)) entries))=length entries;
  fun combine_fragments fragments=Fragment {
    generations=maps(fn Fragment{generations,...}=>generations)fragments,
    inputs=maps(fn Fragment{inputs,...}=>inputs)fragments};
  fun install_fragments allocator fragments =
    let val Fragment{generations=gs,inputs=ins}=combine_fragments fragments
      val entries=distinct(op =)gs
      val input_entries=distinct(op =)ins
      val _=if forall (fn ((w,_),id)=>w=workspace allocator andalso id>0 andalso
        size(IntInf.toString id)<=128) (entries @ input_entries) then ()
        else error "Checked identity fragment bounds/workspace"
      fun add (k,id) old=(case AList.lookup(op =)old k of
        NONE=>AList.update(op =)(k,id)old
      | SOME prior=>if prior=id then old else error "Checked native identity conflict")
    in Synchronized.change identities (fn {generations,inputs,staged}=>
      let val merged=fold add entries generations
        val merged_inputs=fold add input_entries inputs
        val _=if reverse_unique(merged @ merged_inputs) then ()
          else error "Checked native identity graph is not one-to-one"
      in {generations=merged,inputs=merged_inputs,
        staged=fold(fn(k,_)=>remove(op =)k)entries staged} end) end;
  fun lookup_generation_id allocator generation =
    AList.lookup(op =)(#generations(Synchronized.value identities))
      (key(workspace allocator)generation);
  fun lookup_input_identity allocator input =
    AList.lookup(op =)(#inputs(Synchronized.value identities))
      (input_key(workspace allocator)input);
  fun mark_staged_generation allocator generation =
    let val k=key(workspace allocator)generation
    in Synchronized.change identities (fn {generations,inputs,staged}=>
      if is_none(AList.lookup(op =)generations k) then
        {generations=generations,inputs=inputs,staged=insert(op =)k staged}
      else error "Cannot stage an already assigned native generation") end;
  fun release_generation allocator generation =
    let val k=key(workspace allocator)generation
    in Synchronized.change identities (fn {generations,inputs,staged}=>
      {generations=AList.delete(op =)k generations,inputs=inputs,staged=remove(op =)k staged}) end;
  fun release_disposed_input input =
    if not(Veri7vn_Native_Literals.disposed input) then
      error "Cannot detach identity of an owned native input"
    else let val locator=Veri7vn_Native_Literals.input_locator input
    in Synchronized.change identities (fn {generations,inputs,staged}=>
      {generations=generations,inputs=filter_out(fn((_,loc),_)=>loc=locator)inputs,staged=staged}) end;
  fun generation_id allocator generation =
    Synchronized.change_result identities (fn state as {generations,inputs,staged}=>
      let val k=key(workspace allocator)generation
        val _=if member(op =)staged k then
          error "Staged native generation requires checked reassociation" else ()
      in case AList.lookup(op =)generations k of SOME id=>(id,state)
      | NONE=>let val id=allocate allocator
          val merged=bind_entry {workspace=workspace allocator,generation=generation,
            semantic_generation=id}generations
          val _=if reverse_unique(merged @ inputs) then ()
            else error "Allocated native identity collision"
        in(id,{generations=merged,inputs=inputs,staged=staged})end end);
  fun input_identity allocator input = Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val lease=Veri7vn_Native_Literals.retain input
      val result=Exn.capture(fn()=>Synchronized.change_result identities
        (fn state as {generations,inputs,staged}=>
          let val k=input_key(workspace allocator)input
          in case AList.lookup(op =)inputs k of SOME id=>(id,state)
          | NONE=>let val id=allocate allocator
              val merged=AList.update(op =)(k,id)inputs
              val _=if reverse_unique(generations @ merged)then()else
                error "Allocated native input identity collision"
            in(id,{generations=generations,inputs=merged,staged=staged})end end))()
      val disposed=Veri7vn_Native_Literals.release lease
      val _=Option.app release_disposed_input disposed
    in Exn.release result end)();

end;
(* Temporary image-construction capability. The fixed functor captures this
   lexical structure before its name is shadowed below; no raw constructor is
   present in the completed native image. SML functors are top-level declarations. *)
structure Veri7vn_Native_Fragment_Private :
sig
  val generations:((string * int) * IntInf.int) list -> Veri7vn_Native_Identity_Allocator.fragment
  val inputs:((string * int) * IntInf.int) list -> Veri7vn_Native_Identity_Allocator.fragment
end =
struct
  fun generations entries=Fragment{generations=entries,inputs=[]};
  fun inputs entries=Fragment{generations=[],inputs=entries};
end;
end;
functor Veri7vn_Checked_Generation_Reassociation
  (Check:VERI7VN_CHECKED_GENERATION_CORRESPONDENCE) :
sig val fragment: Check.verified -> Veri7vn_Native_Identity_Allocator.fragment end =
struct
  fun fragment verified =
    let val bindings=Check.bindings verified
      val _=if forall (fn {semantic_generation,...}=>semantic_generation>0 andalso
        size(IntInf.toString semantic_generation)<=128) bindings then ()
        else error "Checked native generation identity bound"
    in Veri7vn_Native_Fragment_Private.generations
      (map (fn {workspace,generation,semantic_generation}=>
        ((workspace,Veri7vn_Native_Registry.generation_locator generation),semantic_generation)) bindings) end;
end;
functor Veri7vn_Checked_Input_Reassociation
  (Check:VERI7VN_CHECKED_INPUT_CORRESPONDENCE) :
sig val fragment:Check.verified -> Veri7vn_Native_Identity_Allocator.fragment end =
struct
  fun fragment verified =
    let val bindings=Check.bindings verified
      val _=if forall(fn {input_identity,...}=>input_identity>0 andalso
        size(IntInf.toString input_identity)<=128)bindings then ()
        else error "Checked native input identity bound"
    in Veri7vn_Native_Fragment_Private.inputs
      (map(fn {workspace,input,input_identity}=>
        ((workspace,Veri7vn_Native_Literals.input_locator input),input_identity))bindings)end;
end;
structure Veri7vn_Native_Fragment_Private = struct end;
