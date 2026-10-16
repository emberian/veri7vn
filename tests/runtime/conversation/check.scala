import java.nio.file.Files
import scala.language.unsafeNulls
@main def conversationProtocolCheck():Unit=isabelle.Command_Line.tool {
  val sources=List("src/runtime/conversation/ConversationProtocol.scala",
    "tests/runtime/conversation/ConversationProtocolTests.scala")
  val classes=Files.createTempDirectory("veri7vn-conversation-check-")
  val arguments=(List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(arguments).hasErrors,"conversation protocol compilation failed")
  val loader=new java.net.URLClassLoader(Array(classes.toUri.toURL),getClass.getClassLoader)
  try loader.loadClass("veri7vn.runtime.conversation.ConversationProtocolTests")
    .getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])
  catch {case failure:java.lang.reflect.InvocationTargetException=>throw failure.getCause}
  finally loader.close()
}
