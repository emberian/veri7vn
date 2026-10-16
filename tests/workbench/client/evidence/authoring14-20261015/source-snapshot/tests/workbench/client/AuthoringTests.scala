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
