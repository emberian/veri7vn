package veri7vn.runtime.effects
import scala.language.unsafeNulls
import java.nio.file.Files
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
object OperationProfileTest {
  def main(args:Array[String]):Unit={
    val directory=Files.createTempDirectory("effects-profile-")
    val store=new WorkspaceStore(directory)
    try {
      val sources=new ManagedSources(store)
      val stage=sources.begin("input-stage",Array[Byte](1),"input-draft",None) match {
        case ManagedSources.Fresh(value)=>value
        case other=>throw new IllegalStateException(other.toString)
      }
      val member=stage.put(Array[Byte](4,5,6))
      assert(stage.commit(member,Vector(member)).isInstanceOf[ManagedSources.Published])
      var count=0
      var held:Option[InputLease]=None
      val executor=new Executor {
        val protocol="local-test/1"
        def handoff(identity:AttemptIdentity,limits:WorkerLimits,input:InputLease):Unit={
          assert(input.identity==identity && input.readOnly.get(0)==4.toByte)
          count+=1;held=Some(input)
        }
        def reconcile(identity:AttemptIdentity):Reconciled=Reconciled.Unknown
        def signalStop(identity:AttemptIdentity):Unit=()
        def stop(identity:AttemptIdentity):Unit=()
        def awaitStopped(identity:AttemptIdentity):Unit={held=None}
      }
      val profile=OperationProfile.installApproved(OperationIdentity(1,2,3,"a"*64,"local-copy",4,0),
        executor,1,WorkerLimits(1000,1024,64),64)
      val attempt=AttemptIdentity(store.nativeWorkspace,5,6,2,member)
      assert(OperationProfile.withAuthorizedInput(sources,"input-draft",member,member,attempt,
        Vector(7),profile)(input=>profile.handoff(attempt,input)).isDefined)
      assert(count==1)
      val lease=held.get;val oldView=lease.readOnly
      profile.stop(attempt)
      assert(lease.size==0 && oldView.get(0)==0.toByte)
      def releasedMetadata(input:InputLease):Boolean=try {
        input.sourceDraft;input.sourceHead;input.member;input.dependencies;input.identity;false
      } catch {case _:IllegalArgumentException=>true;case _:IllegalStateException=>true}
      assert(releasedMetadata(lease))
      var rejected=false
      try OperationProfile.withAuthorizedInput(sources,"input-draft","b"*64,member,attempt,
        Vector(7),profile)(input=>profile.handoff(attempt,input))
      catch {case _:IllegalArgumentException=>rejected=true}
      assert(rejected && count==1)
      var failedLease:Option[InputLease]=None
      var failed=false
      try OperationProfile.withAuthorizedInput(sources,"input-draft",member,member,attempt,
        Vector(7),profile) {input=>failedLease=Some(input);throw new java.io.IOException("handoff uncertain")}
      catch {case _:java.io.IOException=>failed=true}
      assert(failed && failedLease.get.size==0 && count==1 && releasedMetadata(failedLease.get))
      val next=sources.begin("next-input",Array[Byte](2),"input-draft",Some(member)) match {
        case ManagedSources.Fresh(value)=>value
        case other=>throw new IllegalStateException(other.toString)
      }
      val newMember=next.put(Array[Byte](8,9))
      assert(next.commit(newMember,Vector(newMember)).isInstanceOf[ManagedSources.Published])
      var oldMemberDenied=false
      try OperationProfile.withAuthorizedInput(sources,"input-draft",newMember,member,attempt,
        Vector(7),profile)(input=>profile.handoff(attempt,input))
      catch {case _:IllegalArgumentException=>oldMemberDenied=true}
      assert(oldMemberDenied && count==1)
      store.revokeSource("input-draft")
      assert(OperationProfile.withAuthorizedInput(sources,"input-draft",member,member,attempt,
        Vector(7),profile)(input=>profile.handoff(attempt,input)).isEmpty)
      assert(count==1)
    } finally store.close()
    println("VERI7VN_EFFECTS operation_profile PASS")
  }
}
