package veri7vn.runtime.connectors

import scala.language.unsafeNulls
import veri7vn.runtime.effects.{InputLease,WorkerLifetime}

/** Protected configuration identity, not a serializable authority token. It binds
  * the complete captured configuration occurrence instead of caching by address.
  * Credential numbers are references to protected host records, never values.
  * Neither endpoint nor credential-reference metadata is rendered or hashed into
  * the public observation configuration label. Native activation remains separate.
  */
final class CapturedAcquisitionConfiguration private[connectors] (
    private[connectors] val draft:String, private[connectors] val head:String,
    private[connectors] val configMember:String, private[connectors] val sourceBinding:BigInt,
    private[connectors] val epoch:BigInt, private[connectors] val endpoint:String,
    private[connectors] val schema:String, private[connectors] val mapping:String,
    private[connectors] val quality:String, private[connectors] val credentialOwner:BigInt,
    private[connectors] val credentialRevision:BigInt) {
  private[connectors] def sameConfiguration(other:CapturedAcquisitionConfiguration):Boolean =
    draft==other.draft && head==other.head && configMember==other.configMember &&
    sourceBinding==other.sourceBinding && epoch==other.epoch && endpoint==other.endpoint &&
    schema==other.schema && mapping==other.mapping && quality==other.quality &&
    credentialOwner==other.credentialOwner && credentialRevision==other.credentialRevision
  private[runtime] def observationConfiguration:String=s"binding-$sourceBinding-epoch-$epoch"
  override def toString:String="CapturedAcquisitionConfiguration(<protected>)"
}
object CapturedAcquisitionConfiguration {
  /** The fixed host installer captures these from managed source/configuration and
    * protected credential records. Construction grants no native execution rights. */
  private[runtime] def capture(draft:String,head:String,configMember:String,sourceBinding:BigInt,
      epoch:BigInt,endpoint:String,schema:String,mapping:String,quality:String,
      credentialOwner:BigInt,credentialRevision:BigInt):CapturedAcquisitionConfiguration={
    require(draft.nonEmpty && draft.length<=256 && head.matches("[0-9a-f]{64}") &&
      configMember.matches("[0-9a-f]{64}"),"acquisition configuration source identity")
    require(Vector(sourceBinding,epoch,credentialOwner,credentialRevision).forall(n=>n>=0 && n.bitLength<=256),
      "acquisition configuration numeric bound")
    require(Vector(endpoint,schema,mapping,quality).forall(s=>s.nonEmpty && s.length<=2048),
      "acquisition configuration field bound")
    new CapturedAcquisitionConfiguration(draft,head,configMember,sourceBinding,epoch,
      endpoint,schema,mapping,quality,credentialOwner,credentialRevision)
  }
}

/** Owns only this live acquisition occurrence and its local worker roots. It is not
  * a registry, scheduler, qualification engine or authority issuer. Retiring it does
  * not delete an independently retained managed historical source snapshot.
  */
final class LocalAcquisitionBinding private[runtime] (private val configuration:CapturedAcquisitionConfiguration) {
  private var live=true
  private var workers=Vector.empty[WorkerLifetime]
  private[connectors] def register(worker:WorkerLifetime):Unit=synchronized {
    require(live && workers.isEmpty,"acquisition occurrence unavailable or already owned")
    workers :+= worker
  }
  private[connectors] def withCurrent[A](expected:CapturedAcquisitionConfiguration)(action: => A):A=synchronized {
    require(live && configuration.sameConfiguration(expected),"acquisition configuration retired or changed")
    action
  }
  private[connectors] def checkInput(input:InputLease):Unit={
    require(input.sourceDraft==configuration.draft && input.sourceHead==configuration.head,
      "acquisition input configuration occurrence mismatch")
    // The source-binding ID must be a dependency of this managed input capture.
    // The fixed installer/native gate must check its association to configMember;
    // a caller-supplied numeric ID alone cannot authenticate configuration bytes.
    require(input.dependencies.contains(configuration.sourceBinding),"acquisition source binding dependency missing")
  }
  /** Invalidate under the owner monitor, then signal/join outside it. Callers may
    * retain old snapshot observations under their independent historical leases. */
  private[runtime] def retire():Unit={
    val owned=synchronized {live=false;workers}
    owned.foreach(_.invalidate())
    owned.foreach(_.awaitStopped())
    synchronized {workers=Vector.empty}
  }
  /** A replacement is data awaiting a separately qualified/approved registration.
    * This method never creates a new adapter, profile, source binding or permit. */
  private[runtime] def retireForReplacement(next:CapturedAcquisitionConfiguration):Unit={
    require(next.sourceBinding!=configuration.sourceBinding && next.epoch>configuration.epoch,
      "replacement requires a new source binding and epoch")
    retire()
  }
  override def toString:String="LocalAcquisitionBinding(<protected>)"
}
