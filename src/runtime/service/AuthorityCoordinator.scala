package veri7vn.runtime.service

import scala.language.unsafeNulls
import veri7vn.runtime.host.WorkspaceStore

object AuthorityCoordinator {
  final case class Limits(maxEventBytes: Int = 1024*1024, maxCheckpointBytes: Int = 1024*1024) {
    require(maxEventBytes>0 && maxCheckpointBytes>=maxEventBytes)
  }
  sealed trait Origin
  private[service] final case class AuthenticatedPolicy(principal: String) extends Origin
  private[service] final case class NativeAdmission(gate: String) extends Origin
  /** Constructor is service-owned; external messages cannot mint privileged core events. */
  final class EventToken private[service](private[service] val nativeId: String, val origin: Origin)
  final class Prepared private[service](val id: String, val expectedSequence: Long,
    val nativeRevision: Long, val epoch: Long, event: Array[Byte], checkpoint: Array[Byte],
    private[service] val recovery: Option[WorkspaceStore.NativeRecoveryMaterial] = None,
    private[service] val dispatch:Option[WorkspaceStore.NativeDispatchMaterial]=None,
    private[service] val invalidations:Option[WorkspaceStore.NativeInvalidations]=None,
    private[service] val sourceGuard:Option[WorkspaceStore.NativeSourceGuard]=None,
    private[service] val sourceBinding:Option[WorkspaceStore.NativeBuildSourceMaterial]=None) {
    require(event.length<=1024*1024 && checkpoint.length<=1024*1024,"native prepared materialization bound")
    private[service] val eventBytes=event.clone()
    private[service] val checkpointBytes=checkpoint.clone()
    private[service] def release():Unit={recovery.foreach(_.release());java.util.Arrays.fill(eventBytes,0.toByte);java.util.Arrays.fill(checkpointBytes,0.toByte)}
  }
  sealed trait Outcome
  final case class Committed(sequence: Long, eventId: String) extends Outcome
  final case class Rejected(reason: String) extends Outcome
  final case class Unavailable(reason: String) extends Outcome
  /** Trusted native adapter. It calls generated code; implementations must not copy its policy.
    * checkpointBytes are the predicted post-ack full metadata image, not a delta or proof.
    */
  trait NativeBridge {
    private[service] def invalidate(): Unit = ()
    private[service] def maintenance():Unit=()
    private[service] def initialize(): Option[Prepared] = None
    private[service] def prepare(token: EventToken): Either[String,Prepared]
    private[service] def validatePrecommit(prepared: Prepared): Boolean
    private[service] def acknowledge(prepared: Prepared): Boolean
    private[service] def recover(record: WorkspaceStore.NativeRecord): Boolean
  }
  object MissingNativeBridge extends NativeBridge {
    private[service] def prepare(token: EventToken)=Left("native authority/association bridge unavailable")
    private[service] def validatePrecommit(p: Prepared)=false
    private[service] def acknowledge(p: Prepared)=false
    private[service] def recover(record: WorkspaceStore.NativeRecord)=false
  }
}

/** Every native event, including blockers, outcomes and lifecycle, uses this one monitor.
  * Holding it only around the DB call is insufficient: stage->precommit->commit->ack
  * excludes all intervening authority events. The bridge must not expose another writer.
  */
final class AuthorityCoordinator(store: WorkspaceStore, bridge: AuthorityCoordinator.NativeBridge,
  limits: AuthorityCoordinator.Limits = AuthorityCoordinator.Limits()) extends AutoCloseable {
  import AuthorityCoordinator.*
  store.claimAuthorityCoordinator()
  private var closed=false
  private var ready=false
  private[service] def requireReady():Unit=synchronized {require(ready && !closed,"native authority not ready")}
  def restore(): Outcome = synchronized {
    require(!ready,"restore is startup-exclusive")
    guarded {
    require(!closed,"authority coordinator closed")
    ready=false
    store.latestNative match {
      case None => Unavailable("initial native image must be installed through native initialization gate")
      case Some(record) if bridge.recover(record) => ready=true; Committed(record.sequence,record.id)
      case _ => bridge.invalidate(); Unavailable("retained native context/payload/association could not be reconstructed")
    }
  }}
  private def guarded(action: => Outcome): Outcome =
    try {require(!closed,"authority coordinator closed"); action} catch {case failure: Throwable =>
      ready=false
      try bridge.invalidate() catch {case cleanup:Throwable=>failure.addSuppressed(cleanup)}
      throw failure}
  private def persist(p: Prepared): Outcome = try {
    def commit():Outcome={
    require(p.eventBytes.length<=limits.maxEventBytes && p.checkpointBytes.length<=limits.maxCheckpointBytes,"native materialization limit")
    if(!bridge.validatePrecommit(p)) return Rejected("native staged transition no longer valid")
    store.commitNative(p.id,p.expectedSequence,p.nativeRevision,p.epoch,p.eventBytes,p.checkpointBytes,p.recovery,p.dispatch,p.invalidations,p.sourceBinding) match {
      case None => ready=false; Unavailable("durable sequence conflict; restore required")
      case Some(record) =>
        if(!bridge.acknowledge(p)) {ready=false; Unavailable("committed; native acknowledgement unavailable; restore required")}
        else {ready=true; Committed(record.sequence,record.id)}
    }
    }
    // Lock order: coordinator -> store/source monitor -> bounded native
    // validate/ack. Resolve native build bindings and transfer/parser work before
    // entering persist; acknowledgement may fork work but must not call Scala
    // source/store callbacks or perform replay synchronously.
    val outcome=p.sourceGuard match {
      case Some(guard)=>store.withNativeSourceGuard(guard)(commit())
      case None=>commit()
    }
    // Teardown can join native work and must run after releasing the source lock.
    if(outcome.isInstanceOf[Unavailable])bridge.invalidate()
    outcome
  } finally p.release()
  private[service] def initialize(): Outcome = synchronized { guarded {
    ready=false
    if(store.latestNative.nonEmpty) Unavailable("native journal already initialized; restore required")
    else bridge.initialize() match {
      case Some(p) => persist(p)
      case None => Unavailable("native initialization gate unavailable")
    }
  }}
  private[service] def submit(token: EventToken): Outcome = synchronized {
    if(!ready) return Unavailable("native authority not restored")
    guarded {bridge.prepare(token) match {
      case Left(reason)=>Rejected(reason)
      case Right(p)=>persist(p)
    }}
  }
  /** Teardown/file cleanup must not retain the all-event coordinator monitor. */
  private[service] def maintenance():Unit=bridge.maintenance()
  def close(): Unit = synchronized {
    if(!closed) {ready=false; closed=true; store.releaseAuthorityCoordinator()}
  }

}
