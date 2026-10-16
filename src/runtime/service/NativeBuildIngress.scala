package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.util.concurrent.{CompletableFuture,Semaphore,TimeUnit}
import java.util.concurrent.atomic.AtomicBoolean
import isabelle.{Bytes,XML,Markup,YXML}
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.effects.WorkerLifetime
import veri7vn.runtime.host.WorkspaceStore

object NativeBuildIngress {
  final class PreparedInput private[NativeBuildIngress](private[service] val ingress:NativeBuildIngress,private[service] val nativeHandle:BigInt,
    private[service] val input:NativeBuildInputs.Owned,
    val original:NativeBuildInputs.CapturedSource,
    private[service] val sourceGuard:WorkspaceStore.NativeSourceGuard) {
    private[NativeBuildIngress] val releaseLock=new Object
    private[NativeBuildIngress] var released=false
  }
  private[service] trait Transport {
    def exchange(operation:String,payload:String="",artifacts:List[Bytes]=Nil):ResidentSupervisor.Reply
  }
  private[service] final case class Limits(prepareWaitMillis:Long=120000,workerJoinMillis:Long=1000,maxOwnedInputs:Int=64) {
    require(prepareWaitMillis>0 && workerJoinMillis>0 && maxOwnedInputs>0 && maxOwnedInputs<=64)
  }
  private[service] final class CleanupPending(message:String) extends IllegalStateException(message)
}

/** Fixed protected ingress. Pending and canceled transfers remain owned until
  * native reconciliation AND worker termination are confirmed. Preparation
  * carries source expectations; it never runs or admits a build. */
