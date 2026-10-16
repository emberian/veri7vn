package veri7vn.runtime.host

import scala.language.unsafeNulls
import isabelle.{SQLite, Path => IPath}
import java.nio.file.{Files, Path, LinkOption, StandardOpenOption}
import java.nio.channels.{FileChannel, FileLock}
import java.nio.file.attribute.PosixFilePermissions
import java.security.MessageDigest
import scala.jdk.CollectionConverters.*

/** Closed-store probe copy. The original database is never opened or recovered here. */
object WorkspaceSnapshot {
  final case class Limits(maxFiles:Int=100000,maxBytes:Long=8L*1024*1024*1024,maxDepth:Int=64) {
    require(maxFiles>0 && maxBytes>0 && maxDepth>0 && maxDepth<Int.MaxValue,"positive snapshot limits required")
  }
  final class Lease private[WorkspaceSnapshot](val source:Path,val snapshot:Path,
      val inventory:String,val files:Int,val bytes:Long,channel:FileChannel,lock:FileLock)
      extends AutoCloseable {
    def close():Unit=try lock.release() finally channel.close()
  }
  def acquireClosed(sourcePath:Path,destination:Path,limits:Limits=Limits()):Lease={
    val source=sourcePath.toAbsolutePath.normalize()
    val target=destination.toAbsolutePath.normalize()
    require(Files.isDirectory(source,LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(source),"snapshot source directory required")
    require(source.toRealPath()==source,"snapshot source must be canonical")
    require(!target.startsWith(source) && !source.startsWith(target),"snapshot directories must be disjoint")
    require(target.getParent.toRealPath()==target.getParent,"snapshot parent must be canonical")
    require(!Files.exists(target,LinkOption.NOFOLLOW_LINKS),"snapshot destination already exists")
    val lockPath=source.resolve("writer.lock")
    require(Files.isRegularFile(lockPath,LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(lockPath),"existing writer lock required")
    val channel=FileChannel.open(lockPath,StandardOpenOption.WRITE)
    var lock:FileLock=null
    try {
      lock=channel.tryLock();require(lock!=null,"workspace writer already active")
      Files.createDirectory(target,PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------")))
      val walk=Files.walk(source,limits.maxDepth+1)
      val entries=try {
        val iterator=walk.iterator().asScala
        val bounded=scala.collection.mutable.ArrayBuffer.empty[Path]
        while(iterator.hasNext){
          require(bounded.size<limits.maxFiles,"snapshot file limit")
          bounded+=iterator.next()
        }
        bounded.toVector.sortBy(p=>source.relativize(p).toString)
      } finally walk.close()
      val digest=MessageDigest.getInstance("SHA-256")
      var count=0;var total=0L
      entries.filterNot(_==source).foreach { path=>
        val relative=source.relativize(path)
        require(relative.getNameCount<=limits.maxDepth && !Files.isSymbolicLink(path),"unsafe snapshot member")
        if(relative.toString!="writer.lock") {
          val out=target.resolve(relative)
          if(Files.isDirectory(path,LinkOption.NOFOLLOW_LINKS))
            Files.createDirectory(out,PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------")))
          else {
            require(Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS),"nonregular snapshot member")
            val size=Files.size(path);require(size<=limits.maxBytes-total,"snapshot byte limit")
            Files.copy(path,out);Files.setPosixFilePermissions(out,PosixFilePermissions.fromString("rw-------"))
            val fileHash=MessageDigest.getInstance("SHA-256")
            val in=Files.newInputStream(out)
            try {val buffer=new Array[Byte](65536);var n=in.read(buffer);while(n>=0){if(n>0)fileHash.update(buffer,0,n);n=in.read(buffer)}} finally in.close()
            val row=relative.toString+"\u0000"+size+"\u0000"+fileHash.digest().map(b=>f"${b & 255}%02x").mkString+"\n"
            digest.update(row.getBytes(java.nio.charset.StandardCharsets.UTF_8))
            val sync=FileChannel.open(out,StandardOpenOption.WRITE);try sync.force(true) finally sync.close()
            total+=size;count+=1
          }
        }
      }
      require(Files.isRegularFile(target.resolve("journal.db")),"snapshot database missing")
      // WAL recovery affects only the clone; original PID/path records must never be replayed.
      val db=SQLite.open_database(IPath.explode(target.resolve("journal.db").toString))
      try List("native_residents","managed_resource_regions","managed_resource_paths").foreach {table=>
        val q=db.connection.createStatement()
        try {val r=q.executeQuery("SELECT COUNT(*) FROM "+table);require(r.next() && r.getLong(1)==0,"snapshot requires owner-free store: "+table)} finally q.close()
      } finally db.close()
      val sync=FileChannel.open(target,StandardOpenOption.READ);try sync.force(true) finally sync.close()
      new Lease(source,target,digest.digest().map(b=>f"${b & 255}%02x").mkString,count,total,channel,lock)
    } catch {case problem:Throwable=>if(lock!=null && lock.isValid)lock.release();channel.close();throw problem}
  }
  private def json(s:String):String="\""+s.flatMap {case '"'=>"\\\"";case '\\'=>"\\\\";case c if c<' '=>f"\\u${c.toInt}%04x";case c=>c.toString}+"\""
  def main(args:Array[String]):Unit={
    require(args.length==2,"WorkspaceSnapshot SOURCE SNAPSHOT")
    val lease=acquireClosed(Path.of(args(0)),Path.of(args(1)))
    try {
      println("{\"status\":\"ready\",\"schema\":1,\"owner_free\":true,\"source\":"+json(lease.source.toString)+",\"snapshot\":"+json(lease.snapshot.toString)+",\"source_inventory_sha256\":"+json(lease.inventory)+",\"files\":"+lease.files+",\"bytes\":"+lease.bytes+"}")
      System.out.flush()
      while(System.in.read()!= -1) ()
    } finally lease.close()
  }
}
