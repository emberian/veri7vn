theory Native_Policy_Identity_Tests
  imports "Veri7vn_Admission.Veri7vn_Admission"
begin
ML \<open>
local
  structure A=Veri7vn_Native_Admission;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Roots=Veri7vn_Native_Installed_Roots;
  structure V=Veri7vn_Native_Recovery_Check;
  fun assert true _=()|assert false text=error text;
  fun rejects action=case Exn.capture action()of Exn.Exn _=>()|Exn.Res _=>error "Expected policy configuration refusal";
  val thy= @{theory};
  val locator=Context.theory_name{long=true}thy;
  val kernel=A.policy thy;
  val first=A.policy_with_oracles thy ["test.beta","test.alpha","test.alpha"];
  val second=A.policy_with_oracles thy ["test.alpha","test.beta"];
  val different=A.policy_with_oracles thy ["test.alpha"];
  val _=assert(A.same_policy_configuration(first,second) andalso
    not(A.same_policy_configuration(first,different)) andalso
    not(A.same_policy_configuration(kernel,first))) "Policy identity discarded or reordered permissions";
  val copied=A.fresh_policy first;
  val _=assert(A.same_policy_configuration(first,copied)) "Fresh policy cache changed immutable configuration";
  val plain_roots=Roots.capture_setup[(locator,kernel)];
  val first_roots=Roots.capture_setup[(locator,first)];
  val second_roots=Roots.capture_setup[(locator,second)];
  val _=assert(Roots.same(first_roots,second_roots) andalso not(Roots.same(first_roots,plain_roots)))
    "Installed root comparison used only theory identity";
  val _=assert(Roots.matches first_roots locator thy andalso
    Roots.matches_policy first_roots locator second andalso
    not(Roots.matches_policy first_roots locator kernel)) "Loader theory matching confused policy matching";
  (* Preserve the historical empty-permission root bytes exactly. *)
  val legacy=YXML.string_of_body[XML.Elem(("veri7vn-installed-native-roots",[("version","1")]),
    XML.Encode.pair(XML.Encode.list XML.Encode.string)
      (XML.Encode.list(XML.Encode.pair XML.Encode.string XML.Encode.string))([locator],[]))];
  val _=assert(Roots.material plain_roots=legacy andalso
    Roots.material first_roots=Roots.material second_roots andalso
    Roots.material first_roots<>legacy) "Installed root policy wire compatibility failed";
  val image=V.install_host_image_with_roots plain_roots kernel "policy-identity-unit-image";
  val changed=V.install_host_image_with_roots first_roots first "policy-identity-unit-image";
  val _=assert(V.context_closure image<>V.context_closure changed) "Image closure omitted actual policy configuration";
  val _=rejects(fn()=>V.install_host_image_with_roots plain_roots first "conflicting-policy-unit-image");
  val allocator=I.install_host_block{workspace="d123456789abcdef0123456789abcdef",first=100,past=10000};
  val dev=P.public_image allocator first;
  val _=assert(A.same_policy_configuration(P.development_policy dev,first))
    "Public native context discarded its approved policy configuration";
  val _=P.release dev;
  val _=rejects(fn()=>A.policy_with_oracles thy(map(fn n=>"test.oracle"^Int.toString n)(1 upto 257)));
  val _=rejects(fn()=>A.policy_with_oracles thy[String.implode(replicate 4097 #"a")]);
  val _=writeln "native_installed_policy_configuration_identity_ok";
in end;
\<close>
end
