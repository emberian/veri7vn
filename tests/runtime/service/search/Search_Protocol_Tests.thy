theory Search_Protocol_Tests
  imports Veri7vn_Search_Service_Metadata.Search_Service_Metadata
begin
ML_file "../../../../src/runtime/service/search/native_search_protocol.ML"
ML \<open>
local
  structure Tickets=Veri7vn_Private_Operation_Tickets();
  structure Worker=Veri7vn_Search_Fn(Tickets);
  structure S=Worker.Search;
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  fun assert true _=() | assert false message=error message;
  fun node name attrs body=XML.Elem((name,attrs),body);
  val literal="  P --> (P & P)  \n";
  val attrs=[("version","1"),("context","40"),("expansions","32"),("frontier","32"),
    ("successors","2"),("milliseconds","1000")];
  fun header attrs actions=YXML.string_of_body[node "search-policy"attrs
    [node "catalogue"[][node "fact"[][XML.Text "HOL.TrueI"]],node "actions"[]actions]];
  fun packet h=let val digits=string_of_int(size h)
    in replicate_string(8-size digits)"0" ^ digits ^ "\n" ^ h ^ literal end;
  fun action kind indices=node "action"[("kind",kind),("indices",indices)][];
  val wire=packet(header attrs[action "introduce" "",action "split" "",action "assume" ""]);
  val parsed=Wire.parse wire;
  val malformed_utf8=["\192\175","\128","\224\128\128","\237\160\128",
    "\240\128\128\128","\244\144\128\128","\245\128\128\128","\195"];
  val _=List.app(fn bad=>assert(not(can Wire.parse(wire ^ bad)))
    "Search native wire accepted malformed, overlong, surrogate or truncated UTF-8")malformed_utf8;
  val unicode="\240\159\140\139";
  val _=assert(#original(Wire.parse(wire ^ unicode))=literal ^ unicode)
    "Search native wire changed valid original UTF-8 bytes";
  val _=assert(#original parsed=literal andalso #context parsed=40 andalso
    #catalogue parsed=["HOL.TrueI"] andalso length(#actions parsed)=3)
    "Search wire lost exact original source/policy";
  val _=assert(not(can Wire.parse(packet(header attrs[action "apply" "1"]))))
    "Search wire accepted foreign fact index";
  val _=assert(not(can Wire.parse(packet(header(("unknown","1")::attrs)[action "assume" ""]))))
    "Search wire accepted unknown policy attributes";
  val _=assert(not(can Wire.parse(packet(header attrs[action "eval_ml" ""]))))
    "Search wire accepted arbitrary worker code";
  val _=assert(not(can Wire.parse("99999999\n" ^ wire))) "Search wire accepted oversized header";
  val ids={request=100,goal=101,slot=102,interpretation=103,decision=104}:Wire.identity;
  val _=assert(String.isSubstring "search-requests" (Wire.requests[{identity=ids,context=40,semantic=41}]))
    "Search reconnect projection missing original context/child";
  val _=assert(not(can Wire.requests[{identity=ids,context=40,semantic=41},{identity=ids,context=40,semantic=41}]))
    "Search reconnect silently duplicated a child";
  val report={outcome=S.BudgetStop,trace=[{step=0,action=S.Split,subgoals=[@{term "P & P"}],route=S.Advanced 1}],
    remaining=[[@{term P}]],expansions=1}:S.report;
  val projected=Wire.unresolved ids @{context} "The proposition remains unresolved." report;
  val _=assert(String.isSubstring "budget" projected andalso String.isSubstring "details_truncated" projected)
    "Search wire lost unresolved budget/truncation";
  val _=assert(not(can (Wire.unresolved ids @{context} "")
    ({outcome=S.ProofProposal "inert",trace=[],remaining=[],expansions=0}:S.report)))
    "Proof proposal mislabeled unresolved";
  val _=assert(String.isSubstring "context" (Wire.context_list[{id=40,semantic=41,label="Installed native package"}]))
    "Search context projection missing";
  val _=writeln "VERI7VN_SEARCH_PROTOCOL_TESTS_PASSED";
in end
\<close>
end
