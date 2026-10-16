package veri7vn.runtime.connectors

import scala.language.unsafeNulls
import veri7vn.runtime.effects.*
import veri7vn.sources.LocalSnapshot

/** Fixed local acquisition adapter, not an authority issuer. Installed registration
  * must bind this exact manifest, input artifact and code identity. The host alone
  * performs durable ClaimStart and consumes its permit before invoking handoff.
  * It captures inert source-row bytes; it does not contact a sensor or publish facts.
  */
final class LocalSensorExecutor private[runtime] (val expectedInput: String, val manifest: LocalSnapshot.Manifest,
    private val configuration:CapturedAcquisitionConfiguration, private val binding:LocalAcquisitionBinding,
    val maxBytes: Int = 65536) extends Executor {
  require(expectedInput.matches("[0-9a-f]{64}") && maxBytes>0 && maxBytes<=65536)
  require(manifest.acquisition.configuration==configuration.observationConfiguration &&
    manifest.schema==configuration.schema && manifest.recipe==configuration.mapping &&
    manifest.acquisition.qualityPolicy==configuration.quality,"acquisition manifest configuration mismatch")
  val protocol="local-sensor-acquire/1"
  private final case class Captured(identity:AttemptIdentity, candidate:LocalSnapshot.Candidate,
    receipt:ExecutorReceipt)
  private var captured:Option[Captured]=None
  private var completedReceipt:Option[ExecutorReceipt]=None
  private var heldInput:Option[InputLease]=None
  @volatile private var attempted:Option[AttemptIdentity]=None
  private val stopped=new java.util.concurrent.atomic.AtomicBoolean(false)

  def handoff(identity:AttemptIdentity,limits:WorkerLimits,input:InputLease):Unit=binding.withCurrent(configuration) {synchronized {
    binding.checkInput(input)
    require(!stopped.get() && attempted.isEmpty,"local sensor executor consumed or stopped")
    require(identity==input.identity && identity.inputArtifact==expectedInput,"local sensor input association")
    require(input.size<=maxBytes && limits.memoryBytes>=4L*maxBytes+131072L && limits.outputBytes>=64,
      "local sensor resource envelope")
    // Mark before reading: a thrown read/parse remains an attempted acquisition.
    attempted=Some(identity)
    heldInput=Some(input)
    val view=input.readOnly
    val bytes=new Array[Byte](view.remaining())
    try {
      view.get(bytes)
      require(LocalSnapshot.hash(bytes)==expectedInput,"local sensor artifact bytes changed")
      val candidate=LocalSnapshot.prepare(bytes,manifest,LocalSnapshot.Limits(maxBytes))
      val receipt=ExecutorReceipt(identity,protocol,candidate.id)
      if(stopped.get()) candidate.release()
      else {captured=Some(Captured(identity,candidate,receipt));completedReceipt=Some(receipt)}
    } finally java.util.Arrays.fill(bytes,0.toByte)
  }}
  def reconcile(identity:AttemptIdentity):Reconciled=synchronized {
    completedReceipt.filter(_.identity==identity).fold[Reconciled](Reconciled.Unknown)(Reconciled.Confirmed.apply)
  }
  /** Trusted fixed source consumer only. This is observed bytes, never accepted
    * source truth. Native metadata decoder + SAME acquisition ticket must follow.
    * No copy may escape the managed owner; the callback is not execution authority.
    */
  private[runtime] def withCaptured[A](identity:AttemptIdentity)(consume:LocalSnapshot.Candidate=>A):A=
      binding.withCurrent(configuration) {synchronized {
    require(!stopped.get(),"local sensor retired")
    val value=captured.filter(_.identity==identity).getOrElse(throw new IllegalStateException("no captured acquisition"))
    consume(value.candidate)
  }}
  def signalStop(identity:AttemptIdentity):Unit={
    if(attempted.contains(identity))stopped.set(true)
  }
  def stop(identity:AttemptIdentity):Unit={
    signalStop(identity)
    synchronized {if(attempted.contains(identity)) {captured.foreach(_.candidate.release());captured=None;heldInput=None}}
  }
  def awaitStopped(identity:AttemptIdentity):Unit=synchronized {
    // Acquisition is synchronous; entering this monitor joins the complete capture.
    require(!attempted.contains(identity) || (stopped.get() && captured.isEmpty),
      "local sensor stop must precede join")
  }
  binding.register(new WorkerLifetime {
    def invalidate():Unit=stopped.set(true)
    def awaitStopped():Unit={
      val input=LocalSensorExecutor.this.synchronized {
        captured.foreach(_.candidate.release());captured=None
        val owned=heldInput;heldInput=None;owned
      }
      // Close outside the executor monitor: managed source cleanup joins this
      // same executor, and lock ordering must not retain a worker lock across it.
      input.foreach(_.close())
    }
  })

}
