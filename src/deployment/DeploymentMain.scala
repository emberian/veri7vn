package veri7vn.deployment

import java.nio.file.{Files, Path, LinkOption}
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest
import java.net.URLClassLoader
import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import isabelle.JSON

/** Recipient-side inventory verification and dispatch. The bootstrap itself is trusted
  * installation code: hashing its inventoried bytes is not a proof of this verifier. */
object DeploymentMain {
  /** Bounded opt-in observations; elapsed spans use this JVM's clock only. */
  private object Profile {
    val enabled = sys.env.get("VERI7VN_LAUNCH_PROFILE").contains("1")
    private val events = new java.util.concurrent.atomic.AtomicInteger()
    private case class Snapshot(gcCount: Option[Long],gcMillis: Option[Long],heapUsedBytes: Long)
    private def snapshot(): Snapshot = {
      val beans = java.lang.management.ManagementFactory.getGarbageCollectorMXBeans.asScala
      val runtime = Runtime.getRuntime
      def supported(values: Seq[Long]): Option[Long] =
        if(values.nonEmpty && values.forall(_ >= 0)) Some(values.sum) else None
      Snapshot(supported(beans.map(_.getCollectionCount).toVector),supported(beans.map(_.getCollectionTime).toVector),
        runtime.totalMemory-runtime.freeMemory)
    }
    def emit(fields: Map[String,Any]): Unit = if(enabled && events.getAndIncrement() < 32) {
      try System.err.println("VERI7VN_LAUNCH_PHASE "+JSON.Format(fields))
      catch {case _: Exception => ()}
    }
    def instant(phase: String): Unit = if(enabled)
      emit(Map("phase" -> phase,"event" -> "instant","at_ns" -> System.nanoTime(),"clock" -> "jvm-nano-local"))
    def span[A](phase: String)(body: => A): A = if(!enabled) body else {
      val before = snapshot();val start = System.nanoTime();var ok = false
      try {val value = body;ok = true;value}
      finally {
        val end = System.nanoTime();val after = snapshot()
        def delta(a: Option[Long],b: Option[Long]): Any = a.zip(b).map[Any]((x,y) => y-x).getOrElse(null)
        emit(Map("phase" -> phase,"event" -> "span","start_ns" -> start,"end_ns" -> end,
          "clock" -> "jvm-nano-local","status" -> (if(ok) "ok" else "error"),
          "gc_count_delta" -> delta(before.gcCount,after.gcCount),"gc_time_ms_delta" -> delta(before.gcMillis,after.gcMillis),
          "gc_count_supported" -> (before.gcCount.nonEmpty && after.gcCount.nonEmpty),
          "gc_time_supported" -> (before.gcMillis.nonEmpty && after.gcMillis.nonEmpty),
          "gc_support_scope" -> "all-reported-beans",
          "heap_used_bytes_before" -> before.heapUsedBytes,"heap_used_bytes_after" -> after.heapUsedBytes))
      }
    }
    def begin(): Unit = if(enabled) {
      instant("jvm-main-entry")
      // Command_Line.tool may sys.exit inside the native main. This is a process
      // observation, never an inferred successful application close/operation.
      Runtime.getRuntime.addShutdownHook(new Thread(() => instant("jvm-shutdown-observed"),"veri7vn-launch-profile"))
    }
  }
  private final class HashStats {
    var nanos = 0L;var files = 0L;var bytes = 0L
    def emit(): Unit = Profile.emit(Map("phase" -> "verify-artifact-hash-aggregate","event" -> "aggregate",
      "clock" -> "jvm-nano-local","elapsed_ns" -> nanos,"files" -> files,"bytes" -> bytes))
  }
  private type Obj = Map[String, Any]
  private def obj(x: Any): Obj = x match {
    case m: Map[?, ?] if m.keys.forall(_.isInstanceOf[String]) => m.asInstanceOf[Obj]
    case _ => throw new IllegalArgumentException("expected JSON object")
  }
  private def strings(x: Any): List[String] = x match {
    case xs: List[?] if xs.forall(_.isInstanceOf[String]) => xs.asInstanceOf[List[String]]
    case _ => throw new IllegalArgumentException("expected string array")
  }
  private def text(x: Any): String = x match {
    case s: String => s
    case _ => throw new IllegalArgumentException("expected string")
  }
  private def array(x: Any): List[Any] = x match {
    case xs: List[?] => xs
    case _ => throw new IllegalArgumentException("expected array")
  }
  private object StrictJSON extends JSON.Parsers {
    override def json_object: Parser[JSON.Object.T] =
      $$$("{") ~> repsep(string ~ ($$$(":") ~> json_value) ^^ {case a ~ b => (a,b)},$$$(",")) <~ $$$("}") ^^ { entries =>
        require(entries.map(_._1).distinct.size == entries.size, "duplicate JSON object key")
        entries.toMap
      }
  }
  private val hexadecimal = java.util.HexFormat.of()
  private def sha(bytes: Array[Byte]): String =
    hexadecimal.formatHex(MessageDigest.getInstance("SHA-256").digest(bytes))
  private def digest(path: Path,stats: HashStats,bytes: Array[Byte]): String = {
    val started = if(Profile.enabled) System.nanoTime() else 0L
    var readBytes = 0L
    val md = MessageDigest.getInstance("SHA-256")
    val in = Files.newInputStream(path)
    try {
      var n = in.read(bytes)
      while(n != -1) {md.update(bytes,0,n);if(Profile.enabled) readBytes += n;n = in.read(bytes)}
      hexadecimal.formatHex(md.digest())
    } finally {
      in.close()
      if(Profile.enabled) {stats.nanos += System.nanoTime()-started;stats.files += 1;stats.bytes += readBytes}
    }
  }
  private def relative(s: String): Path = {
    val p = Path.of(s)
    require(s.nonEmpty && !p.isAbsolute && p.normalize.toString == s && !p.iterator.asScala.exists(_.toString == ".."),
      "artifact destination must be a normalized relative path")
    p
  }
  private def canonical(path: Path,depth: Int = 0): Path = {
    require(depth < 64,"symlink resolution limit")
    val absolute = path.toAbsolutePath.normalize
    if(Files.isSymbolicLink(absolute)) canonical(absolute.getParent.resolve(Files.readSymbolicLink(absolute)),depth+1)
    else if(Files.exists(absolute)) absolute.toRealPath()
    else {
      require(absolute.getParent != null,"cannot resolve state")
      canonical(absolute.getParent,depth+1).resolve(absolute.getFileName)
    }
  }
  private def artifacts(m: Obj): List[Obj] = array(m("artifacts")).map(obj)
  private def mode(value: Any): Int = value match {
    case n: Number =>
      val d = n.doubleValue
      require(java.lang.Double.isFinite(d) && d >= 0 && d <= 511 && d == Math.rint(d),"invalid artifact mode")
      d.toInt
    case _ => throw new IllegalArgumentException("invalid artifact mode")
  }
  def verify(root: Path): Obj = Profile.span("verify-total") {
    val raw = Profile.span("verify-manifest-read") {
      val input = Files.newInputStream(root.resolve("manifest.json"))
      try input.readNBytes(32*1024*1024+1) finally input.close()
    }
    require(raw.length <= 32*1024*1024,"manifest size limit")
    Profile.span("verify-manifest-identity") {
      if(root.getFileName.toString.length == 64)
        require(sha(raw) == root.getFileName.toString,"generation manifest identity mismatch")
    }
    val json = Profile.span("verify-manifest-decode") {
      val decoder = UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
      decoder.decode(java.nio.ByteBuffer.wrap(raw)).toString
    }
    Profile.span("verify-manifest-lexer") {
    val scanner = new JSON.Lexer.Scanner(isabelle.Scan.char_reader(json))
    var tokens: scala.util.parsing.input.Reader[JSON.Token] = scanner
    var depth = 0
    while(!tokens.atEnd) {
      val token = tokens.first
      if(token.is_keyword("{") || token.is_keyword("[")) depth += 1
      if(token.is_keyword("}") || token.is_keyword("]")) depth -= 1
      require(depth <= 64 && depth >= 0,"manifest JSON nesting limit")
      tokens = tokens.rest
    }
    }
    val m = Profile.span("verify-manifest-parse") {obj(StrictJSON.parse(json,true))}
    require(m("schema") == "veri7vn-local-deployment/1","unsupported deployment schema")
    val entries = artifacts(m)
    val paths = entries.map(e => text(e("path")))
    require(paths.distinct.size == paths.size,"duplicate artifact path")
    val stats = new HashStats
    Profile.span("verify-inventory") {
    // Invocation-local: bounded scratch space without sharing mutable bytes
    // between concurrent callers or allocating a megabyte for every file.
    val hashBuffer = new Array[Byte](1024*1024)
    try entries.foreach { e =>
      val name = text(e("path")); val p = root.resolve(relative(name))
      require(name != "manifest.json" && !name.startsWith("manifest.json/"),"reserved artifact path")
      var parent = p.getParent
      while(parent != root) {
        require(!Files.isSymbolicLink(parent),"symlink artifact parent: "+name)
        parent = parent.getParent
      }
      e.get("link") match {
        case Some(value) =>
          val link = text(value)
          require(Files.isSymbolicLink(p) && Files.readSymbolicLink(p).toString == link &&
            sha(link.getBytes(UTF_8)) == text(e("sha256")) && canonical(p).startsWith(root),
            "changed or escaping link: "+name)
        case None =>
          require(!Files.isSymbolicLink(p) && Files.isRegularFile(p,LinkOption.NOFOLLOW_LINKS) &&
            digest(p,stats,hashBuffer) == text(e("sha256")),"missing or changed artifact: "+name)
          val actualMode = Files.getAttribute(p,"unix:mode").asInstanceOf[Number].intValue & 511
          require(actualMode == mode(e("mode")),"changed artifact mode: "+name)
      }
    } finally stats.emit()}
    m
  }
  private case class Plan(command: List[String], environment: Map[String,String], state: Path)
  private def plan(root: Path,m: Obj,statePath: Path,surface: Option[String],extra: List[String]): Plan = {
    val target = (System.getProperty("os.name"),System.getProperty("os.arch")) match {
      case ("Mac OS X","aarch64" | "arm64") => "macOS-ARM64"
      case ("Linux","amd64" | "x86_64") => "Linux-x86_64"
      case _ => "unsupported"
    }
    require(m("target") == target,"target mismatch; cross-target launch is unqualified")
    val state = canonical(statePath)
    val immutable = if(root.getParent != null && Option(root.getParent.getFileName).exists(_.toString == "generations")) root.getParent else root
    require(!state.startsWith(immutable),"mutable state must be outside immutable generations")
    val selected = surface.map { s =>
      obj(m.getOrElse("surfaces",Map.empty[String,Any])).get(s).map(obj)
        .getOrElse(throw new IllegalArgumentException("surface unavailable in this generation: "+s))
    }.getOrElse(Map.empty[String,Any])
    def expand(s: String): String = s.replace("{package}",root.toString).replace("{state}",state.toString)
    val command = strings(selected.getOrElse("launch",m("launch"))).map(expand) ++
      strings(selected.getOrElse("arguments",Nil)) ++ extra
    require(command.nonEmpty,"deployment has no launch command")
    val executable = Path.of(command.head)
    require(executable.isAbsolute && executable.normalize == executable && executable.startsWith(root),
      "launch executable must belong to staged package")
    require(artifacts(m).exists(e => e("path") == root.relativize(executable).toString &&
      e.get("mode").exists(v => mode(v) == 365)),
      "launch executable is not an inventoried executable artifact")
    val env = (obj(m.getOrElse("environment",Map.empty[String,Any])) ++
      obj(selected.getOrElse("environment",Map.empty[String,Any]))).map((k,v) => k -> expand(text(v)))
    require((env.keySet -- Set("CLASSPATH","USER_HOME")).isEmpty,"unsupported launch environment override")
    Plan(command,env,state)
  }
  private def dispatch(root: Path,m: Obj,p: Plan): Unit = {
    require(strings(m.getOrElse("missing",Nil)).isEmpty,"deployment incomplete")
    require((Set("runtime","heap","host","source","license") -- artifacts(m).map(e => text(e("role"))).toSet).isEmpty,
      "deployment lacks required artifact roles")
    require(p.command.length >= 3 && p.command.head == root.resolve("runtime/bin/isabelle").toString &&
      p.command(1) == "java","unsupported installed launch command")
    val main = p.command(2)
    require(Set("veri7vn.cli.Workbench","veri7vn.runtime.service.RuntimeMain").contains(main),"unsupported installed entrypoint")
    val jars = p.environment.getOrElse("CLASSPATH",throw new IllegalArgumentException("missing surface classpath"))
      .split(java.io.File.pathSeparator).toList.map(Path.of(_))
    require(jars.nonEmpty && jars.forall(j => j.isAbsolute && j.normalize == j && j.startsWith(root) &&
      artifacts(m).exists(e => e("path") == root.relativize(j).toString && e("role") == "host")),
      "surface classpath must contain inventoried package host artifacts")
    require(obj(m.getOrElse("associations",Map.empty[String,Any])).get("bootstrap_user_home").contains("fresh-owned-temporary/1") &&
      p.environment.get("USER_HOME").contains("{bootstrap_home}"),"installed launcher requires fresh-owned-temporary USER_HOME policy")
    val userHome = canonical(Path.of(sys.env.getOrElse("VERI7VN_BOOTSTRAP_HOME",throw new IllegalArgumentException("missing bootstrap home"))))
    require(!userHome.startsWith(root),"mutable user home must be outside immutable generation")
    require(sys.env.get("USER_HOME").exists(s => canonical(Path.of(s)) == userHome),"bootstrap USER_HOME differs from owned temporary home")
    Profile.instant("dispatch-start")
    Files.createDirectories(p.state)
    val loader = new URLClassLoader(jars.map(_.toUri.toURL).toArray,getClass.getClassLoader)
    val thread = Thread.currentThread(); val previous = thread.getContextClassLoader
    try {
      thread.setContextClassLoader(loader)
      Profile.span("dispatch-returned") {
        loader.loadClass(main).getMethod("main",classOf[Array[String]])
          .invoke(null,p.command.drop(3).toArray.asInstanceOf[Object])
      }
    } finally {thread.setContextClassLoader(previous);loader.close()}
  }
  def main(args: Array[String]): Unit = {
    Profile.begin()
    try {
    require(args.length >= 3 && args(0) == "--package","expected --package PINNED-GENERATION command")
    val root = Path.of(args(1)).toRealPath()
    val command = args(2)
    var state: Option[Path] = None; var surface: Option[String] = None; var tutorial: Option[String] = None
    var extra = List.empty[String]; var i = 3
    while(i < args.length) {
      args(i) match {
        case "--" => extra = args.drop(i+1).toList; i = args.length
        case "--state" => require(i+1 < args.length && state.isEmpty,"--state requires one path");state=Some(Path.of(args(i+1)));i+=2
        case "--surface" => require(i+1 < args.length && surface.isEmpty,"--surface requires one name");surface=Some(args(i+1));i+=2
        case "--tutorial" => require(i+1 < args.length && tutorial.isEmpty,"--tutorial requires one name");tutorial=Some(args(i+1));i+=2
        case other => throw new IllegalArgumentException("unknown launcher argument: "+other)
      }
    }
    require(Set("verify","locate","plan","launch").contains(command),"unknown launcher command: "+command)
    val m = verify(root)
    command match {
      case "verify" => require(state.isEmpty && surface.isEmpty && tutorial.isEmpty && extra.isEmpty,"verify takes no options");println(JSON.Format(m))
      case "locate" =>
        require(state.isEmpty && surface.isEmpty && extra.isEmpty,"locate takes only --tutorial")
        val path = tutorial.map { name =>
          val tutorials = obj(obj(m.getOrElse("associations",Map.empty[String,Any])).getOrElse("tutorial_sources",Map.empty[String,Any]))
          val e = obj(tutorials.getOrElse(name,throw new IllegalArgumentException("tutorial unavailable in this generation: "+name)))
          val directory = root.resolve(relative(text(e("root"))))
          val files = strings(e("files")); val sources = artifacts(m).filter(_("role") == "source").map(_("path")).toSet
          require(files.nonEmpty && files.forall(f => sources(f) && root.resolve(relative(f)).startsWith(directory)),"tutorial source closure is not inventoried")
          directory
        }.getOrElse(root)
        println(path)
      case _ =>
        require(tutorial.isEmpty,"--tutorial is only valid for locate")
        val p = Profile.span("launch-plan-resolution") {
          plan(root,m,state.getOrElse(throw new IllegalArgumentException("--state required")),surface,extra)
        }
        if(command == "plan") println(JSON.Format(Map("command" -> p.command,"environment" -> p.environment,
          "missing" -> m.getOrElse("missing",Nil),"qualification_notes" -> m.getOrElse("qualification_notes",Nil))))
        else dispatch(root,m,p)
    }
  } catch {
    case e: java.lang.reflect.InvocationTargetException =>
      System.err.println("deployment: "+Option(e.getCause).getOrElse(e).toString);System.exit(1)
    case e: Exception => System.err.println("deployment: "+e.getMessage);System.exit(1)
  }
  }
}
