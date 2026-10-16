import scala.language.unsafeNulls
import java.nio.file.Files
@main def runtimeHostCheck(): Unit = isabelle.Command_Line.tool {
  val out=Files.createTempDirectory("veri7vn-host-classes-")
  val paths=List("tests/runtime/service/ServiceCapabilitiesTests.scala","src/runtime/service/ServiceCapabilities.scala","tests/runtime/service/EffectSourceProtocolTests.scala","src/runtime/service/EffectSourceProtocol.scala","tests/runtime/service/RestoreInventoryTests.scala","tests/runtime/host/NativeEffectSourceTests.scala","src/runtime/service/effects/NativeEffectCommand.scala","src/runtime/service/RuntimeService.scala","src/runtime/service/build/BuildHistory.scala","tests/runtime/host/NativeBuildSourceTests.scala","src/runtime/service/search/SearchIngress.scala","src/runtime/conversation/ConversationProtocol.scala","tests/runtime/service/ProducerReleaseQueueTests.scala","src/runtime/service/ProducerReleaseQueue.scala","src/diagnostics/SourceDiagnostic.scala","src/diagnostics/BuildFailure.scala","src/runtime/host/WorkspaceSnapshot.scala","tests/runtime/host/WorkspaceSnapshotTests.scala","src/runtime/service/NativeBuildIngress.scala","src/runtime/service/PackageDescriptorFunction.scala","tests/runtime/service/PackageDescriptorFunctionTests.scala","tests/runtime/service/NativeBuildIngressTests.scala","src/diagnostics/Diagnostics.scala","src/diagnostics/RequestInspection.scala",
    "src/packages/lifecycle/PackageModel.scala","src/packages/lifecycle/InertJSON.scala",
    "src/runtime/host/WorkspaceStore.scala", "src/runtime/host/ManagedSources.scala", "tests/runtime/host/ManagedSourcesTests.scala", "src/runtime/service/AuthorityCoordinator.scala",
    "src/runtime/service/ResidentSupervisor.scala", "src/runtime/service/DeploymentImages.scala", "src/runtime/service/ResidentNativeBridge.scala", "src/runtime/service/ResidentAuthorityService.scala", "src/runtime/service/MetadataFrame.scala", "tests/runtime/host/WorkspaceStoreTests.scala", "tests/runtime/service/CoordinatorTests.scala", "tests/runtime/service/ResidentServiceTests.scala",
    "src/packages/intake/Intake.scala", "src/packages/intake/SourceObjects.scala", "src/packages/intake/HostDraftJournal.scala",
    "tests/packages/intake/IntakeTests.scala", "src/packages/native_build/NativeBuildInputs.scala", "tests/packages/native_build/NativeBuildInputsTests.scala", "src/packages/lifecycle/SessionInventory.scala", "src/packages/lifecycle/OperationIdentity.scala", "src/packages/lifecycle/ManagedDrafts.scala", "tests/packages/lifecycle/ManagedDraftTests.scala", "src/runtime/effects/WorkerResources.scala", "tests/effects/WorkerResourcesTest.scala", "src/runtime/effects/Executor.scala", "src/runtime/effects/IsolatedLearning.scala", "src/runtime/effects/OperationProfile.scala", "tests/effects/IsolatedLearningTest.scala", "tests/effects/OperationProfileTest.scala")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"runtime host compilation failed")
  println("RUNTIME_HOST_CLASSES "+out.toAbsolutePath)
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  val failures=scala.collection.mutable.ArrayBuffer.empty[(String,Throwable)]
  def check(name:String,method:String):Unit={
    println("RUNTIME_CHECK_BEGIN "+name)
    try {
      try {
        if(method=="main")loader.loadClass(name).getMethod(method,classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])
        else loader.loadClass(name).getMethod(method).invoke(null)
      } catch {case wrapped:java.lang.reflect.InvocationTargetException=>throw wrapped.getCause}
    } catch {case scala.util.control.NonFatal(problem)=>
      failures+=((name,problem));System.err.println("RUNTIME_CHECK_FAILED "+name);problem.printStackTrace()
    }
  }
  try {
    for(name<-List("veri7vn.runtime.service.ServiceCapabilitiesTests","veri7vn.runtime.service.EffectSourceProtocolTests","veri7vn.runtime.service.RestoreInventoryTests","veri7vn.runtime.host.NativeEffectSourceTests","veri7vn.runtime.host.NativeBuildSourceTests","veri7vn.runtime.service.ProducerReleaseQueueTests","veri7vn.runtime.host.WorkspaceSnapshotTests","veri7vn.runtime.host.WorkspaceStoreTests","veri7vn.runtime.host.ManagedSourcesTests","veri7vn.runtime.service.CoordinatorTests","veri7vn.runtime.service.PackageDescriptorFunctionTests","veri7vn.runtime.service.NativeBuildIngressTests","veri7vn.packages.intake.IntakeTests","veri7vn.packages.lifecycle.ManagedDraftTests","veri7vn.runtime.effects.IsolatedLearningTest","veri7vn.runtime.effects.OperationProfileTest","veri7vn.runtime.effects.WorkerResourcesTest"))check(name,"main")
    check("veri7vn.packages.native_build.NativeBuildInputsTests","checks")
    if(failures.nonEmpty){
      val problem=new IllegalStateException("runtime checks failed: "+failures.map(_._1).mkString(","))
      failures.foreach(p=>problem.addSuppressed(p._2));throw problem
    }
  } finally loader.close()
}
