package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.CountDownLatch
import veri7vn.runtime.effects.*
import veri7vn.sources.LocalSnapshot

/** Fixed leaf; generated durable ClaimStart/ack and one-use parent handoff precede
  * this call. The sole completion publication is atomic, including actual response. */
final class McpExecutor private[mcp] (private val session:McpConnectorSession,
    val prepared:McpWorkflow.Prepared,private val inputDraft:String,private val inputHead:String) extends Executor {
  import McpWorkflow.*
  val protocol="local-mcp/1"
  private case class State(live:Boolean,completion:Completion)
  private val state=new AtomicReference(State(true,Completion.Unknown))
  @volatile private var attempt:Option[AttemptIdentity]=None
  @volatile private var worker:Option[Thread]=None
  private var input:Option[InputLease]=None
  private val completionPublished=new CountDownLatch(1)
  private[runtime] def awaitCompletionForTest(timeoutMillis:Long):Boolean=
    completionPublished.await(timeoutMillis,java.util.concurrent.TimeUnit.MILLISECONDS)
  @volatile private var completionGate:Option[(CountDownLatch,CountDownLatch)]=None
  private[runtime] def holdCompletion(constructed:CountDownLatch,release:CountDownLatch):Unit={
    require(attempt.isEmpty,"MCP completion test gate installed after handoff")
    completionGate=Some((constructed,release))
  }
  private def key(identity:AttemptIdentity):String=
    s"${identity.workspace.length}:${identity.workspace}:${identity.attempt}:${identity.request}:${identity.capability}:${identity.inputArtifact}"
  private def current:Boolean=try {session.current {true}} catch {
    case _:IllegalArgumentException=>false;case _:IllegalStateException=>false
  }
  private def terminal(value:Completion):Completion=value match {
    case Completion.ResponseReady(receipt,observation)=>Completion.StatusOnly(receipt,"cancelled-or-retired",observation.status)
    case other=>other
  }
  private def record(identity:AttemptIdentity,response:Map[String,Any],schema:Option[String],failed:Boolean=false):Unit={
    val bytes=McpWire.encode(response)
    val artifact=try LocalSnapshot.hash(bytes) finally java.util.Arrays.fill(bytes,0.toByte)
    val receipt=ExecutorReceipt(identity,protocol,artifact)
    val observation=Observation(prepared.operation,identity,schema,response,artifact,
      if(failed)ResponseStatus.RejectedResponse else ResponseStatus.ConfirmedResponse)
    // Test gate is after full construction and before the ONE atomic publication.
    completionGate.foreach {case (constructed,release)=>constructed.countDown();release.await()}
    val sourceCurrent=current
    state.updateAndGet(previous=>State(previous.live,
      if(!previous.live)Completion.StatusOnly(receipt,"cancelled-or-retired",observation.status)
      else if(!sourceCurrent)Completion.StatusOnly(receipt,"configuration-retired-or-revised",observation.status)
      else Completion.ResponseReady(receipt,observation)))
    completionPublished.countDown()
    ()
  }
  def handoff(identity:AttemptIdentity,limits:WorkerLimits,lease:InputLease):Unit=session.current {synchronized {
    require(state.get().live && attempt.isEmpty,"MCP operation already handed off or retired")
    require(lease.sourceDraft==inputDraft && lease.sourceHead==inputHead &&
      lease.dependencies.contains(session.configuration.sourceBinding),"MCP packet/configuration dependency mismatch")
    require(identity==lease.identity && identity.inputArtifact==prepared.inputArtifact,"MCP exact input association")
    require(lease.size<=16384 && limits.memoryBytes>=262144 && limits.outputBytes>=16384 &&
      limits.wallMillis<=60000,"MCP operation resource envelope")
    val expected=prepared.bytes;val actual=new Array[Byte](lease.size)
    try {lease.readOnly.get(actual);require(actual.sameElements(expected),"MCP prepared bytes mismatch")}
    finally {java.util.Arrays.fill(expected,0.toByte);java.util.Arrays.fill(actual,0.toByte)}
    attempt=Some(identity);input=Some(lease)
    val running=new Thread(()=> {
      try {
        session.current {require(state.get().live,"MCP operation cancelled before RPC")}
        prepared.operation match {
          case Operation.Discover=>
            val discovery=session.client.discover(math.max(1,limits.wallMillis/2))
            record(identity,Map("tool"->discovery.tool,"schema"->discovery.schemaIdentity),Some(discovery.schemaIdentity))
          case Operation.QualifyCounter | Operation.InvokeCounter=>
            val result=session.client.invoke(prepared.schemaIdentity.get,prepared.delta,key(identity),limits.wallMillis)
            record(identity,result,prepared.schemaIdentity)
        }
      } catch {
        case rejected:McpRejected=>
          try record(identity,Map("error"->rejected.response),prepared.schemaIdentity,true)
          catch {case _:Exception=>()}
        case _:Exception=>() // no fabricated failure or source on timeout/interruption
      }
    },"veri7vn-mcp-operation")
    running.setDaemon(true);worker=Some(running);running.start()
  }}
  /** Parent consumes this typed value. Capture/storage failure must leave a
    * ResponseReady undelivered, never turn it into terminal-only reconciliation. */
  private[runtime] def completionSnapshot(identity:AttemptIdentity):Completion=
    if(attempt.contains(identity))state.get().completion else Completion.Unknown
  private def projected(value:Completion):Reconciled=value match {
    case Completion.Unknown=>Reconciled.Unknown
    case Completion.ResponseReady(receipt,observation)=>
      if(observation.status==ResponseStatus.RejectedResponse)Reconciled.Failed(receipt) else Reconciled.Confirmed(receipt)
    case Completion.StatusOnly(receipt,_,status)=>
      if(status==ResponseStatus.RejectedResponse)Reconciled.Failed(receipt) else Reconciled.Confirmed(receipt)
  }
  def reconcile(identity:AttemptIdentity):Reconciled=completionSnapshot(identity) match {
    case Completion.Unknown if attempt.contains(identity) && prepared.operation!=Operation.Discover && worker.forall(!_.isAlive)=>
      try {session.current {()};session.client.reconcile(key(identity),250)} match {
        case Some(response)=>record(identity,response,prepared.schemaIdentity);projected(completionSnapshot(identity))
        case None=>Reconciled.Unknown
      } catch {case _:Exception=>Reconciled.Unknown}
    case value=>projected(value)
  }
  private[runtime] def withObservation[A](identity:AttemptIdentity)(consume:Observation=>A):A=session.current {
    require(state.get().live,"MCP observation retired")
    completionSnapshot(identity) match {
      case Completion.ResponseReady(_,observation)=>consume(observation)
      case _=>throw new IllegalStateException("MCP response not ready; do not terminalize as status-only")
    }
  }
  private[mcp] def invalidateLocal():Unit={
    state.updateAndGet(previous=>State(false,terminal(previous.completion)))
    worker.foreach(_.interrupt())
  }
  private[mcp] def releaseLocal():Unit={
    invalidateLocal();val running=worker;running.foreach(_.join(5000))
    require(running.forall(!_.isAlive),"MCP worker failed to stop")
    val held=synchronized {worker=None;val owned=input;input=None;owned};held.foreach(_.close())
  }
  def signalStop(identity:AttemptIdentity):Unit=if(attempt.contains(identity))invalidateLocal()
  def stop(identity:AttemptIdentity):Unit=signalStop(identity)
  def awaitStopped(identity:AttemptIdentity):Unit={
    val running=if(attempt.contains(identity))worker else None
    running.foreach(_.join(5000));require(running.forall(!_.isAlive),"MCP worker failed to stop")
    synchronized {if(attempt.contains(identity)) {input=None;worker=None}}
  }
  session.register(this)
}
