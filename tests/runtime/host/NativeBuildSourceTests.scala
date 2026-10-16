package veri7vn.runtime.host
import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.effects.ResourceBudget

/** Actual durable managed ownership and cold JVM-equivalent store reopen. Native
  * envelope contents are fixture metadata, not actual Build admission/replay. */
object NativeBuildSourceTests {
  def main(args:Array[String]):Unit={
    import WorkspaceStore.*
    val base=Files.createTempDirectory("native-build-source-").toRealPath()
    val original="(* λ original *)\nlemma original: True by simp\n".getBytes(UTF_8)
    val directory=Files.createDirectory(base.resolve("input"))
    Files.write(directory.resolve("Demo.thy"),original)
    Files.writeString(directory.resolve("package.json"),"{}")
    val limits=Intake.Limits(maxArchiveBytes=65536,maxFileBytes=65536,maxTotalBytes=262144,maxEntries=32)
    val budget=ResourceBudget(BigInt(0),16L*1024*1024,128,8,64,1024*1024,512,24,1)
    val root=base.resolve("workspace")
    var store=new WorkspaceStore(root)
    var sources=new ManagedSources(store)
    var drafts=new ManagedDrafts(sources,limits)
    require(drafts.create("create","demo",Intake.directory(directory,Intake.Format.NativeDevelopment,limits)).isInstanceOf[ManagedDrafts.Recorded])
    val manifest=sources.withHead("demo")((head,_)=>head).get
    val revision=drafts.read("demo").get.id
    val owned=NativeBuildInputs.materialize(sources,"demo",manifest,budget,limits).get
    val slot=BigInt(13)
    val recoverySlots=Vector("projection"->Array[Byte](1),"sequent"->Array.emptyByteArray,
      "context_closure"->Array[Byte](2),"reconstruction"->Array[Byte](3),"executable"->Array[Byte](4))
    val slots=recoverySlots.toMap
    val attrs=Vector("version"->"2","profile"->"native-development/1","role"->"build-request",
      "workspace"->store.nativeWorkspace,"association"->slot.toString,"semantic-generation"->"12",
      "projection"->digest(slots("projection")),"sequent"->digest(slots("sequent")),
      "context-closure"->digest(slots("context_closure")),"kind"->"controlled-recipe",
      "payload"->digest(slots("reconstruction")),"executable"->digest(slots("executable")))
    val envelope=("\u0005\u0006veri7vn-native-association\u0006"+attrs.map((k,v)=>k+"="+v).mkString("\u0006")+"\u0005\u0005\u0006\u0005").getBytes(UTF_8)
    val material=new NativeRecoveryMaterial(slot,BigInt(12),("manifest"->envelope)+:recoverySlots,Vector(slot))
    def count(table:String):Long=store.managedRead {c=>val q=c.createStatement();try {val r=q.executeQuery("SELECT COUNT(*) FROM "+table);require(r.next());r.getLong(1)} finally q.close()}
    def denies(body: => Any):Unit={var rejected=false;try body catch {case _:IllegalArgumentException=>rejected=true;case _:IllegalStateException=>rejected=true};assert(rejected)}
    val binding=store.prepareNativeBuildSource(owned.currentSourceGuard,slot,BigInt(11),BigInt(12),slot,revision,"Demo.thy",Intake.hash(original),original.length)
    try {
      assert(store.commitNative("wrong_sequence",1,0,0,Array[Byte](1),Array[Byte](2),Some(material),source=Some(binding)).isEmpty)
      assert(count("native_source_bindings")==0 && count("native_source_pins")==0)
      store.afterNativeBlobPublish=()=>throw new IllegalStateException("fixture failure before source/journal transaction")
      denies(store.commitNative("failed",0,0,0,Array[Byte](1),Array[Byte](2),Some(material),source=Some(binding)))
      assert(store.latestNative.isEmpty && count("native_source_bindings")==0 && count("native_source_pins")==0)
      store.afterNativeBlobPublish=()=>()
      store.commitNative("committed",0,0,0,Array[Byte](1),Array[Byte](2),Some(material),source=Some(binding)).get
      assert(count("native_source_bindings")==1 && count("native_source_pins")>0)
    } finally {material.release();owned.close()}
    val next="(* current head *)\n\nlemma current: True by simp\n".getBytes(UTF_8)
    assert(drafts.edit("edit","demo",manifest,revision,Vector(Intake.Edit("Demo.thy",0,original.length,Intake.Content(original),Intake.Content(next)))).isInstanceOf[ManagedDrafts.Recorded])
    store.close()
    store=new WorkspaceStore(root);sources=new ManagedSources(store);drafts=new ManagedDrafts(sources,limits)
    val capability=store.committedNativeBuildSource(store.latestNative.get,slot).get
    assert(capability.source.manifest==manifest && capability.source.revision==revision)
    val historical=NativeBuildInputs.recoverHistorical(sources,capability,budget,limits)
    try {
      historical.inspectCapturedSourceRetained {(captured,bytes)=>
        val actual=new Array[Byte](bytes.remaining());bytes.get(actual)
        assert(actual.sameElements(original) && captured.revision==revision && captured.manifest==manifest)
        java.util.Arrays.fill(actual,0.toByte)
      }
      assert(drafts.read("demo").get.entries.find(_.path=="Demo.thy").get.content.bytes.sameElements(next))
      denies(store.close()) // Actual registered historical owner still blocks shutdown.
      // Revoke denies inspection but retains the source relationship/pins for a
      // later Forget upgrade; an unrelated acknowledgement cannot erase them.
      store.commitNative("revoke",1,1,0,Array[Byte](5),Array[Byte](6),invalidations=Some(new NativeInvalidations("revoke",Vector(slot)))).get
      denies(historical.inspectCapturedSourceRetained {(_,_)=>()})
      assert(count("native_source_pins")>0 && count("native_source_cleanup")==0)
      drafts.forgetStorage("demo")
      var entered=false
      denies(historical.inspectCapturedSourceRetained {(_,_)=>entered=true})
      assert(!entered && store.committedNativeBuildSource(store.latestNative.get,slot).isEmpty)
      assert(count("native_source_cleanup")==1 && count("native_source_pins")>0)
      val objectPath=root.resolve("managed-sources/objects").resolve(Intake.hash(original))
      assert(Files.exists(objectPath),"native-owned original erased before acknowledged cleanup")
      store.nativeSourceCleanupAcknowledged("88","unrelated")
      store.completeNativeSourceCleanup()
      assert(count("native_source_pins")>0 && Files.exists(objectPath),"Revoke mistaken for completed Forget")
      // Controlled native acknowledgement/barrier boundary, not a native test.
      store.nativeSourceCleanupQueued(slot,"77","fixture")
      store.nativeSourceCleanupAcknowledged("77","fixture")
      assert(Files.exists(objectPath))
      store.completeNativeSourceCleanup();sources.eraseReleasedNativeSourceObjects()
      assert(count("native_source_pins")==0 && !Files.exists(objectPath))
    } finally {historical.close();store.close()}
    println("NATIVE_BUILD_SOURCE_HOST_PASS actual ownership commit rollback headedit coldreopen original inspection Forget denial; native producer/barrier are fixture boundaries")
  }
}
