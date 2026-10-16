package veri7vn.runtime.effects

/** Native authority has already checked capability, target, dependencies and budget.
  * This immutable association identifies the exact durable attempt and input bytes;
  * it conveys no permission when constructed outside the service-owned dispatch seam.
  */
final case class AttemptIdentity(workspace: String, attempt: BigInt,
    request: BigInt, capability: BigInt, inputArtifact: String) {
  require(workspace.nonEmpty && attempt >= 0 && request >= 0 && capability >= 0 && inputArtifact.nonEmpty)
}
final case class WorkerLimits(wallMillis: Long, memoryBytes: Long, outputBytes: Int) {
  require(wallMillis > 0 && memoryBytes > 0 && outputBytes > 0)
}
final case class ExecutorReceipt(identity: AttemptIdentity, protocol: String,
    receiptArtifact: String) {
  require(protocol.nonEmpty && receiptArtifact.nonEmpty)
}
sealed trait Reconciled
object Reconciled {
  final case class Confirmed(receipt: ExecutorReceipt) extends Reconciled
  final case class Failed(receipt: ExecutorReceipt) extends Reconciled
  case object Unknown extends Reconciled
}
/** Called synchronously under the coordinator's all-event monitor AFTER the durable
  * unknown-start record and single-use native permit consumption. Returning signifies
  * immediate executor handoff, not future permission to launch from an unchecked queue.
  * Throwing leaves Unknown: neither exception nor missing receipt proves no effect.
  * Implementations must bind exact inputArtifact and enforce actual worker limits.
  */
trait Executor {
  def protocol: String
  def handoff(identity: AttemptIdentity, limits: WorkerLimits, input: InputLease): Unit
  /** Read/reconcile only; must never perform a blind repeat of handoff. Returned
    * receipt identity must equal the supplied identity at the coordinator seam.
    */
  def reconcile(identity: AttemptIdentity): Reconciled
  /** Nonblocking local cancellation signal, callable under the source lifecycle lock. */
  def signalStop(identity: AttemptIdentity): Unit
  /** Best effort termination cannot certify that an external effect did not happen. */
  def stop(identity: AttemptIdentity): Unit
  /** Normal return means owned local workers/children have actually terminated.
    * It never proves an external effect failed or licenses retry. */
  def awaitStopped(identity: AttemptIdentity): Unit
}

/** Receipt transport validation only. It never authorizes launch or publication;
  * a valid result is still submitted to the generated Reconcile transition.
  */
object Executor {
  def validateReconciliation(expected: AttemptIdentity, registeredProtocol: String,
      result: Reconciled): Either[String, Reconciled] = {
    val receipt = result match {
      case Reconciled.Confirmed(value) => Some(value)
      case Reconciled.Failed(value) => Some(value)
      case Reconciled.Unknown => None
    }
    receipt match {
      case Some(value) if value.identity != expected => Left("executor receipt attempt/input mismatch")
      case Some(value) if value.protocol != registeredProtocol => Left("executor receipt protocol mismatch")
      case _ => Right(result)
    }
  }
}
