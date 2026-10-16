import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}

@main def dialogueResidentCheck():Unit=isabelle.Command_Line.tool {
  val sources=List("src/runtime/conversation/ConversationProtocol.scala","src/diagnostics/Diagnostics.scala","src/diagnostics/RequestInspection.scala",
    "src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
    "src/runtime/service/AuthorityCoordinator.scala","src/runtime/service/ResidentSupervisor.scala",
    "src/runtime/service/DeploymentImages.scala","src/runtime/service/ResidentNativeBridge.scala",
    "src/runtime/service/ResidentAuthorityService.scala","src/runtime/service/RuntimeService.scala",
    "src/isabelle/language/runtime/DialogueClient.scala","tests/language/runtime/DialogueClientChecks.scala")
  val classes=Files.createTempDirectory("veri7vn-dialogue-check-")
  val arguments=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(arguments).hasErrors,"dialogue consumer compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(p=>p.getFileName.toString=="ROOT")
    .map(_.getParent.toAbsolutePath.toString).toList.sorted finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.DialogueClientChecks")
      .getMethod("main",classOf[Array[String]]).invoke(null,roots.toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>
      failure.getCause.printStackTrace();throw failure.getCause}
  } finally loader.close()
}
