theory Finite_Ticket_Execution
  imports "Veri7vn_Finite_Runtime.Finite_Scoped_Request"
    "Veri7vn_Domain_Service_Objects.Domain_Service_Objects"
begin

text \<open>The existing curated worker mechanism is structurally generic. Fix
its family to the admitted finite interpreter instead of copying its ticket,
charge, cancellation, native-output and cleanup machinery. The actual state
owner supplies its existing opaque ticket view in final service assembly.\<close>
ML \<open>
functor Veri7vn_Finite_Ticket_Execution_Fn
  (structure Tickets: VERI7VN_OPERATION_TICKET_VIEW) =
  Veri7vn_Domain_Ticket_Execution_Fn
    (structure Domain=Veri7vn_Finite_Execution structure Tickets=Tickets);
\<close>
end
