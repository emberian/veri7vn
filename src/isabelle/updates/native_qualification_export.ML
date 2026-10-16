(* Fixed role exporters consume actual leased native owners. Their output is
   inert store material, never a committed capability or generated event. *)
structure Veri7vn_Qualification_Export_Types =
struct
  structure T=Veri7vn_Qualification_Recovery_Types;
  datatype category=QualificationEvidence | QualificationRequestChild;
  type artifacts={workspace:string,association:IntInf.int,semantic_generation:IntInf.int,
    category:category,manifest:string,projection:string,sequent:string,context_closure:string,reconstruction:string};
  type intent_projection={source_owner:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    export_intent:IntInf.int,dependencies:IntInf.int list};
  type initial_projection={context:T.initial_context,names:T.names,candidate:T.candidate_pin,
    intent:intent_projection,dependencies:IntInf.int list,profile:string};
  type update_projection={context:T.update_context,names:T.names,candidate:T.candidate_pin,
    baseline:T.candidate_pin,dependencies:IntInf.int list,profile:string};
end;

signature VERI7VN_QUALIFICATION_EXPORT_OWNER =
sig
  type value
  type lease
  val value:lease -> value
  (* From the actual native association/source owner, never decoded user metadata. *)
  val workspace:lease -> string
  val is_live:lease -> bool
  val retain:lease -> lease
  val release:lease -> unit
end;

signature VERI7VN_QUALIFICATION_ROLE_EXPORT =
sig
  type lease
  type exported
  val export:Veri7vn_Native_Recovery_Check.image -> lease -> exported
  val artifacts:exported -> Veri7vn_Qualification_Export_Types.artifacts
  val is_live:exported -> bool
  val retain:exported -> exported
  val release:exported -> unit
end;

