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
      println(s"RESIDENT_SERVICE_PASS concurrent_actual_request_charge_worker_publication_nonempty_restore_forget_survivor deployment=${supervisor.deploymentIdentity} capture_ms=${supervisor.deploymentCaptureMillis}")
    }.get
  }
}
