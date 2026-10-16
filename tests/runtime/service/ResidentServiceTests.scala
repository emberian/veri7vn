package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.file.Files
import veri7vn.runtime.host.WorkspaceStore
import isabelle.Path

/** Runs only against the actual prebuilt Native_Service heap. No fixture reducer,
  * event constructor, theorem string, or mock worker supplies the result. */
object ResidentServiceTests {
  def main(args:Array[String]):Unit={
    require(args.nonEmpty,"selected native session and source roots required")
    val root=Files.createTempDirectory("veri7vn-resident-e2e-")
    println("RESIDENT_WORKSPACE "+root)
    val images=new DeploymentImages(root.resolve("deployments"))
    scala.util.Using.Manager {use=>
      val store=use(new WorkspaceStore(root.resolve("workspace")))
      println("RESIDENT_PHASE immutable_boot")
      val supervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
      val bridge=new ResidentNativeBridge(supervisor,store)
      val coordinator=use(new AuthorityCoordinator(store,bridge))
      require(coordinator.initialize().isInstanceOf[AuthorityCoordinator.Committed],"actual native initialization")
      val client=use(new ResidentAuthorityService(supervisor,coordinator))
      def await(c:ResidentAuthorityService)(id:BigInt):c.Result={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var response=c.mathematicsResult(id)
        while(response.status=="pending" && System.nanoTime()<deadline){Thread.sleep(20);response=c.mathematicsResult(id)}
        require(response.status!="pending","native worker result deadline");response
      }
      val pool=java.util.concurrent.Executors.newFixedThreadPool(2)
      val barrier=new java.util.concurrent.CountDownLatch(1)
      def proposal(question:String)=pool.submit(new java.util.concurrent.Callable[BigInt]{def call():BigInt={
        barrier.await()
        val bytes=question.getBytes(java.nio.charset.StandardCharsets.UTF_8)
        try client.proposeMathematics(bytes) finally java.util.Arrays.fill(bytes,0.toByte)
      }})
      println("RESIDENT_PHASE concurrent_proposals")
      val first=proposal("the sum of -2 and 3")
      val second=proposal("the product of 6 and 7")
      barrier.countDown()
      val ids=try (first.get(60,java.util.concurrent.TimeUnit.SECONDS),second.get(60,java.util.concurrent.TimeUnit.SECONDS))
        catch {case failure:Throwable=>
          System.err.println("RESIDENT_NATIVE_SYSLOG_BEGIN\n"+supervisor.diagnosticSyslog+"\nRESIDENT_NATIVE_SYSLOG_END")
          failure.printStackTrace();throw failure
        } finally {pool.shutdownNow();pool.awaitTermination(5,java.util.concurrent.TimeUnit.SECONDS)}
      val sum=await(client)(ids._1)
      val product=await(client)(ids._2)
      require(sum.status=="accepted_exact" && sum.html.contains("<p>The exact sum of -2 and 3 is 1.</p>"),"native licensed sum projection")
      require(product.status=="accepted_exact" && product.html.contains("<p>The exact product of 6 and 7 is 42.</p>"),"concurrent native licensed product projection")
      val undefinedId=client.proposeMathematics("the quotient of 1 and 0".getBytes(java.nio.charset.StandardCharsets.UTF_8))
      val undefined=await(client)(undefinedId)
      require(undefined.status!="accepted_exact" && undefined.html.isEmpty,"undefined quotient emitted numeric answer")
      println("RESIDENT_PHASE publication_pass_nonempty_restart")
      val committedSequence=store.latestNative.get.sequence
      client.close()
      val restartedSupervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
      val restartedBridge=new ResidentNativeBridge(restartedSupervisor,store)
      val restartedCoordinator=use(new AuthorityCoordinator(store,restartedBridge))
      require(restartedCoordinator.restore().isInstanceOf[AuthorityCoordinator.Committed],"actual nonempty native restore")
      val restarted=use(new ResidentAuthorityService(restartedSupervisor,restartedCoordinator))
      val restored=restarted.mathematicsResult(ids._1)
      require(restored.status=="accepted_exact" && restored.html==sum.html,"restored native licensed output changed")
      require(store.latestNative.get.sequence==committedSequence,"restore replayed native event workflow")
      println("RESIDENT_PHASE restored_publication_pass_forget_one")
      restarted.forget(ids._1)
      val forgottenDeadline=System.nanoTime()+60L*1000*1000*1000
      var forgotten=restarted.mathematicsResult(ids._1)
      while(forgotten.status!="cancelled" && System.nanoTime()<forgottenDeadline){Thread.sleep(20);forgotten=restarted.mathematicsResult(ids._1)}
      require(forgotten.status=="cancelled" && forgotten.html.isEmpty,"forgotten request retained authoritative HTML")
      require(restarted.mathematicsResult(ids._2).html==product.html,"forget removed unrelated concurrent result")
      require(store.committedNativeRecovery(store.latestNative.get,ids._1).isEmpty,"forgotten original request artifact remains accessible")
      val cleanupDeadline=System.nanoTime()+60L*1000*1000*1000
      while(store.hasForgottenNativeArtifacts && System.nanoTime()<cleanupDeadline)Thread.sleep(20)
      require(!store.hasForgottenNativeArtifacts,"native cleanup barrier did not finish durable artifact erasure")
      println("RESIDENT_PHASE forget_erasure_pass_survivor_restart")
      restarted.close()
      val thirdSupervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
      val thirdCoordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(thirdSupervisor,store)))
      require(thirdCoordinator.restore().isInstanceOf[AuthorityCoordinator.Committed],"native restore after Forget")
      val third=use(new ResidentAuthorityService(thirdSupervisor,thirdCoordinator))
      require(third.mathematicsResult(ids._2).html==product.html,"surviving native result lost after Forget/restart")
      def awaitForgotten(c:ResidentAuthorityService,id:BigInt):Unit={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var result=c.mathematicsResult(id)
        while(result.status!="cancelled" && System.nanoTime()<deadline){Thread.sleep(20);result=c.mathematicsResult(id)}
        require(result.status=="cancelled" && result.html.isEmpty,"Forget did not durably deny request")
      }
      // The rejected quotient also owns a retained request. Remove it first so
      // product is genuinely the last durable consumer of shared native support.
      third.forget(undefinedId);awaitForgotten(third,undefinedId)
      val lostAcknowledgement=new java.util.concurrent.CountDownLatch(1)
      store.afterNativeCommit=()=>{
        lostAcknowledgement.countDown()
        throw new IllegalStateException("injected last-owner commit-before-native-ack failure")
      }
      var lostAckObserved=false
      try third.forget(ids._2) catch {case _:IllegalArgumentException=>lostAckObserved=true;case _:IllegalStateException=>lostAckObserved=true}
      require(lostAckObserved,"last-owner injected failure was reported as acknowledged")
      require(lostAcknowledgement.await(60,java.util.concurrent.TimeUnit.SECONDS),"last-owner durable commit deadline")
      // Stop with the durable denial committed but without native acknowledgement
      // or cleanup. Recovery must accept that exact checkpoint, not a later repair.
      third.close()
      store.afterNativeCommit=()=>()
      val lastOwnerSequence=store.latestNative.get.sequence
      require(store.committedNativeRecovery(store.latestNative.get,ids._2).isEmpty,"fault fired before last-owner denial committed")
      println("RESIDENT_PHASE last_owner_durable_forget_lost_ack_stop")
      val fourthSupervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
      val fourthCoordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(fourthSupervisor,store)))
      require(fourthCoordinator.restore().isInstanceOf[AuthorityCoordinator.Committed],"strict restore after last-owner Forget")
      val fourth=use(new ResidentAuthorityService(fourthSupervisor,fourthCoordinator))
      require(store.latestNative.get.sequence==lastOwnerSequence,"last-owner restore replayed workflow")
      require(fourth.mathematicsResult(ids._2).html.isEmpty,"last-owner result resurrected")
      println("RESIDENT_PHASE last_owner_restore_pass_immediate_forget")
      val immediate=fourth.proposeMathematics("the sum of 8 and 9".getBytes(java.nio.charset.StandardCharsets.UTF_8))
      fourth.forget(immediate);awaitForgotten(fourth,immediate)
      fourth.close()
      val fifthSupervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
      val fifthCoordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(fifthSupervisor,store)))
      require(fifthCoordinator.restore().isInstanceOf[AuthorityCoordinator.Committed],"strict restore after immediate Forget")
      val fifth=use(new ResidentAuthorityService(fifthSupervisor,fifthCoordinator))
      require(fifth.mathematicsResult(immediate).html.isEmpty,"immediately forgotten worker published after restart")
      println(s"RESIDENT_SERVICE_PASS concurrent_actual_request_charge_worker_publication_nonempty_restore_forget_survivor_last_owner_immediate deployment=${supervisor.deploymentIdentity} capture_ms=${supervisor.deploymentCaptureMillis}")
    }.get
  }
}
