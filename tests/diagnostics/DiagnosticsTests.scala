package veri7vn.diagnostics

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.intake.Intake
import veri7vn.workbench.Authoring
import isabelle.{XML,Markup,YXML}

object DiagnosticsTests {
  private def rejects(body: => Any):Unit={
    var rejected=false;try body catch {case _:IllegalArgumentException=>rejected=true};assert(rejected)
  }
  def main(args:Array[String]):Unit={
    BuildFailureTests.run()
    SourceDiagnosticTests.run()
    PackageImpactTests.run()
    assert(Diagnostics.explain("budget").outcome==Diagnostics.Outcome.Inconclusive)
    assert(Diagnostics.explain("timeout").outcome==Diagnostics.Outcome.Inconclusive)
    assert(Diagnostics.explain("cancelled").outcome==Diagnostics.Outcome.Cancelled)
    assert(Diagnostics.explain("execution.failure").outcome==Diagnostics.Outcome.Failed)
    assert(Diagnostics.explain("undefined").outcome==Diagnostics.Outcome.Declined)
    assert(Diagnostics.explain("unrecognized_future_status").outcome==Diagnostics.Outcome.Unavailable)
    val attrs=List("request","goal","interpretation","decision","capability","operation",
      "semantic_generation","executable_generation","execution").zipWithIndex.map{case(k,i)=>(k,(i+1).toString)}
    def elem(name:String,p:List[(String,String)],body:List[XML.Tree]=Nil)=XML.Elem(Markup(name,p),body)
    val frame=YXML.string_of_body(List(elem("veri7vn-request-inspection",List("version"->"1","status"->"budget","family"->"mathematics"),
      List(elem("identity",attrs),elem("reading",List("index"->"0","operation"->"sum","input_bytes"->"18"),
        List(elem("literal",List("start"->"11","stop"->"12")),elem("literal",List("start"->"17","stop"->"18"))))))))
    val inspection=RequestInspection.parse(frame,BigInt(1))
    assert(inspection.reading.get.literals==Vector(RequestInspection.Span(11,12),RequestInspection.Span(17,18)))
    rejects(RequestInspection.parse(frame,BigInt(2)))
    rejects(RequestInspection.parse(frame.replace("mathematics","source"),BigInt(1)))
    rejects(RequestInspection.parse(frame.replace("input_bytes=18","input_bytes=1"),BigInt(1)))
    val invalidatedFrame=YXML.string_of_body(List(elem("veri7vn-request-inspection",
      List("version"->"1","status"->"cancelled","family"->"mathematics"),
      List(elem("identity",attrs),elem("reading-unavailable",List("reason"->"invalidated"))))))
    val invalidated=RequestInspection.parse(invalidatedFrame,BigInt(1))
    assert(invalidated.reading.isEmpty && invalidated.readingUnavailable.contains("invalidated"))

    val root=Files.createTempDirectory("v7-diagnostic-workspace-").toRealPath()
    val source=Files.createTempDirectory("v7-diagnostic-source-").toRealPath()
    val original="theory Repair imports Main begin\n(* λ retained *)\nlemma target: \"sqrt (x*x) = x\"\nend\n"
    Files.write(source.resolve("Repair.thy"),original.getBytes(UTF_8))
    Files.write(source.resolve("package.json"),"{}".getBytes(UTF_8))
    val store=new WorkspaceStore(root)
    try {
      val managed=new ManagedSources(store);val drafts=new ManagedDrafts(managed);val author=new Authoring(managed)
      author.importSource("diagnostic-import","repair",source,Intake.Format.NativeDevelopment)
      val captured=author.inspect("repair")
      val bytes=original.getBytes(UTF_8)
      val start=original.substring(0,original.indexOf("= x")+2).getBytes(UTF_8).length
      val proposal=Repair.propose("repair",captured.manifest,captured.revision,"admission.unresolved_obligation",
        Repair.Meaning.ChangeSpecification,"Use the absolute value branch rather than restrict x to nonnegative values.",
        "Repair.thy",start,start+1,Intake.Content("abs x".getBytes(UTF_8)))
      assert(author.inspect("repair").revision.id==captured.revision.id) // proposal has no effects
      assert(proposal.applyTo("diagnostic-repair",drafts).isInstanceOf[ManagedDrafts.Recorded])
      val current=author.source("repair","Repair.thy")
      assert(current.text.contains("sqrt (x*x) = abs x") && current.text.contains("λ retained"))
      assert(current.snapshot.revision.id!=captured.revision.id)
      assert(proposal.applyTo("diagnostic-stale",drafts)==ManagedDrafts.Conflict)
      val lambda=original.substring(0,original.indexOf("λ")).getBytes(UTF_8).length
      rejects(Repair.propose("repair",captured.manifest,captured.revision,"execution.domain",Repair.Meaning.Unresolved,
        "Review Unicode boundary","Repair.thy",lambda+1,lambda+2,Intake.Content(Array.emptyByteArray)))
      managed.forget("repair")
      assert(proposal.applyTo("diagnostic-forgotten",drafts)==ManagedDrafts.Unavailable)
    }finally store.close()
    println("DIAGNOSTICS_PASS outcome distinctions closed owner-frame parser exact Unicode source repair stale conflict Forget; no native proof/admission claim")
  }
}
