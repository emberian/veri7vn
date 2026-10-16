import scala.language.unsafeNulls
import java.nio.file.{Files,Paths}

@main def searchIngressCheck():Unit=isabelle.Command_Line.tool {
  // Reuse the installed runtime's explicitly listed production closure. This
  // driver adds only the new search consumer and its controlled wire test.
  val canonical=Files.readString(Paths.get("tests/runtime/service/package.scala"))
  val production="\"(src/[^\"]+\\.scala)\"".r.findAllMatchIn(canonical).map(_.group(1)).toList.distinct
  require(production.nonEmpty && production.contains("src/runtime/service/RuntimeService.scala"),"canonical runtime source inventory")
  val sources=(production++List("src/runtime/service/search/SearchIngress.scala",
    "src/authoring/assistance/LiteralSearch.scala","src/authoring/assistance/StandaloneSearch.scala",
    "tests/runtime/service/search/SearchIngressTests.scala")).distinct
  val classes=Files.createTempDirectory("veri7vn-search-ingress-")
  val options=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(options).hasErrors,"search consumer compilation failed")
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.runtime.service.search.SearchIngressTests").getMethod("main",classOf[Array[String]])
      .invoke(null,Array.empty[String].asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  } finally loader.close()
}
