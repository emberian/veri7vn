package veri7vn.runtime.effects

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.nio.file.{Files,Path,LinkOption,StandardOpenOption}
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.ConcurrentLinkedQueue
import scala.jdk.CollectionConverters.*
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}

/** Payload/disk reservations, not an exact JVM heap cap. Fixed producers must
  * include their internal clone envelope and separately enforce worker limits. */
final case class ResourceBudget(owner:BigInt,maxPayloadBytes:Long,maxArrays:Int,
    maxRoots:Int,maxFiles:Int,maxDiskBytes:Long,maxPathChars:Int,maxDepth:Int,maxWorkers:Int) {
  require(owner>=0 && maxPayloadBytes>=0 && maxDiskBytes>=0 && maxArrays>0 &&
    maxRoots>0 && maxFiles>0 && maxPathChars>0 && maxDepth>0 && maxWorkers>0)
}
trait WorkerLifetime {
  /** Nonblocking cancellation signal, never a join or an acceptance decision. */
  def invalidate():Unit
  /** Normal return certifies the owned local worker has terminated. */
  def awaitStopped():Unit
}

final class WorkerResources private (val budget:ResourceBudget)
    extends WorkspaceStore.ManagedResourceOwner with AutoCloseable {
  private val valid=new AtomicBoolean(true)
  private var registration:Option[WorkspaceStore.ManagedResourceRegistration]=None
  private var payloadBytes=0L
  private var arrays=Vector.empty[OwnedBytes]
  private var roots=Vector.empty[OwnedRoot[?]]
  private var files=Map.empty[Path,Long]
  private var slots=Vector.empty[FileSlot]
  private var directories=Set.empty[Path]
  private var rootDirectory:Option[Path]=None
  private val workers=new ConcurrentLinkedQueue[WorkerLifetime]()
  private def bound:WorkspaceStore.ManagedResourceRegistration=synchronized {
    registration.getOrElse(throw new IllegalStateException("resource not registered"))
  }
  private def open():Unit=require(valid.get(),"worker resource invalidated")
  def isLive:Boolean=valid.get() && bound.isLive
  def withCurrent[A](action: => A):A=bound.withCurrent {open();action}
  private def reserve(bytes:Long):Unit={
    require(bytes>=0 && bytes<=budget.maxPayloadBytes-payloadBytes,"worker payload reservation")
    payloadBytes+=bytes
  }
  final class OwnedBytes private[WorkerResources](private var payload:Option[Array[Byte]]) {
    def size:Int=WorkerResources.this.synchronized {open();payload.fold(0)(_.length)}
    def readOnly:ByteBuffer={
      require(isLive,"worker source unavailable")
      WorkerResources.this.synchronized {open();ByteBuffer.wrap(payload.getOrElse(
        throw new IllegalStateException("owned bytes released"))).asReadOnlyBuffer()}
    }
    private[WorkerResources] def clear():Unit={payload.foreach(a=>java.util.Arrays.fill(a,0.toByte));payload=None}
  }
  final class OwnedRoot[A] private[WorkerResources](val reservationBytes:Long) {
    private var value:Option[A]=None
    def install(actual:A):Unit=withCurrent {WorkerResources.this.synchronized {
      open();require(value.isEmpty,"owned root already installed");value=Some(actual)
    }}
    /** Fixed trusted parser/analyzer region; do not return the private value. */
    def withValue[B](consume:A=>B):B=withCurrent {WorkerResources.this.synchronized {
      open();consume(value.getOrElse(throw new IllegalStateException("owned root empty")))
    }}
    private[effects] def withLiveValue[B](consume:A=>B):B={
      require(isLive,"worker source unavailable")
      WorkerResources.this.synchronized {open();consume(value.getOrElse(
        throw new IllegalStateException("owned root empty")))}
    }
    private[WorkerResources] def clear():Unit={value=None}
  }
  def reserveRoot[A](maxPayloadBytes:Long):OwnedRoot[A]=withCurrent {synchronized {
    open();require(roots.size<budget.maxRoots,"worker root budget");reserve(maxPayloadBytes)
    val root=new OwnedRoot[A](maxPayloadBytes);roots :+= root;root
  }}
  /** Registration is installed before scope.read allocates even its first copy. */
  private[effects] def capture(scope:ManagedSources#ReadScope,hash:String,maxBytes:Int):OwnedBytes=withCurrent {synchronized {
    open();require(maxBytes>=0 && arrays.size<budget.maxArrays,"worker array budget")
    reserve(maxBytes)
    var captured:Option[Array[Byte]]=None
    try {
      val bytes=scope.read(hash,maxBytes);captured=Some(bytes)
      val value=new OwnedBytes(Some(bytes));arrays :+= value
      payloadBytes-=maxBytes-bytes.length;value
    } catch {case failure:Throwable=>
      captured.foreach(a=>java.util.Arrays.fill(a,0.toByte));payloadBytes-=maxBytes;throw failure
    }
  }}
  /** Store journals the private region before mkdir; caller cannot select a parent. */
  def createDirectory():Path=withCurrent {synchronized {
    open();require(workers.isEmpty,"worker materialization already handed off")
    require(rootDirectory.isEmpty,"worker directory already allocated")
    val directory=bound.createScratchRoot()
    directories+=directory;rootDirectory=Some(directory);directory
  }}
  private def relative(name:String):Vector[String]={
    require(name.nonEmpty && name.length<=budget.maxPathChars && !name.startsWith("/") &&
      !name.contains('\\') && !name.contains('\u0000'),"worker relative path bound")
    val parts=name.split("/",-1).toVector
    require(parts.size<=budget.maxDepth && parts.forall(p=>p.nonEmpty && p!="." && p!=".."),"worker path components")
    parts
  }
  final class FileSlot private[WorkerResources](initialPath:Path,val size:Long) {
    private var target:Option[Path]=Some(initialPath)
    private var written=false
    def path:Path=WorkerResources.this.synchronized {open();target.getOrElse(throw new IllegalStateException("worker file released"))}
    private[WorkerResources] def clear():Unit={target=None}
    /** Preflight/reservation precedes evaluating the fixed producer's byte clone.
      * The temporary array is zeroed even on partial write. */
    def writeFrom(produce: => Array[Byte]):Unit=withCurrent {WorkerResources.this.synchronized {
      open();require(!written,"worker file slot already written");reserve(size)
      var bytes:Option[Array[Byte]]=None
      try {
        val data=produce;require(data!=null,"worker producer returned null");bytes=Some(data);require(data.length.toLong==size,"worker file size changed")
        Files.write(path,data,StandardOpenOption.CREATE_NEW,StandardOpenOption.WRITE)
        written=true
      } finally {try bytes.foreach(a=>java.util.Arrays.fill(a,0.toByte)) finally payloadBytes-=size}
    }}
  }
  def reserveFile(name:String,size:Long):FileSlot=withCurrent {synchronized {
    open();require(workers.isEmpty,"worker materialization already handed off");val parts=relative(name)
    require(files.size<budget.maxFiles && size>=0 && size<=budget.maxDiskBytes-files.values.sum,"worker disk budget")
    var parent=rootDirectory.getOrElse(throw new IllegalStateException("worker directory missing"))
    var prefix=Vector.empty[String]
    parts.dropRight(1).foreach {part=>
      prefix :+= part
      val next=parent.resolve(part)
      if(!directories.contains(next)) {
        val reserved=bound.reserveScratchDirectory(prefix.mkString("/"))
        require(reserved==next,"worker directory inventory mismatch")
        // The durable intent survives partial mkdir or process failure.
        Files.createDirectory(next);directories+=next
      }
      require(Files.isDirectory(next,LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(next),"worker parent changed")
      parent=next
    }
    val target=parent.resolve(parts.last)
    require(!files.contains(target) && !Files.exists(target,LinkOption.NOFOLLOW_LINKS),"worker file already exists")
    val reserved=bound.reserveScratchFile(name,size)
    require(reserved==target,"worker file inventory mismatch")
    files+=target->size
    val slot=new FileSlot(target,size);slots :+= slot;slot
  }}
  def attachWorker(worker:WorkerLifetime):Unit=withCurrent {synchronized {
    open();require(workers.size()<budget.maxWorkers,"worker count budget");workers.add(worker);()
  }}
  def invalidate():Unit={
    valid.set(false);var failure:Option[Throwable]=None
    workers.iterator().asScala.foreach {worker=>try worker.invalidate() catch {case problem:Throwable=>failure match {
      case None=>failure=Some(problem);case Some(first)=>first.addSuppressed(problem)
    }}}
    failure.foreach(throw _)
  }
  def stopAndRelease():Unit={
    valid.set(false)
    val snapshot=workers.iterator().asScala.toVector
    snapshot.foreach(worker=>try worker.invalidate() catch {case _:Throwable=>()})
    var joinFailure:Option[Throwable]=None
    snapshot.foreach {worker=>try worker.awaitStopped() catch {case problem:Throwable=>joinFailure match {
      case None=>joinFailure=Some(problem);case Some(first)=>first.addSuppressed(problem)
    }}}
    joinFailure.foreach(throw _)
    synchronized {
      arrays.foreach(_.clear());arrays=Vector.empty
      roots.foreach(_.clear());roots=Vector.empty
      slots.foreach(_.clear());slots=Vector.empty;payloadBytes=0
      // Store owns durable path inventory and cleanup after this callback returns.
      // Clear all process-local metadata even when a closed handle is retained.
      files=Map.empty;directories=Set.empty;rootDirectory=None;workers.clear()
    }
  }
  def close():Unit=bound.release()
}
object WorkerResources {
  final class Capture private[effects](val resources:WorkerResources,scope:ManagedSources#ReadScope) {
    def read(hash:String,maxBytes:Int):resources.OwnedBytes=resources.capture(scope,hash,maxBytes)

  }
  /** Trusted fixed consumer only: this provides storage ownership, never execution
    * authority. Native generated current policy/epoch/grant checks are additional.
    * No scope/parsed source object should escape the fixed consumer's opaque result. */
  def withCurrentCapture[A](sources:ManagedSources,draft:String,expectedHead:String,
      budget:ResourceBudget)(consume:Capture=>A):Option[A]={
    var owner:Option[WorkerResources]=None
    try sources.withHead(draft) {(head,scope)=>
      require(head==expectedHead,"worker source head changed")
      val resource=new WorkerResources(budget);owner=Some(resource)
      val registration=sources.registerCurrentResource(scope,resource)
      resource.synchronized {resource.registration=Some(registration)}
      consume(new Capture(resource,scope))
    } catch {case failure:Throwable=>
      // Outside withHead: joining here cannot retain the outer source lock.
      owner.foreach {resource=>try {
        if(resource.synchronized(resource.registration.nonEmpty))resource.close()
      } catch {case cleanup:Throwable=>failure.addSuppressed(cleanup)}}
      throw failure
    }
  }
}
