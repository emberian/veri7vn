package veri7vn.packages.intake

import scala.language.unsafeNulls
import java.io.{ByteArrayInputStream, ByteArrayOutputStream, DataInputStream, DataOutputStream}
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.{Files, Path, LinkOption, StandardCopyOption, StandardOpenOption}
import Intake.*

/** Host-managed Stage adapters implement this exact-byte storage boundary.
  * put must register ownership before writing; read checks current scoped membership.
  * No implementation may expose a bare global hash read capability to clients.
  */
trait ByteObjects {
  def put(bytes: Array[Byte]): String
  def read(id: String, maxBytes: Long): Array[Byte]
}
private[intake] final class LocalObjects(val root: Path, limits: Limits) extends ByteObjects {
  Files.createDirectories(root)
  require(Files.isDirectory(root,LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(root), "Store root must be a trusted directory")
  private val maximum = math.max(limits.maxArchiveBytes,limits.maxFileBytes)
  private def validId(id: String): Unit = require(id.matches("[0-9a-f]{64}"), "Bad object identity")
  private def readPath(path: Path, bound: Long): Array[Byte] = {
    require(Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS), "Object must be a regular file")
    val in=Files.newInputStream(path,LinkOption.NOFOLLOW_LINKS)
    try {
      val out=new ByteArrayOutputStream(); val buffer=new Array[Byte](8192);var n=in.read(buffer)
      while(n != -1) { require(out.size().toLong+n<=bound,"Stored object exceeds limit");out.write(buffer,0,n);n=in.read(buffer) }
      out.toByteArray
    } finally in.close()
  }
  override def put(bytes: Array[Byte]): String = {
    require(bytes.length<=maximum.toLong.max(limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024),"Object bound")
    val id=hash(bytes);val target=root.resolve(id)
    if(!Files.exists(target,LinkOption.NOFOLLOW_LINKS)) {
      val temp=Files.createTempFile(root,"pending-",".blob")
      try {
        val channel=FileChannel.open(temp,StandardOpenOption.WRITE)
        try { val b=ByteBuffer.wrap(bytes);while(b.hasRemaining)channel.write(b);channel.force(true) } finally channel.close()
        // Atomic no-replace link publishes a fully forced inode. Existing bytes are never overwritten.
        // The trusted host owns this directory; unsupported hard-link providers fail closed.
        try Files.createLink(target,temp)
        catch { case _: java.nio.file.FileAlreadyExistsException => () }
        val directory=FileChannel.open(root,StandardOpenOption.READ)
        try directory.force(true) finally directory.close()
      } finally Files.deleteIfExists(temp)
    }
    require(java.util.Arrays.equals(readPath(target,math.max(maximum.toLong,bytes.length.toLong)),bytes), "Object corruption")
    id
  }
  override def read(id: String,maxBytes: Long):Array[Byte]={validId(id);readPath(root.resolve(id),maxBytes)}
}

