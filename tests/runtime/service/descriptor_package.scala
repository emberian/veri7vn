import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
@main def packageDescriptorProvider():Unit=isabelle.Command_Line.tool {
  val output=Files.createTempDirectory("v7-descriptor-provider-")
  val sources=List("src/packages/intake/Intake.scala","src/packages/lifecycle/InertJSON.scala",
    "src/packages/lifecycle/PackageModel.scala","src/runtime/service/PackageDescriptorFunction.scala")
  require(!dotty.tools.dotc.Main.process((List("-classpath",System.getProperty("java.class.path"),"-d",output.toString)++sources).toArray).hasErrors,"descriptor provider compile failed")
  val target=Path.of("var/runtime-host/descriptor-provider/veri7vn-descriptor.jar")
  Files.createDirectories(target.getParent)
  val temporary=Files.createTempFile(target.getParent,"provider-",".jar")
  val jar=new java.util.jar.JarOutputStream(Files.newOutputStream(temporary))
  try {
    val service=new java.util.jar.JarEntry("META-INF/isabelle/services");service.setTime(0)
    jar.putNextEntry(service);jar.write("veri7vn.runtime.service.PackageDescriptorFunctions\n".getBytes(java.nio.charset.StandardCharsets.UTF_8));jar.closeEntry()
    val walk=Files.walk(output)
    try {
      val iterator=walk.filter(p=>Files.isRegularFile(p)).sorted().iterator()
      while(iterator.hasNext){
        val path=iterator.next();val entry=new java.util.jar.JarEntry(output.relativize(path).toString.replace('\\','/'));entry.setTime(0)
        jar.putNextEntry(entry);Files.copy(path,jar);jar.closeEntry()
      }
    } finally walk.close()
  } finally jar.close()
  Files.move(temporary,target,java.nio.file.StandardCopyOption.ATOMIC_MOVE,java.nio.file.StandardCopyOption.REPLACE_EXISTING)
  println("PACKAGE_DESCRIPTOR_PROVIDER_PASS "+target.toAbsolutePath)
}
