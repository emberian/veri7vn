package veri7vn.runtime.service

import scala.language.unsafeNulls

/** Bounded client-side proposal ownership. Native interpretation and the existing
  * authority service still decide what may run and what may be rendered. */
object DialogueClient {
  final case class Inspection(handle:Long,status:String,alternatives:List[Int],policy:String)
}

final class DialogueClient(resident:ResidentAuthorityService) extends AutoCloseable {
  import DialogueClient.*
  private final case class Pending(original:Array[Byte],alternatives:List[Int],created:Long)
  private val pending=scala.collection.mutable.Map.empty[Long,Pending]
  private var nextHandle=0L
  private var closed=false
  private val lifetimeNanos=5L*60*1000*1000*1000
  private def erase(value:Pending):Unit=java.util.Arrays.fill(value.original,0.toByte)
  private def expire():Unit={
    val now=System.nanoTime()
    pending.keysIterator.filter(id=>now-pending(id).created>=lifetimeNanos).toList.foreach {id=>
      pending.remove(id).foreach(erase)
    }
  }
  private def available():Unit={require(!closed,"dialogue client closed");expire()}

  /** An inspection is not an execution request or an accepted answer. */
  def inspect(original:Array[Byte]):Inspection=synchronized {
    available()
    require(original.length<=256,"dialogue input exceeds native byte budget")
    require(pending.size<128,"too many unresolved dialogue proposals")
    val retained=original.clone()
    try {
      val result=resident.inspectRouting(retained)
      require(Set("readings","literal","budget","unrecognized","structure_blocked").contains(result.status),
        "native routing inspection status")
      require(result.alternatives.distinct==result.alternatives &&
        result.alternatives.forall(i=>i>=0 && i<=255) &&
        ((result.status=="readings") == result.alternatives.nonEmpty),
        "native routing inspection alternatives")
      if(result.status=="readings") {
        nextHandle=Math.addExact(nextHandle,1L)
        pending(nextHandle)=Pending(retained,result.alternatives,System.nanoTime())
        Inspection(nextHandle,if(result.alternatives.size==1)"ready" else "clarification",
          result.alternatives,"math/1")
      } else {
        java.util.Arrays.fill(retained,0.toByte)
        Inspection(0L,result.status,Nil,"math/1")
      }
    } catch {case failure:Throwable=>java.util.Arrays.fill(retained,0.toByte);throw failure}
  }

  /** One-shot selection retains exact original bytes. Native elaboration reruns
    * the fixed reader and reserves the ordinary D46 mathematics request. */
  def select(handle:Long,index:Int):BigInt=synchronized {
    available()
    val proposal=pending.getOrElse(handle,
      throw new IllegalArgumentException("unknown or expired dialogue inspection"))
    require(proposal.alternatives.contains(index),"selection was not a native alternative")
    pending.remove(handle)
    try resident.proposeMathematics(proposal.original,Some(index)) finally erase(proposal)
  }

  def discard(handle:Long):Unit=synchronized {
    available();pending.remove(handle).foreach(erase)
  }
  def close():Unit=synchronized {
    if(!closed){closed=true;pending.valuesIterator.foreach(erase);pending.clear()}
  }
}
