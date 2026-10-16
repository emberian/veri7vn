package veri7vn.diagnostics

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import isabelle.{XML,Markup,YXML}

/** Native build metadata only. The host separately joins these native IDs to
  * its same governed captured input before revealing source or preparing edits. */
object BuildFailure {
  enum Phase { case Replay, Export }
  enum Message { case Text(value:String); case Unavailable }
  final case class Span(startByte:Int,endByte:Int)
  final case class Failure(sourceRevision:BigInt,manifest:BigInt,phase:Phase,
    span:Option[Span],message:Message) {
    def code:String=phase match {
      case Phase.Replay=>"build.replay_failed"
      case Phase.Export=>"build.export_failed"
    }
    def title:String=phase match {
      case Phase.Replay=>"Native source replay failed"
      case Phase.Export=>"Native export failed"
    }
  }
  private def attrs(properties:List[(String,String)],keys:Set[String]):Map[String,String]={
    require(properties.size==keys.size && properties.map(_._1).toSet==keys,"Build diagnostic attributes")
    properties.toMap
  }
  private def id(value:String):BigInt={
    require(value.matches("[1-9][0-9]{0,127}"),"Build diagnostic native identity");BigInt(value)
  }
  private def offset(value:String):Int={
    require(value.matches("0|[1-9][0-9]{0,9}"),"Build diagnostic byte offset")
    val n=value.toLong;require(n<=Int.MaxValue,"Build diagnostic byte offset bound");n.toInt
  }
  def parse(frame:String,expectedSourceRevision:BigInt,expectedManifest:BigInt):Failure={
    require(frame.length<=8192 && frame.getBytes(UTF_8).length<=8192,"Build diagnostic frame exceeds byte bound")
    val (properties,body)=YXML.parse_body(YXML.Source(frame)) match {
      case List(XML.Elem(Markup("veri7vn-build-failure",p),children))=>(p,children)
      case _=>throw new IllegalArgumentException("Build diagnostic root")
    }
    val a=attrs(properties,Set("version","phase","source_revision","manifest"))
    require(a("version")=="1","Build diagnostic version")
    val phase=a("phase") match {
      case "replay"=>Phase.Replay
      case "export"=>Phase.Export
      case _=>throw new IllegalArgumentException("Build diagnostic phase")
    }
    val source=id(a("source_revision"));val manifest=id(a("manifest"))
    require(source==expectedSourceRevision && manifest==expectedManifest,"Build diagnostic source association mismatch")
    require(body.length==2,"Build diagnostic child count")
    val span=body.head match {
      case XML.Elem(Markup("span",p),Nil)=>
        val s=attrs(p,Set("start","stop"));val start=offset(s("start"));val stop=offset(s("stop"))
        require(start<=stop,"Build diagnostic reversed source span");Some(Span(start,stop))
      case XML.Elem(Markup("span-unavailable",p),Nil)=>
        require(attrs(p,Set("reason"))("reason")=="not_reported","Build diagnostic span absence");None
      case _=>throw new IllegalArgumentException("Build diagnostic source span")
    }
    val message=body(1) match {
      case XML.Elem(Markup("message",Nil),text)=>
        require(text.forall(_.isInstanceOf[XML.Text]),"Build diagnostic message must be text")
        val value=text.map{case XML.Text(t)=>t;case _=>""}.mkString
        require(value.getBytes(UTF_8).length<=4096,"Build diagnostic message exceeds byte bound")
        Message.Text(value)
      case XML.Elem(Markup("message-unavailable",p),Nil)=>
        require(attrs(p,Set("reason"))("reason")=="exceeds_bound","Build diagnostic message absence")
        Message.Unavailable
      case _=>throw new IllegalArgumentException("Build diagnostic message")
    }
    Failure(source,manifest,phase,span,message)
  }
}
