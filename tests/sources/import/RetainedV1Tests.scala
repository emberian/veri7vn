package veri7vn.sources
import scala.language.unsafeNulls
import java.io.ByteArrayOutputStream
import java.nio.file.{Files,Path}

/** Local retained original only. Query EOF describes SQLite's selected result;
  * it is not v2 parity, extraction correctness or world-level completeness. */
object RetainedV1Tests {
  def main(args:Array[String]):Unit={
    val path=Path.of("upstream/root/relstore/relations_v1.sqlite3")
    val out=new ByteArrayOutputStream()
    val report=SqliteObservation.observeLocal(path,"fact",Vector("s","p","o","lit"),out,
      selection=Vector(SqliteObservation.IntegerEquals("s",170583),SqliteObservation.IntegerEquals("p",50)))
    require(report.columns.map(_.name)==Vector("s","p","o","lit"),"original schema drift")
    require(report.rows==1 && report.cursorEOF,"retained v1 selected rows changed")
    def integer(n:Long):Vector[Byte]={
      val raw=BigInt(n).toByteArray.toVector.dropWhile(_==0)
      Vector[Byte](1,0,0,0,0,raw.size.toByte)++raw
    }
    val expected=Vector[Byte](83,50,0,0,0,4,82)++integer(170583)++integer(50)++integer(36322)++
      Vector[Byte](0,69,1,0,0,0,0,0,0,0,1)
    require(out.toByteArray.toVector==expected,"original v1 selected typed bytes changed")
    val labels=new ByteArrayOutputStream()
    val labelReport=SqliteObservation.observeLocal(path,"entity",Vector("qid"),labels,
      selection=Vector(SqliteObservation.IntegerEquals("qid",170583)))
    require(labelReport.columns.map(_.name)==Vector("qid","label","enwiki") && labelReport.rows==1 && labelReport.cursorEOF)
    val label="Pride and Prejudice".getBytes(java.nio.charset.StandardCharsets.UTF_8).toVector
    val expectedLabel=Vector[Byte](83,50,0,0,0,3,82)++integer(170583)++
      Vector[Byte](2,0,0,0,label.size.toByte)++label++Vector[Byte](2,0,0,0,label.size.toByte)++label++Vector[Byte](69,1,0,0,0,0,0,0,0,1)
    require(labels.toByteArray.toVector==expectedLabel,"original v1 entity label changed")
    import LocalSnapshot.*
    val manifest=Manifest("retained-relations-v1",Some("v1"),"source-row/2","UTF-8",
      "fact WHERE s=170583 AND p=50 ORDER BY s,p,o,lit","source-row-codec/2",
      None,None,Vector("selected-query-result"),None,None,
      Vector("upstream/root/relstore/relations_v1.sqlite3"),
      Vector("original acquisition/license/provenance unknown","v1 is not v2 parity","no world completeness"),
      Acquisition(None,Clock("fixture-capture","retained-v1-test",0),None,BigInt(1),
        "sqlite-fact-v1",None,"retain-sqlite-dynamic-classes",Origin.Unknown),Retention.Private)
    val candidate=prepare(out.toByteArray,manifest)
    if(args.nonEmpty) {
      val destination=Path.of(args(0));Files.createDirectories(destination)
      Files.write(destination.resolve("retained-v1-source-row2.bin"),candidate.bytes)
      Files.write(destination.resolve("retained-v1-manifest2.bin"),candidate.manifestBytes)
    }
    candidate.release()
    println("VERI7VN_RETAINED_V1 original selected typed wire PASS; upstream provenance/license unknown; no world adoption")
  }
}
