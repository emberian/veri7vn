package veri7vn.runtime.conversation

import veri7vn.runtime.service.ResidentAuthorityService

/** Fixed consumer of the resident session authority. The client intentionally
  * keeps no transcript, accepted-answer cache, session ledger or replay queue. */
final class ConversationClient(resident:ResidentAuthorityService) {
  import ConversationProtocol.*

  /** Returns only after the existing workspace writer acknowledges creation. */
  def create():View=open(resident.createConversation())
  def list():Index=resident.listConversations()
  def open(id:BigInt):View={
    require(id>0 && id.toString.length<=128,"conversation identity")
    resident.openConversation(id)
  }
  /** A newly authorized execution, never an operation performed by open/recall.
    * The native owner rechecks the actual session and observation at reservation
    * and final arbitration; this projection is only the expected CAS version. */
  def propose(view:View,original:Array[Byte],selection:Option[Int]=None):BigInt={
    require(view.status==Status.Active && view.observation.exists(o=>
      o.session==view.id && o.version==view.version),"conversation is unavailable")
    require(original.length<=256 && selection.forall(i=>i>=0 && i<=255),"conversation input bound")
    resident.proposeConversationMathematics(view.id,view.version,original,selection)
  }
  /** Explicit expiry revokes future access through the existing lifecycle path. */
  def expire(id:BigInt):Unit=resident.expireConversation(id)
  /** Existing Forget performs the durable denial and managed closure cleanup. */
  def forget(id:BigInt):Unit={
    require(id>0 && id.toString.length<=128,"conversation identity")
    resident.forget(id)
  }
}
