package veri7vn.runtime.service

import isabelle.Bytes
import scala.language.unsafeNulls
import java.util.concurrent.atomic.AtomicBoolean

/** Finite resident client. Native gates mint every workflow event; the single pump
  * commits them through the coordinator before native continuation or handoff. */
final class ResidentAuthorityService private[service](supervisor:ResidentSupervisor,
  coordinator:AuthorityCoordinator,buildIngress:Option[NativeBuildIngress]=None,
  managedSources:Option[veri7vn.runtime.host.ManagedSources]=None,
  buildHistory:Option[veri7vn.runtime.service.build.BuildHistory]=None) extends AutoCloseable {
  lazy val search=new veri7vn.runtime.service.search.SearchIngress(supervisor,this)
  coordinator.requireReady()
  private val stopped=new AtomicBoolean(false)
  @volatile private var failure:Option[Throwable]=None
  private val receipts=scala.collection.mutable.Map.empty[String,Option[AuthorityCoordinator.Outcome]]
  private val pump=new Thread(new Runnable {def run():Unit={
    try while(!stopped.get()) {
      supervisor.awaitAuthorizedToken().foreach {token=>
      val outcome=coordinator.submit(token)
      receipts.synchronized {
        if(receipts.contains(token.nativeId))receipts(token.nativeId)=Some(outcome)
        receipts.notifyAll()
      }
      outcome match {
        case _:AuthorityCoordinator.Committed=>()
        case AuthorityCoordinator.Rejected("native_gate_expired")=>()
        case other=>throw new IllegalStateException("native workflow could not commit: "+other)
      }
      }
      coordinator.maintenance()
    } catch {case problem:Throwable=>
      if(!stopped.get()) {failure=Some(problem);stopped.set(true);supervisor.close()}
    }
  }},"veri7vn-native-event-coordinator")
  pump.setDaemon(true)
  pump.start()
  private def available():Unit={
    require(!stopped.get(),"resident service stopped")
    failure.foreach(problem=>throw new IllegalStateException("resident workflow unavailable",problem))
  }
  final case class RoutingInspection(status:String,alternatives:List[Int])
  def inspectRouting(original:Array[Byte]):RoutingInspection={
    available();require(original.length<=256,"routing inspection byte bound")
    val owned=original.clone()
    val reply=try supervisor.exchange("inspect_routing","math/1",List(Bytes(owned)))
      finally java.util.Arrays.fill(owned,0.toByte)
    require(reply.tag=="routing" && Set("readings","literal","budget","unrecognized","structure_blocked").contains(reply.payload),"native routing inspection shape")
    val alternatives=if(reply.payload=="readings"){
      require(reply.artifacts.size==1 && reply.artifacts.head.size<=1024,"native routing alternatives bound")
      val text=reply.artifacts.head.text
      require(text.matches("[0-9]{1,3}(,[0-9]{1,3})*"),"native routing alternatives encoding")
      val values=text.split(",",-1).toList.map(_.toInt)
      require(values.size<=256 && values.distinct==values && values.forall(n=>n>=0 && n<=255),"native routing alternatives")
      values
    } else {require(reply.artifacts.isEmpty,"unexpected native routing artifact");Nil}
    RoutingInspection(reply.payload,alternatives)
  }
  def requestInspection(request:BigInt):veri7vn.diagnostics.RequestInspection.Inspection={
    available();require(request>0 && request.toString.length<=128)
    val reply=supervisor.exchange("inspect_request",request.toString)
    require(reply.tag=="request_inspection" && reply.payload==request.toString &&
      reply.artifacts.size==1 && reply.artifacts.head.size<=8192,"native request inspection shape")
    veri7vn.diagnostics.RequestInspection.parse(reply.artifacts.head.text,request)
  }
  def proposeMathematics(original:Array[Byte],selection:Option[Int]=None):BigInt={
    available()
    require(original.length<=256 && selection.forall(n=>n>=0 && n<=255),"mathematics proposal bound")
    val owned=original.clone()
    val reply=try supervisor.exchange("propose_math",selection.map(_.toString).getOrElse(""),List(Bytes(owned)))
      finally java.util.Arrays.fill(owned,0.toByte)
    require(reply.tag=="proposed" && reply.payload.matches("[1-9][0-9]{0,127}") && reply.artifacts.isEmpty,
      "native request proposal refused: "+reply.tag+":"+reply.payload)
    BigInt(reply.payload)
  }
  final case class Result(status:String,html:Option[String])
  def mathematicsResult(request:BigInt):Result={
    available();require(request>0 && request.toString.length<=128)
    val reply=supervisor.exchange("poll_result",request.toString)
    require(reply.tag=="result" && reply.artifacts.size<=1,
      s"native result shape request=$request tag=${reply.tag} payload=${reply.payload.take(256)} artifacts=${reply.artifacts.size}")
    require(reply.artifacts.isEmpty || reply.payload=="accepted_exact","unlicensed result payload")
    Result(reply.payload,reply.artifacts.headOption.map(_.text))
  }
  private val managedBuildCaptures=new java.util.concurrent.Semaphore(2)
  final class BuildRequest private[ResidentAuthorityService](val request:BigInt,val goal:BigInt,val slot:BigInt,
    private[service] val input:Option[NativeBuildIngress.PreparedInput],
    private[service] val historical:Option[veri7vn.runtime.service.build.BuildHistory.HistoricalBuild]=None) extends AutoCloseable {
    def original:veri7vn.packages.native_build.NativeBuildInputs.CapturedSource=input.map(_.original).getOrElse {
      val source=historical.get.source
      veri7vn.packages.native_build.NativeBuildInputs.CapturedSource(source.draft,source.revision,source.manifest,source.path,
        veri7vn.packages.native_build.NativeBuildInputs.Pin(source.sha256,source.size))
    }
    def close():Unit=historical.foreach(_.close())
  }
  /** Fixed host storage profile, distinct from native execution permission,
    * accounting and one-use attempt authority. The UI supplies no resource grant. */
  def proposeManagedBuild(draft:String,expectedManifest:String,theoryPath:String,
    parents:Vector[BigInt]=Vector.empty):BuildRequest={
    available()
    val sources=managedSources.getOrElse(throw new IllegalStateException("managed build source service unavailable"))
    val ingress=buildIngress.getOrElse(throw new IllegalStateException("native build ingress unavailable"))
    require(managedBuildCaptures.tryAcquire(),"managed build capture capacity")
    var captured:Option[veri7vn.packages.native_build.NativeBuildInputs.Owned]=None
    try {
      val limits=veri7vn.packages.intake.Intake.Limits(maxArchiveBytes=8*1024*1024,maxFileBytes=1000000,
        maxTotalBytes=8L*1024*1024,maxEntries=128,maxPathBytes=512,maxDepth=24)
      val budget=veri7vn.runtime.effects.ResourceBudget(BigInt(0),256L*1024*1024,512,4,256,16L*1024*1024,512,24,1)
      val owned=veri7vn.packages.native_build.NativeBuildInputs.materialize(sources,draft,expectedManifest,budget,limits)
        .getOrElse(throw new IllegalStateException("managed build draft unavailable"))
      captured=Some(owned)
      owned.exportIntent.inspect {intent=>
        require(intent.descriptor.dependencies.isEmpty || parents.nonEmpty,"declared package dependencies require actual admitted parents")
      }
      proposeBuild(prepareBuild(owned,theoryPath,parents))
    } catch {case problem:Throwable=>
      // An indeterminate transfer stays owned by ingress until exact retirement;
      // never close its guard behind a late native finish or acknowledged owner.
      captured.filterNot(ingress.ownsSource).foreach {owned=>try owned.close() catch {case cleanup:Throwable=>problem.addSuppressed(cleanup)}}
      throw problem
    } finally managedBuildCaptures.release()
  }
  /** A fresh historical inspection handle, never a recovered execution permit. */
  def openBuild(request:BigInt):Option[BuildRequest]={
    available();coordinator.requireReady()
    buildIngress.flatMap(_.liveRequest(request)) match {
      case Some((goal,slot,input))=>Some(new BuildRequest(request,goal,slot,Some(input)))
      case None=>buildHistory.getOrElse(throw new IllegalStateException("historical Build service unavailable")).open(request).map {history=>
        val source=history.source
        new BuildRequest(source.request,source.goal,source.slot,None,Some(history))
      }
    }
  }
  def prepareBuild(input:veri7vn.packages.native_build.NativeBuildInputs.Owned,theoryPath:String,
    parents:Vector[BigInt]=Vector.empty):NativeBuildIngress.PreparedInput={
    available();buildIngress.getOrElse(throw new IllegalStateException("native build ingress unavailable")).prepare(input,theoryPath,parents)
  }
  /** Proposal is queued; it is not an execution, charge, or artifact receipt. */
  def proposeBuild(input:NativeBuildIngress.PreparedInput):BuildRequest={
    available()
    val ingress=buildIngress.getOrElse(throw new IllegalStateException("native build ingress unavailable"))
    require(ingress.preparedInput(input.nativeHandle) eq input,"native build input association mismatch")
    require(input.proposalClaimed.compareAndSet(false,true),"native build input already proposed")
    // An indeterminate proposal is not retried against the same one-use input.
    val reply=supervisor.exchange("propose_build",input.nativeHandle.toString)
    val fields=reply.payload.split(",",-1)
    require(reply.tag=="build_proposed" && reply.artifacts.isEmpty && fields.length==3 &&
      fields.forall(_.matches("[1-9][0-9]{0,127}")),"native build proposal refused")
    val request=BigInt(fields(0));val goal=BigInt(fields(1));val slot=BigInt(fields(2))
    ingress.bindRequest(input,request,goal,slot)
    new BuildRequest(request,goal,slot,Some(input))
  }
  enum BuildState { case Queued,Running,PendingPublication,ArtifactReady,Failed,Cancelled,Historical }
  final class BuildDiagnostic private[ResidentAuthorityService](private[service] val request:BuildRequest,
    val failure:veri7vn.diagnostics.BuildFailure.Failure)
  final class BuildResult private[ResidentAuthorityService](val state:BuildState,val candidate:Option[BigInt],
    val diagnostic:Option[BuildDiagnostic],val sourceAvailable:Boolean)
  def buildResult(request:BuildRequest):BuildResult={
    available()
    // Historical source access and execution status are independent. The
    // native retained full child tuple supplies status; source ownership does
    // not turn an interrupted attempt into a terminal result.
    val identity=s"${request.request},${request.goal},${request.slot}"
    val reply=supervisor.exchange("poll_build",identity)
    val fields=reply.payload.split(",",-1)
    require(reply.tag=="build_result" && fields.length==8 && fields.take(3).mkString(",")==identity &&
      fields.drop(4).forall(_.matches("0|[1-9][0-9]{0,127}")),"native build result shape")
    val state=fields(3) match {
      case "queued"=>BuildState.Queued
      case "running"=>BuildState.Running
      case "pending_publication"=>BuildState.PendingPublication
      case "artifact_ready"=>BuildState.ArtifactReady
      case "failed"=>BuildState.Failed
      case "cancelled"=>BuildState.Cancelled
      case "historical"=>BuildState.Historical
      case _=>throw new IllegalArgumentException("native build result status")
    }
    val source=fields.slice(4,7).map(BigInt(_))
    val unavailable=source.forall(_==0)
    require((unavailable && state==BuildState.Cancelled) ||
      (source(1)>0 && source(2)>0 && (request.historical match {
        case Some(history)=>source(0)==0 && history.source.request==request.request &&
          history.source.goal==request.goal && history.source.slot==request.slot
        case None=>source(0)==0 || request.input.exists(_.nativeHandle==source(0))
      })),"native build source association mismatch")
    require(state!=BuildState.Historical || (source(0)==0 && !unavailable),"native historical Build status association")
    val candidate=BigInt(fields(7))
    require(if(state==BuildState.ArtifactReady)candidate>0 else candidate==0,"native build candidate status mismatch")
    require(reply.artifacts.size<=1 && (reply.artifacts.isEmpty || (state==BuildState.Failed && !unavailable && reply.artifacts.head.size<=8192)),"native build diagnostic frame")
    val diagnostic=reply.artifacts.headOption.map(frame=>new BuildDiagnostic(request,
      veri7vn.diagnostics.BuildFailure.parse(frame.text,source(1),source(2))))
    new BuildResult(state,if(candidate>0)Some(candidate)else None,diagnostic,!unavailable)
  }
  /** Borrow original captured bytes under their retained access gate. No native
    * transport or source-head replacement occurs within this callback. */
  def withBuildFailureSource[A](diagnostic:BuildDiagnostic)(consume:(veri7vn.packages.native_build.NativeBuildInputs.CapturedSource,
    java.nio.ByteBuffer,veri7vn.diagnostics.BuildFailure.Failure)=>A):A={
    available()
    val original=diagnostic.request.original
    def inspect(captured:veri7vn.packages.native_build.NativeBuildInputs.CapturedSource,bytes:java.nio.ByteBuffer):A={
      require(captured==original,"native build diagnostic captured source mismatch")
      veri7vn.diagnostics.SourceDiagnostic.locate(captured,bytes,diagnostic.failure,None)
      consume(captured,bytes,diagnostic.failure)
    }
    def retained():A={
      val history=buildHistory.getOrElse(throw new IllegalStateException("historical Build service unavailable"))
        .open(diagnostic.request.request).getOrElse(throw new IllegalStateException("Build diagnostic source unavailable"))
      try {
        require(history.source.goal==diagnostic.request.goal && history.source.slot==diagnostic.request.slot,
          "Build diagnostic historical child mismatch")
        history.inspect(inspect)
      } finally history.close()
    }
    diagnostic.request.input match {
      case Some(live)=>
        var entered=false
        try live.input.inspectCapturedSourceRetained(original.path) {(captured,bytes)=>
          entered=true;inspect(captured,bytes)
        } catch {case scala.util.control.NonFatal(problem) if !entered=>retained()}
      case None=>diagnostic.request.historical.get.inspect(inspect)
    }
  }
  def cancel(request:BigInt):Unit=lifecycle("cancel",request)
  def revoke(objectId:BigInt):Unit=lifecycle("revoke",objectId)
  def forget(objectId:BigInt):Unit=lifecycle("forget",objectId)
  private def awaitMutation[A](invoke: => ResidentSupervisor.Reply)(decode:ResidentSupervisor.Reply=>(String,A)):A={
    available()
    val (token,value)=receipts.synchronized {
      require(receipts.size<64,"too many awaited lifecycle receipts")
      val decoded=decode(invoke)
      require(decoded._1.matches("[1-9][0-9]{0,17}") && !receipts.contains(decoded._1),"native mutation token identity")
      receipts(decoded._1)=None
      decoded
    }
    val deadline=System.nanoTime()+60L*1000*1000*1000
    try receipts.synchronized {
      while(receipts(token).isEmpty && System.nanoTime()<deadline){available();receipts.wait(100)}
      require(receipts(token).exists(_.isInstanceOf[AuthorityCoordinator.Committed]),
        "native mutation not durably acknowledged: "+receipts(token))
      value
    } finally receipts.synchronized {receipts.remove(token)}
  }
  private def lifecycle(operation:String,id:BigInt):Unit={
    require(id>0 && id.toString.length<=128)
    awaitMutation(supervisor.exchange(operation,id.toString)){reply=>
      require(reply.tag=="lifecycle_queued" && reply.artifacts.isEmpty,"native lifecycle receipt refused")
      reply.payload->()
    }
  }
  def createConversation():BigInt=awaitMutation(supervisor.exchange("conversation_create")){reply=>
    val fields=reply.payload.split(",",-1)
    require(reply.tag=="conversation_queued" && reply.artifacts.isEmpty && fields.length==2 &&
      fields(1).matches("[1-9][0-9]{0,127}"),"native conversation creation receipt")
    fields(0)->BigInt(fields(1))
  }
  def listConversations():veri7vn.runtime.conversation.ConversationProtocol.Index={
    available()
    val reply=supervisor.exchange("conversation_list")
    require(reply.tag=="conversation_list" && reply.payload=="1" && reply.artifacts.size==1 &&
      reply.artifacts.head.size<=veri7vn.runtime.conversation.ConversationProtocol.maxFrameBytes,"native conversation list shape")
    veri7vn.runtime.conversation.ConversationProtocol.readIndex(reply.artifacts.head.text)
  }
  def openConversation(id:BigInt):veri7vn.runtime.conversation.ConversationProtocol.View={
    available();require(id>0 && id.toString.length<=128)
    val reply=supervisor.exchange("conversation_open",id.toString)
    require(reply.tag=="conversation_view" && reply.payload==id.toString && reply.artifacts.size==1 &&
      reply.artifacts.head.size<=veri7vn.runtime.conversation.ConversationProtocol.maxFrameBytes,"native conversation view shape")
    veri7vn.runtime.conversation.ConversationProtocol.readView(reply.artifacts.head.text,id)
  }
  def expireConversation(id:BigInt):Unit=lifecycle("conversation_expire",id)
  def proposeConversationMathematics(id:BigInt,expectedVersion:BigInt,original:Array[Byte],selection:Option[Int]=None):BigInt={
    available();require(id>0 && id.toString.length<=128 && expectedVersion>=0 && expectedVersion.toString.length<=128 &&
      original.length<=256 && selection.forall(n=>n>=0 && n<=255),"conversation mathematics input bound")
    val owned=original.clone()
    val reply=try supervisor.exchange("propose_conversation_math",s"$id,$expectedVersion,"+selection.map(_.toString).getOrElse(""),List(Bytes(owned)))
      finally java.util.Arrays.fill(owned,0.toByte)
    require(reply.tag=="proposed" && reply.artifacts.isEmpty && reply.payload.matches("[1-9][0-9]{0,127}"),"native conversation mathematics refused")
    BigInt(reply.payload)
  }
  def close():Unit={
    buildHistory.foreach(_.close())
    if(stopped.compareAndSet(false,true)) supervisor.close()
    if(Thread.currentThread()!=pump) pump.join(1000)
    coordinator.close()
  }
}
