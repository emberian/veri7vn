package veri7vn.authoring.assistance

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.workbench.Authoring
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.diagnostics.Repair

object AssistanceTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-assistance-workspace-").toRealPath()
    val source=Files.createTempDirectory("v7-assistance-source-").toRealPath()
    val original="theory Example imports Main begin\n(* preserve custom text λ *)\nlemma branch: \"(x::int) = x\" by simp\nend\n"
    Files.write(source.resolve("Example.thy"),original.getBytes(UTF_8))
    Files.write(source.resolve("package.json"),"{}".getBytes(UTF_8))
    val store=new WorkspaceStore(root)
    try {
      val managed=new ManagedSources(store)
      val client=new Authoring(managed)
      client.importSource("import","example",source,Intake.Format.NativeDevelopment)
      val snapshot=client.inspect("example")
      val bytes=original.getBytes(UTF_8)
      val start=new String(bytes,UTF_8).take(original.indexOf("(x::int)")).getBytes(UTF_8).length
      val stop=start+"(x::int) = x".getBytes(UTF_8).length
      val plan=Assistance.plan(snapshot,"branch","budget","Example.thy",start,stop)
      assert(plan.diagnosis.outcome==veri7vn.diagnostics.Diagnostics.Outcome.Inconclusive)
      assert(plan.choices.contains(Assistance.Choice.Condition))
      val search=LiteralSearch.prepare(plan,LiteralSearch.Budget(32,16,4,1000),
        Vector(LiteralSearch.Action.Introduce,LiteralSearch.Action.Simplify(Vector.empty)),0)
      assert(search.sourceCurrent(client))
      var badFact=false
      try LiteralSearch.prepare(plan,search.budget,Vector(LiteralSearch.Action.Apply(0)),0)
      catch {case _:IllegalArgumentException=>badFact=true}
      assert(badFact)
      var badBudget=false
      try LiteralSearch.Budget(10001,16,4,1000)
      catch {case _:IllegalArgumentException=>badBudget=true}
      assert(badBudget)
      assert(LiteralSearch.inconclusiveMessage("exhausted").contains("remains unresolved"))
      def proposal()=Assistance.review(plan,Assistance.Choice.Obligation,Repair.Meaning.PreserveMeaning,
        "Rename the bound variable explicitly",Intake.Content("(y::int) = y".getBytes(UTF_8)))
      val cancelled=proposal();assert(cancelled.cancel())
      assert(cancelled.applyTo("cancelled",client)==Assistance.Cancelled)
      assert(client.inspect("example").revision.id==snapshot.revision.id)
      val applied=proposal()
      assert(applied.applyTo("apply",client).isInstanceOf[Assistance.Saved])
      assert(applied.state==Assistance.State.Applied)
      assert(!applied.cancel() && applied.applyTo("again",client)==Assistance.AlreadyApplied)
      assert(client.source("example","Example.thy").text==original.replace("(x::int) = x","(y::int) = y"))
      assert(proposal().applyTo("stale",client)==Assistance.StaleSource)
      assert(!search.sourceCurrent(client))
      var unresolved=false
      try Assistance.review(plan,Assistance.Choice.Condition,Repair.Meaning.Unresolved,"unknown",Intake.Content(bytes))
      catch {case _:IllegalArgumentException=>unresolved=true}
      assert(unresolved)
      val restricted=Assistance.review(plan,Assistance.Choice.Condition,Repair.Meaning.RestrictDomain,
        "Require a nonnegative argument",Intake.Content("0 ≤ x ⟹ (x::int) = x".getBytes(UTF_8)))
      val changed=Assistance.review(plan,Assistance.Choice.Obligation,Repair.Meaning.ChangeSpecification,
        "Choose a different claimed result",Intake.Content("(x::int) + 0 = x".getBytes(UTF_8)))
      assert(restricted.review.meaning!=changed.review.meaning)
      assert(restricted.review.plan.target.original.bytes.sameElements("(x::int) = x".getBytes(UTF_8)))
      managed.forget("example")
      assert(proposal().applyTo("forgotten",client)==Assistance.SourceUnavailable)
      println("ASSISTANCE_PASS source pin explicit choices meaning review managed edit stale cancellation custom UTF8")
    }finally store.close()
  }
}
