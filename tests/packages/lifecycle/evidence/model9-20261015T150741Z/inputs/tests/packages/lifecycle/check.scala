import scala.language.unsafeNulls
import java.nio.file.Files
@main def packageModelCheck():Unit={
  val output=Files.createTempDirectory("v7-package-model-classes-")
  try {
    val sources=List("src/packages/intake/Intake.scala","src/packages/lifecycle/PackageModel.scala",
      "src/packages/lifecycle/TransferPolicy.scala","src/packages/lifecycle/OperationIdentity.scala","src/packages/lifecycle/LegacyMapping.scala","src/packages/lifecycle/SourceProjection.scala","tests/packages/lifecycle/ModelTests.scala")
    val args=(List("-classpath",System.getProperty("java.class.path"),"-d",output.toString)++sources).toArray
    require(!dotty.tools.dotc.Main.process(args).hasErrors,"Package model compilation failed")
    val loader=new java.net.URLClassLoader(Array(output.toUri.toURL),Thread.currentThread().getContextClassLoader)
    try loader.loadClass("veri7vn.packages.lifecycle.ModelTests").getMethod("main",classOf[Array[String]])
      .invoke(null,Array.empty[String].asInstanceOf[Object]) finally loader.close()
  } finally {val paths=Files.walk(output);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()}
}
