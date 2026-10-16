package veri7vn.runtime.service

import isabelle.Bytes
import scala.language.unsafeNulls
import java.util.concurrent.atomic.AtomicBoolean

/** Finite resident client. Native gates mint every workflow event; the single pump
  * commits them through the coordinator before native continuation or handoff. */
final class ResidentAuthorityService private[service](supervisor:ResidentSupervisor,
  coordinator:AuthorityCoordinator) extends AutoCloseable {
  coordinator.requireReady()
  private val stopped=new AtomicBoolean(false)
  @volatile private var failure:Option[Throwable]=None
  private val pump=new Thread(new Runnable {def run():Unit={
    try while(!stopped.get()) {
      supervisor.awaitAuthorizedToken().foreach {token=>
      coordinator.submit(token) match {
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
    require(reply.tag=="result" && reply.artifacts.size<=1,"native result shape")
    require(reply.artifacts.isEmpty || reply.payload=="accepted_exact","unlicensed result payload")
    Result(reply.payload,reply.artifacts.headOption.map(_.text))
  }
  def cancel(request:BigInt):Unit=lifecycle("cancel",request)
  def forget(objectId:BigInt):Unit=lifecycle("forget",objectId)
  private def lifecycle(operation:String,id:BigInt):Unit={
    available();require(id>0 && id.toString.length<=128)
    val reply=supervisor.exchange(operation,id.toString)
    require(reply.tag=="lifecycle_queued" && reply.artifacts.isEmpty,"native lifecycle refused")
  }
  def close():Unit={
    if(stopped.compareAndSet(false,true)) supervisor.close()
    if(Thread.currentThread()!=pump) pump.join(1000)
    coordinator.close()
  }
}
