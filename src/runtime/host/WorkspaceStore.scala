package veri7vn.runtime.host

import isabelle.{SQLite, Path => IPath}
import scala.language.unsafeNulls
import java.nio.file.{Files, Path, StandardCopyOption, StandardOpenOption}
import java.nio.channels.FileChannel
import java.security.MessageDigest

object WorkspaceStore {
  final case class Limits(maxBlobBytes: Int = 16 * 1024 * 1024, maxBatchBytes: Int = 32 * 1024 * 1024,
    maxEntries: Int = 4096, maxNameBytes: Int = 1024) {
    require(maxBlobBytes > 0 && maxBatchBytes >= maxBlobBytes && maxEntries > 0 && maxNameBytes > 0)
  }
  final case class DraftFile(name: String, bytes: Array[Byte])
  final case class DraftAck(id: String, revision: Long)
  final case class Conflict(currentRevision: Long)
  trait ManagedResourceOwner {
    /** Nonblocking signal only; never join a worker while the source lock is held. */
    def invalidate(): Unit
    def stopAndRelease(): Unit
  }
  final class ManagedResourceRegistration private[host](store:WorkspaceStore,private[host] val id:String) {
    def isLive:Boolean=store.managedResourceLive(id)
    def withCurrent[A](action: => A):A=store.withManagedResourceCurrent(id)(action)
    def withRetained[A](action: => A):A=store.withManagedResourceRetained(id)(action)
    private[veri7vn] def currentGuard:NativeSourceGuard=new NativeSourceGuard(store,id)
    def release():Unit=store.releaseManagedResource(id)
    def createScratchRoot():Path=store.createResourceScratch(id)
    def reserveScratchDirectory(relative:String):Path=store.reserveResourceScratch(id,relative,true,0)
    def reserveScratchFile(relative:String,size:Long):Path=store.reserveResourceScratch(id,relative,false,size)
  }
  /** Opaque identity of an actual registered captured source owner. Only the
    * owning store can check it; caller-supplied IDs cannot create it. */
  private[veri7vn] final class NativeSourceGuard private[host](
    private[host] val store:WorkspaceStore,private[host] val resource:String)
  final case class NativeBuildSource(association:BigInt,request:BigInt,goal:BigInt,slot:BigInt,
    draft:String,manifest:String,revision:String,path:String,sha256:String,size:Long)
  private[runtime] final class NativeBuildSourceMaterial private[host](
    private[host] val guard:NativeSourceGuard,val source:NativeBuildSource,
    private[host] val pins:Vector[(String,Long)])
  /** Actual durable source ownership imported only from authenticated native
    * recovery plus its committed host lease. It conveys no resume authority. */
  final class NativeBuildSourceLease private[host](private[host] val store:WorkspaceStore,
    val source:NativeBuildSource) extends AutoCloseable {
    private[host] var active=true
    private[veri7vn] def withRetained[A](action: => A):A=store.withNativeBuildSourceLease(this)(action)
    def close():Unit=store.releaseNativeBuildSourceLease(this)
  }
  private[runtime] final class NativeResidentOwnership private[host](private val store:WorkspaceStore,val incarnation:String) {
    private[runtime] def confirmStopped():Unit=store.confirmNativeResidentStopped(incarnation)
  }
  final class NativeIdLease private[host](val workspace: String, val first: BigInt, val past: BigInt)
  /** Service-owned native export bytes; this is storage material, not proof authority. */
  private[runtime] final class NativeRecoveryMaterial private[runtime](
    val association: BigInt, val semanticGeneration: BigInt, input: Vector[(String,Array[Byte])],
    private[runtime] val dependencies:Vector[BigInt]) {
    require(dependencies.nonEmpty && dependencies.size<=8192 && dependencies.distinct.size==dependencies.size &&
      dependencies.forall(n=>n>0 && n.toString.length<=128) && dependencies.contains(association),"native managed dependency closure")
    private val required=Set("manifest","projection","sequent","context_closure","reconstruction")
    require(association>0 && semanticGeneration>0 && association.toString.length<=128 && semanticGeneration.toString.length<=128)
    require(input.size>=5 && input.size<=6 && input.map(_._1).distinct.size==input.size)
    require(required.subsetOf(input.map(_._1).toSet) && input.forall(p=>required.contains(p._1) || p._1=="executable"))
    input.foreach {case(name,bytes)=>require(bytes.length <= (if(name=="manifest")8192 else if(name=="context_closure")16*1024*1024 else if(name=="reconstruction")100000 else 1024*1024),"native recovery slot limit")}
    require(input.foldLeft(0L)((n,p)=>n+p._2.length)<=32L*1024*1024,"native recovery aggregate limit")
    private var payload:Option[Vector[(String,Array[Byte])]]=Some(input.map {case(name,bytes)=>(name,bytes.clone())})
    private[runtime] def slots:Vector[(String,Array[Byte])]=synchronized {payload.getOrElse(throw new IllegalStateException("native recovery material released"))}
    private[runtime] def release():Unit=synchronized {payload.foreach(_.foreach(p=>java.util.Arrays.fill(p._2,0.toByte)));payload=None}
  }
  private[runtime] final class CommittedNativeRecovery private[host](
    val workspace: String, val sequence: Long, val originSequence:Long, val epoch: Long,
    private[host] val material: NativeRecoveryMaterial,private val owner:WorkspaceStore) extends AutoCloseable {
    private[runtime] def withMaterial[A](consume:NativeRecoveryMaterial=>A):A=owner.withNativeRecovery(this)(consume)
    def close():Unit=owner.releaseNativeRecovery(this)
  }
  private[runtime] final class NativeInvalidations private[runtime](val mode:String,val objects:Vector[BigInt]) {
    require(Set("revoke","forget").contains(mode) && objects.nonEmpty && objects.size<=8192 && objects.distinct.size==objects.size &&
      objects.forall(n=>n>0 && n.toString.length<=128),"native invalidation closure")
  }
  private[runtime] final class NativeDispatchMaterial private[runtime](val kind:String,val id:BigInt,
    val incarnation:BigInt,val deployment:String,input:Array[Byte]) {
    require(Set("pure","effect","job").contains(kind) && id>0 && id.toString.length<=128 &&
      incarnation>=0 && incarnation.toString.length<=128 && deployment.matches("[0-9a-f]{64}"))
    require(input.nonEmpty && input.length<=4096,"native dispatch description bound")
    private[runtime] val command=input.clone()
  }
  private[runtime] final case class NativeDispatchRecord(sequence:Long,kind:String,id:BigInt,
    incarnation:BigInt,deployment:String,command:Array[Byte],status:String)
  final case class NativeRecord(id: String, sequence: Long, revision: Long, epoch: Long, event: Array[Byte], checkpoint: Array[Byte])
  final case class DraftView(id: String, revision: Long, files: Vector[(String, Array[Byte])])
  sealed trait Access
  final case class Available(view: DraftView) extends Access
  case object Unavailable extends Access
  private def recoveryEnvelope(bytes:Array[Byte]):Map[String,String]={
    require(bytes.forall(b=>b==5 || b==6 || (b>=32 && b<=126)),"recovery envelope ASCII framing")
    val text=new String(bytes,java.nio.charset.StandardCharsets.US_ASCII)
    val prefix="\u0005\u0006veri7vn-native-association\u0006"
    val suffix="\u0005\u0005\u0006\u0005"
    require(text.startsWith(prefix) && text.endsWith(suffix),"recovery envelope shape")
    val fields=text.substring(prefix.length,text.length-suffix.length).split("\u0006",-1).toVector.map { field=>
      val equal=field.indexOf('='); require(equal>0 && !field.contains('\u0005'),"recovery envelope attribute")
      (field.substring(0,equal),field.substring(equal+1))
    }
    val keys=Set("version","profile","role","workspace","association","semantic-generation","projection","sequent","context-closure","kind","payload","executable")
    require(fields.size==keys.size && fields.map(_._1).toSet==keys,"recovery envelope fields")
    fields.toMap
  }
  private[runtime] def nonassertionalRecovery(bytes:Array[Byte]):Boolean={
    val m=recoveryEnvelope(bytes)
    m("version")=="2" && m("kind")=="controlled-recipe" && m("executable").matches("[0-9a-f]{64}") && Set(
      "native-development/1"->"build-request","native-development/1"->"build-candidate",
      "quantities/1"->"domain-request",
      "source-quantities/1"->"source-domain-request",
      "native-session-input/1"->"session-input",
      "local-mcp/1"->"effect-source-observation",
      "literal-native-proof/1"->"search-request",
      "native-export-admission/1"->"initial-qualification",
      "native-export-admission/1"->"initial-qualification-request",
      "named-native-export-structure/1"->"update-qualification",
      "named-native-export-structure/1"->"update-qualification-request").contains(m("profile")->m("role"))
  }
  private[runtime] def recoveryCategory(bytes:Array[Byte]):String={
    val m=recoveryEnvelope(bytes)
    (m("profile"),m("role")) match {
      case ("native-kernel/1","kernel-evidence")=>"kernel"
      case ("local-mcp/1","effect-source-observation") if nonassertionalRecovery(bytes)=>"acquired-source"
      case ("native-session-input/1","session-input") if nonassertionalRecovery(bytes)=>"source-input"
      case ("source-quantities/1","source-domain-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("source-quantities-runtime-refinement/1","source-domain-output")=>"refined-output"
      case ("exact-arithmetic/1","math-request")=>"request-child"
      case ("exact-arithmetic/1","math-output")=>"refined-output"
      case ("quantities/1","domain-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("quantities-runtime-refinement/1","domain-output")=>"refined-output"
      case ("literal-native-proof/1","search-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("literal-native-proof/1","search-output")=>"refined-output"
      case ("native-development/1","build-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("native-development/1","build-candidate") if nonassertionalRecovery(bytes)=>"artifact"
      case ("native-export-admission/1","initial-qualification-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("named-native-export-structure/1","update-qualification-request") if nonassertionalRecovery(bytes)=>"request-child"
      case ("native-export-admission/1","initial-qualification") if nonassertionalRecovery(bytes)=>"observation"
      case ("named-native-export-structure/1","update-qualification") if nonassertionalRecovery(bytes)=>"observation"
      case _=>throw new IllegalArgumentException("unsupported recovery category/profile/role")
    }
  }
  private[runtime] def isBuildRecovery(bytes:Array[Byte]):Boolean={
    val m=recoveryEnvelope(bytes);m("profile")=="native-development/1" && Set("build-request","build-candidate").contains(m("role"))
  }
  private[runtime] def matchesRecoveryRequirement(bytes:Array[Byte],requirement:String):Boolean={
    val concrete=recoveryCategory(bytes)
    requirement match {
      case "request-child"=>concrete=="request-child"
      case "artifact"=>concrete=="artifact"
      case "source-input"=>concrete=="source-input"
      case "acquired-source"=>concrete=="acquired-source"
      case "evidence"=>
        val m=recoveryEnvelope(bytes)
        Set("native-kernel/1"->"kernel-evidence","exact-arithmetic/1"->"math-output",
          "native-export-admission/1"->"initial-qualification","named-native-export-structure/1"->"update-qualification",
          "quantities-runtime-refinement/1"->"domain-output","literal-native-proof/1"->"search-output",
          "source-quantities-runtime-refinement/1"->"source-domain-output")
          .contains(m("profile")->m("role"))
      case _=>false
    }
  }
  private[host] def validateRecovery(workspace: String, material: NativeRecoveryMaterial): Unit = {
    val slots=material.slots.toMap
    val m=recoveryEnvelope(slots("manifest"))
    require(m("version")=="2" && m("workspace")==workspace && m("association")==material.association.toString &&
      m("semantic-generation")==material.semanticGeneration.toString,"recovery envelope identity")
    val kernel=m("profile")=="native-kernel/1" && m("role")=="kernel-evidence"
    val math=m("profile")=="exact-arithmetic/1" && Set("math-request","math-output").contains(m("role"))
    val nonassertional=nonassertionalRecovery(slots("manifest"))
    val domainOutput=(m("profile")=="quantities-runtime-refinement/1" && m("role")=="domain-output") ||
      (m("profile")=="source-quantities-runtime-refinement/1" && m("role")=="source-domain-output")
    val searchOutput=m("profile")=="literal-native-proof/1" && m("role")=="search-output"
    require(kernel || math || nonassertional || domainOutput || searchOutput,"unsupported recovery profile/role")
    require(slots.forall {case(name,data)=>name=="sequent" || data.nonEmpty},"empty nonassertion recovery slot")
    require(if(nonassertional) slots("sequent").isEmpty else slots("sequent").nonEmpty,"recovery assertion slot role")
    require(if(kernel) Set("fixed-certificate","native-proof","controlled-recipe").contains(m("kind")) && m("executable").isEmpty
      else m("kind")=="controlled-recipe" && m("executable").nonEmpty,"recovery profile reconstruction")
    for((field,slot)<-Vector("projection"->"projection","sequent"->"sequent","context-closure"->"context_closure","payload"->"reconstruction"))
      require(m(field)==digest(slots(slot)),"recovery named-slot integrity")
    require(m("executable")==slots.get("executable").map(digest).getOrElse(""),"recovery executable integrity")
  }
  private[host] def digest(bytes: Array[Byte]): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).map(b => f"${b & 255}%02x").mkString
}

/** Single durable workspace writer. Source revisions confer no native acceptance;
  * native journal entries are installed only through the service coordinator. */
final class WorkspaceStore(root: Path, val limits: WorkspaceStore.Limits = WorkspaceStore.Limits())
  extends AutoCloseable {
  import WorkspaceStore.*
  private val newRoot= !Files.exists(root,java.nio.file.LinkOption.NOFOLLOW_LINKS)
  Files.createDirectories(root)
  require(!Files.isSymbolicLink(root),"workspace root must be private directory")
  // POSIX is the initial supported deployment profile; source material is host-private.
  private val privatePermissions=java.nio.file.attribute.PosixFilePermissions.fromString("rwx------")
  if(newRoot) Files.setPosixFilePermissions(root,privatePermissions)
  else require(privatePermissions.containsAll(Files.getPosixFilePermissions(root)),"workspace root must exclude group/other access")
  private val blobs = Files.createDirectories(root.resolve("blobs"))
  require(!Files.isSymbolicLink(blobs),"artifact directory must not be a symlink")
  Files.setPosixFilePermissions(blobs,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"))
  private val lockChannel = FileChannel.open(root.resolve("writer.lock"), StandardOpenOption.CREATE, StandardOpenOption.WRITE)
  private val writerLock = try {
    val l = lockChannel.tryLock()
    if (l == null) throw new IllegalStateException("workspace writer already active")
    l
  } catch { case e: Throwable => lockChannel.close(); throw e }
  private val database = try SQLite.open_database(IPath.explode(root.resolve("journal.db").toString))
    catch {case e: Throwable => writerLock.release(); lockChannel.close(); throw e}
  private val connection = database.connection
  private var effectSourceIndex:Option[NativeEffectSources]=None
  private[runtime] def nativeEffectSources:NativeEffectSources=synchronized {
    live();effectSourceIndex.getOrElse {val value=new NativeEffectSources(this);effectSourceIndex=Some(value);value}
  }
  private[runtime] def acknowledgeNativeEffectSource(value:NativeEffectSources.Material):Unit=nativeEffectSources.acknowledged(value)
  private def existingEffectSources:Option[NativeEffectSources]=synchronized {live();effectSourceIndex}
  private[runtime] def maintainNativeEffectStages():Unit=existingEffectSources.foreach(_.retryCleanup())
  private[runtime] def nativeEffectStageFailures:Vector[(String,Int,String)]=existingEffectSources.toVector.flatMap(_.cleanupFailures)
  private[runtime] def retryNativeEffectStages():Unit={existingEffectSources.foreach(_.retryExhausted());maintainNativeEffectStages()}
  private[host] def nativeGuardDraft(guard:NativeSourceGuard):String=withNativeSourceGuard(guard) {
    managedResources(guard.resource).draft
  }
  private[host] def nativeGuardCapture(guard:NativeSourceGuard):(String,String)=withNativeSourceGuard(guard) {
    val resource=managedResources(guard.resource);(resource.draft,resource.head)
  }
  private[runtime] def withNativeEffectSource[A](value:NativeEffectSources.Material)(action: => A):A=synchronized {
    live();require(value.stage.owner eq nativeEffectSources,"foreign effect source material")
    value.stage.guards.foreach(g=>withNativeSourceGuard(g)(()));action
  }
  private var nativeSourceCapabilities=Set.empty[NativeBuildSourceLease]
  private var closed = false
  private var authorityOwner=false
  private var nativeCapabilities=Set.empty[CommittedNativeRecovery]
  private[host] def releaseNativeRecovery(capability:CommittedNativeRecovery):Unit=synchronized {
    capability.material.release();nativeCapabilities-=capability
  }
  private[host] def withNativeRecovery[A](capability:CommittedNativeRecovery)(consume:NativeRecoveryMaterial=>A):A=synchronized {
    live();require(nativeCapabilities.contains(capability) && latestNative.exists(_.sequence==capability.sequence),"native recovery capability no longer current")
    val denied=connection.prepareStatement("SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=? LIMIT 1")
    try {denied.setString(1,capability.material.association.toString);require(!denied.executeQuery().next(),"native association access denied")} finally denied.close()
    consume(capability.material)
  }
  private def exactProcess(pid:Long,started:String):Option[java.lang.ProcessHandle]={
    val candidate=java.lang.ProcessHandle.of(pid)
    if(!candidate.isPresent)None else {
      val handle=candidate.get();val instant=handle.info().startInstant()
      require(instant.isPresent,"process start identity unavailable")
      if(instant.get().toString==started && handle.isAlive)Some(handle) else None
    }
  }
  /** A prior live JVM owner is never killed. Only the exact child of a recorded,
    * terminated owner may be stopped as part of workspace recovery. */
  private[runtime] def reconcileNativeResidents():Unit=synchronized {
    live();require(!authorityOwner,"workspace native owner already active")
    val q=connection.createStatement()
    val rows=try {val r=q.executeQuery("SELECT incarnation,pid,started,owner_pid,owner_started FROM native_residents");val b=Vector.newBuilder[(String,Long,String,Long,String)]
      while(r.next())b+=((r.getString(1),r.getLong(2),r.getString(3),r.getLong(4),r.getString(5)));b.result()} finally q.close()
    rows.foreach {case(incarnation,pid,started,owner,ownerStarted)=>
      exactProcess(pid,started).foreach {process=>
        require(exactProcess(owner,ownerStarted).isEmpty,"previous native JVM owner still running")
        process.destroy()
        try process.onExit().get(5,java.util.concurrent.TimeUnit.SECONDS)
        catch {case _:java.util.concurrent.TimeoutException=>process.destroyForcibly();process.onExit().get(5,java.util.concurrent.TimeUnit.SECONDS)}
        require(!process.isAlive,"previous resident did not stop")
      }
      confirmNativeResidentStopped(incarnation)
    }
  }
  private[runtime] def registerNativeResident(incarnation:String,pid:Long):NativeResidentOwnership=synchronized {
    live();require(incarnation.matches("[0-9a-f]{32}") && pid>0,"native resident identity")
    val actual=java.lang.ProcessHandle.of(pid);require(actual.isPresent && actual.get().isAlive,"native resident missing")
    val started=actual.get().info().startInstant();val owner=java.lang.ProcessHandle.current();val ownerStarted=owner.info().startInstant()
    require(started.isPresent && ownerStarted.isPresent,"native resident process identity unavailable")
    transaction {
      val count=connection.createStatement();try {val r=count.executeQuery("SELECT COUNT(*) FROM native_residents");require(r.next() && r.getInt(1)==0,"native resident already registered")} finally count.close()
      val q=connection.prepareStatement("INSERT INTO native_residents VALUES(?,?,?,?,?)")
      try {q.setString(1,incarnation);q.setLong(2,pid);q.setString(3,started.get().toString);q.setLong(4,owner.pid());q.setString(5,ownerStarted.get().toString);q.executeUpdate()} finally q.close()
    }
    new NativeResidentOwnership(this,incarnation)
  }
  private[host] def confirmNativeResidentStopped(incarnation:String):Unit=synchronized {
    val q=connection.prepareStatement("SELECT pid,started FROM native_residents WHERE incarnation=?")
    val record=try {q.setString(1,incarnation);val r=q.executeQuery();if(r.next())Some((r.getLong(1),r.getString(2)))else None} finally q.close()
    record.foreach {case(pid,started)=>require(exactProcess(pid,started).isEmpty,"resident still retains private roots")}
    transaction {val remove=connection.prepareStatement("DELETE FROM native_residents WHERE incarnation=?")
      try {remove.setString(1,incarnation);remove.executeUpdate()} finally remove.close()}
  }
  private[runtime] def claimAuthorityCoordinator(): Unit = synchronized {
    require(!closed && !authorityOwner,"workspace already has an authority coordinator")
    authorityOwner=true
  }
  private[runtime] def releaseAuthorityCoordinator(): Unit = synchronized {authorityOwner=false}
  private final case class ManagedResource(draft:String,head:String,owner:ManagedResourceOwner,active:Boolean,signalFailure:Option[Throwable]=None,joinMonitor:Object=new Object())
  private var managedResources=Map.empty[String,ManagedResource]
  private[runtime] def registerManagedResource(draft:String,selected:String,owner:ManagedResourceOwner):ManagedResourceRegistration=synchronized {
    live();require(head(draft).contains(selected),"managed source changed before resource registration")
    registerCapturedResource(draft,selected,owner)
  }
  private[host] def registerCapturedResource(draft:String,selected:String,owner:ManagedResourceOwner):ManagedResourceRegistration={
    val id=java.util.UUID.randomUUID().toString
    managedWrite {db=>
      val count=db.prepareStatement("SELECT COUNT(*) FROM managed_resource_regions WHERE draft=?")
      try {count.setString(1,draft);val rows=count.executeQuery();require(rows.next() && rows.getLong(1)<128,"worker resource region limit")} finally count.close()
      val insert=db.prepareStatement("INSERT INTO managed_resource_regions(id,draft,head,state) VALUES(?,?,?,'live')")
      try {insert.setString(1,id);insert.setString(2,draft);insert.setString(3,selected);insert.executeUpdate()} finally insert.close()
    }
    managedResources+=id->ManagedResource(draft,selected,owner,true)
    new ManagedResourceRegistration(this,id)
  }
  private[host] def sourcePermitted(draft:String):Boolean={
    val q=connection.prepareStatement("SELECT 1 FROM managed_source_drafts d JOIN source_heads h ON h.draft=d.draft WHERE d.draft=? AND d.forgotten=0 AND h.revoked=0 AND h.locator<>''")
    try {q.setString(1,draft);q.executeQuery().next()} finally q.close()
  }
  private[runtime] def prepareNativeBuildSource(guard:NativeSourceGuard,association:BigInt,request:BigInt,
    goal:BigInt,slot:BigInt,revision:String,path:String,sha256:String,size:Long):NativeBuildSourceMaterial=synchronized {
    withNativeSourceGuard(guard){
      require(Vector(association,request,goal,slot).forall(n=>n>0 && n.toString.length<=128),"native source binding identity")
      require(revision.matches("[0-9a-f]{64}") && sha256.matches("[0-9a-f]{64}") && size>=0 && size<=1000000,"native source binding pin")
      require(path.nonEmpty && path.length<=4096 && path.endsWith(".thy") && !path.contains('\\') && !path.startsWith("/") &&
        path.split("/",-1).forall(p=>p.nonEmpty && p!="." && p!=".."),"native source binding path")
      val resource=managedResources(guard.resource)
      require(sourcePermitted(resource.draft),"native source binding permission")
      val q=connection.prepareStatement("SELECT DISTINCT c.hash,m.size FROM managed_source_closures c JOIN managed_source_ops o ON o.draft=c.draft AND o.state='committed' JOIN managed_source_members m ON m.op=o.id AND m.hash=c.hash AND m.written=1 WHERE c.draft=? AND c.manifest=? ORDER BY c.hash")
      val pins=try {q.setString(1,resource.draft);q.setString(2,resource.head);val r=q.executeQuery();val b=Vector.newBuilder[(String,Long)];var count=0;var bytes=0L
        while(r.next()){count+=1;require(count<=8192,"native source closure bound");val n=r.getLong(2);require(n>=0 && n<=64L*1024*1024-bytes,"native source closure byte bound");bytes+=n;b+=r.getString(1)->n};b.result()
      } finally q.close()
      require(pins.map(_._1).distinct.size==pins.size && pins.exists(_._1==resource.head) && pins.contains(sha256->size),"native source pin outside actual captured closure")
      new NativeBuildSourceMaterial(guard,NativeBuildSource(association,request,goal,slot,resource.draft,resource.head,revision,path,sha256,size),pins)
    }
  }
  private def readNativeSource(association:BigInt):Option[(NativeBuildSource,String)]={
    val q=connection.prepareStatement("SELECT request,goal,slot,draft,manifest,revision,path,sha256,size,state FROM native_source_bindings WHERE association=?")
    try {q.setString(1,association.toString);val r=q.executeQuery();if(!r.next())None else Some((NativeBuildSource(association,BigInt(r.getString(1)),BigInt(r.getString(2)),BigInt(r.getString(3)),r.getString(4),r.getString(5),r.getString(6),r.getString(7),r.getString(8),r.getLong(9)),r.getString(10)))} finally q.close()
  }
  private[host] def sourceAssociationAllowed(association:BigInt):Boolean={
    val q=connection.prepareStatement("SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=? LIMIT 1")
    try {q.setString(1,association.toString); !q.executeQuery().next()} finally q.close()
  }
  private[host] def withNativeBuildSourceLease[A](lease:NativeBuildSourceLease)(action: => A):A=synchronized {
    live();require((lease.store eq this) && lease.active && nativeSourceCapabilities.contains(lease),"native source lease released or foreign")
    require(readNativeSource(lease.source.association).contains(lease.source->"live") && sourcePermitted(lease.source.draft) && sourceAssociationAllowed(lease.source.association),"native source lease access denied")
    action
  }
  private[host] def releaseNativeBuildSourceLease(lease:NativeBuildSourceLease):Unit=synchronized {lease.active=false;nativeSourceCapabilities-=lease}
  private[runtime] def committedNativeBuildSource(record:NativeRecord,association:BigInt):Option[NativeBuildSourceLease]=synchronized {
    val capability=committedNativeRecovery(record,association)
    capability.flatMap {actual=>try actual.withMaterial {material=>
      val envelope=recoveryEnvelope(material.slots.toMap.apply("manifest"))
      require(envelope("profile")=="native-development/1" && Set("build-request","build-candidate").contains(envelope("role")),"native source lease recovery role")
      readNativeSource(association).filter((source,state)=>state=="live" && sourcePermitted(source.draft) && sourceAssociationAllowed(association)).map {(source,_)=>
        require(nativeSourceCapabilities.size<64,"native source lease capability bound")
        val lease=new NativeBuildSourceLease(this,source);nativeSourceCapabilities+=lease;lease
      }
    } finally actual.close()}
  }
  private[runtime] def committedNativeBuildSourceForRequest(record:NativeRecord,request:BigInt):Option[NativeBuildSourceLease]=synchronized {
    live();require(request>0 && request.toString.length<=128,"native build request identity")
    val q=connection.prepareStatement("SELECT association FROM native_source_bindings WHERE request=? AND association=slot AND state='live' LIMIT 2")
    val found=try {q.setString(1,request.toString);val r=q.executeQuery();val b=Vector.newBuilder[BigInt];while(r.next())b+=BigInt(r.getString(1));b.result()} finally q.close()
    require(found.size<=1,"Build request has multiple children; select an exact child")
    found.headOption.flatMap(association=>committedNativeBuildSource(record,association))
  }
  private[runtime] def registerNativeSourceResource(lease:NativeBuildSourceLease,owner:ManagedResourceOwner):ManagedResourceRegistration=synchronized {
    withNativeBuildSourceLease(lease){registerCapturedResource(lease.source.draft,lease.source.manifest,owner)}
  }
  /** Called within the SAME managed-source denial transaction. */
  private[host] def retireNativeBuildSources(draft:String):Unit=synchronized {
    require(!connection.getAutoCommit,"source retirement requires enclosing transaction")
    val update=connection.prepareStatement("UPDATE native_source_bindings SET state='retiring' WHERE draft=? AND state IN('live','revoked')")
    try {update.setString(1,draft);update.executeUpdate()} finally update.close()
    val acquired=connection.prepareStatement("UPDATE native_acquired_sources SET state='retiring' WHERE state IN('pending_ack','live','revoked') AND (draft1=? OR draft2=?)")
    try {acquired.setString(1,draft);acquired.setString(2,draft);acquired.executeUpdate()} finally acquired.close()
    queueRetiringNativeSources()
  }
  private def queueRetiringNativeSources():Unit={
    execute("INSERT OR IGNORE INTO native_source_cleanup SELECT source,'ready','','',0,'',0 FROM native_acquired_sources WHERE state='retiring'")
    execute("INSERT OR IGNORE INTO native_source_cleanup SELECT association,'ready','','',0,'',0 FROM native_source_bindings WHERE state='retiring'")
  }
  private[host] def nativeSourcePinned(hash:String):Boolean=synchronized {
    val q=connection.prepareStatement("SELECT 1 FROM native_source_pins WHERE hash=? LIMIT 1")
    try {q.setString(1,hash);q.executeQuery().next()} finally q.close()
  }
  private[runtime] def resetNativeSourceCleanup(incarnation:String):Unit=synchronized {live();transaction {
    val q=connection.prepareStatement("UPDATE native_source_cleanup SET state='ready',token='',incarnation='' WHERE state='queued' AND incarnation<>?")
    try {q.setString(1,incarnation);q.executeUpdate()} finally q.close()
  }}
  private[runtime] def nextNativeSourceCleanup(nowMillis:Long):Option[BigInt]=synchronized {
    live();val q=connection.prepareStatement("SELECT association FROM native_source_cleanup WHERE state='ready' AND attempts<8 AND next_millis<=? ORDER BY next_millis,association LIMIT 1")
    try {q.setLong(1,nowMillis);val r=q.executeQuery();if(r.next())Some(BigInt(r.getString(1)))else None} finally q.close()
  }
  private[runtime] def nativeSourceCleanupQueued(association:BigInt,token:String,incarnation:String):Unit=synchronized {live();transaction {
    require(token.matches("[1-9][0-9]{0,17}"),"native source cleanup token")
    val q=connection.prepareStatement("UPDATE native_source_cleanup SET state='queued',token=?,incarnation=? WHERE association=? AND state='ready'")
    try {q.setString(1,token);q.setString(2,incarnation);q.setString(3,association.toString);require(q.executeUpdate()==1,"native source cleanup ownership changed")} finally q.close()
  }}
  private[runtime] def nativeSourceCleanupRejected(token:String,incarnation:String):Unit=synchronized {live();transaction {
    val q=connection.prepareStatement("UPDATE native_source_cleanup SET state='ready',token='',incarnation='' WHERE token=? AND incarnation=? AND state='queued'")
    try {q.setString(1,token);q.setString(2,incarnation);q.executeUpdate()} finally q.close()
  }}
  private[runtime] def nativeSourceCleanupAcknowledged(token:String,incarnation:String):Unit=synchronized {live();transaction {
    val q=connection.prepareStatement("UPDATE native_source_cleanup SET state='acknowledged',token='',incarnation='' WHERE state='queued' AND token=? AND incarnation=?")
    try {q.setString(1,token);q.setString(2,incarnation);q.executeUpdate()} finally q.close()
    // A lost reply may leave an already-durable denial without its local token.
    execute("UPDATE native_source_cleanup SET state='acknowledged',token='',incarnation='' WHERE EXISTS(SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=native_source_cleanup.association AND d.mode='forget')")
  }}
  private[runtime] def nativeSourceCleanupFailed(association:BigInt,reason:String,nowMillis:Long):Unit=synchronized {live();transaction {
    val q=connection.prepareStatement("UPDATE native_source_cleanup SET attempts=MIN(8,attempts+1),error=?,next_millis=? WHERE association=? AND state='ready'")
    try {q.setString(1,reason.take(256));q.setLong(2,nowMillis+30000L);q.setString(3,association.toString);q.executeUpdate()} finally q.close()
  }}
  private[runtime] def nativeSourceCleanupFailures:Vector[(BigInt,Int,String)]=synchronized {
    live();val q=connection.createStatement()
    try {val r=q.executeQuery("SELECT association,attempts,error FROM native_source_cleanup WHERE attempts>=8 ORDER BY association LIMIT 4096");val b=Vector.newBuilder[(BigInt,Int,String)];while(r.next())b+=((BigInt(r.getString(1)),r.getInt(2),r.getString(3)));b.result()} finally q.close()
  }
  private[runtime] def retryNativeSourceCleanup():Unit=synchronized {live();transaction {
    execute("UPDATE native_source_cleanup SET attempts=0,error='',next_millis=0 WHERE state='ready' AND attempts>=8")
  }}
  /** Only after the real native cleanup barrier. Durable erasure intents survive
    * a crash between dropping the final pin and deleting its source-object file. */
  private[runtime] def completeNativeSourceCleanup():Unit=synchronized {live();transaction {
    execute("INSERT OR IGNORE INTO native_source_erase_queue SELECT p.hash,p.size FROM native_source_pins p JOIN native_source_cleanup c ON c.association=p.association WHERE c.state='acknowledged'")
    execute("DELETE FROM native_source_pins WHERE association IN(SELECT association FROM native_source_cleanup WHERE state='acknowledged')")
    execute("UPDATE native_source_bindings SET state='retired',draft='',manifest='',revision='',path='',sha256='',size=0 WHERE association IN(SELECT association FROM native_source_cleanup WHERE state='acknowledged')")
    execute("DELETE FROM native_acquired_sources WHERE source IN(SELECT association FROM native_source_cleanup WHERE state='acknowledged')")
    execute("DELETE FROM native_source_cleanup WHERE state='acknowledged'")
  }}
  private[host] def nativeSourceErasureBatch:Vector[(String,Long)]=synchronized {
    live();val q=connection.createStatement()
    try {val r=q.executeQuery("SELECT hash,size FROM native_source_erase_queue ORDER BY hash LIMIT 64");val b=Vector.newBuilder[(String,Long)];while(r.next())b+=r.getString(1)->r.getLong(2);b.result()} finally q.close()
  }
  private[host] def nativeSourceObjectErased(hash:String):Unit=synchronized {live();transaction {
    val q=connection.prepareStatement("DELETE FROM native_source_erase_queue WHERE hash=?")
    try {q.setString(1,hash);q.executeUpdate()} finally q.close()
  }}
  private[runtime] def hasNativeSourceErasure:Boolean=synchronized {live();val q=connection.createStatement();try q.executeQuery("SELECT 1 FROM native_source_erase_queue LIMIT 1").next() finally q.close()}
  private[host] def managedResourceLive(id:String):Boolean=synchronized {
    !closed && managedResources.get(id).exists(r=>r.active && head(r.draft).nonEmpty)
  }
  private[host] def withManagedResourceCurrent[A](id:String)(action: => A):A=synchronized {
    live();val resource=managedResources.getOrElse(id,throw new IllegalStateException("managed resource released"))
    require(resource.active && head(resource.draft).contains(resource.head),"managed source resource no longer current")
    action
  }
  /** Inspect only the captured registered owner's original bytes. Continued
    * source access is required, but this does not establish current-head use. */
  private[host] def withManagedResourceRetained[A](id:String)(action: => A):A=synchronized {
    live();val resource=managedResources.getOrElse(id,throw new IllegalStateException("managed resource released"))
    require(resource.active && head(resource.draft).nonEmpty,"retained managed source resource unavailable")
    action
  }
  private[runtime] def withNativeSourceGuard[A](guard:NativeSourceGuard)(action: => A):A=synchronized {
    require(guard.store eq this,"native source guard belongs to another workspace")
    withManagedResourceCurrent(guard.resource)(action)
  }
  private[host] def releaseManagedResource(id:String):Unit={
    val monitor=synchronized {managedResources.get(id).map(_.joinMonitor)}
    monitor.foreach {lock=>lock.synchronized {
    val selected=synchronized {
      managedResources.get(id).map {resource=>
        var signalFailure=resource.signalFailure
        managedResources+=id->resource.copy(active=false)
        try resource.owner.invalidate() catch {case failure:Throwable=>signalFailure match {
          case None=>signalFailure=Some(failure);case Some(first)=>first.addSuppressed(failure)}}
        (resource.owner,signalFailure)
      }
    }
    selected.foreach {case(owner,signalFailure)=>
      try owner.stopAndRelease() catch {case failure:Throwable=>
        signalFailure.foreach(failure.addSuppressed);throw failure}
      // A completed join/clear resolves a failed earlier cancellation signal.
      synchronized {cleanupResourceScratch(id);managedResources-=id}
    }
    }}
  }
  private def resourceRoot(id:String):Path={
    require(id.matches("[0-9a-f-]{36}"),"resource identity")
    root.resolve("managed-workers").resolve(id)
  }
  private def scratchRelative(name:String):Vector[String]={
    require(name.nonEmpty && name.length<=4096 && !name.startsWith("/") && !name.contains('\\') && !name.contains('\u0000'),"scratch path bound")
    val parts=name.split("/",-1).toVector
    require(parts.size<=32 && parts.forall(p=>p.nonEmpty && p!="." && p!=".."),"scratch path components")
    parts
  }
  private[host] def createResourceScratch(id:String):Path=withManagedResourceCurrent(id) {
    val parent=root.resolve("managed-workers")
    if(!Files.exists(parent,java.nio.file.LinkOption.NOFOLLOW_LINKS)) {
      Files.createDirectory(parent);Files.setPosixFilePermissions(parent,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"))
    }
    require(Files.isDirectory(parent,java.nio.file.LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(parent),"scratch owner directory")
    val target=resourceRoot(id)
    managedWrite {db=>val q=db.prepareStatement("INSERT INTO managed_resource_paths(region,path,kind,size) VALUES(?,'','directory',0)")
      try {q.setString(1,id);q.executeUpdate()} finally q.close()}
    Files.createDirectory(target)
    Files.setPosixFilePermissions(target,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"));target
  }
  private[host] def reserveResourceScratch(id:String,name:String,directory:Boolean,size:Long):Path=withManagedResourceCurrent(id) {
    val parts=scratchRelative(name);require(size>=0 && size<=1024L*1024*1024,"scratch file bound")
    val target=parts.foldLeft(resourceRoot(id))(_.resolve(_))
    var parent=resourceRoot(id)
    parts.dropRight(1).foreach {part=>require(Files.isDirectory(parent,java.nio.file.LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(parent),"scratch parent");parent=parent.resolve(part)}
    require(Files.isDirectory(parent,java.nio.file.LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(parent),"scratch parent")
    managedWrite {db=>
      val usage=db.prepareStatement("SELECT COUNT(*),COALESCE(SUM(size),0) FROM managed_resource_paths WHERE region=?")
      try {usage.setString(1,id);val rows=usage.executeQuery();require(rows.next() && rows.getLong(1)<8192 && size<=1024L*1024*1024-rows.getLong(2),"scratch inventory budget")} finally usage.close()
      val q=db.prepareStatement("INSERT INTO managed_resource_paths(region,path,kind,size) VALUES(?,?,?,?)")
      try {q.setString(1,id);q.setString(2,name);q.setString(3,if(directory)"directory" else "file");q.setLong(4,size);q.executeUpdate()} finally q.close()}
    target
  }
  private def cleanupResourceScratch(id:String):Unit={
    val q=connection.prepareStatement("SELECT path,kind FROM managed_resource_paths WHERE region=?")
    val entries=try {q.setString(1,id);val r=q.executeQuery();val b=Vector.newBuilder[(String,String)]
      while(r.next())b+=((r.getString(1),r.getString(2)));b.result()} finally q.close()
    val base=resourceRoot(id)
    entries.sortBy {case(name,kind)=>(if(kind=="file")0 else 1,-(if(name.isEmpty)0 else name.count(_=='/')+1))}.foreach {case(name,kind)=>
      val parts=if(name.isEmpty)Vector.empty else scratchRelative(name)
      val target=parts.foldLeft(base)(_.resolve(_))
      var parent=target.getParent
      while(parent!=null && parent.startsWith(base)) {require(!Files.isSymbolicLink(parent),"scratch cleanup parent changed");parent=parent.getParent}
      require(!Files.isSymbolicLink(target),"scratch cleanup entry changed")
      Files.deleteIfExists(target)
    }
    managedWrite {db=>
      val paths=db.prepareStatement("DELETE FROM managed_resource_paths WHERE region=?")
      try {paths.setString(1,id);paths.executeUpdate()} finally paths.close()
      val region=db.prepareStatement("DELETE FROM managed_resource_regions WHERE id=?")
      try {region.setString(1,id);region.executeUpdate()} finally region.close()
    }
  }
  private[host] def requireNoOrphanResources(draft:String):Unit=synchronized {
    val q=connection.prepareStatement("SELECT id FROM managed_resource_regions WHERE draft=?")
    try {q.setString(1,draft);val r=q.executeQuery()
      while(r.next())require(managedResources.contains(r.getString(1)),"retained worker resource requires confirmed recovery cleanup")
    } finally q.close()
  }
  private[host] def invalidateManagedResources(draft:String):Vector[ManagedResourceRegistration]=synchronized {
    val selected=managedResources.toVector.filter(_._2.draft==draft)
    selected.foreach {case(id,resource)=>managedResources+=id->resource.copy(active=false)}
    selected.foreach {case(id,resource)=>try resource.owner.invalidate() catch {case failure:Throwable=>
      managedResources+=id->managedResources(id).copy(signalFailure=Some(failure))}}
    selected.map {case(id,_)=>new ManagedResourceRegistration(this,id)}
  }
  private[runtime] var afterNativeCommit: () => Unit = () => ()
  private[host] var afterNativeBlobPublish: () => Unit = () => ()
  private def execute(sql: String): Unit = { val s=connection.createStatement(); try s.execute(sql) finally s.close() }
  private val initialized: Unit = try {
  execute("PRAGMA journal_mode=WAL")
  execute("PRAGMA synchronous=FULL")
  execute("PRAGMA secure_delete=ON")
  execute("PRAGMA foreign_keys=ON")
  execute("CREATE TABLE IF NOT EXISTS workspace (singleton INTEGER PRIMARY KEY CHECK(singleton=1), revision INTEGER NOT NULL)")
  execute("INSERT OR IGNORE INTO workspace VALUES(1,0)")
  execute("CREATE TABLE IF NOT EXISTS drafts (id TEXT PRIMARY KEY, revision INTEGER UNIQUE NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)")
  execute("CREATE TABLE IF NOT EXISTS files (draft TEXT NOT NULL REFERENCES drafts(id), name TEXT NOT NULL, hash TEXT NOT NULL, size INTEGER NOT NULL, PRIMARY KEY(draft,name))")
  execute("CREATE INDEX IF NOT EXISTS files_hash ON files(hash)")
  execute("CREATE TABLE IF NOT EXISTS native_identity (singleton INTEGER PRIMARY KEY CHECK(singleton=1), workspace TEXT NOT NULL, next_id TEXT NOT NULL)")
  val newWorkspace=java.util.UUID.randomUUID().toString.replace("-","")
  execute(s"INSERT OR IGNORE INTO native_identity VALUES(1,'$newWorkspace','1')")
  execute("CREATE TABLE IF NOT EXISTS native_journal (sequence INTEGER PRIMARY KEY, id TEXT UNIQUE NOT NULL, revision INTEGER NOT NULL, epoch INTEGER NOT NULL, event BLOB NOT NULL, checkpoint BLOB NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS managed_resource_regions(id TEXT PRIMARY KEY,draft TEXT NOT NULL,head TEXT NOT NULL,state TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS managed_resource_paths(region TEXT NOT NULL REFERENCES managed_resource_regions(id),path TEXT NOT NULL,kind TEXT NOT NULL,size INTEGER NOT NULL,PRIMARY KEY(region,path))")
  execute("CREATE TABLE IF NOT EXISTS native_residents(incarnation TEXT PRIMARY KEY,pid INTEGER NOT NULL,started TEXT NOT NULL,owner_pid INTEGER NOT NULL,owner_started TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_acquired_sources(source TEXT PRIMARY KEY,attempt TEXT NOT NULL UNIQUE,request TEXT NOT NULL,configuration TEXT NOT NULL,packet TEXT NOT NULL,projection TEXT NOT NULL,payload TEXT NOT NULL,size INTEGER NOT NULL,draft1 TEXT NOT NULL,draft2 TEXT NOT NULL,origin_sequence INTEGER NOT NULL,state TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_source_bindings(association TEXT PRIMARY KEY,request TEXT NOT NULL,goal TEXT NOT NULL,slot TEXT NOT NULL,draft TEXT NOT NULL,manifest TEXT NOT NULL,revision TEXT NOT NULL,path TEXT NOT NULL,sha256 TEXT NOT NULL,size INTEGER NOT NULL,origin_sequence INTEGER NOT NULL,state TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_source_pins(association TEXT NOT NULL,hash TEXT NOT NULL,size INTEGER NOT NULL,PRIMARY KEY(association,hash))")
  execute("CREATE TABLE IF NOT EXISTS native_source_cleanup(association TEXT PRIMARY KEY,state TEXT NOT NULL,token TEXT NOT NULL,incarnation TEXT NOT NULL,attempts INTEGER NOT NULL,error TEXT NOT NULL,next_millis INTEGER NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_source_erase_queue(hash TEXT PRIMARY KEY,size INTEGER NOT NULL)")

  execute("CREATE TABLE IF NOT EXISTS native_dispatch(sequence INTEGER NOT NULL REFERENCES native_journal(sequence),kind TEXT NOT NULL,id TEXT NOT NULL,incarnation TEXT NOT NULL,deployment TEXT NOT NULL,command BLOB NOT NULL,status TEXT NOT NULL,PRIMARY KEY(kind,id,incarnation))")
  execute("CREATE TABLE IF NOT EXISTS native_recovery (sequence INTEGER NOT NULL REFERENCES native_journal(sequence), association TEXT NOT NULL, semantic_generation TEXT NOT NULL, slot TEXT NOT NULL, hash TEXT NOT NULL, size INTEGER NOT NULL, PRIMARY KEY(sequence,association,slot))")
  execute("CREATE INDEX IF NOT EXISTS native_recovery_association ON native_recovery(association,sequence)")
  execute("CREATE TABLE IF NOT EXISTS native_gc_state(singleton INTEGER PRIMARY KEY CHECK(singleton=1),pending INTEGER NOT NULL)")
  execute("INSERT OR IGNORE INTO native_gc_state VALUES(1,0)")
  execute("CREATE TABLE IF NOT EXISTS native_erased_associations(association TEXT PRIMARY KEY)")
  execute("CREATE TABLE IF NOT EXISTS native_artifact_erase_queue(hash TEXT PRIMARY KEY)")
  execute("CREATE TABLE IF NOT EXISTS native_artifact_stages(id TEXT PRIMARY KEY,association TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_artifact_members(stage TEXT NOT NULL REFERENCES native_artifact_stages(id),slot TEXT NOT NULL,hash TEXT NOT NULL,size INTEGER NOT NULL,temporary TEXT NOT NULL,PRIMARY KEY(stage,slot))")
  execute("CREATE TABLE IF NOT EXISTS native_artifact_stage_edges(stage TEXT NOT NULL REFERENCES native_artifact_stages(id),dependency TEXT NOT NULL,PRIMARY KEY(stage,dependency))")
  execute("CREATE TABLE IF NOT EXISTS native_access_denials(object_id TEXT PRIMARY KEY,mode TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS native_recovery_edges(sequence INTEGER NOT NULL REFERENCES native_journal(sequence),association TEXT NOT NULL,dependency TEXT NOT NULL,PRIMARY KEY(sequence,association,dependency))")
  execute("CREATE INDEX IF NOT EXISTS native_edges_association ON native_recovery_edges(association,sequence)")
  execute("CREATE INDEX IF NOT EXISTS native_edges_dependency ON native_recovery_edges(dependency,association)")
  execute("CREATE INDEX IF NOT EXISTS native_stage_hash ON native_artifact_members(hash)")
  execute("CREATE TABLE IF NOT EXISTS source_heads (draft TEXT PRIMARY KEY, locator TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)")
  execute("CREATE TABLE IF NOT EXISTS source_history (sequence INTEGER PRIMARY KEY AUTOINCREMENT, draft TEXT NOT NULL, locator TEXT NOT NULL, mode TEXT NOT NULL)")
  execute("CREATE TABLE IF NOT EXISTS lifecycle (sequence INTEGER PRIMARY KEY AUTOINCREMENT, draft TEXT NOT NULL REFERENCES drafts(id), mode TEXT NOT NULL)")
  cleanupNativeArtifactStages()
  } catch {case e: Throwable =>
    try database.close() finally {writerLock.release(); lockChannel.close()}
    throw e
  }
  private def live(): Unit = require(!closed, "workspace store closed")
  def currentRevision: Long = synchronized { live(); val s=connection.createStatement(); try {
    val r=s.executeQuery("SELECT revision FROM workspace WHERE singleton=1"); require(r.next()); r.getLong(1)
  } finally s.close() }
  private def transaction[A](f: => A): A = {
    connection.setAutoCommit(false)
    try {val result=f; connection.commit(); result}
    catch {case e: Throwable => connection.rollback(); throw e}
    finally connection.setAutoCommit(true)
  }
  private[host] def managedRoot: Path = root
  private[host] def managedRead[A](f: java.sql.Connection => A): A = synchronized {live(); f(connection)}
  private[host] def managedWrite[A](f: java.sql.Connection => A): A = synchronized {live(); transaction(f(connection))}
  private def identifier(id: String): Unit = require(id.matches("[A-Za-z0-9_-]{1,128}"), "invalid identity")
  private def checkedName(name: String): Unit = {
    require(name.nonEmpty && name.length<=limits.maxNameBytes &&
      java.nio.charset.StandardCharsets.UTF_8.newEncoder().canEncode(name) &&
      name.getBytes(java.nio.charset.StandardCharsets.UTF_8).length<=limits.maxNameBytes, "name limit or malformed Unicode")
    require(!name.startsWith("/") && !name.contains('\\') && !name.contains('\u0000') &&
      name.split("/",-1).forall(p => p.nonEmpty && p!="." && p!=".."), "unsafe relative name")
  }
  private def readBlob(hash: String, size: Long): Array[Byte] = {
    require(hash.matches("[0-9a-f]{64}") && size>=0 && size<=limits.maxBlobBytes,"stored artifact bound")
    val path=blobs.resolve(hash)
    require(Files.isRegularFile(path,java.nio.file.LinkOption.NOFOLLOW_LINKS) && Files.size(path)==size,"stored artifact shape")
    val input=Files.newInputStream(path,java.nio.file.LinkOption.NOFOLLOW_LINKS)
    val bytes=new Array[Byte](size.toInt)
    var complete=false
    try {
      var offset=0
      while(offset<bytes.length){val n=input.read(bytes,offset,bytes.length-offset);require(n>0,"stored artifact truncated");offset+=n}
      require(input.read()== -1 && digest(bytes)==hash,"stored artifact integrity")
      complete=true;bytes
    } finally {input.close();if(!complete)java.util.Arrays.fill(bytes,0.toByte)}
  }

  private def putBlob(bytes: Array[Byte]): String = {
    require(bytes.length<=limits.maxBlobBytes,"blob limit")
    val hash=digest(bytes); val destination=blobs.resolve(hash)
    if(!Files.exists(destination)) {
      val temporary=Files.createTempFile(blobs,"publish-",".tmp")
      val out=FileChannel.open(temporary,StandardOpenOption.WRITE)
      try {val buffer=java.nio.ByteBuffer.wrap(bytes); while(buffer.hasRemaining) out.write(buffer); out.force(true)}
      finally out.close()
      Files.move(temporary,destination,StandardCopyOption.ATOMIC_MOVE)
      val directory=FileChannel.open(blobs,StandardOpenOption.READ)
      try directory.force(true) finally directory.close()
    }
    readBlob(hash,bytes.length)
    hash
  }
  def commitDraft(expectedRevision: Long, commandId: String, input: Vector[DraftFile]): Either[Conflict,DraftAck] = synchronized {
    live(); identifier(commandId); require(expectedRevision>=0)
    require(input.nonEmpty && input.size<=limits.maxEntries,"entry limit")
    // Preflight every bound BEFORE cloning. Array lengths cannot change under mutation.
    input.foreach(f => {checkedName(f.name); require(f.bytes.length<=limits.maxBlobBytes,"blob limit")})
    require(input.map(_.name).distinct.size==input.size,"duplicate path")
    require(input.foldLeft(0L)((n,f)=>n+f.bytes.length)<=limits.maxBatchBytes,"batch byte limit")
    val files=input.map(f => DraftFile(f.name,f.bytes.clone()))
    val revision=currentRevision
    if(revision!=expectedRevision) return Left(Conflict(revision))
    val refs=files.map(f=>(f.name,putBlob(f.bytes),f.bytes.length))
    transaction {
      val insert=connection.prepareStatement("INSERT INTO drafts(id,revision) VALUES(?,?)")
      try {insert.setString(1,commandId); insert.setLong(2,revision+1); insert.executeUpdate()} finally insert.close()
      val file=connection.prepareStatement("INSERT INTO files VALUES(?,?,?,?)")
      try refs.foreach {case(name,hash,size)=>file.setString(1,commandId); file.setString(2,name); file.setString(3,hash); file.setInt(4,size); file.executeUpdate()}
      finally file.close()
      execute(s"UPDATE workspace SET revision=${revision+1} WHERE singleton=1")
      Right(DraftAck(commandId,revision+1))
    }
  }
  /** Lookup uses a live draft association. A bare hash is never a read capability. */
  def readDraft(id: String): Access = synchronized {
    live(); identifier(id)
    val q=connection.prepareStatement("SELECT revision,revoked FROM drafts WHERE id=?")
    val revision=try {q.setString(1,id); val r=q.executeQuery(); if(!r.next() || r.getInt(2)!=0) return Unavailable; r.getLong(1)} finally q.close()
    val files=connection.prepareStatement("SELECT name,hash,size FROM files WHERE draft=? ORDER BY name")
    try {
      files.setString(1,id); val r=files.executeQuery(); val result=Vector.newBuilder[(String,Array[Byte])]
      var count=0; var total=0L
      while(r.next()) {
        count+=1; require(count<=limits.maxEntries,"stored entry limit")
        val name=r.getString(1); checkedName(name); val hash=r.getString(2); val size=r.getLong(3)
        require(hash.matches("[0-9a-f]{64}") && size>=0 && size<=limits.maxBlobBytes,"stored artifact bound")
        total+=size; require(total<=limits.maxBatchBytes,"stored batch bound")
        val body=readBlob(hash,size)
        result += ((name,body))
      }
      Available(DraftView(id,revision,result.result()))
    } finally files.close()
  }
  /** Retains non-content history; revoked associations remain inaccessible after restart. */
  def revokeDraft(id: String): Boolean = synchronized {
    live(); identifier(id)
    transaction {
      val q=connection.prepareStatement("UPDATE drafts SET revoked=1 WHERE id=? AND revoked=0")
      val changed=try {q.setString(1,id); q.executeUpdate()==1} finally q.close()
      if(changed) {
        val event=connection.prepareStatement("INSERT INTO lifecycle(draft,mode) VALUES(?,'revoke')")
        try {event.setString(1,id); event.executeUpdate()} finally event.close()
        execute("UPDATE workspace SET revision=revision+1 WHERE singleton=1")
      }
      changed
    }
  }
  private[runtime] def nativeWorkspace: String = synchronized {
    live(); val q=connection.createStatement()
    try {val r=q.executeQuery("SELECT workspace FROM native_identity WHERE singleton=1"); require(r.next())
      val id=r.getString(1); require(id.matches("[0-9a-f]{32}"),"invalid durable workspace identity"); id} finally q.close()
  }
  /** Advance+commit before issuance. Unused identities burn on process failure. */
  private[runtime] def reserveNativeIds(count: Int): NativeIdLease = synchronized {
    live(); require(count>0 && count<=65536,"native ID block bound")
    transaction {
      val q=connection.createStatement()
      val first=try {val r=q.executeQuery("SELECT next_id FROM native_identity WHERE singleton=1"); require(r.next())
        val digits=r.getString(1); require(digits.matches("[1-9][0-9]{0,127}"),"native ID counter corrupt"); BigInt(digits)} finally q.close()
      val past=first+count; require(past.toString.length<=128,"native ID space exhausted")
      val update=connection.prepareStatement("UPDATE native_identity SET next_id=? WHERE singleton=1")
      try {update.setString(1,past.toString); update.executeUpdate()} finally update.close()
      new NativeIdLease(nativeWorkspace,first,past)
    }
  }
  private def nativeSequence: Long = {
    val q=connection.createStatement()
    try {val r=q.executeQuery("SELECT COALESCE(MAX(sequence),0) FROM native_journal"); require(r.next()); r.getLong(1)} finally q.close()
  }
  private def referencedBlob(hash:String,exceptStage:String):Boolean={
    val q=connection.prepareStatement("SELECT 1 FROM native_recovery WHERE hash=? UNION ALL SELECT 1 FROM files WHERE hash=? UNION ALL SELECT 1 FROM native_artifact_members WHERE hash=? AND stage<>? LIMIT 1")
    try {q.setString(1,hash);q.setString(2,hash);q.setString(3,hash);q.setString(4,exceptStage);q.executeQuery().next()} finally q.close()
  }
  /** Only exact managed write intents; never a scan of legacy/private roots. */
  private[host] def cleanupNativeArtifactStages():Unit={
    val q=connection.createStatement()
    val stages=try {val r=q.executeQuery("SELECT id FROM native_artifact_stages");val b=Vector.newBuilder[String];while(r.next())b+=r.getString(1);b.result()} finally q.close()
    stages.foreach {stage=>
      require(stage.matches("[0-9a-f-]{36}"),"native artifact stage identity")
      val members=connection.prepareStatement("SELECT hash,temporary FROM native_artifact_members WHERE stage=?")
      val rows=try {members.setString(1,stage);val r=members.executeQuery();val b=Vector.newBuilder[(String,String)];var n=0
        while(r.next()){n+=1;require(n<=6,"native stage member bound");b+=((r.getString(1),r.getString(2)))};b.result()} finally members.close()
      rows.foreach {case(hash,temp)=>
        require(hash.matches("[0-9a-f]{64}") && temp.matches("native-"+stage+"-[a-z_]+\\.tmp"),"native artifact intent path")
        Files.deleteIfExists(blobs.resolve(temp))
        if(!referencedBlob(hash,stage))Files.deleteIfExists(blobs.resolve(hash))
      }
      val directory=FileChannel.open(blobs,StandardOpenOption.READ);try directory.force(true) finally directory.close()
      transaction {
        for(table<-List("native_artifact_members","native_artifact_stage_edges")){
          val delete=connection.prepareStatement("DELETE FROM "+table+" WHERE stage=?")
          try {delete.setString(1,stage);delete.executeUpdate()} finally delete.close()
        }
        val delete=connection.prepareStatement("DELETE FROM native_artifact_stages WHERE id=?")
        try {delete.setString(1,stage);delete.executeUpdate()} finally delete.close()
      }
    }
  }
  private def planNativeArtifacts(material:NativeRecoveryMaterial):(String,Vector[(String,String,Int)])={
    val stage=java.util.UUID.randomUUID().toString
    val refs=material.slots.map {case(slot,bytes)=>(slot,digest(bytes),bytes.length)}
    transaction {
      val begin=connection.prepareStatement("INSERT INTO native_artifact_stages VALUES(?,?)")
      try {begin.setString(1,stage);begin.setString(2,material.association.toString);begin.executeUpdate()} finally begin.close()
      val member=connection.prepareStatement("INSERT INTO native_artifact_members VALUES(?,?,?,?,?)")
      try refs.foreach {case(slot,hash,size)=>member.setString(1,stage);member.setString(2,slot);member.setString(3,hash);member.setInt(4,size)
        member.setString(5,s"native-$stage-$slot.tmp");member.executeUpdate()} finally member.close()
      val edge=connection.prepareStatement("INSERT INTO native_artifact_stage_edges VALUES(?,?)")
      try material.dependencies.foreach {id=>edge.setString(1,stage);edge.setString(2,id.toString);edge.executeUpdate()} finally edge.close()
    }
    (stage,refs)
  }
  private def publishNativeArtifact(stage:String,slot:String,hash:String,bytes:Array[Byte]):Unit={
    require(digest(bytes)==hash && bytes.length<=limits.maxBlobBytes,"native artifact bytes changed")
    val destination=blobs.resolve(hash)
    if(!Files.exists(destination,java.nio.file.LinkOption.NOFOLLOW_LINKS)){
      val temp=blobs.resolve(s"native-$stage-$slot.tmp")
      val out=FileChannel.open(temp,StandardOpenOption.CREATE_NEW,StandardOpenOption.WRITE)
      try {val buffer=java.nio.ByteBuffer.wrap(bytes);while(buffer.hasRemaining)out.write(buffer);out.force(true)} finally out.close()
      Files.move(temp,destination,StandardCopyOption.ATOMIC_MOVE)
      val directory=FileChannel.open(blobs,StandardOpenOption.READ);try directory.force(true) finally directory.close()
    }
    val checked=readBlob(hash,bytes.length);try () finally java.util.Arrays.fill(checked,0.toByte)
    afterNativeBlobPublish()
  }
  private def checkNativeAssociation(material:NativeRecoveryMaterial):Unit={
    val erased=connection.prepareStatement("SELECT 1 FROM native_erased_associations WHERE association=?")
    try {erased.setString(1,material.association.toString);require(!erased.executeQuery().next(),"erased native association cannot be rebound")} finally erased.close()
    val q=connection.prepareStatement("SELECT semantic_generation,slot,hash,size FROM native_recovery WHERE association=? AND sequence=(SELECT MAX(sequence) FROM native_recovery WHERE association=?)")
    val rows=try {q.setString(1,material.association.toString);q.setString(2,material.association.toString);val r=q.executeQuery();val b=Vector.newBuilder[(String,String,String,Long)]
      var count=0;while(r.next()){count+=1;require(count<=6,"existing native association bound");b+=((r.getString(1),r.getString(2),r.getString(3),r.getLong(4)))};b.result()} finally q.close()
    if(rows.nonEmpty){
      val expected=material.slots.map {case(slot,bytes)=>(material.semanticGeneration.toString,slot,digest(bytes),bytes.length.toLong)}.toSet
      require(rows.toSet==expected,"stable native association cannot rebind artifacts")
      val edges=connection.prepareStatement("SELECT DISTINCT dependency FROM native_recovery_edges WHERE association=?")
      val saved=try {edges.setString(1,material.association.toString);val r=edges.executeQuery();val b=Set.newBuilder[String];var count=0
        while(r.next()){count+=1;require(count<=8192,"existing native edge bound");b+=r.getString(1)};b.result()} finally edges.close()
      require(saved==material.dependencies.map(_.toString).toSet,"stable native association cannot rebind dependencies")
    }
  }
  private[runtime] def commitNative(id: String, expected: Long, revision: Long, epoch: Long,
    event: Array[Byte], checkpoint: Array[Byte], recovery: Option[NativeRecoveryMaterial] = None, dispatch:Option[NativeDispatchMaterial]=None,invalidations:Option[NativeInvalidations]=None,source:Option[NativeBuildSourceMaterial]=None,effectSource:Option[NativeEffectSources.Material]=None): Option[NativeRecord] = synchronized {
    live(); identifier(id); require(expected>=0 && expected<Long.MaxValue && revision>=0 && epoch>=0)
    require(event.length<=1024*1024 && checkpoint.length<=1024*1024,"native record limit")
    if(nativeSequence!=expected) return None
    val record=NativeRecord(id,expected+1,revision,epoch,event.clone(),checkpoint.clone())
    recovery.foreach {m=>
      require(m.slots.forall(_._2.length<=limits.maxBlobBytes) && m.slots.foldLeft(0L)((total,p)=>total+p._2.length)<=limits.maxBatchBytes,"workspace native artifact budget")
      validateRecovery(nativeWorkspace,m);checkNativeAssociation(m)
      val denied=connection.prepareStatement("SELECT 1 FROM native_access_denials WHERE object_id=?")
      try m.dependencies.foreach {id=>denied.setString(1,id.toString);require(!denied.executeQuery().next(),"native artifact depends on denied object")} finally denied.close()
    }
    source.foreach {binding=>
      withNativeSourceGuard(binding.guard){
        val material=recovery.getOrElse(throw new IllegalArgumentException("native source lease requires protected recovery"))
        val envelope=recoveryEnvelope(material.slots.toMap.apply("manifest"))
        require(material.association==binding.source.association && envelope("profile")=="native-development/1" &&
          Set("build-request","build-candidate").contains(envelope("role")) &&
          (if(envelope("role")=="build-request")binding.source.association==binding.source.slot else binding.source.association!=binding.source.slot),"native source binding recovery association")
        require(readNativeSource(binding.source.association).forall((prior,state)=>prior==binding.source && state=="live"),"native source ownership cannot rebind")
      }
    }
    effectSource.foreach(value=>nativeEffectSources.precommit(value,recovery.getOrElse(
      throw new IllegalArgumentException("effect source adoption requires protected native recovery"))))
    cleanupNativeArtifactStages()
    val stage=recovery.map(planNativeArtifacts)
    val protectedRefs=recovery.toVector.flatMap {m=>
      val (id,refs)=stage.get
      val slots=m.slots.toMap
      refs.map {case(slot,hash,size)=>publishNativeArtifact(id,slot,hash,slots(slot));(m,slot,hash,size)}
    }
    val committed=transaction {
      val q=connection.prepareStatement("INSERT INTO native_journal VALUES(?,?,?,?,?,?)")
      try {q.setLong(1,record.sequence); q.setString(2,id); q.setLong(3,revision); q.setLong(4,epoch);
        q.setBytes(5,record.event); q.setBytes(6,record.checkpoint); q.executeUpdate()} finally q.close()
      source.foreach {binding=>
        val data=binding.source
        if(readNativeSource(data.association).isEmpty){
          val count=connection.createStatement()
          try {val r=count.executeQuery("SELECT COUNT(*),(SELECT COUNT(*) FROM native_source_pins) FROM native_source_bindings WHERE state='live'");require(r.next() && r.getLong(1)<4096 && r.getLong(2)+binding.pins.size<=262144,"durable native source ownership capacity")} finally count.close()
        }
        val q=connection.prepareStatement("INSERT OR IGNORE INTO native_source_bindings VALUES(?,?,?,?,?,?,?,?,?,?,?,'live')")
        try {Vector(data.association.toString,data.request.toString,data.goal.toString,data.slot.toString,data.draft,data.manifest,data.revision,data.path,data.sha256).zipWithIndex.foreach((v,i)=>q.setString(i+1,v));q.setLong(10,data.size);q.setLong(11,record.sequence);q.executeUpdate()} finally q.close()
        val pin=connection.prepareStatement("INSERT OR IGNORE INTO native_source_pins VALUES(?,?,?)")
        try binding.pins.foreach {(hash,size)=>pin.setString(1,data.association.toString);pin.setString(2,hash);pin.setLong(3,size);pin.executeUpdate()} finally pin.close()
      }
      effectSource.foreach(value=>nativeEffectSources.adopt(connection,value,record.sequence))
      dispatch.foreach {intent=>
        val q=connection.prepareStatement("INSERT INTO native_dispatch VALUES(?,?,?,?,?,?,'unknown')")
        try {q.setLong(1,record.sequence);q.setString(2,intent.kind);q.setString(3,intent.id.toString)
          q.setString(4,intent.incarnation.toString);q.setString(5,intent.deployment);q.setBytes(6,intent.command);q.executeUpdate()} finally q.close()
      }
      invalidations.foreach {change=>change.objects.foreach {id=>
        val q=connection.prepareStatement("INSERT INTO native_access_denials VALUES(?,?) ON CONFLICT(object_id) DO UPDATE SET mode=CASE WHEN excluded.mode='forget' THEN 'forget' ELSE mode END")
        try {q.setString(1,id.toString);q.setString(2,change.mode);q.executeUpdate()} finally q.close()
      }}
      recovery.foreach {material=>material.dependencies.foreach {dependency=>
        val q=connection.prepareStatement("INSERT INTO native_recovery_edges VALUES(?,?,?)")
        try {q.setLong(1,record.sequence);q.setString(2,material.association.toString);q.setString(3,dependency.toString);q.executeUpdate()} finally q.close()
      }}
      protectedRefs.foreach {case(material,slot,hash,size)=>
        val insert=connection.prepareStatement("INSERT INTO native_recovery VALUES(?,?,?,?,?,?)")
        try {insert.setLong(1,record.sequence); insert.setString(2,material.association.toString)
          insert.setString(3,material.semanticGeneration.toString); insert.setString(4,slot)
          insert.setString(5,hash); insert.setInt(6,size); insert.executeUpdate()} finally insert.close()
      }
      execute("UPDATE native_source_bindings SET state='revoked' WHERE state='live' AND EXISTS(SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=native_source_bindings.association AND d.mode='revoke')")
      execute("UPDATE native_source_bindings SET state='retiring' WHERE state IN('live','revoked') AND EXISTS(SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=native_source_bindings.association AND d.mode='forget')")
      execute("UPDATE native_acquired_sources SET state='revoked' WHERE state IN('pending_ack','live') AND EXISTS(SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=native_acquired_sources.source AND d.mode='revoke')")
      execute("UPDATE native_acquired_sources SET state='retiring' WHERE state IN('pending_ack','live','revoked') AND EXISTS(SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=native_acquired_sources.source AND d.mode='forget')")
      queueRetiringNativeSources()
      stage.foreach {case(id,_)=>
        for(table<-List("native_artifact_members","native_artifact_stage_edges")){
          val delete=connection.prepareStatement("DELETE FROM "+table+" WHERE stage=?")
          try {delete.setString(1,id);delete.executeUpdate()} finally delete.close()
        }
        val delete=connection.prepareStatement("DELETE FROM native_artifact_stages WHERE id=?")
        try {delete.setString(1,id);delete.executeUpdate()} finally delete.close()
      }
      Some(record)
    }
    nativeCapabilities.toVector.foreach(_.close())
    afterNativeCommit() // fault seam: committed-but-unacknowledged is indeterminate
    committed
  }
  private[runtime] def latestNative: Option[NativeRecord] = synchronized {
    live()
    val q=connection.prepareStatement("SELECT sequence,id,revision,epoch,length(event),length(checkpoint) FROM native_journal ORDER BY sequence DESC LIMIT 1")
    val metadata=try {val r=q.executeQuery(); if(!r.next()) return None
      require(r.getLong(5)<=1024*1024 && r.getLong(6)<=limits.maxBatchBytes,"native recovery record limit")
      (r.getLong(1),r.getString(2),r.getLong(3),r.getLong(4))} finally q.close()
    val bytes=connection.prepareStatement("SELECT event,checkpoint FROM native_journal WHERE sequence=?")
    try {bytes.setLong(1,metadata._1); val r=bytes.executeQuery(); require(r.next())
      Some(NativeRecord(metadata._2,metadata._1,metadata._3,metadata._4,r.getBytes(1),r.getBytes(2)))} finally bytes.close()
  }
  private[runtime] def nativeDispatch(kind:String,id:BigInt,incarnation:BigInt):Option[NativeDispatchRecord]=synchronized {
    live();require(Set("pure","effect","job").contains(kind) && id>0 && incarnation>=0)
    val q=connection.prepareStatement("SELECT sequence,deployment,length(command),status FROM native_dispatch WHERE kind=? AND id=? AND incarnation=?")
    val row=try {q.setString(1,kind);q.setString(2,id.toString);q.setString(3,incarnation.toString);val r=q.executeQuery()
      if(!r.next())return None;require(r.getLong(3)>0 && r.getLong(3)<=4096,"native dispatch recovery bound")
      (r.getLong(1),r.getString(2),r.getString(4))} finally q.close()
    val bytes=connection.prepareStatement("SELECT command FROM native_dispatch WHERE kind=? AND id=? AND incarnation=?")
    try {bytes.setString(1,kind);bytes.setString(2,id.toString);bytes.setString(3,incarnation.toString);val r=bytes.executeQuery();require(r.next())
      Some(NativeDispatchRecord(row._1,kind,id,incarnation,row._2,r.getBytes(1),row._3))} finally bytes.close()
  }
  private[runtime] def hasForgottenNativeArtifacts:Boolean=synchronized {
    live();val q=connection.createStatement()
    try q.executeQuery("SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE d.mode='forget' UNION ALL SELECT 1 FROM native_artifact_erase_queue UNION ALL SELECT 1 FROM native_gc_state WHERE pending=1 LIMIT 1").next() finally q.close()
  }
  /** Called only by the fixed resident adapter AFTER its real cleanup barrier.
    * This consumes persisted native denials; no caller-selected deletion set. */
  private[runtime] def eraseForgottenNativeArtifacts():Unit=synchronized {
    live();cleanupNativeArtifactStages()
    val q=connection.createStatement()
    val associations=try {val r=q.executeQuery("SELECT DISTINCT e.association FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE d.mode='forget' LIMIT 8193")
      val b=Vector.newBuilder[String];while(r.next())b+=r.getString(1);b.result()} finally q.close()
    require(associations.size<=8192,"native erasure association bound")
    transaction {execute("UPDATE native_gc_state SET pending=1 WHERE singleton=1");associations.foreach {association=>
      require(association.matches("[1-9][0-9]{0,127}"),"native erasure identity")
      val queue=connection.prepareStatement("INSERT OR IGNORE INTO native_artifact_erase_queue SELECT DISTINCT hash FROM native_recovery WHERE association=?")
      try {queue.setString(1,association);queue.executeUpdate()} finally queue.close()
      val tombstone=connection.prepareStatement("INSERT OR IGNORE INTO native_erased_associations VALUES(?)")
      try {tombstone.setString(1,association);tombstone.executeUpdate()} finally tombstone.close()
      for(table<-List("native_recovery","native_recovery_edges")){
        val remove=connection.prepareStatement("DELETE FROM "+table+" WHERE association=?")
        try {remove.setString(1,association);remove.executeUpdate()} finally remove.close()
      }
    }}
    val hashes=connection.createStatement()
    val pending=try {val r=hashes.executeQuery("SELECT hash FROM native_artifact_erase_queue LIMIT 49153");val b=Vector.newBuilder[String]
      while(r.next())b+=r.getString(1);b.result()} finally hashes.close()
    require(pending.size<=49152,"native erasure blob bound")
    pending.foreach {hash=>require(hash.matches("[0-9a-f]{64}"));if(!referencedBlob(hash,""))Files.deleteIfExists(blobs.resolve(hash))}
    val directory=FileChannel.open(blobs,StandardOpenOption.READ);try directory.force(true) finally directory.close()
    transaction {pending.foreach {hash=>val remove=connection.prepareStatement("DELETE FROM native_artifact_erase_queue WHERE hash=?")
      try {remove.setString(1,hash);remove.executeUpdate()} finally remove.close()}}
    nativeCapabilities.toVector.foreach(_.close())
    val checkpoint=connection.createStatement()
    try {val r=checkpoint.executeQuery("PRAGMA wal_checkpoint(TRUNCATE)");require(r.next() && r.getInt(1)==0,"native erasure checkpoint busy")} finally checkpoint.close()
    transaction {execute("UPDATE native_gc_state SET pending=0 WHERE singleton=1")}
  }
  /** Latest exact commit only. Native lifecycle/semantic checks still precede restoration.
    * A historical hash or association ID alone cannot obtain a capability. */
  private[runtime] def committedNativeRecovery(record: NativeRecord, association: BigInt): Option[CommittedNativeRecovery] = synchronized {
    live(); require(association>0 && association.toString.length<=128)
    val denied=connection.prepareStatement("SELECT 1 FROM native_recovery_edges e JOIN native_access_denials d ON d.object_id=e.dependency WHERE e.association=? LIMIT 1")
    try {denied.setString(1,association.toString);if(denied.executeQuery().next())return None} finally denied.close()
    val current=latestNative
    if(!current.exists(r=>r.sequence==record.sequence && r.id==record.id && r.revision==record.revision && r.epoch==record.epoch &&
      java.util.Arrays.equals(r.checkpoint,record.checkpoint) && java.util.Arrays.equals(r.event,record.event))) return None
    val originQuery=connection.prepareStatement("SELECT MAX(sequence) FROM native_recovery WHERE sequence<=? AND association=?")
    val origin=try {originQuery.setLong(1,record.sequence);originQuery.setString(2,association.toString)
      val r=originQuery.executeQuery();require(r.next());val value=r.getLong(1);if(r.wasNull())return None;value} finally originQuery.close()
    val q=connection.prepareStatement("SELECT semantic_generation,slot,hash,size FROM native_recovery WHERE sequence=? AND association=?")
    val rows=try {q.setLong(1,origin); q.setString(2,association.toString)
      val r=q.executeQuery(); val result=Vector.newBuilder[(String,String,String,Long)]
      var count=0; while(r.next()) {count+=1; require(count<=6,"native recovery row limit")
        result+=((r.getString(1),r.getString(2),r.getString(3),r.getLong(4)))}; result.result()
    } finally q.close()
    if(rows.isEmpty) None else {
      require(rows.map(_._1).distinct.size==1 && rows.head._1.matches("[1-9][0-9]{0,127}"),"native recovery generation")
      // Materialization bounds are checked for every row before the first read.
      rows.foreach {case(_,slot,_,size)=>require(size>=0 && size <= (if(slot=="manifest")8192L else if(slot=="context_closure")16L*1024*1024 else if(slot=="reconstruction")100000L else 1024L*1024),"native recovery row bound")}
      require(rows.map(_._4).sum<=32L*1024*1024,"native recovery total bound")
      val edges=connection.prepareStatement("SELECT dependency FROM native_recovery_edges WHERE sequence=? AND association=?")
      val dependencies=try {edges.setLong(1,origin);edges.setString(2,association.toString);val r=edges.executeQuery();val b=Vector.newBuilder[BigInt]
        var count=0;while(r.next()){count+=1;require(count<=8192,"native dependency edge bound");val text=r.getString(1)
          require(text.matches("[1-9][0-9]{0,127}"),"native dependency identity");b+=BigInt(text)};b.result()} finally edges.close()
      require(nativeCapabilities.size<8,"native recovery capability budget")
      val buffers=scala.collection.mutable.ArrayBuffer.empty[Array[Byte]]
      var material:Option[NativeRecoveryMaterial]=None
      var transferred=false
      try {
        val slots=rows.map {case(_,slot,hash,size)=>val bytes=readBlob(hash,size);buffers+=bytes;(slot,bytes)}
        val owned=new NativeRecoveryMaterial(association,BigInt(rows.head._1),slots,dependencies);material=Some(owned)
        validateRecovery(nativeWorkspace,owned)
        val capability=new CommittedNativeRecovery(nativeWorkspace,record.sequence,origin,record.epoch,owned,this)
        nativeCapabilities+=capability;transferred=true;Some(capability)
      } finally {
        buffers.foreach(a=>java.util.Arrays.fill(a,0.toByte))
        if(!transferred)material.foreach(_.release())
      }
    }
  }
  /** Inert package-source journal. Locators are private storage identities, never native authority. */
  def head(draft: String): Option[String] = synchronized {
    live(); identifier(draft)
    val q=connection.prepareStatement("SELECT locator FROM source_heads WHERE draft=? AND revoked=0")
    try {q.setString(1,draft); val r=q.executeQuery(); if(r.next()) Some(r.getString(1)) else None} finally q.close()
  }
  /** Resolve and materialize under the lifecycle lock; a cached locator never authorizes a read. */
  def withSourceHead[A](draft: String)(materialize: String => A): Option[A] = synchronized {
    head(draft).map(materialize)
  }
  def compareAndAppend(draft: String, expected: Option[String], next: String): Boolean = synchronized {
    live(); identifier(draft); require(next.matches("[0-9a-f]{64}"),"invalid source locator")
    expected.foreach(e=>require(e.matches("[0-9a-f]{64}"),"invalid expected locator"))
    val q=connection.prepareStatement("SELECT locator,revoked FROM source_heads WHERE draft=?")
    val current=try {q.setString(1,draft); val r=q.executeQuery();
      if(r.next()) Some((r.getString(1),r.getBoolean(2))) else None} finally q.close()
    if(current.exists(_._2) || current.map(_._1)!=expected) return false
    transaction {
      val update=connection.prepareStatement("INSERT INTO source_heads VALUES(?,?,0) ON CONFLICT(draft) DO UPDATE SET locator=excluded.locator")
      try {update.setString(1,draft); update.setString(2,next); update.executeUpdate()} finally update.close()
      val record=connection.prepareStatement("INSERT INTO source_history(draft,locator,mode) VALUES(?,?,'append')")
      try {record.setString(1,draft); record.setString(2,next); record.executeUpdate()} finally record.close()
      execute("UPDATE workspace SET revision=revision+1 WHERE singleton=1")
      true
    }
  }
  def revokeSource(draft: String): Boolean = synchronized {
    live(); identifier(draft)
    transaction {
      val q=connection.prepareStatement("UPDATE source_heads SET revoked=1 WHERE draft=? AND revoked=0")
      val changed=try {q.setString(1,draft); q.executeUpdate()==1} finally q.close()
      if(changed) {
        val record=connection.prepareStatement("INSERT INTO source_history(draft,locator,mode) SELECT draft,locator,'revoke' FROM source_heads WHERE draft=?")
        try {record.setString(1,draft); record.executeUpdate()} finally record.close()
        execute("UPDATE workspace SET revision=revision+1 WHERE singleton=1")
      }
      changed
    }
  }
  def close(): Unit = synchronized {
    if(!closed) {require(!authorityOwner,"close authority coordinator before workspace store"); require(managedResources.isEmpty,"release managed source resources before workspace store");
      val residents=connection.createStatement();try {val r=residents.executeQuery("SELECT COUNT(*) FROM native_residents");require(r.next() && r.getInt(1)==0,"stop native resident before workspace store")} finally residents.close()
      effectSourceIndex.foreach(_.requireClosed());require(nativeSourceCapabilities.isEmpty,"close native source lease views before workspace store");nativeCapabilities.toVector.foreach(_.close()); closed=true; try database.close() finally {writerLock.release(); lockChannel.close()}}
  }
}


import java.nio.ByteBuffer
import java.sql.Connection
import WorkspaceStore.{NativeSourceGuard,NativeRecoveryMaterial,NativeRecord}

private[runtime] object NativeEffectSources {
  /** Metadata from the actual protected observation gate. The projection pin
    * binds its full cost, target, capability, status and source provenance. */
  final case class Identity(source:BigInt,attempt:BigInt,request:BigInt,configuration:BigInt,
      packet:BigInt,projection:String,payload:String,size:Int) {
    require(Vector(source,attempt,request,configuration,packet).forall(n=>n>0 && n.toString.length<=128))
    require(projection.matches("[0-9a-f]{64}") && payload.matches("[0-9a-f]{64}") && size>0 && size<=65536)
    val protocol="local-mcp/1"
    val representation="decoded-json/1"
  }
  final class OwnerConfirmation private[NativeEffectSources](private[host] val issuer:OwnerIssuer,
      private[host] val identity:Identity,private[host] val sequence:Long,
      private[host] val semantic:BigInt,private[host] val ownerIncarnation:BigInt,
      private[host] val stateVersion:BigInt,private[host] val status:String) {
    private[host] var consumed=false
  }
  /** The real bridge retains this lexical issuer privately. Parsing a reply or
    * copying Identity fields does not provide this capability. */
  final class OwnerIssuer private[host](private[host] val owner:NativeEffectSources,
      private[host] val resident:AnyRef) {
    private[host] var live=true
    private[runtime] def confirm(actualResident:AnyRef,identity:Identity,sequence:Long,
        semantic:BigInt,incarnation:BigInt,version:BigInt,status:String):OwnerConfirmation=
      owner.confirm(this,actualResident,identity,sequence,semantic,incarnation,version,status)
    private[runtime] def retire():Unit=owner.retire(this)
  }
  final class Stage private[host](private[host] val owner:NativeEffectSources,
      private[host] val guards:Vector[NativeSourceGuard],private[host] val bytes:Array[Byte])
      extends AutoCloseable with WorkspaceStore.ManagedResourceOwner {
    val hash:String=WorkspaceStore.digest(bytes)
    val size:Int=bytes.length
    private[host] var live=true
    private[host] var registrations=Vector.empty[WorkspaceStore.ManagedResourceRegistration]
    private[host] var releasing=false
    private[host] var cleanupAttempts=0
    private[host] var cleanupAfter=0L
    private[host] var cleanupError=""
    val id:String=java.util.UUID.randomUUID().toString
    def invalidate():Unit=owner.invalidate(this)
    def stopAndRelease():Unit=close()
    def close():Unit=owner.release(this)
  }
  final class Material private[host](private[host] val stage:Stage,val identity:Identity,
      private[host] val drafts:Vector[String]) extends AutoCloseable {
    def close():Unit=stage.close()
  }
  final class Lease private[host](private[host] val owner:NativeEffectSources,
      private[host] val confirmation:OwnerConfirmation) extends AutoCloseable {
    val identity:Identity=confirmation.identity
    val status:String=confirmation.status
    private[host] var live=true
    /** Only canonical decoded-response bytes, never an executor or a new input. */
    def inspect[A](consume:ByteBuffer=>A):A=owner.inspect(this)(consume)
    def close():Unit=owner.release(this)
  }
}

/** One small ownership index over the existing native recovery blobs. There is
  * no response draft, second payload store, status reducer or replay scheduler. */
private[runtime] final class NativeEffectSources(store:WorkspaceStore) {
  import NativeEffectSources.*
  private var currentIssuer:Option[OwnerIssuer]=None
  private[runtime] def newOwnerIssuer(actualResident:AnyRef):OwnerIssuer=store.managedRead {_=>
    require(actualResident!=null,"native source resident identity")
    currentIssuer.foreach(_.live=false)
    val value=new OwnerIssuer(this,actualResident);currentIssuer=Some(value);value
  }
  private[host] def retire(issuer:OwnerIssuer):Unit=store.managedRead {_=>
    require(issuer.owner eq this,"foreign source confirmation issuer");issuer.live=false
  }
  private[host] def confirm(issuer:OwnerIssuer,actualResident:AnyRef,identity:Identity,
      sequence:Long,semantic:BigInt,incarnation:BigInt,version:BigInt,status:String):OwnerConfirmation=store.managedRead {_=>
    require(currentIssuer.contains(issuer) && issuer.live && (issuer.resident eq actualResident),"native source resident changed")
    require(sequence>0 && semantic>0 && incarnation>0 && version>=0 &&
      Vector(semantic,incarnation,version).forall(_.toString.length<=128) && Set("confirmed","failed").contains(status),"native source owner reply bounds")
    new OwnerConfirmation(issuer,identity,sequence,semantic,incarnation,version,status)
  }
  private def confirmationLive(value:OwnerConfirmation):Boolean=
    (value.issuer.owner eq this) && currentIssuer.contains(value.issuer) && value.issuer.live
  private val pending=scala.collection.mutable.Set.empty[Stage]
  private val opened=scala.collection.mutable.Set.empty[Lease]
  private def execute(c:Connection,sql:String):Unit={val q=c.createStatement();try q.execute(sql) finally q.close()}


  /** The parent supplies guards from the SAME actual staged MCP owner. The
    * bounded clone remains private and is never a ManagedSources draft. */
  def stage(guards:Vector[NativeSourceGuard],bytes:ByteBuffer):Stage={
    var created:Option[Stage]=None
    try store.managedRead {_=>
      require(guards.size==2 && bytes.remaining()>0 && bytes.remaining()<=65536,"effect source stage bound")
      require(pending.size<2,"effect source stage capacity")
      guards.foreach(g=>store.withNativeSourceGuard(g)(()))
      val copy=new Array[Byte](bytes.remaining());bytes.duplicate().get(copy)
      val value=new Stage(this,guards,copy);pending+=value;created=Some(value)
      guards.map(store.nativeGuardCapture).distinct.foreach {(draft,head)=>
        value.registrations=value.registrations:+store.registerCapturedResource(draft,head,value)
      }
      value
    } catch {case problem:Throwable=>created.foreach(_.close());throw problem}
  }
  private[host] def invalidate(stage:Stage):Unit=store.managedRead {_=>
    require(stage.owner eq this,"foreign effect response stage")
    stage.live=false;java.util.Arrays.fill(stage.bytes,0.toByte)
  }
  private[host] def release(stage:Stage):Unit={
    val selected=store.managedRead {_=>
      invalidate(stage)
      if(stage.releasing)None else {stage.releasing=true;Some(stage.registrations)}
    }
    selected.foreach {registrations=>
      // Resource teardown uses its join monitor. Never acquire that monitor
      // under the source/store monitor. Reentrant stop callbacks do no work.
      var completed=0
      try registrations.foreach {registration=>registration.release();completed+=1}
      catch {case problem:Throwable=>
        store.managedRead {_=>
          stage.cleanupAttempts=math.min(8,stage.cleanupAttempts+1)
          stage.cleanupAfter=System.nanoTime()+math.min(30000L,250L*(1L<<(stage.cleanupAttempts-1)))*1000000L
          stage.cleanupError=problem.getClass.getSimpleName.take(128)
        }
        throw problem
      }
      finally store.managedRead {_=>
        stage.registrations=registrations.drop(completed);stage.releasing=false
        if(stage.registrations.isEmpty)pending-=stage
      }
    }
  }
  /** A failed teardown remains owned; the existing parent maintenance pump may
    * retry one such stage, without evicting its resource registrations. */
  def retryCleanup():Unit={
    val selected=store.managedRead(_=>pending.find(stage=> !stage.live && !stage.releasing &&
      stage.cleanupAttempts<8 && System.nanoTime()>=stage.cleanupAfter))
    selected.foreach {stage=>try stage.close() catch {case scala.util.control.NonFatal(_)=>()}}
  }
  def cleanupFailures:Vector[(String,Int,String)]=store.managedRead {_=>
    pending.toVector.filter(_.cleanupAttempts>0).map(stage=>(stage.id,stage.cleanupAttempts,stage.cleanupError))
  }
  def retryExhausted():Unit=store.managedRead {_=>pending.filterNot(_.live).foreach {stage=>
    stage.cleanupAttempts=0;stage.cleanupAfter=0L;stage.cleanupError=""
  }}
  private def check(stage:Stage,identity:Identity,material:NativeRecoveryMaterial):Unit={
    require((stage.owner eq this) && stage.live && pending.contains(stage),"effect response stage released")
    stage.guards.foreach(g=>store.withNativeSourceGuard(g)(()))
    require(identity.source==material.association && identity.payload==stage.hash && identity.size==stage.size,
      "effect response stage association mismatch")
    val slots=material.slots.toMap
    require(WorkspaceStore.recoveryCategory(slots("manifest"))=="acquired-source" &&
      WorkspaceStore.digest(slots("projection"))==identity.projection &&
      WorkspaceStore.digest(slots("reconstruction"))==identity.payload &&
      java.util.Arrays.equals(slots("reconstruction"),stage.bytes),"effect response protected representation mismatch")
    require(Vector(identity.source,identity.request,identity.configuration,identity.packet)
      .forall(material.dependencies.contains),"effect response protected source closure mismatch")
  }
  def prepare(stage:Stage,identity:Identity,material:NativeRecoveryMaterial):Material=store.managedRead {_=>
    check(stage,identity,material)
    val drafts=stage.guards.map(store.nativeGuardDraft).distinct
    new Material(stage,identity,drafts)
  }
  private[host] def precommit(value:Material,material:NativeRecoveryMaterial):Unit={
    require(value.stage.owner eq this,"foreign effect response material")
    check(value.stage,value.identity,material)
  }
  /** Called only inside commitNative's journal transaction. Blob publication is
    * already handled by native_recovery; this inserts no second payload copy. */
  private[host] def adopt(c:Connection,value:Material,sequence:Long):Unit={
    require(!c.getAutoCommit,"effect source adoption requires native transaction")
    val count=c.createStatement()
    try {val r=count.executeQuery("SELECT COUNT(*) FROM native_acquired_sources");require(r.next() && r.getLong(1)<4096,"effect source association capacity")} finally count.close()
    val q=c.prepareStatement("INSERT INTO native_acquired_sources VALUES(?,?,?,?,?,?,?,?,?,?,?,'pending_ack')")
    val x=value.identity
    try {Vector(x.source.toString,x.attempt.toString,x.request.toString,x.configuration.toString,x.packet.toString,x.projection,x.payload)
      .zipWithIndex.foreach((s,i)=>q.setString(i+1,s));q.setInt(8,x.size)
      q.setString(9,value.drafts.head);q.setString(10,value.drafts.last);q.setLong(11,sequence);q.executeUpdate()}
    finally q.close()
  }
  private def row(c:Connection,source:BigInt):Option[(Identity,Vector[String],String)]={
    val q=c.prepareStatement("SELECT attempt,request,configuration,packet,projection,payload,size,draft1,draft2,state FROM native_acquired_sources WHERE source=?")
    try {q.setString(1,source.toString);val r=q.executeQuery();if(!r.next())None else Some((
      Identity(source,BigInt(r.getString(1)),BigInt(r.getString(2)),BigInt(r.getString(3)),BigInt(r.getString(4)),r.getString(5),r.getString(6),r.getInt(7)),
      Vector(r.getString(8),r.getString(9)).distinct,r.getString(10)))} finally q.close()
  }
  private[host] def acknowledged(value:Material):Unit=store.managedWrite {c=>
    require(row(c,value.identity.source).exists(r=>r._1==value.identity && r._3=="pending_ack"),"effect source acknowledgement association")
    val q=c.prepareStatement("UPDATE native_acquired_sources SET state='live' WHERE source=? AND state='pending_ack'")
    try {q.setString(1,value.identity.source.toString);q.executeUpdate()} finally q.close()
  }
  /** Call only after the fixed native query has confirmed this SAME current
    * reconstructed source owner and complete identity; saved bytes cannot do so. */
  def openConfirmed(record:NativeRecord,confirmation:OwnerConfirmation):Option[Lease]=store.managedWrite {c=>
    require(confirmationLive(confirmation) && !confirmation.consumed,"native source confirmation stale or already consumed")
    confirmation.consumed=true
    require(confirmation.sequence==record.sequence && store.latestNative.exists(_.sequence==record.sequence),"native source confirmation checkpoint changed")
    val identity=confirmation.identity
    require(opened.size<64,"effect source lease capacity")
    row(c,identity.source).filter(r=>r._1==identity && Set("live","pending_ack").contains(r._3) &&
      r._2.forall(store.sourcePermitted) && store.sourceAssociationAllowed(identity.source)).flatMap {_=>
      store.committedNativeRecovery(record,identity.source).flatMap {capability=>
        try capability.withMaterial {material=>
          val slots=material.slots.toMap
          require(material.semanticGeneration==confirmation.semantic &&
            WorkspaceStore.recoveryCategory(slots("manifest"))=="acquired-source" &&
            WorkspaceStore.digest(slots("projection"))==identity.projection &&
            slots("reconstruction").length==identity.size && WorkspaceStore.digest(slots("reconstruction"))==identity.payload,
            "effect source retained protected identity")
          // A crash after commit/before ack is reconciled ONLY by the actual
          // native owner confirmation above, never by journal presence alone.
          if(row(c,identity.source).exists(_._3=="pending_ack")){
            val q=c.prepareStatement("UPDATE native_acquired_sources SET state='live' WHERE source=? AND state='pending_ack'")
            try {q.setString(1,identity.source.toString);q.executeUpdate()} finally q.close()
          }
          val lease=new Lease(this,confirmation);opened+=lease;Some(lease)
        } finally capability.close()
      }
    }
  }
  private[host] def inspect[A](lease:Lease)(consume:ByteBuffer=>A):A=store.managedRead {c=>
    require((lease.owner eq this) && lease.live && opened.contains(lease) && confirmationLive(lease.confirmation),"effect source lease released or resident changed")
    require(row(c,lease.identity.source).exists(r=>r._1==lease.identity && r._3=="live" &&
      r._2.forall(store.sourcePermitted)) && store.sourceAssociationAllowed(lease.identity.source),"effect source access denied")
    val record=store.latestNative.getOrElse(throw new IllegalStateException("effect source journal unavailable"))
    val cap=store.committedNativeRecovery(record,lease.identity.source).getOrElse(throw new IllegalStateException("effect source payload unavailable"))
    try cap.withMaterial {material=>
      val slots=material.slots.toMap;val bytes=slots("reconstruction")
      require(WorkspaceStore.recoveryCategory(slots("manifest"))=="acquired-source" &&
        WorkspaceStore.digest(slots("projection"))==lease.identity.projection && bytes.length==lease.identity.size &&
        WorkspaceStore.digest(bytes)==lease.identity.payload,"effect source borrowed representation mismatch")
      consume(ByteBuffer.wrap(bytes).asReadOnlyBuffer())
    } finally cap.close()
  }
  private[host] def release(lease:Lease):Unit=store.managedRead {_=>
    require(lease.owner eq this,"foreign effect source lease");lease.live=false;opened-=lease
  }
  private[host] def requireClosed():Unit={
    require(pending.isEmpty && opened.isEmpty,"close effect source stages and leases before store")
    currentIssuer.foreach(_.live=false)
  }
}
