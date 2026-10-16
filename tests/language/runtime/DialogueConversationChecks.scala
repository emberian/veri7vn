package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.conversation.{ConversationClient,ConversationProtocol}

/** Composition with the actual resident session producer. No mocked authority,
  * fabricated history frame, or accepted-result poll substitutes for adoption. */
object DialogueConversationChecks {
  def run(resident:ResidentAuthorityService):Unit={
    val conversations=new ConversationClient(resident)
    val dialogue=new DialogueClient(resident)
    val first=conversations.create()
    val second=conversations.create()
    def inspect(text:String,view:ConversationProtocol.View):DialogueClient.Inspection={
      val original=text.getBytes(UTF_8)
      try dialogue.inspect(original,view) finally java.util.Arrays.fill(original,0.toByte)
    }
    def rejects(body: => Any):Unit={
      var rejected=false
      try body catch {
        case _:IllegalArgumentException=>rejected=true
        case _:IllegalStateException=>rejected=true
      }
      require(rejected,"stale or discarded conversation selection was accepted")
    }
    def adopted(before:ConversationProtocol.View,request:BigInt,original:String):ConversationProtocol.View={
      val deadline=System.nanoTime()+60L*1000*1000*1000
      var view=conversations.open(before.id)
      while(view.version==before.version && System.nanoTime()<deadline){
        Thread.sleep(20);view=conversations.open(before.id)
      }
      require(view.status==ConversationProtocol.Status.Active && view.version==before.version+1,
        "native final arbitration/adoption did not finish")
      val turn=view.turns.find(_.request==request).getOrElse(
        throw new IllegalStateException("adoption lost the selected request"))
      require(turn.originalBytes.sameElements(original.getBytes(UTF_8)),"selection changed retained original")
      val quotes=turn.parts.flatMap(_.quotation)
      require(quotes.nonEmpty && quotes.forall(q=>q.observation.session==before.id &&
        q.observation.version==before.version && q.claim.route=="refined_execution" &&
        q.claim.modality=="asserted" && q.claim.premises.isEmpty),
        "historical quotation lost exact original scope or licensed route")
      view
    }
    try {
      val discarded=inspect("the sum of 1 and 2",first)
      val chosen=inspect("the sum of 4 and 5",second)
      val stale=inspect("the sum of 9 and 1",second)
      require(List(discarded,chosen,stale).forall(i=>i.status=="ready" && i.alternatives==List(0)))
      dialogue.discardConversation(first.id)
      rejects(dialogue.select(discarded.handle,0))
      val request=dialogue.select(chosen.handle,0)
      val current=adopted(second,request,"the sum of 4 and 5")
      require(current.turns.flatMap(_.parts.flatMap(_.quotation)).exists(_.html.contains("is 9.")),
        "selected exact arithmetic quotation missing")
      rejects(dialogue.select(stale.handle,0))
      rejects(dialogue.select(stale.handle,0))
      // The actual Run entry point may hold only the selected session identity.
      // It must obtain the native current version, rather than replay old turns.
      val survivorBytes="the product of 6 and 7".getBytes(UTF_8)
      val survivor=try dialogue.inspectConversation(survivorBytes,first.id)
        finally java.util.Arrays.fill(survivorBytes,0.toByte)
      val expired=inspect("the sum of 2 and 3",current)
      conversations.expire(second.id)
      // Deliberately omit UI erasure: native expiry must still reject this handle.
      rejects(dialogue.select(expired.handle,0))
      dialogue.discardConversation(second.id)
      val survivorRequest=dialogue.select(survivor.handle,0)
      adopted(first,survivorRequest,"the product of 6 and 7")
      require(conversations.open(second.id).status==ConversationProtocol.Status.Expired)
      println("DIALOGUE_CONVERSATION_PASS native_adoption original_scope stale_selection expiry discard surviving_session")
    } finally {
      dialogue.close()
      try conversations.forget(first.id) finally conversations.forget(second.id)
    }
  }
}
