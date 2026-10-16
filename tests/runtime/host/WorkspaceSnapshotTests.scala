package veri7vn.runtime.host
import scala.language.unsafeNulls
import java.nio.file.Files
object WorkspaceSnapshotTests {
  def main(args:Array[String]):Unit={
    val base=Files.createTempDirectory("snapshot-check-").toRealPath()
    val source=base.resolve("store")
    val store=new WorkspaceStore(source)
    def rejects(body: => Any):Unit={var denied=false;try body catch {case _:Exception=>denied=true};assert(denied)}
    rejects(WorkspaceSnapshot.acquireClosed(source,base.resolve("active")))
    store.close()
    rejects(WorkspaceSnapshot.Limits(maxFiles=0))
    rejects(WorkspaceSnapshot.Limits(maxDepth=Int.MaxValue))
    val many=Files.createDirectory(source.resolve("many"))
    for(i<-0 until 20)Files.write(many.resolve(i.toString),Array[Byte](1))
    rejects(WorkspaceSnapshot.acquireClosed(source,base.resolve("oversized"),WorkspaceSnapshot.Limits(maxFiles=8)))
    assert(!Files.exists(base.resolve("oversized").resolve("journal.db")))
    for(i<-0 until 20)Files.delete(many.resolve(i.toString))
    Files.delete(many)
    val original=Files.readAllBytes(source.resolve("journal.db"))
    val lease=WorkspaceSnapshot.acquireClosed(source,base.resolve("copy"))
    try {
      assert(lease.files>0 && lease.inventory.length==64)
      assert(Files.readAllBytes(source.resolve("journal.db")).sameElements(original))
      rejects(new WorkspaceStore(source))
      val clone=new WorkspaceStore(lease.snapshot);clone.close()
    } finally lease.close()
    val reopened=new WorkspaceStore(source);reopened.close()
    Files.createSymbolicLink(source.resolve("unsafe"),source.resolve("journal.db"))
    rejects(WorkspaceSnapshot.acquireClosed(source,base.resolve("unsafe-copy")))
    Files.delete(source.resolve("unsafe"))
    val db=isabelle.SQLite.open_database(isabelle.Path.explode(source.resolve("journal.db").toString))
    try {val q=db.connection.createStatement();try q.executeUpdate("INSERT INTO native_residents VALUES('orphan',1,'x',1,'x')") finally q.close()} finally db.close()
    rejects(WorkspaceSnapshot.acquireClosed(source,base.resolve("orphan-copy")))
    println("WORKSPACE_SNAPSHOT_PASS")
  }
}
