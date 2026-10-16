import scala.language.unsafeNulls
import java.nio.file.Files
@main def snapshotCheck():Unit=isabelle.Command_Line.tool {
  val out=Files.createTempDirectory("veri7vn-snapshot-classes-")
  val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/host/WorkspaceSnapshot.scala","tests/runtime/host/WorkspaceSnapshotTests.scala")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"snapshot compilation failed")
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  try loader.loadClass("veri7vn.runtime.host.WorkspaceSnapshotTests").getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])
  finally loader.close()
  println("WORKSPACE_SNAPSHOT_CLASSES "+out)
}
