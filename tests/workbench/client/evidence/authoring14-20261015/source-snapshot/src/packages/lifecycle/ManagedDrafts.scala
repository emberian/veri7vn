package veri7vn.packages.lifecycle

import veri7vn.packages.intake.{Intake,ByteObjects,SourceObjects}
import Intake.{Revision,Staged,Edit,Limits,Rejected}
import veri7vn.runtime.host.ManagedSources

/** Source-service consumer of the host's durable prepared-operation ledger.
  * Results describe inert source commits; none implies native admission/publication.
  * No locator/object-store endpoint is exposed to callers by an operation receipt.
  */
final class ManagedDrafts(host:ManagedSources,limits:Limits=Limits()) {
  import ManagedDrafts.*
  private def staged(stage:ManagedSources#Stage):SourceObjects = new SourceObjects(new ByteObjects {
    def put(bytes:Array[Byte]):String=stage.put(bytes)
    def read(id:String,maxBytes:Long):Array[Byte]=stage.read(id,maxBytes)
  },limits)
  private def readObjects(scope:ManagedSources#ReadScope):SourceObjects = new SourceObjects(new ByteObjects {
    def put(bytes:Array[Byte]):String=throw new UnsupportedOperationException("Read-only source scope")
    def read(id:String,maxBytes:Long):Array[Byte]=scope.read(id,maxBytes)
  },limits)
  private def result(commit:ManagedSources.Commit):Result = commit match {
      case ManagedSources.Published(receipt)=>Recorded(receipt,false)
      case ManagedSources.Conflict=>Conflict
      case ManagedSources.CommitUnavailable=>Unavailable
    }
  private def commit(stage:ManagedSources#Stage,objects:SourceObjects,locator:String):Result =
    result(stage.commit(locator,objects.referenceClosure(locator).toVector.sorted))
  private def begin(operation:String,request:Array[Byte],draft:String,expected:Option[String])
    (run:ManagedSources#Stage=>Result):Result = host.begin(operation,request,draft,expected) match {
    case ManagedSources.Fresh(stage)=>run(stage)
    case ManagedSources.Replay(receipt)=>Recorded(receipt,true)
    case ManagedSources.IdentityMismatch=>IdentityMismatch
    case ManagedSources.Unavailable=>Unavailable
  }
  def create(operation:String,draft:String,source:Staged):Result = {
    // Validate actual immutable bytes before allocating any managed stage.
    Intake.recoverStage(source.format,source.entries,source.identity,source.originalArchive,source.originLabel,limits)
    begin(operation,OperationIdentity.create(draft,source),draft,None) {stage=>
      val objects=staged(stage)
      val original=objects.preserve(source)
      val locator=objects.revision(Intake.initial(source),Some(original.record))
      commit(stage,objects,locator)
    }
  }
  def edit(operation:String,draft:String,expectedLocator:String,expectedRevision:String,edits:Vector[Edit]):Result =
    begin(operation,OperationIdentity.edit(draft,expectedLocator,expectedRevision,edits),draft,Some(expectedLocator)) {stage=>
      val snapshot=host.withHead(draft) {(current,scope)=>
        if(current!=expectedLocator) None
        // Both source and original association are materialized under the same lifecycle lock.
        else Some(readObjects(scope).recoverRecord(current))
      }
      snapshot match {
        case None=>Unavailable
        case Some(None)=>result(stage.conflict())
        case Some(Some((revision,origin)))=>
          val next=try Intake.patch(revision,expectedRevision,edits)
          catch {case rejected:Rejected=>stage.abort();throw rejected}
          val objects=staged(stage)
          commit(stage,objects,objects.revision(next,origin))
      }
    }
  def read(draft:String):Option[Revision]=host.withHead(draft) {(current,scope)=>readObjects(scope).recover(current)}
  def originals(draft:String):Option[Staged]=host.withHead(draft) {(current,scope)=>
    val objects=readObjects(scope)
    val origin=objects.recoverRecord(current)._2.getOrElse(throw new Rejected("origin","Original source unavailable"))
    objects.recoverIntake(origin)
  }
  /** This receipt deliberately covers storage only. Full lifecycle Forget must also
    * acknowledge generated authority retirement and native/private-worker root release. */
  def forgetStorage(draft:String):ManagedSources.StorageErased=host.forget(draft)
}
object ManagedDrafts {
  sealed trait Result
  final case class Recorded(receipt:ManagedSources.Receipt,replayed:Boolean) extends Result
  case object Conflict extends Result
  case object IdentityMismatch extends Result
  case object Unavailable extends Result
}
