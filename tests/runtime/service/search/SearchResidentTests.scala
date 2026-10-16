package veri7vn.runtime.service.search

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.WorkspaceStore
import veri7vn.runtime.service.{ResidentSupervisor,ResidentNativeBridge,ResidentAuthorityService,AuthorityCoordinator,DeploymentImages}
import isabelle.Path

/** Actual resident pipeline only. No fixture reducer/native result/worker or
  * caller theorem/evidence supplies an accepted search result. */
object SearchResidentTests {
  def main(args:Array[String]):Unit={
    require(args.nonEmpty,"selected prebuilt native session and source roots required")
    val root=Files.createTempDirectory("veri7vn-native-search-e2e-")
    println("SEARCH_RESIDENT_WORKSPACE "+root)
    val images=new DeploymentImages(root.resolve("deployments"))
    scala.util.Using.Manager {use=>
      val store=use(new WorkspaceStore(root.resolve("workspace")))
      def open(restoring:Boolean):(ResidentSupervisor,ResidentAuthorityService)={
        val supervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
        val coordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(supervisor,store)))
        val outcome=if(restoring)coordinator.restore() else coordinator.initialize()
        require(outcome.isInstanceOf[AuthorityCoordinator.Committed],"actual native search startup: "+outcome)
        (supervisor,use(new ResidentAuthorityService(supervisor,coordinator)))
      }
      def await(ingress:SearchIngress,request:SearchIngress.Request):SearchIngress.Result={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var result=ingress.poll(request)
        while(result==SearchIngress.Pending && System.nanoTime()<deadline){Thread.sleep(20);result=ingress.poll(request)}
        require(result!=SearchIngress.Pending,"actual native search result deadline")
        result
      }
      val (supervisor,client)=open(false)
      val search=client.search
      val context=search.contexts().headOption.getOrElse(throw new IllegalStateException("actual admitted native context missing"))
      val actions=Vector(SearchIngress.Action.Introduce,SearchIngress.Action.Split,SearchIngress.Action.Assume)
      val literal="  P --> (P & P)  \n"
      val provedRequest=search.propose(context,literal.getBytes(UTF_8),SearchIngress.Budget(100,100,2,5000),actions)
      val proof=await(search,provedRequest) match {
        case proof:SearchIngress.Proved=>proof
        case other=>throw new IllegalStateException("actual native search did not prove original literal: "+other)
      }
      require(proof.proposition==literal && proof.semantic==context.semantic && proof.semantic!=proof.proofSemantic &&
        proof.dependencies.contains(proof.semantic) && proof.dependencies.contains(proof.proofSemantic) &&
        proof.progress.expansions>=3,"actual native original proposition/context/provenance/multistep association")
      search.cancel(provedRequest)
      val historical=search.poll(provedRequest)
      require(historical==SearchIngress.Historical(proof),"Cancel destroyed retained theorem or confused it with active binding")
      val budgetRequest=search.propose(context,literal.getBytes(UTF_8),SearchIngress.Budget(1,100,2,5000),actions)
      val budget=await(search,budgetRequest)
      require(budget.isInstanceOf[SearchIngress.Unresolved] &&
        budget.asInstanceOf[SearchIngress.Unresolved].reason==SearchIngress.Stop.Budget,"native budget stop became proof/refutation")
      val stoppedRequest=search.propose(context,literal.getBytes(UTF_8),SearchIngress.Budget(1,100,2,5000),actions)
      val stopped=await(search,stoppedRequest).asInstanceOf[SearchIngress.Unresolved]
      require(stopped.reason==SearchIngress.Stop.Budget,"cancelled stopped-source fixture did not actually exhaust its budget")
      search.cancel(stoppedRequest)
      val cancelledStopped=search.poll(stoppedRequest).asInstanceOf[SearchIngress.Unresolved]
      require(cancelledStopped.reason==SearchIngress.Stop.Cancelled && cancelledStopped.progress==stopped.progress,
        "cancellation erased actual stopped progress or retained active execution status")
      val cancelledRequest=search.propose(context,("P --> ("+Vector.fill(80)("P").mkString(" & ")+")").getBytes(UTF_8),
        SearchIngress.Budget(10000,1000,2,30000),actions)
      search.cancel(cancelledRequest)
      val cancelled=await(search,cancelledRequest)
      require(cancelled.isInstanceOf[SearchIngress.Unresolved] &&
        cancelled.asInstanceOf[SearchIngress.Unresolved].reason==SearchIngress.Stop.Cancelled,"durably cancelled search exposed proof")
      val retained=search.requests()
      require(retained.exists(r=>r.request==provedRequest.request && r.goal==provedRequest.goal && r.slot==provedRequest.slot &&
        r.context==provedRequest.context && r.semantic==provedRequest.semantic),"native retained typed child missing")
      val committedSequence=store.latestNative.get.sequence
      client.close()
      val (_,restarted)=open(true)
      val restoredRequests=restarted.search.requests()
      val restoredRequest=restoredRequests.find(r=>r.request==provedRequest.request && r.goal==provedRequest.goal && r.slot==provedRequest.slot).get
      val restoredProof=restarted.search.poll(restoredRequest)
      require(restoredProof==historical,"native cancelled search history restore changed original literal/provenance/trace")
      require(store.latestNative.get.sequence==committedSequence,"search restore replayed native charge/event workflow")
      val restoredBudget=restoredRequests.find(r=>r.request==budgetRequest.request && r.goal==budgetRequest.goal && r.slot==budgetRequest.slot).get
      require(restarted.search.poll(restoredBudget)==budget,"budget restore replayed search or changed actual terminal outcome")
      val restoredStopped=restoredRequests.find(_.request==stoppedRequest.request).get
      require(restarted.search.poll(restoredStopped)==cancelledStopped,
        "cancelled stopped-source restore lost exact progress or recreated active search")
      val restoredCancelled=restoredRequests.find(_.request==cancelledRequest.request).get
      require(restarted.search.poll(restoredCancelled).asInstanceOf[SearchIngress.Unresolved].reason==SearchIngress.Stop.Cancelled,
        "cancelled no-proof original source was not restored as inert history")
      restarted.forget(restoredRequest.request)
      require(!restarted.search.requests().exists(_.request==restoredRequest.request),"Forget retained recoverable search child")
      val forgotten=restarted.search.poll(restoredRequest)
      require(!forgotten.isInstanceOf[SearchIngress.Proved] && !forgotten.isInstanceOf[SearchIngress.Historical],
        "Forget still exposed original proposition proof")
      val cleanupDeadline=System.nanoTime()+60L*1000*1000*1000
      while(store.hasForgottenNativeArtifacts && System.nanoTime()<cleanupDeadline)Thread.sleep(20)
      require(!store.hasForgottenNativeArtifacts,"Forget did not finish native owned search artifact cleanup")
      val forgottenSequence=store.latestNative.get.sequence
      restarted.close()
      val (_,third)=open(true)
      require(store.latestNative.get.sequence==forgottenSequence &&
        !third.search.requests().exists(_.request==restoredRequest.request),"Forget/restart resurrected or replayed search")
      val survivingBudget=third.search.requests().find(_.request==budgetRequest.request).get
      require(third.search.poll(survivingBudget)==budget,"Forget damaged unrelated source/native child")
      val newContext=third.search.contexts().head
      val retrieved=third.search.propose(newContext,"True".getBytes(UTF_8),SearchIngress.Budget(8,8,2,5000),
        Vector(SearchIngress.Action.Retrieve),Vector("HOL.TrueI"))
      require(await(third.search,retrieved).isInstanceOf[SearchIngress.Proved],"shared native public image/catalogue did not survive request Forget")
      println("VERI7VN_SEARCH_RESIDENT_TESTS_PASSED actual_scope_charge_worker_reconstruction_licensed_result_cancel_budget_restart_forget")
    }.get
  }
}
