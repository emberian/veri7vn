package veri7vn.sources
import scala.language.unsafeNulls
import veri7vn.runtime.host.ManagedSources

/** An already-authorized host stage owns every write and cleanup obligation.
  * Construct only after the host's exact attempt handoff. This adapter neither
  * starts an attempt nor commits a source head or publishes a native observation.
  */
final class ManagedChunkObjects(stage: ManagedSources#Stage) extends ChunkedSnapshot.Objects {
  def put(expected: String, bytes: Array[Byte], retention: LocalSnapshot.Retention): Unit = {
    if(Thread.currentThread().isInterrupted) throw new InterruptedException("source cancelled")
    require(LocalSnapshot.hash(bytes)==expected,"source chunk identity mismatch")
    val installed=stage.put(bytes)
    require(installed==expected,"managed chunk identity mismatch")
    val recovered=stage.read(installed,bytes.length.toLong)
    require(java.util.Arrays.equals(recovered,bytes),"managed chunk readback mismatch")
  }
}
