(* Inert, bounded payload codec. Decoding certifies no term, identity, source,
   condition or runtime result. Only the fixed protected factory may consume it. *)
structure Veri7vn_Domain_Recovery_Payload =
struct
  structure S=Veri7vn_Domain_Saved_Types;
  structure D=struct type saved=S.request_saved type condition_snapshot=S.condition_snapshot end;
  structure G=struct type saved=S.output_saved end;
  structure C=S;
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun natural text=(require(size text<=128)"Domain recovery natural byte bound";
    case IntInf.fromString text of SOME n=>
      (require(n>=0 andalso size text<=128 andalso IntInf.toString n=text)
        "Domain recovery natural syntax";n)
    | NONE=>error "Domain recovery natural syntax");
  fun enc_bytes raw=XML.Encode.string(Bytes.content(Base64.encode(Bytes.string raw)));
  fun dec_bytes body=Bytes.content(Base64.decode(Bytes.string(XML.Decode.string body)));
  fun enc_id n=XML.Encode.string(IntInf.toString n);
  fun dec_id body=natural(XML.Decode.string body);
  fun enc_span span=XML.Encode.pair XML.Encode.int XML.Encode.int span;
  fun dec_span body=let val(start,stop)=XML.Decode.pair dec_id dec_id body
    in require(start<=1048576 andalso stop<=1048576)"Domain recovery span bound";
      (IntInf.toInt start,IntInf.toInt stop)end;
  fun record fields=map(fn(name,body)=>XML.Elem((name,[]),body))fields;
  fun fields expected body=
    let fun field(XML.Elem((name,[]),value))=(name,value)
          | field _=error "Domain recovery record field shape";
      val actual=map field body;
      val _=require(sort_strings(map #1 actual)=sort_strings expected)
        "Domain recovery fields/duplicates";
      val table=Symtab.make actual;
    in fn name=>the(Symtab.lookup table name)end;
  fun term body=let val t=Term_XML.Decode.term_raw body
    in require(Term.size_of_term t<=80000)"Domain recovery term bound";t end;
  fun role C.InputCondition="input" | role C.IdealSpringModel="ideal-spring-model";
  fun read_role "input"=C.InputCondition | read_role "ideal-spring-model"=C.IdealSpringModel
    | read_role _=error "Domain recovery condition role";
  fun encode_condition(c:D.condition_snapshot)=record
    [("identity",enc_id(#identity c)),("owner",enc_id(#owner_identity c)),
     ("role",XML.Encode.string(role(#role c))),("proposition",Term_XML.Encode.term_raw(#proposition c)),
     ("span",enc_span(#source_span c)),("dependencies",XML.Encode.list enc_id(#dependencies c))];
  fun decode_condition body:D.condition_snapshot=
    let val f=fields["identity","owner","role","proposition","span","dependencies"]body
    in {identity=dec_id(f"identity"),owner_identity=dec_id(f"owner"),
      role=read_role(XML.Decode.string(f"role")),proposition=term(f"proposition"),
      source_span=dec_span(f"span"),dependencies=XML.Decode.list dec_id(f"dependencies")}end;
  fun encode_request_body(s:D.saved)=record
    [("workspace",XML.Encode.string(#workspace s)),("input-identity",enc_id(#input_identity s)),
     ("input",Term_XML.Encode.term_raw(#input s)),("template",Term_XML.Encode.term_raw(#template s)),
     ("bytes",enc_bytes(#bytes s)),("encoding",XML.Encode.string(#encoding s)),
     ("span",enc_span(#input_source_span s)),
     ("context-dependencies",XML.Encode.list enc_id(#context_dependencies s)),
     ("owners",XML.Encode.list(XML.Encode.triple enc_id enc_bytes XML.Encode.string)(#owners s)),
     ("conditions",XML.Encode.list encode_condition(#conditions s)),
     ("implementation",Term_XML.Encode.term_raw(#implementation s)),
     ("model-contract",XML.Encode.option Term_XML.Encode.term_raw(#model_contract s))];
  fun validate_request(s:D.saved)=
    let val _=require(size(#workspace s)=32 andalso forall(fn c=>Char.isDigit c orelse
        (#"a"<=c andalso c<= #"f"))(String.explode(#workspace s)))"Domain recovery workspace";
      val _=require(positive(#input_identity s) andalso #encoding s="UTF-8" andalso
        size(#bytes s)<=1048576 andalso length(#conditions s)<=8192 andalso
        length(#owners s)<=8192)"Domain recovery request bounds";
      fun ids values=require(length values<=8192 andalso forall positive values)
        "Domain recovery dependency bounds";
      fun span bytes(start,stop)=require(0<=start andalso start<=stop andalso stop<=size bytes)
        "Domain recovery source span";
      val _=span(#bytes s)(#input_source_span s);
      val _=ids(#context_dependencies s);
      val _=require(length(distinct(op =)(map #1(#owners s)))=length(#owners s) andalso
        length(distinct(op =)(map #identity(#conditions s)))=length(#conditions s))
        "Domain recovery duplicate owner/condition identities";
      val _=List.app(fn(id,bytes,encoding)=>
        (require(positive id andalso encoding="UTF-8" andalso size bytes<=1048576)
          "Domain recovery owner bounds";
         if id= #input_identity s then require(bytes= #bytes s andalso encoding= #encoding s)
           "Domain recovery conflicting original/premise owner"else()))(#owners s);
      val _=List.app(fn(c:D.condition_snapshot)=>
        let val id= #owner_identity c;
          val bytes=if id= #input_identity s then #bytes s else
            (case find_first(fn(owner,_,_)=>owner=id)(#owners s)of
              SOME(_,bytes,_)=>bytes | NONE=>error "Domain recovery missing premise source owner")
        in require(positive(#identity c) andalso positive id)"Domain recovery condition identity";
          span bytes(#source_span c);ids(#dependencies c)end)(#conditions s);
      val terms=[#input s,#template s,#implementation s] @ the_list(#model_contract s) @
        map #proposition(#conditions s);
      val _=require(fold(fn t=>fn n=>n+Term.size_of_term t)terms 0<=120000)
        "Domain recovery aggregate native term bound";
    in s end;
  fun decode_request_body body=let val f=fields
      ["workspace","input-identity","input","template","bytes","encoding","span",
       "context-dependencies","owners","conditions","implementation","model-contract"]body
    in validate_request{workspace=XML.Decode.string(f"workspace"),input_identity=dec_id(f"input-identity"),
      input=term(f"input"),template=term(f"template"),bytes=dec_bytes(f"bytes"),
      encoding=XML.Decode.string(f"encoding"),input_source_span=dec_span(f"span"),
      context_dependencies=XML.Decode.list dec_id(f"context-dependencies"),
      owners=XML.Decode.list(XML.Decode.triple dec_id dec_bytes XML.Decode.string)(f"owners"),
      conditions=XML.Decode.list decode_condition(f"conditions"),implementation=term(f"implementation"),
      model_contract=XML.Decode.option term(f"model-contract")}end;
  fun framing bytes=
    let val n=size bytes;val _=require(n<=1048576)"Domain recovery payload byte bound";
      fun scan i depth nodes=if i>=n then require(depth=0)"Domain recovery unclosed framing"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then(require(depth>0)"Domain recovery closing framing";scan(i+3)(depth-1)nodes)
          else(require(depth<4096 andalso nodes<131072)"Domain recovery XML bounds";
            scan(i+2)(depth+1)(nodes+1))
        else scan(i+1)depth nodes
    in scan 0 0 0 end;
  fun encode root body=let val bytes=YXML.string_of_body[XML.Elem((root,[("version","1")]),body)]
    in framing bytes;bytes end;
  fun decode root bytes=(framing bytes;case YXML.parse_body bytes of
      [XML.Elem((name,[("version","1")]),body)]=>
        (require(name=root)"Domain recovery role root differs";body)
    | _=>error "Domain recovery role/version framing");
  fun encode_request saved=encode "domain-request"(encode_request_body(validate_request saved));
  fun decode_request bytes=decode_request_body(decode "domain-request" bytes);
  fun encode_output_body(s:G.saved)=record[("request",encode_request_body(validate_request(#request s))),
      ("output",Term_XML.Encode.term_raw(#output s)),("target",Term_XML.Encode.term_raw(#target s)),
      ("implementation",Term_XML.Encode.term_raw(#implementation s)),
      ("model-contract",XML.Encode.option Term_XML.Encode.term_raw(#model_contract s)),
      ("rendering-contract",Term_XML.Encode.term_raw(#rendering_contract s)),
      ("statement-html",enc_bytes(#statement_html s))];
  fun encode_output saved=encode "domain-runtime-refinement"(encode_output_body saved);
  fun decode_output_body body:G.saved=let val f=fields
      ["request","output","target","implementation","model-contract","rendering-contract","statement-html"]
      body;
      val html=dec_bytes(f"statement-html");
      val _=require(size html<=65536)"Domain recovery HTML bound"
    in {request=decode_request_body(f"request"),output=term(f"output"),target=term(f"target"),
      implementation=term(f"implementation"),model_contract=XML.Decode.option term(f"model-contract"),
      rendering_contract=term(f"rendering-contract"),statement_html=html}end;
  fun decode_output bytes=decode_output_body(decode "domain-runtime-refinement" bytes);
  fun encode_request_envelope(e:S.request_envelope)=
    encode "domain-request-envelope"(record
      [("association",enc_id(#association e)),("request",enc_id(#request e)),
       ("goal",enc_id(#goal e)),("slot",enc_id(#slot e)),
       ("semantic-generation",enc_id(#semantic_generation e)),
       ("code-generation",enc_id(#code_generation e)),("operation",enc_id(#operation e)),
       ("saved",encode_request_body(validate_request(#saved e)))]);
  fun decode_request_envelope bytes:S.request_envelope=
    let val f=fields["association","request","goal","slot","semantic-generation",
        "code-generation","operation","saved"](decode "domain-request-envelope" bytes);
      val e={association=dec_id(f"association"),request=dec_id(f"request"),goal=dec_id(f"goal"),
        slot=dec_id(f"slot"),semantic_generation=dec_id(f"semantic-generation"),
        code_generation=dec_id(f"code-generation"),operation=dec_id(f"operation"),
        saved=decode_request_body(f"saved")}:S.request_envelope;
      val _=require(#association e= #slot e andalso forall positive
        [#association e,#request e,#goal e,#semantic_generation e,#code_generation e,#operation e])
        "Domain recovery request envelope identity";
    in e end;
  fun encode_output_envelope(e:S.output_envelope)=
    encode "domain-runtime-refinement-envelope"(record
      [("association",enc_id(#association e)),("request",enc_id(#request e)),
       ("goal",enc_id(#goal e)),("slot",enc_id(#slot e)),
       ("interpretation",enc_id(#interpretation e)),("claim",enc_id(#claim e)),
       ("target",enc_id(#target e)),("evidence",enc_id(#evidence e)),("output",enc_id(#output e)),
       ("execution",enc_id(#execution e)),("batch",enc_id(#batch e)),
       ("semantic-generation",enc_id(#semantic_generation e)),
       ("code-generation",enc_id(#code_generation e)),("operation",enc_id(#operation e)),
       ("saved",encode_output_body(#saved e))]);
  fun decode_output_envelope bytes:S.output_envelope=
    let val f=fields["association","request","goal","slot","interpretation","claim","target",
        "evidence","output","execution","batch","semantic-generation","code-generation","operation","saved"]
        (decode "domain-runtime-refinement-envelope" bytes);
      val e={association=dec_id(f"association"),request=dec_id(f"request"),goal=dec_id(f"goal"),
        slot=dec_id(f"slot"),interpretation=dec_id(f"interpretation"),claim=dec_id(f"claim"),
        target=dec_id(f"target"),evidence=dec_id(f"evidence"),output=dec_id(f"output"),
        execution=dec_id(f"execution"),batch=dec_id(f"batch"),
        semantic_generation=dec_id(f"semantic-generation"),code_generation=dec_id(f"code-generation"),
        operation=dec_id(f"operation"),saved=decode_output_body(f"saved")}:S.output_envelope;
      val _=require(#association e= #evidence e andalso forall positive
        [#association e,#request e,#goal e,#slot e,#interpretation e,#claim e,#target e,#output e,
         #execution e,#batch e,#semantic_generation e,#code_generation e,#operation e])
        "Domain recovery runtime-refinement envelope identity";
    in e end;
end;
