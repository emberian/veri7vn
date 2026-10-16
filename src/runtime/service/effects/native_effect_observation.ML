(* The YXML tree is a bounded proposal, not a trusted JSON parse. Both actual
   retained source bytes and original ordered receipt bytes must be reproduced by
   the generated encoder. Attribution is nonassertional and grants no start. *)
signature VERI7VN_NATIVE_EFFECT_OBSERVATION =
sig
  datatype status=ConfirmedResponse|RejectedResponse
  type expected={workspace:string,attempt:IntInf.int,request:IntInf.int,capability:IntInf.int,
    operation:string,configuration:IntInf.int,configuration_epoch:IntInf.int,
    configuration_source:Veri7vn_Native_Effect_Inputs.source_data,
    packet_source:Veri7vn_Native_Effect_Inputs.source_data}
  type checked
  val check:expected->Veri7vn_Native_Effect_Responses.response->string->checked
  val response:checked->Veri7vn_Native_Effect_Responses.response
  val status:checked->status val receipt_digest:checked->string val schema:checked->string
end;
structure Veri7vn_Native_Effect_Observation :> VERI7VN_NATIVE_EFFECT_OBSERVATION =
struct
  structure Inputs=Veri7vn_Native_Effect_Inputs;
  structure Responses=Veri7vn_Native_Effect_Responses;
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  datatype status=ConfirmedResponse|RejectedResponse;
  type expected={workspace:string,attempt:IntInf.int,request:IntInf.int,capability:IntInf.int,
    operation:string,configuration:IntInf.int,configuration_epoch:IntInf.int,
    configuration_source:Inputs.source_data,packet_source:Inputs.source_data};
  datatype tree=Null|Boolean of bool|Integer of IntInf.int|Text of IntInf.int list|
    Array of tree list|Object of (string*tree)list;
  datatype checked=Checked of {response:Responses.response,status:status,receipt_digest:string,schema:string};
  fun require true _=()|require false message=error message;
  val natural=Veri7vn_Numerals.nat_of_integer;
  val integer=Veri7vn_Numerals.integer_of_nat;
  fun number text=case IntInf.fromString text of SOME n=>
      (require(n>=0 andalso IntInf.toString n=text andalso size text<=8) "Observation scalar canonical natural";n)
    |NONE=>error "Observation scalar syntax";
  fun signed n=if n<0 then "-"^IntInf.toString(~n)else IntInf.toString n;
  fun int32 text=case IntInf.fromString text of SOME n=>
      (require(n>= ~2147483648 andalso n<=2147483647 andalso signed n=text) "Observation signed32 integer";n)
    |NONE=>error "Observation integer syntax";
  fun scalars text=if text="" then [] else
    let val values=map number(space_explode "," text)
      val _=require(length values<=24576 andalso forall(fn n=>n<=1114111 andalso
        not(55296<=n andalso n<=57343))values) "Observation Unicode scalar bound"
    in values end;
  fun byte n=Char.chr(IntInf.toInt(integer n));
  fun scalar_string values=String.concat(map(fn value=>String.implode(map byte
    (@{code effect_json_utf8}(natural value))))values);
  fun ascii_key(Text values)=
      (require(length values<=16384 andalso forall(fn n=>32<=n andalso n<=126)values) "Observation object key fragment";
       String.implode(map(Char.chr o IntInf.toInt)values))
    |ascii_key _=error "Observation object key must be string";
  fun plain [XML.Text text]=text|plain []=""|plain _=error "Observation atomic witness body";
  fun parse witness=
    let val _=require(size witness>0 andalso size witness<=524288) "Observation witness byte bound"
      val nodes=Unsynchronized.ref 0
      fun tree depth (XML.Elem((tag,attributes),body))=
        let val _=nodes:= !nodes+1
          val _=require(!nodes<=4096 andalso depth<=24 andalso null attributes) "Observation witness structural bound"
          fun child x=tree(depth+1)x
        in case tag of "null"=>(require(null body) "Observation null body";Null)
          |"bool"=>(case plain body of "0"=>Boolean false|"1"=>Boolean true|_=>error "Observation boolean")
          |"int"=>Integer(int32(plain body))|"string"=>Text(scalars(plain body))
          |"array"=>Array(map child body)
          |"object"=>Object(map(fn XML.Elem(("entry",[]),[key,value])=>(ascii_key(child key),child value)
            |_=>error "Observation object entry shape")body)
          |_=>error "Observation witness AST tag"end
        |tree _ _=error "Observation witness AST element"
    in case YXML.parse_body witness of
      [XML.Elem(("effect-observation-witness",[("version","1")]),
        [XML.Elem(("record",[]),[record]),XML.Elem(("receipt",[]),[receipt])])]=>
          (tree 0 record,tree 0 receipt)
      |_=>error "Observation witness envelope"end;
  fun generated Null= @{code EJNull}
    |generated(Boolean b)= @{code EJBool}b
    |generated(Integer n)= @{code EJInt}(Veri7vn_Numerals.int_of_integer n)
    |generated(Text values)= @{code EJString}(map natural values)
    |generated(Array values)= @{code EJArray}(map generated values)
    |generated(Object entries)= @{code EJObject}(map(fn(key,value)=>
      (map(natural o IntInf.fromInt o Char.ord)(String.explode key),generated value))entries);
  fun bytes raw=map(natural o IntInf.fromInt o Char.ord)(String.explode raw);
  fun fields(Object entries)=entries|fields _=error "Observation expected object";
  fun field entries name=case AList.lookup(op =)entries name of SOME value=>value|NONE=>error "Observation missing field";
  fun text(Text values)=scalar_string values|text _=error "Observation expected string";
  fun value entries name=text(field entries name);
  fun exact_keys entries expected=require(sort_strings(map fst entries)=sort_strings expected)
    "Observation exact object fields";
  fun digest raw=Message_Digest.rep(SHA256.digest raw);
  fun hash value=size value=64 andalso forall(fn c=>Char.isDigit c orelse (#"a"<=c andalso c<= #"f"))(String.explode value);
  fun source actual (expected:Inputs.source_data)=
    let val entries=fields actual
      val _=exact_keys entries ["draft","head","member","sha256","size"]
      val _=require(value entries "draft"= #draft expected andalso value entries "head"= #head expected
        andalso value entries "member"= #member expected andalso value entries "sha256"= #sha256 expected
        andalso field entries "size"=Integer(IntInf.fromInt(#size expected))) "Observation original source differs"
    in()end;
  fun check(expected:expected) response witness=
    let val raw=L.bytes(P.source_input(Responses.source response))
      val originals=Responses.originals response
      val original_metadata= #metadata originals
      val _=require(P.source_workspace(Responses.source response)= #workspace expected andalso
        P.source_identity(#configuration originals)= #configuration expected andalso
        #configuration original_metadata= #configuration_source expected andalso
        #packet original_metadata= #packet_source expected andalso
        Inputs.configuration_epoch(#configuration_owner originals)= #configuration_epoch expected)
        "Observation expected context differs from retained source owners"
      val(record,receipt)=parse witness
      val entries=fields record
      val _=exact_keys entries ["format","label","representation","protocol","server","origin","operation","status",
        "workspace","attempt","request","capability","inputArtifact","configuration","configurationSource",
        "configurationEpoch","packetSource","schema","receiptArtifact","receiptEncoding","receiptBytes","response"]
      val encoded=value entries "receiptBytes"
      val _=require(size encoded<=24576) "Observation receipt encoding bound"
      val receipt_bytes=Bytes.content(Base64.decode(Bytes.string encoded))
      val _=require(size receipt_bytes<=16384 andalso Bytes.content(Base64.encode(Bytes.string receipt_bytes))=encoded)
        "Observation canonical receipt encoding"
      val _=require(@{code effect_observation_encoding_check}(generated record)(generated receipt)
        (bytes raw)(bytes receipt_bytes)) "Observation generated encoding check failed"
      val _=require(value entries "format"="veri7vn-mcp-observed-response/1" andalso
        value entries "label"="observed MCP response" andalso value entries "representation"="decoded-json/1" andalso
        value entries "protocol"="local-mcp/1" andalso value entries "server"="veri7vn-local-counter" andalso
        value entries "origin"="local-fixture" andalso value entries "receiptEncoding"="JSON.Format/1")
        "Observation fixed representation"
      val _=require(value entries "workspace"= #workspace expected andalso
        value entries "attempt"=IntInf.toString(#attempt expected) andalso
        value entries "request"=IntInf.toString(#request expected) andalso
        value entries "capability"=IntInf.toString(#capability expected) andalso
        value entries "operation"= #operation expected andalso
        member(op =)["Discover","QualifyCounter","InvokeCounter"](#operation expected) andalso
        value entries "configurationEpoch"=IntInf.toString(#configuration_epoch expected) andalso
        value entries "configuration"="binding-"^IntInf.toString(#configuration expected)^"-epoch-"^
          IntInf.toString(#configuration_epoch expected) andalso
        value entries "inputArtifact"= #member(#packet_source expected)) "Observation original attempt/configuration differs"
      val _=source(field entries "configurationSource")(#configuration_source expected)
      val _=source(field entries "packetSource")(#packet_source expected)
      val receipt_sha=value entries "receiptArtifact"
      val schema=value entries "schema"
      val _=require(hash receipt_sha andalso digest receipt_bytes=receipt_sha andalso hash schema)
        "Observation original receipt/schema identity"
      val response_fields=fields receipt
      val rejected=is_some(AList.lookup(op =)response_fields "error")
      val status=case value entries "status" of "ConfirmedResponse"=>
          (require(not rejected) "Observation rejection mislabeled confirmed";ConfirmedResponse)
        |"RejectedResponse"=>(require rejected "Observation failure lacks structured rejection";RejectedResponse)
        |_=>error "Observation unsupported terminal status"
    in Checked{response=response,status=status,receipt_digest=receipt_sha,schema=schema}end;
  fun response(Checked{response,...})=response;
  fun status(Checked{status,...})=status;
  fun receipt_digest(Checked{receipt_digest,...})=receipt_digest;
  fun schema(Checked{schema,...})=schema;
end;
