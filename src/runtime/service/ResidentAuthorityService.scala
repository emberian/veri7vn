package veri7vn.runtime.service

import isabelle.Bytes
import scala.language.unsafeNulls
import java.util.concurrent.atomic.AtomicBoolean

/** Finite resident client. Native gates mint every workflow event; the single pump
  * commits them through the coordinator before native continuation or handoff. */
final class ResidentAuthorityService private[service](supervisor:ResidentSupervisor,
  coordinator:AuthorityCoordinator,buildIngress:Option[NativeBuildIngress]=None) extends AutoCloseable {
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
  final class BuildRequest private[ResidentAuthorityService](val request:BigInt,val goal:BigInt,val slot:BigInt,
    private[service] val input:NativeBuildIngress.PreparedInput)
  def prepareBuild(input:veri7vn.packages.native_build.NativeBuildInputs.Owned,theoryPath:String,
    parents:Vector[BigInt]=Vector.empty):NativeBuildIngress.PreparedInput={
    available();buildIngress.getOrElse(throw new IllegalStateException("native build ingress unavailable")).prepare(input,theoryPath,parents)
  }
  /** Proposal is queued; it is not an execution, charge, or artifact receipt. */
  def proposeBuild(input:NativeBuildIngress.PreparedInput):BuildRequest={
    available()
    val ingress=buildIngress.getOrElse(throw new IllegalStateException("native build ingress unavailable"))
    require(ingress.preparedInput(input.nativeHandle) eq input,"native build input association mismatch")
    val reply=supervisor.exchange("propose_build",input.nativeHandle.toString)
    val fields=reply.payload.split(",",-1)
    require(reply.tag=="build_proposed" && reply.artifacts.isEmpty && fields.length==3 &&
      fields.forall(_.matches("[1-9][0-9]{0,127}")),"native build proposal refused")
    new BuildRequest(BigInt(fields(0)),BigInt(fields(1)),BigInt(fields(2)),input)
  }
  enum BuildState { case Queued,Running,PendingPublication,ArtifactReady,Failed,Cancelled }
  final class BuildDiagnostic private[ResidentAuthorityService](private[service] val request:BuildRequest,
    val failure:veri7vn.diagnostics.BuildFailure.Failure)
  final class BuildResult private[ResidentAuthorityService](val state:BuildState,val candidate:Option[BigInt],
    val diagnostic:Option[BuildDiagnostic],val sourceAvailable:Boolean)
  def buildResult(request:BuildRequest):BuildResult={
    available()
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
      case _=>throw new IllegalArgumentException("native build result status")
    }
    val source=fields.slice(4,7).map(BigInt(_))
    val unavailable=source.forall(_==0)
    require((unavailable && state==BuildState.Cancelled) ||
      (source.forall(_>0) && source(0)==request.input.nativeHandle),"native build source association mismatch")
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
    val original=diagnostic.request.input.original
    diagnostic.request.input.input.inspectCapturedSourceRetained(original.path){(captured,bytes)=>
      require(captured==original,"native build diagnostic captured source mismatch")
      veri7vn.diagnostics.SourceDiagnostic.locate(captured,bytes,diagnostic.failure,None)
      consume(captured,bytes,diagnostic.failure)
    }
  }
  def cancel(request:BigInt):Unit=lifecycle("cancel",request)
  def forget(objectId:BigInt):Unit=lifecycle("forget",objectId)
  private def lifecycle(operation:String,id:BigInt):Unit={
    available();require(id>0 && id.toString.length<=128)
    // Register before the pump can publish completion, even when native emits
    // its token before returning the lifecycle reply. Regular commits retain no
    // receipts and cannot evict an awaited completion.
    val token=receipts.synchronized {
      require(receipts.size<64,"too many awaited lifecycle receipts")
      val reply=supervisor.exchange(operation,id.toString)
      require(reply.tag=="lifecycle_queued" && reply.payload.matches("[1-9][0-9]{0,17}") && reply.artifacts.isEmpty,"native lifecycle receipt refused")
      require(!receipts.contains(reply.payload),"duplicate native lifecycle token")
      receipts(reply.payload)=None
      reply.payload
    }
    val deadline=System.nanoTime()+60L*1000*1000*1000
    try receipts.synchronized {
      while(receipts(token).isEmpty && System.nanoTime()<deadline){
        available();receipts.wait(100)
      }
      val outcome=receipts(token)
      require(outcome.exists(_.isInstanceOf[AuthorityCoordinator.Committed]),"native lifecycle not durably acknowledged: "+outcome)
    } finally receipts.synchronized {receipts.remove(token)}
  }
  def close():Unit={
    if(stopped.compareAndSet(false,true)) supervisor.close()
    if(Thread.currentThread()!=pump) pump.join(1000)
    coordinator.close()
  }
}
