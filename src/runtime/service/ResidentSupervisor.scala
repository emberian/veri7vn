package veri7vn.runtime.service

import isabelle.*
import scala.language.unsafeNulls
import java.util.concurrent.{CompletableFuture, ConcurrentHashMap, LinkedBlockingQueue, TimeUnit}
import java.util.concurrent.atomic.AtomicLong

object ResidentSupervisor {
  final case class Limits(maxFrameBytes: Int = 2200000, maxInFlight: Int = 64, replyTimeoutSeconds: Long = 30) {
    require(maxFrameBytes>0 && maxInFlight>0 && replyTimeoutSeconds>0)
  }
  final case class Reply(id: Long, tag: String, payload: String, artifacts: List[Bytes] = Nil)
}

/** One resident PIDE process, never a per-request build/theory edit. Internal transport;
  * the external API cannot send raw native protocol commands or privileged events.
  */
final class ResidentSupervisor(sessionName: String, sessionDirs: List[Path], deploymentImages: DeploymentImages, threads: Int = 2,
  val limits: ResidentSupervisor.Limits = ResidentSupervisor.Limits()) extends AutoCloseable {
  import ResidentSupervisor.*
  require(threads>=1 && threads<=2,"initial host worker resource profile")
  private[service] val incarnation=java.util.UUID.randomUUID().toString.replace("-","")
  private val sequence=new AtomicLong(0)
  private val pending=new ConcurrentHashMap[Long,CompletableFuture[Reply]]()
  private val gateTokens=new LinkedBlockingQueue[AuthorityCoordinator.EventToken](limits.maxInFlight)
  private var closed=false
  private var residentOwnership:Option[veri7vn.runtime.host.WorkspaceStore.NativeResidentOwnership]=None
  private[service] def attachResidentOwnership(owner:veri7vn.runtime.host.WorkspaceStore.NativeResidentOwnership):Unit=synchronized {
    require(!closed && residentOwnership.isEmpty && owner.incarnation==incarnation,"native resident ownership mismatch")
    residentOwnership=Some(owner)
  }
  @volatile private var transportFailure: Option[String]=None
  private val options=Options.init()+s"threads=$threads"
  private val resources=Headless.Resources.make(options,sessionName,Logger.none,session_dirs=sessionDirs)
  private val image=deploymentImages.acquire(resources,sessionName,options)
  private[service] val bootManifest=image.manifest
  val deploymentIdentity:String=image.identity
  val deploymentCaptureMillis:Double=image.captureMillis
  // Launch exactly the private immutable heap copies named by the boot pin.
  // No theory/ML source is loaded from the mutable workspace after this point.
  private val session={
    val worker=new Session {
      override def session_options:Options=ResidentSupervisor.this.options
      override def interactive:Boolean=true
      override def resources:Resources=ResidentSupervisor.this.resources
    }
    try {
      Isabelle_Process.start(options,worker,resources.parent_background,image.heaps).await_startup()
      worker
    } catch {case failure:Throwable=>try worker.stop() finally image.close();throw failure}
  }
  private class Handler extends Session.Protocol_Handler {
    override def exit(state: Document.State): Unit = failAll("native worker exited")
    override def functions=List(
      "veri7vn_service_token_v1" -> ((message: Prover.Protocol_Output)=> {
        if(message.chunks.length!=1 || message.chunk.size>128 || !message.text.matches("[0-9]{1,18}"))
          failAll("malformed native gate token")
        else if(!gateTokens.offer(new AuthorityCoordinator.EventToken(message.text,
          AuthorityCoordinator.NativeAdmission("resident-admission")))) failAll("native gate token limit")
        true
      }),
      "veri7vn_service_v1" -> ((message: Prover.Protocol_Output)=> {
        val chunks=message.chunks
        if(chunks.isEmpty || chunks.length>3 || chunks.map(_.size).sum>limits.maxFrameBytes || chunks.head.size>1024)
          failAll("native response frame bound")
        else {
          val parts=chunks.head.text.split("\\|",4)
          if(parts.length!=4 || parts(0)!="1" || !parts(1).matches("[0-9]{1,18}")) failAll("malformed native response")
          else {
            val id=parts(1).toLong; val future=pending.remove(id)
            if(future!=null) future.complete(Reply(id,parts(2),parts(3),chunks.tail))
            else if(id==0) failAll("native transition failure")
          }
        }
        true
      }))
  }
  session.init_protocol_handler(new Handler)
  private def failAll(reason: String): Unit = {
    transportFailure=Some(reason)
    val iterator=pending.values().iterator()
    while(iterator.hasNext) iterator.next().completeExceptionally(new IllegalStateException(reason))
    pending.clear()
    gateTokens.clear()
  }
  private[service] def exchange(operation: String, payload: String="", artifacts: List[Bytes]=Nil): Reply = {
    val future=new CompletableFuture[Reply]()
    val id=synchronized {
      require(!closed,"worker closed")
      require(transportFailure.isEmpty,transportFailure.getOrElse("transport unavailable"))
      require(Set("status","initial","prepare","validate","ack","restore","cancel","install_ids","install_boot","command_info","recovery_info","recovery_read","recovery_dependencies","artifact_invalidations","cleanup_barrier","retry_cleanup","restore_begin","restore_material_begin","restore_write","restore_material_end","restore_finish","restore_progress","restore_abort","propose_math","poll_result","forget","inspect_routing","inspect_request","build_input_begin","build_input_write","build_input_finish","build_input_abort","build_input_release","build_input_discard","build_input_accept","build_input_settle","propose_build","build_current_binding").contains(operation),"operation requires an installed native gate")
      require(pending.size()<limits.maxInFlight,"worker in-flight limit")
      val id=sequence.incrementAndGet()
      require(payload.length<=512 && java.nio.charset.StandardCharsets.UTF_8.newEncoder().canEncode(payload),"malformed or oversized payload")
      val frame=List("1",id.toString,operation,payload)
      require(artifacts.size<=1 && frame.map(_.getBytes(java.nio.charset.StandardCharsets.UTF_8).length.toLong).sum+artifacts.map(_.size).sum<=limits.maxFrameBytes,"frame limit")
      pending.put(id,future)
      session.protocol_command_raw("veri7vn_service_v1",frame.map(Bytes.apply)++artifacts)
      id
    }
    val started=System.nanoTime()
    try future.get(limits.replyTimeoutSeconds,TimeUnit.SECONDS)
    catch {case timeout:java.util.concurrent.TimeoutException=>
      val elapsed=(System.nanoTime()-started)/1000000
      throw new IllegalStateException(s"native protocol timeout operation=$operation id=$id elapsed_ms=$elapsed in_flight=${pending.size()}",timeout)
    } finally pending.remove(id)
  }
  private[service] def pollAuthorizedToken(): Option[AuthorityCoordinator.EventToken] = if(transportFailure.nonEmpty) None else Option(gateTokens.poll())
  private[service] def awaitAuthorizedToken(): Option[AuthorityCoordinator.EventToken] = {
    require(transportFailure.isEmpty,transportFailure.getOrElse("transport unavailable"))
    Option(gateTokens.poll(250,TimeUnit.MILLISECONDS))
  }
  private[service] def diagnosticSyslog:String=session.syslog.content().take(16384)
  def status(): Reply = exchange("status")
  def close(): Unit = synchronized {
    if(!closed) {
      closed=true;failAll("worker stopped")
      var failure:Option[Throwable]=None
      try session.stop() catch {case problem:Throwable=>failure=Some(problem)}
      try residentOwnership.foreach(_.confirmStopped()) catch {case problem:Throwable=>failure match {case Some(first)=>first.addSuppressed(problem);case None=>failure=Some(problem)}}
      try image.close() catch {case problem:Throwable=>failure match {case Some(first)=>first.addSuppressed(problem);case None=>failure=Some(problem)}}
      failure.foreach(throw _)
    }
  }
}
