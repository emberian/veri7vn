theory Finite_Scoped_Checks
  imports "Veri7vn_Finite_Runtime.Finite_Scoped_Request"
begin
ML \<open>
local
  structure F=Veri7vn_Finite_Scoped_Request;
  structure X=Veri7vn_Finite_Execution;
  structure S=Veri7vn_Native_Request_Scope;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  val ids=I.install_host_block{workspace="61616161616161616161616161616161",first=1,past=1000};
  val policy=A.policy @{theory};
  val text="population variance of 0, 2";
  val original=L.input{bytes=text,encoding="UTF-8"};
  val source=P.install_host_source ids original;
  val slice=L.slice original{start=0,stop=size text,expected=text};
  val parent=S.new_parent{allocator=ids,policy=policy,observation=S.StateTimeUnused,inputs=[original]};
  val first=S.new_child parent{source=slice,predecessors=[]};
  val second=S.new_child parent{source=slice,predecessors=[first]};
  val development=P.public_image ids policy;
  fun ready(X.Ready value)=value | ready(X.Refused _)=error "Finite scoped native execution refused";
  val instance=ready(X.attach{policy=policy,generation=P.generation development,
    code_context=Veri7vn_Executable_Identity.code_theory(X.executable()),
    limits={nodes=5000,depth=100,seconds=2}});
  fun arguments child owner={child=child,instance=instance,development=development,source=owner};
  val request=F.prepare_child(arguments first source);
  val output=ready(X.execute(X.executable())instance(F.family_request request));
  val result=F.associate request output;
  val _=case F.view result of F.Answer value=>
      if fastype_of(Thm.term_of value)= @{typ finite_value} then ()else error "Finite structured value carrier differs"
    | F.Rejected=>error "Finite literal statistics rejected"
    | F.Incomplete=>error "Explicit literal list incorrectly marked incomplete";
  val _=if L.same_input(L.owner(F.original request),original) andalso
      F.convention request="population; denominator n" then ()
    else error "Finite original/convention detached";
  fun refuses f=if can f()then error "Invalid finite scoped association accepted"else ();
  val _=refuses(fn()=>F.prepare_child(arguments first source));
  val foreign=L.input{bytes=text,encoding="UTF-8"};
  val foreign_source=P.install_host_source ids foreign;
  val _=refuses(fn()=>F.prepare_child(arguments second foreign_source));
  val _=Option.app I.release_disposed_input(L.drop_base foreign);
  val request2=F.prepare_child(arguments second source);
  val _=refuses(fn()=>F.associate request2 output);
  val _=if forall(fn id=>member(op =)(F.dependencies request2)id)
      [#request(F.identity request2),#goal(F.identity request2),#goal(F.identity request)]
    then ()else error "Finite predecessor provenance lost";
  val _=ignore(S.seal parent[first,second]);
  val _=List.app S.release_child[first,second];
  val _=S.release_parent parent;
  val _=if F.result_live result then ()else error "Finite producer disposal erased retained source";
  val _=S.deny parent;
  val _=if F.live request orelse F.result_live result then error "Finite denied parent remained accessible"else ();
  val _=F.release_result result;
  val _=F.release request;
  val _=F.release request2;
  val _=X.release_instance instance;
  val _=Option.app I.release_disposed_input(L.drop_base original);
  val _=P.release development;
in val _=writeln "VERI7VN_FINITE scoped_original_statistics PASS" end
\<close>
end
