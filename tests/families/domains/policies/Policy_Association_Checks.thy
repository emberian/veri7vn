theory Policy_Association_Checks
  imports "Veri7vn_Policy_Checked_Display.Policy_Checked_Display"
begin
ML \<open>
local
  structure C=Veri7vn_Domain_Conditions;
  structure D=Veri7vn_Policy_Request;
  structure S=Veri7vn_Scoped_Policy_Request;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure M=Veri7vn_Policy_Execution;
  structure V=Veri7vn_Policy_Display;
  structure G=Veri7vn_Policy_Native_Gate;
  structure P=Veri7vn_Managed_Provenance;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure A=Veri7vn_Native_Admission;
  val ids=IDs.install_host_block{workspace="77777777777777777777777777777777",first=1,past=1000};
  val policy=A.policy @{theory};
  val development=P.public_image ids policy;
  fun owned text=let val owner=L.input{bytes=text,encoding="UTF-8"}
    in(owner,P.install_host_source ids owner,L.slice owner{start=0,stop=size text,expected=text})end;
  val(condition_owner,condition_source,condition_slice)=owned "selected_policy_applies";
  val condition=C.prepare{allocator=ids,development=development,source=condition_source,
    slice=condition_slice,role=C.InputCondition,proposition= @{cprop "selected_policy_applies"}};
  fun ready(M.Ready x)=x | ready(M.Refused _)=error "Policy association execution refused";
  val instance=ready(M.attach{policy=policy,generation=P.generation development,
    code_context=Veri7vn_Executable_Identity.code_theory(M.executable()),limits={nodes=10000,depth=200,seconds=3}});
  val text="registered_policy_dispatch (PolicyCall (ibc_2021_recipe Business [" ^
    IntInf.toString(C.identity condition) ^ "]) (Some ''IBC-2021-Table-1004.5'') " ^
    "(OccupancyInput GrossArea (PolicyFraction 151 1)) [])";
  val(owner,source,slice)=owned text;
  val input=Thm.cterm_of @{context}(Syntax.read_term @{context} text);
  fun raw conditions=D.prepare{allocator=ids,instance=instance,development=development,
    source=source,slice=slice,input=input,conditions=conditions};
  val _=if can(fn()=>raw [])()then error "Policy recipe premise lost native association"else ();
  val parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[owner]};
  val child=Scope.new_child parent{source=slice,predecessors=[]};
  val request=S.prepare_child{child=child,instance=instance,development=development,
    source=source,input=input,conditions=[condition]};
  val output=ready(M.execute(M.executable())instance(S.family_request request));
  val bridge=V.attach{allocator=ids,policy=policy,instance=instance};
  val witness=G.specialize bridge request output;
  val projection=G.display witness;
  val _=if map Thm.term_of(G.assumptions witness)=[Thm.term_of(C.proposition condition)]
    andalso map #identity(#conditions projection)=[C.identity condition]
    andalso map #owner_identity(#conditions projection)=[C.owner_identity condition]
    andalso String.isSubstring "assuming all 1 attached premises" (#statement_html projection)
    andalso String.isSubstring "occupant load 2" (#statement_html projection)
    then ()else error "Policy report lost full assumption/source/value correspondence";
  val retained=G.retain witness;
  val saved=G.snapshot retained;
  val _=if G.matches_snapshot retained saved then ()else error "Policy retained snapshot changed";
  val _=C.drop_base condition;
  val _=if G.live retained then ()else error "Policy producer disposal destroyed retained assumption";
  val _=C.release condition;
  val _=if G.live retained then error "Policy assumption invalidation left answer licensed"else ();
  val _=G.release retained;
  val _=G.release witness;
  val _=V.release bridge;
  val _=S.release request;
  val _=ignore(Scope.seal parent[child]);
  val _=Scope.release_child child;
  val _=Scope.release_parent parent;
  val _=M.release_instance instance;
  val _=Option.app IDs.release_disposed_input(L.drop_base owner);
  val _=Option.app IDs.release_disposed_input(L.drop_base condition_owner);
  val _=P.release development;
in val _=writeln "POLICY_ASSOCIATION_CHECKS_PASS" end;
\<close>
end
