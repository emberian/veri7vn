(* Lexical include after SearchCodec/SearchRequest/SearchWire, before
   SearchResident. This owns the original literal only. A cancelled parent is
   never reconstructed as an active Scope, Q request, receiver or worker here.
   The checked input functor uses the parent's SAME recovery pool. *)
structure SearchSourceSupport =
struct
  structure Inputs=Veri7vn_Native_Recovery_Inputs;
  structure L=Veri7vn_Native_Literals;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Checkpoint=Veri7vn_Search_Request_Checkpoint;
  val require=SearchWire.require;
  fun projection material=
    let val {links,saved,...}=SearchCodec.inspect material
    in {identity=the(#scope_identity saved),context= #context links,
      receiver= #receiver links,worker= #worker links,input= #source links,
      cost= #cost links}:Checkpoint.projection end;
  fun phase material=
    let val {phase,...}=SearchCodec.inspect material
    in {execution=SearchCodec.execution phase,reason=SearchCodec.reason phase,
      stopped=(case phase of SearchCodec.Pending _=>NONE|
        SearchCodec.Stopped{stop,...}=>SOME(SearchCodec.stop_name stop))}:Checkpoint.phase end;
  local
    datatype checked=Checked of {material:SearchCodec.material,workspace:string};
    structure Check : VERI7VN_CHECKED_RECOVERY_INPUT where type verified=checked =
    struct
      type verified=checked;
      fun binding(Checked{material,workspace})=
        let val {links,saved,...}=SearchCodec.inspect material
        in {workspace=workspace,identity= #source links,bytes= #bytes saved,
          encoding= #encoding saved}end;
    end;
    structure CheckedInputs=Veri7vn_Checked_Recovery_Input_Pool(Check);
    datatype roots=Captured of L.input*L.lease | Recovered of Inputs.lease;
    datatype owner=Owner of {material:SearchCodec.material,workspace:string,roots:roots} option Synchronized.var;
    fun get(Owner cell)=case Synchronized.value cell of SOME payload=>payload|
      NONE=>error "Search original-source owner released";
    fun root_input(Captured(input,_))=input|root_input(Recovered lease)=Inputs.input lease;
    fun drop(Captured(_,lease))=Option.app I.release_disposed_input(L.release lease)
      |drop(Recovered lease)=Inputs.release lease;
  in
    type owner=owner;
    fun material owner= #material(get owner);
    fun input owner=
      let val {material,roots,...}=get owner;
        val actual=root_input roots;val saved= #saved(SearchCodec.inspect material);
        val _=require(L.retained actual andalso L.bytes actual= #bytes saved andalso
          L.encoding actual= #encoding saved) "Search retained original bytes changed"
      in actual end;
    fun live owner=(ignore(input owner);true)handle ERROR _=>false;
    fun release(Owner cell)=Thread_Attributes.uninterruptible_body(fn _=>
      Synchronized.change cell(fn NONE=>NONE|SOME{roots,...}=>(drop roots;NONE)));
    fun fragment owner=case #roots(get owner)of Recovered lease=>Inputs.fragment lease|
      Captured _=>error "Fresh Search original already has its native source identity";
    fun capture_into target context request names phase=
      Thread_Attributes.uninterruptible_body(fn _=>
      let val _=require(is_none(!target)) "Search original-source target occupied";
        val material=SearchCodec.snapshot context request names phase;
        val original=P.source_input(SearchRequest.source request);
        val child=the(SearchRequest.native_scope request);
        val ids=RequestScope.allocator(RequestScope.parent child);
        val {links,saved,...}=SearchCodec.inspect material;
        val _=require(#context links= #receiver links andalso #worker links= #receiver links andalso
          I.lookup_input_identity ids original=SOME(#source links) andalso
          L.bytes original= #bytes saved andalso L.encoding original= #encoding saved)
          "Search original-source native association differs";
        val lease=L.retain original;
        val owner=Owner(Synchronized.var "search_retained_original_source"(SOME
          {material=material,workspace=I.workspace ids,roots=Captured(original,lease)}));
        val _=target:=SOME owner
      in owner end);
    fun restore_into target pool ids image pin committed=
      let val material=SearchCodec.verify image pin committed;
        val {names,...}=SearchCodec.inspect material;
        val workspace= #workspace(C.materials committed);
        (* This is checked before any native bytes are acquired. It verifies
           the immutable original request and exact optional consumed charge,
           plus continuing source access, independently of active-child status. *)
        val _=require(workspace=I.workspace ids andalso Inputs.pool_workspace pool=workspace andalso
          Checkpoint.source_matches committed(projection material)names(phase material))
          "Search inert original differs from current retained source requirement";
        val checked=Checked{material=material,workspace=workspace}
      in Thread_Attributes.uninterruptible_body(fn _=>
        let val _=require(is_none(!target)) "Search restored original-source target occupied";
          val lease=CheckedInputs.acquire pool checked;
          val owner=Owner(Synchronized.var "search_restored_original_source"(SOME
            {material=material,workspace=workspace,roots=Recovered lease}));
          val _=target:=SOME owner
        in owner end)end;
  end;
end;
