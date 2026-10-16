package veri7vn.cli
import scala.language.unsafeNulls
import java.nio.file.{Path,Files}
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.workbench.{Authoring,Browser}
import veri7vn.packages.intake.Intake

/** Local source authoring CLI; the workspace lock prevents competing writers. */
object Workbench {
  def run(args:Array[String]):Unit={
    require(args.length>=2,"Usage: workspace command [draft arguments]; commands: list, serve, import-original, import-native, inspect, source, migration, edit")
    val store=new WorkspaceStore(Path.of(args(0)))
    val managed=new ManagedSources(store)
    try {
      val author=new Authoring(managed)
      if(args(1)=="list") {author.list().foreach(println);return}
      if(args(1)=="serve") {
        val browser=new Browser(author);browser.start();println(browser.url)
        println("Press Enter to close the workspace.")
        try scala.io.StdIn.readLine() finally browser.close()
        return
      }
      require(args.length>=3,"A package name is required")
      val draft=args(2)
      args(1) match {
        case "import-original"|"import-native"=>
          require(args.length==5,"import requires source path and operation ID")
          println(author.importSource(args(4),draft,Path.of(args(3)),
            if(args(1)=="import-original")Intake.Format.Oracle7Original else Intake.Format.NativeDevelopment))
        case "inspect"=>
          val s=author.inspect(draft);println("Package "+draft+"\nSource revision "+s.revision.id+"\nEdit token "+s.manifest)
          s.revision.entries.foreach(e=>println(e.path+"\t"+e.content.size+" bytes\t"+e.role))
        case "source"=>require(args.length==4);print(author.source(draft,args(3)).text)
        case "migration"=>
          val report=author.migration(draft)
          report.diagnostics.foreach(d=>println(d.path.getOrElse("Package")+": "+d.message))
          report.candidates.foreach(c=>{println(c.command);c.remainingObligations.foreach(o=>println("Needs work: "+o))})
        case "edit"=>
          require(args.length==11,"edit requires manifest revision path start-byte end-byte expected-file replacement-file operation-ID")
          println(author.edit(args(10),draft,args(3),args(4),args(5),args(6).toInt,args(7).toInt,
            bounded(Path.of(args(8))),bounded(Path.of(args(9)))))
        case other=>throw new IllegalArgumentException("Unknown command: "+other)
      }
    } finally store.close()
  }
  private def bounded(path:Path):Array[Byte]={require(Files.size(path)<=8*1024*1024,"Edit file exceeds 8 MiB");Files.readAllBytes(path)}
  def main(args:Array[String]):Unit=run(args)
}
