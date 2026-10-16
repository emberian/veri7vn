package veri7vn.authoring.assistance

import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.ResidentAuthorityService
import veri7vn.workbench.Authoring
import veri7vn.packages.intake.Intake
import veri7vn.diagnostics.Repair

/** Native numeric proposal -> author review -> ordinary managed source edit. */
object GrowthCommands {
  def run(client:ResidentAuthorityService,author:Authoring,args:Array[String]):Unit={
    require(args.length==9 && args(0)=="suggest",
      "suggest requires package, theory path, start byte, stop byte, request, meaning, review reason, operation ID")
    val meaning=Repair.Meaning.valueOf(args(6))
    require(meaning!=Repair.Meaning.Unresolved,"Choose PreserveMeaning, RestrictDomain or ChangeSpecification")
    require(args(7).trim.nonEmpty,"A review reason is required")
    val snapshot=author.inspect(args(1))
    val plan=Assistance.plan(snapshot,args(5),"unreviewed",args(2),args(3).toInt,args(4).toInt)
    require(args(2).endsWith(".thy"),"Choose an editable Isabelle theory body")
    val suggestion=client.suggestGrowth(args(5))
    println("Numeric proposal: "+suggestion.operations.mkString(" → "))
    if(suggestion.unsupported.nonEmpty)println("Unsupported: "+suggestion.unsupported.mkString(", "))
    if(suggestion.source.isEmpty){println("No complete proposal. Revise the request.");return}
    val session=Assistance.review(plan,Assistance.Choice.Obligation,meaning,args(7),
      Intake.Content(suggestion.source.getBytes(UTF_8)))
    println("Package "+snapshot.draft+"; revision "+snapshot.revision.id+"; "+args(2)+" bytes "+args(3)+"–"+args(4))
    println("Meaning: "+meaning+"\nReason: "+args(7))
    println("Original:\n"+Authoring.decode(plan.target.original))
    println("Proposed theory declaration:\n"+suggestion.source)
    println("Requires the mathematics expression imports. Build the edited package to check its context and obligations.")
    println("Type apply to save this source proposal; anything else cancels.")
    if(scala.io.StdIn.readLine()=="apply")println(Assistance.resultMessage(session.applyTo(args(8),author)))
    else {session.cancel();println(Assistance.resultMessage(Assistance.Cancelled))}
  }
}
