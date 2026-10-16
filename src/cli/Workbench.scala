package veri7vn.cli
import scala.language.unsafeNulls
import java.nio.file.{Path,Files}
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.workbench.{Authoring,Browser}
import veri7vn.packages.intake.Intake
import veri7vn.authoring.assistance.Assistance
import veri7vn.diagnostics.Repair

/** Local source authoring CLI; the workspace lock prevents competing writers. */
object Workbench {
  def run(args:Array[String]):Unit={
    require(args.length>=2,"Usage: workspace command [draft arguments]; commands: list, serve, import-original, import-native, inspect, impact, source, migration, edit, review")
    val store=new WorkspaceStore(Path.of(args(0)))
    val managed=new ManagedSources(store)
    try {
      runAuthoring(new Authoring(managed),args.drop(1))
    } finally store.close()
  }
  /** Reuses an existing workspace owner, including the resident installation. */
  private[cli] def runAuthoring(author:Authoring,args:Array[String]):Unit={
    require(args.nonEmpty,"A source command is required")
      if(args(0)=="list") {author.list().foreach(println);return}
      if(args(0)=="serve") {
        val browser=new Browser(author);browser.start();println(browser.url)
        println("Press Enter to close the workspace.")
        try scala.io.StdIn.readLine() finally browser.close()
        return
      }
      require(args.length>=2,"A package name is required")
      val draft=args(1)
      args(0) match {
        case "import-original"|"import-native"=>
          require(args.length==4,"import requires source path and operation ID")
          println(author.importSource(args(3),draft,Path.of(args(2)),
            if(args(0)=="import-original")Intake.Format.Oracle7Original else Intake.Format.NativeDevelopment))
        case "inspect"=>
          val s=author.inspect(draft);println("Package "+draft+"\nSource revision "+s.revision.id+"\nEdit token "+s.manifest)
          s.revision.entries.foreach(e=>println(e.path+"\t"+e.content.size+" bytes\t"+e.role))
          try {
            val descriptor=author.describe(draft).descriptor
            println("Declared package: "+descriptor.key.id+" @ "+descriptor.key.version)
            descriptor.dependencies.foreach(k=>println("Pinned dependency: "+k.id+" @ "+k.version))
            descriptor.exports.foreach(e=>println("Declared capability: "+e.id+" — "+e.specification.theory+"."+e.specification.name))
            println("Source inspection does not establish native admission.")
          } catch {case problem:IllegalArgumentException=>println("Package descriptor needs attention: "+problem.getMessage)}
        case "impact"=>
          require(args.length==2,"impact requires a package name")
          val view=author.impact(draft)
          println(view.scope+"\n"+view.qualification)
          view.target.foreach(target=>println("Selected source revision: "+target.revision))
          view.affected.foreach(row=>println("Inspected dependency path: "+row.consumer.draft+"; "+row.pathToTarget.mkString(" -> ")+"; revision "+row.consumer.revision))
          view.issues.foreach(issue=>println("Inspection limit: "+veri7vn.diagnostics.PackageImpact.issueText(issue)))
          view.inspected.foreach(pkg=>println("Inspected: "+pkg.draft+"; "+pkg.key.id+" @ "+pkg.key.version+"; revision "+pkg.revision))
        case "source"=>require(args.length==3);print(author.source(draft,args(2)).text)
        case "migration"=>
          val report=author.migration(draft)
          report.diagnostics.foreach(d=>println(d.path.getOrElse("Package")+": "+d.message))
          report.candidates.foreach(c=>{println(c.command);c.remainingObligations.foreach(o=>println("Needs work: "+o))})
        case "review"=>
          require(args.length==11,"review requires path start-byte end-byte work-item change-kind meaning reason replacement-file operation-ID")
          val snapshot=author.inspect(draft)
          val plan=Assistance.plan(snapshot,args(5),"unreviewed",args(2),args(3).toInt,args(4).toInt)
          val session=Assistance.review(plan,Assistance.Choice.valueOf(args(6)),Repair.Meaning.valueOf(args(7)),args(8),Intake.Content(bounded(Path.of(args(9)))))
          println("Author-selected source change; no native check result is asserted.")
          println("Captured revision "+snapshot.revision.id+"; "+args(2)+" bytes "+args(3)+"–"+args(4))
          println("Meaning: "+session.review.meaning+"\nReason: "+args(8))
          println("Original:\n"+Authoring.decode(plan.target.original)+"\nReplacement:\n"+Authoring.decode(session.review.replacement))
          println("Type apply to record this source change; anything else cancels.")
          if(scala.io.StdIn.readLine()=="apply")println(Assistance.resultMessage(session.applyTo(args(10),author)))
          else {session.cancel();println(Assistance.resultMessage(Assistance.Cancelled))}
        case "edit"=>
          require(args.length==10,"edit requires manifest revision path start-byte end-byte expected-file replacement-file operation-ID")
          println(author.edit(args(9),draft,args(2),args(3),args(4),args(5).toInt,args(6).toInt,
            bounded(Path.of(args(7))),bounded(Path.of(args(8)))))
        case other=>throw new IllegalArgumentException("Unknown command: "+other)
      }
  }
  private def bounded(path:Path):Array[Byte]={
    val input=Files.newInputStream(path)
    try {
      val bytes=input.readNBytes(8*1024*1024+1)
      require(bytes.length<=8*1024*1024,"Edit file exceeds 8 MiB");bytes
    } finally input.close()
  }
  def main(args:Array[String]):Unit=run(args)
}
