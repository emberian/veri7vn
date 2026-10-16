package veri7vn.workbench
import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
object AuthoringTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-author-client-").toRealPath()
    val source=Files.createTempDirectory("v7-author-source-").toRealPath()
    val text="theory Custom imports Main begin\n(* expert block untouched *)\nlemma preserved: True by simp\nend\n"
    Files.write(source.resolve("Custom.thy"),text.getBytes(UTF_8))
    Files.write(source.resolve("package.json"),"{}".getBytes(UTF_8))
    val store=new WorkspaceStore(root)
    try {
      val managed=new ManagedSources(store)
      val client=new Authoring(managed)
      assert(client.list().isEmpty)
      assert(client.importSource("import1","custom",source,Intake.Format.NativeDevelopment).isInstanceOf[ManagedDrafts.Recorded])
      assert(client.list()==Vector("custom"))
      val current=client.source("custom","Custom.thy")
      val start=text.indexOf("expert block")
      assert(client.edit("edit1","custom",current.snapshot.manifest,current.snapshot.revision.id,"Custom.thy",start,start+12,
        "expert block".getBytes(UTF_8),"custom expert block".getBytes(UTF_8)).isInstanceOf[ManagedDrafts.Recorded])
      val next=client.source("custom","Custom.thy")
      assert(next.text.contains("lemma preserved: True by simp"))
      assert(client.list()==Vector("custom"))
      assert(next.text.contains("custom expert block untouched"))
      val diagnostic=SourceLocation.locate(current.snapshot,"Custom.thy",start,start+12,next.snapshot.revision.id)
      assert(diagnostic.line==2 && diagnostic.column==4 && !diagnostic.current)
      var foreign=false;try SourceLocation.locate(current.snapshot,"Other.thy",0,1,current.snapshot.revision.id)
        catch {case _:IllegalArgumentException=>foreign=true};assert(foreign)

      assert(client.edit("stale","custom",current.snapshot.manifest,current.snapshot.revision.id,"Custom.thy",start,start+12,
        "expert block".getBytes(UTF_8),"bad".getBytes(UTF_8))==ManagedDrafts.Conflict)
      val original=Path.of("upstream/workbench/examples/paint-coverage")
      assert(client.importSource("original1","paint",original,Intake.Format.Oracle7Original).isInstanceOf[ManagedDrafts.Recorded])
      assert(client.migration("paint").candidates.nonEmpty)
      assert(client.panel("paint").rows.size==18)
      assert(client.list()==Vector("custom","paint"))
      var overflow=false;try client.list(1) catch {case _:IllegalArgumentException=>overflow=true};assert(overflow)
      assert(client.importSource("temporary1","temporary",source,Intake.Format.NativeDevelopment).isInstanceOf[ManagedDrafts.Recorded])
      managed.forget("temporary")
      assert(client.list()==Vector("custom","paint"))
      val growth=Path.of("examples/growth/retained-identity")
      assert(client.importSource("growth1","identity",growth,Intake.Format.NativeDevelopment).isInstanceOf[ManagedDrafts.Recorded])
      assert(client.describe("identity").descriptor.exports.isEmpty)
      assert(client.source("identity","OBLIGATIONS.md").text.nonEmpty)
      val browser=new Browser(client);browser.start()
      try {
        val http=java.net.http.HttpClient.newHttpClient()
        val response=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url)).GET().build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(response.statusCode()==200 && response.body().contains("Specialist workspace"))
        val token="name=\"token\" value=\"([^\"]+)".r.findFirstMatchIn(response.body()).get.group(1)
        val form="token="+token+"&action=Open&draft=custom&file=Custom.thy"
        val opened=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString(form)).build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(opened.body().contains("lemma preserved: True by simp"))
        val inspected=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("token="+token+"&action=Inspect&draft=custom")).build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(inspected.body().contains("name=\"file\" value=\"Custom.thy\""))
        assert(inspected.body().contains("Source-only workspace"))
        val growthPage=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("token="+token+"&action=Inspect&draft=identity")).build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(growthPage.body().contains("Retained_Identity.thy") && growthPage.body().contains("inspection does not establish native admission"))
        val migration=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("token="+token+"&action=Migration&draft=paint")).build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(migration.body().contains("v7_math_formula litres_scalar") && migration.body().contains("Remaining obligations") && migration.body().contains("zero spread rate"))
        def savePage(page:String,replacement:String):String={
          def hidden(name:String):String=("name=\""+name+"\" value=\"([^\"]*)").r.findFirstMatchIn(page).get.group(1)
          val values=Vector("token"->token,"action"->"Save","draft"->"custom","file"->"Custom.thy",
            "manifest"->hidden("manifest"),"revision"->hidden("revision"),"original"->hidden("original"),"replacement"->replacement)
          val encoded=values.map((key,value)=>java.net.URLEncoder.encode(key,UTF_8)+"="+java.net.URLEncoder.encode(value,UTF_8)).mkString("&")
          http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
            .POST(java.net.http.HttpRequest.BodyPublishers.ofString(encoded)).build(),java.net.http.HttpResponse.BodyHandlers.ofString()).body()
        }
        val firstSave=savePage(opened.body(),next.text+"(* first browser save *)\n")
        assert(firstSave.contains("Saved."))
        val secondSave=savePage(firstSave,next.text+"(* second browser save *)\n")
        assert(secondSave.contains("Saved.") && client.source("custom","Custom.thy").text.contains("second browser save"))
        val denied=http.send(java.net.http.HttpRequest.newBuilder(java.net.URI.create(browser.url))
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("action=Open&draft=custom&file=Custom.thy")).build(),java.net.http.HttpResponse.BodyHandlers.ofString())
        assert(denied.body().contains("Expired form") && !denied.body().contains("lemma preserved"))
      }finally browser.close()
    } finally store.close()
    val reopened=new WorkspaceStore(root)
    try assert(new Authoring(new ManagedSources(reopened)).source("custom","Custom.thy").text.contains("lemma preserved"))
    finally reopened.close()
    val stdout=new java.io.ByteArrayOutputStream()
    Console.withOut(new java.io.PrintStream(stdout,true,"UTF-8")) {
      veri7vn.cli.Workbench.run(Array(root.toString,"list"))
      veri7vn.cli.Workbench.run(Array(root.toString,"inspect","custom"))
    }
    assert(stdout.toString("UTF-8").contains("custom") && stdout.toString("UTF-8").contains("Custom.thy"))
    println("AUTHORING_CLIENT_PASS actual native edit stale conflict original paint18 listing forget overflow browser CLI restart")
  }
}
