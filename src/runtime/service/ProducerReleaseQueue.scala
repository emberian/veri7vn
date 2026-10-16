package veri7vn.runtime.service

import scala.language.unsafeNulls

object ProducerReleaseQueue {
  final case class Failure(preparedInput:BigInt,attempts:Int,reason:String)
}

/** Cleanup work owned by the existing maintenance pump, not a second scheduler.
  * Exhausted entries retain their opaque owner and remain explicitly retryable. */
private[service] final class ProducerReleaseQueue {
  import ProducerReleaseQueue.*
  private final class Entry(val input:NativeBuildIngress.PreparedInput) {
    var attempts=0;var nextAt=0L;var running=false;var error=""
  }
  private val entries=scala.collection.mutable.ArrayBuffer.empty[Entry]
  def enqueue(input:NativeBuildIngress.PreparedInput):Unit=synchronized {
    if(!entries.exists(_.input eq input)){
      require(entries.size<64,"producer release queue capacity exhausted")
      entries+=new Entry(input)
    }
  }
  def failures:Vector[Failure]=synchronized {
    entries.filter(_.attempts>=8).map(e=>Failure(e.input.nativeHandle,e.attempts,e.error)).toVector
  }
  def pendingCount:Int=synchronized {entries.size}
  def retryExhausted():Unit=synchronized {
    entries.filter(e=> !e.running && e.attempts>=8).foreach {e=>e.attempts=0;e.nextAt=0L;e.error=""}
  }
  def pump(now:Long):Unit={
    val selected=synchronized {
      entries.find(e=> !e.running && e.attempts<8 && now>=e.nextAt).map {e=>e.running=true;e}
    }
    selected.foreach {entry=>
      try {
        entry.input.ingress.releaseProducer(entry.input)
        synchronized {entries-=entry}
      } catch {case scala.util.control.NonFatal(problem)=>synchronized {
        entry.running=false;entry.attempts+=1
        entry.error=(problem.getClass.getSimpleName+": "+Option(problem.getMessage).getOrElse("")).take(256)
        entry.nextAt=now+math.min(30000L,250L*(1L<<(entry.attempts-1)))*1000000L
        // Rotate failures so a ready sibling can drain even while this owner fails.
        entries-=entry;entries+=entry
      }}
    }
  }
}
