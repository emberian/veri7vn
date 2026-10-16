package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import isabelle.{Bytes,Markup,XML,YXML}

/** Tentative source for explicit review, never activation or checked meaning. */
final case class GrowthSuggestion(operations:Vector[String],source:String,unsupported:Vector[String])
private[service] object GrowthSuggestionProtocol {
  private val operations=Set("square","double","increment","absolute","negate")
  private val unsupported=Set("sort","descending","reverse","unique","duplicate","even","odd","positive","negative",
    "sum","count","maximum","minimum","average","mean","join","string","word","list")
  def read(reply:ResidentSupervisor.Reply):GrowthSuggestion={
    require(reply.tag=="growth_suggestion" && reply.payload=="numeric/1" && reply.artifacts.size==1 &&
      reply.artifacts.head.size<=32768,"native growth suggestion reply")
    val frame=reply.artifacts.head.text
    require(Bytes(frame)==reply.artifacts.head,"native growth suggestion UTF8")
    val body=YXML.parse_body(YXML.Source(frame)) match {
      case List(XML.Elem(Markup("growth-suggestion",attrs),children))=>
        require(attrs.size==3 && attrs.map(_._1).toSet==Set("version","profile","status"),"native growth suggestion fields")
        val a=attrs.toMap;require(a("version")=="1" && a("profile")=="numeric/1" && a("status")=="tentative","native growth suggestion profile")
        children
      case _=>throw new IllegalArgumentException("native growth suggestion root")
    }
    def text(children:List[XML.Tree]):String=children.map {
      case XML.Text(value)=>value
      case _=>throw new IllegalArgumentException("native growth suggestion text structure")
    }.mkString
    def words(children:List[XML.Tree],tag:String,allowed:Set[String],max:Int):Vector[String]={
      require(children.size<=max,"native growth suggestion word bound")
      val values=children.map {
        case XML.Elem(Markup(name,Nil),content) if name==tag=>
          val value=text(content);require(allowed.contains(value),"native growth suggestion word");value
        case _=>throw new IllegalArgumentException("native growth suggestion word structure")
      }.toVector
      require(values.distinct.size==values.size,"native growth duplicate word");values
    }
    body match {
      case List(XML.Elem(Markup("operations",Nil),ops),XML.Elem(Markup("source",Nil),source),
          XML.Elem(Markup("unsupported",Nil),blocked))=>
        val result=GrowthSuggestion(words(ops,"operation",operations,5),text(source),words(blocked,"word",unsupported,21))
        require(result.source.getBytes(UTF_8).length<=8192,"native growth source bound")
        require(if(result.operations.isEmpty || result.unsupported.nonEmpty)result.source.isEmpty else result.source.nonEmpty,
          "native growth source disposition")
        result
      case _=>throw new IllegalArgumentException("native growth suggestion child order")
    }
  }
}