structure Veri7vn_Qualification_Export_Common =
struct
  structure X=Veri7vn_Qualification_Export_Types;
  structure C=Veri7vn_Qualification_Material_Check;
  structure M=Veri7vn_Recovery_Manifest;
  fun make image executable role category marker workspace association semantic projection:X.artifacts=
    let
      val _=C.require(size workspace=32 andalso forall(fn c=>Char.isDigit c orelse
        (#"a"<=c andalso c<= #"f"))(String.explode workspace)) "Qualification export workspace"
      val _=C.require(association>0 andalso semantic>0 andalso size(IntInf.toString association)<=128 andalso
        size(IntInf.toString semantic)<=128 andalso size projection<=1048576) "Qualification export identity/projection bounds"
      val closure=C.closure image executable
      val _=C.require(size closure<=16777216 andalso size marker<=100000) "Qualification export closure bounds"
      val manifest=M.encode{profile=role,workspace=workspace,association=association,semantic_generation=semantic,
        projection=C.digest projection,sequent=C.digest "",context_closure=C.digest closure,payload=C.digest marker,
        reconstruction=M.Controlled_Recipe,executable=SOME(Veri7vn_Native_Recovery_Pin.digest executable)}
      val _=C.require(size manifest<=8192) "Qualification export manifest bound"
    in {workspace=workspace,association=association,semantic_generation=semantic,category=category,
      manifest=manifest,projection=projection,sequent="",context_closure=closure,reconstruction=marker} end;
  fun snapshots workspace consequences=
    map(fn consequence=>
      let val _=C.require(Veri7vn_Managed_Provenance.is_live consequence andalso
          Veri7vn_Managed_Provenance.workspace consequence=workspace) "Qualification export subject workspace/liveness"
        val accepted=Veri7vn_Managed_Provenance.accepted consequence
        val name=case Veri7vn_Managed_Provenance.public_name consequence of SOME name=>name
          | NONE=>error "Qualification export has no canonical native name"
      in (name,Veri7vn_Native_Sequent.capture(Veri7vn_Native_Admission.target accepted)
        (Veri7vn_Native_Admission.theorem accepted)) end)consequences;
end;

(* Static image abstraction only. Fixed instantiations below choose all roles and
   projections; the service never accepts a callback/codec from a request. *)
functor Veri7vn_Qualification_Export_Root
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val project:Veri7vn_Native_Recovery_Check.image -> string -> Owner.value ->
     Veri7vn_Qualification_Export_Types.artifacts) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  type lease=Owner.lease;
  type payload={owner:lease,artifacts:Veri7vn_Qualification_Export_Types.artifacts};
  structure Root=Veri7vn_Checked_Qualification_Root(type payload=payload
    val live=fn({owner,...}:payload)=>Owner.is_live owner
    val dispose=fn({owner,...}:payload)=>Owner.release owner);
  type exported=Root.checked;
  fun export image owner=
    let val _=Veri7vn_Qualification_Material_Check.require(Owner.is_live owner) "Qualification export owner unavailable"
      val retained=Owner.retain owner
      fun produce()=Root.create{owner=retained,artifacts=project image (Owner.workspace retained)(Owner.value retained)}
    in case Exn.capture produce() of Exn.Res exported=>exported
      | Exn.Exn exn=>(Owner.release retained;Exn.reraise exn) end;
  fun artifacts exported= #artifacts(Root.read exported);
  val is_live=Root.is_live;
  val retain=Root.retain;
  val release=Root.release;
end;

functor Veri7vn_Export_Initial_Qualification
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val result:Owner.value -> Veri7vn_Qualification_Export_Types.initial_projection * int
   val exports:Owner.value -> Veri7vn_Managed_Provenance.consequence list
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  structure X=Veri7vn_Qualification_Export_Types;
  structure W=Veri7vn_Qualification_Codec;
  structure C=Veri7vn_Qualification_Export_Common;
  structure Export=Veri7vn_Qualification_Export_Root(structure Owner=Owner
    fun project image workspace qualified=
      let val (p,count)=result qualified
        val bytes=W.encode_initial{context= #context p,names= #names p,candidate= #candidate p,
          profile= #profile p,count=count,dependencies= #dependencies p,exports=C.snapshots workspace(exports qualified)}
        val _=Veri7vn_Qualification_Material_Check.require(result qualified=(p,count)) "Initial export changed during capture"
      in C.make image executable Veri7vn_Recovery_Manifest.InitialQualification X.QualificationEvidence
        "initial-qualification/2" workspace (#evidence(#names p)) (#semantic_generation(#names p)) bytes end);
  open Export;
end;

functor Veri7vn_Export_Update_Qualification
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val result:Owner.value -> Veri7vn_Qualification_Export_Types.update_projection * int
   val expected_exports:Owner.value -> Veri7vn_Qualification_Recovery_Types.sequents
   val exports:Owner.value -> Veri7vn_Managed_Provenance.consequence list
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  structure X=Veri7vn_Qualification_Export_Types;
  structure W=Veri7vn_Qualification_Codec;
  structure C=Veri7vn_Qualification_Export_Common;
  structure Export=Veri7vn_Qualification_Export_Root(structure Owner=Owner
    fun project image workspace qualified=
      let val (p,count)=result qualified
        val bytes=W.encode_update{context= #context p,names= #names p,candidate= #candidate p,baseline= #baseline p,
          profile= #profile p,count=count,dependencies= #dependencies p,expected_exports=expected_exports qualified,
          exports=C.snapshots workspace(exports qualified)}
        val _=Veri7vn_Qualification_Material_Check.require(result qualified=(p,count)) "Update export changed during capture"
      in C.make image executable Veri7vn_Recovery_Manifest.UpdateQualification X.QualificationEvidence
        "update-qualification/2" workspace (#evidence(#names p)) (#semantic_generation(#names p)) bytes end);
  open Export;
end;

functor Veri7vn_Export_Initial_Qualification_Request
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val snapshot:Owner.value -> Veri7vn_Pending_Qualification_Types.initial
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  structure Export=Veri7vn_Qualification_Export_Root(structure Owner=Owner
    fun project image workspace pending=
      let val p=snapshot pending
      in Veri7vn_Qualification_Export_Common.make image executable Veri7vn_Recovery_Manifest.InitialQualificationRequest
        Veri7vn_Qualification_Export_Types.QualificationRequestChild "initial-qualification-request/2"
        workspace (#request_slot p) (#semantic_generation(#names p))
        (Veri7vn_Pending_Qualification_Codec.encode_initial p) end);
  open Export;
end;

functor Veri7vn_Export_Update_Qualification_Request
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val snapshot:Owner.value -> Veri7vn_Pending_Qualification_Types.update
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  structure Export=Veri7vn_Qualification_Export_Root(structure Owner=Owner
    fun project image workspace pending=
      let val p=snapshot pending
      in Veri7vn_Qualification_Export_Common.make image executable Veri7vn_Recovery_Manifest.UpdateQualificationRequest
        Veri7vn_Qualification_Export_Types.QualificationRequestChild "update-qualification-request/1"
        workspace (#request_slot p) (#semantic_generation(#names p))
        (Veri7vn_Pending_Qualification_Codec.encode_update p) end);
  open Export;
end;

functor Veri7vn_Export_Initial_Qualification_Template
  (structure Owner:VERI7VN_QUALIFICATION_EXPORT_OWNER
   val snapshot:Owner.value -> Veri7vn_Initial_Qualification_Template_Types.snapshot
   val executable:Veri7vn_Executable_Identity.pin) :>
  VERI7VN_QUALIFICATION_ROLE_EXPORT where type lease=Owner.lease =
struct
  structure Export=Veri7vn_Qualification_Export_Root(structure Owner=Owner
    fun project image workspace template=
      let val p=snapshot template
      in Veri7vn_Qualification_Export_Common.make image executable Veri7vn_Recovery_Manifest.InitialQualificationRequest
        Veri7vn_Qualification_Export_Types.QualificationRequestChild "initial-qualification-request/2"
        workspace (#request_slot(#context p)) (#semantic_generation(#names p))
        (Veri7vn_Initial_Template_Codec.encode p) end);
  open Export;
end;
