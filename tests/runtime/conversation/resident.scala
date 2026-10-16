import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}

/** Compile the real consumer against the produced runtime, rather than maintain
  * another handwritten inventory of production host dependencies. */
@main def conversationResidentCheck():Unit=isabelle.Command_Line.tool {
  val runtimeJar=Paths.get("var/runtime-host/package/veri7vn-runtime.jar").toAbsolutePath
  require(Files.isRegularFile(runtimeJar),"produce the current runtime JAR before conversation composition checks")
  val sources=List("tests/runtime/conversation/ConversationResidentTests.scala",
    "tests/language/runtime/DialogueConversationChecks.scala")
  val classes=Files.createTempDirectory("v7-conversation-resident-check-")
  val classpath=System.getProperty("java.class.path")+java.io.File.pathSeparator+runtimeJar.toString
  require(!dotty.tools.dotc.Main.process((List("-classpath",classpath,"-d",classes.toString)++sources).toArray).hasErrors,
    "conversation packaged consumer compilation failed")
  val walk=Files.walk(Paths.get("src"))
  val roots=try walk.iterator().asScala.filter(p=>p.getFileName.toString=="ROOT")
    .map(_.getParent.toAbsolutePath.toString).toList.sorted finally walk.close()
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL,runtimeJar.toUri.toURL),getClass.getClassLoader)
  try loader.loadClass("veri7vn.runtime.service.ConversationResidentTests")
    .getMethod("main",classOf[Array[String]])
    .invoke(null,("Veri7vn_Runtime_Service"::roots).toArray.asInstanceOf[Object])
  catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  finally loader.close()
}
