package veri7vn.packages.native_build
import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.{SessionInventory,ManagedDrafts}
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.runtime.effects.ResourceBudget
object NativeBuildInputsTests {
  def main(args:Array[String]):Unit=isabelle.Command_Line.tool {checks()}
  def checks():Unit={
    val root=Files.createTempDirectory("v7-native-build-inputs-").toRealPath()
    def bytes(s:String)=s.getBytes(UTF_8)
    Files.write(root.resolve("ROOT"),bytes("session Native_Build_Input_Test = HOL +\n theories Input\n"))
    Files.write(root.resolve("Input.thy"),bytes("theory Input imports Main begin end\n"))
    val inventory=SessionInventory.inspect("Native_Build_Input_Test",Vector(root))
    val pins=inventory.sources.map(s=>s.path->NativeBuildInputs.Pin(s.sha256,s.size)).toMap
    val (local,installed)=pins.partition((p,_)=>java.nio.file.Path.of(p).startsWith(root))
    NativeBuildInputs.verify(root,local,inventory,installed)
    def rejects(body: =>Unit):Unit={var rejected=false
      try body catch {case _:IllegalArgumentException=>rejected=true;case _:IllegalStateException=>rejected=true}
      assert(rejected,"Incorrect native source closure accepted")}
    rejects(NativeBuildInputs.verify(root,local,inventory,Map.empty))
    val source=root.resolve("Input.thy").toString
    rejects(NativeBuildInputs.verify(root,local.updated(source,NativeBuildInputs.Pin("0"*64,local(source).size)),inventory,installed))
    val descriptor="""{"format":"veri7vn.package/0","package":{"id":"test.native","version":"1.0.0","title":"Native","description":"Captured intent"},"files":[{"path":"Input.thy","role":"source"}],"requires":[],"native":{"session":"Native_Build_Input_Test","theories":["Input"]},"capabilities":[{"id":"selection","title":"Selection","specification":{"theory":"Input","name":"selection_spec"},"contracts":[{"theory":"Input","name":"selection_contract"}],"executable":{"theory":"Input","name":"selection_code"}}]}"""
    Files.write(root.resolve("package.json"),bytes(descriptor))
    val storeRoot=Files.createTempDirectory("v7-native-build-store-")
    val store=new WorkspaceStore(storeRoot)
    scala.util.Using.resource(store) { _ =>
      val host=new ManagedSources(store)
      val drafts=new ManagedDrafts(host)
      val staged=Intake.directory(root,Intake.Format.NativeDevelopment)
      val manifest=drafts.create("build_source_create","build_source",staged) match {
        case ManagedDrafts.Recorded(_,_)=>host.withHead("build_source")((head,_)=>head).get
        case other=>throw new AssertionError("source create failed: "+other)
      }
      val capturedRevision=drafts.read("build_source").get.id
      val parent=storeRoot.resolve("managed-workers")
      val budget=ResourceBudget(BigInt(7),512L*1024*1024,4096,4,2048,64L*1024*1024,512,24,1)
      val owned=NativeBuildInputs.materialize(host,"build_source",manifest,budget).get
      scala.util.Using.resource(owned) { _ =>
      owned.inspect("Native_Build_Input_Test",Vector("."),installed)
      assert(owned.isLive)
      val intent=owned.exportIntent
      assert(intent eq owned.exportIntent,"intent was not captured once")
      intent.inspect {view=>
        assert(view.draft=="build_source" && view.manifest==manifest && view.revision==capturedRevision && view.descriptorPath=="package.json")
        assert(view.descriptorPin==NativeBuildInputs.Pin(Intake.hash(bytes(descriptor)),bytes(descriptor).length.toLong))
        val capability=view.descriptor.exports.head
        assert(capability.specification.name=="selection_spec" && capability.contracts.head.name=="selection_contract")
        assert(capability.executable.exists(_.name=="selection_code"))
      }
      var borrowed:Option[java.nio.ByteBuffer]=None
      intent.withOriginal {original=>
        assert(original.isReadOnly)
        borrowed=Some(original)
        assert(UTF_8.decode(original.duplicate()).toString==descriptor,"intent original source changed")
      }
      assert(borrowed.get.get(0)==0,"temporary descriptor transport was not cleared")
      owned.withCapturedSource("Input.thy") {(captured,original)=>
        assert(captured.draft=="build_source" && captured.revision==capturedRevision && captured.manifest==manifest && captured.path=="Input.thy")
        assert(UTF_8.decode(original.duplicate()).toString=="theory Input imports Main begin end\n")
        borrowed=Some(original)
      }
      assert(borrowed.get.get(0)==0,"temporary source transport was not cleared")
      rejects(owned.withCapturedSource("missing.thy")((_,_)=>()))
      val originalTheory="theory Input imports Main begin end\n"
      val editedTheory="theory Input imports Main begin (* edited *) end\n"
      val edited=drafts.edit("build_source_edit","build_source",manifest,capturedRevision,
        Vector(Intake.Edit("Input.thy",0,bytes(originalTheory).length,
          Intake.Content(bytes(originalTheory)),Intake.Content(bytes(editedTheory)))))
      assert(edited.isInstanceOf[ManagedDrafts.Recorded])
      rejects(owned.withCapturedSource("Input.thy")((_,_)=>()))
      owned.inspectCapturedSourceRetained("Input.thy") {(captured,original)=>
        assert(captured.revision==capturedRevision && captured.manifest==manifest)
        assert(UTF_8.decode(original.duplicate()).toString==originalTheory,"historical inspection remapped current head")
      }
      drafts.forgetStorage("build_source")
      assert(!owned.isLive && !intent.isLive)
      rejects(intent.inspect(_=>()))
      rejects(intent.withOriginal(_=>()))
      rejects(owned.withCapturedSource("Input.thy")((_,_)=>()))
      rejects(owned.inspectCapturedSourceRetained("Input.thy")((_,_)=>()))
      rejects(owned.inspect("Native_Build_Input_Test",Vector("."),installed))
      val remaining=Files.list(parent)
      try assert(remaining.count()==0,"forgotten build workspace remains") finally remaining.close()
      }
    }
    Files.write(root.resolve("ROOT"),bytes("session Changed = HOL +\n"))
    rejects(NativeBuildInputs.verify(root,local,inventory,installed))
    println("NATIVE_BUILD_INPUTS_PASS actual_inventory_pinned_closure_and_swaps")
  }
}
