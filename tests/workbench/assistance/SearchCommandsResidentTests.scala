package veri7vn.runtime.service.search

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.WorkspaceStore
import veri7vn.runtime.service.{ResidentSupervisor,ResidentNativeBridge,ResidentAuthorityService,AuthorityCoordinator,DeploymentImages}
import veri7vn.authoring.assistance.SearchCommands
import isabelle.Path

/** Real command consumer through the production service. No synthetic context,
  * accepted theorem, result packet or authority callback supplies success. */
object SearchCommandsResidentTests {
  def main(args:Array[String]):Unit={
    require(args.nonEmpty,"Production session and source roots required")
    val root=Files.createTempDirectory("veri7vn-search-commands-")
    val proposition=root.resolve("obligation.txt")
    val literal="  P --> (P & P)  \n"
    Files.write(proposition,literal.getBytes(UTF_8))
    val images=new DeploymentImages(root.resolve("deployments"))
    scala.util.Using.Manager {use=>
      val store=use(new WorkspaceStore(root.resolve("workspace")))
      def open(restoring:Boolean):ResidentAuthorityService={
        val supervisor=use(new ResidentSupervisor(args.head,args.tail.toList.map(Path.explode),images))
        val coordinator=use(new AuthorityCoordinator(store,new ResidentNativeBridge(supervisor,store)))
        val initialized=if(restoring)coordinator.restore()else coordinator.initialize()
        require(initialized.isInstanceOf[AuthorityCoordinator.Committed],"Actual resident initialization")
        use(new ResidentAuthorityService(supervisor,coordinator))
      }
      def command(client:ResidentAuthorityService,args:String*):String={
        val out=new java.io.ByteArrayOutputStream()
        Console.withOut(new java.io.PrintStream(out,true,"UTF-8")){SearchCommands.run(client,args.toArray)}
        out.toString("UTF-8")
      }
      def await(client:ResidentAuthorityService,id:BigInt):SearchIngress.Result={
        val request=client.search.requests().find(_.request==id).get
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var result=client.search.poll(request)
        while(result==SearchIngress.Pending && System.nanoTime()<deadline){Thread.sleep(20);result=client.search.poll(request)}
        require(result!=SearchIngress.Pending,"Actual search observer deadline")
        result
      }
      val first=open(false)
      val contexts=first.search.contexts()
      require(contexts.nonEmpty,"Actual approved native context required")
      require(command(first,"search-contexts").contains(contexts.head.label),"Context command omitted native label")
      val started=command(first,"search",contexts.head.id.toString,proposition.toString,"100","100","2","5000")
      val requestId="Request ([0-9]+);".r.findFirstMatchIn(started).map(m=>BigInt(m.group(1))).get
      val proof=await(first,requestId) match {
        case p:SearchIngress.Proved=>p
        case other=>throw new IllegalStateException("Real command search failed: "+other)
      }
      require(proof.proposition==literal && proof.progress.expansions>=3,"Original literal/multistep proof lost")
      val current=command(first,"search-status",requestId.toString)
      require(current.contains(literal) && current.contains(proof.proofSemantic.toString) && current.contains("Native dependencies"),
        "CLI lost exact original proposition or native provenance")
      val limited=command(first,"search",contexts.head.id.toString,proposition.toString,"1","100","2","5000")
      val limitedId="Request ([0-9]+);".r.findFirstMatchIn(limited).map(m=>BigInt(m.group(1))).get
      require(await(first,limitedId).asInstanceOf[SearchIngress.Unresolved].reason==SearchIngress.Stop.Budget,
        "Actual bounded policy did not stop at its budget")
      val inconclusive=command(first,"search-status",limitedId.toString)
      require(inconclusive.contains("remains unresolved") && !inconclusive.contains("Native evidence reference"),
        "Budget exhaustion became accepted proof/refutation")
      command(first,"search-cancel",requestId.toString)
      require(command(first,"search-status",requestId.toString).contains("Historical result"),"Cancellation erased/distorted retained proof")
      val sequence=store.latestNative.get.sequence
      first.close()
      val second=open(true)
      require(store.latestNative.get.sequence==sequence,"Command reopen replayed workflow")
      require(command(second,"search-requests").contains(requestId.toString),"Restart lost actual opaque child enumeration")
      val historical=command(second,"search-status",requestId.toString)
      require(historical.contains("Historical result") && historical.contains(literal),"Restart changed historical proposition")
      command(second,"search-forget",requestId.toString,"--confirm")
      require(!second.search.requests().exists(_.request==requestId),"Forget retained recoverable command request")
      var rejected=false
      try command(second,"search-status",requestId.toString)
      catch {case _:IllegalArgumentException=>rejected=true}
      require(rejected,"Forgotten ID reconstructed authority")
      println("ASSISTANCE_SEARCH_COMMANDS_RESIDENT_PASS actual_context_original_multistep_provenance_cancel_restart_history_forget")
    }.get
  }
}