/** Immutable object parser; mutable heads, ownership and replay belong to the host. */
final class SourceObjects(storage: ByteObjects, limits: Limits) {
  def this(storage: ByteObjects)=this(storage,Limits())
  def this(root: Path, limits: Limits)=this(new LocalObjects(root,limits),limits)
  def this(root: Path)=this(root,Limits())
  /** Legacy test/development root only; managed stages deliberately expose no filesystem root. */
  def root: Path=storage match {case local:LocalObjects=>local.root
    case _=>throw new UnsupportedOperationException("Managed source objects have no raw root endpoint")}
  private val maximum=math.max(limits.maxArchiveBytes,limits.maxFileBytes)
  private def validId(id:String):Unit=require(id.matches("[0-9a-f]{64}"),"Bad object identity")
  private def read(id:String,bound:Long):Array[Byte]={
    validId(id);val bytes=storage.read(id,bound)
    require(bytes.length.toLong<=bound,"Storage adapter exceeded requested bound");bytes.clone()
  }
  private def persist(bytes:Array[Byte]):String={
    require(bytes.length.toLong<=maximum.toLong.max(limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024),"Object bound")
    val expected=hash(bytes);val id=storage.put(bytes.clone())
    require(id==expected,"Storage adapter changed exact object identity")
    require(java.util.Arrays.equals(read(id,bytes.length),bytes),"Stored object differs from exact bytes")
    id
  }
  def put(content:Content):String={require(content.size<=maximum,"Blob exceeds store limit");persist(content.bytes)}
  def content(id:String):Content={val bytes=read(id,maximum);require(hash(bytes)==id,"Stored blob checksum mismatch");Content(bytes)}
  private def encode(write: DataOutputStream => Unit): Array[Byte] = {
    val bytes=new ByteArrayOutputStream();val out=new DataOutputStream(bytes)
    write(out);out.flush();bytes.toByteArray
  }
  private def writeEntries(out: DataOutputStream, entries: Vector[Entry]): Unit = {
    require(entries.size<=limits.maxEntries);out.writeInt(entries.size)
    entries.foreach(e => {out.writeUTF(e.path);out.writeUTF(put(e.content))})
  }
  private def readEntries(in: DataInputStream): Vector[Entry] = {
    val n=in.readInt();require(n>=0 && n<=limits.maxEntries,"Invalid manifest entry count")
    var total=0L
    Vector.fill(n) {
      val path=in.readUTF();Intake.portablePath(path,limits)
      val c=content(in.readUTF());total+=c.size
      require(c.size<=limits.maxFileBytes && total<=limits.maxTotalBytes,"Revision data exceeds bounds")
      Entry(path,c,Role.Other) // classification is recovered through inert staging, never stored authority flags
    }
  }
  final case class StoredIntake(record: String, packageIdentity: String, archive: Option[String])
  def preserve(staged: Staged): StoredIntake = {
    Intake.recoverStage(staged.format,staged.entries,staged.identity,staged.originalArchive,staged.originLabel,limits)
    val archive=staged.originalArchive.map(put)
    val bytes=encode { out =>
      out.writeUTF("veri7vn-intake-record/1");out.writeUTF(staged.format.toString)
      out.writeUTF(staged.identity);out.writeUTF(staged.originLabel)
      out.writeBoolean(archive.nonEmpty);archive.foreach(out.writeUTF)
      writeEntries(out,staged.entries)
    }
    StoredIntake(persist(bytes),staged.identity,archive)
  }
  def revision(value: Revision, originalRecord: Option[String] = None): String = {
    validId(value.id);value.parent.foreach(validId);originalRecord.foreach(validId)
    require(value.entries.size<=limits.maxEntries && value.entries.forall(_.content.size<=limits.maxFileBytes) &&
      value.entries.map(_.content.size.toLong).sum<=limits.maxTotalBytes,"Revision source exceeds bounds")
    Intake.recoverRevision(value.id,value.parent,value.entries,limits)
    val bytes=encode { out =>
      out.writeUTF("veri7vn-draft-source/1");out.writeUTF(value.id)
      out.writeBoolean(value.parent.nonEmpty);value.parent.foreach(out.writeUTF)
      out.writeBoolean(originalRecord.nonEmpty);originalRecord.foreach(out.writeUTF)
      writeEntries(out,value.entries)
    }
    persist(bytes)
  }
  /** Returned identity is a storage object locator, distinct from Revision.id (source lineage). */
  private[packages] def recoverRecord(locator: String): (Revision, Option[String]) = {
    validId(locator)
    val bytes=read(locator,limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024)
    require(hash(bytes)==locator,"Revision manifest checksum mismatch")
    val in=new DataInputStream(new ByteArrayInputStream(bytes))
    require(in.readUTF()=="veri7vn-draft-source/1","Unknown revision record")
    val id=in.readUTF();validId(id)
    val parent=if(in.readBoolean())Some(in.readUTF())else None;parent.foreach(validId)
    val origin=if(in.readBoolean())Some(in.readUTF())else None;origin.foreach(validId)
    val entries=readEntries(in)
    require(in.read()== -1,"Trailing manifest contents")
    // Validate identity/paths using the same creation operation (no parsed source execution).
    (Intake.recoverRevision(id,parent,entries,limits),origin)
  }
  def recover(locator: String): Revision = recoverRecord(locator)._1
  def originRecord(locator: String): Option[String] = recoverRecord(locator)._2
  def recoverIntake(locator: String): Staged = {
    validId(locator)
    val bytes=read(locator,limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024)
    require(hash(bytes)==locator,"Intake manifest checksum mismatch")
    val in=new DataInputStream(new ByteArrayInputStream(bytes))
    require(in.readUTF()=="veri7vn-intake-record/1","Unknown intake record")
    val format=Format.valueOf(in.readUTF());val id=in.readUTF();validId(id);val label=in.readUTF()
    val archive=if(in.readBoolean())Some(content(in.readUTF()))else None
    val entries=readEntries(in);require(in.read()== -1,"Trailing intake record contents")
    Intake.recoverStage(format,entries,id,archive,label,limits)
  }
  /** Complete direct object closure of one source revision and its preserved original.
    * Historical revisions/prepared writes are additional host associations, not guessed here. */
  def referenceClosure(locator:String):Set[String]={
    val (revision,origin)=recoverRecord(locator)
    var result=Set(locator)++revision.entries.map(_.content.sha256)
    origin.foreach { record=>
      val original=recoverIntake(record)
      result+=record;result++=original.entries.map(_.content.sha256)
      original.originalArchive.foreach(c=>result+=c.sha256)
    }
    require(result.size<=limits.maxEntries.toLong*2+3,"Object closure bound")
    result
  }

}

/** Required adapter: host single-writer transaction durably CASes draft source head.
  * Head is an inert source manifest locator, not active package authority.
  * Must atomically return false without changing head on mismatch, and acknowledge only after durability.
  * The package-lifecycle adapter additionally enforces access/revocation and operation-id replay policy.
  */
trait DraftJournal {
  def head(draft: String): Option[String]
  def withHead[A](draft: String)(materialize: String => A): Option[A]
  def compareAndAppend(draft: String, expected: Option[String], next: String): Boolean
}
final class Drafts(store: SourceObjects, journal: DraftJournal) {
  def read(draft: String): Option[Revision] = journal.withHead(draft)(store.recover)
  def originals(draft: String): Option[Staged] = journal.withHead(draft) { locator =>
    store.recoverIntake(store.originRecord(locator).getOrElse(throw new Rejected("origin","No original intake record")))
  }
  def create(draft: String, source: Staged): String = {
    val original=store.preserve(source)
    val locator=store.revision(Intake.initial(source),Some(original.record))
    if(!journal.compareAndAppend(draft,None,locator)) throw new Rejected("conflict","Draft already exists")
    locator
  }
  def edit(draft: String, expectedLocator: String, expectedRevision: String, edits: Vector[Edit]): String = {
    val snapshot=journal.withHead(draft) { current =>
      if(current!=expectedLocator) throw new Rejected("conflict","Draft head changed")
      // Both source and provenance are read while current association access is protected.
      store.recoverRecord(current)
    }.getOrElse(throw new Rejected("conflict","Draft unavailable or revoked"))
    val next=Intake.patch(snapshot._1,expectedRevision,edits)
    val locator=store.revision(next,snapshot._2)
    if(!journal.compareAndAppend(draft,Some(expectedLocator),locator))
      throw new Rejected("conflict","Concurrent draft update; prepared immutable object is not published")
    locator
  }
}
