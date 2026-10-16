import scala.language.unsafeNulls
import java.nio.file.Files

@main def intakeCheck(): Unit = {
  val root=java.nio.file.Paths.get("").toAbsolutePath
  val out=Files.createTempDirectory("veri7vn-intake-classes-")
  try {
    val paths=List("src/packages/intake/Intake.scala", "src/packages/intake/SourceObjects.scala", "src/packages/intake/HostDraftJournal.scala", "src/runtime/host/WorkspaceStore.scala", "tests/packages/intake/IntakeTests.scala")
    val arguments=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++paths).toArray
    val reporter=dotty.tools.dotc.Main.process(arguments)
    require(!reporter.hasErrors,"Intake compilation failed")
    val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
    try loader.loadClass("veri7vn.packages.intake.IntakeTests").getMethod("main",classOf[Array[String]])
      .invoke(null,Array.empty[String].asInstanceOf[Object])
    finally loader.close()
  } finally {
    val paths=Files.walk(out)
    try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p => Files.delete(p)) finally paths.close()
  }
}
