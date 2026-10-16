theory Domain_Recovery_Payload_Checks
  imports "Veri7vn_Domain_Recovery_Payload.Domain_Recovery_Payload"
begin
ML \<open>
local
  structure X=Veri7vn_Domain_Recovery_Payload;
  structure D=Veri7vn_Domain_Request;
  structure G=Veri7vn_Domain_Native_Gate;
  structure C=Veri7vn_Domain_Conditions;
  structure S=Veri7vn_Domain_Saved_Types;
  (* Deliberately inert records: successful decoding must not create a native
     condition, request, theorem, gate or preserved-ID witness. *)
  val text="registered_domain_dispatch (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 1] [20] None)";
  val saved:D.saved={workspace="abababababababababababababababab",input_identity=10,
    input=Syntax.read_term @{context} text,
    template= @{term "domain_call_meaning (DomainCall (ConvertLinear Metre Centimetre) [LinearValue Metre 1] [20] None)"},
    bytes=text,encoding="UTF-8",input_source_span=(0,size text),context_dependencies=[40],
    owners=[(30,"True","UTF-8")],conditions=[{identity=20,owner_identity=30,
      role=C.InputCondition,proposition= @{prop True},source_span=(0,4),dependencies=[30,40]}],
    implementation=Thm.prop_of @{thm domain_execution_refinement},model_contract=NONE};
  val encoded=X.encode_request saved;
  val decoded=X.decode_request encoded;
  val _=if decoded=saved then ()else error "Domain recovery payload lost exact source/condition data";
  val output:G.saved={request=saved,output= @{term "DomainAnswer (LinearValue Centimetre 100) [20]"},
    target= @{prop True},implementation= #implementation saved,model_contract=NONE,
    rendering_contract=Thm.prop_of @{thm fixed_domain_display_contract_checked},
    statement_html="<p>Conditional on all 1 attached premises: Exact quantity 100/1 cm</p>"};
  val decoded_output=X.decode_output(X.encode_output output);
  val _=if decoded_output=output then ()else error "Runtime-refinement data roundtrip changed its target/contracts";
  val request_envelope:S.request_envelope={association=11,request=12,goal=13,slot=11,
    semantic_generation=40,code_generation=14,operation=15,saved=saved};
  val output_envelope:S.output_envelope={association=21,request=12,goal=13,slot=11,
    interpretation=22,claim=23,target=24,evidence=21,output=25,execution=26,batch=27,
    semantic_generation=40,code_generation=14,operation=15,saved=output};
  val _=if X.decode_request_envelope(X.encode_request_envelope request_envelope)=request_envelope andalso
    X.decode_output_envelope(X.encode_output_envelope output_envelope)=output_envelope
    then ()else error "Domain envelopes lost original request/output naming";
  fun refuses f=if can f()then error "Malformed domain recovery payload accepted"else ();
  val _=refuses(fn()=>X.decode_output encoded);
  val _=refuses(fn()=>X.decode_request(X.encode_output output));
  val _=refuses(fn()=>X.decode_output "kernel-evidence");
  val _=refuses(fn()=>X.decode_request_envelope(X.encode_output_envelope output_envelope));
  val wrong_association:S.output_envelope={association=11,request=12,goal=13,slot=11,
    interpretation=22,claim=23,target=24,evidence=21,output=25,execution=26,batch=27,
    semantic_generation=40,code_generation=14,operation=15,saved=output};
  val _=refuses(fn()=>X.decode_output_envelope(X.encode_output_envelope wrong_association));
  val duplicate=(case YXML.parse_body encoded of [XML.Elem(root,field::rest)]=>
    YXML.string_of_body[XML.Elem(root,field::field::rest)] | _=>error "Fixture framing");
  val _=refuses(fn()=>X.decode_request duplicate);
  val wrong_version=(case YXML.parse_body encoded of [XML.Elem((root,_),body)]=>
    YXML.string_of_body[XML.Elem((root,[("version","2")]),body)] | _=>error "Fixture framing");
  val _=refuses(fn()=>X.decode_request wrong_version);
  val _=refuses(fn()=>X.decode_request(String.implode(replicate 1048577 #"x")));
in val _=writeln "VERI7VN_DOMAINS inert_recovery_payload PASS" end;
\<close>
end
