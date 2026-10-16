package veri7vn.cli

import veri7vn.workbench.{Authoring,BuildWorkspace}

/** Shared presentation over the resident's actual durable build handles. */
object BuildCommands {
  def run(author:Authoring,builds:BuildWorkspace,args:Array[String]):Unit={
    require(args.nonEmpty,"A build command is required")
    args(0) match {
      case "build"=>
        require(args.length==3,"build requires package name and declared theory path")
        val snapshot=author.inspect(args(1))
        val request=builds.start(snapshot.draft,snapshot.manifest,args(2))
        println("Build request "+request+" was proposed. Inspect its status before using an artifact.")
      case "build-status"=>
        require(args.length==2,"build-status requires a request ID")
        builds.inspect(BigInt(args(1))) match {
          case None=>println("Build unavailable; no retained source or result was opened.")
          case Some(view)=>
            println("Build "+view.request+": "+view.state)
            view.source.foreach(source=>println("Captured source: "+source.draft+"/"+source.path+"; revision "+source.revision))
            view.candidate.foreach(candidate=>println("Native artifact "+candidate+"; package admission and activation remain separate."))
            view.diagnostic.foreach(diagnostic=>println(diagnostic.description+"\n"+diagnostic.message))
        }
      case "build-cancel"=>
        require(args.length==2,"build-cancel requires a request ID")
        builds.cancel(BigInt(args(1)));println("Native cancellation was durably acknowledged.")
      case "build-forget"=>
        require(args.length==3 && args(2)=="--confirm","build-forget requires a request ID and --confirm")
        builds.forget(BigInt(args(1)));println("Native Forget was durably acknowledged; physical cleanup follows the ownership barrier.")
      case _=>throw new IllegalArgumentException("Unknown build command")
    }
  }
}
