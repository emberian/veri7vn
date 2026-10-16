package veri7vn.packages.lifecycle
import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.packages.intake.Intake
import Intake.{Content,Edit}
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
object ManagedDraftTests {
  def main(args:Array[String]):Unit={
    val root=Files.createTempDirectory("v7-managed-draft-consumer-").toRealPath()
    var store:WorkspaceStore=null
    var passed=0
    def test(name:String)(body: =>Unit):Unit={body;passed+=1;println("MANAGED_DRAFT_PASS "+name)}
    def c(s:String)=Content(s.getBytes(UTF_8))
    def recorded(r:ManagedDrafts.Result,replay:Boolean):ManagedSources.Receipt=r match {
      case ManagedDrafts.Recorded(receipt,actual)=>assert(actual==replay);receipt
      case other=>throw new AssertionError("Expected source receipt: "+other)
    }
    try {
      val input=Files.createDirectory(root.resolve("input"))
      val original="theory Example imports Main begin\n(* expert λ *)\nend\n"
      Files.write(input.resolve("Example.thy"),c(original).bytes)
      Files.write(input.resolve("manifest.json"),c("{\"id\":\"fixture\"}").bytes)
      Files.write(input.resolve("exam_log.jsonl"),c("{\"sender\":\"already examined\"}\n").bytes)
      val source=Intake.directory(input,Intake.Format.Oracle7Original)
      val workspace=root.resolve("workspace");store=new WorkspaceStore(workspace)
      var host=new ManagedSources(store);var drafts=new ManagedDrafts(host)
      test("actual source create replay and identity mismatch") {
        recorded(drafts.create("create_a","a",source),false)
        recorded(drafts.create("create_a","a",source),true)
        assert(drafts.create("create_a","other",source)==ManagedDrafts.IdentityMismatch)
        assert(drafts.originals("a").get.exposure.size==1)
      }
      val before=drafts.read("a").get
      val locator=host.withHead("a")((id,_)=>id).get
      val edit=Edit("Example.thy",original.indexOf("λ"),original.indexOf("λ")+2,c("λ"),c("μ"))
      test("exact edit preserves source original and restart historical replay") {
        recorded(drafts.edit("edit_a","a",locator,before.id,Vector(edit)),false)
        assert(new String(drafts.read("a").get.entries.find(_.path=="Example.thy").get.content.bytes,UTF_8)==original.replace("λ","μ"))
        assert(drafts.originals("a").get.entries.find(_.path=="Example.thy").get.content.sha256==c(original).sha256)
        store.close();store=new WorkspaceStore(workspace);host=new ManagedSources(store);drafts=new ManagedDrafts(host)
        recorded(drafts.edit("edit_a","a",locator,before.id,Vector(edit)),true)
      }
      test("stale expected head conflict is durable and exact retry replays the terminal outcome") {
        assert(drafts.edit("stale_edit","a",locator,before.id,Vector(edit))==ManagedDrafts.Conflict)
        val receipt=recorded(drafts.edit("stale_edit","a",locator,before.id,Vector(edit)),true)
        assert(receipt.status==ManagedSources.OperationStatus.Conflict)
      }
      test("invalid exact-byte edit aborts durably and never publishes source") {
        val current=drafts.read("a").get
        val head=host.withHead("a")((id,_)=>id).get
        val invalid=Edit("Example.thy",0,6,c("WRONG!"),c("theory"))
        try {drafts.edit("invalid_edit","a",head,current.id,Vector(invalid));throw new AssertionError("Invalid patch accepted")}
        catch{case _:Intake.Rejected=>()}
        assert(drafts.read("a").get.id==current.id)
        val receipt=recorded(drafts.edit("invalid_edit","a",head,current.id,Vector(invalid)),true)
        assert(receipt.status==ManagedSources.OperationStatus.Aborted)
      }
      val editedHash=drafts.read("a").get.entries.find(_.path=="Example.thy").get.content.sha256
      var prepared:ManagedSources#Stage=null
      var unused=""
      test("forget covers actual source history and unused prepared writes while shared source survives") {
        recorded(drafts.create("create_b","b",source),false)
        host.begin("prepared_a",c("private exact request").bytes,"a",host.withHead("a")((id,_)=>id)) match {
          case ManagedSources.Fresh(stage)=>prepared=stage;unused=stage.put(c("unused prepared private bytes").bytes)
          case _=>throw new AssertionError("Prepared operation unavailable")
        }
        drafts.forgetStorage("a")
        assert(drafts.read("a").isEmpty && drafts.originals("a").isEmpty)
        assert(drafts.create("create_a","a",source)==ManagedDrafts.Unavailable)
        assert(!Files.exists(workspace.resolve("managed-sources/objects").resolve(unused)))
        assert(!Files.exists(workspace.resolve("managed-sources/objects").resolve(editedHash)))
        assert(Files.exists(workspace.resolve("managed-sources/objects").resolve(c(original).sha256)))
        try {prepared.read(unused,1024);throw new AssertionError("Forgotten prepared bytes accessible")}
        catch{case _:IllegalArgumentException=>()}
        assert(drafts.read("b").nonEmpty && drafts.originals("b").get.exposure.size==1)
      }
      test("forget tombstone and shared source survive reopen") {
        store.close();store=new WorkspaceStore(workspace);host=new ManagedSources(store);drafts=new ManagedDrafts(host)
        assert(drafts.create("new_after_forget","a",source)==ManagedDrafts.Unavailable)
        assert(drafts.read("a").isEmpty && drafts.read("b").nonEmpty)
        recorded(drafts.create("create_b","b",source),true)
      }
      println(s"MANAGED_DRAFT_SUMMARY $passed PASS; inert storage only, native release separately required")
    } finally {
      if(store!=null)store.close()
      val paths=Files.walk(root);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()
    }
  }
}
