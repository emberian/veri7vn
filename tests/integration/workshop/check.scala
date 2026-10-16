import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}
@main def workshopLifecycleCheck():Unit=isabelle.Command_Line.tool {
  // These fragments share private lexical state and the generated reducer's
  // carrier types. Catch a stale parent copy before exercising that consumer.
  List(
    "src/runtime/service/native_service.ML"->List("native_build_parent_pre.inc.ML","native_build_parent_post.inc.ML"),
    "src/runtime/service/metadata_frame.ML"->List("build_metadata_frame.inc.ML","build_recovery_frame.inc.ML")
  ).foreach {case(parent,fragments)=>
    val assembled=Files.readString(Paths.get(parent))
    fragments.foreach {fragment=>
      require(assembled.contains(Files.readString(Paths.get("src/runtime/service/build",fragment)).trim),
        s"Stale native parent fragment: $parent does not contain $fragment")
    }
  }
  val producer=Files.readString(Paths.get("tests/runtime/service/package.scala"))
  val begin=producer.indexOf("  val sources=List(")
  val end=producer.indexOf("  val classes=",begin)
  require(begin>=0 && end>begin,"Canonical resident source inventory missing")
  val sources="\"(src/[^\"]+\\.scala)\"".r.findAllMatchIn(producer.substring(begin,end)).map(_.group(1)).toList
  require(sources.nonEmpty && sources.distinct==sources && sources.forall(p=>Files.isRegularFile(Paths.get(p))),"Invalid resident source inventory")
  val classes=Files.createTempDirectory("v7-workshop-check-")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources:+"tests/integration/workshop/WorkshopLifecycleTests.scala").toArray).hasErrors,"Workshop compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(_.getFileName.toString=="ROOT").map(_.getParent.toAbsolutePath.toString).toList.sorted finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    try loader.loadClass("veri7vn.integration.workshop.WorkshopLifecycleTests").getMethod("main",classOf[Array[String]]).invoke(null,roots.toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  } finally loader.close()
}
