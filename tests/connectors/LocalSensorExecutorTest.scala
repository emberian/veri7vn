package veri7vn.runtime.connectors
import scala.language.unsafeNulls
import java.nio.file.Files
import veri7vn.runtime.effects.*
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.sources.LocalSnapshot.*
object LocalSensorExecutorTest {
  def main(args:Array[String]):Unit={
    val dir=Files.createTempDirectory("stateful-connector-")
    val store=new WorkspaceStore(dir)
    try {
      val sources=new ManagedSources(store)
      val raw=Files.readAllBytes(java.nio.file.Paths.get("tests/sources/import/fixtures/rows-v1.bin"))
      // Captured wire bytes still require native decoding and the same acquisition ticket.
      val stage=sources.begin("sensor-input",Array[Byte](1),"sensor",None) match {
        case ManagedSources.Fresh(s)=>s;case _=>sys.error("stage")
      }
      val member=stage.put(raw)
      val configMember=stage.put("fixture acquisition mapping v1; protected credential reference".getBytes(java.nio.charset.StandardCharsets.UTF_8))
      require(stage.commit(member,Vector(member,configMember)).isInstanceOf[ManagedSources.Published])
      val config=CapturedAcquisitionConfiguration.capture("sensor",member,configMember,7,1,
        "fixture/topic","source-row/1:nullable,integer,text,blob","fixture-row/1","retain-invalid/1",11,1)
      val binding=new LocalAcquisitionBinding(config)
      val manifest=Manifest("fixture-sensor",Some("1"),"source-row/1:nullable,integer,text,blob","bytes","fixture",
        "fixture-row/1",None,None,Vector("opaque source report"),None,Some("C"),Vector.empty,Vector.empty,
        Acquisition(Some(Clock("source-event","fixture",1)),Clock("source-event","fixture",100),
          Some(Clock("source-event","fixture",100)),1,config.observationConfiguration,None,"retain-invalid/1",Origin.Measured),Retention.Private)
      val executor=new LocalSensorExecutor(member,manifest,config,binding)
      val profile=OperationProfile.installApproved(OperationIdentity(1,2,3,"a"*64,
        "local-sensor-acquire/1",5,4,0),executor,1,WorkerLimits(1000,524288,64),65536)
      val attempt=AttemptIdentity(store.nativeWorkspace,5,6,2,member)
      var firstLease:Option[InputLease]=None
      require(OperationProfile.withAuthorizedInput(sources,"sensor",member,member,attempt,Vector(7),profile) {
        input=>firstLease=Some(input);profile.handoff(attempt,input)
      }.isDefined)
      val first=executor.reconcile(attempt)
      require(first.isInstanceOf[Reconciled.Confirmed])
      require(executor.reconcile(attempt)==first,"reconciliation must not reexecute")
      executor.withCaptured(attempt) {candidate=>
        require(candidate.bytes.sameElements(raw))
        require(candidate.manifest.acquisition.event.get.ticks==1)
        require(candidate.manifest.acquisition.poll.get.ticks==100)
        require(candidate.manifest.acquisition.origin==Origin.Measured)
      }
      // Same endpoint, changed protected credential reference: never reuse old
      // connection/configuration occurrence or relabel its existing observation.
      val changedCredentialOnly=CapturedAcquisitionConfiguration.capture("sensor",member,configMember,7,1,
        "fixture/topic","source-row/1:nullable,integer,text,blob","fixture-row/1","retain-invalid/1",12,2)
      var sameOccurrenceChangedCredentialDenied=false
      try binding.withCurrent(changedCredentialOnly)(()) catch {case _:IllegalArgumentException=>sameOccurrenceChangedCredentialDenied=true}
      require(sameOccurrenceChangedCredentialDenied,"credential change reused old same-endpoint binding/epoch")
      var unchangedEpochDenied=false
      try binding.retireForReplacement(changedCredentialOnly) catch {case _:IllegalArgumentException=>unchangedEpochDenied=true}
      require(unchangedEpochDenied,"configuration change accepted without new binding/epoch")
      val nextConfig=CapturedAcquisitionConfiguration.capture("sensor",member,configMember,8,2,
        "fixture/topic","source-row/1:nullable,integer,text,blob","fixture-row/1","retain-invalid/1",12,2)
      var changedConfigDenied=false
      try binding.withCurrent(nextConfig)(()) catch {case _:IllegalArgumentException=>changedConfigDenied=true}
      require(changedConfigDenied,"same endpoint reused a different credential/configuration occurrence")
      require(!config.toString.contains("fixture/topic") && !binding.toString.contains("fixture/topic"))
      val historical=executor.withCaptured(attempt)(candidate=>prepare(candidate.bytes,candidate.manifest))
      binding.retireForReplacement(nextConfig) // signals, joins and releases registered lease
      require(firstLease.get.size==0,"configuration retirement retained managed input payload")
      require(executor.reconcile(attempt)==first,"configuration retirement changed known acquisition outcome")
      var retiredConfigDenied=false
      try executor.withCaptured(attempt)(_=>()) catch {case _:IllegalArgumentException=>retiredConfigDenied=true}
      require(retiredConfigDenied,"old configuration could reach publication consumer")
      require(historical.isLive && historical.manifest.acquisition.configuration==config.observationConfiguration)
      require(historical.manifest.acquisition.origin==Origin.Measured && historical.manifest.acquisition.event.get.ticks==1)
      val nextBinding=new LocalAcquisitionBinding(nextConfig)
      var relabelDenied=false
      try new LocalSensorExecutor(member,manifest,nextConfig,nextBinding)
      catch {case _:IllegalArgumentException=>relabelDenied=true}
      require(relabelDenied,"old snapshot manifest relabeled as new configuration")
      val nextManifest=manifest.copy(acquisition=manifest.acquisition.copy(configuration=nextConfig.observationConfiguration))
      val nextExecutor=new LocalSensorExecutor(member,nextManifest,nextConfig,nextBinding)
      val nextProfile=OperationProfile.installApproved(OperationIdentity(9,10,3,"a"*64,
        "local-sensor-acquire/1",11,4,0),nextExecutor,1,WorkerLimits(1000,524288,64),65536)
      val nextAttempt=AttemptIdentity(store.nativeWorkspace,11,12,10,member)
      require(OperationProfile.withAuthorizedInput(sources,"sensor",member,member,nextAttempt,Vector(8),nextProfile) {
        input=>nextProfile.handoff(nextAttempt,input)
      }.isDefined)
      nextExecutor.withCaptured(nextAttempt) {candidate=>
        require(candidate.manifest.acquisition.configuration==nextConfig.observationConfiguration)
        require(candidate.manifest.acquisition.configuration!=historical.manifest.acquisition.configuration)
      }
      // Fixture registration above is separate: retirement itself installed nothing.
      // Real source retirement reaches attached executor and erases its captured root.
      store.revokeSource("sensor")
      require(executor.reconcile(attempt)==first,"retirement must preserve known outcome, not imply failure")
      require(nextExecutor.reconcile(nextAttempt).isInstanceOf[Reconciled.Confirmed])
      var nextDenied=false
      try nextExecutor.withCaptured(nextAttempt)(_=>()) catch {case _:IllegalArgumentException=>nextDenied=true}
      require(nextDenied,"source retirement failed to stop replacement worker")
      require(historical.isLive,"retiring one live occurrence deleted independently retained historical snapshot")
      historical.release()
      var denied=false
      try executor.withCaptured(attempt)(_=>()) catch {case _:IllegalArgumentException=>denied=true}
      require(denied,"retired capture accessible")
      require(OperationProfile.withAuthorizedInput(sources,"sensor",member,member,attempt,
        Vector(7),profile)(input=>profile.handoff(attempt,input)).isEmpty)
      println("LOCAL_SENSOR_EXECUTOR_PASS")
    } finally store.close()
  }
}
