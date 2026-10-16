package veri7vn.runtime.effects

import scala.language.unsafeNulls
import java.nio.file.{Files, Path, StandardOpenOption}

/** Limits are allocated from the actual run/job reservation by its authority owner.
  * They bound retained payload bytes and peak replacement payload staging. They are
  * not a process memory cap: JVM object/key overhead requires worker resource limits.
  */
final case class LearningBudget(owner: BigInt, maxItems: Int, maxMemoryBytes: Long,
    maxDiskBytes: Long, maxArtifacts: Int, maxIdentityChars: Int) {
  require(owner >= 0 && maxItems > 0 && maxMemoryBytes >= 0 && maxDiskBytes >= 0 && maxArtifacts > 0 && maxIdentityChars > 0)
}
final class IsolatedLearning private (initialBaseline: Map[String, Vector[Byte]],
    directory: Path, val budget: LearningBudget, write: (Path,Array[Byte]) => Unit)
    extends AutoCloseable {
  private var baseline = initialBaseline
  private var overlay = Map.empty[String, Vector[Byte]]
  private var artifacts = Map.empty[String, Path]
  private var owned = Map.empty[Path,Long]
  private var closed = false
  private def open(): Unit = require(!closed, "learning run closed")
  private def size(values: Iterable[Vector[Byte]]): Long = values.foldLeft(0L)((n,v) => Math.addExact(n,v.length.toLong))
  def lookup(identity: String): Option[Array[Byte]] = synchronized {
    open(); overlay.get(identity).orElse(baseline.get(identity)).map(_.toArray)
  }
  def learn(identity: String, bytes: Array[Byte]): Unit = synchronized {
    open(); require(identity.nonEmpty && identity.length <= budget.maxIdentityChars, "learning identity bound")
    require((baseline.keySet ++ overlay.keySet + identity).size <= budget.maxItems, "learning item budget")
    val overlayBytes=size(overlay.values)
    require(bytes.length.toLong * 2 <= budget.maxMemoryBytes-size(baseline.values)-overlayBytes, "learning memory budget")
    require(owned.size < budget.maxArtifacts, "learning artifact budget")
    require(bytes.length.toLong <= budget.maxDiskBytes-owned.values.sum, "learning disk budget")
    // Check the peak before cloning or allocating a temporary artifact. Replacement
    // keeps the old committed value until writing and cleanup have succeeded.
    val value=bytes.toVector
    val artifact=Files.createTempFile(directory,"candidate-",".bin")
    owned += artifact -> bytes.length.toLong
    try {
      write(artifact,value.toArray)
      artifacts.get(identity).foreach { old => Files.delete(old); owned -= old }
      artifacts=artifacts.updated(identity,artifact)
      overlay=overlay.updated(identity,value)
    } catch {
      case failure: Throwable =>
        try { Files.deleteIfExists(artifact); owned -= artifact }
        catch {case cleanup: Throwable => failure.addSuppressed(cleanup)}
        throw failure
    }
  }
  /** Returned immutable byte snapshots have their own caller-managed retention. */
  def snapshot: Map[String, Vector[Byte]] = synchronized { open(); baseline ++ overlay }
  private[effects] def retainedPayloadBytes: Long = synchronized {size(baseline.values)+size(overlay.values)}
  def close(): Unit = synchronized {
    closed=true
    baseline=Map.empty; overlay=Map.empty; artifacts=Map.empty
    // Only explicitly owned paths are removed. Retain failed paths for another close.
    var failure: Option[Throwable]=None
    owned.keys.toList.foreach { path =>
      try {Files.deleteIfExists(path); owned -= path}
      catch {case problem: Throwable => failure match {
        case None => failure=Some(problem)
        case Some(first) => first.addSuppressed(problem)
      }}
    }
    if(owned.isEmpty) try {Files.deleteIfExists(directory)} catch {
      case problem: Throwable => failure match {
        case None => failure=Some(problem)
        case Some(first) => first.addSuppressed(problem)
      }
    }
    failure.foreach(throw _)
  }
}
object IsolatedLearning {
  def fork(parent: Path, baseline: Map[String, Array[Byte]], budget: LearningBudget): IsolatedLearning =
    forkWithWriter(parent,baseline,budget,(path,bytes) => {
      Files.write(path,bytes,StandardOpenOption.TRUNCATE_EXISTING); ()
    })
  private[effects] def forkWithWriter(parent: Path, baseline: Map[String,Array[Byte]],
      budget: LearningBudget, write: (Path,Array[Byte]) => Unit): IsolatedLearning = {
    require(baseline.size<=budget.maxItems,"baseline item budget")
    val bytes=baseline.values.foldLeft(0L)((n,v) => Math.addExact(n,v.length.toLong))
    require(bytes<=budget.maxMemoryBytes,"baseline memory budget")
    // Validate aggregate limits before copying payloads or creating the run directory.
    val copied=baseline.map {case (k,v) => require(k.nonEmpty && k.length<=budget.maxIdentityChars,"learning identity bound"); k -> v.toVector}
    Files.createDirectories(parent)
    val directory=Files.createTempDirectory(parent,"learning-run-")
    try new IsolatedLearning(copied,directory,budget,write)
    catch {case failure: Throwable =>
      try Files.delete(directory) catch {case cleanup: Throwable => failure.addSuppressed(cleanup)}
      throw failure
    }
  }
}
