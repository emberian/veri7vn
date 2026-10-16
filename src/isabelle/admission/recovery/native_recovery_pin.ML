(* Canonical inert identity material for a fixed shipped native producer. This is
   build identity only: neither a serialized pin nor implementation acceptance.
   The installed image closure authenticates code context/build ancestry; adapters
   still compare the actual current opaque pins with Executable_Identity.same. *)
structure Veri7vn_Native_Recovery_Pin =
struct
  structure E=Veri7vn_Executable_Identity;
  fun encoded text=Bytes.content(Base64.encode(Bytes.string text));
  val body=XML.Encode.pair XML.Encode.string
    (XML.Encode.pair XML.Encode.string
      (XML.Encode.pair XML.Encode.string
        (XML.Encode.pair XML.Encode.string
          (XML.Encode.triple (XML.Encode.list XML.Encode.string)
            (XML.Encode.list XML.Encode.string)(XML.Encode.list XML.Encode.string)))));
  fun material pin=
    let val m=E.manifest pin
      val theory=Context.theory_name{long=true}(E.code_theory pin)
      val groups=[#serializers m,#foreign_primitives m,#settings m]
      val strings=[theory,#artifact m,#compiler m,#target m] @ flat groups
      val _=if length strings<=4096 andalso size theory<=4096 andalso
          forall(fn text=>size text<=65536)strings andalso
          fold(fn text=>fn total=>total+size text)strings 0<=524288
        then()else error "Native recovery pin material bounds"
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-fixed-native-producer",[("version","1")]),
        body(encoded theory,(encoded(#artifact m),(encoded(#compiler m),(encoded(#target m),
          (map encoded(#serializers m),map encoded(#foreign_primitives m),map encoded(#settings m)))))))]
    in if size bytes<=1048576 then bytes else error "Native recovery pin encoded byte bound"end;
  fun digest pin=Message_Digest.rep(SHA256.digest(material pin));
end;
