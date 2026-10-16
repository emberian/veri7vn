import scala.language.unsafeNulls
import java.nio.file.Files
@main def connectorCheck():Unit={
  val out=Files.createTempDirectory("connector-classes-")
  val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
    "src/runtime/effects/WorkerResources.scala","src/runtime/effects/OperationProfile.scala",
    "src/runtime/effects/Executor.scala","src/sources/import/LocalSnapshot.scala",
    "src/connectors/LocalAcquisitionBinding.scala","src/connectors/LocalSensorExecutor.scala","tests/connectors/LocalSensorExecutorTest.scala")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"connector compilation")
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  try loader.loadClass("veri7vn.runtime.connectors.LocalSensorExecutorTest").getMethod("main",classOf[Array[String]])
    .invoke(null,Array.empty[String].asInstanceOf[Object]) finally loader.close()
}
