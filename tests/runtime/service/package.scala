import scala.language.unsafeNulls
import java.nio.file.{Files,Paths}
@main def packageRuntime():Unit=isabelle.Command_Line.tool {
  val sources=List("src/runtime/service/RoutingDetailsProtocol.scala","src/runtime/service/GrowthSuggestionProtocol.scala","src/authoring/assistance/GrowthCommands.scala","src/authoring/assistance/RoutingCommands.scala","src/runtime/effects/Executor.scala","src/runtime/effects/OperationProfile.scala","src/runtime/service/ServiceCapabilities.scala","src/runtime/service/EffectSourceProtocol.scala","src/runtime/service/effects/NativeEffectCommand.scala","src/workbench/BuildWorkspace.scala","src/workbench/ResidentBuildWorkspace.scala","src/cli/BuildCommands.scala","src/runtime/service/build/BuildHistory.scala","src/diagnostics/PackageImpact.scala","src/runtime/service/search/SearchIngress.scala","src/runtime/conversation/ConversationClient.scala","src/runtime/conversation/ConversationProtocol.scala","src/runtime/service/ProducerReleaseQueue.scala","src/diagnostics/BuildFailure.scala","src/diagnostics/SourceDiagnostic.scala","src/runtime/service/NativeBuildIngress.scala","src/runtime/service/PackageDescriptorFunction.scala","src/packages/native_build/NativeBuildInputs.scala","src/packages/lifecycle/SessionInventory.scala","src/packages/intake/HostDraftJournal.scala","src/runtime/effects/WorkerResources.scala","src/authoring/assistance/Assistance.scala","src/diagnostics/Repair.scala","src/workbench/ReviewTickets.scala","src/cli/Workbench.scala","src/diagnostics/Diagnostics.scala","src/diagnostics/RequestInspection.scala","src/runtime/host/WorkspaceStore.scala","src/runtime/service/AuthorityCoordinator.scala",
    "src/runtime/service/ResidentSupervisor.scala","src/runtime/service/DeploymentImages.scala",
    "src/runtime/service/ResidentNativeBridge.scala","src/runtime/service/ResidentAuthorityService.scala",
    "src/runtime/service/RuntimeService.scala","src/runtime/service/RuntimeMain.scala",
    "src/runtime/host/ManagedSources.scala",
    "src/packages/intake/Intake.scala","src/packages/intake/SourceObjects.scala",
    "src/packages/lifecycle/OperationIdentity.scala","src/packages/lifecycle/ManagedDrafts.scala",
    "src/packages/lifecycle/InertJSON.scala","src/packages/lifecycle/LegacyPanel.scala",
    "src/packages/lifecycle/LegacyMapping.scala","src/packages/lifecycle/PackageModel.scala",
    "src/packages/lifecycle/PackageUpdates.scala",
    "src/workbench/Authoring.scala","src/workbench/Browser.scala","src/workbench/SourceLocation.scala",
    "src/workbench/Execution.scala","src/workbench/ResidentExecution.scala","src/cli/ResidentWorkbench.scala","src/isabelle/language/runtime/DialogueClient.scala")
  val classes=Files.createTempDirectory("veri7vn-runtime-package-")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"runtime launcher compilation failed")
  val destination=Paths.get("var/runtime-host/package/veri7vn-runtime.jar")
  Files.createDirectories(destination.getParent)
  val temporary=Files.createTempFile(destination.getParent,"runtime-",".jar")
  val manifest=new java.util.jar.Manifest()
  manifest.getMainAttributes.putValue("Manifest-Version","1.0")
  manifest.getMainAttributes.putValue("Main-Class","veri7vn.runtime.service.RuntimeMain")
  val jar=new java.util.jar.JarOutputStream(Files.newOutputStream(temporary),manifest)
  try {
    val service=new java.util.jar.JarEntry("META-INF/isabelle/services");service.setTime(0)
    jar.putNextEntry(service)
    jar.write("veri7vn.runtime.service.PackageDescriptorFunctions\n".getBytes(java.nio.charset.StandardCharsets.UTF_8))
    jar.closeEntry()
    val walk=Files.walk(classes)
    try {
      val files=walk.filter(p=>Files.isRegularFile(p)).sorted().toList
      val iterator=files.iterator()
      while(iterator.hasNext){
        val path=iterator.next()
        val entry=new java.util.jar.JarEntry(classes.relativize(path).toString.replace('\\','/'));entry.setTime(0)
        jar.putNextEntry(entry);Files.copy(path,jar);jar.closeEntry()
      }
    } finally walk.close()
  } finally jar.close()
  Files.move(temporary,destination,java.nio.file.StandardCopyOption.REPLACE_EXISTING,java.nio.file.StandardCopyOption.ATOMIC_MOVE)
  val loader=new java.net.URLClassLoader(Array(destination.toUri.toURL),getClass.getClassLoader)
  try {
    require(loader.loadClass("veri7vn.runtime.service.RuntimeMain").getMethod("main",classOf[Array[String]])!=null)
    val session=loader.loadClass("veri7vn.runtime.service.RuntimeService").getMethod("sessionName").invoke(null).asInstanceOf[String]
    require(session=="Veri7vn_Runtime_Service","launcher does not select actual production session")
    val store=isabelle.Store(isabelle.Options.init())
    val selected=store.get_session(session)
    require(selected.heap.nonEmpty && selected.log_db.nonEmpty,"production heap/build database unavailable")
    val db=isabelle.SQLite.open_database(selected.log_db.get)
    try require(store.read_build(db,session).exists(_.ok),"production session has no successful build record") finally db.close()
  } finally loader.close()
  println("RUNTIME_PACKAGE_PASS "+destination.toAbsolutePath+" native_heap_launch_unchecked")
}
