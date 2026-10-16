import scala.language.unsafeNulls
import java.nio.file.Files
@main def effectsCheck(): Unit = {
  val out=Files.createTempDirectory("veri7vn-effects-classes-")
  val paths=List("src/runtime/host/WorkspaceStore.scala", "src/runtime/host/ManagedSources.scala",
    "src/runtime/effects/WorkerResources.scala", "src/runtime/effects/OperationProfile.scala", "src/runtime/effects/Executor.scala", "src/runtime/effects/IsolatedLearning.scala",
    "tests/effects/IsolatedLearningTest.scala", "tests/effects/OperationProfileTest.scala", "tests/effects/WorkerResourcesTest.scala")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"effects compilation failed")
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  try for(name<-List("veri7vn.runtime.effects.IsolatedLearningTest", "veri7vn.runtime.effects.OperationProfileTest", "veri7vn.runtime.effects.WorkerResourcesTest"))
    loader.loadClass(name).getMethod("main",classOf[Array[String]])
      .invoke(null,Array.empty[String].asInstanceOf[Object])
  finally loader.close()
}
