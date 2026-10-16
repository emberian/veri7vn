(* Explicit unresolved variant of InitialQualificationRequest v2. Decoding is
   inert and cannot produce a candidate, native generation or observation. *)
structure Veri7vn_Initial_Template_Codec =
struct
  structure T=Veri7vn_Initial_Qualification_Template_Types;
  structure W=Veri7vn_Qualification_Codec;
  fun prepared(p:T.prepared_pin)=XML.Elem(("prepared",[]),[
    W.strings "identity"(map W.number[#template p,#source_owner p,#source_revision p,#manifest p,
      #profile p,#setup p,#export_intent p,#candidate p]),
    W.strings "parents"(W.ids(#parents p)),W.strings "dependencies"(W.ids(#dependencies p))]);
  fun parse_prepared tree=(case tree of XML.Elem(("prepared",[]),[identity,parents,dependencies])=>
    (case map W.positive(W.parse_strings "identity" identity) of
      [template,source_owner,source_revision,manifest,profile,setup,export_intent,candidate]=>
      {template=template,source_owner=source_owner,source_revision=source_revision,manifest=manifest,
        profile=profile,setup=setup,export_intent=export_intent,candidate=candidate,
        parents=W.parse_ids(W.parse_strings "parents" parents),
        dependencies=W.parse_ids(W.parse_strings "dependencies" dependencies)}:T.prepared_pin
      | _=>error "Initial template prepared arity") | _=>error "Initial template prepared shape");
  fun plan(p:T.build_plan)=XML.Elem(("build",[]),[
    W.strings "identity"(map W.number[#request p,#goal p,#slot p,#execution p,#semantic_generation p]),
    W.strings "inputs"(W.ids(#input_bindings p))]);
  fun parse_plan tree=(case tree of XML.Elem(("build",[]),[identity,inputs])=>
    (case map W.positive(W.parse_strings "identity" identity) of
      [request,goal,slot,execution,semantic_generation]=>{request=request,goal=goal,slot=slot,
        execution=execution,semantic_generation=semantic_generation,
        input_bindings=W.parse_ids(W.parse_strings "inputs" inputs)}:T.build_plan
      | _=>error "Initial template build plan arity") | _=>error "Initial template build plan shape");
  fun encode({context,names,prepared=pin,build,profile,dependencies}:T.snapshot)=
    let
      val _=W.require(profile=W.initial_profile andalso #request build= #request context andalso
        #goal build<> #goal context andalso #slot build<> #request_slot context andalso
        #slot build<> #slot context andalso #request_slot context<> #slot context)
        "Initial template role/child slot mismatch"
      val raw=YXML.string_of_body[XML.Elem(("initial-qualification-request",
        [("version","2"),("variant","template"),("profile",profile),("slot",W.number(#request_slot context))]),
        [W.strings "names"(W.names names),W.strings "context"(W.initial_context context),
          prepared pin,plan build,W.strings "dependencies"(W.ids dependencies)])]
      val _=W.framing raw
    in raw end;
  fun decode raw=
    let val _=W.framing raw
      val (slot,result)=case YXML.parse_body raw of
        [XML.Elem(("initial-qualification-request",[("version","2"),("variant","template"),
          ("profile",profile),("slot",slot)]),[names,context,pin,build,dependencies])]=>
          (W.positive slot,{context=W.parse_initial(W.parse_strings "context" context),
            names=W.parse_names(W.parse_strings "names" names),prepared=parse_prepared pin,
            build=parse_plan build,profile=profile,
            dependencies=W.parse_ids(W.parse_strings "dependencies" dependencies)}:T.snapshot)
        | _=>error "Initial qualification template v2 schema"
      val _=W.require(slot= #request_slot(#context result) andalso encode result=raw)
        "Noncanonical initial qualification template"
    in result end;
  datatype variant=Template | Bound;
  fun variant raw=
    let val _=W.framing raw
    in case YXML.parse_body raw of
      [XML.Elem(("initial-qualification-request",[("version","2"),("variant",kind),
        ("profile",profile),("slot",slot)]),_)]=>
        (ignore(W.positive slot);W.require(profile=W.initial_profile) "Initial request profile";
         case kind of "template"=>Template | "bound"=>Bound | _=>error "Initial request variant")
      | _=>error "Unsupported initial request wire version/schema" end;
end;
