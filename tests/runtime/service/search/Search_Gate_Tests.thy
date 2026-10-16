theory Search_Gate_Tests
  imports Search_Protocol_Tests
begin
ML_file "../../../../src/runtime/service/search/native_search_gate.ML"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Search_Fn(T);
  structure S=W.Search;
  structure Q=Veri7vn_Search_Request_Fn(S);
  structure G=Veri7vn_Search_Gate_Fn(Q);
  fun assert true _=() | assert false message=error message;
  fun reconstruct scope request wire=
    let val target=Unsynchronized.ref NONE;
      val result=Exn.capture(fn()=>G.reconstruct_into target scope request wire)();
    in case result of Exn.Res witness=>
        (assert(is_some(!target)) "Search gate did not register typed cleanup before handoff";witness)
      | Exn.Exn failure=>(Option.app G.release(!target);Exn.reraise failure)end;
  val ids=I.install_host_block{workspace="33333333333333333333333333333333",
    first=5000000000000000000000000000000,past=5000000000000000000000000010000};
  val policy=A.policy @{theory};
  val receiver=P.public_image ids policy;
  val input=L.input{bytes="  P --> (P & P)  \n",encoding="UTF-8"};
  val source=P.install_host_source ids input;
  val parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[input]};
  val child=Scope.new_child parent{source=L.slice input{start=0,stop=size(L.bytes input),expected=L.bytes input},predecessors=[]};
  val qscope=Q.construction_scope();
  val instance=S.qualify{expansions=100,frontier=100,successors=2,milliseconds=5000};
  val request=Q.prepare_child_owned qscope instance child
    {receiver=receiver,worker=receiver,source=source,facts=[],actions=[S.Introduce,S.Split,S.Assume]};
  val _=Scope.seal parent[child];
  val issuer=T.new_issuer();
  val tScope=T.begin_scope issuer{owner_version=1,epoch=1};
  val identity={execution=1,slot= #slot(Scope.identity child),operation={workspace=I.workspace ids,
    request= #request(Scope.identity child),profile=4,code_generation=5,operation=6,step=1,
    cost=Q.cost request,inputs=Q.dependencies request,owner_version=1,epoch=1,journal_sequence=1,
    semantic_generation=I.generation_id ids(P.generation receiver),implementation_artifact=replicate_string 64 "b"}};
  val job=W.start(T.issue_pure tScope identity
    {instance=instance,request=Q.prepared request,operation=S.operation instance,
     executable=S.executable instance,generation=P.generation receiver,receiver=P.generation receiver});
  val output=W.join job;
  val wire=case #outcome(W.report output) of S.ProofProposal bytes=>bytes
    | _=>error "Fixed scoped search produced no native proof proposal";
  val pscope=P.construction_scope();
  val witness=reconstruct pscope request wire;
  val projection=G.project witness;
  val _=assert(#receiver_semantic projection<> #proof_semantic projection)
    "Search erased separate source proof-development generation";
  val _=assert(R.same_generation(A.generation(G.accepted witness),P.generation receiver))
    "Search did not re-admit into actual immutable receiver generation";
  val _=assert(Thm.prop_of(A.theorem(G.accepted witness)) aconv Thm.term_of(Q.target request))
    "Search receiver admission lost the full original target";
  val _=assert(#identity projection=Scope.identity child andalso
    #bytes(G.snapshot witness)="  P --> (P & P)  \n") "Search gate lost exact child/original bytes";
  val _=assert(not(can (reconstruct pscope request) "not a proof term"))
    "Search gate accepted malformed worker wire";
  val other_input=L.input{bytes="True",encoding="UTF-8"};
  val other_source=P.install_host_source ids other_input;
  val other_parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[other_input]};
  val other_child=Scope.new_child other_parent{source=L.slice other_input
    {start=0,stop=4,expected="True"},predecessors=[]};
  val other_request=Q.prepare_child_owned qscope instance other_child
    {receiver=receiver,worker=receiver,source=other_source,facts=[],actions=[S.Assume]};
  val _=Scope.seal other_parent[other_child];
  val _=assert(not(can (reconstruct pscope other_request) wire))
    "Search gate accepted a valid proof of another literal target";
  val _=G.release witness;
  val _=assert(P.development_live receiver andalso Q.live request andalso not(G.live witness))
    "Search gate release damaged shared receiver or retained released witness";
  val _=P.abort_scope pscope;
  val denied_scope=P.construction_scope();
  val second=reconstruct denied_scope request wire;
  val retained=G.retain second;
  val _=P.commit_scope denied_scope;
  val _=Scope.deny parent;
  val _=assert(not(G.active_live second) andalso not(can G.request second) andalso
    G.live retained andalso #bytes(G.snapshot retained)="  P --> (P & P)  \n")
    "Inactive child either retained execution permission or destroyed independent proof provenance";
  val _=G.release second;
  val _=assert(not(can G.retain second)andalso G.live retained)
    "Released proof view was re-retained through a live sibling root";
  val _=P.abort_scope denied_scope;
  val _=Q.abort_scope qscope;
  val _=assert(G.live retained andalso
    R.same_generation(A.generation(G.accepted retained),P.generation receiver))
    "Execution scope retirement destroyed counted native proof view";
  val _=G.release retained;
  val _=assert(not(G.live retained) andalso P.development_live receiver)
    "Last proof view retained its root or released shared receiver";
  val _=Scope.release_child child;
  val _=Scope.release_parent parent;
  val _=Scope.release_child other_child;
  val _=Scope.release_parent other_parent;
  val _=Option.app I.release_disposed_input(L.drop_base input);
  val _=Option.app I.release_disposed_input(L.drop_base other_input);
  val _=W.release_output output;
  val _=S.release_instance instance;
  val _=P.release receiver;
  val _=writeln "VERI7VN_SEARCH_NATIVE_GATE_TESTS_PASSED";
in end
\<close>
end
