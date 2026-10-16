package veri7vn.packages.lifecycle

import isabelle.{Outer_Syntax,Command_Span}
import veri7vn.packages.intake.Intake
import Intake.{Content,Edit}

/** Lexical source ownership using the actual Isabelle outer-syntax tokenizer.
  * syntax must come from the selected native image/context, not an author-supplied keyword list.
  * Native command elaboration/admission still checks the term and its meaning.
  */
object SourceProjection {
  private val recipes=Set("v7_math_formula","v7_reader_query")
  final case class Span(command:String,startByte:Int,endByte:Int,original:Content)
  private def decode(content:Content):String=java.nio.charset.StandardCharsets.UTF_8.newDecoder()
    .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
    .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
    .decode(java.nio.ByteBuffer.wrap(content.bytes)).toString
  def spans(content:Content,syntax:Outer_Syntax):Vector[Span]={
    require(content.size<=8*1024*1024,"Source projection limit")
    val text=decode(content);val parsed=syntax.parse_spans(text)
    require(parsed.flatMap(_.content).map(_.source).mkString==text,"Tokenizer did not preserve exact source")
    var offset=0
    parsed.flatMap { span=>
      val raw=span.content.map(_.source).mkString.getBytes(java.nio.charset.StandardCharsets.UTF_8)
      val start=offset;offset+=raw.length
      span.kind match {
        case Command_Span.Command_Span(_,name,_) if recipes(name)=>Some(Span(name,start,offset,Content(raw)))
        case _=>None
      }
    }.toVector
  }
  def edit(path:String,source:Content,selected:Span,replacement:Content,syntax:Outer_Syntax):Edit={
    val actual=spans(source,syntax).find(s=>s.startByte==selected.startByte && s.endByte==selected.endByte)
      .getOrElse(throw new IllegalArgumentException("Recipe source span unavailable"))
    require(actual.command==selected.command && actual.original.sha256==selected.original.sha256,"Recipe projection stale")
    val parsed=syntax.parse_spans(decode(replacement))
    val commands=parsed.collect{case s if s.kind.isInstanceOf[Command_Span.Command_Span]=>s.kind.asInstanceOf[Command_Span.Command_Span].name}
    require(commands==List(actual.command) && !parsed.exists(_.kind==Command_Span.Malformed_Span),"Form patch must contain one same-family command")
    Edit(path,actual.startByte,actual.endByte,actual.original,replacement)
  }
}
