import scala.language.unsafeNulls
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
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources++List("tests/integration/workshop/WorkshopLifecycleTests.scala",
    "tests/workbench/assistance/RoutingCommandsChecks.scala","tests/workbench/assistance/GrowthCommandsChecks.scala")).toArray).hasErrors,"Workshop compilation failed")
  // Use exactly the native graph built by the guarded invocation. Scanning
  // unrelated source ROOTs can introduce conflicting experimental sessions.
  val closurePath=Paths.get(Option(System.getenv("VERI7VN_WORKSHOP_NATIVE_CLOSURE"))
    .getOrElse(throw new IllegalArgumentException("Workshop requires its captured native closure manifest")))
  val closure=isabelle.JSON.parse(Files.readString(closurePath))
  require(isabelle.JSON.string(closure,"format").contains("veri7vn.native-source-closure/1") &&
    isabelle.JSON.strings(closure,"sessions").contains(List("Veri7vn_Runtime_Service")),
    "Workshop native closure target")
  val selectedRoots=isabelle.JSON.strings(closure,"session_roots").getOrElse(
    throw new IllegalArgumentException("Workshop native closure roots"))
  require(selectedRoots.nonEmpty && selectedRoots.distinct==selectedRoots,"Workshop native roots must be unique")
  val roots=selectedRoots.map {root=>
    val path=Paths.get(root).toAbsolutePath.normalize()
    require(path.startsWith(Paths.get("src").toAbsolutePath.normalize()) &&
      Files.isRegularFile(path.resolve("ROOT")),"Workshop native root outside captured source graph")
    path.toString
  }
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try {
    val runtimeOrigin=Paths.get(loader.loadClass("veri7vn.runtime.service.RuntimeService")
      .getProtectionDomain.getCodeSource.getLocation.toURI)
    require(Files.isSameFile(runtimeOrigin,classes),"Workshop runtime shadowed by an older parent classloader")
    val providerOrigin=Paths.get(loader.loadClass("veri7vn.runtime.service.PackageDescriptorFunctions")
      .getProtectionDomain.getCodeSource.getLocation.toURI)
    require(Files.isRegularFile(providerOrigin),"Workshop descriptor provider must be registered in the initial JVM classpath")
    println("WORKSHOP_CODE_SOURCES runtime="+runtimeOrigin+" descriptor="+providerOrigin)
    try loader.loadClass("veri7vn.integration.workshop.WorkshopLifecycleTests").getMethod("main",classOf[Array[String]]).invoke(null,roots.toArray.asInstanceOf[Object])
    catch {case failure:java.lang.reflect.InvocationTargetException=>
      val cause=failure.getCause
      cause.printStackTrace()
      throw cause
    }
  } finally loader.close()
}
