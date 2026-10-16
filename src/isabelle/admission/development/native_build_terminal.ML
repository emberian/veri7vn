(* Inert observed-failure data. Decoding does not authenticate an observation,
   alter a request outcome, mint a ticket, or authorize replay. *)
structure Veri7vn_Native_Build_Terminal =
struct
  structure H=Veri7vn_Native_Package_Input_Types;
  datatype phase=Replay|Export;
  type failure={request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    execution:IntInf.int,reason:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    phase:phase,span:{start:int,stop:int}option,message:string option};
  fun require true _=()|require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun validate(f:failure)=
    (require(forall positive[#request f,#goal f,#slot f,#execution f,#reason f,
       #source_revision f,#manifest f]) "Build terminal identity bound";
     Option.app(fn{start,stop}=>require(start>=0 andalso stop>=start)
       "Build terminal original span") (#span f);
     Option.app(fn message=>require(size message<=4096 andalso
       XML.content_of(YXML.parse_body message)=message) "Build terminal plain message bound") (#message f));
  fun encode(f:failure)=
    let val _=validate f
      val attributes=map(fn(name,id)=>(name,IntInf.toString id))
        [("request",#request f),("goal",#goal f),("slot",#slot f),
         ("execution",#execution f),("reason",#reason f),("source_revision",#source_revision f),
         ("manifest",#manifest f)]
      val span=case #span f of NONE=>XML.Elem(("span-unavailable",[("reason","not_reported")]),[])
        |SOME{start,stop}=>XML.Elem(("span",[("start",Int.toString start),("stop",Int.toString stop)]),[])
      val message=case #message f of NONE=>XML.Elem(("message-unavailable",[("reason","exceeds_bound")]),[])
        |SOME text=>XML.Elem(("message",[]),[XML.Text text])
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-terminal",
        [("version","1"),("phase",case #phase f of Replay=>"replay"|Export=>"export")]@attributes),[span,message])]
    in require(size bytes<=10000) "Build terminal frame bound";bytes end;
  (* Source diagnostic transport preserves unavailable detail explicitly. Only
     the checked request phase gives restored data its observation provenance. *)
  fun diagnostic_packet(f:failure)=
    let val _=validate f
      val span=case #span f of NONE=>XML.Elem(("span-unavailable",[("reason","not_reported")]),[])
        |SOME{start,stop}=>XML.Elem(("span",[("start",Int.toString start),("stop",Int.toString stop)]),[])
      val message=case #message f of NONE=>XML.Elem(("message-unavailable",[("reason","exceeds_bound")]),[])
        |SOME text=>XML.Elem(("message",[]),[XML.Text text])
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-failure",[("version","1"),
        ("phase",case #phase f of Replay=>"replay"|Export=>"export"),
        ("source_revision",IntInf.toString(#source_revision f)),("manifest",IntInf.toString(#manifest f))]),
        [span,message])]
    in require(size bytes<=8192) "Build terminal diagnostic transport bound";bytes end;
  fun decode bytes:failure=
    let val _=Veri7vn_Native_Construction_Codec.framing bytes
      val _=require(size bytes<=10000) "Build terminal frame bound"
      val (attributes,span_node,message_node)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-build-terminal",attributes),[span,message])] =>(attributes,span,message)
        |_=>error "Build terminal frame shape"
      val _=H.exact["version","phase","request","goal","slot","execution","reason",
        "source_revision","manifest"]attributes
      val get=H.attr attributes
      val _=require(get "version"="1") "Build terminal version"
      val phase=case get "phase"of "replay"=>Replay|"export"=>Export|_=>error "Build terminal phase"
      val span=case span_node of
          XML.Elem(("span",a),[]) =>(H.exact["start","stop"]a;
            SOME{start=H.natural(H.attr a "start"),stop=H.natural(H.attr a "stop")})
        |XML.Elem(("span-unavailable",[("reason","not_reported")]),[])=>NONE
        |_=>error "Build terminal span shape"
      val message=case message_node of XML.Elem(("message",[]),body)=>
          if forall(fn XML.Text _=>true|_=>false)body then SOME(XML.content_of body)
          else error "Build terminal message shape"
        |XML.Elem(("message-unavailable",[("reason","exceeds_bound")]),[])=>NONE
        |_=>error "Build terminal message shape"
      val result={request=H.positive(get "request"),goal=H.positive(get "goal"),slot=H.positive(get "slot"),
        execution=H.positive(get "execution"),reason=H.positive(get "reason"),
        source_revision=H.positive(get "source_revision"),manifest=H.positive(get "manifest"),
        phase=phase,span=span,message=message}:failure
      val _=validate result
      val _=require(encode result=bytes) "Noncanonical build terminal frame"
    in result end;
end;
