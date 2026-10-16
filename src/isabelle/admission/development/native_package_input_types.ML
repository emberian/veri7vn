(* Inert source metadata and the one closed transfer-header codec. No source,
   prepared-input, ticket, context or artifact constructor is exported here. *)
structure Veri7vn_Native_Package_Input_Types =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure Intent=Veri7vn_Native_Export_Intent;
  type metadata={upload_nonce:string,revision:string,manifest:string,descriptor_path:string,theory_path:string,
    descriptor_size:int,theory_size:int,descriptor_sha256:string,theory_sha256:string,
    parents:IntInf.int list};
  type expectation={package_id:string,package_version:string,session:string,
    theories:string list,files:(string * string) list,dependencies:(string * string) list,
    capabilities:Intent.capability list};
  type binding={metadata:metadata,expectation:expectation,descriptor_source:P.source_owner,
    descriptor_slice:L.slice,theory_source:P.source_owner,theory_slice:L.slice,
    source_revision:IntInf.int,manifest:IntInf.int,export_intent:IntInf.int};
  fun require true _=() | require false text=error text;
  fun exact keys attributes=require(sort_strings(map #1 attributes)=sort_strings keys)
    "Package input attributes";
  fun attr attributes name=the(AList.lookup(op =)attributes name);
  fun natural text=case Int.fromString text of SOME n=>
      if n>=0 andalso Int.toString n=text then n else error "Package input decimal"
    | NONE=>error "Package input decimal";
  fun positive text=case IntInf.fromString text of SOME n=>
      if n>0 andalso size text<=128 andalso IntInf.toString n=text then n
      else error "Package input identity" | NONE=>error "Package input identity";
  fun digest text=size text=64 andalso forall(fn c=>Char.isDigit c orelse
    (c>= #"a" andalso c<= #"f"))(String.explode text);
  fun portable text=size text>0 andalso size text<=4096 andalso
    forall(fn c=>Char.isAlphaNum c orelse member(op =)[#"_",#"-",#".",#"/"]c)(String.explode text)
    andalso forall(fn p=>p<>"" andalso p<>"." andalso p<>"..") (space_explode "/" text);
  fun nonce text=size text=32 andalso forall(fn c=>Char.isDigit c orelse
    (c>= #"a" andalso c<= #"f"))(String.explode text);
  fun bounded text=size text>0 andalso size text<=4096;
  fun decode_header raw:metadata=
    let val _=require(size raw<=16384) "Package input header bound"
      val (attributes,children)=case YXML.parse_body raw of
        [XML.Elem(("build-input",a),c)]=>(a,c) | _=>error "Package input header shape"
      val _=exact ["version","upload_nonce","revision","manifest","descriptor_path","theory_path",
        "descriptor_size","theory_size","descriptor_sha256","theory_sha256"] attributes
      val get=attr attributes
      val _=require(get "version"="1") "Package input header version"
      val parents=map(fn XML.Elem(("parent",a),[])=>
        (exact["candidate"]a;positive(attr a "candidate"))
        | _=>error "Package input parent shape")children
      val m={upload_nonce=get "upload_nonce",revision=get "revision",manifest=get "manifest",descriptor_path=get "descriptor_path",
        theory_path=get "theory_path",descriptor_size=natural(get "descriptor_size"),
        theory_size=natural(get "theory_size"),descriptor_sha256=get "descriptor_sha256",
        theory_sha256=get "theory_sha256",parents=parents}:metadata
      val _=require(nonce(#upload_nonce m) andalso forall digest [#revision m,#manifest m,#descriptor_sha256 m,#theory_sha256 m]
        andalso #descriptor_path m="package.json" andalso portable(#theory_path m)
        andalso String.isSuffix ".thy" (#theory_path m) andalso
        #descriptor_size m>0 andalso #descriptor_size m<=1000000 andalso
        #theory_size m>0 andalso #theory_size m<=1000000 andalso length parents<=64
        andalso length(distinct(op =)parents)=length parents) "Package input header bounds"
    in m end;
  val decode_metadata=decode_header;
  fun encode_metadata (m:metadata)=
    let val attributes=[("version","1"),("upload_nonce",#upload_nonce m),
      ("revision",#revision m),("manifest",#manifest m),("descriptor_path",#descriptor_path m),
      ("theory_path",#theory_path m),("descriptor_size",string_of_int(#descriptor_size m)),
      ("theory_size",string_of_int(#theory_size m)),("descriptor_sha256",#descriptor_sha256 m),
      ("theory_sha256",#theory_sha256 m)]
      val raw=YXML.string_of_body[XML.Elem(("build-input",attributes),
        map(fn id=>XML.Elem(("parent",[("candidate",IntInf.toString id)]),[]))(#parents m))]
      val _=decode_header raw
    in raw end;
end;
