package veri7vn.sources
import scala.language.unsafeNulls
import java.io.ByteArrayOutputStream
import java.nio.file.Files
import java.sql.DriverManager
object SqliteObservationTests {
  def main(args:Array[String]):Unit={
    Class.forName("org.sqlite.JDBC")
    val dir=Files.createTempDirectory("veri7vn-sqlite-observation-");val file=dir.resolve("fixture.sqlite")
    try {
      val c=DriverManager.getConnection("jdbc:sqlite:"+file)
      try {
        val s=c.createStatement()
        try {s.execute("CREATE TABLE facts(id INTEGER PRIMARY KEY,mixed,text_value TEXT,blob_value BLOB)")
          s.execute("CREATE TABLE dupes(value)");s.execute("INSERT INTO dupes VALUES(NULL),(NULL)")
        } finally s.close()
        val insert=c.prepareStatement("INSERT INTO facts(mixed,text_value,blob_value) VALUES(?,?,?)")
        try {var n=0;while(n<258){
          n%5 match {
            case 0=>insert.setLong(1,-15)
            case 1=>insert.setDouble(1,0.1)
            case 2=>insert.setNull(1,java.sql.Types.NULL)
            case 3=>insert.setBytes(1,Array(0.toByte,255.toByte))
            case _=>insert.setString(1,"")
          }
          insert.setString(2,if(n==0)("é"*32176)+"x" else "duplicate")
          insert.setBytes(3,Array.emptyByteArray);insert.executeUpdate();n+=1
        }} finally insert.close()
      } finally c.close()
      val out=new ByteArrayOutputStream()
      val full=SqliteObservation.observeLocal(file,"facts",Vector("id"),out,includeRowid=true)
      require(full.rows==258 && full.cursorEOF && full.columns.size==5 && full.columns.head.synthetic)
      require(full.databaseEncoding=="UTF-8" && full.engineVersion.nonEmpty && full.driverVersion.nonEmpty)
      require(full.sql.contains("typeof(") && full.sql.contains("CAST("),"extraction policy retained")
      val raw=out.toByteArray
      require(raw.take(6).sameElements(Array[Byte](83,50,0,0,0,5)))
      require(raw(raw.length-9)==1,"full query observation footer")
      // Independent exact framing oracle for actual JDBC values, not just row counts.
      def u32(n:Int):Vector[Byte]=Vector((n>>>24).toByte,(n>>>16).toByte,(n>>>8).toByte,n.toByte)
      def integer(negative:Boolean,magnitude:Int):Vector[Byte]=
        Vector[Byte](1,if(negative)1 else 0)++u32(1)++Vector(magnitude.toByte)
      def text(bytes:Vector[Byte]):Vector[Byte]=Vector[Byte](2)++u32(bytes.size)++bytes
      def blob(bytes:Vector[Byte]):Vector[Byte]=Vector[Byte](3)++u32(bytes.size)++bytes
      val longText=Vector.fill(32176)(Vector(195.toByte,169.toByte)).flatten:+120.toByte
      require(longText.size==64353)
      val ordinary="duplicate".getBytes(java.nio.charset.StandardCharsets.UTF_8).toVector
      val mixed=Vector(integer(true,15),Vector[Byte](4,63,185.toByte,153.toByte,153.toByte,
        153.toByte,153.toByte,153.toByte,154.toByte),Vector[Byte](0),blob(Vector[Byte](0,255.toByte)),text(Vector.empty))
      val firstFive=(0 until 5).flatMap(i=>Vector[Byte](82)++integer(false,i+1)++integer(false,i+1)++
        mixed(i)++text(if(i==0)longText else ordinary)++blob(Vector.empty)).toVector
      val expected=Vector[Byte](83,50)++u32(5)++firstFive
      require(raw.take(expected.size).toVector==expected,
        "exact JDBC integer/REALbits/NULL/TEXT/BLOB/order preservation failed")
      // Compare the long UTF8 field even when a fixed chunk boundary splits a code point.
      val chunked=raw.grouped(257).toVector
      require(chunked.flatten.toVector.take(expected.size)==expected && chunked.size>255,
        "long UTF8 observation bytes changed across chunk boundaries")
      val prefix=new ByteArrayOutputStream()
      val partial=SqliteObservation.observeLocal(file,"facts",Vector("id"),prefix,SqliteObservation.Limits(maxRows=1))
      require(partial.rows==1 && !partial.cursorEOF && prefix.toByteArray.apply(prefix.size()-9)==0)
      val selectedBytes=new ByteArrayOutputStream()
      val selected=SqliteObservation.observeLocal(file,"facts",Vector("id"),selectedBytes,
        includeRowid=true,selection=Vector(SqliteObservation.IntegerEquals("id",2)))
      require(selected.rows==1 && selected.cursorEOF && selected.bindings==Vector(SqliteObservation.IntegerEquals("id",2)))
      require(selected.sql.contains("WHERE \"id\" = ?"),"selection SQL must retain placeholders")
      val secondRow=Vector[Byte](82)++integer(false,2)++integer(false,2)++mixed(1)++text(ordinary)++blob(Vector.empty)
      require(selectedBytes.toByteArray.drop(6).take(secondRow.size).toVector==secondRow,
        "selected original typed row changed")
      var rejected=false
      try SqliteObservation.observeLocal(file,"facts",Vector("id"),new ByteArrayOutputStream(),
        selection=Vector(SqliteObservation.IntegerEquals("id\" OR 1=1 --",2)))
      catch {case _:IllegalArgumentException=>rejected=true}
      require(rejected,"undeclared selection column accepted")
      val dnfBytes=new ByteArrayOutputStream()
      val groups=Vector(Vector(SqliteObservation.IntegerEquals("id",2)),Vector(SqliteObservation.IntegerEquals("id",3)))
      val dnf=SqliteObservation.observeLocal(file,"facts",Vector("id"),dnfBytes,
        selection=Vector(SqliteObservation.TextEquals("text_value","duplicate")),
        alternatives=groups,descending=Vector("id"))
      require(dnf.rows==2 && dnf.cursorEOF && dnf.alternatives==groups && dnf.descending==Vector("id"))
      require(dnf.sql.contains(" OR ") && dnf.sql.endsWith("\"id\" DESC"))
      val firstDnf=Vector[Byte](82)++integer(false,3)++mixed(2)++text(ordinary)++blob(Vector.empty)
      require(dnfBytes.toByteArray.drop(6).take(firstDnf.size).toVector==firstDnf,"DNF direction or typed binding changed")
      val noInjection=SqliteObservation.observeLocal(file,"facts",Vector("id"),new ByteArrayOutputStream(),
        selection=Vector(SqliteObservation.TextEquals("text_value","duplicate' OR 1=1 --")))
      require(noInjection.rows==0 && noInjection.cursorEOF,"text equality became query syntax")
      val duplicate=new ByteArrayOutputStream()
      val dupeReport=SqliteObservation.observeLocal(file,"dupes",Vector("value"),duplicate)
      require(dupeReport.rows==2 && dupeReport.cursorEOF)
      require(duplicate.toByteArray.drop(6).take(4).sameElements(Array[Byte](82,0,82,0)),"duplicate NULL rows retained")
      println("VERI7VN_SQLITE_OBSERVATION Scala regressions PASS")
    } finally {
      val paths=Files.walk(dir)
      try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p)) finally paths.close()
    }
  }
}
