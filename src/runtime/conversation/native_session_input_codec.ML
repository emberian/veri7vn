(* D65 inert source metadata. Decoding does not acquire a source, install saved
   identities, create a session, record an utterance or grant any native claim.
   The fixed C/checkpoint factory checks this against the exact typed source-row
   requirement before acquiring original bytes through the common source pool. *)
structure Veri7vn_Session_Input_Codec =
struct
  structure P=Veri7vn_Native_Observation_Pin;
  structure D=Veri7vn_Native_Construction_Codec;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Encoding=Veri7vn_Native_Recovery_Encoding;
  type metadata={version:int,workspace:string,session:IntInf.int,utterance:IntInf.int,
    source_generation:IntInf.int,source_dependencies:IntInf.int list,
    observation:P.snapshot,input_encoding:string,input_bytes:string};
  type payload={graph:G.graph_description};
  fun require true _=() | require false message=error message;
  fun natural n=n>=0 andalso size(IntInf.toString n)<=128;
  fun positive n=n>0 andalso natural n;
  fun decimal n=(require(natural n) "Session input natural bound";IntInf.toString n);
  fun signed n=if n<0 then "-"^IntInf.toString(~n)else IntInf.toString n;
  fun number value=(case IntInf.fromString value of SOME n=>
      (require(natural n andalso decimal n=value) "Session input canonical natural";n)
    | NONE=>error "Session input natural syntax");
  fun identifier value=let val n=number value
    in require(n>0) "Session input positive identity";n end;
  fun integer value=(case IntInf.fromString value of SOME n=>
      (require(size(IntInf.toString(IntInf.abs n))<=128 andalso signed n=value)
        "Session input canonical clock";n)
    | NONE=>error "Session input clock syntax");
  fun base64 value=Bytes.content(Base64.encode(Bytes.string value));
  fun unbase64 value=
    (require(size value<=344) "Session input encoded original bound";
     let val raw=Bytes.content(Base64.decode(Bytes.string value))
     in require(size raw<=256 andalso base64 raw=value) "Session input canonical original encoding";raw end);
  fun origin(P.Wall value)=value | origin(P.Monotonic value)=value | origin(P.SourceEvent value)=value;
  fun basis(P.Wall _)="wall" | basis(P.Monotonic _)="monotonic" | basis(P.SourceEvent _)="source_event";
  fun bounds(m:metadata)=
    let val observed= #observation m;
      val _=require(#version m=1 andalso size(#workspace m)=32 andalso
        forall(fn c=>Char.isDigit c orelse(#"a"<=c andalso c<= #"f"))(String.explode(#workspace m)) andalso
        #workspace observed= #workspace m andalso #session observed= #session m andalso
        forall positive[#session m,#utterance m,#source_generation m] andalso natural(#version observed))
        "Session input original workspace/session/context";
      val deps= #source_dependencies m;
      val _=require(not(null deps) andalso length deps<=8192 andalso forall positive deps andalso
        length(distinct(op =)deps)=length deps andalso member(op =)deps(#source_generation m))
        "Session input actual source context closure";
      val reads= #reads observed;
      val _=require(length reads<=256 andalso forall(fn(id,version)=>positive id andalso natural version)reads andalso
        length(distinct(op =)(map fst reads))=length reads) "Session input original reads";
      val _=(case #evaluation_time observed of NONE=>() | SOME{basis,ticks}=>
        require(size(origin basis)<=256 andalso Encoding.utf8(origin basis) andalso
          size(IntInf.toString(IntInf.abs ticks))<=128) "Session input original source clock");
      val _=require(size(#input_bytes m)<=256 andalso Encoding.valid(#input_encoding m)(#input_bytes m))
        "Session input original physical encoding";
      val estimated=8192+fold(fn id=>fn n=>n+32+size(IntInf.toString id))deps 0+
        fold(fn(id,version)=>fn n=>n+64+size(IntInf.toString id)+size(IntInf.toString version))reads 0;
    in require(estimated<=100000) "Session input projection aggregate bound"end;
  fun node name fields body=XML.Elem((name,fields),body);
  fun encode_projection(m:metadata)=
    let val _=bounds m;
      val o_= #observation m;
      val clock=(case #evaluation_time o_ of NONE=>node "clock-unused" [] []
        | SOME{basis=b,ticks}=>node "clock"
          [("kind",basis b),("origin",base64(origin b)),("ticks",signed ticks)][]);
      val tree=node "veri7vn-session-input" [("version","1"),("workspace",#workspace m),
        ("session",decimal(#session m)),("utterance",decimal(#utterance m)),
        ("source-generation",decimal(#source_generation m)),("input-encoding",#input_encoding m),
        ("input-bytes",base64(#input_bytes m))]
        [node "observation" [("version",decimal(#version o_))]
          [clock,node "reads" [] (map(fn(id,version)=>node "read"
            [("id",decimal id),("version",decimal version)][])(#reads o_))],
         node "source-dependencies" [] (map(fn id=>node "id"[("value",decimal id)][])(#source_dependencies m))];
      val bytes=YXML.string_of_body[tree];
    in require(size bytes<=100000) "Session input encoded projection bound";bytes end;
  fun decode_projection bytes=
    let val _=D.framing bytes;
      val(fields,version,clock,reads,deps)=(case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-session-input",fields),
          [XML.Elem(("observation",[("version",version)]),[clock,XML.Elem(("reads",[]),reads)]),
           XML.Elem(("source-dependencies",[]),deps)])]=>(fields,version,clock,reads,deps)
        | _=>error "Session input projection schema");
      fun field name=the(AList.lookup(op =)fields name);
      val _=require(field "version"="1") "Session input projection version";
      val workspace=field "workspace";
      val session=identifier(field "session");
      val observed_clock=(case clock of XML.Elem(("clock-unused",[]),[])=>NONE
        | XML.Elem(("clock",[("kind",kind),("origin",encoded),("ticks",ticks)]),[])=>
          let val name=unbase64 encoded;
            val b=(case kind of "wall"=>P.Wall name | "monotonic"=>P.Monotonic name
              | "source_event"=>P.SourceEvent name | _=>error "Session input clock kind")
          in SOME{basis=b,ticks=integer ticks}end
        | _=>error "Session input original clock schema");
      val observed_reads=map(fn XML.Elem(("read",[("id",id),("version",version)]),[])=>(identifier id,number version)
        | _=>error "Session input read schema")reads;
      val dependencies=map(fn XML.Elem(("id",[("value",id)]),[])=>identifier id
        | _=>error "Session input context dependency schema")deps;
      val m={version=1,workspace=workspace,session=session,utterance=identifier(field "utterance"),
        source_generation=identifier(field "source-generation"),source_dependencies=dependencies,
        observation={workspace=workspace,session=session,version=number version,
          evaluation_time=observed_clock,reads=observed_reads},
        input_encoding=field "input-encoding",input_bytes=unbase64(field "input-bytes")}:metadata;
      val _=require(encode_projection m=bytes) "Noncanonical session input projection";
    in m end;
  fun encode_payload({graph}:payload)=D.encode graph;
  fun decode_payload bytes={graph=D.decode bytes}:payload;
  fun graph_contexts({graph}:payload)=D.context_ids graph;
  fun graph_sources({graph}:payload)=D.source_ids graph;
  (* This closure belongs to code-source reconstruction only. Original utterance
     bytes remain in their exact bounded projection field, not the UTF-8 Q graph. *)
  fun check_graph(m:metadata)(p:payload)=
    let val expected=distinct(op =)(graph_contexts p @ graph_sources p);
    in require(#source_generation m= #head(#graph p) andalso
      length expected=length(#source_dependencies m) andalso
      forall(fn id=>member(op =)(#source_dependencies m)id)expected)
      "Session input context graph/complete closure mismatch"end;
  fun dependencies(m:metadata)=distinct(op =)
    (#utterance m :: #session m :: map fst(#reads(#observation m)) @ #source_dependencies m);
end;
