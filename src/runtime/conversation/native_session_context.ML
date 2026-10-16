(* The fixed session producer creates a real native source context. Each source
   entry retains a view of this root independently of mathematics children.
   There is no constructor from a borrowed development or a saved numeric ID. *)
signature VERI7VN_SESSION_CONTEXT_VIEW =
sig
  type lease
  val development:lease -> Veri7vn_Managed_Provenance.development
  val is_live:lease -> bool
  val retain:lease -> lease
  val release:lease -> unit
end;
signature VERI7VN_SESSION_CONTEXT_OWNER =
sig
  include VERI7VN_SESSION_CONTEXT_VIEW
  val create:Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> lease
end;
functor Veri7vn_Private_Session_Context() :> VERI7VN_SESSION_CONTEXT_OWNER =
struct
  structure P=Veri7vn_Managed_Provenance;
  datatype root=Root of {development:P.development,count:int} option Synchronized.var;
  datatype lease=Lease of {root:root,owned:bool Synchronized.var};
  fun require true _=() | require false message=error message;
  fun create ids policy=Thread_Attributes.uninterruptible_body(fn _=>
    let val development=P.public_image ids policy;
      val result=Exn.capture(fn()=>Lease{root=Root(Synchronized.var "session_source_context"
        (SOME{development=development,count=1})),owned=Synchronized.var "session_context_view" true})()
    in case result of Exn.Res value=>value
      | Exn.Exn failure=>(P.release development;Exn.reraise failure)end);
  fun with_view(Lease{root=Root root,owned})action=Synchronized.change_result owned(fn active=>
    (require active "Session native context view released";
     Synchronized.change_result root(fn NONE=>error "Session native context root released"
       | SOME value=>(require(P.development_live(#development value)) "Session native context invalidated";
           (action value,SOME value))),active));
  fun development lease=with_view lease #development;
  fun is_live lease=can development lease;
  fun retain(Lease{root=root as Root cell,owned})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change_result owned(fn active=>
      (require active "Session native context view released";
       Synchronized.change_result cell(fn NONE=>error "Session native context root released"
       | SOME{development,count}=>
           (require(P.development_live development andalso count<8192) "Session native context retention bound";
            (Lease{root=root,owned=Synchronized.var "session_context_retained_view" true},
             SOME{development=development,count=count+1}))),active)));
  fun release(Lease{root=Root root,owned})=Thread_Attributes.uninterruptible_body(fn _=>
    let val final=Synchronized.change_result owned(fn false=>(NONE,false)
      | true=>(Synchronized.change_result root(fn NONE=>(NONE,NONE)
        | SOME{development,count}=>if count=1 then(SOME development,NONE)
          else(NONE,SOME{development=development,count=count-1})),false))
    in Option.app P.release final end);
end;
