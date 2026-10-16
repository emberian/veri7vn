(* Parent splice: after inspect_routing; requires pure ordered_numeric_policy.ML. *)
fun growth_suggest id payload bytes =
  let val _=F.guard(payload="numeric/1" andalso size bytes<=8192)
      "Growth proposal profile/input bound";
    val {operations,source,unsupported,...}=Veri7vn_Growth_Proposal_Policy.suggest bytes;
    val _=F.guard(size source<=8192) "Growth proposal source bound";
    fun item name text=XML.Elem((name,[]),[XML.Text text]);
    val body=YXML.string_of_body[XML.Elem(("growth-suggestion",
      [("version","1"),("profile","numeric/1"),("status","tentative")]),
      [XML.Elem(("operations",[]),map(item "operation")operations),
       item "source" source,
       XML.Elem(("unsupported",[]),map(item "word")unsupported)])];
    val _=F.guard(size body<=32768) "Growth proposal response bound";
  in emit id "growth_suggestion" "numeric/1" [Bytes.string body] end;

(* Native_Service.thy: before native_service.ML, after math imports:
ML_file \<open>../../isabelle/growth/native/ordered_numeric_policy.ML\<close>
*)
(* handle_command branch:
    | ("growth_suggest",[bytes])=>growth_suggest id payload (Bytes.content bytes)
*)
(* rpc_operations: add "growth_suggest". *)
