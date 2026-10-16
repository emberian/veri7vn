package veri7vn.sources

import scala.language.unsafeNulls
import java.io.{ByteArrayOutputStream,DataOutputStream}
import java.nio.file.{Files,Path,LinkOption}
import java.security.MessageDigest

/** Acquisition of declared inert local inputs. No SQL/connector execution, publication,
  * clock sampling, forgotten-locator recovery or source-policy decisions occur here.
  * Raw bytes go to the generated native Source_Row_Import decoder, not a Scala parser.
  */
object LocalSnapshot {
  final case class Limits(maxBytes: Int = 65536, maxManifestBytes: Int = 65536) {
    require(maxBytes>0 && maxBytes<=16*1024*1024 && maxManifestBytes>0 && maxManifestBytes<=16*1024*1024)
  }
  enum Origin { case Measured, Simulated, Unknown }
  enum Retention { case Private, Public }
  final case class Clock(basis: String, origin: String, ticks: BigInt)
  final case class Acquisition(event: Option[Clock], receipt: Clock, poll: Option[Clock],
    sequence: BigInt, configuration: String, calibration: Option[String], qualityPolicy: String,
    origin: Origin)
  final case class Manifest(source: String, version: Option[String], schema: String,
    encoding: String, selection: String, recipe: String, license: Option[String],
    provenance: Option[String], qualifiers: Vector[String], rank: Option[String],
    units: Option[String], references: Vector[String], knownLoss: Vector[String],
    acquisition: Acquisition, retention: Retention) {
    require(Vector(source,schema,encoding,selection,recipe,acquisition.sequence.toString,
      acquisition.configuration,acquisition.qualityPolicy).forall(_.nonEmpty),"Missing source identity/policy")
  }
  final class Candidate private[LocalSnapshot](identity: String, payloadIdentity: String,
    sourceManifest: Manifest, original: Array[Byte], record: Array[Byte]) {
    private final case class Material(id: String,payloadId: String,manifest: Manifest,
      bytes: Array[Byte],manifestBytes: Array[Byte])
    private var material: Option[Material]=Some(Material(identity,payloadIdentity,sourceManifest,original,record))
    private def retained: Material=material.getOrElse(throw new IllegalStateException("source candidate released"))
    def id: String=synchronized {retained.id}
    def payloadId: String=synchronized {retained.payloadId}
    def manifest: Manifest=synchronized {retained.manifest}
    def bytes: Array[Byte]=synchronized {retained.bytes.clone()}
    def manifestBytes: Array[Byte]=synchronized {retained.manifestBytes.clone()}
    def derivedRetention: Retention=synchronized {retained.manifest.retention}
    def isLive: Boolean=synchronized {material.nonEmpty}
    /** Called by the host's authorized managed-object closure, never a policy decision here.
      * In-flight readers and previously returned copies must be drained/dropped by that owner.
      */
    def release(): Unit=synchronized {
      material.foreach(m=>{java.util.Arrays.fill(m.bytes,0.toByte);java.util.Arrays.fill(m.manifestBytes,0.toByte)})
      material=None
    }
  }
  def hash(bytes: Array[Byte]): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).map(b=>f"${b & 255}%02x").mkString
  private[sources] def manifestRecord(m: Manifest,payload: Option[String]): Array[Byte] = {
    val buffer=new ByteArrayOutputStream();val out=new DataOutputStream(buffer)
    def text(s: String): Unit={
      val encoded=java.nio.charset.StandardCharsets.UTF_8.newEncoder()
        .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
        .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
        .encode(java.nio.CharBuffer.wrap(s))
      val b=new Array[Byte](encoded.remaining());encoded.get(b);out.writeInt(b.length);out.write(b)
    }
    def opt(s: Option[String]): Unit={out.writeBoolean(s.nonEmpty);s.foreach(text)}
    def strings(ss: Vector[String]): Unit={out.writeInt(ss.size);ss.foreach(text)}
    def clock(c: Clock): Unit={text(c.basis);text(c.origin);text(c.ticks.toString)}
    def optionalClock(c: Option[Clock]): Unit={out.writeBoolean(c.nonEmpty);c.foreach(clock)}
    text("veri7vn-local-source/2");opt(payload);text(m.source);opt(m.version);text(m.schema)
    text(m.encoding);text(m.selection);text(m.recipe);opt(m.license);opt(m.provenance)
    strings(m.qualifiers);opt(m.rank);opt(m.units);strings(m.references);strings(m.knownLoss)
    optionalClock(m.acquisition.event);clock(m.acquisition.receipt);optionalClock(m.acquisition.poll)
    text(m.acquisition.sequence.toString);text(m.acquisition.configuration);opt(m.acquisition.calibration)
    text(m.acquisition.qualityPolicy);text(m.acquisition.origin.toString);text(m.retention.toString)
    out.flush();buffer.toByteArray
  }
  def prepare(bytes: Array[Byte], manifest: Manifest, limits: Limits = Limits()): Candidate = {
    require(bytes.length<=limits.maxBytes,"Source exceeds acquisition bound")
    require(manifest.qualifiers.size<=256 && manifest.references.size<=256 && manifest.knownLoss.size<=256,
      "Too many manifest fields")
    val clocks=manifest.acquisition.event.toVector++Vector(manifest.acquisition.receipt)++manifest.acquisition.poll.toVector
    require(manifest.acquisition.sequence>=0 && manifest.acquisition.sequence.bitLength<=4096,"Sequence exceeds native numeric identity bound")
    require(clocks.forall(_.ticks.abs.bitLength<=4096),"Clock value exceeds manifest bound")
    val fields=Vector(manifest.source,manifest.schema,manifest.encoding,manifest.selection,manifest.recipe,
      manifest.acquisition.sequence.toString,manifest.acquisition.configuration,manifest.acquisition.qualityPolicy)++
      manifest.version.toVector++manifest.license.toVector++manifest.provenance.toVector++manifest.qualifiers++
      manifest.rank.toVector++manifest.units.toVector++manifest.references++manifest.knownLoss++
      manifest.acquisition.calibration.toVector++clocks.flatMap(c=>Vector(c.basis,c.origin,c.ticks.toString))
    require(fields.foldLeft(0L)((n,s)=>n+s.length.toLong)<=limits.maxManifestBytes/4,"Manifest text exceeds bound")
    val original=bytes.clone();val payload=hash(original);val record=manifestRecord(manifest,Some(payload))
    require(record.length<=limits.maxManifestBytes,"Source manifest exceeds bound")
    new Candidate(hash(record),payload,manifest,original,record)
  }
  def acquire(path: Path,manifest: Manifest,limits: Limits = Limits()): Candidate = {
    require(Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS),"Source must be an inert regular file")
    val in=Files.newInputStream(path,LinkOption.NOFOLLOW_LINKS)
    val bytes=new ByteArrayOutputStream()
    try {
      val chunk=new Array[Byte](4096);var n=in.read(chunk)
      while(n != -1) {require(bytes.size().toLong+n<=limits.maxBytes,"Source exceeds acquisition bound");bytes.write(chunk,0,n);n=in.read(chunk)}
    } finally in.close()
    prepare(bytes.toByteArray,manifest,limits)
  }
  /** An unavailable original is explicit; it is not replaced with a differently licensed corpus. */
  final case class Unavailable(source: String, requiredSchema: String, reason: String)
  val unavailableOriginals=Vector(
    Unavailable("relations_v2","original-relations-v2","Original store unavailable; v1 schemas are not v2 parity"),
    Unavailable("names","original-names","Original store unavailable"),
    Unavailable("labels-aliases","original-labels-aliases","Original store unavailable"))
}
