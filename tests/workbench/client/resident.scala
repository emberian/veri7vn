import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}
@main def residentWorkbenchCheck():Unit=isabelle.Command_Line.tool {
  // Share the producer inventory instead of maintaining another host closure.
  // The steward pins this script, package.scala and every resolved source byte.
  val producer=Paths.get("tests/runtime/service/package.scala")
  val text=Files.readString(producer)
  val begin=text.indexOf("  val sources=List(")
  val end=text.indexOf("  val classes=",begin)
  require(begin>=0 && end>begin,"Cannot locate the canonical runtime producer source list")
  val runtimeSources="\"(src/[^\"]+\\.scala)\"".r.findAllMatchIn(text.substring(begin,end)).map(_.group(1)).toList
  require(runtimeSources.nonEmpty && runtimeSources.distinct==runtimeSources && runtimeSources.forall(path=>Files.isRegularFile(Paths.get(path))),"Invalid canonical runtime source inventory")
  val sources=runtimeSources++List("tests/workbench/client/ResidentWorkbenchTests.scala","tests/workbench/assistance/RoutingCommandsChecks.scala")
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
