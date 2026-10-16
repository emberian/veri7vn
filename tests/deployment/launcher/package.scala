import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Path,Paths}
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest

/** Recipient bootstrap producer. No native process, heap build or admission. */
@main def packageDeploymentLauncher():Unit=isabelle.Command_Line.tool {
  def sha(bytes:Array[Byte]):String=MessageDigest.getInstance("SHA-256").digest(bytes).map(b=>f"${b&255}%02x").mkString
  def quoted(value:String):String="\""+value.flatMap {
    case '\\'=>"\\\\"
    case '"'=>"\\\""
    case '\n'=>"\\n"
    case '\r'=>"\\r"
    case '\t'=>"\\t"
    case c if c<' '=>f"\\u${c.toInt}%04x"
    case c=>c.toString
  }+"\""
  def objectJson(values:Vector[(String,String)]):String=values.sortBy(_._1).map((key,value)=>quoted(key)+":"+quoted(value)).mkString("{",",","}")
  val selected=Vector("src/deployment/DeploymentMain.scala")
  val attempt=java.util.UUID.randomUUID().toString.replace("-","")
  val archive=Paths.get("var/deployment-launcher/archives",attempt).toAbsolutePath
  Files.createDirectories(archive)
  val snapshot=archive.resolve("source-snapshot")
  val recorded=selected++Vector("src/deployment/veri7vn","tests/deployment/launcher/package.scala","tests/deployment/launcher/parity.py","tests/deployment/launcher/bootstrap.py")
  val pins=recorded.map {name=>
    require(!name.contains("..") && !Path.of(name).isAbsolute,"Portable source inventory")
    val bytes=Files.readAllBytes(Paths.get(name))
    val target=snapshot.resolve(name);Files.createDirectories(target.getParent);Files.write(target,bytes)
    name->sha(bytes)
  }
  val classes=Files.createTempDirectory("v7-launcher-package-classes-")
  try {
    val arguments=List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++selected.map(path=>snapshot.resolve(path).toString)
    require(!dotty.tools.dotc.Main.process(arguments.toArray).hasErrors,"Source workbench packaging compilation failed")
    val walk=Files.walk(classes)
    val entries=try walk.iterator().asScala.filter(path=>Files.isRegularFile(path)).toVector.sortBy(path=>classes.relativize(path).toString) finally walk.close()
    require(entries.nonEmpty,"No source application classes produced")
    val classPins=entries.map(path=>classes.relativize(path).toString.replace('\\','/')->sha(Files.readAllBytes(path)))
    val jarPath=archive.resolve("veri7vn-launcher.jar")
    val manifest=new java.util.jar.Manifest()
    manifest.getMainAttributes.putValue("Manifest-Version","1.0")
    manifest.getMainAttributes.putValue("Main-Class","veri7vn.deployment.DeploymentMain")
    val jar=new java.util.jar.JarOutputStream(Files.newOutputStream(jarPath),manifest)
    try entries.foreach {path=>
      val entry=new java.util.jar.JarEntry(classes.relativize(path).toString.replace('\\','/'));entry.setTime(0)
      jar.putNextEntry(entry);Files.copy(path,jar);jar.closeEntry()
    } finally jar.close()
    val loader=new java.net.URLClassLoader(Array(jarPath.toUri.toURL),getClass.getClassLoader)
    try {
      val main=loader.loadClass("veri7vn.deployment.DeploymentMain")
      require(main.getMethod("main",classOf[Array[String]])!=null,"Source entrypoint is not callable")
      require(main.getProtectionDomain.getCodeSource.getLocation==jarPath.toUri.toURL,"Source entrypoint came from another classpath")
    } finally loader.close()
    val pinMap=pins.toMap
    recorded.foreach(name=>require(sha(Files.readAllBytes(Paths.get(name)))==pinMap(name),"Source changed during packaging: "+name))
    val receipt="{\"format\":\"veri7vn.deployment-launcher-producer/1\",\"attempt_id\":"+quoted(attempt)+
      ",\"scope\":\"bootstrap compile and classload; installed execution unchecked\",\"sources_sha256\":"+objectJson(pins)+
      ",\"classes_sha256\":"+objectJson(classPins)+",\"java_version\":"+quoted(System.getProperty("java.version"))+"}\n"
    Files.writeString(archive.resolve("receipt.json"),receipt,UTF_8)
    val shell=archive.resolve("bin/veri7vn")
    Files.createDirectories(shell.getParent)
    Files.copy(snapshot.resolve("src/deployment/veri7vn"),shell)
    Files.setPosixFilePermissions(shell,java.nio.file.attribute.PosixFilePermissions.fromString("r-xr-xr-x"))
    Files.writeString(archive.resolve("artifact.json"),isabelle.JSON.Format(Map("sha256"->sha(Files.readAllBytes(jarPath)),"shell_sha256"->sha(Files.readAllBytes(shell))))+"\n",UTF_8)
    println("DEPLOYMENT_LAUNCHER_PACKAGE_PASS "+archive+" installed_execution_unchecked")
  } finally {
    val cleanup=Files.walk(classes)
    try cleanup.sorted(java.util.Comparator.reverseOrder()).forEach(path=>Files.delete(path)) finally cleanup.close()
  }
}
