package veri7vn.packages.native_build

import scala.language.unsafeNulls
import java.nio.file.{Files,Path,LinkOption}
import java.nio.ByteBuffer
import veri7vn.packages.intake.{Intake,SourceObjects,ByteObjects}
import veri7vn.runtime.host.{ManagedSources,WorkspaceStore}
import veri7vn.runtime.effects.{WorkerResources,ResourceBudget,WorkerLifetime}
import veri7vn.packages.lifecycle.{SessionInventory,PackageModel}

/** Host-internal integrity check over an ALREADY host-owned materialized closure.
  * It issues no source/worker/exposure permission, native admission, successful
  * build, executable identity or sandbox. The host's live input/worker lease must
  * own memory and directories before capture and through replay/handoff/cleanup.
  * There is deliberately no unleased source capture/materialization endpoint.
  */
object NativeBuildInputs {
  final case class Pin(sha256:String,size:Long) {
    require(sha256.matches("[0-9a-f]{64}") && size>=0 && size<=64L*1024*1024,"Invalid build source pin")
  }
  /** Opaque host-only live owner. It exposes inspection, never private bytes or
    * an unregistered snapshot/path resolver. Closing releases tracked derivatives.
    * Durable crash scratch cleanup still depends on the host ownership journal.
    */
  final case class CapturedSource(draft:String,revision:String,manifest:String,path:String,pin:Pin)
  final case class IntentView(draft:String,revision:String,manifest:String,descriptorPath:String,
      descriptorPin:Pin,descriptor:PackageModel.Descriptor)
  private final case class IntentPayload(view:IntentView,original:Intake.Content)
  /** Opaque original-descriptor expectation. This carries no proof or activation.
    * Inspection/transport are fixed host-internal consumers inside the live owner;
    * the original descriptor never becomes a path resolved by a worker. */
  final class ExportIntent private[NativeBuildInputs](private val owner:Owned)(
      private val payload:owner.resources.OwnedRoot[IntentPayload]) {
    def isLive:Boolean=owner.isLive
    def inspect[A](consume:IntentView=>A):A=payload.withValue(p=>consume(p.view))
    /** Bounded temporary transport clone; a retained view is zeroed on return.
      * Receiver must register its own native input lifetime before copying. */
    def withOriginal[A](consume:ByteBuffer=>A):A=payload.withValue {p=>
      val bytes=p.original.bytes
      try consume(ByteBuffer.wrap(bytes).asReadOnlyBuffer())
      finally java.util.Arrays.fill(bytes,0.toByte)
    }
  }
  private final case class State(directory:Path,pins:Map[String,Pin],draft:String,revision:String,manifest:String)
  final class Owned private[NativeBuildInputs](private[NativeBuildInputs] val resources:WorkerResources)(
      private val state:resources.OwnedRoot[State],
      private val revision:resources.OwnedRoot[Intake.Revision],private val limits:Intake.Limits) extends AutoCloseable {
    private var intent:Option[ExportIntent]=None
    def isLive:Boolean=resources.isLive
    private[veri7vn] def currentSourceGuard:WorkspaceStore.NativeSourceGuard=resources.currentSourceGuard
    private[veri7vn] def attachTransferWorker(worker:WorkerLifetime):Unit=resources.attachWorker(worker)
    /** Fixed transfer job only. Clone registration precedes copying; native I/O
      * runs outside source/resource monitors. Current adoption is checked later. */
    private[veri7vn] def withTransferSource[A](worker:WorkerLifetime,relative:String)(
        consume:(CapturedSource,ByteBuffer)=>A):A={
      var captured:Option[CapturedSource]=None
      val maximum=math.min(limits.maxFileBytes,1000000)
      resources.withTransfer(worker,maximum) {
        state.withValue {current=>revision.withValue {source=>
          require(Intake.portablePath(relative,limits)==relative,"Invalid transfer source path")
          val entry=source.entries.find(_.path==relative)
            .getOrElse(throw new IllegalArgumentException("Path not in captured source revision"))
          require(entry.content.size<=maximum,"Native source transfer byte bound")
          captured=Some(CapturedSource(current.draft,current.revision,current.manifest,relative,
            Pin(entry.content.sha256,entry.content.size.toLong)))
          entry.content.bytes
        }}
      } {bytes=>consume(captured.getOrElse(throw new IllegalStateException("Missing transfer source metadata")),bytes)}
    }
    private[veri7vn] def withTheoryTransfer[A](worker:WorkerLifetime,path:String)(
        consume:(CapturedSource,ByteBuffer)=>A):A=withTransferSource(worker,path)(consume)
    private[veri7vn] def withDescriptorTransfer[A](worker:WorkerLifetime)(
        consume:(IntentView,ByteBuffer)=>A):A={
      val original=exportIntent.inspect(view=>view)
      withTransferSource(worker,original.descriptorPath) {(captured,bytes)=>
        require(captured.draft==original.draft && captured.revision==original.revision &&
          captured.manifest==original.manifest && captured.pin==original.descriptorPin,
          "Captured descriptor intent/transport mismatch")
        consume(original,bytes)
      }
    }
    /** Parse the actual captured package.json once, under a reserved private root.
      * This exact typed expectation predates replay and is not copied from exports
      * discovered in a resulting native candidate. No descriptor is required for
      * inventory-only use; asking for intent validates the real package schema. */
    def exportIntent:ExportIntent=synchronized {
      state.withValue {current=>
        intent.getOrElse {
          val captured=revision.withValue {source=>
            val entry=source.entries.find(_.path=="package.json")
              .getOrElse(throw new IllegalArgumentException("Missing captured package.json export intent"))
            require(entry.content.size<=1000000,"Native descriptor interpretation byte bound")
            val root=resources.reserveRoot[IntentPayload](Math.addExact(4096L,Math.multiplyExact(entry.content.size.toLong,8L)))
            val descriptor=PackageModel.descriptor(entry.content)
            root.install(IntentPayload(IntentView(current.draft,current.revision,current.manifest,entry.path,
              Pin(entry.content.sha256,entry.content.size.toLong),descriptor),entry.content))
            new ExportIntent(this)(root)
          }
          intent=Some(captured);captured
        }
      }
    }
    /** Fixed protected transfer/repair consumer over the ORIGINAL captured revision.
      * Reads no mutable materialized path and never substitutes the current head.
      * The reserved parser envelope includes one max-file temporary clone; resource
      * ownership serializes callbacks, and the borrowed view is wiped on return. */
    private def borrowSource[A](current:State,source:Intake.Revision,relative:String)(
        consume:(CapturedSource,ByteBuffer)=>A):A={
      require(Intake.portablePath(relative,limits)==relative,"Invalid captured source path")
      val entry=source.entries.find(_.path==relative)
        .getOrElse(throw new IllegalArgumentException("Path not in captured source revision"))
      val bytes=entry.content.bytes
      try consume(CapturedSource(current.draft,current.revision,current.manifest,relative,
        Pin(entry.content.sha256,entry.content.size.toLong)),ByteBuffer.wrap(bytes).asReadOnlyBuffer())
      finally java.util.Arrays.fill(bytes,0.toByte)
    }
    def withCapturedSource[A](relative:String)(consume:(CapturedSource,ByteBuffer)=>A):A=
      state.withValue(current=>revision.withValue(source=>borrowSource(current,source,relative)(consume)))
    /** Governed historical inspection only; never build/revalidation permission.
      * Access/revocation/Forget and this capture's ownership are still checked. */
    def inspectCapturedSourceRetained[A](relative:String)(consume:(CapturedSource,ByteBuffer)=>A):A=
      state.withRetainedValue(current=>revision.withRetainedValue(source=>borrowSource(current,source,relative)(consume)))
    def inspect(selected:String,relativeRoots:Vector[String],installedPins:Map[String,Pin]):Unit=
      state.withValue {current=>
        val directory=current.directory
        val roots=relativeRoots.map {relative=>
          require(relative=="." || Intake.portablePath(relative)==relative,"Invalid native session root")
          directory.resolve(relative).normalize()
        }
        val inventory=SessionInventory.inspect(selected,roots)
        verify(directory,current.pins,inventory,installedPins)
        ()
      }
    def close():Unit=resources.close()
  }
  /** Registration happens inside the source scope before the parser's first
    * byte copy. All private parser roots and derived files stay on that owner.
    * The caller must obtain the generated build/reveal grant before invoking this.
    * The default source limit is 2048 entries; actual host scratch caps also count
    * directories and may reject an input before the inventory-only 32768 pin cap.
    */
  def materialize(sources:ManagedSources,draft:String,expectedManifest:String,
      budget:ResourceBudget,limits:Intake.Limits=Intake.Limits()):Option[Owned]=
    WorkerResources.withCurrentCapture(sources,draft,expectedManifest,budget) {capture=>
      val resources=capture.resources
      val manifestBound=limits.maxEntries.toLong*(limits.maxPathBytes+150)+1024
      val cloneEnvelope=Math.addExact(Math.multiplyExact(limits.maxTotalBytes,3L),
        Math.addExact(Math.multiplyExact(manifestBound,2L),limits.maxFileBytes.toLong))
      val parsed=resources.reserveRoot[Intake.Revision](cloneEnvelope)
      val temporary=scala.collection.mutable.ArrayBuffer.empty[Array[Byte]]
      try {
        val objects=new SourceObjects(new ByteObjects {
          def put(bytes:Array[Byte]):String=throw new UnsupportedOperationException("Read-only native build input")
          def read(id:String,maxBytes:Long):Array[Byte]={
            val owned=capture.read(id,Math.toIntExact(maxBytes)).readOnly
            val copy=new Array[Byte](owned.remaining());temporary+=copy;owned.get(copy);copy
          }
        },limits)
        parsed.install(objects.recover(expectedManifest))
      } finally temporary.foreach(bytes=>java.util.Arrays.fill(bytes,0.toByte))
      parsed.withValue {revision=>
        val root=resources.createDirectory().toRealPath()
        val metadataBytes=Math.multiplyExact(revision.entries.size.toLong,
          (root.toString.length.toLong+limits.maxPathBytes+1L)*2L+256L)
        val state=resources.reserveRoot[State](metadataBytes)
        val pins=revision.entries.map {entry=>
          val relative=Intake.portablePath(entry.path,limits)
          val slot=resources.reserveFile(relative,entry.content.size.toLong)
          slot.writeFrom(entry.content.bytes)
          slot.path.toRealPath().toString->Pin(entry.content.sha256,entry.content.size.toLong)
        }.toMap
        state.install(State(root,pins,draft,revision.id,expectedManifest))
        new Owned(resources)(state,parsed,limits)
      }
    }
  /** sourcePins are the exact immutable source revision closure; installedPins
    * come from the accepting host's pinned public image, never worker labels.
    * Root/options/toolchain/executable setup are separately pinned by that host.
    * Caller holds the live registered input/workspace lease throughout this call.
    */
  def verify(root:Path,sourcePins:Map[String,Pin],inventory:SessionInventory.Inventory,
      installedPins:Map[String,Pin]):Unit={
    require(Files.isDirectory(root,LinkOption.NOFOLLOW_LINKS) && !Files.isSymbolicLink(root),
      "Build root must be a host-owned directory")
    val realRoot=root.toRealPath()
    require(sourcePins.nonEmpty && sourcePins.size<=32768 &&
      sourcePins.values.map(_.size).sum<=256L*1024*1024,"Materialized source closure budget")
    require(sourcePins.keys.forall(p=>Path.of(p).normalize().startsWith(realRoot)),
      "Captured source pin outside materialized workspace")
    require(inventory.roots.forall(p=>Path.of(p).startsWith(realRoot)),
      "Inventory roots outside materialized source")
    inventory.sources.foreach {source=>
      val expected=sourcePins.get(source.path).orElse(installedPins.get(source.path))
        .getOrElse(throw new IllegalArgumentException("Unpinned native build source: "+source.path))
      require(expected==Pin(source.sha256,source.size),
        "Native build source differs from captured closure: "+source.path)
    }
    // ROOT/ROOTS do not carry earlier analyzer digests. Recheck all captured
    // files while the same owned workspace is held, with no source bytes escaping.
    sourcePins.foreach {case(path,pin)=>
      val p=Path.of(path)
      require(Files.isRegularFile(p,LinkOption.NOFOLLOW_LINKS) && p.toRealPath().startsWith(realRoot),
        "Materialized source replaced")
      val in=Files.newInputStream(p,LinkOption.NOFOLLOW_LINKS)
      val bytes=try in.readNBytes(Math.toIntExact(pin.size)+1) finally in.close()
      try require(bytes.length.toLong==pin.size && Intake.hash(bytes)==pin.sha256,
        "Materialized source changed")
      finally java.util.Arrays.fill(bytes,0.toByte)
    }
  }
}
