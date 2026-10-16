package veri7vn.authoring.assistance

import veri7vn.workbench.Authoring
import veri7vn.diagnostics.{Diagnostics,Repair}
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts

/** Source-owned planning and review of inert edits. Native search/admission is
  * deliberately not represented by caller-supplied theorem or success fields. */
object Assistance {
  enum Choice { case Obligation, Condition, Example }
  enum State { case Reviewing, Cancelled, Applied }
  final case class Target private[Assistance](snapshot:Authoring.Snapshot,
    obligation:String,path:String,start:Int,stop:Int,original:Intake.Content)
  final case class Plan private[Assistance](target:Target,
    diagnosis:Diagnostics.Explanation,choices:Vector[Choice])
  final case class Review private[Assistance](plan:Plan,choice:Choice,proposal:Repair.Proposal) {
    def meaning:Repair.Meaning=proposal.meaning
    def replacement:Intake.Content=proposal.edit.replacement
  }
  sealed trait Applied
  final case class Saved(result:ManagedDrafts.Result) extends Applied
  case object Cancelled extends Applied
  case object StaleSource extends Applied
  case object SourceUnavailable extends Applied
  case object AlreadyApplied extends Applied

  def resultMessage(result:Applied):String=result match {
    case Saved(saved)=>Authoring.resultMessage(saved)
    case Cancelled=>"Review cancelled. No edit was applied."
    case StaleSource=>"The source changed after this review. Reopen it and review the proposal again."
    case SourceUnavailable=>"This package is no longer available. Refresh the package list."
    case AlreadyApplied=>"This review was already applied. Reopen the source before making another edit."
  }

  /** Pins the original bytes, not a later editor buffer or a diagnostic summary.
    * Obligation labels identify author work; they assert no native proposition. */
  def plan(snapshot:Authoring.Snapshot,obligation:String,status:String,
    path:String,start:Int,stop:Int):Plan={
    require(obligation.trim.nonEmpty,"Select an explicit obligation")
    val entry=snapshot.revision.entries.find(_.path==path)
      .getOrElse(throw new IllegalArgumentException("Obligation source unavailable"))
    val bytes=entry.content.bytes
    require(start>=0 && stop>start && stop<=bytes.length,"Select a nonempty source span")
    val original=Intake.Content(java.util.Arrays.copyOfRange(bytes,start,stop))
    // Validate UTF-8 boundaries with the same validator used for final edits.
    Intake.patch(snapshot.revision,snapshot.revision.id,
      Vector(Intake.Edit(path,start,stop,original,original)))
    Plan(Target(snapshot,obligation,path,start,stop,original),Diagnostics.explain(status),Choice.values.toVector)
  }

  /** Choice and meaning are explicit author decisions. Examples remain proposed
    * source material; a blank answer cannot acquire a ground-truth label here. */
  def review(plan:Plan,choice:Choice,meaning:Repair.Meaning,reason:String,
    replacement:Intake.Content):Session={
    require(meaning!=Repair.Meaning.Unresolved,"Review the effect on meaning before applying")
    val t=plan.target;val s=t.snapshot
    val proposal=Repair.propose(s.draft,s.manifest,s.revision,plan.diagnosis.code,
      meaning,reason,t.path,t.start,t.stop,replacement)
    new Session(Review(plan,choice,proposal))
  }

  /** A review has one local apply/cancel boundary. The managed source service
    * still owns durable operation identity, stale-head checks and commit state. */
  final class Session private[Assistance](val review:Review) {
    private var current=State.Reviewing
    def state:State=synchronized {current}
    def cancel():Boolean=synchronized {
      if(current==State.Reviewing){current=State.Cancelled;true}else false
    }
    def applyTo(operation:String,authoring:Authoring):Applied=synchronized {
      if(current==State.Cancelled)Cancelled
      else if(current==State.Applied)AlreadyApplied
      else {
        val t=review.plan.target;val snapshot=t.snapshot
        val now=try Some(authoring.inspect(snapshot.draft))
          catch {case _:IllegalArgumentException=>None}
        if(now.isEmpty)SourceUnavailable
        else if(now.get.manifest!=snapshot.manifest || now.get.revision.id!=snapshot.revision.id)StaleSource
        else {
          val e=review.proposal.edit
          val result=authoring.edit(operation,snapshot.draft,snapshot.manifest,snapshot.revision.id,
            e.path,e.start,e.end,e.expected.bytes,e.replacement.bytes)
          result match {
            case ManagedDrafts.Recorded(receipt,_) if receipt.status.toString=="Committed"=>current=State.Applied
            case _=>()
          }
          Saved(result)
        }
      }
    }
  }
}
