theory Growth_Native_Tests
  imports Veri7vn_Growth_Native.Growth_Native
    Veri7vn_Mathematics_Ticket_Execution.Mathematics_Ticket_Execution
begin
ML \<open>
local
  structure G=Veri7vn_Growth_Preparation;
  structure M=Veri7vn_Mathematics_Execution;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Math_Ticket_Execution_Fn(structure Mathematics=M structure Tickets=T);
  val ids=I.install_host_block{workspace="73737373737373737373737373737373",
    first=7300000000000000000000000000000,past=7300000000000000000000000010000};
  val parent=P.public_image ids(A.policy @{theory});
  val pin=M.executable();
  val instance=case M.attach{policy=A.policy @{theory},generation=P.generation parent,
    code_context=E.code_theory pin,limits={nodes=5000,depth=100,work=100,seconds=2}}of
    M.Ready instance=>instance | _=>error "Growth fixture math instance failed";
  val all_inputs=Unsynchronized.ref([]:L.input list);
  fun source text=let val input=L.input{bytes="prefix "^text^" suffix",encoding="UTF-8"}
      val _=all_inputs:=input::(!all_inputs)
      val owner=P.install_host_source ids input
      val slice=L.slice input{start=7,stop=7+size text,expected=text}
    in (owner,slice) end;
  val expression=source "Times (Parameter 0) (Rational 2)";
  val samples=[source "([(0,2::rat)], Some (4::rat))",source "([(0,3::rat)], Some (7::rat))"];
  val request=G.prepare instance{parent=parent,expression=expression,samples=samples,work=100};
  val _=if G.live request andalso length(G.closures request)=2 andalso
      length(G.meanings request)=2 andalso forall(fn cost=>cost>0)(G.costs request) andalso
      #start(hd(G.source_spans request))=7 then () else error "Growth ownership/closure lost";
  val issuer=T.new_issuer();
  val ticket_scope=T.begin_scope issuer{owner_version=1,epoch=1};
  fun run prepared index =
    let val input=nth(G.inputs prepared)index
      val cost=nth(G.costs prepared)index
      val identity={execution=IntInf.fromInt(serial()),slot=IntInf.fromInt(index+10),
        operation={workspace=I.workspace ids,request=3,profile=4,code_generation=5,
          operation=6,step=IntInf.fromInt(index+1),cost=cost,inputs=G.dependencies prepared,
          owner_version=1,epoch=1,journal_sequence=1,semantic_generation=7,
          implementation_artifact=replicate_string 64 "b"}}
      val ticket=T.issue_pure ticket_scope identity
        {instance=instance,request=input,operation=M.operation instance,executable=pin}
      val job=case W.start ticket of W.Ready job=>job | _=>error "Growth ticket start failed"
      val output=case W.collect job of W.Ready output=>output | _=>error "Growth sample worker failed"
      val native=case W.native_output output of W.Ready native=>native | _=>error "Growth output lost"
      val _=if index=0 andalso length(G.inputs prepared)>1 andalso
          can (G.observe prepared 1) native then error "Growth accepted another sample output" else ()
      val observation=G.observe prepared index native
      val _=W.release_output output
    in observation end;
  val _=case(run request 0,run request 1)of
      (G.Observation{actual=M.Exact_Rational(4,1),agrees=true,...},
       G.Observation{actual=M.Exact_Rational(6,1),agrees=false,...})=>()
    | _=>error "Growth samples became universal agreement or lost exact values";
  val _=G.release request;
  val _=if G.live request then error "Released growth request remains live" else ();
  val missing=Exn.capture(fn()=>G.prepare instance{parent=parent,expression=expression,
    samples=[source "([], Some (0::rat))"],work=100})();
  val _=case missing of Exn.Exn _=>() | Exn.Res request=>(G.release request;error "Missing parameter was undefined arithmetic");
  val undefined=G.prepare instance{parent=parent,
    expression=source "Divide (Rational 1) (Rational 0)",
    samples=[source "([], None::rat option)"],work=100};
  val _=if length(G.inputs undefined)=1 then () else error "Undefined arithmetic was refused";
  val _=case run undefined 0 of
      G.Observation{actual=M.Undefined_Arithmetic,agrees=true,...}=>()
    | _=>error "Undefined arithmetic lost its finite observation qualifier";
  val _=G.release undefined;
  val stale_source=source "Parameter 0";
  val stale=G.prepare instance{parent=parent,expression=stale_source,
    samples=[source "([(0,1::rat)], Some (1::rat))"],work=100};
  val _=L.invalidate(L.owner(snd stale_source));
  val _=if G.live stale orelse can G.inputs stale then
    error "Invalidated growth source retained usable preparation" else ();
  val _=G.release stale;
  val _=T.close_scope ticket_scope;
  val _=M.release_instance instance;
  val _=P.release parent;
  val _=List.app(fn input=>Option.app I.release_disposed_input(L.drop_base input))(!all_inputs);
in val _=writeln "GROWTH owned_source_closed_samples_charged_worker PASS" end
\<close>
end
