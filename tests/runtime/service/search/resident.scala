import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}

@main def searchResidentCheck():Unit=isabelle.Command_Line.tool {
  // Compile the actual packaged host and select the actual production session.
  // The fixture creates no alternate authority, scheduler or native result.
  val canonical=Files.readString(Paths.get("tests/runtime/service/package.scala"))
  val production="\"(src/[^\"]+\\.scala)\"".r.findAllMatchIn(canonical).map(_.group(1)).toList.distinct
  require(production.nonEmpty && production.contains("src/runtime/service/RuntimeService.scala"),"canonical runtime source inventory")
  val sources=production:+"tests/runtime/service/search/SearchResidentTests.scala"
  val classes=Files.createTempDirectory("veri7vn-search-resident-")
  val options=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(options).hasErrors,"search resident consumer compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(p=>p.getFileName.toString=="ROOT")
    .map(_.getParent.toAbsolutePath.toString).toList.sorted
    finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.search.SearchResidentTests").getMethod("main",classOf[Array[String]])
      .invoke(null,("Veri7vn_Runtime_Service"::roots).toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  } finally loader.close()
}
