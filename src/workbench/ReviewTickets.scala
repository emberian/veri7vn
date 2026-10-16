package veri7vn.workbench

import java.util.UUID
import java.nio.charset.StandardCharsets.UTF_8
import java.security.MessageDigest

/** Bounded one-use review consent. Retains only digests, never source or edits. */
final class ReviewTickets {
  private val pending=scala.collection.mutable.Map.empty[String,(Array[Byte],Long)]
  private def expire():Unit={
    val now=System.nanoTime()
    pending.keysIterator.filter(id=>now-pending(id)._2>=5L*60*1000*1000*1000).toList.foreach(pending.remove)
  }
  private def digest(fields:Map[String,String]):Array[Byte]={
    val canonical=fields.toVector.sortBy(_._1).map((key,value)=>key.length+":"+key+value.length+":"+value).mkString
    MessageDigest.getInstance("SHA-256").digest(canonical.getBytes(UTF_8))
  }
  def issue(fields:Map[String,String]):String=synchronized {
    expire();require(pending.size<64,"Too many pending reviews; apply or cancel an existing review")
    val id=UUID.randomUUID().toString;pending(id)=(digest(fields),System.nanoTime());id
  }
  def consume(id:String,fields:Map[String,String]):Boolean=synchronized {
    expire();pending.remove(id).exists((expected,_)=>MessageDigest.isEqual(expected,digest(fields)))
  }
  def cancel(id:String):Boolean=synchronized {expire();pending.remove(id).nonEmpty}
  def clear():Unit=synchronized {pending.clear()}
}
