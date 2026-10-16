(* Bounded wire projection only. This module cannot mint a native witness, update
   a session, or license an answer. The fixed service obtains records from the
   generated conversation helpers and adds only exact native historical renders.
   No independent mutable session table is retained here. *)
structure Veri7vn_Conversation_Display =
struct
  val max_bytes=262144;
  fun require true _=() | require false message=error message;
  fun natural n=(require(n>=0 andalso size(IntInf.toString n)<=128)
    "Conversation natural bound";IntInf.toString n);
  fun identity n=(require(n>0) "Conversation positive identity";natural n);
  fun signed n=if n<0 then "-" ^ IntInf.toString(~n) else IntInf.toString n;
  fun small n limit=(require(n>=0 andalso n<=limit) "Conversation count bound";Int.toString n);
  fun bool true="true" | bool false="false";
  fun hex bytes=String.translate(fn c=>let val n=Char.ord c;
    val digits="0123456789abcdef" in
      String.implode[String.sub(digits,n div 16),String.sub(digits,n mod 16)] end)bytes;
  fun node name attributes body=XML.Elem((name,attributes),body);
  datatype status=Active | Expired | Unavailable;
  fun status Active="active" | status Expired="expired" | status Unavailable="unavailable";
  type clock={kind:string,origin:string,ticks:IntInf.int};
  type observation={session:IntInf.int,version:IntInf.int,clock:clock option,
    reads:(IntInf.int*IntInf.int)list};
  type claim={claim:IntInf.int,target:IntInf.int,interpretation:IntInf.int,evidence:IntInf.int,
    semantic_generation:IntInf.int,executable_generation:IntInf.int option,
    route:string,kind:string,modality:string,collection:string,optimality:string,
    premises:IntInf.int list,dependencies:IntInf.int list};
  type quotation={claim:claim,observation:observation,html:string};
  type predecessor={kind:string,goal:IntInf.int};
  type part={goal:IntInf.int,slot:IntInf.int,status:string,
    predecessors:predecessor list,quotation:quotation option};
  type turn={request:IntInf.int,utterance:IntInf.int,input_encoding:string,input:string,
    observation:observation,parts:part list};
  type summary={id:IntInf.int,version:IntInf.int,status:status,utterances:int,adopted:int};
  type view={id:IntInf.int,version:IntInf.int,status:status,
    observation:observation option,turns:turn list,complete:bool};
  fun references name values=
    (require(length values<=8192) "Conversation references bound";
     node name [] (map(fn value=>node "ref" [("id",identity value)][])values));
  fun observation ({session,version,clock,reads}:observation)=
    let
      val _=require(length reads<=8192 andalso
        length(distinct(op =)(map fst reads))=length reads) "Conversation read bound/uniqueness";
      val clock=(case clock of NONE=>node "clock-unused" [] []
        | SOME {kind,origin,ticks}=>
          (require(member(op =)["wall","monotonic","source_event"]kind andalso
            size origin<=256 andalso size(signed ticks)<=129) "Conversation clock bound";
           node "clock" [("kind",kind),("origin_hex",hex origin),("ticks",signed ticks)][]));
    in node "observation" [("session",identity session),("version",natural version)]
      [clock,node "reads" [] (map(fn(object,version)=>node "read"
        [("object",identity object),("version",natural version)][])reads)] end;
  fun quotation ({claim=c,observation=observed,html}:quotation)=
    let val {claim,target,interpretation,evidence,semantic_generation,executable_generation,
      route,kind,modality,collection,optimality,premises,dependencies}=c;
      val _=require(size html>0 andalso size html<=32768 andalso
        not(String.isSubstring "\005" html) andalso not(String.isSubstring "\006" html))
        "Conversation historical render bound/framing";
      val _=require(member(op =)["kernel_consequence","refined_execution","oracle_consequence"]route
        andalso member(op =)["mathematical","source_observation","engine_observation",
          "model_prediction","test_observation","optimization"]kind
        andalso member(op =)["asserted","conditional","quoted","hypothetical","fictional"]modality
        andalso member(op =)["unspecified","feasible","optimal","impossible"]optimality)
        "Conversation claim variants";
      val _=require(member(op =)["scalar","complete"]collection orelse
        (String.isPrefix "prefix:" collection andalso
          (case IntInf.fromString(String.extract(collection,7,NONE))of
            SOME n=>natural n=String.extract(collection,7,NONE) | NONE=>false)))
        "Conversation collection variant";
    in node "quotation" [("claim",identity claim),("target",identity target),
      ("interpretation",identity interpretation),("evidence",identity evidence),
      ("semantic_generation",identity semantic_generation),
      ("executable_generation",case executable_generation of NONE=>"none" | SOME n=>identity n),
      ("route",route),("kind",kind),("modality",modality),("collection",collection),("optimality",optimality)]
      [references "premises" premises,references "dependencies" dependencies,
       observation observed,node "answer" [] [XML.Text html]] end;
  fun part ({goal,slot,status,predecessors,quotation=quote}:part)=
    (require(member(op =)["pending","historical","declined","inconclusive","failed",
        "cancelled","unavailable","artifact"]status andalso
      ((status="historical")=is_some quote)) "Conversation part variants";
     node "part" [("goal",identity goal),("slot",identity slot),("status",status)]
       (node "predecessors" []
         (require(length predecessors<=256) "Conversation predecessor bound";
          map(fn {kind,goal}=>
            (require(member(op =)["logical","artifact"]kind) "Conversation dependency variant";
             node "dependency" [("kind",kind),("goal",identity goal)][]))predecessors) ::
         (case quote of NONE=>[] | SOME value=>[quotation value])));
  fun turn ({request,utterance,input_encoding,input,observation=original,parts}:turn)=
    (require(member(op =)["UTF-8","binary","native-term/1"]input_encoding andalso
      size input<=256 andalso not(null parts) andalso length parts<=64 andalso
      length(distinct(op =)(map #goal parts))=length parts andalso
      length(distinct(op =)(map #slot parts))=length parts) "Conversation turn bound/uniqueness";
     ignore(fold(fn ({goal,predecessors,...}:part)=>fn previous=>
       (require(forall(fn {goal,...}:predecessor=>member(op =)previous goal)predecessors)
         "Conversation dangling/late predecessor";goal::previous))parts []);
     require(forall(fn ({quotation,...}:part)=>case quotation of NONE=>true
       | SOME {observation,...}=>observation=original)parts) "Conversation original turn observation";
     node "turn" [("request",identity request),("utterance",identity utterance)]
       ([node "input" [("encoding","hex"),("source_encoding",input_encoding)] [XML.Text(hex input)],observation original] @ map part parts));
  fun bounded body=
    let val bytes=YXML.string_of_body body;
      val _=require(size bytes<=max_bytes) "Conversation projection exceeds transport bound";
    in bytes end;
  fun index (summaries:summary list) complete=
    (require(length summaries<=128 andalso
      length(distinct(op =)(map #id summaries))=length summaries) "Conversation list bound/uniqueness";
     bounded[node "veri7vn-conversations" [("version","1"),("complete",bool complete)]
       (map(fn {id,version,status=state,utterances,adopted}=>node "conversation"
         [("id",identity id),("revision",natural version),("status",status state),
          ("utterances",small utterances 8192),("adopted",small adopted 8192)][])summaries)]);
  fun view ({id,version,status=state,observation=observed,turns,complete}:view)=
    let
      val _=require(length turns<=128 andalso
        length(distinct(op =)(map #request turns))=length turns andalso
        length(distinct(op =)(map #utterance turns))=length turns andalso
        forall(fn ({parts,...}:turn)=>not(null parts) andalso length parts<=64)turns andalso
        fold(fn ({parts,...}:turn)=>fn count=>count+length parts)turns 0<=1024)
        "Conversation view turn bound/uniqueness";
      val parts=maps #parts turns;
      val quotes=map_filter #quotation parts;
      (* Bound aggregate content before constructing the XML/YXML projection. *)
      fun observation_cost ({reads,...}:observation)=1024+512*length reads;
      val total=4096+fold(fn ({input,observation,...}:turn)=>fn n=>
          n+1024+2*size input+observation_cost observation)turns 0 +
        512*length parts +512*fold(fn ({predecessors,...}:part)=>fn n=>n+length predecessors)parts 0 +
        fold(fn ({claim={premises,dependencies,...},observation,html}:quotation)=>fn n=>
          n+4096+size html+256*(length premises+length dependencies)+
            observation_cost observation)quotes 0 +
        (case observed of NONE=>0 | SOME value=>observation_cost value);
      val _=require(length parts<=1024 andalso total<=max_bytes)
        "Conversation aggregate projection bound";
      val body=(case (state,observed)of
          (Active,SOME value)=>
            (require(#session value=id andalso #version value=version andalso
               forall(fn ({observation,...}:turn)=> #session observation=id andalso
                 #version observation<=version)turns andalso
               forall(fn ({observation,...}:quotation)=> #session observation=id andalso
                 #version observation<version)quotes) "Conversation observation identity/version";
             observation value :: map turn turns)
        | (Active,NONE)=>error "Active conversation lacks observation"
        | (_,NONE)=>(require(null turns) "Unavailable conversation disclosed payload";[])
        | _=>error "Unavailable conversation disclosed observation");
    in bounded[node "veri7vn-conversation" [("version","1"),("id",identity id),
      ("revision",natural version),("status",status state),("complete",bool complete)]body] end;
end;
