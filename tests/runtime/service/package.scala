import scala.language.unsafeNulls
import java.nio.file.{Files,Paths}
@main def packageRuntime():Unit=isabelle.Command_Line.tool {
  val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/service/AuthorityCoordinator.scala",
    "src/runtime/service/ResidentSupervisor.scala","src/runtime/service/DeploymentImages.scala",
    "src/runtime/service/ResidentNativeBridge.scala","src/runtime/service/ResidentAuthorityService.scala",
    "src/runtime/service/RuntimeService.scala","src/runtime/service/RuntimeMain.scala")
  val classes=Files.createTempDirectory("veri7vn-runtime-package-")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"runtime launcher compilation failed")
  val destination=Paths.get("var/runtime-host/package/veri7vn-runtime.jar")
  Files.createDirectories(destination.getParent)
  val temporary=Files.createTempFile(destination.getParent,"runtime-",".jar")
  val manifest=new java.util.jar.Manifest()
  manifest.getMainAttributes.putValue("Manifest-Version","1.0")
  manifest.getMainAttributes.putValue("Main-Class","veri7vn.runtime.service.RuntimeMain")
  val jar=new java.util.jar.JarOutputStream(Files.newOutputStream(temporary),manifest)
  try {
    val walk=Files.walk(classes)
    try {
      val files=walk.filter(p=>Files.isRegularFile(p)).sorted().toList
      val iterator=files.iterator()
      while(iterator.hasNext){
        val path=iterator.next()
        val entry=new java.util.jar.JarEntry(classes.relativize(path).toString.replace('\\','/'));entry.setTime(0)
        jar.putNextEntry(entry);Files.copy(path,jar);jar.closeEntry()
      }
    } finally walk.close()
  } finally jar.close()
  Files.move(temporary,destination,java.nio.file.StandardCopyOption.REPLACE_EXISTING,java.nio.file.StandardCopyOption.ATOMIC_MOVE)
  val loader=new java.net.URLClassLoader(Array(destination.toUri.toURL),getClass.getClassLoader)
  try {
    require(loader.loadClass("veri7vn.runtime.service.RuntimeMain").getMethod("main",classOf[Array[String]])!=null)
    val session=loader.loadClass("veri7vn.runtime.service.RuntimeService").getMethod("sessionName").invoke(null).asInstanceOf[String]
    require(session=="Veri7vn_Runtime_Service","launcher does not select actual production session")
    val store=isabelle.Store(isabelle.Options.init())
    val selected=store.get_session(session)
    require(selected.heap.nonEmpty && selected.log_db.nonEmpty,"production heap/build database unavailable")
    val db=isabelle.SQLite.open_database(selected.log_db.get)
    try require(store.read_build(db,session).exists(_.ok),"production session has no successful build record") finally db.close()
  } finally loader.close()
  println("RUNTIME_PACKAGE_PASS "+destination.toAbsolutePath+" native_heap_launch_unchecked")
}
