(* Run after Native_Service and native_math_routing.ML in the real native image.
   This fixture uses the authored reader and actual scoped request constructor. *)
local
  structure M=Veri7vn_Mathematics_Execution;
  structure N=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure R=Veri7vn_Interpreted_Request;
  structure Routing=Veri7vn_Native_Math_Routing;
  fun require true _=() | require false message=error message;
  fun rejects f=(case Exn.capture f () of Exn.Exn(ERROR _)=>true | _=>false);
  val inspected_original="the sum of -2 and 3";
  val inspected=Routing.inspect_bytes inspected_original;
  val _=require(#status inspected="readings" andalso
    (case #alternatives inspected of [(0,0,spans)]=>
       map(fn(start,stop)=>String.substring(inspected_original,start,stop-start))spans=["-2","3"]
     | _=>false)) "Routing projection lost actual operation or original literal spans";
  val _=require(#status(Routing.inspect_bytes "not a supported question")="unrecognized")
    "Unrecognized original became a specialist route";
  val _=require(rejects(fn()=>ignore(Routing.inspect_bytes(String.implode(replicate 257 #"x")))))
    "Routing projection admitted oversized original input";
  val ctxt=Proof_Context.init_global(Veri7vn_Executable_Identity.code_theory(M.executable()));
  val ids=I.install_host_block {workspace="d6000000000000000000000000000001",first=10000,past=75000};
  val policy=A.policy(Proof_Context.theory_of ctxt);
  val generation=N.generation ctxt {packages=[],runtime="native routing checks",
    policy="kernel",sources=[],interpretation="same protected original goal"};
  val instance=(case M.attach {policy=policy,generation=generation,
      code_context=Proof_Context.theory_of ctxt,
      limits={nodes=20000,depth=2048,work=512,seconds=5}} of
      M.Ready x=>x | _=>error "Routing fixture mathematics attachment refused");
  val input=L.input{bytes="the sum of -2 and 3",encoding="UTF-8"};
  val source=L.slice input{start=0,stop=size(L.bytes input),expected=L.bytes input};
  val parent=Scope.new_parent{allocator=ids,policy=policy,
    observation=Scope.StateTimeUnused,inputs=[input]};
  val child=Scope.new_child parent{source=source,predecessors=[]};
  val _=require(Routing.same_math_goal instance child 0 0)
    "Same actual predicate was not recognized";
  val _=require(Scope.unclaimed child) "Comparison claimed a required child";
  val _=require(rejects(fn()=>ignore(Routing.same_math_goal instance child 0 255)))
    "Unlicensed reader index entered native comparison";
  val selected=(case R.elaborate_math_child (R.allow_mathematics ids(M.executable())instance)
      child NONE of R.Ready x=>x | _=>error "Selected actual material refused");
  val selected_predicate=Thm.cterm_of ctxt (@{term closed_expression_meaning} $
    HOLogic.mk_number @{typ nat} 512 $
    Veri7vn_Native_Language_Input.native_expression
      (Veri7vn_Native_Language_Input.select_slice source 0));
  val _=require(Thm.term_of(R.native_requirement selected) aconv Thm.term_of selected_predicate)
    "Selected material differs from the compared full native predicate";
  val _=require(rejects(fn()=>ignore(Routing.same_math_goal instance child 0 0)))
    "Already claimed child reused as a routing proposal";
  val sealed=Scope.seal parent[child];
  val _=require(length(Scope.sealed_children sealed)=1 andalso R.live selected)
    "Comparison left an unselected required part";
  val _=Scope.release_child child;
  val _=Scope.release_parent parent;
  val _=Option.app I.release_disposed_input(L.drop_base input);
  val _=require(not(Scope.child_live child) andalso R.live selected andalso
      Thm.term_of(R.native_requirement selected) aconv Thm.term_of selected_predicate)
    "Producer release killed the independently retained selected material";
  val _=R.release selected;
  val _=require(L.disposed input) "Final selected material release retained original input";
  val _=M.release_instance instance;
in
  val _=writeln "VERI7VN_NATIVE_MATH_ROUTING PASS exact_native_predicate single_selected_child independent_retention_final_disposal";
end;
