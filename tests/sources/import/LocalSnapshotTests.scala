package veri7vn.sources
import scala.language.unsafeNulls
import java.nio.file.Files
object LocalSnapshotTests {
  import LocalSnapshot.*
  def main(args: Array[String]): Unit = {
    val receipt=Clock("wall","UTC",100)
    val event=Clock("source-event","sensor-origin",10)
    val m=Manifest("fixture-sensor",Some("recorded-v1"),"source-row/1:nullable,integer,text,blob",
      "UTF-8 text; opaque blobs","declared ordered rows","source-row-codec/1",Some("CC0 fixture"),
      Some("hand-authored deterministic fixture"),Vector("test-only"),None,Some("Celsius"),
      Vector("fixture:local"),Vector.empty,
      Acquisition(Some(event),receipt,Some(receipt),BigInt(4),"Celsius-v1",Some("cal-1"),"retain-rejected",Origin.Measured),Retention.Private)
    // Two columns and three rows: NULL/text, integer -7/blob, observed IEEE bits 0.1/-0.0.
    val bytes=Files.readAllBytes(java.nio.file.Paths.get("tests/sources/import/fixtures/rows-v1.bin"))
    val c=prepare(bytes,m);val c2=prepare(bytes,m)
    require(c.id==c2.id && c.payloadId==c2.payloadId,"reproducible candidate")
    bytes(0)=0;require(c.bytes(0)==83,"candidate owns original bytes")
    val stolen=c.bytes;stolen(0)=0;require(c.bytes(0)==83,"read cannot mutate candidate")
    require(c.derivedRetention==Retention.Private,"private origin propagates")
    val repoll=prepare(c.bytes,m.copy(acquisition=m.acquisition.copy(receipt=receipt.copy(ticks=1000))))
    require(repoll.payloadId==c.payloadId && repoll.id!=c.id,"poll manifest identity distinct from source payload")
    require(repoll.manifest.acquisition.event==Some(event),"repoll cannot refresh event")
    val mixed=prepare(c.bytes,m.copy(units=Some("Fahrenheit"),acquisition=m.acquisition.copy(configuration="Fahrenheit-v2")))
    require(c.manifest.units==Some("Celsius") && mixed.id!=c.id,"old config immutable")
    val dir=Files.createTempDirectory("veri7vn-source-import-");val input=dir.resolve("recorded.bin")
    try {
      Files.write(input,c.bytes);require(acquire(input,m).id==c.id,"bounded local acquisition")
      var rejected=false;try acquire(input,m,Limits(maxBytes=2)) catch {case _:IllegalArgumentException=>rejected=true}
      require(rejected,"byte bound")
      val link=dir.resolve("link");Files.createSymbolicLink(link,input)
      rejected=false;try acquire(link,m) catch {case _:IllegalArgumentException=>rejected=true}
      require(rejected,"symlink input rejected")
      Files.delete(link)
      // Candidate payload is inert even when malformed. Only native decoder can license rows.
      val malformed=prepare(Array[Byte](83,49,1,2,1,3,12,7),m)
      require(malformed.bytes.length==8,"malformed original retained without invented decoded rows")
      Files.write(dir.resolve("native-fixture.bin"),c.bytes)
      Files.delete(dir.resolve("native-fixture.bin"))
    } finally {Files.deleteIfExists(input);Files.delete(dir)}
    require(unavailableOriginals.map(_.source).toSet==Set("relations_v2","names","labels-aliases"))
    val unknown=prepare(c.bytes,m.copy(acquisition=m.acquisition.copy(origin=Origin.Unknown)))
    require(unknown.manifest.acquisition.origin==Origin.Unknown,"unknown origin is not promoted")
    unknown.release()
    c.release();require(!c.isLive,"release clears candidate roots")
    var stale=false;try c.bytes catch {case _:IllegalStateException=>stale=true}
    require(stale,"released candidate cannot materialize bytes")
    stale=false;try c.manifest catch {case _:IllegalStateException=>stale=true}
    require(stale,"released candidate cannot materialize private manifest")
    c2.release();repoll.release();mixed.release()
    println("VERI7VN_SOURCE_IMPORT acquisition PASS")
  }
}
