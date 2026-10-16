(* Bounded inert qualification-role wire. Parsing never creates a checked owner. *)
structure Veri7vn_Qualification_Codec =
struct
  structure T=Veri7vn_Qualification_Recovery_Types;
  structure S=Veri7vn_Native_Sequent;
  type initial={context:T.initial_context,names:T.names,candidate:T.candidate_pin,
    profile:string,count:int,dependencies:IntInf.int list,exports:T.sequents};
  type update={context:T.update_context,names:T.names,candidate:T.candidate_pin,
    baseline:T.candidate_pin,profile:string,count:int,dependencies:IntInf.int list,
    expected_exports:T.sequents,exports:T.sequents};
  val initial_profile="native-export-admission/1";
  val update_profile="named-native-export-structure/1";
  fun require true _=() | require false message=error message;
  fun number n=(require(n>0 andalso size(IntInf.toString n)<=128) "Qualification identity bound";IntInf.toString n);
  fun natural text=(require(size text>0 andalso size text<=128) "Qualification numeric byte bound";
    case IntInf.fromString text of SOME n=>(require(n>=0 andalso IntInf.toString n=text)
      "Qualification canonical number";n) | NONE=>error "Qualification numeric syntax");
  fun positive text=let val n=natural text in require(n>0) "Qualification positive identity";n end;
  fun ids values=(require(length values<=8192 andalso length(distinct(op =)values)=length values)
    "Qualification identity vector bounds/duplicates";map number values);
  fun parse_ids texts=let val _=require(length texts<=8192) "Qualification vector bounds"
    val values=map positive texts val _=ignore(ids values) in values end;
  fun names({claim,target,evidence,contract,attempt,qualification,observation,semantic_generation}:T.names)=
    ids[claim,target,evidence,contract,attempt,qualification,observation,semantic_generation];
  fun parse_names texts=(case parse_ids texts of [claim,target,evidence,contract,attempt,qualification,observation,semantic_generation]=>
    {claim=claim,target=target,evidence=evidence,contract=contract,attempt=attempt,
      qualification=qualification,observation=observation,semantic_generation=semantic_generation}:T.names
    | _=>error "Qualification name vector arity");
  fun initial_context(c:T.initial_context)=map number[#request c,#goal c,#request_slot c,#interpretation c,
    #run_spec c,#policy c,#policy_resource c,#exposure c,#acceptance_metric c,#count_metric c,
    #unit_id c,#executable_generation c,#slot c];
  fun parse_initial texts=(case map positive texts of [request,goal,request_slot,interpretation,run_spec,policy,
      policy_resource,exposure,acceptance_metric,count_metric,unit_id,executable_generation,slot]=>
    {request=request,goal=goal,request_slot=request_slot,interpretation=interpretation,run_spec=run_spec,policy=policy,
      policy_resource=policy_resource,exposure=exposure,acceptance_metric=acceptance_metric,
      count_metric=count_metric,unit_id=unit_id,executable_generation=executable_generation,slot=slot}:T.initial_context
    | _=>error "Initial qualification context arity");
  fun update_context(c:T.update_context)=map number[#request c,#goal c,#request_slot c,#interpretation c,
    #run_spec c,#policy c,#policy_resource c,#exposure c,#structural_metric c,#count_metric c,
    #unit_id c,#executable_generation c,#slot c] @
    [case #previous c of SOME n=>number n | NONE=>error "Update qualification requires prior candidate"];
  fun parse_update texts=(case map positive texts of [request,goal,request_slot,interpretation,run_spec,policy,
      policy_resource,exposure,structural_metric,count_metric,unit_id,executable_generation,slot,previous]=>
    {request=request,goal=goal,request_slot=request_slot,interpretation=interpretation,run_spec=run_spec,policy=policy,
      policy_resource=policy_resource,exposure=exposure,structural_metric=structural_metric,
      count_metric=count_metric,unit_id=unit_id,executable_generation=executable_generation,slot=slot,
      previous=SOME previous}:T.update_context
    | _=>error "Update qualification context arity");
  fun strings tag values=XML.Elem((tag,[]),XML.Encode.list XML.Encode.string values);
  fun parse_strings tag tree=case tree of XML.Elem((actual,[]),body)=>
    (require(actual=tag) "Qualification field order/tag";XML.Decode.list XML.Decode.string body)
    | _=>error "Qualification vector shape";
  fun candidate tag(c:T.candidate_pin)=XML.Elem((tag,[]),[
    strings "identity" (map number[#template c,#source_owner c,#source_revision c,#manifest c,
      #profile c,#setup c,#export_intent c,#candidate c,#lineage c]),
    strings "parents"(ids(#parents c)),strings "dependencies"(ids(#dependencies c))]);
  fun parse_candidate tag tree=(case tree of XML.Elem((actual,[]),[identity,parents,dependencies])=>
    let val _=require(actual=tag) "Qualification candidate tag"
      val parent_ids=parse_ids(parse_strings "parents" parents)
      val deps=parse_ids(parse_strings "dependencies" dependencies)
    in case map positive(parse_strings "identity" identity) of
      [template,source_owner,source_revision,manifest,profile,setup,export_intent,candidate,lineage]=>
        {template=template,source_owner=source_owner,source_revision=source_revision,manifest=manifest,
          parents=parent_ids,profile=profile,setup=setup,export_intent=export_intent,candidate=candidate,
          lineage=lineage,dependencies=deps}:T.candidate_pin
      | _=>error "Qualification candidate arity" end
    | _=>error "Qualification candidate shape");
  fun base64 raw=Bytes.content(Base64.encode(Bytes.string raw));
  fun unbase64 encoded=
    let val _=require(size encoded<=90000) "Qualification encoded sequent bound"
      val raw=Bytes.content(Base64.decode(Bytes.string encoded))
      val _=require(size raw<=65536 andalso base64 raw=encoded) "Qualification canonical sequent encoding"
    in raw end;
  fun export_name name=require(size name>0 andalso size name<=4096 andalso
    forall(fn c=>Char.ord c>=32 andalso Char.ord c<>127)(String.explode name)) "Qualification canonical export name bound";
  fun sequents tag values=
    (require(not(null values) andalso length values<=256) "Qualification export vector bounds";
     XML.Elem((tag,[]),map(fn((name,index),snapshot)=>
       let val _=export_name name val _=require(index>=0 andalso index<=1000000) "Qualification export index"
         val raw=S.encode snapshot val _=require(size raw<=65536) "Qualification sequent bound"
       in XML.Elem(("export",[("name",name),("index",Int.toString index)]),[XML.Text(base64 raw)]) end)values));
  fun parse_sequents tag tree=(case tree of XML.Elem((actual,[]),rows)=>
    (require(actual=tag andalso not(null rows) andalso length rows<=256) "Qualification export shape/bounds";
     map(fn XML.Elem(("export",[("name",name),("index",index)]),[XML.Text encoded])=>
       let val _=export_name name val n=natural index
         val _=require(n<=1000000) "Qualification export index bound"
         val snapshot=S.decode{max_bytes=65536,max_depth=128,max_nodes=20000}(unbase64 encoded)
       in ((name,IntInf.toInt n),snapshot) end
      | _=>error "Qualification export row shape")rows)
    | _=>error "Qualification export vector shape");
  fun framing raw=
    let val n=size raw val _=require(n<=1048576) "Qualification role payload byte bound"
      fun walk i depth nodes=if i>=n then require(depth=0) "Qualification unclosed framing"
        else if String.sub(raw,i)=Char.chr 5 andalso i+1<n andalso String.sub(raw,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(raw,i+2)=Char.chr 5
          then (require(depth>0) "Qualification closing frame";walk(i+3)(depth-1)nodes)
          else (require(depth<64 andalso nodes<100000) "Qualification framing bounds";walk(i+2)(depth+1)(nodes+1))
        else walk(i+1)depth nodes
    in walk 0 0 0 end;
  fun count n=(require(n>0 andalso n<=256) "Qualification measured count bound";Int.toString n);
  fun parse_count text=let val n=natural text in require(n>0 andalso n<=256) "Qualification count";IntInf.toInt n end;
  fun encode_initial({context,names=own,candidate=pin,profile,count=measured,dependencies,exports}:initial)=
    let val _=require(profile=initial_profile) "Initial qualification profile"
      val raw=YXML.string_of_body[XML.Elem(("initial-qualification",[("version","2"),("profile",profile),("count",count measured)]),
        [strings "names"(names own),strings "context"(initial_context context),candidate "candidate" pin,
         strings "dependencies"(ids dependencies),sequents "exports" exports])]
      val _=framing raw
    in raw end;
  fun decode_initial raw=
    let val _=framing raw
      val decoded=case YXML.parse_body raw of
        [XML.Elem(("initial-qualification",[("version","2"),("profile",profile),("count",count)]),
          [own,context,pin,dependencies,exports])]=>
          {context=parse_initial(parse_strings "context" context),names=parse_names(parse_strings "names" own),
           candidate=parse_candidate "candidate" pin,profile=profile,count=parse_count count,
           dependencies=parse_ids(parse_strings "dependencies" dependencies),exports=parse_sequents "exports" exports}:initial
        | _=>error "Initial qualification role schema"
      val _=require(encode_initial decoded=raw) "Noncanonical initial qualification payload"
    in decoded end;
  fun encode_update({context,names=own,candidate=pin,baseline,profile,count=measured,dependencies,expected_exports,exports}:update)=
    let val _=require(profile=update_profile) "Update qualification profile"
      val raw=YXML.string_of_body[XML.Elem(("update-qualification",[("version","2"),("profile",profile),("count",count measured)]),
        [strings "names"(names own),strings "context"(update_context context),candidate "candidate" pin,
         candidate "baseline" baseline,strings "dependencies"(ids dependencies),
         sequents "expected" expected_exports,sequents "exports" exports])]
      val _=framing raw
    in raw end;
  fun decode_update raw=
    let val _=framing raw
      val decoded=case YXML.parse_body raw of
        [XML.Elem(("update-qualification",[("version","2"),("profile",profile),("count",count)]),
          [own,context,pin,baseline,dependencies,expected,exports])]=>
          {context=parse_update(parse_strings "context" context),names=parse_names(parse_strings "names" own),
           candidate=parse_candidate "candidate" pin,baseline=parse_candidate "baseline" baseline,
           profile=profile,count=parse_count count,dependencies=parse_ids(parse_strings "dependencies" dependencies),
           expected_exports=parse_sequents "expected" expected,exports=parse_sequents "exports" exports}:update
        | _=>error "Update qualification role schema"
      val _=require(encode_update decoded=raw) "Noncanonical update qualification payload"
    in decoded end;
end;
