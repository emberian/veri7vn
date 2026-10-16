package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import veri7vn.runtime.host.{ManagedSources,WorkspaceStore}
import veri7vn.runtime.effects.{ResourceBudget,WorkerResources,WorkerLifetime}
import veri7vn.runtime.connectors.{CapturedAcquisitionConfiguration,LocalAcquisitionBinding}
import veri7vn.runtime.service.effects.NativeMcpConfiguration
import veri7vn.packages.intake.Intake.Content
import veri7vn.packages.lifecycle.InertJSON
import veri7vn.sources.LocalSnapshot

/** Managed source metadata is inert data. Native source UID and retained owner
  * arrive only after the protected supervisor uploads this exact capture once. */
object McpIngress {
  final case class ConfigurationSource(draft:String,head:String,member:String,sha256:String,size:Int,epoch:BigInt)
  final class Installation private[mcp] (private val owned:LocalMcpFixture.Owned,
      private val configuration:CapturedAcquisitionConfiguration,
      private[runtime] val nativeConfiguration:NativeMcpConfiguration,
      private[runtime] val sources:ManagedSources) extends AutoCloseable {
    private[runtime] def currentSourceGuard:WorkspaceStore.NativeSourceGuard=owned.resources.get.currentSourceGuard
    private[runtime] def session:McpConnectorSession=owned.session
    private[runtime] def configurationLabel:String=configuration.observationConfiguration
    private[runtime] def withCurrent[A](consume: => A):A=owned.session.current(consume)
    def close():Unit=owned.close()
    override def toString:String="McpInstallation(<managed protected configuration>)"
  }
  final class StagedConfiguration private[mcp] (
      private[runtime] val descriptor:ConfigurationSource,private val sources:ManagedSources,resources:WorkerResources,
      bytes:WorkerResources#OwnedBytes,credentialOwner:BigInt,credentialRevision:BigInt) extends AutoCloseable {
    private val active=new AtomicBoolean(true)
    @volatile private var installed:Option[LocalMcpFixture.Owned]=None
    private[runtime] def currentSourceGuard:WorkspaceStore.NativeSourceGuard=resources.currentSourceGuard
    private var claimed=false
    @volatile private var transfers=Vector.empty[WorkerLifetime]
    private var transferReservation=false
    private[runtime] def trackTransfer(worker:WorkerLifetime):Unit=resources.withCurrent {synchronized {
      require(active.get() && transfers.size<8,"MCP configuration transfer retry bound")
      // One envelope covers the driver's two globally concurrent bounded uploads;
      // stopped retry jobs keep ownership metadata, but release their byte copies.
      if(!transferReservation) {val root=resources.reserveRoot[Unit](98304);root.install(());transferReservation=true}
      transfers :+= worker
    }}
    private[runtime] def withBytes[A](consume:ByteBuffer=>A):A=resources.withCurrent {
      require(active.get(),"MCP configuration capture unavailable");consume(bytes.readOnly)
    }
    /** Only a service-owned association from the same supervisor's native config
      * finish may cross here. There is no raw numeric UID overload. */
    private[runtime] def install(association:NativeMcpConfiguration):Installation=resources.withCurrent {synchronized {
      require(active.get() && !claimed,"MCP configuration already installed or retired")
      val uid=association.claim(descriptor,this)
      claimed=true
      val config=CapturedAcquisitionConfiguration.capture(descriptor.draft,descriptor.head,descriptor.member,uid,
        descriptor.epoch,"local-mcp://counter","mcp-counter/1","fixed-counter/1","source-response/1",credentialOwner,credentialRevision)
      val owned=LocalMcpFixture.open(config,new LocalAcquisitionBinding(config))
      owned.resources=Some(resources);owned.session.attachSource(resources);installed=Some(owned)
      new Installation(owned,config,association,sources)
    }}
    private[mcp] def invalidate():Unit={active.set(false);transfers.foreach(_.invalidate());installed.foreach(_.session.invalidate())}
    private[mcp] def release():Unit={
      invalidate();transfers.foreach(_.awaitStopped());transfers=Vector.empty;installed.foreach(_.releaseFixture());installed=None
    }
    def close():Unit=resources.close()
    override def toString:String="McpStagedConfiguration(<managed protected source>)"
  }
  final case class PacketSource(draft:String,head:String,member:String,sha256:String,size:Int)
  final class StagedPacket private[mcp] (private[runtime] val sources:ManagedSources,private[runtime] val installation:Installation,
      private[runtime] val packet:McpWorkflow.Prepared,private[runtime] val descriptor:PacketSource,
      resources:WorkerResources,bytes:WorkerResources#OwnedBytes) extends AutoCloseable {
    private[runtime] def currentSourceGuards:Vector[WorkspaceStore.NativeSourceGuard]=
      Vector(installation.currentSourceGuard,resources.currentSourceGuard)
    private val active=new AtomicBoolean(true)
    @volatile private var response:Option[McpObservationRecord.Candidate]=None
    private var responseRoot:Option[WorkerResources#OwnedRoot[McpObservationRecord.Candidate]]=None
    @volatile private var transfers=Vector.empty[WorkerLifetime]
    private var transferReservation=false
    private[runtime] def trackTransfer(worker:WorkerLifetime):Unit=resources.withCurrent {synchronized {
      require(active.get() && transfers.size<8,"MCP packet/response transfer retry bound")
      // Response upload retries retain the SAME candidate; they do not reserve a
      // new source root or repeat the operation that produced the response.
      if(!transferReservation) {val root=resources.reserveRoot[Unit](1343488);root.install(());transferReservation=true}
      transfers :+= worker
    }}
    private[mcp] def retainResponse(produce: => McpObservationRecord.Candidate):McpObservationRecord.Candidate=
        resources.withCurrent {synchronized {
      require(active.get() && response.isEmpty,"MCP response record already captured or unavailable")
      val root=responseRoot.getOrElse {
        val reserved=resources.reserveRoot[McpObservationRecord.Candidate](589824);responseRoot=Some(reserved);reserved
      }
      val candidate=produce
      try {root.install(candidate);response=Some(candidate);candidate}
      catch {case failure:Throwable=>candidate.close();throw failure}
    }}
    private[runtime] def withBytes[A](consume:ByteBuffer=>A):A=installation.withCurrent {resources.withCurrent {
      require(active.get(),"MCP packet source unavailable");consume(bytes.readOnly)
    }}
    private[mcp] def invalidate():Unit={active.set(false);transfers.foreach(_.invalidate());response.foreach(_.invalidate())}
    private[mcp] def release():Unit={invalidate();transfers.foreach(_.awaitStopped());transfers=Vector.empty;response.foreach(_.close());response=None}
    def close():Unit=resources.close()
    override def toString:String="McpStagedPacket(<managed source linked to installed configuration>)"
  }
  /** Produce a fresh inert managed request source without editing configuration.
    * Native packet upload must link installation.nativeConfiguration's SAME owner. */
  private[runtime] def stagePacket(installation:Installation,
      packet:McpWorkflow.Prepared,stageKey:String,draft:String,expectedHead:Option[String],
      resourceOwner:BigInt):StagedPacket=installation.withCurrent {
    val sources=installation.sources
    require(packet.configurationLabel==installation.configurationLabel,"MCP packet configuration changed")
    val raw=packet.bytes
    val descriptor=try {
      val stage=sources.begin(stageKey,raw,draft,expectedHead) match {
        case ManagedSources.Fresh(value)=>value
        case _=>throw new IllegalStateException("MCP fresh packet stage required")
      }
      try {
        val member=stage.put(raw)
        require(member==packet.inputArtifact,"MCP staged packet hash")
        require(stage.commit(member,Vector(member)).isInstanceOf[ManagedSources.Published],"MCP packet publication conflict")
        PacketSource(draft,member,member,member,raw.length)
      } catch {case failure:Throwable=>stage.abort();throw failure}
    } finally java.util.Arrays.fill(raw,0.toByte)
    val budget=ResourceBudget(resourceOwner,2097152,1,4,1,0,128,1,2)
    WorkerResources.withCurrentCapture(sources,descriptor.draft,descriptor.head,budget) {capture=>
      val bytes=capture.read(descriptor.member,16384)
      val staged=new StagedPacket(sources,installation,packet,descriptor,capture.resources,bytes)
      val root=capture.resources.reserveRoot[StagedPacket](4096);root.install(staged)
      capture.resources.attachWorker(new WorkerLifetime {
        def invalidate():Unit=staged.invalidate()
        def awaitStopped():Unit=staged.release()
      })
      staged
    }.getOrElse(throw new IllegalStateException("MCP packet source unavailable"))
  }
  /** Capture owns bytes before parsing and creates no session/native UID. Host
    * protected credential references are not authored JSON or public wire fields. */
  private[runtime] def stage(sources:ManagedSources,draft:String,expectedHead:String,
      configMember:String,epoch:BigInt,resourceOwner:BigInt,
      credentialOwner:BigInt,credentialRevision:BigInt):Option[StagedConfiguration]={
    val budget=ResourceBudget(resourceOwner,196608,1,2,1,0,128,1,2)
    WorkerResources.withCurrentCapture(sources,draft,expectedHead,budget) {capture=>
      val bytes=capture.read(configMember,16384)
      val view=bytes.readOnly;val raw=new Array[Byte](view.remaining())
      val (fields,sha)=try {
        view.get(raw)
        (InertJSON.objectValue(InertJSON.parse(Content(raw),16384,8,1024)),LocalSnapshot.hash(raw))
      } finally java.util.Arrays.fill(raw,0.toByte)
      require(sha==configMember,"MCP actual configuration member hash")
      require(fields.keySet==Set("protocol","endpoint","schema","mapping","quality"),"MCP configuration fields")
      require(fields("protocol")=="local-mcp/1" && fields("endpoint")=="local-mcp://counter" &&
        fields("schema")=="mcp-counter/1" && fields("mapping")=="fixed-counter/1" &&
        fields("quality")=="source-response/1","MCP fixed local configuration")
      require(Vector(epoch,credentialOwner,credentialRevision).forall(n=>n>=0 && n.bitLength<=256),"MCP protected reference bounds")
      val descriptor=ConfigurationSource(draft,expectedHead,configMember,sha,bytes.size,epoch)
      val staged=new StagedConfiguration(descriptor,sources,capture.resources,bytes,credentialOwner,credentialRevision)
      val root=capture.resources.reserveRoot[StagedConfiguration](32768);root.install(staged)
      capture.resources.attachWorker(new WorkerLifetime {
        def invalidate():Unit=staged.invalidate()
        def awaitStopped():Unit=staged.release()
      })
      staged
    }
  }
}
