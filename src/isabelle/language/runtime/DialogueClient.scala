package veri7vn.runtime.service

import scala.language.unsafeNulls
import veri7vn.runtime.conversation.ConversationProtocol

/** Bounded client-side proposal ownership. Native interpretation and the existing
  * authority service still decide what may run and what may be rendered. */
object DialogueClient {
  final case class Inspection(handle:Long,status:String,alternatives:List[Int],policy:String)
}

final class DialogueClient(resident:ResidentAuthorityService) extends AutoCloseable {
  import DialogueClient.*
  private final case class SessionPin(id:BigInt,version:BigInt)
  private final case class Pending(original:Array[Byte],alternatives:List[Int],created:Long,
    conversation:Option[SessionPin])
  private val pending=scala.collection.mutable.Map.empty[Long,Pending]
  private var nextHandle=0L
  private var closed=false
  private val lifetimeNanos=5L*60*1000*1000*1000
  private def erase(value:Pending):Unit=java.util.Arrays.fill(value.original,0.toByte)
  private def expire():Unit={
    val now=System.nanoTime()
    pending.keysIterator.filter(id=>now-pending(id).created>=lifetimeNanos).toList.foreach {id=>
      pending.remove(id).foreach(erase)
    }
  }
  private def available():Unit={require(!closed,"dialogue client closed");expire()}

  /** An inspection is not an execution request or an accepted answer. */
  def inspect(original:Array[Byte]):Inspection=inspectPinned(original,None)

  /** Open the current native conversation before proposing readings. Opening is
    * read-only: it neither replays old requests nor adopts their quoted claims.
    * Selection still rechecks this exact version at the native writer. */
  def inspectConversation(original:Array[Byte],id:BigInt):Inspection={
    require(id>0 && id.toString.length<=128,"conversation identity")
    inspect(original,resident.openConversation(id))
  }

  /** The view is an expected native CAS version, not authority or cached history.
    * This fixed reader remains context-free; it does not resolve pronouns. */
  def inspect(original:Array[Byte],view:ConversationProtocol.View):Inspection={
    require(view.id>0 && view.id.toString.length<=128 && view.version>=0 &&
      view.version.toString.length<=128 && view.status==ConversationProtocol.Status.Active && view.observation.exists(o=>
      o.session==view.id && o.version==view.version),"conversation is unavailable")
    inspectPinned(original,Some(SessionPin(view.id,view.version)))
  }

  private def inspectPinned(original:Array[Byte],conversation:Option[SessionPin]):Inspection=synchronized {
    available()
    require(original.length<=256,"dialogue input exceeds native byte budget")
    require(pending.size<128,"too many unresolved dialogue proposals")
    val retained=original.clone()
    try {
      val result=resident.inspectRouting(retained)
      require(Set("readings","literal","budget","unrecognized","structure_blocked").contains(result.status),
        "native routing inspection status")
      require(result.alternatives.distinct==result.alternatives &&
        result.alternatives.forall(i=>i>=0 && i<=255) &&
        ((result.status=="readings") == result.alternatives.nonEmpty),
        "native routing inspection alternatives")
      if(result.status=="readings") {
        nextHandle=Math.addExact(nextHandle,1L)
        pending(nextHandle)=Pending(retained,result.alternatives,System.nanoTime(),conversation)
        Inspection(nextHandle,if(result.alternatives.size==1)"ready" else "clarification",
          result.alternatives,"math/1")
      } else {
        java.util.Arrays.fill(retained,0.toByte)
        Inspection(0L,result.status,Nil,"math/1")
      }
    } catch {case failure:Throwable=>java.util.Arrays.fill(retained,0.toByte);throw failure}
  }

  /** One-shot selection retains exact original bytes. Native elaboration reruns
    * the fixed reader and reserves the ordinary D46 mathematics request. */
  def select(handle:Long,index:Int):BigInt=synchronized {
    available()
    val proposal=pending.getOrElse(handle,
      throw new IllegalArgumentException("unknown or expired dialogue inspection"))
    require(proposal.alternatives.contains(index),"selection was not a native alternative")
    pending.remove(handle)
    try proposal.conversation match {
      case None=>resident.proposeMathematics(proposal.original,Some(index))
      case Some(pin)=>resident.proposeConversationMathematics(pin.id,pin.version,proposal.original,Some(index))
    } finally erase(proposal)
  }

  def discard(handle:Long):Unit=synchronized {
    available();pending.remove(handle).foreach(erase)
  }
  /** Expire/Forget in the UI also erases pending input for that conversation.
    * Native authority independently rejects stale handles even if UI erasure races. */
  def discardConversation(id:BigInt):Unit=synchronized {
    available();require(id>0 && id.toString.length<=128,"conversation identity")
    pending.keysIterator.filter(key=>pending(key).conversation.exists(_.id==id)).toList.foreach {key=>
      pending.remove(key).foreach(erase)
    }
  }
  def close():Unit=synchronized {
    if(!closed){closed=true;pending.valuesIterator.foreach(erase);pending.clear()}
  }
}
