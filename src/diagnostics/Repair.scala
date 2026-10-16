package veri7vn.diagnostics

import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts

/** An explicit source change, reviewed before a normal draft edit. The edit is
  * inert development material; revalidation and activation are separate operations. */
object Repair {
  enum Meaning { case PreserveMeaning, RestrictDomain, ChangeSpecification, Unresolved }
  final case class Proposal private[Repair](draft:String,manifest:String,revision:String,
    diagnosticCode:String,meaning:Meaning,reason:String,edit:Intake.Edit) {
    def applyTo(operation:String,drafts:ManagedDrafts):ManagedDrafts.Result=
      drafts.edit(operation,draft,manifest,revision,Vector(edit))
  }
  def propose(draft:String,manifest:String,revision:Intake.Revision,diagnosticCode:String,
    meaning:Meaning,reason:String,path:String,start:Int,stop:Int,replacement:Intake.Content):Proposal={
    require(draft.nonEmpty && manifest.nonEmpty && diagnosticCode.nonEmpty && reason.trim.nonEmpty,
      "Repair requires an attributable diagnostic and review reason")
    val source=revision.entries.find(_.path==path).getOrElse(throw new IllegalArgumentException("Repair source unavailable"))
    val bytes=source.content.bytes
    require(start>=0 && stop>=start && stop<=bytes.length,"Repair span outside source")
    val expected=Intake.Content(java.util.Arrays.copyOfRange(bytes,start,stop))
    val edit=Intake.Edit(path,start,stop,expected,replacement)
    // Reuse the authoritative source patch validator, including UTF-8 boundaries.
    Intake.patch(revision,revision.id,Vector(edit))
    Proposal(draft,manifest,revision.id,diagnosticCode,meaning,reason,edit)
  }
}
