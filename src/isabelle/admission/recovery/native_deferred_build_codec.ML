(* Deferred Build requests preserve unresolved predecessor slots as slots. This
   inert codec never constructs a development, candidate, prepared request or
   ticket. The fixed checked producer must authenticate the original Scope and
   full plan before any runtime adoption. *)
structure Veri7vn_Native_Deferred_Build_Codec =
struct
  structure T=Veri7vn_Native_Deferred_Build_Types;
  structure D=Veri7vn_Native_Construction_Codec;
  structure Inputs=Veri7vn_Native_Package_Input_Types;
  fun require true _=()|require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun text value=Bytes.content(Base64.encode(Bytes.string value));
  fun untext value=Bytes.content(Base64.decode(Bytes.string value));
  fun fields(p:T.plan)=map(fn(key,value)=>(key,IntInf.toString value))
    [("prepared-input",#prepared_input p),("request",#request p),("goal",#goal p),("slot",#slot p),
     ("interpretation",#interpretation p),("decision",#decision p),("parameter",#parameter p),
     ("candidate",#candidate p),("execution",#execution p),("template",#template p),
     ("profile",#profile p),("setup",#setup p),("capability",#capability p),
     ("operation",#operation p),("code-generation",#code_generation p),
     ("operation-generation",#operation_generation p),("step",#step p)];
  fun source_fields(s:T.source)=map(fn(key,value)=>(key,IntInf.toString value))
    [("owner",#source_owner s),("revision",#source_revision s),("manifest",#manifest s),
     ("intent",#export_intent s),("descriptor",#descriptor_source s)] @
    map(fn(key,value)=>(key,Int.toString value))[("start",#start s),("stop",#stop s),
     ("descriptor-start",#descriptor_start s),("descriptor-stop",#descriptor_stop s)];
  fun locator name=require(size name>0 andalso size name<=512) "Deferred parent locator bound";
  fun span start stop=require(start>=0 andalso stop>=start andalso stop<=1048576)
    "Deferred original source span bound";
  fun parent(T.Installed{locator=name,root})=
        (locator name;locator root;XML.Elem(("installed",[("locator",text name),("root",text root)]),[]))
    |parent(T.KnownCandidate{locator=name,candidate,context,slot})=
        (locator name;require(forall positive[candidate,context,slot]) "Deferred known parent IDs";
         XML.Elem(("known",[("locator",text name),("candidate",IntInf.toString candidate),
           ("context",IntInf.toString context),("slot",IntInf.toString slot)]),[]))
    |parent(T.ReservedOutput{locator=name,goal,slot,source_owner,start,stop})=
        (locator name;span start stop;require(forall positive[goal,slot,source_owner]) "Deferred reserved parent IDs";
         XML.Elem(("reserved",[("locator",text name),("goal",IntInf.toString goal),
           ("slot",IntInf.toString slot),("source-owner",IntInf.toString source_owner),
           ("start",Int.toString start),("stop",Int.toString stop)]),[]));
  fun encode(p:T.plan)=
    let val scalar=fields p
      val original=Inputs.encode_metadata(#original_input p)
      val known=map_filter(fn T.KnownCandidate{candidate,...}=>SOME candidate|_=>NONE)(#parents p)
      val _=require(#parents(#original_input p)=known) "Deferred original known-parent list differs"
      val source= #source p
      val _=require(size(#workspace p)=32 andalso forall(fn c=>Char.isDigit c orelse(c>= #"a" andalso c<= #"f"))
        (String.explode(#workspace p))) "Deferred workspace"
      val _=require(forall(fn(_,value)=>positive(the(IntInf.fromString value)))scalar andalso
        forall positive[#source_owner source,#source_revision source,#manifest source,
          #export_intent source,#descriptor_source source] andalso
        length(#parents p)<=64 andalso length(#exports p)<=256 andalso
        length(distinct(op =)(#exports p))=length(#exports p) andalso
        length(#dependencies p)<=8192 andalso forall positive(#dependencies p) andalso
        length(distinct(op =)(#dependencies p))=length(#dependencies p)) "Deferred plan IDs/object bounds"
      val _=span(#start source)(#stop source)
      val _=span(#descriptor_start source)(#descriptor_stop source)
      val _=require(forall(fn(name,index)=>size name>0 andalso size name<=4096 andalso index>=0)(#exports p))
        "Deferred selected exports"
      val _=require(fold(fn(name,_)=>fn total=>total+size name)(#exports p)0<=45000 andalso
        fold(fn id=>fn total=>total+size(IntInf.toString id)) (#dependencies p)0<=90000)
        "Deferred plan aggregate estimate"
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-deferred-build-request",
        [("version","1"),("workspace",#workspace p)]@scalar),
        [XML.Elem(("original-input",[("value",text original)]),[]),XML.Elem(("source",source_fields source),[]),XML.Elem(("parents",[]),map parent(#parents p)),
         XML.Elem(("exports",[]),map(fn(name,index)=>XML.Elem(("export",[("name",text name),
           ("index",Int.toString index)]),[]))(#exports p)),
         XML.Elem(("dependencies",[]),map(fn id=>XML.Elem(("id",[("value",IntInf.toString id)]),[]))
           (#dependencies p))])]
    in require(size bytes<=100000) "Deferred plan encoded aggregate bound";bytes end;
  fun decode bytes=
    let val _=D.framing bytes
      val(fields,original,source,parents,exports,dependencies)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-deferred-build-request",fields),
          [XML.Elem(("original-input",[("value",original)]),[]),XML.Elem(("source",source),[]),XML.Elem(("parents",[]),parents),
           XML.Elem(("exports",[]),exports),XML.Elem(("dependencies",[]),dependencies)])]=>
             (fields,Inputs.decode_metadata(untext original),source,parents,exports,dependencies)
      |_=>error "Deferred request schema"
      fun field rows name=the(AList.lookup(op =)rows name)
      fun number name=D.number(field fields name)
      fun src name=D.number(field source name)
      fun pos name=D.integer(field source name)
      fun read_parent(XML.Elem(("installed",[("locator",name),("root",root)]),[]))=
            T.Installed{locator=untext name,root=untext root}
        |read_parent(XML.Elem(("known",[("locator",name),("candidate",candidate),("context",context),("slot",slot)]),[]))=
            T.KnownCandidate{locator=untext name,candidate=D.number candidate,context=D.number context,slot=D.number slot}
        |read_parent(XML.Elem(("reserved",[("locator",name),("goal",goal),("slot",slot),
            ("source-owner",owner),("start",start),("stop",stop)]),[]))=
            T.ReservedOutput{locator=untext name,goal=D.number goal,slot=D.number slot,
              source_owner=D.number owner,start=D.integer start,stop=D.integer stop}
        |read_parent _=error "Deferred parent schema"
      val plan={original_input=original,prepared_input=number "prepared-input",workspace=field fields "workspace",request=number "request",goal=number "goal",slot=number "slot",
        interpretation=number "interpretation",decision=number "decision",parameter=number "parameter",
        candidate=number "candidate",execution=number "execution",template=number "template",profile=number "profile",
        setup=number "setup",capability=number "capability",operation=number "operation",
        code_generation=number "code-generation",operation_generation=number "operation-generation",step=number "step",
        source={source_owner=src "owner",start=pos "start",stop=pos "stop",source_revision=src "revision",
          manifest=src "manifest",export_intent=src "intent",descriptor_source=src "descriptor",
          descriptor_start=pos "descriptor-start",descriptor_stop=pos "descriptor-stop"},
        parents=map read_parent parents,exports=map(fn XML.Elem(("export",[("name",name),("index",index)]),[])=>
          (untext name,D.integer index)|_=>error "Deferred export schema")exports,
        dependencies=map(fn XML.Elem(("id",[("value",value)]),[])=>D.number value
          |_=>error "Deferred dependency schema")dependencies}:T.plan
      val _=require(encode plan=bytes) "Noncanonical deferred request"
    in plan end;
end;
