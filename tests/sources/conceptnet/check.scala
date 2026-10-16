import scala.language.unsafeNulls
import java.nio.file.Files
@main def conceptNetCheck():Unit={
 val out=Files.createTempDirectory("veri7vn-conceptnet-classes-")
 try {
  val paths=List("src/sources/import/SqliteObservation.scala","src/sources/conceptnet/ConceptNetObservation.scala","tests/sources/conceptnet/ConceptNetObservationTests.scala")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray).hasErrors)
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  try loader.loadClass("veri7vn.sources.conceptnet.ConceptNetObservationTests").getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object]) finally loader.close()
 } finally {val paths=Files.walk(out);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p)) finally paths.close()}
}
