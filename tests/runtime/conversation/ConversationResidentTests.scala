package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.WorkspaceStore
import veri7vn.runtime.conversation.{ConversationClient,ConversationProtocol}
import isabelle.Path

/** Actual session producer/recovery consumer. This must not pass by substituting
  * fabricated frames or reissuing the original questions during restoration. */
object ConversationResidentTests {
  def main(args:Array[String]):Unit={
    require(args.nonEmpty,"native service session and source roots required")
    val root=Files.createTempDirectory("veri7vn-conversation-resident-").toRealPath()
    val images=new DeploymentImages(root.resolve("images"))
    final case class Opened(store:WorkspaceStore,resident:ResidentAuthorityService) extends AutoCloseable {
      val conversations=new ConversationClient(resident)
      def close():Unit=try resident.close() finally store.close()
    }
    def start(restore:Boolean):Opened={
      val store=new WorkspaceStore(root.resolve("workspace"))
      val supervisor=new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images)
      val coordinator=new AuthorityCoordinator(store,new ResidentNativeBridge(supervisor,store))
      try {
        val result=if(restore)coordinator.restore()else coordinator.initialize()
        require(result.isInstanceOf[AuthorityCoordinator.Committed],"conversation resident startup")
        Opened(store,new ResidentAuthorityService(supervisor,coordinator))
      } catch {case failure:Throwable=>
        supervisor.close();coordinator.close();store.close();throw failure
      }
    }
    def adopted(client:ConversationClient,id:BigInt,revision:BigInt):ConversationProtocol.View={
      val deadline=System.nanoTime()+60L*1000*1000*1000
      var view=client.open(id)
      while(view.version<revision && System.nanoTime()<deadline){Thread.sleep(20);view=client.open(id)}
      require(view.status==ConversationProtocol.Status.Active && view.version==revision,"native conversation adoption did not finish")
      require(view.turns.flatMap(_.parts).count(_.quotation.nonEmpty)>=revision.toInt,"native accepted turn was not adopted")
      view
    }
    def rejects(body: => Any):Unit={
      var rejected=false;try body catch {case _:IllegalArgumentException=>rejected=true;case _:IllegalStateException=>rejected=true}
      require(rejected,"stale/expired conversation accepted a new request")
    }
    var active:Option[Opened]=None
    try {
      val first=start(false);active=Some(first)
      val client=first.conversations
      val created=client.create()
      val survivor=client.create()
      require(created.version==0 && created.turns.isEmpty && created.id!=survivor.id,"native conversation creation")
      require(client.list().conversations.map(_.id).toSet==Set(created.id,survivor.id),"native conversation list")
      val undefined=client.propose(survivor,"the quotient of 1 and 0".getBytes(UTF_8))
      val declineDeadline=System.nanoTime()+60L*1000*1000*1000
      var declined=first.resident.mathematicsResult(undefined)
      while(declined.status=="pending" && System.nanoTime()<declineDeadline){
        Thread.sleep(20);declined=first.resident.mathematicsResult(undefined)
      }
      require(declined.status=="undefined" && declined.html.isEmpty,"native undefined fixture did not decline")
      val unadopted=client.open(survivor.id)
      require(unadopted.version==0 && unadopted.turns.exists(t=>t.request==undefined &&
        t.parts.forall(p=>p.status=="declined" && p.quotation.isEmpty)),"final decline was adopted or lost from transcript")
      val question="the sum of -2 and 3".getBytes(UTF_8)
      val firstRequest=client.propose(created,question)
      val one=adopted(client,created.id,1)
      require(one.turns.head.request==firstRequest && one.turns.head.originalBytes.sameElements(question),"first original turn association")
      rejects(client.propose(created,"the sum of 1 and 2".getBytes(UTF_8)))
      val secondRequest=client.propose(one,"the product of 6 and 7".getBytes(UTF_8))
      val two=adopted(client,created.id,2)
      require(two.turns.map(_.request)==Vector(firstRequest,secondRequest),"native turn ordering")
      val quotes=two.turns.flatMap(_.parts.flatMap(_.quotation))
      require(quotes.map(_.observation.version)==Vector(BigInt(0),BigInt(1)),"historical observation versions lost")
      require(quotes.forall(q=>q.observation.session==created.id && q.claim.modality=="asserted" &&
        q.claim.premises.isEmpty && q.claim.route=="refined_execution"),"native historical scope/conditions")
      require(quotes(1).html.contains("42"),"second native output was not quoted")
      val sequence=first.store.latestNative.get.sequence
      client.open(created.id);client.list()
      require(first.store.latestNative.get.sequence==sequence,"read-only recall committed a workflow")
      first.close();active=None
      val reopened=start(true);active=Some(reopened)
      require(reopened.store.latestNative.get.sequence==sequence,"restart replayed a request/adoption")
      require(reopened.conversations.open(created.id)==two,"restart changed retained native conversation")
      require(reopened.conversations.open(survivor.id)==unadopted,"restart changed recorded nonaccepted turn")
      reopened.conversations.expire(created.id)
      val expired=reopened.conversations.open(created.id)
      require(expired.status==ConversationProtocol.Status.Expired && expired.turns.isEmpty && expired.observation.isEmpty,
        "expired conversation exposed private payload")
      rejects(reopened.conversations.propose(two,"the sum of 1 and 2".getBytes(UTF_8)))
      require(reopened.conversations.open(survivor.id).status==ConversationProtocol.Status.Active,"expiry crossed sessions")
      reopened.conversations.forget(created.id)
      require(reopened.conversations.open(created.id).status==ConversationProtocol.Status.Unavailable,"Forget retained a session view")
      reopened.close();active=None
      val finalRestart=start(true);active=Some(finalRestart)
      require(finalRestart.conversations.open(created.id).status==ConversationProtocol.Status.Unavailable,"restart resurrected forgotten conversation")
      require(finalRestart.conversations.open(survivor.id).status==ConversationProtocol.Status.Active,"Forget crossed sessions")
      DialogueConversationChecks.run(finalRestart.resident)
      println("CONVERSATION_RESIDENT_PASS native_create list open two_turn_adoption decline_not_adopted historical_conditions stale_cas restart no_replay explicit_expiry Forget surviving_session")
      println("CONVERSATION_RESIDENT_WORKSPACE "+root)
    } finally active.foreach(_.close())
  }
}
