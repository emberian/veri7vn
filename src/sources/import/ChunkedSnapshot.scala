package veri7vn.sources

import scala.language.unsafeNulls
import java.io.{ByteArrayOutputStream,DataOutputStream}
import java.nio.file.{Files,Path,LinkOption}
import java.security.MessageDigest
import scala.collection.mutable.ArrayBuffer
import scala.util.control.NonFatal

/** Whole captured byte stream, independent of bounded row-materialization formats.
  * The host owns storage, attempt authority and cleanup. No chunk is a complete source.
  */
object ChunkedSnapshot {
  import LocalSnapshot.*
  final case class Limits(chunkBytes: Int=65536,maxBytes: Long=1024L*1024*1024*1024,
    maxChunks: Int=1000000,maxManifestBytes: Int=64*1024*1024) {
    require(chunkBytes>0 && chunkBytes<=16*1024*1024 && maxBytes>=0 && maxChunks>=0 &&
      maxManifestBytes>0 && maxManifestBytes<=64*1024*1024)
  }
  final case class Span(offset: Long,size: Int,objectId: String)
  /** Existing host immutable-object store adapter. This is I/O, not native authority.
    * Every expected object is managed under the current attempt before calling put.
    * Storage failures may be indeterminate; the host reconciles/cleans the whole attempt.
    */
  trait Objects {
    def put(expected: String,bytes: Array[Byte],retention: Retention): Unit
  }
  final class Candidate private[ChunkedSnapshot](source: Manifest,spans: Vector[Span],
    count: Long,digest: Option[String],complete: Boolean) {
    private final case class Material(manifest: Manifest,chunks: Vector[Span],size: Long,
      payloadId: Option[String],complete: Boolean)
    private var material: Option[Material]=Some(Material(source,spans,count,digest,complete))
    private def retained=material.getOrElse(throw new IllegalStateException("source chunks released"))
    def manifest: Manifest=synchronized {retained.manifest}
    def chunks: Vector[Span]=synchronized {retained.chunks}
    def size: Long=synchronized {retained.size}
    def payloadId: Option[String]=synchronized {retained.payloadId}
    def isComplete: Boolean=synchronized {retained.complete}
    def isLive: Boolean=synchronized {material.nonEmpty}
    def release(): Unit=synchronized {material=None}
    /** Index is a storage descriptor. Native chunk/index association and EOF observation
      * are required before publishing it; a hash is not source-query coverage evidence.
      */
    def indexBytes: Array[Byte]=synchronized {
      val m=retained;val buffer=new ByteArrayOutputStream();val out=new DataOutputStream(buffer)
      out.writeUTF("veri7vn-source-byte-chunks/1");out.writeBoolean(m.complete);out.writeLong(m.size)
      out.writeBoolean(m.payloadId.nonEmpty);m.payloadId.foreach(out.writeUTF)
      val context=LocalSnapshot.manifestRecord(m.manifest,m.payloadId)
      out.writeInt(context.length);out.write(context)
      out.writeInt(m.chunks.size)
      m.chunks.foreach(s=>{out.writeLong(s.offset);out.writeInt(s.size);out.writeUTF(s.objectId)})
      out.flush();buffer.toByteArray
    }
  }
  sealed trait Result
  final case class Captured(candidate: Candidate) extends Result
  final case class Incomplete(code: String,candidate: Candidate) extends Result
  /** Bounded producer output. finishProduced means the selected producer returned a
    * complete wire stream, not that the source relation or query is complete.
    * close/abort never install a complete index. The host still owns commit/admission.
    */
  final class ChunkOutput private[ChunkedSnapshot](initial: Manifest,objects: Objects,limits: Limits)
      extends java.io.OutputStream {
    private var source: Option[Manifest]=Some(initial)
    private val buffer=new Array[Byte](limits.chunkBytes)
    private var used=0
    private val spans=ArrayBuffer.empty[Span]
    private var digest: Option[MessageDigest]=Some(MessageDigest.getInstance("SHA-256"))
    private var sink: Option[Objects]=Some(objects)
    private var offset=0L
    private var indexSize=256L+LocalSnapshot.manifestRecord(initial,None).length
    private var terminal: Option[Result]=None
    private def active(): Manifest = {
      if(indexSize>limits.maxManifestBytes)throw new java.io.IOException("source.manifest_budget")
      if(terminal.nonEmpty)throw new java.io.IOException("source producer closed")
      if(Thread.currentThread().isInterrupted)throw new java.io.InterruptedIOException("source producer cancelled")
      source.getOrElse(throw new java.io.IOException("source producer released"))
    }
    private def flushChunk(): Unit = if(used>0) {
      val manifest=active()
      if(spans.size>=limits.maxChunks || used.toLong>limits.maxBytes-offset)
        throw new java.io.IOException("source.acquisition_budget")
      if(indexSize+84>limits.maxManifestBytes)throw new java.io.IOException("source.manifest_budget")
      val bytes=java.util.Arrays.copyOf(buffer,used)
      val id=LocalSnapshot.hash(bytes)
      // The candidate and Stage independently retain the intended locator before I/O.
      spans+=Span(offset,used,id);offset+=used;indexSize+=84;digest.get.update(bytes)
      used=0;java.util.Arrays.fill(buffer,0.toByte)
      try sink.get.put(id,bytes,manifest.retention) catch {
        case error: java.io.InterruptedIOException => abort("source.cancelled");throw error
        case NonFatal(error) => abort("source.acquisition_failure");throw error
      }
    }
    override def write(value: Int): Unit = synchronized {
      active();buffer(used)=value.toByte;used+=1
      if(used==buffer.length)flushChunk()
    }
    override def write(bytes: Array[Byte],start: Int,length: Int): Unit = synchronized {
      java.util.Objects.checkFromIndexSize(start,length,bytes.length)
      active();var position=start;var remaining=length
      while(remaining>0) {
        active()
        val n=Math.min(buffer.length-used,remaining)
        System.arraycopy(bytes,position,buffer,used,n)
        used+=n;position+=n;remaining-=n
        if(used==buffer.length)flushChunk()
      }
    }
    // Flush is deliberately just a bounded chunk boundary, never an EOF assertion.
    override def flush(): Unit=synchronized {active();flushChunk()}
    def abort(code: String): Result = synchronized {
      terminal.getOrElse {
        val result=Incomplete(code,new Candidate(source.get,spans.toVector,offset,None,false))
        used=0;java.util.Arrays.fill(buffer,0.toByte);source=None;digest=None;sink=None;terminal=Some(result);result
      }
    }
    def finishProduced(): Result = synchronized {
      terminal.getOrElse {
        try {
          active()
          if(indexSize>limits.maxManifestBytes)throw new java.io.IOException("source.manifest_budget")
          flushChunk()
          val id=digest.get.digest().map(b=>f"${b & 255}%02x").mkString
          val result=Captured(new Candidate(source.get,spans.toVector,offset,Some(id),true))
          source=None;digest=None;sink=None;terminal=Some(result);result
        } catch {
          case _:java.io.InterruptedIOException => abort("source.cancelled")
          case NonFatal(_) => abort("source.acquisition_failure")
        }
      }
    }
    override def close(): Unit={abort("source.producer_closed_without_completion");()}
    def release(): Unit=synchronized {
      terminal.foreach {
        case Captured(candidate)=>candidate.release()
        case Incomplete(_,candidate)=>candidate.release()
      }
      source=None;digest=None;sink=None;spans.clear();used=0;java.util.Arrays.fill(buffer,0.toByte)
    }
  }
  def chunkOutput(manifest: Manifest,objects: Objects,limits: Limits=Limits()): ChunkOutput = {
    val validation=LocalSnapshot.prepare(Array.emptyByteArray,manifest);validation.release()
    new ChunkOutput(manifest,objects,limits)
  }
  def capture(path: Path,manifest: Manifest,objects: Objects,limits: Limits=Limits()): Result = {
    require(Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS),"Source must be an inert regular file")
    val producer=chunkOutput(manifest,objects,limits)
    val in=Files.newInputStream(path,LinkOption.NOFOLLOW_LINKS)
    try {
      val buffer=new Array[Byte](limits.chunkBytes)
      var eof=false
      while(!eof) {
        if(Thread.currentThread().isInterrupted)return producer.abort("source.cancelled")
        val count=in.read(buffer)
        if(count<0)eof=true
        else if(count==0)throw new java.io.IOException("Non-progressing source read")
        else producer.write(buffer,0,count)
      }
      producer.finishProduced()
    } catch {
      case _:InterruptedException=>Thread.currentThread().interrupt();producer.abort("source.cancelled")
      case _:java.io.InterruptedIOException=>producer.abort("source.cancelled")
      case NonFatal(error)=>producer.abort(Option(error.getMessage).filter(message=>
        message=="source.acquisition_budget" || message=="source.manifest_budget").getOrElse("source.acquisition_failure"))
    } finally in.close()
  }
}
