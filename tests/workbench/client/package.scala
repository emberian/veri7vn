import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Path,Paths}
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest

/** Source-only application producer. No native process, heap build or admission. */
@main def packageSourceWorkbench():Unit=isabelle.Command_Line.tool {
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
  val inventory=Paths.get("tests/workbench/client/check.scala")
  val inventoryBytes=Files.readAllBytes(inventory)
  val inventoryText=new String(inventoryBytes,UTF_8)
  val start=inventoryText.indexOf("val sources=List(")
  val stop=inventoryText.indexOf("require(!dotty",start)
  require(start>=0 && stop>start,"Source check inventory unavailable")
  val selected="\"([^\"]+\\.scala)\"".r.findAllMatchIn(inventoryText.substring(start,stop)).map(_.group(1)).toVector
    .filter(path=>path.startsWith("src/") && path!="src/cli/launch.scala")
  require(selected.nonEmpty && selected.distinct==selected && selected.contains("src/cli/Workbench.scala"),"Source application inventory")
  require(!selected.exists(path=>path.contains("Resident") || path.endsWith("RuntimeMain.scala")),"Source surface must not include resident entrypoints")
  val attempt=java.util.UUID.randomUUID().toString.replace("-","")
  val archive=Paths.get("var/workbench-source/archives",attempt).toAbsolutePath
  Files.createDirectories(archive)
  val snapshot=archive.resolve("source-snapshot")
  val recorded=selected++Vector(inventory.toString,"tests/workbench/client/package.scala")
  val pins=recorded.map {name=>
    require(!name.contains("..") && !Path.of(name).isAbsolute,"Portable source inventory")
    val bytes=if(name==inventory.toString)inventoryBytes else Files.readAllBytes(Paths.get(name))
    val target=snapshot.resolve(name);Files.createDirectories(target.getParent);Files.write(target,bytes)
    name->sha(bytes)
  }
  val classes=Files.createTempDirectory("v7-source-package-classes-")
  try {
    val arguments=List("-classpath",System.getProperty("java.class.path"),"-d",classes.toString)++selected.map(path=>snapshot.resolve(path).toString)
    require(!dotty.tools.dotc.Main.process(arguments.toArray).hasErrors,"Source workbench packaging compilation failed")
    val walk=Files.walk(classes)
    val entries=try walk.iterator().asScala.filter(path=>Files.isRegularFile(path)).toVector.sortBy(path=>classes.relativize(path).toString) finally walk.close()
    require(entries.nonEmpty,"No source application classes produced")
    val classPins=entries.map(path=>classes.relativize(path).toString.replace('\\','/')->sha(Files.readAllBytes(path)))
    val jarPath=archive.resolve("veri7vn-source-workbench.jar")
    val manifest=new java.util.jar.Manifest()
    manifest.getMainAttributes.putValue("Manifest-Version","1.0")
    manifest.getMainAttributes.putValue("Main-Class","veri7vn.cli.Workbench")
    val jar=new java.util.jar.JarOutputStream(Files.newOutputStream(jarPath),manifest)
    try entries.foreach {path=>
      val entry=new java.util.jar.JarEntry(classes.relativize(path).toString.replace('\\','/'));entry.setTime(0)
      jar.putNextEntry(entry);Files.copy(path,jar);jar.closeEntry()
    } finally jar.close()
    val loader=new java.net.URLClassLoader(Array(jarPath.toUri.toURL),getClass.getClassLoader)
    try {
      val main=loader.loadClass("veri7vn.cli.Workbench")
      require(main.getMethod("main",classOf[Array[String]])!=null,"Source entrypoint is not callable")
      require(main.getProtectionDomain.getCodeSource.getLocation==jarPath.toUri.toURL,"Source entrypoint came from another classpath")
    } finally loader.close()
    val pinMap=pins.toMap
    recorded.foreach(name=>require(sha(Files.readAllBytes(Paths.get(name)))==pinMap(name),"Source changed during packaging: "+name))
    val receipt="{\"format\":\"veri7vn.source-workbench-producer/1\",\"attempt_id\":"+quoted(attempt)+
      ",\"scope\":\"source application compile and classload; native runtime unchecked\",\"sources_sha256\":"+objectJson(pins)+
      ",\"classes_sha256\":"+objectJson(classPins)+",\"java_version\":"+quoted(System.getProperty("java.version"))+"}\n"
    Files.writeString(archive.resolve("receipt.json"),receipt,UTF_8)
    Files.writeString(archive.resolve("artifact.json"),"{\"sha256\":"+quoted(sha(Files.readAllBytes(jarPath)))+"}\n",UTF_8)
    println("SOURCE_WORKBENCH_PACKAGE_PASS "+archive+" source_only_native_unchecked")
  } finally {
    val cleanup=Files.walk(classes)
    try cleanup.sorted(java.util.Comparator.reverseOrder()).forEach(path=>Files.delete(path)) finally cleanup.close()
  }
}
