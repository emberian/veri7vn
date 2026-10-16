import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}
@main def residentWorkbenchCheck():Unit=isabelle.Command_Line.tool {
  val sources=List("src/diagnostics/Diagnostics.scala","src/diagnostics/RequestInspection.scala","src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
    "src/runtime/service/AuthorityCoordinator.scala","src/runtime/service/ResidentSupervisor.scala",
    "src/runtime/service/DeploymentImages.scala","src/runtime/service/ResidentNativeBridge.scala",
    "src/runtime/service/ResidentAuthorityService.scala","src/runtime/service/RuntimeService.scala",
    "src/packages/intake/Intake.scala","src/packages/intake/SourceObjects.scala",
    "src/packages/lifecycle/OperationIdentity.scala","src/packages/lifecycle/ManagedDrafts.scala",
    "src/packages/lifecycle/InertJSON.scala","src/packages/lifecycle/LegacyPanel.scala",
    "src/packages/lifecycle/LegacyMapping.scala","src/packages/lifecycle/PackageModel.scala",
    "src/packages/lifecycle/PackageUpdates.scala",
    "src/workbench/Authoring.scala","src/workbench/ReviewTickets.scala","src/diagnostics/Repair.scala","src/authoring/assistance/Assistance.scala","src/workbench/SourceLocation.scala","src/workbench/Browser.scala","src/workbench/Execution.scala",
    "src/workbench/ResidentExecution.scala","src/isabelle/language/runtime/DialogueClient.scala","src/cli/Workbench.scala","src/cli/ResidentWorkbench.scala","tests/workbench/client/ResidentWorkbenchTests.scala")
  val classes=Files.createTempDirectory("v7-resident-workbench-check-")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray).hasErrors,"resident workbench compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(p=>p.getFileName.toString=="ROOT").map(_.getParent.toAbsolutePath.toString).toList.sorted finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.workbench.ResidentWorkbenchTests").getMethod("main",classOf[Array[String]]).invoke(null,roots.toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>failure.getCause.printStackTrace();throw failure.getCause}
  }finally loader.close()
}
