package veri7vn.sources
import scala.language.unsafeNulls
import java.nio.file.Files
object ChunkedSnapshotTests {
  import LocalSnapshot.*
  def main(args: Array[String]): Unit = {
    val m=Manifest("deterministic-long-fixture",None,"opaque-source-bytes","UTF-8",
      "whole captured file","inert-local-stream",Some("CC0 fixture"),None,Vector.empty,None,None,
      Vector("fixture:long"),Vector.empty,
      Acquisition(None,Clock("wall","UTC",100),None,BigInt(1),"fixture",None,"retain",Origin.Unknown),Retention.Private)
    // More than 255 rows and a 64,353-byte value, without inspecting original corpora.
    val bytes=("x"*64353+"\n"+("duplicate\n"*4096)).getBytes(java.nio.charset.StandardCharsets.UTF_8)
    val dir=Files.createTempDirectory("veri7vn-chunks-");val path=dir.resolve("fixture")
    val objects=scala.collection.mutable.Map.empty[String,Array[Byte]]
    val sink=new ChunkedSnapshot.Objects {
      def put(id:String,b:Array[Byte],r:Retention):Unit={
        require(r==Retention.Private && hash(b)==id);objects(id)=b.clone()
      }
    }
    try {
      Files.write(path,bytes)
      val result=ChunkedSnapshot.capture(path,m,sink,ChunkedSnapshot.Limits(chunkBytes=257))
      val c=result match {case ChunkedSnapshot.Captured(c)=>c;case _=>sys.error("full capture failed")}
      require(c.isComplete && c.size==bytes.length && c.payloadId==Some(hash(bytes)))
      require(c.chunks.size>255 && c.chunks.head.offset==0)
      require(c.chunks.sliding(2).forall(xs=>xs.size<2 || xs(0).offset+xs(0).size==xs(1).offset))
      require(c.chunks.flatMap(s=>objects(s.objectId)).toArray.sameElements(bytes),"ordered lossless chunk capture")
      require(c.indexBytes.sameElements(c.indexBytes),"deterministic manifest")
      val incomplete=ChunkedSnapshot.capture(path,m,sink,ChunkedSnapshot.Limits(chunkBytes=257,maxChunks=2))
      incomplete match {
        case ChunkedSnapshot.Incomplete("source.acquisition_budget",p)=>
          require(!p.isComplete && p.payloadId.isEmpty && p.chunks.size==2);p.release()
        case _=>sys.error("prefix was incorrectly promoted")
      }
      val failure=new ChunkedSnapshot.Objects {def put(id:String,b:Array[Byte],r:Retention):Unit=throw new java.io.IOException("fixture")}
      ChunkedSnapshot.capture(path,m,failure,ChunkedSnapshot.Limits(chunkBytes=257)) match {
        case ChunkedSnapshot.Incomplete("source.acquisition_failure",p)=>
          require(!p.isComplete && p.chunks.size==1,"uncertain write locator retained for host reconciliation");p.release()
        case _=>sys.error("failed store incorrectly promoted")
      }
      c.release();require(!c.isLive)
      var stale=false;try c.indexBytes catch {case _:IllegalStateException=>stale=true};require(stale)
      println("VERI7VN_SOURCE_CHUNKS Scala regressions PASS")
    } finally {Files.deleteIfExists(path);Files.deleteIfExists(dir)}
  }
}
