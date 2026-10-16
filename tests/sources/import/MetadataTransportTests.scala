package veri7vn.sources
import scala.language.unsafeNulls
import java.nio.file.{Files,Paths}
object MetadataTransportTests {
  import LocalSnapshot.*
  def main(args:Array[String]):Unit={
    val m=Manifest("fixture-sensor",None,"source-row/1","UTF-8","ordered rows","source-row-codec/1",
      Some("CC0 fixture"),None,Vector("source-scoped","caf\u00e9"),Some("preferred"),Some("Celsius"),
      Vector("fixture:local"),Vector("upstream unknown"),
      Acquisition(Some(Clock("source-event","sensor-origin",-10)),Clock("wall","UTC",100),None,
        BigInt(4),"Celsius-v1",None,"retain-rejected",Origin.Unknown),Retention.Private)
    val raw=Files.readAllBytes(Paths.get("tests/sources/import/fixtures/rows-v1.bin"))
    val c=prepare(raw,m)
    require(c.manifestBytes.sameElements(Files.readAllBytes(Paths.get("tests/sources/import/fixtures/manifest-v2.bin"))),
      "Scala acquisition record differs from native-consumed fixture")
    require(c.manifest.provenance.isEmpty && c.manifest.acquisition.origin==Origin.Unknown)
    var rejected=false
    try prepare(raw,m.copy(source="invalid-\ud800")) catch {case _:java.nio.charset.CharacterCodingException=>rejected=true}
    require(rejected,"malformed UTF-16 cannot silently become replacement UTF-8")
    c.release()
    println("VERI7VN_SOURCE_METADATA Scala regressions PASS")
  }
}
