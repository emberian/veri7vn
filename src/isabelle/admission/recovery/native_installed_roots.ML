(* Privileged fixed-setup capture, never a decoded request or restore operation.
   An installed locator names its actual theory; the registry cannot turn a
   stronger boot context into a lower source import by relabelling it. *)
signature VERI7VN_NATIVE_INSTALLED_ROOTS =
sig
  type registry
  val capture_setup: (string * Veri7vn_Native_Admission.policy) list -> registry
  val capture_setup_with_imports: {roots:(string * Veri7vn_Native_Admission.policy) list,
    imports:(string * string) list,context:theory} -> registry
  val resolve_import: registry -> string -> string
  val locators: registry -> string list
  val policy: registry -> string -> Veri7vn_Native_Admission.policy
  val imports: registry -> (string * string) list
  val material: registry -> string
  val same: registry * registry -> bool
  val matches: registry -> string -> theory -> bool

end;
structure Veri7vn_Native_Installed_Roots :> VERI7VN_NATIVE_INSTALLED_ROOTS =
struct
  structure A=Veri7vn_Native_Admission;
  datatype registry=Registry of {roots:(string * A.policy) list,imports:(string * string) list};
  fun capture entries imports=
    let val _=if length entries<=128 then()else error "Installed native root bound"
      val names=map #1 entries
      val _=if length(distinct(op =)names)=length names then()
        else error "Duplicate installed native root locator"
      val _=List.app(fn(locator,policy)=>
        if size locator>0 andalso size locator<=512 andalso
          locator=Context.theory_name{long=true}(A.policy_theory policy)
        then()else error "Installed native root locator differs from actual theory")entries
      val _=if length imports<=512 andalso
        length(distinct(op =)(map #1 imports))=length imports andalso
        forall(fn(alias,root)=>size alias>0 andalso size alias<=512 andalso member(op =)names root andalso
          (not(member(op =)names alias) orelse alias=root))imports
        then()else error "Invalid fixed installed import aliases"
    in Registry{roots=entries,imports=imports}end;
  fun capture_setup entries=capture entries [];
  fun locators(Registry{roots,...})=map #1 roots;
  fun resolve_import(Registry{roots,imports}) locator=
    if is_some(AList.lookup(op =)roots locator)then locator else
    case AList.lookup(op =)imports locator of SOME root=>root
    | NONE=>error "Source import is not installed in this fixed setup";
  fun policy(Registry{roots,...}) locator=case AList.lookup(op =)roots locator of
    SOME policy=>policy|NONE=>error "Native root is not installed in this fixed setup";
  fun imports(Registry{imports,...})=imports;
  fun material(registry as Registry{imports,...})=YXML.string_of_body
    [XML.Elem(("veri7vn-installed-native-roots",[("version","1")]),
      XML.Encode.pair(XML.Encode.list XML.Encode.string)
        (XML.Encode.list(XML.Encode.pair XML.Encode.string XML.Encode.string))
        (locators registry,imports))];
  fun same(left,right)=locators left=locators right andalso imports left=imports right andalso
    forall(fn locator=>Context.eq_thy(A.policy_theory(policy left locator),A.policy_theory(policy right locator)))
      (locators left);
  fun matches registry locator theory=Context.eq_thy(A.policy_theory(policy registry locator),theory);
  fun capture_setup_with_imports {roots,imports,context}=
    let val registry=capture roots imports
      val qualifier=Resources.theory_qualifier(Context.theory_name{long=true}context)
      val directory=Resources.master_directory context
      val _=List.app(fn(alias,root)=>
        let val resolved=Resources.import_name qualifier directory alias
          val theory=Build.get_theory(#theory_name resolved)
        in if matches registry root theory then()
          else error "Fixed native import alias differs from installed loader theory"end)imports
    in registry end;
end;
