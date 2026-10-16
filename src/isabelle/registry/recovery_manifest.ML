(* Inert durable association envelope. Parsing grants no native/metadata authority.
   Blob digests establish integrity only when bound by the existing host commit. *)
signature VERI7VN_RECOVERY_MANIFEST =
sig
  datatype payload_profile = KernelEvidence | MathRequest | MathOutput | BuildRequest | BuildCandidate | InitialQualification | UpdateQualification | InitialQualificationRequest | UpdateQualificationRequest | DomainRequest | DomainOutput | SearchRequest | SearchOutput | SourceDomainRequest | SourceDomainOutput | SessionInput
  datatype reconstruction = Fixed_Certificate | Native_Proof | Controlled_Recipe
  type manifest = {profile: payload_profile, workspace: string, association: IntInf.int, semantic_generation: IntInf.int,
    projection: string, sequent: string, context_closure: string,
    reconstruction: reconstruction, payload: string, executable: string option}
  val require_profile: payload_profile -> manifest -> unit
  val encode: manifest -> string
  val decode: {max_bytes: int} -> string -> manifest
end;
structure Veri7vn_Recovery_Manifest :> VERI7VN_RECOVERY_MANIFEST =
struct
  datatype payload_profile = KernelEvidence | MathRequest | MathOutput | BuildRequest | BuildCandidate | InitialQualification | UpdateQualification | InitialQualificationRequest | UpdateQualificationRequest | DomainRequest | DomainOutput | SearchRequest | SearchOutput | SourceDomainRequest | SourceDomainOutput | SessionInput;
  datatype reconstruction = Fixed_Certificate | Native_Proof | Controlled_Recipe;
  type manifest = {profile: payload_profile, workspace: string, association: IntInf.int, semantic_generation: IntInf.int,
    projection: string, sequent: string, context_closure: string,
    reconstruction: reconstruction, payload: string, executable: string option};
  fun hex n s = size s = n andalso forall (fn c =>
    Char.isDigit c orelse (c >= #"a" andalso c <= #"f")) (String.explode s);
  fun kind Fixed_Certificate = "fixed-certificate"
    | kind Native_Proof = "native-proof"
    | kind Controlled_Recipe = "controlled-recipe";
  fun profile_fields KernelEvidence = ("native-kernel/1","kernel-evidence")
    | profile_fields MathRequest = ("exact-arithmetic/1","math-request")
    | profile_fields MathOutput = ("exact-arithmetic/1","math-output")
    | profile_fields BuildRequest = ("native-development/1","build-request")
    | profile_fields BuildCandidate = ("native-development/1","build-candidate")
    | profile_fields InitialQualification = ("native-export-admission/1","initial-qualification")
    | profile_fields UpdateQualification = ("named-native-export-structure/1","update-qualification")
    | profile_fields InitialQualificationRequest = ("native-export-admission/1","initial-qualification-request")
    | profile_fields UpdateQualificationRequest = ("named-native-export-structure/1","update-qualification-request")
    | profile_fields DomainRequest = ("quantities/1","domain-request")
    | profile_fields DomainOutput = ("quantities-runtime-refinement/1","domain-output")
    | profile_fields SearchRequest = ("literal-native-proof/1","search-request")
    | profile_fields SearchOutput = ("literal-native-proof/1","search-output")
    | profile_fields SourceDomainRequest = ("source-quantities/1","source-domain-request")
    | profile_fields SourceDomainOutput = ("source-quantities-runtime-refinement/1","source-domain-output")
    | profile_fields SessionInput = ("native-session-input/1","session-input");
  fun require_profile expected (m: manifest) =
    if #profile m = expected then () else error "Recovery payload profile/role mismatch";
  fun durable_id n = n > 0 andalso size (IntInf.toString n) <= 128;
  fun validate (m: manifest) =
    let val _ = (case (#profile m,#reconstruction m,#executable m) of
      (KernelEvidence,_,NONE) => ()
    | (MathRequest,Controlled_Recipe,SOME _) => ()
    | (MathOutput,Controlled_Recipe,SOME _) => ()
    | (BuildRequest,Controlled_Recipe,SOME _) => ()
    | (BuildCandidate,Controlled_Recipe,SOME _) => ()
    | (InitialQualification,Controlled_Recipe,SOME _) => ()
    | (UpdateQualification,Controlled_Recipe,SOME _) => ()
    | (InitialQualificationRequest,Controlled_Recipe,SOME _) => ()
    | (UpdateQualificationRequest,Controlled_Recipe,SOME _) => ()
    | (DomainRequest,Controlled_Recipe,SOME _) => ()
    | (DomainOutput,Controlled_Recipe,SOME _) => ()
    | (SearchRequest,Controlled_Recipe,SOME _) => ()
    | (SearchOutput,Controlled_Recipe,SOME _) => ()
    | (SourceDomainRequest,Controlled_Recipe,SOME _) => ()
    | (SourceDomainOutput,Controlled_Recipe,SOME _) => ()
    | (SessionInput,Controlled_Recipe,SOME _) => ()
    | _ => error "Recovery payload profile/recipe/executable mismatch")
    in if hex 32 (#workspace m) andalso durable_id (#association m) andalso durable_id (#semantic_generation m)
      andalso forall (hex 64) ([#projection m,#sequent m,#context_closure m,#payload m] @
        the_list (#executable m)) then m else error "Invalid recovery locator/integrity envelope" end;
  fun encode m =
    let val m = validate m
      val (profile,role) = profile_fields (#profile m)
    in YXML.string_of_body [XML.Elem
      (("veri7vn-native-association", [("version","2"),("profile",profile),("role",role),("workspace",#workspace m),
        ("association",IntInf.toString (#association m)),
        ("semantic-generation",IntInf.toString (#semantic_generation m)),
        ("projection",#projection m),("sequent",#sequent m),
        ("context-closure",#context_closure m),("kind",kind (#reconstruction m)),
        ("payload",#payload m),("executable",the_default "" (#executable m))]),[])] end;
  (* Inspect framing before recursive YXML parsing. This envelope has no child
     elements at all; a hostile nested body must not reach the parser. *)
  fun shallow bytes =
    let
      val n = size bytes;
      fun walk i depth roots =
        if i >= n then if depth=0 andalso roots=1 then () else error "Recovery envelope framing"
        else if String.sub (bytes,i) = Char.chr 5 andalso i+1<n andalso
          String.sub (bytes,i+1) = Char.chr 6 then
          if i+2<n andalso String.sub (bytes,i+2) = Char.chr 5 then
            if depth=1 then walk (i+3) 0 roots else error "Recovery envelope closing depth"
          else if depth=0 andalso roots=0 then walk (i+2) 1 1
          else error "Nested/multiple recovery envelope"
        else walk (i+1) depth roots;
    in walk 0 0 0 end;
  fun decode {max_bytes} bytes =
    if max_bytes < 0 orelse size bytes > Int.min (max_bytes, 8192) then error "Recovery envelope byte bound"
    else (shallow bytes; case YXML.parse_body bytes of
      [XML.Elem (("veri7vn-native-association", attrs),[])] =>
        let
          val versions = map_filter (fn (key,value) => if key="version" then SOME value else NONE) attrs;
          val _ = (case versions of ["2"] => ()
            | [_] => error "Unsupported recovery envelope version; explicit migration required"
            | _ => error "Recovery envelope missing/duplicate version");
          val keys=["version","profile","role","workspace","association","semantic-generation","projection",
            "sequent","context-closure","kind","payload","executable"];
          val _ = if sort_strings (map #1 attrs) = sort_strings keys then ()
            else error "Recovery envelope fields/duplicates";
          fun field key = the (AList.lookup (op =) attrs key);
          val profile = (case (field "profile",field "role") of
            ("native-kernel/1","kernel-evidence") => KernelEvidence
          | ("exact-arithmetic/1","math-request") => MathRequest
          | ("exact-arithmetic/1","math-output") => MathOutput
          | ("native-development/1","build-request") => BuildRequest
          | ("native-development/1","build-candidate") => BuildCandidate
          | ("native-export-admission/1","initial-qualification") => InitialQualification
          | ("named-native-export-structure/1","update-qualification") => UpdateQualification
          | ("native-export-admission/1","initial-qualification-request") => InitialQualificationRequest
          | ("named-native-export-structure/1","update-qualification-request") => UpdateQualificationRequest
          | ("quantities/1","domain-request") => DomainRequest
          | ("quantities-runtime-refinement/1","domain-output") => DomainOutput
          | ("literal-native-proof/1","search-request") => SearchRequest
          | ("literal-native-proof/1","search-output") => SearchOutput
          | ("source-quantities/1","source-domain-request") => SourceDomainRequest
          | ("source-quantities-runtime-refinement/1","source-domain-output") => SourceDomainOutput
          | ("native-session-input/1","session-input") => SessionInput
          | _ => error "Unsupported recovery payload profile/role");
          fun number key = (case IntInf.fromString (field key) of SOME n =>
            if IntInf.toString n = field key then n else error "Noncanonical recovery number"
            | NONE => error "Recovery number");
          val reconstruction = (case field "kind" of "fixed-certificate" => Fixed_Certificate
            | "native-proof" => Native_Proof | "controlled-recipe" => Controlled_Recipe
            | _ => error "Unregistered recovery kind");
        in validate {profile=profile,workspace=field "workspace",association=number "association",
          semantic_generation=number "semantic-generation",projection=field "projection",
          sequent=field "sequent",context_closure=field "context-closure",
          reconstruction=reconstruction,payload=field "payload",
          executable=if field "executable" = "" then NONE else SOME (field "executable")} end
    | _ => error "Recovery envelope shape");
end;
