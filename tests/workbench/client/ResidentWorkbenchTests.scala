package veri7vn.workbench

import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.net.URI
import java.net.http.{HttpClient,HttpRequest,HttpResponse}
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.RuntimeService

/** Actual browser -> resident service -> durable publication consumer. */
object ResidentWorkbenchTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-resident-workbench-")
    scala.util.Using.resource(RuntimeService.open(root.resolve("workspace"),root.resolve("images"),args.toList.map(Path.of(_)))) {service=>
      val execution=new ResidentExecution(service)
      val browser=new Browser(new Authoring(service.managedSources),Some(execution));browser.start()
      try {
        val http=HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).build()
        def get():String=http.send(HttpRequest.newBuilder(URI.create(browser.url)).GET().build(),HttpResponse.BodyHandlers.ofString()).body()
        val token="name=\"token\" value=\"([^\"]+)".r.findFirstMatchIn(get()).get.group(1)
        var lastRedirect=false
        var lastURI=URI.create(browser.url)
        def post(action:String,fields:Seq[(String,String)]):String={
          val form=(Seq("token"->token,"action"->action)++fields).map((k,v)=>java.net.URLEncoder.encode(k,UTF_8)+"="+java.net.URLEncoder.encode(v,UTF_8)).mkString("&")
          val response=http.send(HttpRequest.newBuilder(URI.create(browser.url)).POST(HttpRequest.BodyPublishers.ofString(form)).build(),HttpResponse.BodyHandlers.ofString())
          lastRedirect=response.previousResponse().isPresent && response.previousResponse().get().statusCode()==303
          lastURI=response.uri()
          response.body()
        }
        val source=root.resolve("authored-source");Files.createDirectories(source)
        val original="theory Editable imports Main begin\nlemma original: True by simp\nend\n"
        Files.write(source.resolve("Editable.thy"),original.getBytes(UTF_8))
        Files.write(source.resolve("package.json"),"{}".getBytes(UTF_8))
        veri7vn.cli.ResidentWorkbench.run(service,Array("import-native","editable",source.toRealPath().toString,"residentSourceImport"))
        val captured=new Authoring(service.managedSources).source("editable","Editable.thy")
        val replacement=root.resolve("edited-source.thy")
        Files.write(replacement,(original+"(* resident CLI edit *)\n").getBytes(UTF_8))
        veri7vn.cli.ResidentWorkbench.run(service,Array("edit","editable",captured.snapshot.manifest,captured.snapshot.revision.id,
          "Editable.thy","0",captured.entry.content.size.toString,source.resolve("Editable.thy").toString,replacement.toString,"residentSourceEdit"))
        val authored=post("Open",Seq("draft"->"editable","file"->"Editable.thy"))
        assert(authored.contains("lemma original: True by simp") && authored.contains("resident CLI edit"))
        val started=post("Run mathematics",Seq("question"->"the product of 6 and 7"))
        assert(lastRedirect && lastURI.getQuery.startsWith("request="))
        val id="<h2>Request ([0-9]+)</h2>".r.findFirstMatchIn(started).get.group(1)
        val retainedUrl=browser.url+"?request="+id
        val reloaded=http.send(HttpRequest.newBuilder(URI.create(retainedUrl)).GET().build(),HttpResponse.BodyHandlers.ofString())
        assert(reloaded.body().contains("<h2>Request "+id+"</h2>"))
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var page=post("Refresh result",Seq("request"->id))
        while(!page.contains("accepted_exact") && System.nanoTime()<deadline){Thread.sleep(25);page=post("Refresh result",Seq("request"->id))}
        assert(page.contains("accepted_exact") && page.contains("The exact product of 6 and 7 is 42.") && page.contains("iframe sandbox"))
        assert(page.contains("Literal 1 byte range") && page.contains("Semantic generation") && page.contains("Mathematics operation"))
        val denied=post("Forget request",Seq("request"->id))
        assert(denied.contains("Confirm removal"))
        post("Forget request",Seq("request"->id,"confirm"->"yes"))
        val forgottenDeadline=System.nanoTime()+60L*1000*1000*1000
        page=post("Refresh result",Seq("request"->id))
        while(!page.contains("<p role=status>cancelled</p>") && System.nanoTime()<forgottenDeadline){Thread.sleep(25);page=post("Refresh result",Seq("request"->id))}
        assert(page.contains("<p role=status>cancelled</p>") && !page.contains("The exact product of 6 and 7 is 42."))
        println("RESIDENT_WORKBENCH_PASS actual browser request native licensed HTML confirmed Forget")
      }finally {browser.close();execution.close()}
    }
    println("RESIDENT_WORKBENCH_WORKSPACE "+root)
  }
}
