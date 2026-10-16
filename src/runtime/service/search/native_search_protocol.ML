(* Closed inert wire codec and bounded read-only projections. This module does
   not select P owners, issue tickets, admit evidence or license a result. The
   resident assembly must do those operations before calling a proof renderer. *)
functor Veri7vn_Search_Protocol_Fn (S: VERI7VN_NATIVE_SEARCH) =
struct
  type proposal={context:IntInf.int,original:string,limits:S.limits,
    catalogue:string list,actions:S.action list};
  type identity=Veri7vn_Native_Request_Scope.identity;
  fun require true _=() | require false message=error message;
  fun digits text=size text>0 andalso forall Char.isDigit (String.explode text);
  fun natural max text=
    (require(size text<=9 andalso digits text andalso
      (text="0" orelse String.sub(text,0)<> #"0")) "Search bounded integer encoding";
     case Int.fromString text of SOME n=>
       (require(n>=0 andalso n<=max) "Search integer bound";n)
     | NONE=>error "Search integer encoding");
  fun identity text=
    (require(size text>0 andalso size text<=128 andalso digits text andalso
      String.sub(text,0)<> #"0") "Search native identity encoding";
     case IntInf.fromString text of SOME n=>n | NONE=>error "Search identity encoding");
  fun safe text bound=
    (require(size text<=bound andalso Veri7vn_Search_UTF8.valid text andalso not(exists(fn c=>c= #"\005" orelse c= #"\006")
      (String.explode text))) "Search text byte bound/control";text);
  fun attributes keys attrs=
    (require(length attrs=length keys andalso distinct(op =)(map #1 attrs)=map #1 attrs andalso
      sort_strings(map #1 attrs)=sort_strings keys) "Search policy attributes";
     fn key=>the(AList.lookup(op =)attrs key));
  fun plain [XML.Text text]=text
    | plain []=""
    | plain _=error "Search policy plain text expected";
  fun action_of_xml catalogue_size tree=
    let fun index text=let val n=natural 127 text
        in require(n<catalogue_size) "Search fact index outside catalogue";n end;
      fun parse_action(XML.Elem(("action",attrs),[]))=
          let val a=attributes["kind","indices"]attrs;
            val indices=if a "indices"="" then [] else space_explode "," (a "indices");
            val _=require(length indices<=128) "Search simplification fact bound";
            val selected=map index indices;
            fun empty action=(require(null selected) "Search unexpected action index";action)
          in case a "kind" of
            "retrieve"=>empty S.Retrieve | "split"=>empty S.Split |
            "introduce"=>empty S.Introduce | "assume"=>empty S.Assume |
            "apply"=>(case selected of [n]=>S.Apply n | _=>error "Search apply index") |
            "simplify"=>S.Simplify selected | _=>error "Search action kind"
          end
        | parse_action _=error "Search action shape";
    in parse_action tree end;
  fun parse wire : proposal =
    let val _=require(size wire>=10 andalso size wire<=196617 andalso String.sub(wire,8)= #"\n")
          "Search packet byte framing";
      val prefix=String.substring(wire,0,8);
      val _=require(forall Char.isDigit(String.explode prefix)) "Search policy length encoding";
      val count=case Int.fromString prefix of SOME n=>n | NONE=>error "Search policy length";
      val _=require(count>0 andalso count<=131072 andalso 9+count<size wire) "Search policy byte bound";
      val header=String.substring(wire,9,count);
      (* The closed policy has at most 195 shallow elements. Bound structural
         controls BEFORE YXML parsing, so a tiny-attribute/deep hostile header
         cannot allocate an unbounded tree before the shape checks below. *)
      val _=require(length(String.fields(fn c=>c= #"\005")header)<=781 andalso
        length(String.fields(fn c=>c= #"\006")header)<=525) "Search policy structural bound";
      val original=safe(String.extract(wire,9+count,NONE))65536;
      val _=require(size original>0) "Search proposition is empty";
      val (a,catalogue_trees,action_trees)=case YXML.parse_body header of
        [XML.Elem(("search-policy",attrs),
          [XML.Elem(("catalogue",[]),facts),XML.Elem(("actions",[]),actions)])]=>
            (attributes["version","context","expansions","frontier","successors","milliseconds"]attrs,facts,actions)
        | _=>error "Search closed policy shape";
      val _=require(a "version"="1") "Search policy version";
      val _=require(length catalogue_trees<=128 andalso not(null action_trees) andalso
        length action_trees<=64) "Search policy catalogue/action bound";
      val catalogue=map(fn XML.Elem(("fact",[]),body)=>
          let val name=safe(plain body)512
          in require(size name>0 andalso length(Symbol.explode name)<=512) "Search fact name bound";name end
        | _=>error "Search catalogue entry")catalogue_trees;
      val limits={expansions=natural 10000(a "expansions"),frontier=natural 1000(a "frontier"),
        successors=natural 16(a "successors"),milliseconds=natural 30000(a "milliseconds")};
      val _=require(#expansions limits>0 andalso #frontier limits>0 andalso
        #successors limits>0 andalso #milliseconds limits>0) "Search positive budgets";
    in {context=identity(a "context"),original=original,limits=limits,
      catalogue=catalogue,actions=map (action_of_xml(length catalogue)) action_trees} end;
  fun node name attrs body=XML.Elem((name,attrs),body);
  fun document tree=YXML.string_of_body[tree];
  fun action_xml action=
    let val (kind,indices)=case action of S.Retrieve=>("retrieve",[]) | S.Split=>("split",[]) |
        S.Introduce=>("introduce",[]) | S.Assume=>("assume",[]) | S.Apply n=>("apply",[n]) |
        S.Simplify ns=>("simplify",ns)
    in node "action"[("kind",kind),("indices",space_implode ","(map string_of_int indices))][]end;
  fun context_list (contexts:{id:IntInf.int,semantic:IntInf.int,label:string} list)=
    (require(length contexts<=256 andalso length(distinct(op =)(map #id contexts))=length contexts)
      "Search context list bound/uniqueness";
     document(node "search-contexts"[("version","1")](map(fn {id,semantic,label}=>
       (require(id>0 andalso semantic>0) "Search context native identity";
        node "context"[("id",IntInf.toString id),("semantic",IntInf.toString semantic)]
          [XML.Text(safe label 512)]))contexts)));
  (* Caller supplies only the intersection of current authority-required
     children and exact retained native Search associations. An explicit bound
     failure is preferable to silently omitting reconnect handles. *)
  fun requests (entries:{identity:identity,context:IntInf.int,semantic:IntInf.int} list)=
    let fun key({identity,...}:{identity:identity,context:IntInf.int,semantic:IntInf.int})=
        (#request identity,#goal identity,#slot identity);
      val _=require(length entries<=256 andalso length(distinct(op =)(map key entries))=length entries)
        "Search retained child list bound/uniqueness";
    in document(node "search-requests"[("version","1")](map(fn {identity,context,semantic}=>
      (require(context>0 andalso semantic>0 andalso #request identity>0 andalso #goal identity>0 andalso
        #slot identity>0) "Search retained original context/child identity";
       node "request"[("id",IntInf.toString(#request identity)),("goal",IntInf.toString(#goal identity)),
         ("slot",IntInf.toString(#slot identity)),("context",IntInf.toString context),
         ("semantic",IntInf.toString semantic)][]))entries))end;
  fun root (ids:identity) status body=document(node "search-result"
    [("version","1"),("request",IntInf.toString(#request ids)),
     ("goal",IntInf.toString(#goal ids)),("slot",IntInf.toString(#slot ids)),("status",status)]body);
  fun pending ids=root ids "pending" [];
  fun take_at_most n xs=take(Int.min(n,length xs))xs;
  (* A bounded diagnostic skeleton, never a reparsed theorem/target. Do not
     pretty-print a full term and trim afterwards: a small term can contain a
     very long name, and repeated names can amplify the rendered allocation. *)
  fun term_projection term=
    let val chunks=Unsynchronized.ref([]:string list);
      val room=Unsynchronized.ref 256;
      val nodes=Unsynchronized.ref 0;
      val truncated=Unsynchronized.ref false;
      fun prefix bound text=
        let fun cut count=let val part=String.substring(text,0,count)
              in if Veri7vn_Search_UTF8.valid part then part else cut(count-1)end
        in cut(Int.min(bound,size text))end;
      fun append text=let val part=prefix(!room)text
        in if size part<size text then truncated:=true else();
          room:= !room-size part;chunks:=part :: !chunks end;
      fun name text=let val part=prefix 48 text;
          val visible=String.translate(fn c=>if c= #"\005" orelse c= #"\006" then "?" else str c)part
        in if part<>text orelse visible<>part then truncated:=true else();append visible end;
      fun render depth term=
        if depth>=10 orelse !nodes>=32 orelse !room=0 then (truncated:=true;append "...")
        else (nodes:= !nodes+1;
          case term of Const(n,_)=>name n | Free(n,_)=>name n |
            Var((n,i),_) =>(append "?";name n;append ".";append(string_of_int i)) |
            Bound i=>(append "#";append(string_of_int i)) |
            Abs(n,_,body)=>(append "(%";name n;append ". ";render(depth+1)body;append ")") |
            f $ x=>(append "(";render(depth+1)f;append " ";render(depth+1)x;append ")"));
      val _=render 0 term;
    in (String.concat(rev(!chunks)),!truncated)end;
  fun action_name S.Retrieve="retrieve" | action_name(S.Apply _)="apply" |
    action_name(S.Simplify _)="simplify" | action_name S.Split="split" |
    action_name S.Introduce="introduce" | action_name S.Assume="assume";
  fun route_name(S.Advanced _)="advanced" | route_name S.Failed="failed" |
    route_name(S.Blocked _)="blocked" | route_name S.ActionTimedOut="timed_out";
  fun progress _ ({trace,remaining,expansions,...}:S.report)=
    let val selected_trace=take_at_most 32 trace;
      val selected_remaining=take_at_most 8 remaining;
      val details_truncated=Unsynchronized.ref false;
      fun goals terms=
        (if length terms>4 then details_truncated:=true else();
         map(fn term=>let val (text,truncated)=term_projection term
           val _=if truncated then details_truncated:=true else()
         in node "subgoal"[][XML.Text text]end)(take_at_most 4 terms));
      val steps=map(fn {step,action,subgoals,route}=>node "step"
        [("index",string_of_int step),("action",action_name action),("route",route_name route)]
        (goals subgoals))selected_trace;
      val states=map(fn state=>node "state"[](goals state))selected_remaining;
    in node "progress"[("expansions",string_of_int expansions),("trace_total",string_of_int(length trace)),
      ("remaining_total",string_of_int(length remaining)),("details_truncated",Bool.toString(!details_truncated))]
      [node "trace"[]steps,node "remaining"[]states]end;
  fun validate_progress tree=
    let fun subgoals goals=
        (require(length goals<=4) "Search stored subgoal projection bound";
         List.app(fn XML.Elem(("subgoal",[]),body)=>ignore(safe(plain body)256)
           | _=>error "Search stored subgoal projection")goals);
      fun step(XML.Elem(("step",attrs),goals))=
          let val a=attributes["index","action","route"]attrs;
            val _=natural 10000(a "index");
            val _=require(member(op =)["retrieve","apply","simplify","split","introduce","assume"](a "action") andalso
              member(op =)["advanced","failed","blocked","timed_out"](a "route")) "Search stored step variant"
          in subgoals goals end
        | step _=error "Search stored trace step";
    in case tree of XML.Elem(("progress",attrs),[XML.Elem(("trace",[]),steps),XML.Elem(("remaining",[]),states)])=>
        let val a=attributes["expansions","trace_total","remaining_total","details_truncated"]attrs;
          val _=natural 10000(a "expansions");
          val total=natural 10000(a "trace_total");
          val remaining=natural 1000(a "remaining_total");
          val _=require(length steps<=32 andalso length states<=8 andalso length steps<=total andalso
            length states<=remaining andalso member(op =)["true","false"](a "details_truncated"))
            "Search stored progress bounds/truncation";
          val _=List.app step steps;
        in List.app(fn XML.Elem(("state",[]),goals)=>subgoals goals
          | _=>error "Search stored remaining state")states end
      | _=>error "Search stored progress shape" end;
  fun unresolved ids ctxt diagnostic (report:S.report)=
    let val status=case #outcome report of S.Exhausted=>"exhausted" | S.BudgetStop=>"budget" |
      S.Cancelled=>"cancelled" | S.Deadline=>"deadline" |
      S.ProofProposal _=>error "Proof proposal is not an unresolved outcome";
    in root ids status[node "diagnostic"[][XML.Text(safe diagnostic 2048)],progress ctxt report]end;
  (* Sole caller is the assembly after it verifies a current licensed binding.
     The proposition is the actual retained original source, not a pretty term. *)
  fun proved ids ctxt {proposition,evidence,semantic,proof_semantic,dependencies} report=
    (require(evidence>0 andalso semantic>0 andalso proof_semantic>0 andalso semantic<>proof_semantic andalso
      member(op =)dependencies semantic andalso member(op =)dependencies proof_semantic andalso length dependencies<=1024 andalso
      distinct(op =)dependencies=dependencies andalso forall(fn id=>id>0)dependencies)
       "Search licensed projection identity/dependencies";
     root ids "proved"[node "proof"[("evidence",IntInf.toString evidence),
       ("semantic",IntInf.toString semantic),("proof_semantic",IntInf.toString proof_semantic),("route","kernel_consequence")]
       [node "proposition"[][XML.Text(safe proposition 65536)],
        node "dependencies"[](map(fn id=>node "dependency"[("id",IntInf.toString id)][])dependencies)],
       progress ctxt report]);
  fun failure ids status diagnostic=
    (require(member(op =)["failed","unavailable","cancelled"]status) "Search failure projection status";
     root ids status[node "diagnostic"[][XML.Text(safe diagnostic 2048)],
       node "progress"[("expansions","0"),("trace_total","0"),("remaining_total","0"),("details_truncated","false")]
         [node "trace"[][],node "remaining"[][]]]);
end;
