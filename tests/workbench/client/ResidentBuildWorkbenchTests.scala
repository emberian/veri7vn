package veri7vn.workbench

import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.nio.charset.StandardCharsets.UTF_8
import java.net.URI
import java.net.http.{HttpClient,HttpRequest,HttpResponse}
import veri7vn.runtime.service.RuntimeService
import veri7vn.packages.intake.Intake

/** Requires the actual matching installed Build profile. No fake Build provider. */
object ResidentBuildWorkbenchTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-native-build-browser-").toRealPath()
    scala.util.Using.resource(RuntimeService.open(root.resolve("workspace"),root.resolve("images"),args.toList.map(Path.of(_)))) {service=>
      val source=root.resolve("source");Files.createDirectories(source)
      val original="theory Browser_Build imports Main begin\nlemma candidate: False by simp\nend\n"
      Files.writeString(source.resolve("Browser_Build.thy"),original)
      Files.writeString(source.resolve("package.json"),"""{"format":"veri7vn.package/0","package":{"id":"test.browser-build","version":"1.0.0","title":"Build fixture","description":"Actual native failure and reviewed source repair"},"files":[{"path":"Browser_Build.thy","role":"source"}],"requires":[],"native":{"session":"Browser_Build","theories":["Browser_Build"]},"capabilities":[]}""")
      val author=new Authoring(service.managedSources)
      author.importSource("native-browser-import","candidate",source,Intake.Format.NativeDevelopment)
      val builds=new ResidentBuildWorkspace(service,author)
      val browser=new Browser(author,None,Some(builds));browser.start()
      try {
        val http=HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).build()
        def get(query:String):String=http.send(HttpRequest.newBuilder(URI.create(browser.url+query)).GET().build(),HttpResponse.BodyHandlers.ofString()).body()
        val token="name=\"token\" value=\"([^\"]+)".r.findFirstMatchIn(get("")).get.group(1)
        def post(fields:Map[String,String]):String={
          val body=(fields+("token"->token)).toVector.map((key,value)=>java.net.URLEncoder.encode(key,UTF_8)+"="+java.net.URLEncoder.encode(value,UTF_8)).mkString("&")
          val response=http.send(HttpRequest.newBuilder(URI.create(browser.url)).POST(HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString())
          if(fields("action")=="Build native source")assert(response.previousResponse().get().statusCode()==303 && response.uri().getQuery.startsWith("build="))
          response.body()
        }
        def start():BigInt={
          val snapshot=author.inspect("candidate")
          val page=post(Map("action"->"Build native source","draft"->"candidate","manifest"->snapshot.manifest,"file"->"Browser_Build.thy"))
          BigInt("<h2>Build ([0-9]+)</h2>".r.findFirstMatchIn(page).get.group(1))
        }
        def await(id:BigInt,state:String):String={
          val deadline=System.nanoTime()+60L*1000*1000*1000
          var page=get("?build="+id)
          while(!page.contains("<p role=status>"+state+"</p>") && System.nanoTime()<deadline){Thread.sleep(25);page=get("?build="+id)}
          assert(page.contains("<p role=status>"+state+"</p>"),page)
          page
        }
        assert(get("?package=candidate").contains("Build native source"))
        val capturedRevision=author.inspect("candidate").revision.id
        val failed=start()
        val page=await(failed,"Failed")
        assert(page.contains("Native source replay failed") && page.contains("Current captured source"))
        assert(page.contains("name=\"context\" value=\"build.replay_failed\""))
        def field(name:String):String=("name=\""+name+"\" value=\"([^\"]*)").r.findFirstMatchIn(page).get.group(1)
        val selected="(?s)<textarea name=replacement rows=12>(.*?)</textarea>".r.findFirstMatchIn(page).get.group(1)
        assert(selected.contains("False"))
        val repair=Vector("draft","file","manifest","revision","context","start","stop").map(name=>name->field(name)).toMap++Map(
          "obligation"->"Correct the proposed theorem","choice"->"Obligation","meaning"->"ChangeSpecification","reason"->"The submitted False statement must be changed explicitly","replacement"->selected.replace("False","True"))
        val preview=post(repair+("action"->"Preview source change"))
        val review="name=\"review\" value=\"([^\"]+)".r.findFirstMatchIn(preview).get.group(1)
        assert(post(repair++Map("action"->"Apply reviewed change","review"->review)).contains("Saved."))
        assert(author.source("candidate","Browser_Build.thy").text.contains("candidate: True"))
        val oldAfterEdit=get("?build="+failed)
        assert(oldAfterEdit.contains(capturedRevision) && !oldAfterEdit.contains("name=\"context\" value=\"build.replay_failed\""))
        val next=start();assert(next!=failed)
        val artifact=await(next,"ArtifactReady")
        assert(artifact.contains("does not establish package admission or activation") && !artifact.contains("accepted_exact"))
        val cliOutput=new java.io.ByteArrayOutputStream()
        Console.withOut(new java.io.PrintStream(cliOutput,true,"UTF-8")) {
          veri7vn.cli.ResidentWorkbench.run(service,Array("build-status",next.toString),Some(builds))
        }
        assert(cliOutput.toString("UTF-8").contains("ArtifactReady") && cliOutput.toString("UTF-8").contains("admission and activation remain separate"))
        service.client.revoke(failed)
        val revoked=get("?build="+failed)
        assert(revoked.contains("Forget build") && !revoked.contains("Native build diagnostic"))
        val denied=post(Map("action"->"Forget build","build"->failed.toString))
        assert(denied.contains("Confirm removal"))
        post(Map("action"->"Forget build","build"->failed.toString,"confirm"->"yes"))
        val forgotten=get("?build="+failed)
        assert(!forgotten.contains("Native build diagnostic") && !forgotten.contains("Current captured source"))
        println("RESIDENT_BUILD_WORKBENCH_PASS actual managed build native failure exact-span reviewed specification edit explicit new artifact confirmed Forget")
      }finally browser.close()
    }
  }
}
