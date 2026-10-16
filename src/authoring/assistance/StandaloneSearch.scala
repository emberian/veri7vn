package veri7vn.authoring.assistance

import veri7vn.packages.intake.Intake
import veri7vn.runtime.service.search.SearchIngress

/** Actual consumer of the fixed resident search service. The original standalone
  * proposition is separate from an editable package or failed declaration. Native
  * ingress owns parsing, context selection, resource charging and proof checking. */
object StandaloneSearch {
  final case class Observation(summary:String,result:SearchIngress.Result)
  /** Retain the typed result and trace, including truncation and native evidence
    * references, alongside concise text. A summary never becomes a proof script
    * or an editable theorem, and is never reparsed to drive later reasoning. */
  def inspect(ingress:SearchIngress,request:SearchIngress.Request):Observation={
    val result=ingress.poll(request)
    val summary=result match {
      case SearchIngress.Pending=>"Search is still running."
      case _:SearchIngress.Proved=>
        "The resident admitted a consequence for the selected proposition. Inspect its exact proposition, dependencies and search trace."
      case SearchIngress.Unresolved(reason,_,_)=>reason match {
        case SearchIngress.Stop.Exhausted=>LiteralSearch.inconclusiveMessage("exhausted")
        case SearchIngress.Stop.Budget=>LiteralSearch.inconclusiveMessage("budget")
        case SearchIngress.Stop.Deadline=>LiteralSearch.inconclusiveMessage("deadline")
        case SearchIngress.Stop.Cancelled=>LiteralSearch.inconclusiveMessage("cancelled")
        case SearchIngress.Stop.Failed=>"Search failed. The proposition remains unresolved; inspect the native diagnostic."
        case SearchIngress.Stop.Unavailable=>"Search or its dependencies are unavailable. No proof or refutation follows."
      }
    }
    Observation(summary,result)
  }
  def cancel(ingress:SearchIngress,request:SearchIngress.Request):Unit=ingress.cancel(request)

  def submit(ingress:SearchIngress,context:SearchIngress.Context,original:Intake.Content,
    budget:LiteralSearch.Budget,actions:Vector[LiteralSearch.Action],
    catalogue:Vector[String]=Vector.empty):SearchIngress.Request={
    require(original.size>0 && original.size<=65536,"Standalone proposition byte bound")
    // Strict UTF-8 decoding validates the original without normalizing its bytes.
    veri7vn.workbench.Authoring.decode(original)
    require(catalogue.size<=128,"Search managed catalogue bound")
    require(actions.nonEmpty && actions.size<=64,"Search fixed action bound")
    def index(i:Int):Unit=require(i>=0 && i<catalogue.size,"Search fact index outside catalogue")
    val fixed=actions.map {
      case LiteralSearch.Action.Retrieve=>SearchIngress.Action.Retrieve
      case LiteralSearch.Action.Split=>SearchIngress.Action.Split
      case LiteralSearch.Action.Introduce=>SearchIngress.Action.Introduce
      case LiteralSearch.Action.Assume=>SearchIngress.Action.Assume
      case LiteralSearch.Action.Apply(i)=>index(i);SearchIngress.Action.Apply(i)
      case LiteralSearch.Action.Simplify(indices)=>
        require(indices.size<=128,"Search simplification fact bound")
        indices.foreach(index);SearchIngress.Action.Simplify(indices)
    }
    ingress.propose(context,original.bytes,
      SearchIngress.Budget(budget.expansions,budget.frontier,budget.successors,budget.milliseconds),fixed,catalogue)
  }
}
