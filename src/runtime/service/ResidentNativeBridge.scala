package veri7vn.runtime.service

import scala.language.unsafeNulls
import isabelle.Bytes
import veri7vn.runtime.host.WorkspaceStore

/** Actual resident transport. No client may supply Prepared/event/checkpoint bytes. */
final class ResidentNativeBridge(supervisor: ResidentSupervisor, store: WorkspaceStore,
  buildIngress:Option[NativeBuildIngress]=None)
  extends AuthorityCoordinator.NativeBridge {
  import AuthorityCoordinator.*
  private def initializing[A](action: => A):A=try action catch {case failure:Throwable=>
    try supervisor.close() catch {case cleanup:Throwable=>failure.addSuppressed(cleanup)}
    throw failure
  }
  private val previousResidents=initializing(store.reconcileNativeResidents())
  initializing(store.resetNativeSourceCleanup(supervisor.incarnation))
  private val installedBootImage=initializing {
    val reply=supervisor.exchange("install_boot",artifacts=List(Bytes(supervisor.bootManifest)))
    require(reply.tag=="boot_installed" && reply.payload.matches("[1-9][0-9]{0,17}"),"native boot image installation failed")
    val ownership=store.registerNativeResident(supervisor.incarnation,reply.payload.toLong)
    supervisor.attachResidentOwnership(ownership)
    supervisor.deploymentIdentity
  }
  // Advance and commit the durable counter before native code can allocate.
  // Transport failure burns this lease; it must never be retried as a fresh block.
  private val installedIdentityLease = initializing {
    val lease=store.reserveNativeIds(65536)
    val reply=supervisor.exchange("install_ids",s"${lease.workspace},${lease.first},${lease.past}")
    require(reply.tag=="ids_installed","native durable identity lease installation failed")
    lease
  }
  private final case class BuildBinding(phase:String,input:NativeBuildIngress.PreparedInput,request:BigInt,goal:BigInt,slot:BigInt)
  private var pendingBuild:Option[BuildBinding]=None
  private val releaseQueue=new ProducerReleaseQueue
  private[service] def producerCleanupFailures:Vector[ProducerReleaseQueue.Failure]=releaseQueue.failures
  private[service] def retryProducerCleanup():Unit=releaseQueue.retryExhausted()
  private[service] def sourceCleanupFailures:Vector[(BigInt,Int,String)]=store.nativeSourceCleanupFailures
  private[service] def retrySourceCleanup():Unit=store.retryNativeSourceCleanup()
  // Native owns the exact token -> phase/input/rid/gid/slot relation. Host checks
  // its closed shape and retains the opaque input guard; it does not reimplement
  // the generated reducer. Native consumer tests must reject foreign/expired
  // tokens and mismatched child bindings before returning this association.
  private def buildBinding(id:String):Option[BuildBinding]=buildIngress.flatMap { ingress=>
    val reply=supervisor.exchange("build_current_binding",id)
    require(reply.artifacts.isEmpty,"native build binding artifacts")
    if(reply.tag=="build_binding_none"){require(reply.payload==id,"native build binding token");None}
    else {
      val fields=reply.payload.split(",",-1)
      require(reply.tag=="build_binding" && fields.length==6 && fields(0)==id &&
        Set("reserve","execute","artifact").contains(fields(1)) && fields.drop(2).forall(_.matches("[1-9][0-9]{0,127}")),"native build binding shape")
      Some(BuildBinding(fields(1),ingress.preparedInput(BigInt(fields(2))),BigInt(fields(3)),BigInt(fields(4)),BigInt(fields(5))))
    }
  }
  private var pending: Option[Prepared]=None
  private[service] override def invalidate():Unit={pending.foreach(_.release());pending=None;pendingBuild=None;supervisor.close()}
  private def currentSequence: Long=store.latestNative.map(_.sequence).getOrElse(0L)
  private def token(p: Prepared): String=p.id.substring(p.id.lastIndexOf('_')+1)
  private var cleanupPollAt=0L
  private var cleanupRetryAt=0L
  private var cleanupRetries=0
  private[service] override def maintenance():Unit={
    val now=System.nanoTime()
    // Source teardown and native producer release run outside coordinator/source locks.
    releaseQueue.pump(now)
    if(now>=cleanupPollAt){
      cleanupPollAt=now+1000000000L
      val wall=System.currentTimeMillis()
      store.nextNativeSourceCleanup(wall).foreach {association=>
        try {
          val queued=supervisor.exchange("forget",association.toString)
          require(queued.tag=="lifecycle_queued" && queued.artifacts.isEmpty,"native source cleanup receipt")
          store.nativeSourceCleanupQueued(association,queued.payload,supervisor.incarnation)
        } catch {case scala.util.control.NonFatal(problem)=>
          store.nativeSourceCleanupFailed(association,(problem.getClass.getSimpleName+": "+Option(problem.getMessage).getOrElse("")).take(256),wall)
        }
      }
      val reply=supervisor.exchange("cleanup_barrier")
      require(reply.tag=="cleanup","native cleanup barrier unavailable")
      if(reply.payload=="complete"){
        cleanupRetries=0;cleanupRetryAt=0L
        store.completeNativeSourceCleanup()
        if(store.hasNativeSourceErasure)new veri7vn.runtime.host.ManagedSources(store).eraseReleasedNativeSourceObjects()
        if(store.hasForgottenNativeArtifacts)store.eraseForgottenNativeArtifacts()
      } else {
        require(Set("pending","failed_retryable").contains(reply.payload),"native cleanup barrier shape")
        if(reply.payload=="failed_retryable" && cleanupRetries<8 && now>=cleanupRetryAt){
          val retried=supervisor.exchange("retry_cleanup")
          require(retried.tag=="cleanup" && Set("complete","pending","failed_retryable").contains(retried.payload),"native cleanup retry shape")
          cleanupRetries+=1
          cleanupRetryAt=now+math.min(30000L,250L*(1L<<(cleanupRetries-1)))*1000000L
        }
        // Retain failed native roots and durable erasure intent. Exhaustion does
        // not terminate service or spin on a permanently failing cleanup.
        if(cleanupRetries>=8)cleanupPollAt=now+30000000000L
      }
    }
  }
  private[service] override def initialize(): Option[Prepared] = {
    val reply=supervisor.exchange("initial")
    if(reply.tag!="initial" || reply.artifacts.length!=1) None
    else {
      val bytes=reply.artifacts.head.make_array
      try {
        val p=new Prepared("native_initial",0,0,0,"veri7vn.native-initial/1".getBytes(java.nio.charset.StandardCharsets.US_ASCII),bytes)
        pending=Some(p);Some(p)
      } finally java.util.Arrays.fill(bytes,0.toByte)
    }
  }
  private[service] def prepare(event: EventToken): Either[String,Prepared] = {
    val reply=supervisor.exchange("prepare",event.nativeId)
    if(reply.tag!="prepared") {
      if(reply.payload=="native_gate_expired")store.nativeSourceCleanupRejected(event.nativeId,supervisor.incarnation)
      Left(reply.payload)
    }
    else {
      require(reply.artifacts.length==2,"native prepared shape")
      val fields=reply.payload.split(",",-1)
      require(fields.length==3 && fields(0)==event.nativeId && fields.tail.forall(_.matches("[0-9]{1,18}")),"native prepared identity")
      val eventBytes=reply.artifacts.head.make_array
      val checkpointBytes=reply.artifacts(1).make_array
      var recovery:Option[WorkspaceStore.NativeRecoveryMaterial]=None
      var transferred=false
      try {
        val binding=buildBinding(event.nativeId)
        recovery=readRecovery(event.nativeId)
        val sourceBinding=for {
          bound<-binding
          material<-recovery if WorkspaceStore.isBuildRecovery(material.slots.toMap.apply("manifest"))
        } yield {
          val original=bound.input.original
          store.prepareNativeBuildSource(bound.input.sourceGuard,material.association,bound.request,bound.goal,bound.slot,
            original.revision,original.path,original.pin.sha256,original.pin.size)
        }
        val p=new Prepared("native_"+supervisor.incarnation+"_"+event.nativeId,currentSequence,fields(1).toLong,fields(2).toLong,
          eventBytes,checkpointBytes,recovery=recovery,dispatch=readDispatch(event.nativeId),invalidations=readInvalidations(event.nativeId),sourceGuard=binding.map(_.input.sourceGuard),sourceBinding=sourceBinding)
        pendingBuild=binding;pending=Some(p);transferred=true;Right(p)
      } finally {
        java.util.Arrays.fill(eventBytes,0.toByte);java.util.Arrays.fill(checkpointBytes,0.toByte)
        if(!transferred)recovery.foreach(_.release())
      }
    }
  }
  private def readInvalidations(id:String):Option[WorkspaceStore.NativeInvalidations]={
    val reply=supervisor.exchange("artifact_invalidations",id)
    require(reply.tag=="artifact_invalidations","native invalidation response")
    if(reply.payload==s"$id,none") {require(reply.artifacts.isEmpty);None}
    else {
      val fields=reply.payload.split(",",-1)
      require(fields.length==2 && fields.head==id && Set("revoke","forget").contains(fields(1)) && reply.artifacts.size==1 && reply.artifacts.head.size<=1048576,"native invalidation frame")
      val bytes=reply.artifacts.head.make_array
      require(bytes.forall(b=>b>=32 && b<=126),"native invalidation ASCII")
      val ids=new String(bytes,java.nio.charset.StandardCharsets.US_ASCII).split(",",-1).toVector
      require(ids.size<=8192 && ids.forall(_.matches("[1-9][0-9]{0,127}")),"native invalidation identities")
      Some(new WorkspaceStore.NativeInvalidations(fields(1),ids.map(BigInt(_))))
    }
  }
  private def readDispatch(id:String):Option[WorkspaceStore.NativeDispatchMaterial]={
    val reply=supervisor.exchange("command_info",id)
    require(reply.tag=="commands","native command qualification unavailable")
    if(reply.artifacts.isEmpty) None
    else {
      require(reply.payload==id && reply.artifacts.size==1 && reply.artifacts.head.size<=4096,"native command frame")
      val bytes=reply.artifacts.head.make_array
      require(bytes.forall(b=>b>=32 && b<=126),"native command ASCII")
      val fields=new String(bytes,java.nio.charset.StandardCharsets.US_ASCII).split(",",-1)
      require(fields.length==9 && fields.head=="pure" && fields.tail.forall(_.matches("[1-9][0-9]{0,127}")),"native command identity")
      Some(new WorkspaceStore.NativeDispatchMaterial("pure",BigInt(fields(1)),BigInt(0),supervisor.deploymentIdentity,bytes))
    }
  }
  private def readRecovery(id:String):Option[WorkspaceStore.NativeRecoveryMaterial]={
    val reply=supervisor.exchange("recovery_info",id)
    if(reply.tag=="recovery_none") {require(reply.payload==id && reply.artifacts.isEmpty);None}
    else {
      require(reply.tag=="recovery" && reply.artifacts.isEmpty,"native recovery header")
      val fields=reply.payload.split(",",-1)
      require((fields.length==8 || fields.length==9) && fields.head==id && fields.slice(1,3).forall(_.matches("[1-9][0-9]{0,127}")),"native recovery identity")
      val caps=Vector(8192,1048576,1048576,16777216,100000,1048576)
      val names=Vector("manifest","projection","sequent","context_closure","reconstruction","executable")
      val buffers=scala.collection.mutable.ArrayBuffer.empty[Array[Byte]]
      try {
      val slots=(0 until (fields.length-3)).map { slot=>
        require(fields(slot+3).matches("[0-9]{1,8}"),"native recovery length")
        val length=fields(slot+3).toInt
        require(length<=caps(slot) && (length>0 || (slot==2 && buffers.nonEmpty && WorkspaceStore.nonassertionalRecovery(buffers.head))),"native recovery bound")
        val bytes=new Array[Byte](length);buffers+=bytes
        var offset=0
        while(offset<length){
          val part=supervisor.exchange("recovery_read",s"$id,$slot,$offset")
          require(part.tag=="recovery_bytes" && part.payload==s"$id,$slot,$offset" && part.artifacts.size==1,"native recovery chunk")
          val chunk=part.artifacts.head
          require(chunk.size>0 && chunk.size<=65536 && chunk.size<=length-offset,"native recovery chunk bound")
          val array=chunk.make_array
          try {System.arraycopy(array,0,bytes,offset,array.length);offset+=array.length}
          finally java.util.Arrays.fill(array,0.toByte)
        }
        names(slot)->bytes
      }.toVector
      val edges=supervisor.exchange("recovery_dependencies",id)
      require(edges.tag=="recovery_dependencies" && edges.payload==id && edges.artifacts.size==1 && edges.artifacts.head.size<=1048576,"native dependency frame")
      val edgeBytes=edges.artifacts.head.make_array
      require(edgeBytes.forall(b=>b>=32 && b<=126),"native dependency ASCII")
      val ids=new String(edgeBytes,java.nio.charset.StandardCharsets.US_ASCII).split(",",-1).toVector
      require(ids.nonEmpty && ids.size<=8192 && ids.forall(_.matches("[1-9][0-9]{0,127}")),"native dependency identity")
      Some(new WorkspaceStore.NativeRecoveryMaterial(BigInt(fields(1)),BigInt(fields(2)),slots,ids.map(BigInt(_))))
      } finally buffers.foreach(a=>java.util.Arrays.fill(a,0.toByte))
    }
  }
  private[service] def validatePrecommit(p: Prepared): Boolean = pending.exists(_ eq p) && {
    if(p.id=="native_initial") {
      val reply=supervisor.exchange("initial")
      reply.tag=="initial" && reply.artifacts.length==1 && reply.artifacts.head==Bytes(p.checkpointBytes)
    } else supervisor.exchange("validate",token(p)).tag=="valid"
  }
  private[service] def acknowledge(p: Prepared): Boolean = {
    if(!pending.exists(_ eq p)) return false
    val committed=store.latestNative.getOrElse(throw new IllegalStateException("native acknowledgement without commit"))
    require(committed.sequence==p.expectedSequence+1 && committed.id==p.id &&
      java.util.Arrays.equals(committed.event,p.eventBytes) && java.util.Arrays.equals(committed.checkpoint,p.checkpointBytes),"native acknowledgement commit mismatch")
    val reply=if(p.id=="native_initial") supervisor.exchange("restore",committed.sequence.toString,List(Bytes(p.checkpointBytes)))
      else supervisor.exchange("ack",s"${token(p)},${committed.sequence}")
    val accepted=reply.artifacts.isEmpty && (if(p.id=="native_initial")reply.tag=="restored"
      else reply.tag=="acknowledged" && reply.payload==token(p))
    if(accepted) {
      if(p.id!="native_initial")store.nativeSourceCleanupAcknowledged(token(p),supervisor.incarnation)
      pendingBuild.filter(_.phase=="artifact").foreach(binding=>releaseQueue.enqueue(binding.input))
      pendingBuild=None;pending=None
    }
    accepted
  }
  private[service] def recover(record: WorkspaceStore.NativeRecord): Boolean = {
    if(record.id=="native_initial" && record.sequence==1 && record.revision==0 && record.epoch==0){
      val reply=supervisor.exchange("restore",record.sequence.toString,List(Bytes(record.checkpoint)))
      pending=None;return reply.tag=="restored"
    }
    var installed=false
    var primary:Throwable=null
    try {
      val begin=supervisor.exchange("restore_begin",s"${store.nativeWorkspace},${record.sequence},${record.revision},${record.epoch}",List(Bytes(record.checkpoint)))
      require(begin.tag=="restore_required" && begin.payload=="2" && begin.artifacts.size==1 && begin.artifacts.head.size<=1048576,"native restore closure unavailable")
      val text=begin.artifacts.head.text
      val required=if(text.isEmpty)Vector.empty else text.split("\n",-1).toVector
      require(required.size<=8192,"native restore association bound")
      var seen=Set.empty[BigInt]
      required.foreach {line=>
        val fields=line.split(",",-1)
        require(fields.length==3 && Set("request-child","artifact","evidence").contains(fields(0)) && fields.tail.forall(_.matches("[1-9][0-9]{0,127}")),"native restore required identity")
        val association=BigInt(fields(1));val generation=BigInt(fields(2))
        require(!seen.contains(association),"duplicate native restore association");seen+=association
        val capability=store.committedNativeRecovery(record,association).getOrElse(throw new IllegalStateException("required native origin unavailable"))
        try capability.withMaterial {material=>
          require(material.semanticGeneration==generation,"native restore semantic generation mismatch")
          require(WorkspaceStore.matchesRecoveryRequirement(material.slots.toMap.apply("manifest"),fields(0)),"native restore category/profile/role mismatch")
          val names=Vector("manifest","projection","sequent","context_closure","reconstruction")++(if(material.slots.exists(_._1=="executable"))Vector("executable")else Vector.empty)
          val slots=material.slots.toMap
          val header=(Vector(association.toString,generation.toString,capability.originSequence.toString)++names.map(name=>slots(name).length.toString)).mkString(",")
          require(supervisor.exchange("restore_material_begin",header).tag=="restore_material_ready","native restore material refused")
          names.zipWithIndex.foreach {case(name,index)=>
            val bytes=slots(name);var offset=0
            while(offset<bytes.length){
              val count=math.min(65536,bytes.length-offset)
              val reply=supervisor.exchange("restore_write",s"$association,$index,$offset",List(Bytes(bytes,offset,count)))
              require(reply.tag=="restore_written","native restore chunk refused");offset+=count
            }
          }
          require(supervisor.exchange("restore_material_end",association.toString).tag=="restore_material_staged","native restore material verification refused")
        } finally capability.close()
      }
      require(supervisor.exchange("restore_finish").tag=="restore_verifying","native restore did not start")
      val deadline=System.nanoTime()+300L*1000*1000*1000
      var progress=supervisor.exchange("restore_progress")
      while(progress.tag=="restore_verifying" && System.nanoTime()<deadline){Thread.sleep(25);progress=supervisor.exchange("restore_progress")}
      installed=progress.tag=="restored" && progress.payload=="complete_no_dispatch_replay"
      if(installed)store.nativeSourceCleanupAcknowledged("",supervisor.incarnation)
      pending=None;installed
    } catch {case problem:Throwable=>primary=problem;throw problem}
    finally {
      if(!installed){
        var cleanup:Throwable=null
        try supervisor.exchange("restore_abort") catch {case problem:Throwable=>cleanup=problem}
        try supervisor.close() catch {case problem:Throwable=>if(cleanup==null)cleanup=problem else cleanup.addSuppressed(problem)}
        if(cleanup!=null){if(primary!=null)primary.addSuppressed(cleanup) else throw cleanup}
      }
    }
  }
}