final class NativeBuildIngress private[service](transport:NativeBuildIngress.Transport,
  store:WorkspaceStore,limits:NativeBuildIngress.Limits=NativeBuildIngress.Limits()) extends AutoCloseable {
  import NativeBuildIngress.*
  private val thisIngress=this
  private[service] def this(supervisor:ResidentSupervisor,store:WorkspaceStore)=this(new NativeBuildIngress.Transport {
    def exchange(operation:String,payload:String,artifacts:List[Bytes]):ResidentSupervisor.Reply=
      supervisor.exchange(operation,payload,artifacts)
  },store,NativeBuildIngress.Limits())
  type PreparedInput=NativeBuildIngress.PreparedInput
  private enum Handoff { case Waiting,Offered,Accepting,Accepted,Canceled }
  private val slots=new Semaphore(2)
  // Native exchanges and source callbacks never run under this monitor.
  private val ownership=new Object
  private val owned=scala.collection.mutable.Set.empty[TransferJob]
  private val prepared=scala.collection.mutable.Map.empty[BigInt,PreparedInput]
  private var closed=false

  private def expect(reply:ResidentSupervisor.Reply,tag:String,payload:String):Unit=
    require(reply.tag==tag && reply.payload==payload && reply.artifacts.isEmpty,"native build input response: "+tag)

  private final class TransferJob(val input:NativeBuildInputs.Owned,theoryPath:String,parents:Vector[BigInt]) extends WorkerLifetime {
    val nonce=java.util.UUID.randomUUID().toString.replace("-","")
    private val canceled=new AtomicBoolean(false)
    private val slotReleased=new AtomicBoolean(false)
    private val cleanupLock=new Object
    private var state=Handoff.Waiting // ownership monitor
    private var known:Option[PreparedInput]=None // ownership monitor
    private var touchedNative=false // ownership monitor
    private var disposed=false // cleanupLock
    @volatile private var correlationSettled=false
    val offered=new CompletableFuture[PreparedInput]()
    val thread=new Thread(new Runnable {def run():Unit=runTransfer()},"veri7vn-native-build-input-transfer")
    thread.setDaemon(true)
    private def live():Unit=require(!canceled.get(),"build input transfer canceled")
    private def runTransfer():Unit={
      try {
        live()
        val intent=input.withDescriptorTransfer(this)((view,_)=>view)
        val source=input.withTheoryTransfer(this,theoryPath)((view,_)=>view)
        require(intent.descriptorPath=="package.json" && source.path.endsWith(".thy") && source.path!="package.json")
        require(intent.draft==source.draft && intent.revision==source.revision && intent.manifest==source.manifest,
          "build descriptor and theory do not share captured revision")
        require(intent.descriptor.files.exists(file=>file.path==theoryPath &&
          file.role==veri7vn.packages.lifecycle.PackageModel.FileRole.Source),"build theory not declared source")
        val attributes=List("version"->"1","upload_nonce"->nonce,"revision"->source.revision,"manifest"->source.manifest,
          "descriptor_path"->intent.descriptorPath,"theory_path"->source.path,
          "descriptor_size"->intent.descriptorPin.size.toString,"theory_size"->source.pin.size.toString,
          "descriptor_sha256"->intent.descriptorPin.sha256,"theory_sha256"->source.pin.sha256)
        val children=parents.toList.map(id=>XML.Elem(Markup("parent",List("candidate"->id.toString)),Nil))
        val metadata=Bytes(YXML.string_of_body(List(XML.Elem(Markup("build-input",attributes),children))))
        require(metadata.size<=16384,"build input metadata bound")
        live()
        ownership.synchronized {touchedNative=true}
        val begin=transport.exchange("build_input_begin",artifacts=List(metadata))
        require(begin.tag=="build_input_ready" && begin.payload.matches("[1-9][0-9]{0,127}") && begin.artifacts.isEmpty,"native build input begin refused")
        val id=BigInt(begin.payload)
        def write(role:String,buffer:ByteBuffer):Unit={
          var offset=0
          while(buffer.hasRemaining){
            live()
            val bytes=new Array[Byte](math.min(buffer.remaining(),65536));buffer.get(bytes)
            val reply=try transport.exchange("build_input_write",s"$id,$role,$offset",List(Bytes(bytes)))
              finally java.util.Arrays.fill(bytes,0.toByte)
            expect(reply,"build_input_written",id.toString);offset+=bytes.length
          }
        }
        input.withDescriptorTransfer(this){(view,bytes)=>require(view==intent);write("descriptor",bytes)}
        input.withTheoryTransfer(this,theoryPath){(view,bytes)=>require(view==source);write("theory",bytes)}
        live()
        val finish=transport.exchange("build_input_finish",id.toString)
        require(finish.tag=="build_input_prepared" && finish.payload.matches("[1-9][0-9]{0,127}") && finish.artifacts.isEmpty,"native build input finish refused")
        val value=new PreparedInput(thisIngress,BigInt(finish.payload),input,source,input.currentSourceGuard)
        ownership.synchronized {
          // Remember a canceled late finish for release by known handle too.
          known=Some(value)
          require(state==Handoff.Waiting && !closed && !canceled.get(),"late canceled build input offer")
          state=Handoff.Offered
          offered.complete(value)
        }
      } catch {case problem:Throwable=>
        invalidate();offered.completeExceptionally(problem)
      }
    }
    def start():Unit=synchronized {live();thread.start()}
    def releaseSlot():Unit=if(slotReleased.compareAndSet(false,true))slots.release()
    def invalidate():Unit=synchronized {
      ownership.synchronized {
        canceled.set(true);state=Handoff.Canceled
        known.foreach(value=>prepared.remove(value.nativeHandle))
      }
      thread.interrupt()
    }
    private def joinWorker():Unit={
      require(Thread.currentThread()!=thread,"transfer cannot join itself")
      thread.join(limits.workerJoinMillis)
      if(thread.isAlive)throw new CleanupPending("build transfer worker has not terminated; ownership retained")
    }
    private def disposeNative():Unit=cleanupLock.synchronized {
      if(!disposed){
        val (handle,touched)=ownership.synchronized {(known.map(_.nativeHandle),touchedNative)}
        // A lost accept reply can hide accepted ownership. Nonce discard alone
        // cannot release that lease; retain and release the known handle first.
        handle.foreach {id=>expect(transport.exchange("build_input_release",id.toString),"build_input_released",id.toString)}
        if(touched && !correlationSettled){
          expect(transport.exchange("build_input_discard",nonce),"build_input_discarded",nonce)
          // Joined worker + FIFO discard reply drain all older begin/finish
          // commands before the terminal correlation record is removed.
          expect(transport.exchange("build_input_settle",nonce),"build_input_settled",nonce)
          correlationSettled=true
        }
        disposed=true
        // The two upload permits bound unresolved nonce correlations too, not
        // only live Scala threads. Never recycle one before confirmed settle.
        releaseSlot()
      }
    }
    def awaitStopped():Unit={joinWorker();if(canceled.get())disposeNative()}
    def accept(value:PreparedInput):PreparedInput={
      ownership.synchronized {
        require(!closed && state==Handoff.Offered && known.contains(value),"build input offer canceled")
        state=Handoff.Accepting
      }
      val payload=s"$nonce,${value.nativeHandle}"
      expect(transport.exchange("build_input_accept",payload),"build_input_accepted",payload)
      joinWorker()
      expect(transport.exchange("build_input_settle",nonce),"build_input_settled",nonce)
      correlationSettled=true
      ownership.synchronized {
        require(!closed && !canceled.get() && state==Handoff.Accepting,"build input acceptance canceled")
        require(!prepared.contains(value.nativeHandle),"duplicate native build input handle")
        prepared(value.nativeHandle)=value;state=Handoff.Accepted
      }
      releaseSlot()
      value
    }
    def retire():Unit={
      invalidate();awaitStopped();input.close()
      ownership.synchronized {owned-=this}
    }
    def isRetiring:Boolean=ownership.synchronized {state==Handoff.Canceled}
    def owns(value:PreparedInput):Boolean=ownership.synchronized {known.exists(_ eq value)}
  }

  /** Failed cleanup retains the registered input and consumes capacity until
    * retryCleanup confirms disposal. No unresolved ownership is evicted. */
  def prepare(input:NativeBuildInputs.Owned,theoryPath:String,parents:Vector[BigInt]=Vector.empty):PreparedInput={
    require(parents.size<=64 && parents.distinct==parents && parents.forall(id=>id>0 && id.toString.length<=128),"build input parent bound")
    // Reject a captured owner from another workspace before any native effect.
    store.withNativeSourceGuard(input.currentSourceGuard)(())
    require(slots.tryAcquire(),"native build input transfer capacity")
    val job=new TransferJob(input,theoryPath,parents)
    var registered=false
    try {
      ownership.synchronized {
        require(!closed && owned.size<limits.maxOwnedInputs,"build ingress closed or input capacity")
        owned+=job;registered=true
      }
      // Never take the source/store monitor under ownership: source invalidation
      // signals workers in the opposite direction. Cancellation before start is
      // arbitrated by the job's own start/invalidate monitor.
      input.attachTransferWorker(job)
      job.start()
      job.accept(job.offered.get(limits.prepareWaitMillis,TimeUnit.MILLISECONDS))
    } catch {case problem:Throwable=>
      if(job.thread.getState==Thread.State.NEW)job.releaseSlot()
      if(registered)try job.retire() catch {case cleanup:Throwable=>problem.addSuppressed(cleanup)}
      throw problem
    }
  }
  private[service] def preparedInput(handle:BigInt):PreparedInput=ownership.synchronized {
    require(!closed,"build ingress closed")
    prepared.getOrElse(handle,throw new IllegalStateException("native build input owner unavailable"))
  }
  private[service] def currentGuard(handle:BigInt):WorkspaceStore.NativeSourceGuard=ownership.synchronized {
    require(!closed,"build ingress closed")
    prepared.getOrElse(handle,throw new IllegalStateException("native build input owner unavailable")).sourceGuard
  }
  private[service] def retirementCount:Int=ownership.synchronized {owned.count(_.isRetiring)}
  private[service] def preparedCount:Int=ownership.synchronized {prepared.size}
  /** Called by the fixed artifact-ack consumer only after native request/candidate
    * owners retain independent source and intent leases. This releases the
    * upload producer, never semantic authority or those consumer leases. */
  private[service] def releaseProducer(value:PreparedInput):Unit=value.releaseLock.synchronized {
    require(value.ingress eq this,"prepared input belongs to another ingress")
    if(!value.released){
      val job=ownership.synchronized {owned.find(_.owns(value))}
      job match {
        case Some(owner)=>owner.retire()
        case None=>require(!value.input.isLive,"prepared input owner unavailable")
      }
      // Failed native release or resource teardown leaves this false and keeps
      // the retirement registered for an exact retry.
      value.released=true
    }
  }
  /** At most one owned cleanup per maintenance call. */
  private[service] def retryCleanup():Unit=ownership.synchronized {owned.find(_.isRetiring)}.foreach(_.retire())
  def close():Unit={
    val jobs=ownership.synchronized {closed=true;owned.toVector}
    jobs.foreach(_.invalidate())
    var failure:Option[Throwable]=None
    jobs.foreach {job=>try job.retire() catch {case problem:Throwable=>failure match {
      case None=>failure=Some(problem)
      case Some(first)=>first.addSuppressed(problem)
    }}}
    failure.foreach(throw _)
  }
}
