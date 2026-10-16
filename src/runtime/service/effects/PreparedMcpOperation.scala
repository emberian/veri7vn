package veri7vn.runtime.service.effects

import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import scala.util.control.NonFatal
import veri7vn.runtime.connectors.mcp.{McpIngress,McpWorkflow,McpObservationRecord}
import veri7vn.runtime.effects.{OperationProfile,WorkerLimits,ExecutorReceipt}

/** Fixed local producer. Preparation captures an installed MCP executor and
  * packet association; it performs no external operation and grants no start.
  */
private[service] final class PreparedMcpOperation private (
    staged:McpIngress.StagedPacket,association:NativeMcpPacket) {
  private val sources=staged.sources
  private val installation=staged.installation
  private val packet=staged.packet
  private val draft=staged.descriptor.draft
  private val head=staged.descriptor.head
  association.claim(staged)
  private val executor=installation.withCurrent {installation.session.executor(packet,draft,head)}

  /** The parent calls this only for its actual native registered operation,
    * checking the retained executable/profile pins. IDs are not permission.
    * Only the separately consumed acknowledged permit can initiate handoff. */
  private[service] def bindNativeRegistration(workspace:String,command:NativeEffectCommand,
      association:NativeMcpRegistration):Bound={
    val registration=association.claim(PreparedMcpOperation.this.association,command)
    require(registration.operation==packet.operation.toString &&
      registration.capability==command.capability && registration.profile==command.cost.profile,"MCP native operation registration mismatch")
    require(packet.configurationLabel==installation.configurationLabel,"MCP prepared configuration mismatch")
    val profile=installation.withCurrent {
      OperationProfile.installApproved(registration,executor,1,WorkerLimits(5000,1048576,65536),16384)
    }
    require(command.cost==NativeEffectCost(profile.identity.costProfile,profile.identity.codeGeneration,
      profile.identity.nativeOperation,profile.identity.step,profile.cost),
      "MCP actual ClaimStart cost differs from installed profile")
    new Bound(workspace,command,profile)
  }

  final class Bound private[PreparedMcpOperation](workspace:String,
      expected:NativeEffectCommand,profile:OperationProfile) {
    private val identity=expected.identity(workspace,packet.inputArtifact)
    private var handedOff=false
    private var consumedStart:Option[NativeEffectPermits.ConsumedStart]=None
    private var response:Option[PreparedMcpOperation.ObservationCandidate]=None
    /** Called synchronously under the parent's all-event coordinator and source
      * guard after durable unknown-start installation and native acknowledgement.
      * Consuming a permit is irreversible even if capture or handoff throws:
      * the durable outcome remains unknown and must never authorize replay. */
    def handoff(view:NativeEffectPermits.View)(permit:view.Permit):Unit={
      val consumed=view.consume(permit,association.supervisor)
      consumed.command.requireExact(expected)
      synchronized {require(!handedOff,"MCP prepared operation already consumed");handedOff=true;consumedStart=Some(consumed)}
      installation.withCurrent {
        val started=OperationProfile.withAuthorizedInput(sources,draft,head,packet.inputArtifact,
          identity,expected.dependencies,profile) {input=>profile.handoff(identity,input)}
        require(started.nonEmpty,"MCP packet source unavailable")
      }
    }
    private def checked(receipt:ExecutorReceipt):Unit=
      require(receipt.identity==identity && receipt.protocol==profile.protocol,"MCP completion association mismatch")
    /** One typed result prevents a transient/capture failure from terminalizing
      * an otherwise deliverable response. Reuse the same candidate on retries. */
    def completion():PreparedMcpOperation.Completion={
      import PreparedMcpOperation.*
      executor.completionSnapshot(identity) match {
        case McpWorkflow.Completion.Unknown=>Completion.Unknown
        case McpWorkflow.Completion.StatusOnly(receipt,reason,status)=>
          checked(receipt);Completion.StatusOnly(receipt,reason,status)
        case McpWorkflow.Completion.ResponseReady(receipt,observed)=>
          checked(receipt)
          require(observed.attempt==identity && observed.receiptArtifact==receipt.receiptArtifact,
            "MCP observed response differs from receipt")
          try {
            val candidate=synchronized {response.getOrElse {
              val source=installation.withCurrent {McpObservationRecord.capture(staged,observed)}
              val value=new ObservationCandidate(expected,consumedStart.getOrElse(
                throw new IllegalStateException("MCP response without actual consumed start")),
                receipt,observed.status,staged,association,source)
              response=Some(value);value
            }}
            Completion.ResponseReady(candidate)
          } catch {case NonFatal(_)=>Completion.Undelivered("response source materialization unavailable")}
      }
    }
    def completionSnapshot():PreparedMcpOperation.Completion=completion()
    private[service] def holdCompletionForTest(constructed:CountDownLatch,release:CountDownLatch):Unit={
      synchronized {require(!handedOff,"completion test gate installed after handoff")}
      executor.holdCompletion(constructed,release)
    }
    private[service] def awaitCompletionForTest(timeoutMillis:Long):Boolean=
      executor.awaitCompletionForTest(timeoutMillis)
    /** Explicit read-only lookup, never another handoff. Actual result remains
      * typed; a valid response must use staged source delivery rather than the
      * status-only Reconcile shortcut. */
    def reconcile():PreparedMcpOperation.Completion={
      profile.reconcile(identity) match {
        case Left(_)=>PreparedMcpOperation.Completion.Undelivered("receipt validation failed")
        case Right(_)=>completion()
      }
    }
    /** Cleanup belongs outside the coordinator/source monitor because it joins. */
    def stop():Unit=profile.stop(identity)
  }
}
private[service] object PreparedMcpOperation {
  enum Completion {
    case Unknown
    case ResponseReady(candidate:ObservationCandidate)
    case StatusOnly(receipt:ExecutorReceipt,reason:String,status:McpWorkflow.ResponseStatus)
    case Undelivered(reason:String)
  }
  final class ObservationCandidate private[PreparedMcpOperation](
      val command:NativeEffectCommand,val consumedStart:NativeEffectPermits.ConsumedStart,
      val receipt:ExecutorReceipt,val status:McpWorkflow.ResponseStatus,
      val staged:McpIngress.StagedPacket,val packet:NativeMcpPacket,private val source:McpObservationRecord.Candidate) {
    val identity:String=source.identity
    val configuration:NativeMcpConfiguration=staged.installation.nativeConfiguration
    def withBytes[A](consume:ByteBuffer=>A):A=source.withBytes(consume)
    def withWitness[A](consume:ByteBuffer=>A):A=source.withWitness(consume)
  }
  def prepare(staged:McpIngress.StagedPacket,association:NativeMcpPacket):PreparedMcpOperation={
    new PreparedMcpOperation(staged,association)
  }
}
