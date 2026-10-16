theory Scoped_Domain_Checks
  imports "Veri7vn_Scoped_Domain.Scoped_Domain_Request"
begin
ML \<open>
local
  structure S=Veri7vn_Scoped_Domain_Request;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure M=Veri7vn_Domain_Execution;
  structure E=Veri7vn_Executable_Identity;
  val ids=IDs.install_host_block{workspace="55555555555555555555555555555555",first=1,past=1000};
  val policy=A.policy @{theory};
  val text="registered_domain_dispatch (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 2] [] None)";
  val original=L.input{bytes=text,encoding="UTF-8"};
  val source=P.install_host_source ids original;
  val slice=L.slice original{start=0,stop=size text,expected=text};
  val parent=Scope.new_parent{allocator=ids,policy=policy,observation=Scope.StateTimeUnused,inputs=[original]};
  val first_child=Scope.new_child parent{source=slice,predecessors=[]};
  val second_child=Scope.new_child parent{source=slice,predecessors=[first_child]};
  val cancelled_child=Scope.new_child parent{source=slice,predecessors=[]};
  val development=P.public_image ids policy;
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Scoped domain execution refused";
  val instance=ready(M.attach{policy=policy,generation=P.generation development,
    code_context=E.code_theory(M.executable()),limits={nodes=5000,depth=100,seconds=2}});
  val input= @{cterm "registered_domain_dispatch (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 2] [] None)"};
  fun arguments child source={child=child,instance=instance,development=development,
    source=source,input=input,conditions=[]}:S.preparation;
  val first=S.prepare_child(arguments first_child source);
  val first_output=ready(M.execute(M.executable())instance(S.family_request first));
  fun refuses f=if can f()then error "Invalid scoped domain ownership accepted"else ();
  val _=refuses(fn()=>S.prepare_child(arguments first_child source));
  val foreign_owner=L.input{bytes=text,encoding="UTF-8"};
  val foreign_source=P.install_host_source ids foreign_owner;
  val _=refuses(fn()=>S.prepare_child(arguments second_child foreign_source));
  val _=Option.app IDs.release_disposed_input(L.drop_base foreign_owner);
  val second=S.prepare_child(arguments second_child source);
  val _=refuses(fn()=>S.specialize second first_output);
  val _=if S.matches_snapshot first(S.snapshot first) andalso
    not(S.matches_snapshot second(S.snapshot first)) andalso
    forall(fn id=>member(op =)(S.managed_dependencies second)id)
      [#request(S.identity second),#goal(S.identity second),#slot(S.identity second),#goal(S.identity first)]
    then ()else error "Scoped domain lost original identity/dependency correspondence";
  val cancelled_root=Unsynchronized.ref(NONE:S.request option);
  val cancellation=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=restore(fn()=>ignore(S.prepare_child_into(arguments cancelled_child source)cancelled_root))()
    in restore(fn()=>raise Thread.Thread.Interrupt)()end)())();
  val _=case cancellation of Exn.Exn exn=>if Exn.is_interrupt exn then ()else Exn.reraise exn
    | Exn.Res _=>error "Scoped domain rollback did not interrupt";
  val _=case !cancelled_root of SOME r=>S.release r
    | NONE=>error "Scoped domain cancellation lost cleanup root";
  val _=ignore(Scope.seal parent[first_child,second_child,cancelled_child]);
  val _=List.app Scope.release_child[first_child,second_child,cancelled_child];
  val _=Scope.release_parent parent;
  val _=if S.live first andalso S.live second then(ignore(S.specialize first first_output);())
    else error "Producer disposal destroyed retained scoped domain consumers";
  val _=Scope.deny parent;
  val _=if S.live first orelse S.live second then error "Denied parent retained domain access"else ();
  val _=S.release first;
  val _=S.release second;
  val _=M.release_instance instance;
  val _=Option.app IDs.release_disposed_input(L.drop_base original);
  val _=P.release development;
in val _=writeln "VERI7VN_DOMAINS scoped_request PASS" end;
\<close>
end
