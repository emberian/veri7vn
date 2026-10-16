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
        require(args.length==1 || (args.length==2 && args(1)=="--verbose"),"specialists [--verbose]")
        val verbose=args.length==2
        client.installedFamilies() match {
          case None=>println("Installed family metadata is unavailable. Use route QUESTION to inspect the fixed reader.")
          case Some(families)=>
            println("Installed families")
            println("Family\tVersion")
            if(families.isEmpty)println("(none declared)")
            families.foreach((name,version,propose,poll)=>
              println(name+"\t"+version+(if(verbose)"\tpropose="+propose+"\tpoll="+poll else "")))
            println("Use route QUESTION to inspect applicable readings.")
        }
      case "route"=>
        require(args.length==2,"route requires the original question")
        val bytes=args(1).getBytes(UTF_8)
        val inspected=try client.inspectRoutingDetails(bytes)
          finally java.util.Arrays.fill(bytes,0.toByte)
        println("Route: "+inspected.status+" (math/1)")
        inspected.status match {
          case "readings"=>
            inspected.alternatives.foreach {alternative=>
              val operation=alternative.operation match {
                case 0=>"Sum"
                case 1=>"Difference"
                case 2=>"Product"
                case 3=>"Quotient"
                case 4=>"Subtract from"
                case _=>throw new IllegalArgumentException("Unsupported native operation")
              }
              println("Reading "+alternative.index+": "+operation+"; literal bytes "+
                alternative.literals.map(span=>span.start+"–"+span.stop).mkString(", "))
            }
            if(inspected.alternatives.size==1)println("Run this question with: run QUESTION")
            else println("Choose a reading with: run QUESTION INDEX")
          case "literal"=>println("Review the question's numeric literals, then inspect it again.")
          case "budget"=>println("Inspection budget reached; the question remains unresolved.")
          case "unrecognized"=>println("Question unrecognized by math/1. Try a supported arithmetic phrasing.")
          case "structure_blocked"=>println("Question structure blocked by math/1. Review the phrasing.")
          case _=>throw new IllegalArgumentException("Unsupported native routing status")
        }
        inspected.blockedLiterals.foreach(spans=>println("Blocked literal bytes: "+spans.map(span=>span.start+"–"+span.stop).mkString(", ")))
        println("Inspection only. Use run to select and execute a reading.")
      case "explain"=>
        require(args.length==2 || (args.length==3 && args(2)=="--verbose"),"explain REQUEST [--verbose]")
        val verbose=args.length==3
        val request=BigInt(args(1))
        val inspection=client.requestInspection(request)
        val result=client.mathematicsResult(request)
        println("Request "+request+": "+result.status)
        result.html.foreach(println)
        if(result.html.isEmpty)println(Diagnostics.explain(result.status).detail)
        inspection.reading.foreach {reading=>
          println("Selected reading: "+reading.index+"; "+reading.description)
          if(verbose){
            println("Original input bytes: "+reading.inputBytes)
            reading.literals.zipWithIndex.foreach((span,index)=>println("Literal "+(index+1)+" byte range: "+span.startByte+"–"+span.endByte))
          }
        }
        inspection.readingUnavailable.foreach(reason=>println("Reading unavailable: "+reason))
        if(verbose){
          println("Earlier inspection status: "+inspection.status)
          inspection.provenance.foreach((name,value)=>println(name+": "+value))
          inspection.informationLimits.foreach(limit=>println("Inspection limit: "+limit))
        }else println("Use explain REQUEST --verbose for source spans and native provenance.")
      case other=>throw new IllegalArgumentException("Unknown routing command: "+other)
    }
  }
}
