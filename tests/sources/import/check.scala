import scala.language.unsafeNulls
import java.nio.file.Files
@main def sourceImportCheck(): Unit = {
  val out=Files.createTempDirectory("veri7vn-source-import-classes-")
  try {
    val paths=List("src/sources/import/LocalSnapshot.scala","src/sources/import/ChunkedSnapshot.scala","src/sources/import/SqliteObservation.scala","tests/sources/import/LocalSnapshotTests.scala","tests/sources/import/ChunkedSnapshotTests.scala","tests/sources/import/MetadataTransportTests.scala","tests/sources/import/SqliteObservationTests.scala","tests/sources/import/RetainedV1Tests.scala")
    val arguments=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray
    require(!dotty.tools.dotc.Main.process(arguments).hasErrors,"source importer compilation failed")
    val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
    try List("veri7vn.sources.LocalSnapshotTests","veri7vn.sources.ChunkedSnapshotTests","veri7vn.sources.MetadataTransportTests","veri7vn.sources.SqliteObservationTests").foreach(name=>
      loader.loadClass(name).getMethod("main",classOf[Array[String]])
        .invoke(null,Array.empty[String].asInstanceOf[Object])) finally loader.close()
  } finally {
    val paths=Files.walk(out)
    try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p)) finally paths.close()
  }
}
