package veri7vn.diagnostics

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.runtime.effects.ResourceBudget

/** Actual governed captured-source callback. Native failure IDs below are fixture
  * data; this does not qualify the separate D43 native association producer. */
object RetainedSourceDiagnosticTests {
  def main(args:Array[String]):Unit={
    val source=Files.createTempDirectory("v7-retained-diagnostic-source-").toRealPath()
    val root=Files.createTempDirectory("v7-retained-diagnostic-store-").toRealPath()
    val original="(* λ original *)\nlemma broken: False\n"
    val originalBytes=original.getBytes(UTF_8)
    Files.write(source.resolve("Demo.thy"),originalBytes)
    Files.write(source.resolve("package.json"),"{}".getBytes(UTF_8))
    // SourceObjects reserves max(archive,file) before each protected read.
    val limits=Intake.Limits(maxArchiveBytes=65536,maxFileBytes=65536,maxTotalBytes=262144,maxEntries=32)
    val store=new WorkspaceStore(root)
    try {
      val managed=new ManagedSources(store);val drafts=new ManagedDrafts(managed,limits)
      drafts.create("diagnostic-create","demo",Intake.directory(source,Intake.Format.NativeDevelopment,limits))
      val manifest=managed.withHead("demo")((head,_)=>head).get
      val revision=drafts.read("demo").get
      val budget=ResourceBudget(BigInt(101),16L*1024*1024,128,8,32,1024*1024,512,24,1)
      val owned=NativeBuildInputs.materialize(managed,"demo",manifest,budget,limits).get
      try {
        val start="(* λ original *)\nlemma ".getBytes(UTF_8).length
        val failure=BuildFailure.Failure(BigInt(1),BigInt(2),BuildFailure.Phase.Replay,
          Some(BuildFailure.Span(start,start+6)),BuildFailure.Message.Text("Fixture unresolved proof"))
        val before=owned.inspectCapturedSourceRetained("Demo.thy") {(captured,bytes)=>
          SourceDiagnostic.locate(captured,bytes,failure,Some(SourceDiagnostic.Head(manifest,revision.id)))
        }
        assert(before.status==SourceDiagnostic.SourceStatus.Current && before.location.get.start==SourceDiagnostic.Position(2,7))
        val replacement="(* current source shifted *)\n\n\nlemma broken: True\n".getBytes(UTF_8)
        val edit=drafts.edit("diagnostic-edit","demo",manifest,revision.id,Vector(
          Intake.Edit("Demo.thy",0,originalBytes.length,Intake.Content(originalBytes),Intake.Content(replacement))))
        assert(edit.isInstanceOf[ManagedDrafts.Recorded])
        val currentManifest=managed.withHead("demo")((head,_)=>head).get
        val currentRevision=drafts.read("demo").get.id
        val historical=owned.inspectCapturedSourceRetained("Demo.thy") {(captured,bytes)=>
          SourceDiagnostic.locate(captured,bytes,failure,Some(SourceDiagnostic.Head(currentManifest,currentRevision)))
        }
        assert(historical.status==SourceDiagnostic.SourceStatus.Historical && historical.source.revision==revision.id)
        assert(historical.location==before.location && historical.source.pin.sha256==Intake.hash(originalBytes))
        drafts.forgetStorage("demo")
        var called=false;var denied=false
        try owned.inspectCapturedSourceRetained("Demo.thy"){(_,_)=>called=true}
        catch {case _:IllegalStateException=>denied=true;case _:IllegalArgumentException=>denied=true}
        assert(denied && !called && !owned.isLive)
        println("RETAINED_SOURCE_DIAGNOSTIC_PASS actual owned callback original Unicode positions after edit historical pins Forget denial; native-ID join not tested")
      }finally owned.close()
    }finally store.close()
  }
}
