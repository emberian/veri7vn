(* Inert original-plan support for a committed candidate. It is deliberately
   distinct from a live BuildRequest and cannot mint a Scope, ticket or owner.
   The fixed candidate factory must check both halves against the SAME C role. *)
structure Veri7vn_Native_Build_Candidate_Envelope =
struct
  structure Plan=Veri7vn_Native_Deferred_Build_Codec;
  structure Header=Veri7vn_Native_Package_Input_Types;
  type packet={plan:Veri7vn_Native_Deferred_Build_Types.plan,body:string};
  fun require true _=()|require false message=error message;
  fun encoded bytes=Bytes.content(Base64.encode(Bytes.string bytes));
  fun decoded bytes=Bytes.content(Base64.decode(Bytes.string bytes));
  fun text tag bytes=XML.Elem((tag,[]),[XML.Text(encoded bytes)]);
  fun encode({plan,body}:packet)=
    let val control=Plan.encode plan
      val _=require(size control+size body<=74000) "Build candidate decoded support bound"
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-candidate",[("version","1")]),
        [text "original-plan" control,text "native-recipe" body])]
    in require(size bytes<=100000) "Build candidate role byte bound";bytes end;
  fun decode bytes:packet=
    let val _=require(size bytes<=100000) "Build candidate role byte bound"
      val _=Veri7vn_Native_Construction_Codec.framing bytes
      val(control,body)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-build-candidate",attributes),[plan,recipe])]=>
          let val _=Header.exact["version"]attributes
            val _=require(Header.attr attributes "version"="1") "Build candidate support version"
            fun content expected(XML.Elem((tag,[]),[XML.Text raw]))=
                  (require(tag=expected) "Build candidate support field";decoded raw)
              |content _ _=error "Build candidate support shape"
          in(content "original-plan" plan,content "native-recipe" recipe)end
        |_=>error "Build candidate support envelope"
      val _=require(size control+size body<=74000) "Build candidate decoded support bound"
      val result={plan=Plan.decode control,body=body}:packet
      val _=require(encode result=bytes) "Build candidate support is not canonical"
    in result end;
end;
