import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}
@main def residentRuntimeCheck():Unit=isabelle.Command_Line.tool {
  val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/service/AuthorityCoordinator.scala",
    "src/runtime/service/ResidentSupervisor.scala","src/runtime/service/DeploymentImages.scala",
    "src/runtime/service/ResidentNativeBridge.scala","src/runtime/service/ResidentAuthorityService.scala",
    "tests/runtime/service/ResidentServiceTests.scala")
  val classes=Files.createTempDirectory("veri7vn-resident-check-")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"resident consumer compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(p=>p.getFileName.toString=="ROOT").map(_.getParent.toAbsolutePath.toString).toList.sorted
    finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.ResidentServiceTests").getMethod("main",classOf[Array[String]])
      .invoke(null,("Veri7vn_Runtime_Service"::roots).toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>failure.getCause.printStackTrace();throw failure.getCause}
  } finally loader.close()
}
