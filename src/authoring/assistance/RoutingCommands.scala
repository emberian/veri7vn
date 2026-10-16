package veri7vn.authoring.assistance

import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.ResidentAuthorityService
import veri7vn.diagnostics.Diagnostics

/** Inspection of the actual installed fixed reader and retained request. These
  * commands issue no execution proposal, infer no missing specialist, and grant
  * no fallback permission from a declined or unrecognized reading. */
object RoutingCommands {
  def run(client:ResidentAuthorityService,args:Array[String]):Unit={
    require(args.nonEmpty,"A routing inspection command is required")
    args(0) match {
      case "specialists"=>
        require(args.length==1,"specialists takes no arguments")
        client.installedFamilies() match {
          case None=>println("This installation does not expose native family metadata. Source packages do not establish installed availability.")
          case Some(families)=>
            if(families.isEmpty)println("The native service declares no operation families.")
            families.foreach((name,version,propose,poll)=>
              println(name+" / "+version+"; propose "+propose+"; inspect "+poll))
            println("These are native service family declarations, not a list of every specialist or proof of request applicability.")
        }
      case "route"=>
        require(args.length==2,"route requires the original question")
        val bytes=args(1).getBytes(UTF_8)
        val inspected=try client.inspectRouting(bytes)
          finally java.util.Arrays.fill(bytes,0.toByte)
        println("Installed reader policy: math/1")
        println("Native routing status: "+inspected.status)
        inspected.status match {
          case "readings"=>
            println("Native candidate reading indexes: "+inspected.alternatives.mkString(", "))
            if(inspected.alternatives.size==1)println("One native reading is available. Use run with this question to propose execution.")
            else println("Choose an explicit native index with run QUESTION INDEX. No interpretation has been selected here.")
          case "literal"=>println("The fixed reader needs a supported literal. Review the exact question; no execution was proposed.")
          case "budget"=>println("Routing reached its inspection budget. No answer or refutation follows.")
          case "unrecognized"=>println("The fixed reader did not recognize this question. This does not establish that another specialist can answer it.")
          case "structure_blocked"=>println("The native reader blocked the question structure. This inspection does not authorize another route.")
          case _=>throw new IllegalArgumentException("Unsupported native routing status")
        }
        println("This projection exposes reading indexes, not candidate meanings, a full specialist catalogue or a precedence trace.")
      case "explain"=>
        require(args.length==2,"explain requires a native request ID")
        val request=BigInt(args(1))
        val inspection=client.requestInspection(request)
        println("Request "+request+"\nObserved request status: "+inspection.status)
        println(inspection.explanation.title+"\n"+inspection.explanation.detail)
        inspection.provenance.foreach((name,value)=>println(name+": "+value))
        inspection.reading.foreach {reading=>
          println("Selected reading: "+reading.index+"; "+reading.description)
          println("Original input bytes: "+reading.inputBytes)
          reading.literals.zipWithIndex.foreach((span,index)=>println("Literal "+(index+1)+" byte range: "+span.startByte+"–"+span.endByte))
        }
        inspection.readingUnavailable.foreach(reason=>println("Reading unavailable: "+reason))
        inspection.informationLimits.foreach(limit=>println("Inspection limit: "+limit))
        // A separate actual result observation may be newer than the inspection.
        // Only its native licensed HTML is displayed; metadata is not an answer.
        val result=client.mathematicsResult(request)
        println("Latest result observation: "+result.status)
        println(Diagnostics.explain(result.status).detail)
        result.html.foreach(println)
      case other=>throw new IllegalArgumentException("Unknown routing command: "+other)
    }
  }
}
