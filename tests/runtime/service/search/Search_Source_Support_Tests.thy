theory Search_Source_Support_Tests
  imports Search_Source_Tests
begin
ML \<open>
structure SearchSourceSupportFixture =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure A=Veri7vn_Native_Admission;
  structure V=Veri7vn_Native_Recovery_Check;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure RequestScope=Veri7vn_Native_Request_Scope;
  structure Tickets=Veri7vn_Private_Operation_Tickets();
  structure Worker=Veri7vn_Search_Fn(Tickets);
  structure SearchCore=Worker.Search;
  structure SearchRequest=Veri7vn_Search_Request_Fn(SearchCore);
  structure SearchCodec=Veri7vn_Search_Request_Codec_Fn(structure S=SearchCore structure Q=SearchRequest);
  structure SearchWire=Veri7vn_Search_Protocol_Fn(SearchCore);
  structure Source=Veri7vn_Search_Source_Fn(structure S=SearchCore structure Q=SearchRequest);
end;
open SearchSourceSupportFixture;
\<close>
ML_file "../../../../src/runtime/service/search/native_search_source_support.inc.ML"
ML \<open>
local
  open SearchSourceSupportFixture;
  fun assert true _=()|assert false message=error message;
  fun nat n=Veri7vn_Numerals.nat_of_integer n;
  fun integer n=Veri7vn_Numerals.integer_of_nat n;
  fun checkpoint state=Veri7vn_Native_Authority_Wire.write_with
    (fn @{code WireNat} number=>Veri7vn_Native_Authority_Wire.Natural(integer number)
      | @{code WireNode}(tag,children)=>Veri7vn_Native_Authority_Wire.Branch(integer tag,children))
      (@{code encode_checkpoint}state);
  fun accept state event=
    let val(next,commands)= @{code step}state event
    in case commands of []=>next|[@{code RunPure} _]=>next|
      [@{code Persist} batch]=>
        let val(final,visible)= @{code step}next(@{code DurableAck}
          (@{code batch_id}batch,@{code Suc}(@{code expected_revision}batch),@{code batch_epoch}batch))
        in case visible of [@{code Visible} _]=>final|_=>error "Source support durable acknowledgement refused"end
      |_=>error "Source support metadata producer refused"end;
  val ids=I.install_host_block{workspace="77777777777777777777777777777777",
    first=12000000000000000000000000000000,past=12000000000000000000000000010000};
  val policy=A.policy @{theory};
  val public=P.public_image ids policy;
  val context=Source.bind_public ids policy public;
  val header=SearchWire.document(SearchWire.node "search-policy"[("version","1"),
    ("context",IntInf.toString(Source.context context)),("expansions","8"),("frontier","8"),
    ("successors","2"),("milliseconds","5000")]
    [SearchWire.node "catalogue"[][],SearchWire.node "actions"[][SearchWire.action_xml SearchCore.Assume]]);
  val digits=string_of_int(size header);
  val original="  P --> P  \n";
  val source_root=Unsynchronized.ref NONE;
  val source=Source.prepare_into source_root context(replicate_string(8-size digits)"0"^digits^"\n"^header^original);
  val q=Source.request source;val p=Source.project source;val n=Source.names source;val i= #identity p;
  val values=[#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
    #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,#execution n,#code n,
    #evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
  val control= @{code search_service_control}(map nat values);
  val deps=distinct(op =)[#parameter n,#capability n,#operation n,#profile n,#code n,#template n,
    #input p,#receiver p,#interpretation i,#decision i];
  val reserved=accept @{code initial_state}(@{code search_service_reserve}control
    (@{code revision} @{code initial_state})(nat(#cost p))(map nat deps));
  val(unstarted,_)= @{code step}reserved(@{code CancelRequest}(nat(#request i)));
  val supported=fold(fn id=>fn state=>accept state(if id= #input p then @{code search_service_input}control
      else @{code search_service_intrinsic}(nat id)))
    (filter(fn id=>id<> #parameter n andalso id<> #output n)values)reserved;
  val parameter=accept supported(@{code search_service_parameter}control(map nat deps));
  val charged=accept parameter(@{code search_service_execute}control(nat(#cost p)));
  val(cancelled,_)= @{code step}charged(@{code CancelRequest}(nat(#request i)));
  val image=V.install_host_image policy "fixed-search-source-support/1";
  val pin=SearchRequest.executable q;
  val unstarted_material=SearchCodec.export image(#context p)q n(SearchCodec.Pending NONE);
  val charged_material=SearchCodec.export image(#context p)q n(SearchCodec.Pending(SOME(#execution n)));
  fun commit state(material:SearchCodec.artifacts)=C.install_committed_host
    {workspace=I.workspace ids,journal_sequence=1,association= #association material,
      semantic_generation= #semantic_generation material,checkpoint=checkpoint state,
      manifest= #manifest material,projection= #projection material,sequent= #sequent material,
      context_closure= #context_closure material,reconstruction= #reconstruction material};
  val unstarted_cap=commit unstarted unstarted_material;
  val charged_cap=commit cancelled charged_material;
  val wrong_charge=commit cancelled unstarted_material;
  val retained_root=Unsynchronized.ref NONE;
  val retained=SearchSourceSupport.capture_into retained_root(#context p)q n(SearchCodec.Pending(SOME(#execution n)));
  val input=SearchSourceSupport.input retained;
  val _=Source.deny source;val _=Source.release source;
  val _=assert(SearchSourceSupport.live retained andalso L.bytes input=original)
    "Cancellation/active source cleanup destroyed independently retained original literal";
  val _=SearchSourceSupport.release retained;
  val _=assert(L.disposed input andalso I.lookup_input_identity ids input=NONE)
    "Final original-source release retained native bytes or identity";
  val pool=Veri7vn_Native_Recovery_Inputs.create ids;
  val bad=Unsynchronized.ref NONE;
  val _=assert(not(can(SearchSourceSupport.restore_into bad pool ids image pin)wrong_charge)andalso is_none(!bad))
    "Cancelled source recipe fabricated a missing consumed execution";
  val first_root=Unsynchronized.ref NONE;val second_root=Unsynchronized.ref NONE;
  val first=SearchSourceSupport.restore_into first_root pool ids image pin unstarted_cap;
  val second=SearchSourceSupport.restore_into second_root pool ids image pin charged_cap;
  val _=assert(L.same_input(SearchSourceSupport.input first,SearchSourceSupport.input second))
    "Inert source restore allocated a competing input interner";
  val _=I.install_fragments ids[SearchSourceSupport.fragment first];
  val _=Veri7vn_Native_Recovery_Inputs.close pool;
  val _=assert(I.lookup_input_identity ids(SearchSourceSupport.input second)=SOME(#input p)andalso
    #bytes(#saved(SearchCodec.inspect(SearchSourceSupport.material second)))=original)
    "Inert original source changed identity/bytes after fragment publication";
  val(forgotten,_)= @{code step}cancelled(@{code Forget}(nat(#request i)));
  val forgotten_cap=commit forgotten charged_material;
  val denied_pool=Veri7vn_Native_Recovery_Inputs.create ids;
  val forgotten_root=Unsynchronized.ref NONE;
  val _=assert(not(can(SearchSourceSupport.restore_into forgotten_root denied_pool ids image pin)forgotten_cap)andalso
    is_none(!forgotten_root))
    "Forgotten cancelled original was reacquired as source support";
  val _=Veri7vn_Native_Recovery_Inputs.abort denied_pool;
  val _=SearchSourceSupport.release first;val _=SearchSourceSupport.release second;
  val _=List.app C.release[unstarted_cap,charged_cap,wrong_charge,forgotten_cap];
  val _=P.release public;
in val _=writeln "VERI7VN_SEARCH_SOURCE_SUPPORT_TESTS_PASSED" end;
\<close>
end
