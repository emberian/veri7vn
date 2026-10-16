package veri7vn.cli

import scala.language.unsafeNulls
import veri7vn.runtime.service.RuntimeService
import veri7vn.workbench.{Authoring,Browser,ResidentExecution,BuildWorkspace}
import java.nio.charset.StandardCharsets.UTF_8

/** Commands over the same managed source store and resident native authority. */
object ResidentWorkbench {
  def run(service:RuntimeService,args:Array[String],builds:Option[BuildWorkspace]=None):Unit={
    val author=new Authoring(service.managedSources)
    val execution=new ResidentExecution(service)
    try {
    require(args.nonEmpty,"Workbench command required: serve, specialists, route, run, explain, result, cancel, forget, list, import-original, import-native, inspect, source, migration, edit")
    args(0) match {
      case "specialists"|"route"|"explain"=>veri7vn.authoring.assistance.RoutingCommands.run(service.client,args)
      case "serve"=>
        require(args.length==1,"serve takes no arguments")
        val browser=new Browser(author,Some(execution),builds);browser.start();println(browser.url)
        println("Press Enter to close the workspace.")
        try scala.io.StdIn.readLine() finally browser.close()
      case "build"|"build-status"|"build-cancel"|"build-forget"=>
        BuildCommands.run(author,builds.getOrElse(throw new IllegalArgumentException("The installed resident does not expose native Build support")),args)
      case "run"=>
        require(args.length==2 || args.length==3,"run requires a question and optional interpretation choice")
        val bytes=args(1).getBytes(UTF_8)
        val id=try {
          val route=execution.route(bytes)
          val selected=args.lift(2).map(_.toInt).getOrElse {
            require(route.status=="ready" && route.alternatives.size==1,
              "Native interpretation requires attention: "+route.status+"; available indexes: "+route.alternatives.mkString(", "))
            route.alternatives.head
          }
          require(route.alternatives.contains(selected),"Selection is not a native alternative")
          execution.select(route.handle,selected)
        } finally java.util.Arrays.fill(bytes,0.toByte)
        println("Request "+id)
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var outcome=execution.result(id)
        while(outcome.status=="pending" && System.nanoTime()<deadline){Thread.sleep(25);outcome=execution.result(id)}
        println("Status: "+outcome.status)
        println(veri7vn.diagnostics.Diagnostics.explain(outcome.status).detail)
        outcome.html.foreach(println)
        require(outcome.status!="pending","Request did not finish before the observer deadline; retain its ID and inspect the restored workspace")
        require(outcome.status=="accepted_exact","Request did not produce an accepted result: "+outcome.status)
      case "result"=>
        require(args.length==2,"result requires a request ID")
        val result=execution.result(BigInt(args(1)))
        val diagnosis=veri7vn.diagnostics.Diagnostics.explain(result.status)
        println("Request "+args(1)+"\nStatus: "+result.status+"\n"+diagnosis.title+"\n"+diagnosis.detail)
        result.html.foreach(println)
        execution.provenance(BigInt(args(1))).foreach((key,value)=>println(key+": "+value))
      case "cancel"=>require(args.length==2,"cancel requires a request ID");execution.cancel(BigInt(args(1)));println("Cancellation durably acknowledged.")
      case "forget"=>
        require(args.length==3 && args(2)=="--confirm","forget requires a request ID and --confirm; removes dependent retained results")
        execution.forget(BigInt(args(1)));println("Forget durably acknowledged; physical erasure follows the native cleanup barrier.")
      case _=>Workbench.runAuthoring(author,args)
    }
    } finally execution.close()
  }
}
