package veri7vn.diagnostics

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.packages.native_build.NativeBuildInputs.{CapturedSource,Pin}
import veri7vn.packages.intake.Intake

object SourceDiagnosticTests {
  def run():Unit={
    val bytes="(* λ 🦉 *)\nlemma broken: False\n".getBytes(UTF_8)
    val source=CapturedSource("demo","original-revision","original-manifest","Demo.thy",Pin(Intake.hash(bytes),bytes.length.toLong))
    val start="(* λ 🦉 *)\nlemma ".getBytes(UTF_8).length
    val failure=BuildFailure.Failure(BigInt(1),BigInt(2),BuildFailure.Phase.Replay,
      Some(BuildFailure.Span(start,start+6)),BuildFailure.Message.Text("Unresolved proof"))
    val buffer=ByteBuffer.wrap(bytes).asReadOnlyBuffer()
    val historical=SourceDiagnostic.locate(source,buffer,failure,Some(SourceDiagnostic.Head("new-manifest","new-revision")))
    assert(historical.status==SourceDiagnostic.SourceStatus.Historical)
    assert(!historical.hasCurrentSpan)
    assert(historical.location.get.start==SourceDiagnostic.Position(2,7))
    assert(historical.location.get.end==SourceDiagnostic.Position(2,13))
    assert(buffer.position()==0 && historical.source==source)
    val current=SourceDiagnostic.locate(source,buffer,failure,Some(SourceDiagnostic.Head(source.manifest,source.revision)))
    assert(current.status==SourceDiagnostic.SourceStatus.Current && current.hasCurrentSpan)
    val withoutSpan=SourceDiagnostic.locate(source,buffer,failure.copy(span=None),Some(SourceDiagnostic.Head(source.manifest,source.revision)))
    assert(withoutSpan.location.isEmpty && !withoutSpan.hasCurrentSpan)
    def rejects(body: => Any):Unit={var rejected=false;try body catch{case _:Exception=>rejected=true};assert(rejected)}
    rejects(SourceDiagnostic.locate(source,buffer,failure.copy(span=Some(BuildFailure.Span(4,5))),None)) // inside λ
    rejects(SourceDiagnostic.locate(source,buffer,failure.copy(span=Some(BuildFailure.Span(0,bytes.length+1))),None))
    val replaced=bytes.clone();replaced(0)='!'.toByte
    rejects(SourceDiagnostic.locate(source,ByteBuffer.wrap(replaced),failure,None))
    val chunked=("a"*1023+"🦉b").getBytes(UTF_8)
    val chunkedSource=source.copy(pin=Pin(Intake.hash(chunked),chunked.length.toLong))
    val eof=failure.copy(span=Some(BuildFailure.Span(chunked.length,chunked.length)))
    assert(SourceDiagnostic.locate(chunkedSource,ByteBuffer.wrap(chunked),eof,None).location.get.start==SourceDiagnostic.Position(1,1026))
    println("SOURCE_DIAGNOSTIC_PASS exact captured pin historical/current Unicode physical spans no retained buffer; host association producer unchecked")
  }
}
