(* Inert, canonical source-artifact wire. Neither decoding nor numeric fields
   authorize a candidate, a prepared request, or an execution ticket. *)
structure Veri7vn_Native_Development_Codec =
struct
  structure D=Veri7vn_Native_Construction_Codec;
  structure G=Veri7vn_Native_Recovery_Graph;
  type metadata={workspace:string,template:IntInf.int,source_owner:IntInf.int,
    source_revision:IntInf.int,manifest:IntInf.int,parents:IntInf.int list,
    profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,candidate:IntInf.int,
    lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
    charged_generation:IntInf.int,semantic_generation:IntInf.int,
    input_bindings:IntInf.int list,dependencies:IntInf.int list,
    descriptor_source:IntInf.int,descriptor_start:int,descriptor_stop:int};
  type payload={graphs:G.graph_description list,start:int,stop:int,
    parent_bindings:(IntInf.int option*IntInf.int*string)list,exports:Thm_Name.T list};
  fun require true _=()|require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun text bytes=Bytes.content(Base64.encode(Bytes.string bytes));
  fun untext bytes=Bytes.content(Base64.decode(Bytes.string bytes));
  fun scalar_fields(m:metadata)=
    [("version","1"),("workspace",#workspace m)] @
    map(fn(key,value)=>(key,IntInf.toString value))
      [("template",#template m),("source-owner",#source_owner m),("source-revision",#source_revision m),
       ("manifest",#manifest m),("profile",#profile m),("setup",#setup m),("export-intent",#export_intent m),
       ("candidate",#candidate m),("lineage",#lineage m),("request",#request m),("goal",#goal m),("slot",#slot m),
       ("charged-generation",#charged_generation m),("semantic-generation",#semantic_generation m),
       ("descriptor-source",#descriptor_source m)] @
    [("descriptor-start",Int.toString(#descriptor_start m)),("descriptor-stop",Int.toString(#descriptor_stop m))];
  fun bounds(m:metadata)=
    (require(size(#workspace m)=32 andalso forall(fn c=>Char.isDigit c orelse(c>= #"a" andalso c<= #"f"))
       (String.explode(#workspace m))) "Build recovery workspace";
     require(forall positive([#template m,#source_owner m,#source_revision m,#manifest m,#profile m,#setup m,
       #export_intent m,#candidate m,#lineage m,#request m,#goal m,#slot m,#charged_generation m,
       #semantic_generation m,#descriptor_source m] @ #parents m @ #input_bindings m @ #dependencies m))
       "Build recovery metadata IDs";
     require(length(#parents m)<=64 andalso length(distinct(op =)(#parents m))=length(#parents m) andalso
       length(#input_bindings m)=1+length(#parents m) andalso length(#dependencies m)<=8192 andalso
       length(distinct(op =)(#dependencies m))=length(#dependencies m) andalso
       #descriptor_start m>=0 andalso #descriptor_stop m>= #descriptor_start m)
       "Build recovery metadata closure bounds");
  fun id_rows name ids=XML.Elem((name,[]),map(fn id=>XML.Elem(("id",[("value",IntInf.toString id)]),[]))ids);
  fun encode_projection(m:metadata)=
    let val _=bounds m
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-projection",scalar_fields m),
        [id_rows "parents"(#parents m),id_rows "input-bindings"(#input_bindings m),id_rows "dependencies"(#dependencies m)])]
    in require(size bytes<=100000) "Build recovery projection aggregate bound";bytes end;
  fun decode_projection bytes=
    let val _=D.framing bytes
      val(fields,body)=case YXML.parse_body bytes of[XML.Elem(("veri7vn-build-projection",fields),body)]=>
        (fields,body)|_=>error "Build recovery projection schema"
      fun field key=the(AList.lookup(op =)fields key)
      fun number key=D.number(field key)
      fun ids name=case find_first(fn XML.Elem((tag,_),_)=>tag=name|_=>false)body of
        SOME(XML.Elem((_,[]),rows))=>map(fn XML.Elem(("id",[("value",value)]),[])=>D.number value
          |_=>error "Build recovery projection ID row")rows|_=>error "Build recovery projection group"
      val m={workspace=field "workspace",template=number "template",source_owner=number "source-owner",
        source_revision=number "source-revision",manifest=number "manifest",parents=ids "parents",
        profile=number "profile",setup=number "setup",export_intent=number "export-intent",candidate=number "candidate",
        lineage=number "lineage",request=number "request",goal=number "goal",slot=number "slot",
        charged_generation=number "charged-generation",semantic_generation=number "semantic-generation",
        input_bindings=ids "input-bindings",dependencies=ids "dependencies",descriptor_source=number "descriptor-source",
        descriptor_start=D.integer(field "descriptor-start"),descriptor_stop=D.integer(field "descriptor-stop")}:metadata
      val _=require(encode_projection m=bytes) "Noncanonical build recovery projection"
    in m end;
  fun encode_payload({graphs,start,stop,parent_bindings,exports}:payload)=
    let val _=require(not(null graphs) andalso length graphs<=64 andalso start>=0 andalso stop>=start andalso
        length exports<=256 andalso length(distinct(op =)exports)=length exports andalso length parent_bindings<=64 andalso
        forall(fn(name,index)=>size name>0 andalso size name<=4096 andalso index>=0)exports andalso
        forall(fn(id,context,locator)=>forall positive(the_list id) andalso positive context andalso
          size locator>0 andalso size locator<=512)parent_bindings) "Build recovery recipe bounds"
      val wires=map D.encode graphs
      val estimate=1024+fold(fn wire=>fn n=>n+size wire)wires 0+
        fold(fn(_,_,name)=>fn n=>n+512+2*size name)parent_bindings 0+
        fold(fn(name,_)=>fn n=>n+128+2*size name)exports 0
      val _=require(estimate<=100000) "Build recovery recipe aggregate bound"
      val body=[XML.Elem(("graphs",[]),maps YXML.parse_body wires),
        XML.Elem(("parents",[]),map(fn(id,context,locator)=>XML.Elem(("parent",
          [("association",case id of NONE=>""|SOME id=>IntInf.toString id),
           ("context",IntInf.toString context),("locator",text locator)]),[]))parent_bindings),
        XML.Elem(("exports",[]),map(fn(name,index)=>XML.Elem(("export",[("name",text name),("index",Int.toString index)]),[]))exports)]
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-recipe",
        [("version","1"),("start",Int.toString start),("stop",Int.toString stop)]),body)]
    in require(size bytes<=100000) "Build recovery encoded recipe bounds";bytes end;
  fun decode_payload bytes=
    let val _=D.framing bytes
      val(start,stop,graphs,parents,exports)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-build-recipe",[("version","1"),("start",start),("stop",stop)]),
          [XML.Elem(("graphs",[]),graphs),XML.Elem(("parents",[]),parents),XML.Elem(("exports",[]),exports)])]=>
            (D.integer start,D.integer stop,graphs,parents,exports)
      | _=>error "Build recovery recipe schema"
      val graph_values=map(fn tree=>D.decode(YXML.string_of_body[tree]))graphs
      val parent_bindings=map(fn XML.Elem(("parent",[("association",id),("context",context),("locator",locator)]),[])=>
        (if id=""then NONE else SOME(D.number id),D.number context,untext locator)|_=>error "Build recovery parent binding")parents
      val names=map(fn XML.Elem(("export",[("name",name),("index",index)]),[])=>
        (untext name,D.integer index)|_=>error "Build recovery export declaration")exports
      val payload={graphs=graph_values,start=start,stop=stop,parent_bindings=parent_bindings,exports=names}:payload
      val _=require(encode_payload payload=bytes) "Noncanonical build recovery recipe"
    in payload end;
  fun graph_contexts(p:payload)=distinct(op =)(maps D.context_ids(#graphs p));
  fun graph_sources(p:payload)=distinct(op =)(maps D.source_ids(#graphs p));
  fun source_ids(m:metadata)(p:payload)=distinct(op =)(graph_sources p @ [#source_owner m,#descriptor_source m]);
end;
