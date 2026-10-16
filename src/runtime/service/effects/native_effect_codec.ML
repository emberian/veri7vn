(* Closed inert effect material. These records describe originals, never tickets,
   sessions or callbacks. A decoder alone cannot install source/context identity. *)
structure Veri7vn_Native_Effect_Codec =
struct
  structure Inputs=Veri7vn_Native_Effect_Inputs;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure D=Veri7vn_Native_Construction_Codec;
  type names={request:IntInf.int,goal:IntInf.int,interpretation:IntInf.int,target:IntInf.int,
    capability:IntInf.int,profile:IntInf.int,operation:IntInf.int,step:IntInf.int,
    generation:IntInf.int,attempt:IntInf.int,batch:IntInf.int};
  type original={workspace:string,names:names,prestate:IntInf.int,sources:IntInf.int list,
    dependencies:IntInf.int list,operation:string,configuration:IntInf.int,packet:IntInf.int,
    configuration_epoch:IntInf.int,configuration_source:Inputs.source_data,packet_source:Inputs.source_data};
  datatype projection=Request of original|Observation of {original:original,response:IntInf.int,
    epoch:IntInf.int,rejected:bool,receipt:string,schema:string};
  type originals={configuration:string,packet:string};
  type context={image:string,graph:G.graph_description,originals:originals,witness:string option};
  fun require true _=()|require false message=error message;
  fun hash s=size s=64 andalso forall(fn c=>Char.isDigit c orelse(#"a"<=c andalso c<= #"f"))(String.explode s);
  fun digest raw=Message_Digest.rep(SHA256.digest raw);
  fun natural n=n>=0 andalso size(IntInf.toString n)<=128;
  fun positive n=n>0 andalso natural n;
  fun number s=case IntInf.fromString s of SOME n=>
      (require(natural n andalso IntInf.toString n=s) "Effect material canonical natural";n)
    |NONE=>error "Effect material natural syntax";
  fun encode_text raw=Bytes.content(Base64.encode(Bytes.string raw));
  fun decode_text bound raw=
    let val _=require(size raw<=4*((bound+2)div 3)) "Effect material encoded byte bound"
      val value=Bytes.content(Base64.decode(Bytes.string raw))
      val _=require(size value<=bound andalso encode_text value=raw) "Effect material canonical bytes"
    in value end;
  fun attrs fields expected=
    (require(sort_strings(map fst fields)=sort_strings expected andalso
      length fields=length(distinct(op =)(map fst fields))) "Effect material exact attributes";
     fn key=>the(AList.lookup(op =)fields key));
  fun controls(n:names)=[#request n,#goal n,#interpretation n,#target n,#capability n,
    #profile n,#operation n,#step n,#generation n,#attempt n,#batch n];
  val control_keys=["request","goal","interpretation","target","capability","profile","operation_id",
    "step","generation","attempt","batch"];
  fun names values=case values of [request,goal,interpretation,target,capability,profile,
      operation,step,generation,attempt,batch]=>{request=request,goal=goal,interpretation=interpretation,
        target=target,capability=capability,profile=profile,operation=operation,step=step,
        generation=generation,attempt=attempt,batch=batch}:names
    |_=>error "Effect material control arity";
  fun source_valid({draft,head,member,sha256,size=n}:Inputs.source_data)=
    size draft>0 andalso size draft<=256 andalso hash head andalso hash member andalso
    member=sha256 andalso n>0 andalso n<=16384;
  fun original_valid(m:original)=
    let val n= #names m
    in size(#workspace m)=32 andalso forall(fn c=>Char.isDigit c orelse(#"a"<=c andalso c<= #"f"))
      (String.explode(#workspace m)) andalso forall positive(controls n) andalso
      length(distinct(op =)(controls n))=11 andalso natural(#prestate m) andalso
      member(op =)["Discover","QualifyCounter","InvokeCounter"](#operation m) andalso
      positive(#configuration m) andalso positive(#packet m) andalso #configuration m<> #packet m andalso
      not(member(op =)(controls n)(#configuration m)) andalso not(member(op =)(controls n)(#packet m)) andalso
      natural(#configuration_epoch m) andalso #sources m=[#configuration m] andalso
      #dependencies m=[#packet m,#configuration m] andalso
      source_valid(#configuration_source m) andalso source_valid(#packet_source m)end;
  fun original(Request m)=m|original(Observation{original,...})=original;
  fun projection_valid p=original_valid(original p) andalso
    (case p of Request _=>true|Observation{original=m,response,epoch,receipt,schema,...}=>
      positive response andalso not(member(op =)(controls(#names m)@[#configuration m,#packet m])response)
      andalso natural epoch andalso hash receipt andalso hash schema);
  fun source_node tag({draft,head,member,sha256,size}:Inputs.source_data)=
    XML.Elem((tag,[("draft",encode_text draft),("head",head),("member",member),
      ("sha256",sha256),("bytes",Int.toString size)]),[]);
  fun decode_source tag(XML.Elem((actual,fields),[]))=
      let val _=require(actual=tag) "Effect material original-source tag"
        val field=attrs fields ["draft","head","member","sha256","bytes"]
        val count=number(field "bytes")
        val _=require(count>0 andalso count<=16384) "Effect material original-source size"
        val result={draft=decode_text 256(field "draft"),head=field "head",member=field "member",
          sha256=field "sha256",size=IntInf.toInt count}:Inputs.source_data
      in require(source_valid result) "Effect material original-source descriptor";result end
    |decode_source _ _=error "Effect material original-source shape";
  fun encode p=
    let val _=require(projection_valid p) "Effect material projection invalid"
      val m=original p
      val extra=case p of Request _=>[("kind","request")]
        |Observation{response,epoch,rejected,receipt,schema,...}=>[("kind","observation"),
          ("response",IntInf.toString response),("epoch",IntInf.toString epoch),
          ("status",if rejected then "failed"else "confirmed"),("receipt",receipt),("schema",schema)]
      val fields=[("version","2"),("workspace",#workspace m),("prestate",IntInf.toString(#prestate m)),
        ("operation",#operation m),("configuration",IntInf.toString(#configuration m)),
        ("packet",IntInf.toString(#packet m)),("configurationEpoch",IntInf.toString(#configuration_epoch m))]
        @map(fn(key,value)=>(key,IntInf.toString value))(control_keys~~controls(#names m))@extra
      val raw=YXML.string_of_body[XML.Elem(("effect-material",fields),
        [source_node "configuration-source"(#configuration_source m),source_node "packet-source"(#packet_source m)])]
    in require(size raw<=16384) "Effect projection byte bound";raw end;
  fun decode raw=
    let val _=require(size raw>0 andalso size raw<=16384) "Effect projection byte bound"
      val(root,children)=case YXML.parse_body raw of [XML.Elem(("effect-material",fields),children)]=>
          (fields,children)|_=>error "Effect projection envelope"
      val kind=the(AList.lookup(op =)root "kind")
      val keys=["version","workspace","prestate","operation","configuration","packet","configurationEpoch","kind"]
        @control_keys@(if kind="request"then []else if kind="observation"then
          ["response","epoch","status","receipt","schema"]else error "Effect material role")
      val field=attrs root keys
      val _=require(field "version"="2") "Effect material version"
      val(config,packet)=case children of [config,packet]=>
        (decode_source "configuration-source" config,decode_source "packet-source" packet)
        |_=>error "Effect material original source arity"
      val configuration=number(field "configuration") val packet_id=number(field "packet")
      val m={workspace=field "workspace",names=names(map(number o field)control_keys),
        prestate=number(field "prestate"),sources=[configuration],dependencies=[packet_id,configuration],
        operation=field "operation",configuration=configuration,packet=packet_id,
        configuration_epoch=number(field "configurationEpoch"),configuration_source=config,packet_source=packet}:original
      val p=if kind="request"then Request m else Observation{original=m,response=number(field "response"),
        epoch=number(field "epoch"),rejected=(case field "status" of "failed"=>true|"confirmed"=>false
          |_=>error "Effect material response status"),receipt=field "receipt",schema=field "schema"}
      val _=require(projection_valid p andalso encode p=raw) "Effect projection noncanonical/invalid"
    in p end;
  fun original_bytes (m:original) ({configuration,packet}:originals)=
    require(size configuration= #size(#configuration_source m) andalso digest configuration= #sha256(#configuration_source m)
      andalso size packet= #size(#packet_source m) andalso digest packet= #sha256(#packet_source m))
      "Effect original bytes differ from actual source descriptors";
  fun encode_context(m:original)({image,graph,originals,witness}:context)=
    let val _=original_bytes m originals
      val _=require(#head graph= #generation(#names m) andalso size image<=1048576 andalso
        (case witness of NONE=>true|SOME value=>size value<=524288)) "Effect context/encoding witness bound"
      val fields=[("version","2"),("configuration",encode_text(#configuration originals)),
        ("packet",encode_text(#packet originals)),("image",encode_text image),
        ("graph",encode_text(D.encode graph))]@
        (case witness of NONE=>[]|SOME value=>[("witness",encode_text value)])
      val raw=YXML.string_of_body[XML.Elem(("effect-context",fields),[])]
    in require(size raw<=2097152) "Effect context closure bound";raw end;
  fun decode_context(m:original) raw=
    let val _=require(size raw>0 andalso size raw<=2097152) "Effect context closure bound"
      val fields=case YXML.parse_body raw of [XML.Elem(("effect-context",fields),[])]=>fields
        |_=>error "Effect context shape"
      val has_witness=is_some(AList.lookup(op =)fields "witness")
      val field=attrs fields(["version","configuration","packet","image","graph"]@
        (if has_witness then ["witness"]else []))
      val _=require(field "version"="2") "Effect context version"
      val result={image=decode_text 1048576(field "image"),graph=D.decode(decode_text 1048576(field "graph")),
        originals={configuration=decode_text 16384(field "configuration"),packet=decode_text 16384(field "packet")},
        witness=if has_witness then SOME(decode_text 524288(field "witness"))else NONE}:context
      val _=require(encode_context m result=raw) "Effect context noncanonical"
    in result end;
end;
