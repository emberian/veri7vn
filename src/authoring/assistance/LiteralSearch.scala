package veri7vn.authoring.assistance

import veri7vn.workbench.Authoring

/** Author intent for the fixed native literal-proposition producer. This is
  * neither a prepared native request nor a parsed proposition. The eventual
  * ingress must resolve actual source/context/fact owners and parse this exact
  * slice in the receiver context before it can issue a charged search ticket. */
object LiteralSearch {
  enum Action {
    case Retrieve, Split, Introduce, Assume
    case Apply(index:Int)
    case Simplify(indices:Vector[Int])
  }
  final case class Budget(expansions:Int,frontier:Int,successors:Int,milliseconds:Int) {
    require(expansions>0 && expansions<=10000,"Search expansion bound")
    require(frontier>0 && frontier<=1000,"Search frontier bound")
    require(successors>0 && successors<=16,"Search successor bound")
    require(milliseconds>0 && milliseconds<=30000,"Search time bound")
  }
  final case class Intent private[LiteralSearch](plan:Assistance.Plan,budget:Budget,
    actions:Vector[Action],catalogueSize:Int) {
    /** This local check is advisory. Native ingress must recheck atomically when
      * adopting the source and native owners; currentness grants no authority. */
    def sourceCurrent(authoring:Authoring):Boolean={
      val expected=plan.target.snapshot
      try {
        val actual=authoring.inspect(expected.draft)
        actual.manifest==expected.manifest && actual.revision.id==expected.revision.id
      }catch {case _:IllegalArgumentException=>false}
    }
  }
  def prepare(plan:Assistance.Plan,budget:Budget,actions:Vector[Action],catalogueSize:Int):Intent={
    val t=plan.target
    val entry=t.snapshot.revision.entries.find(_.path==t.path).get
    require(entry.content.size<=1048576,"Search original source byte bound")
    require(t.original.size>0 && t.original.size<=65536,"Search proposition slice byte bound")
    require(catalogueSize>=0 && catalogueSize<=128,"Search managed catalogue bound")
    require(actions.nonEmpty && actions.size<=64,"Search fixed action bound")
    def index(i:Int):Unit=require(i>=0 && i<catalogueSize,"Search fact index outside declared catalogue")
    actions.foreach {
      case Action.Apply(i)=>index(i)
      case Action.Simplify(indices)=>
        require(indices.size<=128,"Search simplification fact bound");indices.foreach(index)
      case _=>()
    }
    Intent(plan,budget,actions,catalogueSize)
  }
  /** Native failure, exhausted exploration and a time limit establish no
    * refutation. Keep these outcome explanations useful without a false claim. */
  def inconclusiveMessage(reason:String):String=reason match {
    case "exhausted"=>"The selected search actions found no proof. The proposition remains unresolved."
    case "budget"=>"Search reached its expansion or frontier budget. The proposition remains unresolved."
    case "deadline"=>"Search reached its time limit. The proposition remains unresolved."
    case "cancelled"=>"Search was cancelled. No proof or refutation follows."
    case _=>"Search did not establish a result. Inspect the actual request diagnostic."
  }
}
