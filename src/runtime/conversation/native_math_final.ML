(* Fixed typed final-outcome association. This does not grant current publication
   or adoption permission: the final private service must match the exact object's
   actual binding against Owner licensing, then commit the generated adoption.
   Unlike a host status/evidence ID, an exact object retains the SAME live native
   witness. No string/ID/saved-record constructor is exported. *)
signature VERI7VN_CONVERSATION_MATH_FINAL =
sig
  type exact
  datatype outcome=ExactCandidate of exact | Undefined | Missing of IntInf.int list |
    Syntax | Budget
  type identity={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,evidence:IntInf.int}
  val inspect: Veri7vn_Native_Math_Gate.witness -> outcome
  val live: exact -> bool
  val identity: exact -> identity
  val request: exact -> Veri7vn_Interpreted_Request.request
  val html: exact -> string
  val publication_frame:exact -> string
  val managed_dependencies: exact -> IntInf.int list
end;

structure Veri7vn_Conversation_Math_Final :> VERI7VN_CONVERSATION_MATH_FINAL =
struct
  structure G=Veri7vn_Native_Math_Gate;
  structure D=Veri7vn_Refined_Math_Display;
  structure R=Veri7vn_Interpreted_Request;
  datatype exact=Exact of G.witness;
  datatype outcome=ExactCandidate of exact | Undefined | Missing of IntInf.int list |
    Syntax | Budget;
  type identity={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,evidence:IntInf.int};
  fun inspect witness=(case G.display witness of
      D.Exact _=>ExactCandidate(Exact witness)
    | D.Undefined=>Undefined
    | D.Missing values=>Missing values
    | D.Syntax=>Syntax
    | D.Budget=>Budget);
  fun checked(Exact witness)=
    if not(G.live witness) then error "Conversation native exact witness released"
    else (case G.display witness of D.Exact value=>(witness,value)
      | _=>error "Conversation native outcome is not exact");
  fun live value=(ignore(checked value);true)handle ERROR _=>false;
  fun identity value=
    let val (witness,_)=checked value;
      val p=R.project(G.request witness)
    in {request= #request_id p,goal= #goal_id p,slot= #output_slot_id p,
      evidence=G.evidence witness}:identity end;
  fun request value=G.request(#1(checked value));
  fun html value= #statement_html(#2(checked value));
  fun publication_frame value=G.publication_frame(#1(checked value));
  fun managed_dependencies value=G.managed_dependencies(#1(checked value));
end;
