import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}

@main def assistanceSearchResidentCheck():Unit=isabelle.Command_Line.tool {
  val inventory=Files.readString(Paths.get("tests/runtime/service/package.scala"))
  val production="\"(src/[^\"]+\\.scala)\"".r.findAllMatchIn(inventory).map(_.group(1)).toList.distinct
  require(production.contains("src/runtime/service/RuntimeService.scala"),"Canonical runtime source inventory")
  val sources=(production++List("src/authoring/assistance/LiteralSearch.scala",
    "src/authoring/assistance/StandaloneSearch.scala","src/authoring/assistance/SearchCommands.scala",
    "tests/workbench/assistance/SearchCommandsResidentTests.scala")).distinct
  val classes=Files.createTempDirectory("veri7vn-search-command-classes-")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray).hasErrors,
    "Assistance real search commands compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(_.getFileName.toString=="ROOT").map(_.getParent.toAbsolutePath.toString).toList.sorted
    finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.search.SearchCommandsResidentTests").getMethod("main",classOf[Array[String]])
      .invoke(null,("Veri7vn_Runtime_Service"::roots).toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  }finally loader.close()
}
