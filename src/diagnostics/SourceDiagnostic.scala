package veri7vn.diagnostics

import scala.language.unsafeNulls
import java.nio.{ByteBuffer,CharBuffer}
import java.nio.charset.{StandardCharsets,CodingErrorAction}
import java.security.MessageDigest
import veri7vn.packages.native_build.NativeBuildInputs.CapturedSource

/** Pure presentation inside a governed retained-source callback. No buffer or
  * source text escapes. Native association checks belong to the host producer. */
object SourceDiagnostic {
  enum SourceStatus { case Current, Historical, Unknown }
  final case class Head(manifest:String,revision:String)
  final case class Position(line:Int,column:Int)
  final case class Location(startByte:Int,endByte:Int,start:Position,end:Position)
  final case class View(source:CapturedSource,status:SourceStatus,failure:BuildFailure.Failure,
    location:Option[Location]) {
    /** UI seeding only. Applying a proposal still checks its original draft head. */
    def hasCurrentSpan:Boolean=status==SourceStatus.Current && location.nonEmpty
    def description:String={
      val age=status match {
        case SourceStatus.Current=>"Current captured source"
        case SourceStatus.Historical=>"Historical captured source; the editor has a different revision"
        case SourceStatus.Unknown=>"Captured source; current editor revision not inspected"
      }
      val where=location.map(l=>s"${source.path}:${l.start.line}:${l.start.column} (original bytes ${l.startByte}–${l.endByte})")
        .getOrElse(source.path+" (native source position not reported)")
      age+". "+where
    }
  }
  def locate(source:CapturedSource,borrowed:ByteBuffer,failure:BuildFailure.Failure,
    current:Option[Head]):View={
    val original=borrowed.asReadOnlyBuffer().slice().asReadOnlyBuffer()
    require(original.remaining().toLong==source.pin.size && source.pin.size<=8L*1024*1024,
      "Diagnostic bytes differ from captured source size")
    val digest=MessageDigest.getInstance("SHA-256")
    digest.update(original.asReadOnlyBuffer())
    require(java.util.HexFormat.of().formatHex(digest.digest())==source.pin.sha256,
      "Diagnostic bytes differ from captured source pin")
    def position(end:Int):Position={
      val prefix=original.asReadOnlyBuffer();prefix.limit(end)
      val decoder=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT)
      val chars=CharBuffer.allocate(1024)
      var line=1;var column=1;var previousHigh=false
      def consume():Unit={
        chars.flip()
        while(chars.hasRemaining()){
          val c=chars.get()
          if(c=='\n'){line+=1;column=1;previousHigh=false}
          else if(Character.isLowSurrogate(c) && previousHigh)previousHigh=false
          else {column+=1;previousHigh=Character.isHighSurrogate(c)}
        }
        chars.clear()
      }
      try {
        var decoding=true
        while(decoding){
          val result=decoder.decode(prefix,chars,true);consume()
          if(result.isError)result.throwException()
          decoding=result.isOverflow
        }
        var flushing=true
        while(flushing){
          val result=decoder.flush(chars);consume()
          if(result.isError)result.throwException()
          flushing=result.isOverflow
        }
        Position(line,column)
      }finally java.util.Arrays.fill(chars.array(),0.toChar)
    }
    val location=failure.span.map {span=>
      require(span.startByte>=0 && span.endByte>=span.startByte && span.endByte<=original.remaining(),
        "Native diagnostic span is outside original captured source")
      Location(span.startByte,span.endByte,position(span.startByte),position(span.endByte))
    }
    val status=current match {
      case Some(head) if head.manifest==source.manifest && head.revision==source.revision=>SourceStatus.Current
      case Some(_)=>SourceStatus.Historical
      case None=>SourceStatus.Unknown
    }
    View(source,status,failure,location)
  }
}
