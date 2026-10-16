package veri7vn.integration.workshop

import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.RuntimeService
import veri7vn.workbench.{Authoring,ResidentBuildWorkspace,BuildWorkspace}
import veri7vn.packages.intake.Intake

/** Actual managed authoring -> native replay -> source repair -> durable reopen.
  * No fake bridge, evaluator, acknowledgement or restored source is supplied.
  * ArtifactReady is deliberately not described as package activation. */
object WorkshopLifecycleTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-workshop-lifecycle-").toRealPath()
    val workspace=root.resolve("workspace");val images=root.resolve("images")
    val directories=args.toList.map(Path.of(_))
    val source=root.resolve("source");Files.createDirectories(source)
    val path="Stock_Policy.thy"
    val original="""theory Stock_Policy imports Main begin
definition reorder :: "nat => nat => bool" where "reorder stock floor = (stock < floor)"
lemma boundary: "reorder 10 10" by (simp add: reorder_def)
end
"""
    val repaired=original.replace("\"reorder 10 10\"","\"~ reorder 10 10\"")
    Files.writeString(source.resolve(path),original)
    Files.writeString(source.resolve("package.json"),"""{"format":"veri7vn.package/0","package":{"id":"test.stock-policy","version":"1.0.0","title":"Stock policy","description":"Repair an explicit reorder boundary obligation"},"files":[{"path":"Stock_Policy.thy","role":"source"}],"requires":[],"native":{"session":"Stock_Policy","theories":["Stock_Policy"]},"capabilities":[]}""")
    def await(builds:ResidentBuildWorkspace,id:BigInt,expected:String):BuildWorkspace.View={
      val deadline=System.nanoTime()+90L*1000000000
      var view=builds.inspect(id)
      val terminal=Set("ArtifactReady","Failed","Cancelled","Historical")
      while(!view.exists(_.state==expected) && System.nanoTime()<deadline){
        assert(!view.exists(v=>terminal(v.state)),s"Build $id reached unexpected terminal state: $view")
        Thread.sleep(25);view=builds.inspect(id)
      }
      assert(view.exists(_.state==expected),s"Build $id expected $expected, actual $view")
      view.get
    }
    var failed=BigInt(0);var successful=BigInt(0);var candidate=BigInt(0)
    var originalRevision="";var repairedRevision=""
    scala.util.Using.resource(RuntimeService.open(root.resolve("routing-workspace"),images,directories)){service=>
      def sequence():Long=service.client.durableSequence
      val beforeInspection=sequence()
      val question="the sum of -2 and 3"
      val routing=service.client.inspectRoutingDetails(question.getBytes(UTF_8))
      assert(routing.status=="readings" && routing.alternatives.size==1)
      val reading=routing.alternatives.head
      assert(reading.index==0 && reading.operation==0 &&
        reading.literals.map(span=>question.substring(span.start,span.stop))==Vector("-2","3"))
      assert(service.client.inspectRoutingDetails("hello".getBytes(UTF_8)).status=="unrecognized")
      val proposal=service.client.suggestGrowth("double then square")
      assert(proposal.operations==Vector("double","square") && proposal.source.contains("proposed_recipe") && proposal.unsupported.isEmpty)
      val blocked=service.client.suggestGrowth("sort then double")
      assert(blocked.source.isEmpty && blocked.unsupported.contains("sort"))
      assert(sequence()==beforeInspection,"Read-only routing or suggestion changed the authority journal")
      println("WORKSHOP_ROUTING_GROWTH_PASS native readings original spans ordered tentative source unsupported refusal no authority mutation")
      val author=new Authoring(service.managedSources)
      veri7vn.authoring.assistance.RoutingCommandsChecks.run(service.client)
      veri7vn.authoring.assistance.GrowthCommandsChecks.run(service.client,author)
    }
    scala.util.Using.resource(RuntimeService.open(workspace,images,directories)){service=>
      val author=new Authoring(service.managedSources)
      val builds=new ResidentBuildWorkspace(service,author)
      author.importSource("workshop-import","stock-policy",source,Intake.Format.NativeDevelopment)
      val before=author.inspect("stock-policy");originalRevision=before.revision.id
      failed=builds.start(before.draft,before.manifest,path)
      val failure=await(builds,failed,"Failed")
      assert(failure.source.exists(_.revision==originalRevision))
      assert(failure.diagnostic.exists(d=>d.code=="build.replay_failed" && d.message.nonEmpty))
      val edit=author.edit("workshop-boundary-repair",before.draft,before.manifest,
        originalRevision,path,0,original.getBytes(UTF_8).length,original.getBytes(UTF_8),repaired.getBytes(UTF_8))
      assert(Authoring.resultMessage(edit)=="Saved.")
      val after=author.inspect("stock-policy");repairedRevision=after.revision.id
      assert(repairedRevision!=originalRevision)
      assert(builds.inspect(failed).get.source.exists(_.revision==originalRevision))
      successful=builds.start(after.draft,after.manifest,path)
      val ready=await(builds,successful,"ArtifactReady")
      candidate=ready.candidate.get
      assert(ready.source.exists(_.revision==repairedRevision))
    }
    // Exercise the shipped launcher selection too. Supplying BuildWorkspace
    // directly in a test would miss a CLI/browser that never enables Build.
    val cliArgs=Vector("--workspace",workspace.toString,"--images",images.toString)++
      directories.toVector.flatMap(p=>Vector("--session-root",p.toString))++
      Vector("--workbench","build-status",successful.toString)
    val runtimeClasses=Path.of(classOf[veri7vn.runtime.service.RuntimeService]
      .getProtectionDomain.getCodeSource.getLocation.toURI)
    val cliLog=root.resolve("production-cli.log")
    val cliPid=root.resolve("production-cli.pid")
    val javaCommand=Path.of(System.getProperty("java.home"),"bin","java").toString
    val classpath=runtimeClasses.toString+java.io.File.pathSeparator+System.getProperty("java.class.path")
    // RuntimeMain uses Isabelle's Command_Line.tool, which exits its JVM.
    // A separate process both tests that real entry point and leaves these
    // subsequent recovery assertions running in the parent test process.
    val cli=new ProcessBuilder((Vector(javaCommand,"-cp",classpath,
      "veri7vn.runtime.service.RuntimeMain")++cliArgs)*).redirectErrorStream(true)
      .redirectOutput(cliLog.toFile).start()
    Files.writeString(cliPid,cli.pid().toString)
    require(cli.waitFor(120,java.util.concurrent.TimeUnit.SECONDS),
      "Production CLI timed out; owned process PID retained at "+cliPid)
    val cliOutput=Files.readString(cliLog)
    assert(cli.exitValue()==0,"Production CLI failed: "+cliOutput)
    assert(cliOutput.contains("ArtifactReady"),cliOutput)
    assert(cliOutput.contains("Native artifact "+candidate),cliOutput)
    // Closing the whole service forces a new native process and authenticated
    // recovery. Reopening a browser or a client handle is insufficient here.
    scala.util.Using.resource(RuntimeService.open(workspace,images,directories)){service=>
      val author=new Authoring(service.managedSources)
      val builds=new ResidentBuildWorkspace(service,author)
      val failure=await(builds,failed,"Failed")
      assert(failure.source.exists(_.revision==originalRevision))
      assert(failure.diagnostic.exists(d=>d.message.nonEmpty && d.currentSpan.isEmpty))
      val ready=await(builds,successful,"ArtifactReady")
      assert(ready.candidate.contains(candidate) && ready.source.exists(_.revision==repairedRevision))
      assert(author.source("stock-policy",path).text==repaired)
      builds.forget(failed)
      assert(builds.inspect(failed).isEmpty)
      assert(builds.inspect(successful).exists(_.candidate.contains(candidate)))
    }
    scala.util.Using.resource(RuntimeService.open(workspace,images,directories)){service=>
      val builds=new ResidentBuildWorkspace(service,new Authoring(service.managedSources))
      assert(builds.inspect(failed).isEmpty)
      assert(await(builds,successful,"ArtifactReady").candidate.contains(candidate))
      builds.forget(successful)
      assert(builds.inspect(successful).isEmpty)
    }
    println("WORKSHOP_LIFECYCLE_PASS actual native failure repair artifact production CLI fresh-process recovery original-source diagnostics selective Forget second restart")
  }
}
