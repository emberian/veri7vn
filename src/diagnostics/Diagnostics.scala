package veri7vn.diagnostics

/** Read-only explanations of resident observations. These values never grant
  * admission, select an interpretation, or license result HTML. */
object Diagnostics {
  enum Outcome {
    case Pending, Accepted, NeedsInput, Declined, Inconclusive, Failed, Cancelled, Unavailable
  }
  enum Action {
    case Wait, InspectInterpretation, EditInput, InspectDomain, ReviewAdmission,
      RetryWithBudget, InspectDependencies, StartNewRequest, Refresh
  }
  final case class Explanation(code:String,outcome:Outcome,title:String,detail:String,actions:Vector[Action])
  def explain(status:String):Explanation = status match {
    case "pending"=>Explanation("execution.pending",Outcome.Pending,"Still running",
      "No accepted result is available yet.",Vector(Action.Wait))
    case "accepted_exact"=>Explanation("result.accepted",Outcome.Accepted,"Accepted exact result",
      "The resident service supplied licensed result content. Inspect the request for its selected interpretation and execution provenance.",Vector(Action.InspectInterpretation))
    case "undefined"=>Explanation("execution.domain",Outcome.Declined,"Outside the operation's domain",
      "The selected operation returned undefined. Review its inputs and domain; this is not a false answer to the request.",Vector(Action.InspectDomain,Action.EditInput))
    case "missing_parameters"|"needs_literal"=>Explanation("interpretation.literal",Outcome.NeedsInput,"A parameter needs attention",
      "The selected request has a missing or unsupported literal. Review the original input and its declared literal codec.",Vector(Action.InspectInterpretation,Action.EditInput))
    case "needs_selection"=>Explanation("interpretation.ambiguous",Outcome.NeedsInput,"Choose an interpretation",
      "The native elaborator requires an explicit choice between readings before execution.",Vector(Action.InspectInterpretation))
    case "invalid_syntax"=>Explanation("interpretation.unrecognized",Outcome.Declined,"Input is outside the supported syntax",
      "The selected operation could not interpret this input. This does not refute the intended claim.",Vector(Action.EditInput))
    case "budget"=>Explanation("execution.budget",Outcome.Inconclusive,"Budget exhausted",
      "Execution did not establish an answer within its budget. No negative claim follows from this outcome.",Vector(Action.RetryWithBudget))
    case "timeout"=>Explanation("execution.timeout",Outcome.Inconclusive,"Time limit reached",
      "The observer stopped waiting before an answer was established. Inspect or cancel the existing request before starting another.",Vector(Action.Refresh))
    case "cancelled"=>Explanation("execution.cancelled",Outcome.Cancelled,"Request is no longer active",
      "The native request is not live. Cancellation or dependency retirement can cause this status; the current API does not distinguish them.",Vector(Action.InspectDependencies,Action.StartNewRequest))
    case "execution.handoff_rejected"=>Explanation(status,Outcome.Failed,"Execution handoff was rejected",
      "The native service rejected dispatch before it could publish a result. Inspect the pinned request and dependency state.",Vector(Action.InspectDependencies))
    case "execution.failure"=>Explanation(status,Outcome.Failed,"Execution failed",
      "The native worker failed. This status does not identify an admission failure or refute the requested claim.",Vector(Action.InspectDependencies))
    case "admission.unresolved_obligation"=>Explanation(status,Outcome.Declined,"Admission has an unresolved obligation",
      "The candidate has not satisfied the required admission condition. Editing or retrying cannot bypass that condition.",Vector(Action.ReviewAdmission))
    case _=>Explanation("execution.unavailable",Outcome.Unavailable,"Diagnostic detail unavailable",
      "The resident returned an outcome this client does not recognize. Refresh with a compatible client; no result is inferred.",Vector(Action.Refresh))
  }
  def actionText(action:Action):String=action match {
    case Action.Wait=>"Wait for the result"
    case Action.InspectInterpretation=>"Inspect the selected interpretation"
    case Action.EditInput=>"Review and edit the original input"
    case Action.InspectDomain=>"Review the operation's domain conditions"
    case Action.ReviewAdmission=>"Review the failed admission obligation"
    case Action.RetryWithBudget=>"Review the execution budget before a new request"
    case Action.InspectDependencies=>"Inspect the request's dependencies"
    case Action.StartNewRequest=>"Start a new request after reviewing the cause"
    case Action.Refresh=>"Refresh the request inspection"
  }
}
