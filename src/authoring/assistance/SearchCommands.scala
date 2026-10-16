package veri7vn.authoring.assistance

import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import veri7vn.packages.intake.Intake
import veri7vn.runtime.service.ResidentAuthorityService
import veri7vn.runtime.service.search.SearchIngress

/** Commands over actual resident-owned handles. Enumeration is also the reopen
  * path after restart; text IDs select a returned opaque object, never mint one.
  * Installation must expose these commands only after native Search qualifies. */
object SearchCommands {
  def run(client:ResidentAuthorityService,args:Array[String]):Unit={
    require(args.nonEmpty,"A search command is required")
    val ingress=client.search
    def request():SearchIngress.Request={
      require(args.length>=2,"A search request ID is required")
      val id=BigInt(args(1))
      ingress.requests().find(_.request==id)
        .getOrElse(throw new IllegalArgumentException("Search request is not available in current retained authority"))
    }
    args(0) match {
      case "search-contexts"=>
        require(args.length==1,"search-contexts takes no arguments")
        ingress.contexts().foreach(c=>println(s"${c.id}\tsemantic ${c.semantic}\t${c.label}"))
      case "search-requests"=>
        require(args.length==1,"search-requests takes no arguments")
        ingress.requests().foreach(r=>println("Request "+r.request+"; goal "+r.goal+"; slot "+r.slot+
          "; original context "+r.context+"; semantic "+r.semantic))
      case "search"=>
        require(args.length==7,"search requires native context ID, proposition file, expansions, frontier, successors, milliseconds")
        val id=BigInt(args(1))
        val context=ingress.contexts().find(_.id==id)
          .getOrElse(throw new IllegalArgumentException("Select a context returned by search-contexts"))
        val input=Files.newInputStream(Path.of(args(2)))
        val bytes=try input.readNBytes(65537)finally input.close()
        try {
          require(bytes.nonEmpty && bytes.length<=65536,"Standalone proposition must contain 1–65536 bytes")
          val request=StandaloneSearch.submit(ingress,context,Intake.Content(bytes),
            LiteralSearch.Budget(args(3).toInt,args(4).toInt,args(5).toInt,args(6).toInt),
            Vector(LiteralSearch.Action.Introduce,LiteralSearch.Action.Split,LiteralSearch.Action.Assume))
          println("Request "+request.request+"; goal "+request.goal+"; slot "+request.slot)
          println("Policy: introduce, split conjunction, assume. The exact standalone proposition was submitted in native context "+context.id+".")
          println("Inspect with search-status; cancellation and Forget are separate commands.")
        }finally java.util.Arrays.fill(bytes,0.toByte)
      case "search-status"=>
        require(args.length==2,"search-status requires a retained request ID")
        val r=request();val observation=StandaloneSearch.inspect(ingress,r)
        println("Request "+r.request+"; goal "+r.goal+"; slot "+r.slot)
        println(observation.summary)
        observation.result match {
          case SearchIngress.Pending=>()
          case proof:SearchIngress.Proved=>printProof(proof)
          case SearchIngress.Historical(proof)=>println("Historical result");printProof(proof)
          case SearchIngress.Unresolved(reason,diagnostic,progress)=>
            println("Stop: "+reason+"\n"+diagnostic);printProgress(progress)
        }
      case "search-cancel"=>
        require(args.length==2,"search-cancel requires a retained request ID")
        StandaloneSearch.cancel(ingress,request())
        println("Search cancellation durably acknowledged. A retained theorem may remain accessible under history permissions.")
      case "search-forget"=>
        require(args.length==3 && args(2)=="--confirm","search-forget requires a retained request ID and --confirm")
        val r=request();client.forget(r.request)
        println("Forget durably acknowledged; physical erasure follows the native cleanup barrier.")
      case other=>throw new IllegalArgumentException("Unknown search command: "+other)
    }
  }
  private def printProof(proof:SearchIngress.Proved):Unit={
    println("Original proposition:\n"+proof.proposition)
    println("Native evidence reference: "+proof.evidence+"; receiver semantic "+proof.semantic+
      "; proof semantic "+proof.proofSemantic)
    println("Native dependencies: "+proof.dependencies.mkString(", "))
    printProgress(proof.progress)
  }
  private def printProgress(progress:SearchIngress.Progress):Unit={
    println("Expansions: "+progress.expansions)
    progress.trace.foreach(s=>println("Step "+s.index+": "+s.action+" / "+s.route+"; subgoals "+s.subgoals.mkString(" | ")))
    progress.remaining.foreach(goals=>println("Unresolved search state: "+goals.mkString(" | ")))
    if(progress.traceTruncated)println("Trace shows "+progress.trace.size+" of "+progress.traceTotal+" steps.")
    if(progress.remainingTruncated)println("Remaining states show "+progress.remaining.size+" of "+progress.remainingTotal+" states.")
    if(progress.detailsTruncated)println("Some subgoal details are truncated.")
  }
}
