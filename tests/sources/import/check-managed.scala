import scala.language.unsafeNulls
import java.nio.file.Files
@main def managedSourceCheck(): Unit = {
  val out=Files.createTempDirectory("veri7vn-source-import-classes-")
  try {
    val paths=List("src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
      "src/sources/import/LocalSnapshot.scala","src/sources/import/ChunkedSnapshot.scala",
      "src/sources/import/SqliteObservation.scala","src/sources/import/ManagedChunkObjects.scala",
      "tests/sources/import/ManagedSourceTests.scala")
    val arguments=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray
    require(!dotty.tools.dotc.Main.process(arguments).hasErrors,"source importer compilation failed")
    val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
    try List("veri7vn.sources.ManagedSourceTests").foreach(name=>
      loader.loadClass(name).getMethod("main",classOf[Array[String]])
        .invoke(null,Array.empty[String].asInstanceOf[Object])) finally loader.close()
  } finally {
    val paths=Files.walk(out)
    try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p)) finally paths.close()
  }
}
