package veri7vn.runtime.host

import scala.language.unsafeNulls
import java.nio.file.{Files,Path,StandardOpenOption,StandardCopyOption,LinkOption}
import java.nio.channels.FileChannel
import java.sql.Connection

object ManagedSources {
  final case class Limits(maxObjectBytes: Int=40*1024*1024,maxStageBytes: Long=256L*1024*1024,maxObjects:Int=8192,maxOperations:Int=128) {
    require(maxObjectBytes>0 && maxStageBytes>=maxObjectBytes && maxObjects>0 && maxObjects<=8192 && maxOperations>0 && maxOperations<=65536)
  }
  enum OperationStatus { case Committed, Conflict, Aborted }
  final case class Receipt(operation: String,status:OperationStatus=OperationStatus.Committed)
  sealed trait Begin
  final case class Fresh(stage: ManagedSources#Stage) extends Begin
  final case class Replay(receipt: Receipt) extends Begin
  case object IdentityMismatch extends Begin
  case object Unavailable extends Begin
  sealed trait Commit
  final case class Published(receipt: Receipt) extends Commit
  case object Conflict extends Commit
  case object CommitUnavailable extends Commit
  final case class StorageErased(draft: String)
}

/** Inert managed bytes and operation replay, sharing the existing workspace writer.
  * Native release/Forget must be joined separately before reporting full deletion. */
final class ManagedSources(store: WorkspaceStore,val limits: ManagedSources.Limits=ManagedSources.Limits()) {
  import ManagedSources.*
  private val nofollow=LinkOption.NOFOLLOW_LINKS
  private def privateDirectory(path:Path):Path={
    if(!Files.exists(path,nofollow)) Files.createDirectory(path)
    require(Files.isDirectory(path,nofollow),"managed source directory symlink or shape")
    Files.setPosixFilePermissions(path,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"))
    path
  }
  private val base=privateDirectory(store.managedRoot.resolve("managed-sources"))
  private val objects=privateDirectory(base.resolve("objects"))
  private val stages=privateDirectory(base.resolve("stages"))
  private[host] var afterBeginPreflight: () => Unit = () => ()
  private def sql(c:Connection,text:String):Unit={val q=c.createStatement();try q.execute(text) finally q.close()}
  store.managedRead { c=>
    sql(c,"PRAGMA secure_delete=ON")
    sql(c,"CREATE TABLE IF NOT EXISTS managed_source_drafts(draft TEXT PRIMARY KEY,forgotten INTEGER NOT NULL DEFAULT 0)")
    sql(c,"CREATE TABLE IF NOT EXISTS managed_source_ops(id TEXT PRIMARY KEY,draft TEXT NOT NULL REFERENCES managed_source_drafts(draft),request BLOB,expected TEXT,state TEXT NOT NULL,stage TEXT NOT NULL)")
    sql(c,"CREATE TABLE IF NOT EXISTS managed_source_closures(draft TEXT NOT NULL,manifest TEXT NOT NULL,hash TEXT NOT NULL,PRIMARY KEY(draft,manifest,hash))")
    sql(c,"CREATE INDEX IF NOT EXISTS managed_source_ops_draft ON managed_source_ops(draft)")
    sql(c,"CREATE TABLE IF NOT EXISTS managed_source_members(op TEXT NOT NULL REFERENCES managed_source_ops(id),hash TEXT NOT NULL,size INTEGER NOT NULL,written INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(op,hash))")
    sql(c,"CREATE INDEX IF NOT EXISTS managed_source_members_hash ON managed_source_members(hash)")
  }
  private def identity(id:String):Unit=require(id.matches("[A-Za-z0-9_-]{1,128}"),"managed identity")
  private def locator(hash:String):Unit=require(hash.matches("[0-9a-f]{64}"),"managed locator")
  private def permitted(c:Connection,draft:String):Boolean={
    val q=c.prepareStatement("SELECT forgotten FROM managed_source_drafts WHERE draft=?")
    try {q.setString(1,draft);val r=q.executeQuery();val allowed=r.next() && !r.getBoolean(1)
      val head=c.prepareStatement("SELECT revoked FROM source_heads WHERE draft=?")
      try {head.setString(1,draft);val h=head.executeQuery();allowed && !(h.next() && h.getBoolean(1))} finally head.close()
    } finally q.close()
  }
  private def current(c:Connection,draft:String):Option[String]={
    val q=c.prepareStatement("SELECT locator FROM source_heads WHERE draft=? AND revoked=0")
    try {q.setString(1,draft);val r=q.executeQuery();if(r.next())Some(r.getString(1)) else None} finally q.close()
  }
  private def liveOperation(c:Connection,id:String,draft:String):Boolean={
    val q=c.prepareStatement("SELECT state FROM managed_source_ops WHERE id=? AND draft=?")
    try {q.setString(1,id);q.setString(2,draft);val r=q.executeQuery();permitted(c,draft) && r.next() && r.getString(1)=="prepared"} finally q.close()
  }
  def begin(opId:String,canonicalRequest:Array[Byte],draft:String,expected:Option[String]):Begin={
    identity(opId);identity(draft);expected.foreach(locator)
    require(canonicalRequest.length<=limits.maxObjectBytes,"managed request bound")
    val exact=store.managedRead {c=>
      val q=c.prepareStatement("SELECT COALESCE(SUM(length(request)),0) FROM managed_source_ops WHERE draft=? AND id<>?")
      try {q.setString(1,draft);q.setString(2,opId);val r=q.executeQuery();require(r.next())
        require(r.getLong(1)+canonicalRequest.length<=limits.maxStageBytes,"managed retained request budget")
        canonicalRequest.clone()
      } finally q.close()
    }
    afterBeginPreflight()
    store.managedWrite { c=>
      val query=c.prepareStatement("SELECT draft,request,expected,state FROM managed_source_ops WHERE id=?")
      val old=try {query.setString(1,opId);val r=query.executeQuery();if(r.next())Some((r.getString(1),r.getBytes(2),Option(r.getString(3)),r.getString(4))) else None} finally query.close()
      old match {
        case Some((_,_,_,"forgotten"))=>Unavailable
        case Some((owner,bytes,head,state))=>
          if(!permitted(c,owner)) Unavailable
          else if(owner!=draft || head!=expected || !java.util.Arrays.equals(bytes,exact)) IdentityMismatch
          else if(state=="committed") Replay(Receipt(opId))
          else if(state=="conflict") Replay(Receipt(opId,OperationStatus.Conflict))
          else if(state=="aborted") Replay(Receipt(opId,OperationStatus.Aborted))
          else if(state=="prepared") Fresh(new Stage(opId,draft)) else Unavailable
        case None=>
          val insert=c.prepareStatement("INSERT OR IGNORE INTO managed_source_drafts VALUES(?,0)")
          try {insert.setString(1,draft);insert.executeUpdate()} finally insert.close()
          val revoked=c.prepareStatement("SELECT revoked FROM source_heads WHERE draft=?")
          val denied=try {revoked.setString(1,draft);val r=revoked.executeQuery();r.next() && r.getBoolean(1)} finally revoked.close()
          if(!permitted(c,draft) || denied) Unavailable
          else {
            // Revalidate under the SAME transaction as INSERT; concurrent begins
            // may both have passed the allocation preflight before either inserts.
            val bytes=c.prepareStatement("SELECT COALESCE(SUM(length(request)),0) FROM managed_source_ops WHERE draft=?")
            val retained=try {bytes.setString(1,draft);val r=bytes.executeQuery();require(r.next());r.getLong(1)} finally bytes.close()
            require(retained+exact.length<=limits.maxStageBytes,"managed transactional request budget")
            val count=c.prepareStatement("SELECT COUNT(*) FROM managed_source_ops WHERE draft=?")
            val operations=try {count.setString(1,draft);val r=count.executeQuery();require(r.next());r.getLong(1)} finally count.close()
            require(operations<limits.maxOperations,"managed draft operation budget")
            val q=c.prepareStatement("INSERT INTO managed_source_ops VALUES(?,?,?,?,?,?)")
            try {q.setString(1,opId);q.setString(2,draft);q.setBytes(3,exact);q.setString(4,expected.orNull)
              q.setString(5,"prepared");q.setString(6,java.util.UUID.randomUUID().toString);q.executeUpdate()} finally q.close()
            Fresh(new Stage(opId,draft))
          }
      }
    }
  }
  private def forceDirectory(path:Path):Unit={val f=FileChannel.open(path,StandardOpenOption.READ);try f.force(true) finally f.close()}
  private def readObject(hash:String,size:Long,maxBytes:Long):Array[Byte]={
    locator(hash);require(size>=0 && size<=limits.maxObjectBytes && size<=maxBytes,"managed read bound")
    val path=objects.resolve(hash)
    require(Files.isRegularFile(path,nofollow) && Files.size(path)==size,"managed object shape")
    val in=Files.newInputStream(path,nofollow);val out=new java.io.ByteArrayOutputStream()
    try {val buffer=new Array[Byte](8192);var n=in.read(buffer)
      while(n != -1){require(out.size().toLong+n<=size,"managed object growth");out.write(buffer,0,n);n=in.read(buffer)}
      val bytes=out.toByteArray;require(bytes.length==size && WorkspaceStore.digest(bytes)==hash,"managed object integrity");bytes
    } finally in.close()
  }
  final class Stage private[ManagedSources](val operation:String,val draft:String) {
    def put(input:Array[Byte]):String={
      require(input.length<=limits.maxObjectBytes,"managed object bound")
      val bytes=store.managedRead {c=>
        require(liveOperation(c,operation,draft),"managed stage unavailable")
        val proposed=WorkspaceStore.digest(input)
        val q=c.prepareStatement("SELECT COUNT(*),COALESCE(SUM(size),0),COALESCE(MAX(CASE WHEN hash=? THEN 1 ELSE 0 END),0) FROM (SELECT m.hash,MAX(m.size) AS size FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op WHERE o.draft=? GROUP BY m.hash)")
        try {q.setString(1,proposed);q.setString(2,draft);val r=q.executeQuery();require(r.next())
          require(r.getInt(3)==1 || (r.getLong(1)<limits.maxObjects && r.getLong(2)+input.length<=limits.maxStageBytes),"managed preflight aggregate bound")
          input.clone()
        } finally q.close()
      }
      val hash=WorkspaceStore.digest(bytes)
      // Persist ownership intent BEFORE any content file/temp is created.
      val stageName=store.managedWrite {c=>
        require(liveOperation(c,operation,draft),"managed stage unavailable")
        val count=c.prepareStatement("SELECT COUNT(*),COALESCE(SUM(size),0) FROM managed_source_members WHERE op=?")
        val usage=try {count.setString(1,operation);val r=count.executeQuery();require(r.next());(r.getLong(1),r.getLong(2))} finally count.close()
        val old=c.prepareStatement("SELECT size FROM managed_source_members WHERE op=? AND hash=?")
        val existing=try {old.setString(1,operation);old.setString(2,hash);val r=old.executeQuery();if(r.next())Some(r.getLong(1)) else None} finally old.close()
        require(existing.forall(_==bytes.length),"managed hash size mismatch")
        if(existing.isEmpty){require(usage._1<limits.maxObjects && usage._2+bytes.length<=limits.maxStageBytes,"managed stage aggregate bound")
          val total=c.prepareStatement("SELECT COUNT(*),COALESCE(SUM(size),0),COALESCE(MAX(CASE WHEN hash=? THEN 1 ELSE 0 END),0) FROM (SELECT m.hash,MAX(m.size) AS size FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op WHERE o.draft=? GROUP BY m.hash)")
          val retained=try {total.setString(1,hash);total.setString(2,draft);val r=total.executeQuery();require(r.next());(r.getLong(1),r.getLong(2),r.getInt(3))} finally total.close()
          require(retained._3==1 || (retained._1<limits.maxObjects && retained._2+bytes.length<=limits.maxStageBytes),"managed retained draft budget")
          val q=c.prepareStatement("INSERT INTO managed_source_members VALUES(?,?,?,0)")
          try {q.setString(1,operation);q.setString(2,hash);q.setInt(3,bytes.length);q.executeUpdate()} finally q.close()}
        val q=c.prepareStatement("SELECT stage FROM managed_source_ops WHERE id=?")
        try {q.setString(1,operation);val r=q.executeQuery();require(r.next());r.getString(1)} finally q.close()
      }
      store.managedRead {c=>
        require(liveOperation(c,operation,draft),"managed stage retired before write")
        val directory=privateDirectory(stages.resolve(stageName))
        val destination=objects.resolve(hash)
        if(!Files.exists(destination,nofollow)){
          val temporary=Files.createTempFile(directory,"object-",".tmp")
          val f=FileChannel.open(temporary,StandardOpenOption.WRITE)
          try {val b=java.nio.ByteBuffer.wrap(bytes);while(b.hasRemaining)f.write(b);f.force(true)} finally f.close()
          Files.move(temporary,destination,StandardCopyOption.ATOMIC_MOVE);forceDirectory(objects)
        }
        readObject(hash,bytes.length,limits.maxObjectBytes)
        val q=c.prepareStatement("UPDATE managed_source_members SET written=1 WHERE op=? AND hash=?")
        try {q.setString(1,operation);q.setString(2,hash);q.executeUpdate()} finally q.close()
      }
      hash
    }
    def read(hash:String,maxBytes:Long):Array[Byte]=store.managedRead {c=>
      locator(hash);require(maxBytes>=0 && permitted(c,draft),"managed source unavailable")
      val q=c.prepareStatement("SELECT m.size FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op WHERE o.draft=? AND o.state IN ('prepared','committed') AND m.hash=? AND m.written=1 LIMIT 1")
      try {q.setString(1,draft);q.setString(2,hash);val r=q.executeQuery();require(r.next(),"unassociated managed object");readObject(hash,r.getLong(1),maxBytes)} finally q.close()
    }
    def commit(nextManifest:String,closure:Vector[String]):Commit={
      locator(nextManifest);require(closure.nonEmpty && closure.size<=limits.maxObjects && closure.distinct.size==closure.size && closure.contains(nextManifest),"managed closure bound")
      closure.foreach(locator)
      store.managedWrite {c=>
        if(!liveOperation(c,operation,draft)) CommitUnavailable else {
          val q=c.prepareStatement("SELECT expected FROM managed_source_ops WHERE id=?")
          val expected=try {q.setString(1,operation);val r=q.executeQuery();require(r.next());Option(r.getString(1))} finally q.close()
          if(current(c,draft)!=expected) {
            val conflict=c.prepareStatement("UPDATE managed_source_ops SET state='conflict' WHERE id=?")
            try {conflict.setString(1,operation);conflict.executeUpdate()} finally conflict.close()
            Conflict
          } else {
            closure.foreach(hash=>read(hash,limits.maxObjectBytes))
            val prior=c.prepareStatement("SELECT hash FROM managed_source_closures WHERE draft=? AND manifest=?")
            val priorClosure=try {prior.setString(1,draft);prior.setString(2,nextManifest);val r=prior.executeQuery();val b=Vector.newBuilder[String]
              while(r.next())b+=r.getString(1);b.result()} finally prior.close()
            if(priorClosure.nonEmpty) require(priorClosure.toSet==closure.toSet,"managed manifest closure cannot be rebound")
            else closure.foreach {hash=>
              val member=c.prepareStatement("INSERT INTO managed_source_closures VALUES(?,?,?)")
              try {member.setString(1,draft);member.setString(2,nextManifest);member.setString(3,hash);member.executeUpdate()} finally member.close()
            }
            val head=c.prepareStatement("INSERT INTO source_heads VALUES(?,?,0) ON CONFLICT(draft) DO UPDATE SET locator=excluded.locator")
            try {head.setString(1,draft);head.setString(2,nextManifest);head.executeUpdate()} finally head.close()
            val history=c.prepareStatement("INSERT INTO source_history(draft,locator,mode) VALUES(?,?,'managed_append')")
            try {history.setString(1,draft);history.setString(2,nextManifest);history.executeUpdate()} finally history.close()
            val done=c.prepareStatement("UPDATE managed_source_ops SET state='committed' WHERE id=?")
            try {done.setString(1,operation);done.executeUpdate()} finally done.close()
            sql(c,"UPDATE workspace SET revision=revision+1 WHERE singleton=1")
            Published(Receipt(operation))
          }
        }
      }
    }
    def conflict():Commit=store.managedWrite {c=>
      if(!liveOperation(c,operation,draft)) CommitUnavailable else {
        val q=c.prepareStatement("SELECT expected FROM managed_source_ops WHERE id=?")
        val expected=try {q.setString(1,operation);val r=q.executeQuery();require(r.next());Option(r.getString(1))} finally q.close()
        if(current(c,draft)==expected) CommitUnavailable else {
          val update=c.prepareStatement("UPDATE managed_source_ops SET state='conflict' WHERE id=?")
          try {update.setString(1,operation);update.executeUpdate()} finally update.close()
          Conflict
        }
      }
    }
    def abort():Unit=store.managedWrite {c=>
      val q=c.prepareStatement("UPDATE managed_source_ops SET state='aborted' WHERE id=? AND draft=? AND state='prepared'")
      try {q.setString(1,operation);q.setString(2,draft);q.executeUpdate()} finally q.close()
    }
  }
  final class ReadScope private[ManagedSources](private[ManagedSources] val draft:String,private[ManagedSources] val manifest:String,
    private[ManagedSources] val nativeLease:Option[WorkspaceStore.NativeBuildSourceLease]=None) {
    private[ManagedSources] var active=true
    def read(hash:String,maxBytes:Long):Array[Byte]={
      def access():Array[Byte]=store.managedRead {c=>
        require(active && permitted(c,draft) && (nativeLease.nonEmpty || current(c,draft).contains(manifest)),"managed read scope expired")
        locator(hash);require(maxBytes>=0)
        nativeLease match {
          case Some(lease)=>
            val q=c.prepareStatement("SELECT size FROM native_source_pins WHERE association=? AND hash=?")
            try {q.setString(1,lease.source.association.toString);q.setString(2,hash);val r=q.executeQuery();require(r.next(),"object outside owned native source closure");readObject(hash,r.getLong(1),maxBytes)} finally q.close()
          case None=>
            val q=c.prepareStatement("SELECT m.size FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op WHERE o.draft=? AND o.state='committed' AND m.hash=? AND m.written=1 AND EXISTS (SELECT 1 FROM managed_source_closures a WHERE a.draft=o.draft AND a.manifest=? AND a.hash=m.hash) LIMIT 1")
            try {q.setString(1,draft);q.setString(2,hash);q.setString(3,manifest);val r=q.executeQuery();require(r.next(),"unassociated current source object");readObject(hash,r.getLong(1),maxBytes)} finally q.close()
        }
      }
      nativeLease match {case Some(lease)=>lease.withRetained(access());case None=>access()}
    }
  }
  private[runtime] def registerCurrentResource(scope:ReadScope,owner:WorkspaceStore.ManagedResourceOwner):WorkspaceStore.ManagedResourceRegistration=store.managedRead {c=>
    require(scope.active && permitted(c,scope.draft) && current(c,scope.draft).contains(scope.manifest),"resource registration outside current source scope")
    store.registerManagedResource(scope.draft,scope.manifest,owner)
  }
  /** Fixed recovery consumer only: the lease was minted from an authenticated
    * committed native association and owns these original objects, not a hash hint. */
  private[veri7vn] def withNativeBuildSource[A](lease:WorkspaceStore.NativeBuildSourceLease)(consume:(String,ReadScope)=>A):A={
    require(lease.store eq store,"native source lease belongs to another workspace")
    lease.withRetained {
      val scope=new ReadScope(lease.source.draft,lease.source.manifest,Some(lease))
      try consume(lease.source.manifest,scope) finally scope.active=false
    }
  }
  private[runtime] def registerNativeSourceResource(scope:ReadScope,owner:WorkspaceStore.ManagedResourceOwner):WorkspaceStore.ManagedResourceRegistration={
    require(scope.active,"native source scope expired")
    store.registerNativeSourceResource(scope.nativeLease.getOrElse(throw new IllegalArgumentException("native source lease required")),owner)
  }
  /** Current managed package names only; an overflow is never presented as a complete list. */
  def listDrafts(limit:Int):Vector[String]={
    require(limit>0 && limit<=4096,"managed draft list bound")
    store.managedRead {c=>
      val query=c.prepareStatement("SELECT d.draft FROM managed_source_drafts d JOIN source_heads h ON h.draft=d.draft WHERE d.forgotten=0 AND h.revoked=0 ORDER BY d.draft LIMIT ?")
      try {
        query.setInt(1,limit+1)
        val rows=query.executeQuery();val result=Vector.newBuilder[String]
        while(rows.next())result+=rows.getString(1)
        val names=result.result()
        require(names.size<=limit,"managed draft listing exceeds requested limit")
        names
      } finally query.close()
    }
  }
  def withHead[A](draft:String)(materialize:(String,ReadScope)=>A):Option[A]=store.managedRead {c=>
    identity(draft)
    if(!permitted(c,draft)) None else current(c,draft).map {head=>
      val scope=new ReadScope(draft,head)
      try materialize(head,scope) finally scope.active=false
    }
  }
  /** Fixed maintenance consumer after native acknowledgement and cleanup barrier.
    * Queue rows remain until directory fsync confirms deletion or another actual
    * source owner still protects the shared object. */
  private[runtime] def eraseReleasedNativeSourceObjects():Unit={
    val batch=store.nativeSourceErasureBatch
    store.managedRead {c=>batch.foreach {(hash,size)=>
      locator(hash);require(size>=0 && size<=limits.maxObjectBytes,"native source erasure size")
      val q=c.prepareStatement("SELECT 1 FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op JOIN managed_source_drafts d ON d.draft=o.draft WHERE m.hash=? AND d.forgotten=0 LIMIT 1")
      val shared=try {q.setString(1,hash);q.executeQuery().next()} finally q.close()
      if(!shared && !store.nativeSourcePinned(hash)){
        val path=objects.resolve(hash)
        if(Files.exists(path,nofollow)){
          require(Files.isRegularFile(path,nofollow) && Files.size(path)==size,"native source erasure object shape")
          Files.delete(path)
        }
      }
    };if(batch.nonEmpty)forceDirectory(objects)}
    batch.foreach((hash,_)=>store.nativeSourceObjectErased(hash))
  }
  /** Source-association erasure only. Native-owned pinned objects remain denied
    * and queued until their real native cleanup barrier; caller must join native
    * release before claiming full deletion. */
  def forget(draft:String):StorageErased={
    identity(draft)
    // Keep ownership rows until physical cleanup finishes so interruption is retryable.
    val owned=store.managedWrite {c=>
      val draftRow=c.prepareStatement("INSERT INTO managed_source_drafts VALUES(?,1) ON CONFLICT(draft) DO UPDATE SET forgotten=1")
      try {draftRow.setString(1,draft);draftRow.executeUpdate()} finally draftRow.close()
      store.retireNativeBuildSources(draft)
      val q=c.prepareStatement("SELECT DISTINCT m.hash FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op WHERE o.draft=?")
      val hashes=try {q.setString(1,draft);val r=q.executeQuery();val b=Vector.newBuilder[String];while(r.next())b+=r.getString(1);b.result()} finally q.close()
      val stageQuery=c.prepareStatement("SELECT stage FROM managed_source_ops WHERE draft=?")
      val directories=try {stageQuery.setString(1,draft);val r=stageQuery.executeQuery();val b=Vector.newBuilder[String];while(r.next()){val name=r.getString(1);if(name.nonEmpty)b+=name};b.result()} finally stageQuery.close()
      val ops=c.prepareStatement("UPDATE managed_source_ops SET state='forgotten',request=NULL,expected=NULL WHERE draft=?")
      try {ops.setString(1,draft);ops.executeUpdate()} finally ops.close()
      val head=c.prepareStatement("UPDATE source_heads SET revoked=1,locator='' WHERE draft=?")
      try {head.setString(1,draft);head.executeUpdate()} finally head.close()
      val closures=c.prepareStatement("DELETE FROM managed_source_closures WHERE draft=?")
      try {closures.setString(1,draft);closures.executeUpdate()} finally closures.close()
      val history=c.prepareStatement("DELETE FROM source_history WHERE draft=?")
      try {history.setString(1,draft);history.executeUpdate()} finally history.close()
      (hashes,directories)
    }
    // Access denial committed above. Signal under the source lock, then join and
    // clear derivatives outside it; failed cleanup remains registered for retry.
    val resources=store.invalidateManagedResources(draft)
    resources.foreach(_.release())
    store.requireNoOrphanResources(draft)
    store.managedRead {c=>
      owned._1.foreach {hash=>
        locator(hash)
        val q=c.prepareStatement("SELECT COUNT(*) FROM managed_source_members m JOIN managed_source_ops o ON o.id=m.op JOIN managed_source_drafts d ON d.draft=o.draft WHERE m.hash=? AND d.forgotten=0")
        val shared=try {q.setString(1,hash);val r=q.executeQuery();require(r.next());r.getLong(1)>0} finally q.close()
        if(!shared && !store.nativeSourcePinned(hash)) Files.deleteIfExists(objects.resolve(hash))
      }
      owned._2.foreach {name=>
        require(name.matches("[0-9a-f-]{36}"),"managed stage directory identity")
        val directory=stages.resolve(name)
        if(Files.exists(directory,nofollow)) {
          require(Files.isDirectory(directory,nofollow),"managed stage shape")
          val children=Files.list(directory)
          try children.forEach(path=>{require(!Files.isDirectory(path,nofollow),"unexpected managed stage subtree");Files.deleteIfExists(path)}) finally children.close()
          Files.deleteIfExists(directory)
        }
      }
      forceDirectory(objects);forceDirectory(stages)
    }
    store.managedWrite {c=>
      val q=c.prepareStatement("DELETE FROM managed_source_members WHERE op IN (SELECT id FROM managed_source_ops WHERE draft=?)")
      try {q.setString(1,draft);q.executeUpdate()} finally q.close()
      val clean=c.prepareStatement("UPDATE managed_source_ops SET stage='' WHERE draft=?")
      try {clean.setString(1,draft);clean.executeUpdate()} finally clean.close()
    }
    store.managedRead {c=>
      val q=c.createStatement()
      try {val r=q.executeQuery("PRAGMA wal_checkpoint(TRUNCATE)");require(r.next() && r.getInt(1)==0,"managed erasure WAL cleanup incomplete")} finally q.close()
    }
    StorageErased(draft)
  }
}
