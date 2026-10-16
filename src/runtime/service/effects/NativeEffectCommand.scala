package veri7vn.runtime.service.effects

import veri7vn.runtime.effects.AttemptIdentity

private[service] final case class NativeEffectCost(profile:BigInt,codeGeneration:BigInt,
    operation:BigInt,step:BigInt,units:BigInt) {
  require(Vector(profile,codeGeneration,operation,step,units).forall(n=>n>=0 && n.toString.length<=128),
    "native effect cost identity bound")
}

/** Inspection of a generated ClaimStart command. This is data, never a permit.
  * The resident gate must retain, journal and acknowledge its actual candidate
  * before consuming its separate single-use handoff capability.
  */
private[service] final case class NativeEffectCommand(attempt:BigInt,request:BigInt,
    target:BigInt,capability:BigInt,sources:Vector[BigInt],dependencies:Vector[BigInt],
    prestate:BigInt,epoch:BigInt,cost:NativeEffectCost) {
  private def natural(value:BigInt):Boolean=value>=0 && value.toString.length<=128
  require(Vector(attempt,request,target,capability,prestate,epoch).forall(natural),
    "native effect command identity bound")
  require(sources.size<=8192 && dependencies.size<=8192 &&
    sources.forall(natural) && dependencies.forall(natural),"native effect command input bound")

  /** Exact association includes ordered source/dependency lists and the original
    * prestate/epoch. Set membership would silently permit a different command. */
  def requireExact(expected:NativeEffectCommand):Unit=
    require(this==expected,"native ClaimStart differs from prepared operation")

  def identity(workspace:String,inputArtifact:String):AttemptIdentity=
    AttemptIdentity(workspace,attempt,request,capability,inputArtifact)
}
