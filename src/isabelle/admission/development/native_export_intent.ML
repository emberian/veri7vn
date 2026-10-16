(* Original package expectation, not theorem authority. The sole production
   installer is the fixed host PackageModel parser bridge from the opaque captured
   NativeBuildInputs.ExportIntent. Never expose capture_owned as a decoded-name RPC.
   Original source ownership and exact protected revision/manifest association must
   be registered before this call; the owner checks the captured package mapping. *)
signature VERI7VN_NATIVE_EXPORT_INTENT =
sig
  type intent
  type locator={theory:string,name:string}
  type capability={id:string,specification:locator,contracts:locator list,
    executable:locator option}
  type binding={source:Veri7vn_Managed_Provenance.source_owner,
    slice:Veri7vn_Native_Literals.slice,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int,
    capabilities:capability list,dependencies:IntInf.int list}
  val binding:intent -> binding
  val theorem_names:intent -> Thm_Name.T list
  val executable_locators:intent -> locator list
  val workspace:intent -> string
  val same:intent * intent -> bool
  val is_live:intent -> bool
  val retain_owned:Veri7vn_Managed_Provenance.construction_scope -> intent -> intent
  val release:intent -> unit
end;
structure Veri7vn_Native_Export_Intent :>
sig
  include VERI7VN_NATIVE_EXPORT_INTENT
  val capture_owned:Veri7vn_Managed_Provenance.construction_scope ->
    {source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
     source_revision:IntInf.int,manifest:IntInf.int,export_intent:IntInf.int,
     capabilities:capability list} -> intent
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  type locator={theory:string,name:string};
  type capability={id:string,specification:locator,contracts:locator list,
    executable:locator option};
  type binding={source:P.source_owner,slice:L.slice,source_revision:IntInf.int,
    manifest:IntInf.int,export_intent:IntInf.int,
    capabilities:capability list,dependencies:IntInf.int list};
  type payload={binding:binding,lease:L.lease};
  datatype intent=Intent of {identity:serial,payload:payload option Synchronized.var};
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun is_live(Intent{payload,...})=case Synchronized.value payload of NONE=>false
    |SOME{binding={source,slice,...},lease}=>P.owns_input source(L.owner slice) andalso
      can L.lease_input lease;
  fun binding(intent as Intent{payload,...})=
    (require(is_live intent) "Original export intent released";
     case Synchronized.value payload of SOME{binding,...}=>binding
     |NONE=>error "Original export intent released");
  fun same(a as Intent{identity=x,...},b as Intent{identity=y,...})=
    x=y andalso is_live a andalso is_live b;
  fun workspace intent=P.source_workspace(#source(binding intent));
  (* The locator explicitly supplies a declaring theory. A local name denotes
     that theory's full name; an already qualified name must retain its exact
     declaring-theory prefix. Never ask the native context for a short alias. *)
  fun canonical({theory,name}:locator)=
    (if Long_Name.is_qualified name then
      (require(String.isPrefix(theory ^ ".")name) "Package locator declaring theory mismatch";name)
     else Long_Name.qualify theory name,0):Thm_Name.T;
  fun theorem_names intent=distinct(op =)(maps(fn(c:capability)=>
    map canonical(#specification c :: #contracts c))(#capabilities(binding intent)));
  fun executable_locators intent=map_filter #executable(#capabilities(binding intent));
  fun locator_ok({theory,name}:locator)=size theory>0 andalso size theory<=4096 andalso
    size name>0 andalso size name<=4096;
  fun capture_owned scope {source,slice,source_revision,manifest,export_intent,capabilities}=
    let val _=require(P.owns_input source(L.owner slice) andalso L.retained(L.owner slice)
        andalso L.encoding(L.owner slice)="UTF-8" andalso size(L.original slice)<=1000000)
        "Original descriptor source ownership/bounds"
      val _=require(forall positive[source_revision,manifest,export_intent] andalso
        length capabilities<=256 andalso length(distinct(op =)(map #id capabilities))=length capabilities
        andalso forall(fn(c:capability)=>size(#id c)>0 andalso size(#id c)<=256 andalso
          length(#contracts c)<=256 andalso forall locator_ok
            (#specification c :: #contracts c @ the_list(#executable c)))capabilities)
        "Original descriptor expectation bounds"
      val data={source=source,slice=slice,source_revision=source_revision,manifest=manifest,
        export_intent=export_intent,capabilities=capabilities,
        dependencies=[P.source_identity source]}:binding
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val lease=P.retain_source_owned scope source
      in Intent{identity=serial(),payload=Synchronized.var "original_export_intent"(SOME{binding=data,lease=lease})}end) end;
  fun retain_owned scope (original as Intent{identity,payload})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result payload(fn current=>
      let val data=case current of SOME{binding,lease}=>
            (ignore(L.lease_input lease);binding)|NONE=>error "Original export intent released"
        val lease=P.retain_source_owned scope (#source data)
      in(Intent{identity=identity,payload=Synchronized.var "retained_original_export_intent"
          (SOME{binding=data,lease=lease})},current)end));
  fun release(Intent{payload,...})=Synchronized.change payload(fn NONE=>NONE
    |SOME(data:payload)=>(Option.app I.release_disposed_input(L.release(#lease data));NONE));
end;
