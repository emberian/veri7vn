package veri7vn.runtime.host

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.effects.ResourceBudget

/** Storage/ownership test. Native observation and owner-confirmation are explicit
  * fixture boundaries; this is not an MCP invocation/admission test. */
object NativeEffectSourceTests {
  def main(args:Array[String]):Unit={
    import WorkspaceStore.*
    val base=Files.createTempDirectory("effect-source-").toRealPath()
    val input=Files.createDirectory(base.resolve("input"))
    Files.writeString(input.resolve("Demo.thy"),"theory Demo imports Main begin end")
    Files.writeString(input.resolve("package.json"),"{}")
    val limits=Intake.Limits(maxArchiveBytes=65536,maxFileBytes=65536,maxTotalBytes=262144,maxEntries=32)
    val budget=ResourceBudget(BigInt(0),16L*1024*1024,128,8,64,1024*1024,512,24,1)
    val root=base.resolve("workspace")
    var store=new WorkspaceStore(root)
    var sources=new ManagedSources(store)
    var drafts=new ManagedDrafts(sources,limits)
    require(drafts.create("create","input",Intake.directory(input,Intake.Format.NativeDevelopment,limits)).isInstanceOf[ManagedDrafts.Recorded])
    val head=sources.withHead("input")((head,_)=>head).get
    val revision=drafts.read("input").get.id
    val owned=NativeBuildInputs.materialize(sources,"input",head,budget,limits).get
    val original="{\"response\":\"λ observed\"}".getBytes(UTF_8)
    val uid=BigInt(31)
    val slots=Vector("projection"->Array[Byte](1),"sequent"->Array.emptyByteArray,
      "context_closure"->Array[Byte](2),"reconstruction"->original,"executable"->Array[Byte](3))
    val map=slots.toMap
    val attrs=Vector("version"->"2","profile"->"local-mcp/1","role"->"effect-source-observation",
      "workspace"->store.nativeWorkspace,"association"->uid.toString,"semantic-generation"->"32",
      "projection"->digest(map("projection")),"sequent"->digest(map("sequent")),
      "context-closure"->digest(map("context_closure")),"kind"->"controlled-recipe",
      "payload"->digest(original),"executable"->digest(map("executable")))
    val envelope=("\u0005\u0006veri7vn-native-association\u0006"+attrs.map((k,v)=>k+"="+v).mkString("\u0006")+"\u0005\u0005\u0006\u0005").getBytes(UTF_8)
    val material=new NativeRecoveryMaterial(uid,BigInt(32),("manifest"->envelope)+:slots,Vector(uid,BigInt(11),BigInt(12),BigInt(13)))
    val identity=NativeEffectSources.Identity(uid,BigInt(10),BigInt(11),BigInt(12),BigInt(13),digest(map("projection")),digest(original),original.length)
    val index=store.nativeEffectSources
    val stage=index.stage(Vector(owned.currentSourceGuard,owned.currentSourceGuard),ByteBuffer.wrap(original))
    val mismatched=index.stage(Vector(owned.currentSourceGuard,owned.currentSourceGuard),ByteBuffer.wrap(original))
    var refused=false
    try index.prepare(mismatched,identity.copy(payload="0"*64),material) catch {case _:IllegalArgumentException=>refused=true}
    assert(refused,"unrelated response identity adopted private bytes")
    mismatched.close()
    assert(mismatched.bytes.forall(_==0),"retired private response clone remained readable")
    val failedStage=index.stage(Vector(owned.currentSourceGuard,owned.currentSourceGuard),ByteBuffer.wrap(original))
    val scratch=failedStage.registrations.head.createScratchRoot()
    val obstruction=Files.writeString(scratch.resolve("fixture-untracked-child"),"owned test obstruction")
    var cleanupFailed=false
    try failedStage.close() catch {case _:java.nio.file.DirectoryNotEmptyException=>cleanupFailed=true}
    assert(cleanupFailed && failedStage.bytes.forall(_==0) && failedStage.registrations.nonEmpty,
      "failed response teardown lost tracked registrations or retained original bytes")
    assert(store.nativeEffectStageFailures.exists(_._1==failedStage.id),"cleanup failure was hidden")
    // Remove only this fixture's own obstruction, then use the SAME parent pump
    // entry point after its retry deadline (advanced under the test boundary).
    Files.delete(obstruction)
    store.managedRead(_=>failedStage.cleanupAfter=0L)
    store.maintainNativeEffectStages()
    assert(failedStage.registrations.isEmpty && store.nativeEffectStageFailures.isEmpty)
    val prepared=index.prepare(stage,identity,material)
    def count(table:String):Long=store.managedRead {c=>val q=c.createStatement();try {val r=q.executeQuery("SELECT COUNT(*) FROM "+table);require(r.next());r.getLong(1)} finally q.close()}
    def denied(body: => Any):Unit={var failure=false;try body catch {case _:IllegalArgumentException|_:IllegalStateException=>failure=true};assert(failure)}
    assert(count("managed_source_drafts")==1 && count("native_acquired_sources")==0,"pending response became source draft")
    assert(store.commitNative("wrong",1,0,0,Array[Byte](1),Array[Byte](2),Some(material),effectSource=Some(prepared)).isEmpty)
    store.afterNativeBlobPublish=()=>throw new IllegalStateException("before response transaction")
    denied(store.commitNative("failed",0,0,0,Array[Byte](1),Array[Byte](2),Some(material),effectSource=Some(prepared)))
    assert(store.latestNative.isEmpty && count("native_acquired_sources")==0)
    store.afterNativeBlobPublish=()=>()
    store.commitNative("response",0,0,0,Array[Byte](1),Array[Byte](2),Some(material),effectSource=Some(prepared)).get
    assert(store.managedRead {c=>val q=c.createStatement();try {val r=q.executeQuery("SELECT state FROM native_acquired_sources");require(r.next());r.getString(1)} finally q.close()}=="pending_ack")
    val oldResident=new Object
    val oldIssuer=index.newOwnerIssuer(oldResident)
    val oldConfirmation=oldIssuer.confirm(oldResident,identity,store.latestNative.get.sequence,BigInt(32),BigInt(1),BigInt(1),"confirmed")
    // Crash/lost native acknowledgement: the durable row is still pending_ack.
    // Drop only transient host owners, then cold-reopen without replay/dispatch.
    prepared.close();material.release();owned.close();store.close()
    store=new WorkspaceStore(root);sources=new ManagedSources(store);drafts=new ManagedDrafts(sources,limits)
    // Actual deployment must supply this confirmation from its reconstructed
    // owner query; old journal/material presence alone is insufficient.
    assert(store.managedRead {c=>val q=c.createStatement();try {val r=q.executeQuery("SELECT state FROM native_acquired_sources");require(r.next());r.getString(1)} finally q.close()}=="pending_ack")
    val reopened=store.nativeEffectSources
    denied(reopened.openConfirmed(store.latestNative.get,oldConfirmation))
    val actualResident=new Object // explicit native owner-query fixture boundary
    val issuer=reopened.newOwnerIssuer(actualResident)
    denied(issuer.confirm(new Object,identity,store.latestNative.get.sequence,BigInt(32),BigInt(1),BigInt(1),"confirmed"))
    def confirmed()=issuer.confirm(actualResident,identity,store.latestNative.get.sequence,BigInt(32),BigInt(1),BigInt(1),"confirmed")
    val once=confirmed()
    val lease=reopened.openConfirmed(store.latestNative.get,once).get
    denied(reopened.openConfirmed(store.latestNative.get,once))
    val stale=confirmed()
    store.commitNative("unrelated",1,0,0,Array[Byte](3),Array[Byte](4)).get
    denied(reopened.openConfirmed(store.latestNative.get,stale))
    assert(store.managedRead {c=>val q=c.createStatement();try {val r=q.executeQuery("SELECT state FROM native_acquired_sources");require(r.next());r.getString(1)} finally q.close()}=="live")
    var borrowed:ByteBuffer=null
    lease.inspect {bytes=>borrowed=bytes;val actual=new Array[Byte](bytes.remaining());bytes.get(actual);assert(actual.sameElements(original));java.util.Arrays.fill(actual,0.toByte)}
    assert((0 until borrowed.limit()).forall(i=>borrowed.get(i)==0),"response bytes escaped borrowed scope")
    denied(store.close())
    assert(drafts.edit("edit","input",head,revision,Vector(Intake.Edit("Demo.thy",0,0,Intake.Content(Array.emptyByteArray),Intake.Content("(* new head *)".getBytes(UTF_8))))).isInstanceOf[ManagedDrafts.Recorded])
    lease.inspect(bytes=>assert(bytes.remaining()==original.length))
    val beforeRevoke=confirmed()
    store.commitNative("revoke",2,0,1,Array[Byte](5),Array[Byte](6),invalidations=Some(new NativeInvalidations("revoke",Vector(BigInt(12))))).get
    denied(reopened.openConfirmed(store.latestNative.get,beforeRevoke))
    denied(lease.inspect(_=>throw new AssertionError("revoked response callback entered")))
    assert(reopened.openConfirmed(store.latestNative.get,confirmed()).isEmpty)
    sources.forget("input")
    denied(lease.inspect(_=>throw new AssertionError("forgotten response callback entered")))
    assert(reopened.openConfirmed(store.latestNative.get,confirmed()).isEmpty)
    assert(count("native_acquired_sources")==1,"Forget deleted ownership before native drain")
    lease.close()
    // Native forget commit + cleanup barrier are controlled fixture boundaries.
    store.nativeSourceCleanupQueued(uid,"77","fixture")
    store.nativeSourceCleanupAcknowledged("77","fixture")
    store.completeNativeSourceCleanup()
    assert(count("native_acquired_sources")==0)
    store.close()
    println("NATIVE_EFFECT_SOURCE_HOST_PASS private_stage retained_failed_cleanup atomic_commit_rollback lost_ack_cold_reopen borrowed_wipe historical_headedit fresh_oneuse_confirmation revoke_race old_resident_denial forget_denial controlled_native_boundary")
  }
}
