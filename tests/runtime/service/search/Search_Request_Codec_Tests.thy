theory Search_Request_Codec_Tests
  imports Search_Gate_Tests
begin
ML_file "../../../../src/runtime/service/search/native_search_request_codec.ML"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Search_Fn(T);
  structure S=W.Search;
  structure Q=Veri7vn_Search_Request_Fn(S);
  structure Codec=Veri7vn_Search_Request_Codec_Fn(structure S=S structure Q=Q);
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  fun assert true _=() | assert false message=error message;
  val ids=I.install_host_block{workspace="44444444444444444444444444444444",
    first=7000000000000000000000000000000,past=7000000000000000000000000010000};
  val policy=A.policy @{theory};
  val receiver=P.public_image ids policy;
  val input=L.input{bytes="  P --> (P & P)  \n",encoding="UTF-8"};
  val source=P.install_host_source ids input;
  val parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[input]};
  val child=Scope.new_child parent{source=L.slice input{start=0,stop=size(L.bytes input),expected=L.bytes input},predecessors=[]};
  val qscope=Q.construction_scope();
  val instance=S.qualify{expansions=1,frontier=16,successors=2,milliseconds=5000};
  val request=Q.prepare_child_owned qscope instance child
    {receiver=receiver,worker=receiver,source=source,facts=[],actions=[S.Introduce,S.Split,S.Assume]};
  val _=Scope.seal parent[child];
  val context=I.generation_id ids(P.generation receiver);
  val names=Codec.names_of_values(map(fn _=>I.allocate ids)(1 upto 17));
  val pending=Codec.snapshot context request names(Codec.Pending NONE);
  val encoded=Codec.encode pending;
  val decoded=Codec.inspect(Codec.decode encoded);
  val _=assert(#bytes(#saved decoded)=L.bytes input andalso #scope_identity(#saved decoded)=SOME(Scope.identity child) andalso
    #cost(#links decoded)=Q.cost request andalso Codec.execution(#phase decoded)=NONE)
    "Search request codec lost exact source/child/cost or invented a dispatch";
  val issuer=T.new_issuer();
  val tscope=T.begin_scope issuer{owner_version=1,epoch=1};
  val identity={execution= #execution names,slot= #slot(Scope.identity child),operation={workspace=I.workspace ids,
    request= #request(Scope.identity child),profile= #profile names,code_generation= #code names,
    operation= #operation names,step= #step names,
    cost=Q.cost request,inputs=Q.dependencies request,owner_version=1,epoch=1,journal_sequence=1,
    semantic_generation=context,implementation_artifact=replicate_string 64 "b"}};
  val job=W.start(T.issue_pure tscope identity
    {instance=instance,request=Q.prepared request,operation=S.operation instance,
      executable=S.executable instance,generation=P.generation receiver,receiver=P.generation receiver});
  val output=W.join job;
  val report=W.report output;
  val phase=Codec.stopped request{execution= #execution names,reason= #budget names,
    diagnostic="Budget reached; the proposition remains unresolved.",report=report};
  val stopped=Codec.decode(Codec.encode(Codec.snapshot context request names phase));
  val _=case #phase(Codec.inspect stopped) of Codec.Stopped{stop=Codec.Budget,execution,reason,...}=>
      assert(execution= #execution names andalso reason= #budget names) "Search codec changed producer names"
    | _=>error "Search codec changed actual worker budget outcome/lineage/reason";
  val image=Veri7vn_Native_Recovery_Check.install_host_image policy "fixed-search-request-test-image/1";
  val exported=Codec.export image context request names phase;
  val committed=Veri7vn_Committed_Native_Recovery.install_committed_host
    {workspace=I.workspace ids,journal_sequence=1,association= #association exported,
     semantic_generation= #semantic_generation exported,checkpoint="request codec fixture",
     manifest= #manifest exported,projection= #projection exported,sequent= #sequent exported,
     context_closure= #context_closure exported,reconstruction= #reconstruction exported};
  val checked=Codec.verify image(Q.executable request)committed;
  val _=assert(#sequent exported="" andalso
    Codec.execution(#phase(Codec.inspect checked))=SOME(#execution names))
    "Search stopped request role became assertional or lost consumed execution";
  val wrong_pin=Veri7vn_Executable_Identity.pin @{theory}
    {artifact="wrong-search-executable",compiler="fixture",target="PolyML",serializers=[],foreign_primitives=[],settings=[]};
  val _=assert(not(can (Codec.verify image wrong_pin)committed))
    "Search request recovery accepted changed executable pin";
  val _=Veri7vn_Committed_Native_Recovery.release committed;
  val _=assert(not(can Q.prepared request)) "Decoding stopped material recreated executable prepared input";
  val interrupted=Codec.decode(Codec.encode(Codec.snapshot context request names(Codec.Pending(SOME(#execution names)))));
  val _=assert(Codec.execution(#phase(Codec.inspect interrupted))=SOME(#execution names))
    "Search pending codec erased consumed execution; restart could replay it";
  val _=assert(not(can Codec.decode(encoded ^ "junk"))) "Search codec accepted trailing material";
  val _=assert(not(can Codec.encode(Codec.snapshot context request names(Codec.Pending(SOME 1)))))
    "Search codec accepted a substituted consumed execution";
  val wrong_reason=Codec.stopped request{execution= #execution names,reason= #exhausted names,diagnostic="",report=report};
  val _=assert(not(can Codec.encode(Codec.snapshot context request names wrong_reason)))
    "Search codec accepted a substituted terminal reason association";
  val _=assert(not(can (Codec.failed){execution=0,reason=2,diagnostic="failure"}))
    "Search stopped material accepted absent execution identity";
  val _=assert(not(can (Codec.stopped request){execution=1,reason=2,diagnostic="",
    report={outcome=S.ProofProposal "inert",trace=[],remaining=[],expansions=0}}))
    "Search request observation manufactured a proof-output role";
  val long=Free(replicate_string 4096 "x",@{typ bool});
  val (snippet,truncated)=Wire.term_projection long;
  val _=assert(size snippet<=256 andalso truncated) "Search trace expanded long term before projection";
  val _=assert(not(can (Codec.term_bound 256)long)) "Search term codec ignored serialized name bytes";
  val overflow_refused=(Codec.preflight_target[XML.Elem(("3",[]),[XML.Text "99999999999999999999"])];false)
    handle ERROR _=>true | Overflow=>error "Search target preflight leaked integer Overflow";
  val _=assert overflow_refused "Search target XML admitted an oversized native index";
  val deep_type=funpow 66(fn T=>Type("fun",[T,@{typ bool}])) @{typ bool};
  val _=assert(not(can Codec.preflight_target(Term_XML.Encode.term_raw(Free("x",deep_type)))))
    "Search target type depth was decoded before preflight refusal";
  val _=W.release_output output;
  val _=Q.abort_scope qscope;
  val _=Scope.release_child child;
  val _=Scope.release_parent parent;
  val _=Option.app I.release_disposed_input(L.drop_base input);
  val _=S.release_instance instance;
  val _=P.release receiver;
  val _=writeln "VERI7VN_SEARCH_REQUEST_CODEC_TESTS_PASSED";
in end
\<close>
end
