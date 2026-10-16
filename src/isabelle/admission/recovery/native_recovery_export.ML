(* Loaded after the actual generated evidence descriptor. Export qualification
   reconstructs the native object before any durable commit is requested. *)
signature VERI7VN_NATIVE_RECOVERY_EXPORT =
sig
  type material = {association:IntInf.int,semantic_generation:IntInf.int,
    manifest:string,projection:string,sequent:string,context_closure:string,reconstruction:string,dependencies:IntInf.int list}
  val export: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Check.image -> Veri7vn_Native_Authority_Descriptor.descriptor -> material
end;
structure Veri7vn_Native_Recovery_Export :> VERI7VN_NATIVE_RECOVERY_EXPORT =
struct
  structure D=Veri7vn_Native_Authority_Descriptor;
  structure N=Veri7vn_Native_Descriptor;
  structure V=Veri7vn_Native_Recovery_Check;
  structure A=Veri7vn_Native_Admission;
  type material = {association:IntInf.int,semantic_generation:IntInf.int,
    manifest:string,projection:string,sequent:string,context_closure:string,reconstruction:string,dependencies:IntInf.int list};
  fun export allocator image descriptor =
    let val native=D.native descriptor
      val p=N.project native
      val th=A.theorem (N.accepted native)
      val assumption_count=length (Thm.hyps_of th @ Thm.prems_of th)
      val (assumption_ids,sort_ids)=chop assumption_count (#premises p)
      val consequence=case N.producer native of SOME c=>c
        | NONE=>error "Native recovery requires controlled producer provenance"
      val association=D.evidence_id descriptor
      val artifacts=V.qualify allocator image consequence
        {workspace=N.workspace native,evidence_id=association,projection=p,
         assumption_ids=assumption_ids,sort_ids=sort_ids}
      fun digest bytes=Message_Digest.rep (SHA256.digest bytes)
      val manifest=Veri7vn_Recovery_Manifest.encode
        {profile=Veri7vn_Recovery_Manifest.KernelEvidence,workspace=N.workspace native,association=association,semantic_generation= #semantic_generation p,
         projection=digest (#projection artifacts),sequent=digest (#sequent artifacts),
         context_closure=digest (#context_closure artifacts),payload=digest (#reconstruction artifacts),
         reconstruction=(if Veri7vn_Native_Recovery_Replay.has_replay
           (Veri7vn_Managed_Provenance.consequence_development consequence)
           then Veri7vn_Recovery_Manifest.Controlled_Recipe
           else case Veri7vn_Managed_Provenance.public_name consequence of
           SOME _=>Veri7vn_Recovery_Manifest.Fixed_Certificate
         | NONE=>Veri7vn_Recovery_Manifest.Controlled_Recipe),executable=NONE}
    in {association=association,semantic_generation= #semantic_generation p,manifest=manifest,
      projection= #projection artifacts,sequent= #sequent artifacts,
      context_closure= #context_closure artifacts,reconstruction= #reconstruction artifacts,
      dependencies=distinct(op =)(association::N.native_object_dependencies native)} end;
end;
