theory Search_Source_Tests
  imports Search_Request_Codec_Tests
begin
ML_file "../../../../src/runtime/service/search/native_search_source.ML"
ML \<open>
local
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure T=Veri7vn_Private_Operation_Tickets();
  structure W=Veri7vn_Search_Fn(T);
  structure S=W.Search;
  structure Q=Veri7vn_Search_Request_Fn(S);
  structure Source=Veri7vn_Search_Source_Fn(structure S=S structure Q=Q);
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  fun assert true _=() | assert false message=error message;
  val ids=I.install_host_block{workspace="55555555555555555555555555555555",
    first=9000000000000000000000000000000,past=9000000000000000000000000010000};
  val policy=A.policy @{theory};
  val receiver=P.public_image ids policy;
  val owner=Source.bind_public ids policy receiver;
  fun packet context catalogue=
    let val header=Wire.document(Wire.node "search-policy"[("version","1"),("context",IntInf.toString context),
      ("expansions","32"),("frontier","16"),("successors","2"),("milliseconds","1000")]
      [Wire.node "catalogue"[](map(fn name=>Wire.node "fact"[][XML.Text name])catalogue),
       Wire.node "actions"[][Wire.action_xml S.Introduce,Wire.action_xml S.Split,Wire.action_xml S.Assume]]);
      val digits=string_of_int(size header)
    in replicate_string(8-size digits)"0" ^ digits ^ "\n" ^ header ^ "  P --> (P & P)  \n"end;
  val root=Unsynchronized.ref NONE;
  val entry=Source.prepare_into root owner(packet(Source.context owner)[]);
  val _=assert(is_some(!root) andalso Source.live entry) "Search source did not register owned handoff";
  val q=Source.request entry;
  val original=P.source_input(Source.source entry);
  val projection=Source.project entry;
  val _=assert(L.bytes original="  P --> (P & P)  \n" andalso
    #identity projection=Scope.identity(Source.child entry) andalso
    Q.project_scope q=SOME(#identity projection) andalso Q.cost q= #cost projection)
    "Search source helper changed actual source/context/child association";
  val _=assert(not(can (Scope.new_child(Source.parent entry))
    {source=Scope.source(Source.child entry),predecessors=[]})) "Search singleton parent was not sealed";
  val wrong_root=Unsynchronized.ref NONE;
  val _=assert(not(can (Source.prepare_into wrong_root owner)(packet(Source.context owner+1)[])) andalso is_none(!wrong_root))
    "Search source accepted another context selector";
  val failed_root=Unsynchronized.ref NONE;
  val _=assert(not(can (Source.prepare_into failed_root owner)
    (packet(Source.context owner)["HOL.TrueI","NoSuchNativeFact"])) andalso Source.owner_live owner)
    "Failed catalogue preparation damaged shared public owner";
  val _=Option.app Source.release(!failed_root);
  val private_alias=P.context_alias receiver;
  val _=assert(not(can (Source.bind_public ids policy)private_alias))
    "Search first profile accepted a nonpublic alias as shipped public context";
  val _=P.release private_alias;
  val _=Source.deny entry;
  val _=assert(not(Source.live entry) andalso not(can Source.request entry)) "Denied source still exposed executable Q request";
  val _=Source.release entry;
  val _=assert(L.disposed original andalso I.lookup_input_identity ids original=NONE andalso P.development_live receiver)
    "Search source retained base bytes or destroyed shared receiver";
  val next_root=Unsynchronized.ref NONE;
  val next=Source.prepare_into next_root owner(packet(Source.context owner)["HOL.TrueI"]);
  val _=assert(Source.live next) "Search source could not reuse shared public context after release";
  val _=Source.release next;
  val _=P.release receiver;
  val _=writeln "VERI7VN_SEARCH_SOURCE_TESTS_PASSED";
in end
\<close>
end
