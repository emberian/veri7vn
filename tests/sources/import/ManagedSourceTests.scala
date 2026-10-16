package veri7vn.sources
import scala.language.unsafeNulls
import java.nio.file.Files
import java.sql.DriverManager
import veri7vn.runtime.host.{ManagedSources,WorkspaceStore}
object ManagedSourceTests {
  import LocalSnapshot.*
  def main(args:Array[String]):Unit={
    Class.forName("org.sqlite.JDBC")
    val dir=Files.createTempDirectory("veri7vn-managed-jdbc-")
    val store=new WorkspaceStore(dir.resolve("workspace"))
    try {
      val database=dir.resolve("input.sqlite")
      val c=DriverManager.getConnection("jdbc:sqlite:"+database)
      try {val s=c.createStatement();try {
        s.execute("CREATE TABLE readings(value TEXT)")
        val p=c.prepareStatement("INSERT INTO readings VALUES(?)")
        try {p.setString(1,(0 until 600).map(i=>f"$i%08d"+("x"*120)).mkString);p.executeUpdate()}finally p.close()
      }finally s.close()}finally c.close()
      val m=Manifest("managed-jdbc-fixture",None,"source-row/2","UTF-8","ordered rows",
        "sqlite-observation/1",Some("CC0 fixture"),None,Vector.empty,None,None,
        Vector("fixture:managed"),Vector.empty,
        Acquisition(None,Clock("wall","UTC",100),None,BigInt(1),"fixture",None,"retain",Origin.Unknown),Retention.Private)
      // Real Stage rejects growth after owned chunks, rather than an untracked fake sink.
      val managed=new ManagedSources(store,ManagedSources.Limits(maxObjectBytes=256,maxStageBytes=512))
      val stage=managed.begin("failing-observation","fixture request".getBytes,"fixture-draft",None) match {
        case ManagedSources.Fresh(value)=>value
        case _=>sys.error("fixture Stage unavailable")
      }
      val output=ChunkedSnapshot.chunkOutput(m,new ManagedChunkObjects(stage),ChunkedSnapshot.Limits(chunkBytes=128))
      var failed=false
      try SqliteObservation.observeLocal(database,"readings",Vector("value"),output)
      catch {case _:Exception=>failed=true}
      require(failed,"real bounded Stage failure was not exercised")
      val candidate=output.finishProduced() match {
        case ChunkedSnapshot.Incomplete(_,value)=>value
        case _=>sys.error("failed JDBC prefix became complete wire")
      }
      require(!candidate.isComplete && candidate.payloadId.isEmpty && candidate.chunks.size==5 && candidate.size==640)
      val intended=candidate.chunks
      require(intended.map(_.objectId).distinct.size==5)
      intended.take(4).foreach(span=>require(stage.read(span.objectId,span.size.toLong).length==128))
      var uninstalled=false;try stage.read(intended.last.objectId,128)catch {case _:Exception=>uninstalled=true}
      require(uninstalled,"failed Stage member was installed beyond budget")
      stage.abort();managed.forget("fixture-draft")
      intended.foreach(span=>{
        var denied=false;try stage.read(span.objectId,span.size.toLong) catch {case _:Exception=>denied=true}
        require(denied,"forgotten Stage exposed source bytes")
      })
      output.release();require(!candidate.isLive)
      println("VERI7VN_MANAGED_SOURCE Scala regressions PASS")
    }finally {
      store.close()
      val paths=Files.walk(dir)
      try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()
    }
  }
}
