package veri7vn.runtime.effects

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import veri7vn.runtime.host.ManagedSources

/** Describes an installed registration, never proof authority or a serialized callback.
  * Recovery must locate the exact approved installed implementation and compare all
  * fields before the service reinstalls a profile. A digest alone is insufficient.
  */
final case class OperationIdentity(profile: BigInt, capability: BigInt,
    codeGeneration: BigInt, implementationArtifact: String, operation: String,
    nativeOperation:BigInt,costProfile: BigInt, step: BigInt) {
  require(profile>0 && capability>0 && codeGeneration>0 && nativeOperation>0 && costProfile>0 && step>=0)
  require(Vector(profile,capability,codeGeneration,nativeOperation,costProfile,step).forall(_.toString.length<=128),"operation identity bound")
  require(implementationArtifact.matches("[0-9a-f]{64}"))
  require(operation.nonEmpty && operation.length<=256)
}

/** A tracked worker payload root. Existing read-only views observe zeroes after
  * close; this class does not hand out the backing array. Any executor-created
  * copies are explicit worker-owned derivatives that its termination must release.
  */
final class InputLease private[effects] (attempt: AttemptIdentity,
    draft: String, head: String, inputMember: String,
    inputDependencies: Vector[BigInt], private val resources:WorkerResources,
    initial:WorkerResources#OwnedBytes) extends AutoCloseable {
  private final case class Payload(identity:AttemptIdentity,sourceDraft:String,
      sourceHead:String,member:String,dependencies:Vector[BigInt],bytes:WorkerResources#OwnedBytes)
  private val payload=resources.reserveRoot[Payload](0)
  payload.install(Payload(attempt,draft,head,inputMember,inputDependencies,initial))
  private def current:Payload={
    require(resources.isLive,"input lease source released")
    payload.withLiveValue(value=>value)
  }
  def identity:AttemptIdentity=synchronized {current.identity}
  def sourceDraft:String=synchronized {current.sourceDraft}
  def sourceHead:String=synchronized {current.sourceHead}
  def member:String=synchronized {current.member}
  def dependencies:Vector[BigInt]=synchronized {current.dependencies}
  def readOnly:ByteBuffer=synchronized {current.bytes.readOnly}
  def size:Int=if(!resources.isLive)0 else synchronized {payload.withLiveValue(_.bytes.size)}
  private[effects] def attach(profile:OperationProfile,executor:Executor):Unit={
    val actual=identity
    resources.attachWorker(new WorkerLifetime {
      def invalidate():Unit=executor.signalStop(actual)
      def awaitStopped():Unit={
        executor.stop(actual);executor.awaitStopped(actual)
        profile.resourceStopped(actual,InputLease.this)
      }
    })
  }
  def close():Unit=resources.close()
}

/** Only the authenticated host registration seam may construct an installed profile.
  * It must associate the actual executor implementation with the approved executable
  * generation and exact operation contract before calling installApproved.
  * This object cannot produce a native grant, event token or dispatch permit.
  */
final class OperationProfile private[effects] (val identity: OperationIdentity,
    val protocol: String, val cost: BigInt, val limits: WorkerLimits,
    val maxInputBytes: Int, private val executor: Executor) {
  private var active=Map.empty[AttemptIdentity,InputLease]
  private[effects] def resourceStopped(attempt:AttemptIdentity,input:InputLease):Unit=synchronized {
    if(active.get(attempt).exists(_ eq input))active-=attempt
  }
  private[runtime] def handoff(attempt: AttemptIdentity, input: InputLease): Unit = {
    require(attempt==input.identity && attempt.capability==identity.capability,"profile input/attempt mismatch")
    require(input.size<=maxInputBytes && executor.protocol==protocol,"installed executor changed")
    synchronized {require(!active.contains(attempt),"attempt worker already owned");active+=attempt->input}
    var attached=false
    try {input.attach(this,executor);attached=true;executor.handoff(attempt,limits,input)}
    catch {case failure:Throwable=>
      if(!attached)resourceStopped(attempt,input)
      // The source factory closes this registered lease after leaving its lock.
      throw failure
    }
  }
  private[runtime] def reconcile(attempt: AttemptIdentity): Either[String,Reconciled] =
    Executor.validateReconciliation(attempt,protocol,executor.reconcile(attempt))
  private[runtime] def stop(attempt: AttemptIdentity): Unit =
    synchronized(active.get(attempt)).foreach(_.close())
}
object OperationProfile {
  private[runtime] def installApproved(identity: OperationIdentity, executor: Executor,
      cost: BigInt, limits: WorkerLimits, maxInputBytes: Int): OperationProfile = {
    require(cost>0 && cost.toString.length<=128 && maxInputBytes>0 && maxInputBytes.toLong<=limits.memoryBytes,"operation allocation bounds")
    val protocol=executor.protocol
    require(protocol.nonEmpty && protocol.length<=256,"executor protocol bound")
    new OperationProfile(identity,protocol,cost,limits,maxInputBytes,executor)
  }

  /** Call only inside the coordinator's generated-authority dispatch critical section.
    * Managed membership authorizes bytes access only; it does not authorize execution.
    * Callback runs while current source access is locked. Handoff must occur here;
    * returning an unlaunched lease for a later unchecked queue violates the contract.
    * Successful handoff transfers the lease to the host's tracked worker ownership.
    */
  private[runtime] def withAuthorizedInput[A](sources: ManagedSources, draft: String,
      expectedHead: String, member: String, attempt: AttemptIdentity,
      dependencies: Vector[BigInt], profile: OperationProfile)(handoff: InputLease => A): Option[A] = {
    require(dependencies.size<=8192 && dependencies.forall(_>=0),"input dependency bound")
    require(attempt.capability==profile.identity.capability && attempt.inputArtifact==member,"input association mismatch")
    val budget=ResourceBudget(attempt.request,profile.maxInputBytes.toLong,1,1,1,0,128,1,1)
    WorkerResources.withCurrentCapture(sources,draft,expectedHead,budget) {capture=>
      val bytes=capture.read(member,profile.maxInputBytes)
      val input=new InputLease(attempt,draft,expectedHead,member,dependencies,capture.resources,bytes)
      handoff(input)
    }
  }
}
