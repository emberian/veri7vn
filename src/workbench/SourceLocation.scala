package veri7vn.workbench

import veri7vn.packages.intake.Intake
import java.nio.ByteBuffer
import java.nio.charset.{StandardCharsets,CodingErrorAction}

/** Presentation only: native diagnostics supply exact original byte offsets.
  * A current editor is highlighted only when its revision matches the build input.
  */
object SourceLocation {
  final case class Location(path:String,revision:String,startByte:Int,endByte:Int,
    line:Int,column:Int,current:Boolean)
  def locate(build:Authoring.Snapshot,path:String,start:Int,stop:Int,currentRevision:String):Location={
    val source=build.revision.entries.find(_.path==path)
      .getOrElse(throw new IllegalArgumentException("Diagnostic source is outside the captured revision"))
    require(start>=0 && stop>=start && stop<=source.content.size,"Diagnostic byte span is outside captured source")
    val bytes=source.content.bytes
    def decode(end:Int)=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
      .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes,0,end)).toString
    val prefix=decode(start);decode(stop)
    val line=prefix.count(_=='\n')+1
    val tail=prefix.substring(prefix.lastIndexOf('\n')+1)
    Location(path,build.revision.id,start,stop,line,tail.codePointCount(0,tail.length)+1,
      currentRevision==build.revision.id)
  }
}
