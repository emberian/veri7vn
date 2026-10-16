theory Search_Service_Tests
  imports Veri7vn_Search_Service.Search_Service
begin
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Search_Fn(T);
  structure S=W.Search;
  structure Q=Veri7vn_Search_Request_Fn(S);
  fun bytes ns=String.implode(map Char.chr ns);
  val _=if forall Veri7vn_Search_UTF8.valid
      ["", "ASCII",bytes[194,128],bytes[224,160,128],bytes[237,159,191],
       bytes[238,128,128],bytes[240,144,128,128],bytes[244,143,191,191]] andalso
    forall (not o Veri7vn_Search_UTF8.valid)
      [bytes[128],bytes[192,128],bytes[193,191],bytes[194],bytes[224,159,191],
       bytes[237,160,128],bytes[240,143,191,191],bytes[244,144,128,128],bytes[245,128,128,128]]
    then () else error "Search strict UTF8 boundary validation failed";
  val ids=I.install_host_block{workspace="22222222222222222222222222222222",
    first=3000000000000000000000000000000,past=3000000000000000000000000010000};
  val receiver=P.public_image ids (A.policy @{theory});
  val worker=P.context_alias receiver;
  val input=L.input{bytes="prefix P --> (P & P) suffix",encoding="UTF-8"};
  val source=P.install_host_source ids input;
  val slice=L.slice input{start=7,stop=20,expected="P --> (P & P)"};
  val instance=S.qualify{expansions=100,frontier=100,successors=2,milliseconds=5000};
  val request_scope=Q.construction_scope();
  val request=Q.prepare_owned request_scope instance{receiver=receiver,worker=worker,source=source,slice=slice,
    facts=[P.public_theorem receiver ("HOL.TrueI",0)],
    actions=[S.Apply 0,S.Introduce,S.Split,S.Assume]};
  val saved=Q.snapshot request;
  val _=if #bytes saved="prefix P --> (P & P) suffix" andalso #start saved=7 andalso #stop saved=20
      andalso #encoding saved="UTF-8" andalso Q.live request then ()
    else error "Search request lost original proposition span";
  val restored=Q.restore_owned request_scope instance saved{receiver=receiver,worker=worker,source=source,
    facts=[P.public_theorem receiver ("HOL.TrueI",0)]};
  val _=if Q.live restored andalso Thm.term_of(Q.target restored) aconv Thm.term_of(Q.target request)
    then () else error "Restored search changed original native target";
  val _=Q.release restored;
  val scope_parent=Veri7vn_Native_Request_Scope.new_parent
    {allocator=ids,policy=A.policy @{theory},observation=Veri7vn_Native_Request_Scope.StateTimeUnused,
      inputs=[input]};
  val scope_child=Veri7vn_Native_Request_Scope.new_child scope_parent{source=slice,predecessors=[]};
  val scoped=Q.prepare_child_owned request_scope instance scope_child
    {receiver=receiver,worker=worker,source=source,facts=[],actions=[S.Introduce,S.Split,S.Assume]};
  val _=if Q.project_scope scoped=SOME(Veri7vn_Native_Request_Scope.identity scope_child)
      andalso Q.cost scoped>0 then () else error "Search child lost opaque native scope";
  val _=Veri7vn_Native_Request_Scope.seal scope_parent[scope_child];
  val owned_child=the(Q.native_scope scoped);
  val _=Veri7vn_Native_Request_Scope.release_child scope_child;
  val _=if Q.live scoped andalso Veri7vn_Native_Request_Scope.child_live owned_child then ()
    else error "Producer child release revoked independent search view";
  val _=Q.release scoped;
  val _=if Veri7vn_Native_Request_Scope.child_live owned_child then
    error "Released search retained its native child view" else ();
  val _=Veri7vn_Native_Request_Scope.release_parent scope_parent;
  val issuer=T.new_issuer();
  val ticket_scope=T.begin_scope issuer{owner_version=1,epoch=1};
  val prepared=Q.prepared request;
  val identity={execution=1,slot=2,operation={workspace=I.workspace ids,request=3,
    profile=4,code_generation=5,operation=6,step=1,cost=S.cost prepared,
    inputs=Q.dependencies request,owner_version=1,epoch=1,journal_sequence=1,
    semantic_generation=7,implementation_artifact=replicate_string 64 "b"}};
  val job=W.start(T.issue_pure ticket_scope identity
    {instance=instance,request=prepared,operation=S.operation instance,
     executable=S.executable instance,generation=P.generation worker,
     receiver=P.generation receiver});
  val output=W.join job;
  val _=if can Q.prepared request then error "Joined search exposed reusable prepared input" else ();
  val _=if Q.cost request= #cost(#operation identity) then ()
    else error "Joined search lost original charged cost";
  val wire=case #outcome(W.report output) of S.ProofProposal bytes=>bytes
    | _=>error "Managed original proof search produced no proposal";
  val construction=P.construction_scope();
  val (proved,consequence)=Q.prove_owned construction request wire;
  val _=if Thm.prop_of(A.theorem(P.accepted consequence)) aconv Thm.term_of(Q.target request)
      andalso member(op =)(P.source_dependencies consequence)(P.source_identity source)
      andalso is_some(P.proof_recipe proved) then ()
    else error "Search managed consequence lost original source/full target";
  val _=W.release_output output;
  val _=T.close_scope ticket_scope;
  val _=P.abort_scope construction;
  val _=if P.is_live consequence then error "Aborted proof construction remained live" else ();
  val _=writeln "SEARCH original_source_managed_proof_consequence PASS";
  val _=L.drop_base input;
  val _=if L.retained input andalso Q.live request then ()
    else error "Search request lost its independent source lease";
  val _=L.invalidate input;
  val _=if Q.live request then error "Invalidated original target remained live" else ();
  val _=Q.abort_scope request_scope;
  val _=if L.disposed input andalso not(Q.live request) then ()
    else error "Search request retained released original input";
  val _=S.release_instance instance;
  val _=P.release worker;
  val _=P.release receiver;
in val _=writeln "SEARCH original_source_span_owner_lifecycle PASS" end
\<close>
end
