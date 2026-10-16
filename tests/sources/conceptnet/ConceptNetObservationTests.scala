package veri7vn.sources.conceptnet
import scala.language.unsafeNulls
import java.io.{ByteArrayOutputStream,DataOutputStream}
import java.nio.file.{Path,Files}
import java.sql.DriverManager
import veri7vn.sources.SqliteObservation
object ConceptNetObservationTests {
  def main(args:Array[String]):Unit={
    val path=Path.of("upstream/root/fable-content/oracle-m-series-2026-08-15/m13e5_conceptnet_build_a_v1/conceptnet_specialist.sqlite3")
    require(Files.isRegularFile(path),"original ConceptNet corpus unavailable")
    // Independent JDBC framing oracle, not the production importer/materializer.
    def oracle(sql:String,bindings:Vector[String],count:Int):Array[Byte]={
      val expected=new ByteArrayOutputStream();val out=new DataOutputStream(expected)
      out.writeByte(83);out.writeByte(50);out.writeInt(8)
      val c=DriverManager.getConnection("jdbc:sqlite:"+path.toAbsolutePath.toUri.toASCIIString+"?mode=ro")
      try {
        val s=c.prepareStatement(sql)
        try {
          bindings.zipWithIndex.foreach((value,index)=>s.setString(index+1,value))
          val r=s.executeQuery();var rows=0
          try {while(r.next()){
            rows+=1;out.writeByte(82)
            (1 to 8).foreach { i=>
              if(i==6){out.writeByte(4);out.writeLong(java.lang.Double.doubleToRawLongBits(r.getDouble(i)))}
              else {val b=r.getBytes(i);if(b==null)out.writeByte(0) else {out.writeByte(2);out.writeInt(b.length);out.write(b)}}
            }
          }} finally r.close()
          require(rows==count)
        } finally s.close()
      } finally c.close()
      out.writeByte(69);out.writeByte(0);out.writeLong(count);out.flush();expected.toByteArray
    }
    val actual=new ByteArrayOutputStream()
    val report=ConceptNetObservation.observe(path,actual,SqliteObservation.Limits(maxRows=257))
    require(report.rows==257 && !report.cursorEOF && report.disposition=="source.row_budget")
    require(report.columns.map(_.name)==ConceptNetObservation.columns)
    val prefix=oracle("SELECT rel,start,start_pos,end,end_pos,weight,surface_text,dataset FROM edge ORDER BY rel,start,end,weight,start_pos,end_pos,surface_text,dataset LIMIT 257",Vector.empty,257)
    require(actual.toByteArray.sameElements(prefix),"original corpus typed cells/order/prefix metadata changed")
    val selected=new ByteArrayOutputStream()
    val view=ConceptNetObservation.observeChainView(path,"robin","bird","meat",selected)
    require(view.rows==45 && !view.cursorEOF && view.disposition=="source.row_budget")
    require(view.alternatives.size==2 && view.bindings.size==4)
    require(view.selectionPolicy.nonEmpty && view.limits.maxRows==45)
    val expectedView=oracle("SELECT rel,start,start_pos,end,end_pos,weight,surface_text,dataset FROM edge WHERE rel=? AND ((start=? AND end=?) OR (end=?)) ORDER BY end,start,weight,start_pos,end_pos,surface_text,dataset,rel LIMIT 45",Vector("IsA","robin","bird","meat"),45)
    require(selected.toByteArray.sameElements(expectedView),"selected ConceptNet original rows changed")
    // Producer output is consumed by the queued native /2 materializer test.
    Files.write(Path.of("tests/sources/conceptnet/ConceptNet_Original.wire"),selected.toByteArray)
    Files.writeString(Path.of("tests/sources/conceptnet/ConceptNet_Original.selection"),view.selectionPolicy)
    println("VERI7VN_CONCEPTNET actual corpus257row prefix +45row typedDNF selected view exact /2 bytes PASS")
  }
}
