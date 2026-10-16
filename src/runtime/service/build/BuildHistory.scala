package veri7vn.runtime.service.build

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import veri7vn.packages.intake.Intake
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.effects.ResourceBudget
import veri7vn.runtime.host.{ManagedSources,WorkspaceStore}

private[service] object BuildHistory {
  final class HistoricalBuild private[BuildHistory](private[BuildHistory] val owner:BuildHistory,
      val source:WorkspaceStore.NativeBuildSource,
      private[BuildHistory] val original:NativeBuildInputs.HistoricalOwned) extends AutoCloseable {
    def inspect[A](consume:(NativeBuildInputs.CapturedSource,ByteBuffer)=>A):A=
      original.inspectCapturedSourceRetained(consume)
    def close():Unit=owner.release(this)
  }
}
/** Reopens authenticated original sources, without a dispatch or current grant.
  * Each open consults the actual current committed BuildRequest association. */
private[service] final class BuildHistory(store:WorkspaceStore,sources:ManagedSources)
    extends AutoCloseable {
  import BuildHistory.HistoricalBuild
  private val opened=scala.collection.mutable.Set.empty[HistoricalBuild]
  private var closed=false
  private def release(entry:HistoricalBuild):Unit=synchronized {
    require(entry.owner eq this,"Foreign historical Build source owner")
    entry.original.close()
    opened-=entry
  }
  def open(request:BigInt):Option[HistoricalBuild]=synchronized {
    require(!closed && request>0 && request.toString.length<=128,"Historical Build request unavailable")
    require(opened.size<2,"Historical Build inspection owner bound")
    store.latestNative.flatMap(record=>store.committedNativeBuildSourceForRequest(record,request)).map {lease=>
      val limits=Intake.Limits()
      val manifestBound=limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024
      // Parsed closure, retained source arrays, parser clones and one borrowed file.
      val bytes=Math.addExact(Math.multiplyExact(limits.maxTotalBytes,4L),
        Math.addExact(Math.multiplyExact(manifestBound,3L),
          Math.addExact(limits.maxFileBytes.toLong,math.max(limits.maxArchiveBytes,limits.maxFileBytes).toLong)))
      val budget=ResourceBudget(request,bytes,limits.maxEntries+1,1,1,0,1,1,1)
      val original=NativeBuildInputs.recoverHistorical(sources,lease,budget,limits)
      val entry=new HistoricalBuild(this,lease.source,original)
      opened+=entry
      entry
    }
  }
  /** Failed destructors remain in the owning set for an explicit cleanup retry. */
  def close():Unit=synchronized {
    closed=true
    opened.toVector.foreach(_.close())
  }
}
