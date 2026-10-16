package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.util.concurrent.{CompletableFuture,Semaphore,TimeUnit}
import java.util.concurrent.atomic.AtomicBoolean
import isabelle.{Bytes,XML,YXML,Markup}
import veri7vn.runtime.connectors.mcp.McpIngress
import veri7vn.runtime.effects.WorkerLifetime
import veri7vn.runtime.service.effects.{NativeMcpConfiguration,NativeMcpPacket,NativeMcpResponse,PreparedMcpOperation}

/** Fixed source-upload mechanism for the same resident. Finite protocol handlers
  * must be installed by assembly; this class issues no effect grants or starts.
  * All transport happens on owned workers outside managed-source guard callbacks. */
private[service] final class ResidentMcpIngress(supervisor:ResidentSupervisor) extends AutoCloseable {
  private val slots=new Semaphore(2)
  private val active=new AtomicBoolean(true)
  private var jobs=Vector.empty[TransferJob]
  private def expect(reply:ResidentSupervisor.Reply,tag:String,payload:String):Unit=
    require(reply.tag==tag && reply.payload==payload && reply.artifacts.isEmpty,"MCP native upload response mismatch")
  private def number(s:String):BigInt={require(s.matches("[1-9][0-9]{0,127}"),"MCP native handle bound");BigInt(s)}
  private sealed trait Source {
    def copyBytes():Array[Byte]
    def checkCurrent():Unit
    def track(worker:WorkerLifetime):Unit
  }
  private final case class ConfigSource(staged:McpIngress.StagedConfiguration) extends Source {
    def fields={val d=staged.descriptor;(d.draft,d.head,d.member,d.sha256,d.size)}
    def copyBytes()=staged.withBytes(ResidentMcpIngress.this.copy)
    def checkCurrent():Unit=staged.withBytes(_=>())
    def track(worker:WorkerLifetime):Unit=staged.trackTransfer(worker)
  }
  private final case class PacketSource(staged:McpIngress.StagedPacket) extends Source {
    def fields={val d=staged.descriptor;(d.draft,d.head,d.member,d.sha256,d.size)}
    def copyBytes()=staged.withBytes(ResidentMcpIngress.this.copy)
    def checkCurrent():Unit=staged.withBytes(_=>())
    def track(worker:WorkerLifetime):Unit=staged.trackTransfer(worker)
  }
  private final case class ResponseSource(candidate:PreparedMcpOperation.ObservationCandidate) extends Source {
    def copyBytes()=candidate.withBytes(ResidentMcpIngress.this.copy)
    def checkCurrent():Unit=candidate.withBytes(_=>())
    def track(worker:WorkerLifetime):Unit=candidate.staged.trackTransfer(worker)
  }
  private sealed trait Accepted
  private case class ConfigAccepted(value:NativeMcpConfiguration) extends Accepted
  private case class PacketAccepted(value:NativeMcpPacket) extends Accepted
  private case class ResponseAccepted(value:NativeMcpResponse) extends Accepted
  private def copy(view:ByteBuffer):Array[Byte]={
    require(view.remaining()<=65536,"MCP source upload bound")
    val data=new Array[Byte](view.remaining());view.get(data);data
  }
  private final class TransferJob(val source:Source) extends WorkerLifetime {
    val nonce=java.util.UUID.randomUUID().toString.replace("-","")
    private val stopped=new AtomicBoolean(false)
    private val slotReleased=new AtomicBoolean(false)
    private var bytes=Array.emptyByteArray
    @volatile private var touched=false
    @volatile private var settled=false
    @volatile private var nativeHandle:Option[BigInt]=None
    @volatile private var error:Option[String]=None
    private var released=false
    @volatile private var cleanupAttempts=0
    @volatile private var cleanupAt=0L
    private val result=new CompletableFuture[Accepted]()
    private val cleanupLock=new Object
    private val startLock=new Object
    private def live():Unit=require(active.get() && !stopped.get(),"MCP source transfer retired")
    private val thread=new Thread(()=>run(),"veri7vn-mcp-source-upload")
    thread.setDaemon(true)
    def initialize():Unit={
      source.track(this) // registration precedes worker/copy allocation
      startLock.synchronized {live();thread.start()}
    }
    private def metadata:Bytes=source match {
      case ResponseSource(candidate)=>
        Bytes(YXML.string_of_body(List(XML.Elem(Markup("effect-response-source",List(
          "version"->"1","nonce"->nonce,"sha256"->candidate.identity,"size"->bytes.length.toString)),Nil))))
      case _=>
        val (draft,head,member,sha,size)=source match {
          case config:ConfigSource=>config.fields
          case packet:PacketSource=>packet.fields
          case _=>throw new IllegalStateException("MCP source role")
        }
        val attrs=List("version"->"1","nonce"->nonce,"draft"->draft,"head"->head,
          "member"->member,"sha256"->sha,"size"->size.toString)
        Bytes(YXML.string_of_body(List(XML.Elem(Markup("effect-source",attrs),Nil))))
    }
    private def run():Unit=try {
      live();bytes=source.copyBytes();live();touched=true
      val begin=source match {
        case _:ConfigSource=>supervisor.exchange("effect_config_begin",artifacts=List(metadata))
        case PacketSource(staged)=>
          val config=staged.installation.nativeConfiguration
          require(config.supervisor eq supervisor,"MCP packet belongs to another supervisor")
          supervisor.exchange("effect_packet_begin",config.nativeHandle.toString,List(metadata))
        case ResponseSource(candidate)=>
          val consumed=candidate.consumedStart
          require((consumed.supervisor eq supervisor) && (candidate.packet.supervisor eq supervisor),
            "MCP response belongs to another supervisor")
          supervisor.exchange("effect_response_begin",s"${consumed.gateToken},${consumed.entryIncarnation},${consumed.permitIdentity}",List(metadata))
      }
      val parts=begin.payload.split(",",-1)
      require(begin.tag=="effect_transfer" && begin.artifacts.isEmpty && parts.length==2 && parts(0)==nonce,
        "MCP native transfer correlation")
      val transfer=number(parts(1));val input=ByteBuffer.wrap(bytes);var offset=0
      while(input.hasRemaining) {
        live();val chunk=new Array[Byte](math.min(input.remaining(),65536));input.get(chunk)
        val next=offset+chunk.length
        try expect(supervisor.exchange("effect_input_write",s"$transfer,$offset",List(Bytes(chunk))),
          "effect_written",s"$transfer,$next") finally java.util.Arrays.fill(chunk,0.toByte)
        offset=next
      }
      live();expect(supervisor.exchange("effect_input_finish",transfer.toString),"effect_finished",nonce)
      live();val accepted=supervisor.exchange("effect_input_accept",nonce)
      val fields=accepted.payload.split(",",-1)
      require(accepted.artifacts.isEmpty && fields.nonEmpty && fields(0)==nonce,"MCP native accepted source correlation")
      val value=source match {
        case ConfigSource(staged)=>
          require(accepted.tag=="effect_configuration" && fields.length==3,"MCP native config response")
          val handle=number(fields(1));nativeHandle=Some(handle)
          ConfigAccepted(new NativeMcpConfiguration(staged.descriptor,number(fields(2)),handle,supervisor,staged))
        case PacketSource(staged)=>
          require(accepted.tag=="effect_packet" && fields.length==2,"MCP native packet response")
          val handle=number(fields(1));nativeHandle=Some(handle)
          PacketAccepted(new NativeMcpPacket(staged.descriptor,handle,supervisor,staged,staged.installation.nativeConfiguration))
        case ResponseSource(candidate)=>
          require(accepted.tag=="effect_response" && fields.length==3,"MCP native response-source association")
          val handle=number(fields(1));nativeHandle=Some(handle)
          ResponseAccepted(new NativeMcpResponse(candidate,handle,number(fields(2)),supervisor))
      }
      source.checkCurrent();live()
      result.complete(value)
    } catch {case failure:Throwable=>
      stopped.set(true);error=Some(failure.getClass.getSimpleName);result.completeExceptionally(failure)
    } finally {java.util.Arrays.fill(bytes,0.toByte);bytes=Array.emptyByteArray}
    private def releaseSlot():Unit=if(slotReleased.compareAndSet(false,true))slots.release()
    def invalidate():Unit={stopped.set(true);thread.interrupt()}
    def awaitStopped():Unit={
      require(Thread.currentThread()!=thread,"MCP transfer cannot join itself")
      startLock.synchronized {if(thread.getState==Thread.State.NEW)stopped.set(true)}
      thread.join(5000)
      require(!thread.isAlive,"MCP transfer worker still live; ownership retained")
      java.util.Arrays.fill(bytes,0.toByte);bytes=Array.emptyByteArray
      if(stopped.get())try cleanup() catch {case failure:Throwable=>
        cleanupAttempts+=1;error=Some(failure.getClass.getSimpleName)
        cleanupAt=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(math.min(30000L,250L*(1L<<math.min(7,cleanupAttempts-1))))
        throw failure
      }
    }
    private def cleanup():Unit=cleanupLock.synchronized {
      if(!released) {
        nativeHandle.foreach {handle=>source match {
          case _:ConfigSource=>expect(supervisor.exchange("effect_config_release",handle.toString),"effect_config_released",handle.toString)
          case _:PacketSource=>expect(supervisor.exchange("effect_packet_release",handle.toString),"effect_packet_released",handle.toString)
          case _:ResponseSource=>expect(supervisor.exchange("effect_response_release",handle.toString),"effect_response_released",handle.toString)
        }}
        if(touched && !settled) {
          expect(supervisor.exchange("effect_input_discard",nonce),"effect_discarded",nonce)
          expect(supervisor.exchange("effect_input_settle",nonce),"effect_settled",nonce)
          settled=true
        }
        released=true;releaseSlot();ResidentMcpIngress.this.synchronized {jobs=jobs.filterNot(_ eq this)}
      }
    }
    def awaitResult():Accepted={
      val accepted=result.get(60000,TimeUnit.MILLISECONDS)
      // The native nonce tombstone may be settled only after this tracked upload
      // worker has stopped: no late finish/accept may race removal of the nonce.
      awaitStopped();source.checkCurrent();live()
      cleanupLock.synchronized {
        live()
        expect(supervisor.exchange("effect_input_settle",nonce),"effect_settled",nonce)
        settled=true;releaseSlot()
      }
      accepted
    }
    def canRetry:Boolean=stopped.get() && cleanupAttempts<8 && System.nanoTime()>=cleanupAt
    def retryExhausted():Unit={cleanupAttempts=0;cleanupAt=0L}
    def pendingFailure:Option[(String,String)]=if(stopped.get())Some((nonce,error.getOrElse("cleanup pending")))else None
  }
  private def upload(source:Source):Accepted={
    require(active.get() && slots.tryAcquire(),"MCP upload capacity unavailable")
    val job=new TransferJob(source)
    try {
      synchronized {require(jobs.size<64,"MCP retained upload owner bound");jobs :+= job}
      job.initialize();job.awaitResult()
    } catch {case failure:Throwable=>
      job.invalidate()
      try job.awaitStopped() catch {case cleanup:Throwable=>failure.addSuppressed(cleanup)}
      throw failure
    }
  }
  private[service] def installConfiguration(staged:McpIngress.StagedConfiguration):McpIngress.Installation={
    val association=upload(ConfigSource(staged)) match {
      case ConfigAccepted(value)=>value;case _=>throw new IllegalStateException("MCP config result kind")
    }
    try staged.install(association) catch {case failure:Throwable=>
      try staged.close() catch {case cleanup:Throwable=>failure.addSuppressed(cleanup)}
      throw failure
    }
  }
  private[service] def uploadPacket(staged:McpIngress.StagedPacket):NativeMcpPacket=upload(PacketSource(staged)) match {
    case PacketAccepted(value)=>value;case _=>throw new IllegalStateException("MCP packet result kind")
  }
  private[service] def uploadResponse(candidate:PreparedMcpOperation.ObservationCandidate):NativeMcpResponse=
      upload(ResponseSource(candidate)) match {
    case ResponseAccepted(value)=>value
    case _=>throw new IllegalStateException("MCP response result kind")
  }
  /** Existing host maintenance pump calls this; no new scheduler/thread. */
  private[service] def retryCleanup():Unit={
    val pending=synchronized {jobs.filter(_.canRetry)}
    pending.take(1).foreach(job=>try job.awaitStopped() catch {case scala.util.control.NonFatal(_)=>()})
  }
  private[service] def retryExhausted():Unit=synchronized {jobs.foreach(_.retryExhausted())}
  private[service] def cleanupFailures:Vector[(String,String)]=synchronized {jobs.flatMap(_.pendingFailure)}
  def close():Unit={
    active.set(false);val owned=synchronized {jobs};owned.foreach(_.invalidate())
    var failure:Option[Throwable]=None
    owned.foreach(job=>try job.awaitStopped() catch {case error:Throwable=>failure match {
      case None=>failure=Some(error);case Some(first)=>first.addSuppressed(error)
    }})
    failure.foreach(throw _)
  }
}
