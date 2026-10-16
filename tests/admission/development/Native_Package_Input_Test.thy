theory Native_Package_Input_Test
  imports "Veri7vn_Native_Build_Candidate.Native_Build_Candidate"
begin
ML \<open>
local
  structure Inputs=Veri7vn_Native_Package_Inputs;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  val allocator=I.install_host_block{workspace="f123456789abcdef0123456789abcdef",first=1,past=60000};
  val pool=Inputs.create allocator;
  val descriptor="{}";
  val source="theory Input imports Main begin end";
  val header=YXML.string_of_body[XML.Elem(("build-input",[("version","1"),
    ("upload_nonce",String.implode(replicate 32 #"a")),("revision",String.implode(replicate 64 #"a")),("manifest",String.implode(replicate 64 #"b")),
    ("descriptor_path","package.json"),("theory_path","Input.thy"),
    ("descriptor_size",Int.toString(size descriptor)),("theory_size",Int.toString(size source)),
    ("descriptor_sha256",String.implode(replicate 64 #"0")),
    ("theory_sha256",String.implode(replicate 64 #"0"))]),[])];
  fun rejects f=case Exn.capture f() of Exn.Exn _=>() | Exn.Res _=>error "Expected package input rejection";
  fun nonce c=String.implode(replicate 32 c);
  fun with_nonce c=YXML.string_of_body(case YXML.parse_body header of
    [XML.Elem((name,a),body)]=>[XML.Elem((name,AList.update(op =)("upload_nonce",nonce c)a),body)]
    | _=>error "Input fixture header");
  val metadata=Inputs.decode_metadata header;
  val _=if Inputs.decode_metadata(Inputs.encode_metadata metadata)=metadata then ()
    else error "Original package metadata codec changed the captured binding";
  val _=rejects(fn()=>Inputs.decode_metadata(YXML.string_of_body
    (case YXML.parse_body header of [XML.Elem((name,a),body)]=>
      [XML.Elem((name,("version","1")::a),body)]|_=>[])));
  val first=Inputs.begin_input pool header;
  val retry=Inputs.begin_input pool header;
  val _=if Inputs.transfer_key first=Inputs.transfer_key retry then () else error "Nonce retry allocated duplicate stage";
  val _=Inputs.discard_nonce pool(nonce #"b");
  val _=rejects(fn()=>Inputs.begin_input pool(with_nonce #"b"));
  val _=Inputs.settle_nonce pool(nonce #"b");
  val second=Inputs.begin_input pool(with_nonce #"c");
  val _=rejects(fn()=>Inputs.begin_input pool(with_nonce #"d"));
  val _=rejects(fn()=>Inputs.write first Inputs.Descriptor 1(Bytes.string descriptor));
  val _=Inputs.write first Inputs.Descriptor 0(Bytes.string descriptor);
  val _=rejects(fn()=>Inputs.write first Inputs.Descriptor 0(Bytes.string descriptor));
  val _=Inputs.write first Inputs.Theory 0(Bytes.string source);
  val scope=P.construction_scope();
  (* Exact source hash failure happens before the installed Scala parser is
     invoked. This test cannot substitute a fake successful metadata adapter. *)
  val _=rejects(fn()=>Inputs.finish_owned scope first);
  val _=P.abort_scope scope;
  val _=Inputs.abort first;
  val _=Inputs.abort first;
  val _=Inputs.discard_nonce pool(String.implode(replicate 32 #"a"));
  val _=Inputs.settle_nonce pool(String.implode(replicate 32 #"a"));
  val replacement=Inputs.begin_input pool header;
  val _=Inputs.close pool;
  val _=rejects(fn()=>Inputs.write replacement Inputs.Theory 0(Bytes.string source));
  val _=rejects(fn()=>Inputs.begin_input pool header);
  val _=Inputs.abort second;
in val _=writeln "native_package_input_bounds_ok" end;
\<close>
end
