import scala.language.unsafeNulls
import java.nio.file.Files
@main def authoringClientCheck():Unit=isabelle.Command_Line.tool {
  val output=Files.createTempDirectory("v7-authoring-classes-")
  try {
    val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
      "src/packages/intake/Intake.scala","src/packages/intake/SourceObjects.scala",
      "src/packages/lifecycle/OperationIdentity.scala","src/packages/lifecycle/ManagedDrafts.scala",
      "src/packages/lifecycle/InertJSON.scala","src/packages/lifecycle/PackageModel.scala","src/packages/lifecycle/PackageUpdates.scala","src/packages/lifecycle/LegacyPanel.scala","src/packages/lifecycle/LegacyMapping.scala",
      "src/workbench/Authoring.scala","src/workbench/ReviewTickets.scala","src/diagnostics/Repair.scala","src/authoring/assistance/Assistance.scala","src/workbench/Execution.scala","src/diagnostics/Diagnostics.scala","src/workbench/SourceLocation.scala","src/workbench/Browser.scala","src/cli/Workbench.scala","src/cli/launch.scala","tests/workbench/client/AuthoringTests.scala")
    require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",output.toString)++sources).toArray).hasErrors,"Authoring compilation failed")
    val loader=new java.net.URLClassLoader(Array(output.toUri.toURL),Thread.currentThread().getContextClassLoader)
    try {
      try loader.loadClass("veri7vn.workbench.AuthoringTests").getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])
      catch {case wrapped:java.lang.reflect.InvocationTargetException=>wrapped.getCause.printStackTrace();throw wrapped.getCause}
    }finally loader.close()
  }finally {val paths=Files.walk(output);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()}
}
