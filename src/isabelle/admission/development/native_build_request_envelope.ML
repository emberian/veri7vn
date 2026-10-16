(* Versioned inert BuildRequest carrier. The control plan and observed diagnostic
   are authenticated only by the fixed committed-role/checkpoint checker. *)
structure Veri7vn_Native_Build_Request_Envelope =
struct
  structure Plan=Veri7vn_Native_Deferred_Build_Codec;
  structure Terminal=Veri7vn_Native_Build_Terminal;
  datatype phase=Prepared|ObservedFailure of Terminal.failure;
  type packet={plan:Veri7vn_Native_Deferred_Build_Types.plan,phase:phase,body:string};
  fun require true _=()|require false message=error message;
  fun encoded bytes=Bytes.content(Base64.encode(Bytes.string bytes));
  fun decoded text=Bytes.content(Base64.decode(Bytes.string text));
  fun text tag bytes=XML.Elem((tag,[]),[XML.Text(encoded bytes)]);
  fun validate({plan,phase,body}:packet)=
    (require(size body<=100000) "Build request inner recipe bound";
     case phase of Prepared=>()|ObservedFailure failure=>
       (Terminal.validate failure;
        require(#request failure= #request plan andalso #goal failure= #goal plan andalso
          #slot failure= #slot plan andalso #execution failure= #execution plan andalso
          #source_revision failure= #source_revision(#source plan) andalso
          #manifest failure= #manifest(#source plan)) "Build failure/control plan identity differs"));
  fun encode(p:packet)=
    let val _=validate p
      val plan=Plan.encode(#plan p)
      val diagnostic=case #phase p of Prepared=>""|ObservedFailure failure=>Terminal.encode failure
      (* Refuse oversized prepared material before charging, reserving the full
         terminal frame allowance for a subsequent observed failure. *)
      val limit=case #phase p of Prepared=>64000|ObservedFailure _=>74000
      val _=require(size plan+size diagnostic+size(#body p)<=limit)
        "Build request aggregate metadata/terminal headroom bound"
      val phase=case #phase p of Prepared=>XML.Elem(("prepared",[]),[])
        |ObservedFailure failure=>text "observed-failure"(Terminal.encode failure)
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-build-request",[("version","1")]),
        [text "control-plan" plan,phase,text "native-recipe"(#body p)])]
    in require(size bytes<=100000) "Build request envelope bound";bytes end;
  fun decode bytes:packet=
    let val _=Veri7vn_Native_Construction_Codec.framing bytes
      val _=require(size bytes<=100000) "Build request envelope bound"
      val (plan,phase,body)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-build-request",[("version","1")]),[plan,phase,body])] =>(plan,phase,body)
        |_=>error "Build request envelope shape"
      fun read tag(XML.Elem((name,[]),body))=
          if name=tag andalso forall(fn XML.Text _=>true|_=>false)body
          then decoded(XML.content_of body)else error "Build request envelope field"
        |read _ _=error "Build request envelope field"
      val phase=case phase of XML.Elem(("prepared",[]),[])=>Prepared
        |_=>ObservedFailure(Terminal.decode(read "observed-failure" phase))
      val result={plan=Plan.decode(read "control-plan" plan),phase=phase,
        body=read "native-recipe" body}:packet
      val _=validate result
      val _=require(encode result=bytes) "Noncanonical build request envelope"
    in result end;
end;
