package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.WorkspaceStore
import veri7vn.diagnostics.RequestInspection
import veri7vn.diagnostics.Diagnostics
import isabelle.Path

/** Actual resident producer and restore consumer, never a fabricated frame. */
object RequestInspectionTests {
  def main(args:Array[String]):Unit={
    require(args.nonEmpty,"selected native session and source roots required")
    val root=Files.createTempDirectory("v7-request-inspection-").toRealPath()
    val images=new DeploymentImages(root.resolve("images"))
    scala.util.Using.Manager {use=>
      val store=use(new WorkspaceStore(root.resolve("workspace")))
      def open(restore:Boolean):ResidentAuthorityService={
        val supervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
        val coordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(supervisor,store)))
        val result=if(restore)coordinator.restore()else coordinator.initialize()
        require(result.isInstanceOf[AuthorityCoordinator.Committed],"inspection resident initialization/restore")
        use(new ResidentAuthorityService(supervisor,coordinator))
      }
      def accepted(client:ResidentAuthorityService,id:BigInt):Unit={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var result=client.mathematicsResult(id)
        while(result.status=="pending" && System.nanoTime()<deadline){Thread.sleep(20);result=client.mathematicsResult(id)}
        require(result.status=="accepted_exact" && result.html.nonEmpty,"inspection fixture native result")
      }
      def denied(client:ResidentAuthorityService,id:BigInt):RequestInspection.Inspection={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var view=client.requestInspection(id)
        while(view.status!="cancelled" && System.nanoTime()<deadline){Thread.sleep(20);view=client.requestInspection(id)}
        require(view.status=="cancelled" && view.reading.isEmpty,"inactive request exposed retained reading")
        require(view.readingUnavailable.exists(Set("invalidated","released","not_retained")),"inactive request reason")
        require(client.mathematicsResult(id).html.isEmpty,"inactive request exposed licensed answer")
        view
      }
      val client=open(false)
      val question="the sum of -2 and 3"
      val id=client.proposeMathematics(question.getBytes(UTF_8))
      val product=client.proposeMathematics("the product of 6 and 7".getBytes(UTF_8))
      accepted(client,id);accepted(client,product)
      val before=client.requestInspection(id)
      val reading=before.reading.get
      require(before.status=="accepted_exact" && before.identity.request==id,"actual owner identity/status")
      require(reading.index==0 && reading.operation==RequestInspection.Operation.Sum && reading.inputBytes==question.getBytes(UTF_8).length,
        "actual selected reading changed")
      require(reading.literals==Vector(RequestInspection.Span(11,13),RequestInspection.Span(18,19)),"actual original byte spans changed")
      // A real domain decline can be repaired by explicitly changing the input;
      // neither the old reading nor its non-answer is rewritten into success.
      val undefined=client.proposeMathematics("the quotient of 1 and 0".getBytes(UTF_8))
      val domainDeadline=System.nanoTime()+60L*1000*1000*1000
      var domain=client.requestInspection(undefined)
      while(domain.status=="pending" && System.nanoTime()<domainDeadline){Thread.sleep(20);domain=client.requestInspection(undefined)}
      require(domain.status=="undefined" && domain.explanation.outcome==Diagnostics.Outcome.Declined &&
        domain.reading.exists(_.operation==RequestInspection.Operation.Quotient),"actual undefined quotient diagnostic")
      val corrected=client.proposeMathematics("the quotient of 1 and 2".getBytes(UTF_8))
      accepted(client,corrected)
      require(corrected!=undefined && client.requestInspection(undefined)==domain,
        "corrected input overwrote historical declined request")
      val sequence=store.latestNative.get.sequence
      client.close()
      val restarted=open(true)
      val after=restarted.requestInspection(id)
      require(after==before,"restored native request inspection changed")
      require(store.latestNative.get.sequence==sequence,"inspection restore replayed workflow")
      restarted.cancel(id)
      val cancelled=denied(restarted,id)
      require(cancelled.identity==before.identity,"cancel changed original request provenance")
      restarted.forget(product)
      denied(restarted,product)
      require(restarted.requestInspection(id).reading.isEmpty,"Forget revived cancelled reading")
      println("REQUEST_INSPECTION_PASS actual accepted selected_reading byte_spans domain_decline corrected_new_request exact_provenance nonempty_restore no_replay cancel Forget unavailable_reading")
    }.get
    println("REQUEST_INSPECTION_WORKSPACE "+root)
  }
}
