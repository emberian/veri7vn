import isabelle.*
import scala.language.unsafeNulls
import scala.jdk.CollectionConverters.*
import java.nio.file.{Files,Paths}

@main def exportDeploymentClosure():Unit=Command_Line.tool {
  val output=Paths.get("var/deployment-closure-"+java.util.UUID.randomUUID().toString)
  require(!Files.exists(output),"closure output already exists; preserve previous capture")
  Files.createDirectories(output)
  val roots=Files.readAllLines(Paths.get("deployment/production-roots.txt")).asScala.toList.filter(_.nonEmpty).map(p=>Paths.get(p).toAbsolutePath.toString)
  def rootDirectory(path:String):String={
    var current=Paths.get(path)
    while(current!=null && !Files.isRegularFile(current.resolve("ROOT")))current=current.getParent
    require(current!=null,"session ROOT unavailable: "+path)
    current.toString
  }
  val resources=Headless.Resources.make(Options.init()+"threads=2","Veri7vn_Runtime_Service",Logger.none,session_dirs=roots.map(Path.explode))
  val background=resources.parent_background
  val names=background.sessions_structure.selection("Veri7vn_Runtime_Service").build_requirements(List("Veri7vn_Runtime_Service"))
  val store=resources.store
  val records=names.map { name=>
    val selected=store.get_session(name)
    val heap=selected.the_heap
    val database=selected.log_db.getOrElse(error("missing local build database: "+name))
    val db=SQLite.open_database(database)
    try {
      val build=store.read_build(db,name).getOrElse(error("missing build record: "+name))
      require(build.ok,"unsuccessful build: "+name)
      val sources=store.read_sources(db,name).zipWithIndex.map {case(source,index)=>
        val path=output.resolve("sources").resolve(name).resolve(index.toString)
        Files.createDirectories(path.getParent)
        Bytes.write(path.toFile,source.bytes)
        JSON.Object("name"->source.name,"digest"->source.digest.rep,"snapshot"->path.toAbsolutePath.toString)
      }
      JSON.Object("session"->name,"heap"->heap.file.getAbsolutePath,"database"->database.file.getAbsolutePath,
        "directory"->background.sessions_structure(name).dir.file.getAbsolutePath,"uuid"->build.uuid,
        "input_heaps"->build.input_heaps.toString,"output_heap"->build.output_heap.toString,"sources_conditions"->build.sources_conditions.toString,"sources"->sources)
    } finally db.close()
  }
  File.write(Path.explode(output.resolve("closure.json").toString),JSON.Format(JSON.Object(
    "session"->"Veri7vn_Runtime_Service","isabelle_home"->Isabelle_System.getenv("ISABELLE_HOME"),
    "ml_platform"->store.ml_settings.ml_platform,
    "session_roots"->background.sessions_structure.imports_requirements(List("Veri7vn_Runtime_Service")).map(name=>rootDirectory(background.sessions_structure(name).dir.file.getAbsolutePath)).distinct,
    "records"->records)))
  println("DEPLOYMENT_CLOSURE_PASS "+output.toAbsolutePath+" "+names.mkString(","))
}
