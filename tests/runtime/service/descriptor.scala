import scala.language.unsafeNulls
import java.nio.file.Files
@main def descriptorAdapterCheck():Unit=isabelle.Command_Line.tool {
  val output=Files.createTempDirectory("v7-descriptor-adapter-")
  val sources=List("src/packages/intake/Intake.scala","src/packages/lifecycle/InertJSON.scala",
    "src/packages/lifecycle/PackageModel.scala","src/runtime/service/PackageDescriptorFunction.scala",
    "tests/runtime/service/PackageDescriptorFunctionTests.scala")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",output.toString)++sources).toArray).hasErrors,"descriptor adapter compile failed")
  val loader=new java.net.URLClassLoader(Array(output.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.PackageDescriptorFunctionTests").getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  } finally loader.close()
}
