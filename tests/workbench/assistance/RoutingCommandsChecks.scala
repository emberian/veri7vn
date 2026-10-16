package veri7vn.authoring.assistance

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.ResidentAuthorityService

/** Invoked by the actual resident workbench rehearsal, with no transport or
  * result substitution. Tests inspection separately from native execution. */
object RoutingCommandsChecks {
  def run(client:ResidentAuthorityService):Unit={
    def command(args:String*):String={
      val out=new java.io.ByteArrayOutputStream()
      Console.withOut(new java.io.PrintStream(out,true,"UTF-8")){RoutingCommands.run(client,args.toArray)}
      out.toString("UTF-8")
    }
    val question="the sum of 8 and 9"
    val bytes=question.getBytes(UTF_8)
    try {
      val actual=client.inspectRouting(bytes)
      val routed=command("route",question)
      require(routed.contains("Route: "+actual.status),"Command changed actual native route status")
      actual.alternatives.foreach(index=>require(routed.contains(index.toString),"Command dropped native alternative"))
      require(routed.contains("Inspection only"),"Command failed to distinguish inspection from execution")
      val unavailable=command("route","tell me which impossible specialist knows this")
      require(unavailable.contains("unrecognized by math/1") && !unavailable.contains("Selected reading:"),
        "Unrecognized route became invented specialist fallback")
      val families=client.installedFamilies()
      val listed=command("specialists")
      families match {
        case None=>require(listed.contains("metadata is unavailable"),"Old installation gained fabricated catalogue")
        case Some(values)=>values.foreach((name,version,_,_)=>require(listed.contains(name+"\t"+version),"Declared family lost"))
      }
      require(actual.status=="readings" && actual.alternatives.size==1,"Actual fixed arithmetic fixture interpretation")
      val request=client.proposeMathematics(bytes,Some(actual.alternatives.head))
      val deadline=System.nanoTime()+60L*1000*1000*1000
      var result=client.mathematicsResult(request)
      while(result.status=="pending" && System.nanoTime()<deadline){Thread.sleep(20);result=client.mathematicsResult(request)}
      require(result.status=="accepted_exact","Actual native mathematics did not yield licensed result")
      val explained=command("explain",request.toString,"--verbose")
      require(explained.contains("Selected reading:") && explained.contains("Add the two captured integers.") &&
        explained.contains("Selection decision:") && explained.contains("Executable generation:") &&
        explained.contains("Request "+request+": accepted_exact"),"Explanation lost actual selection/execution provenance")
      result.html.foreach(html=>require(explained.contains(html),"Explanation substituted for licensed native result"))
      client.forget(request)
      println("ASSISTANCE_ROUTING_COMMANDS_PASS actual_native_route_selection_family_metadata_explanation_licensed_result")
    }finally java.util.Arrays.fill(bytes,0.toByte)
  }
}
