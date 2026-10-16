package veri7vn.runtime.service

import scala.language.unsafeNulls
import isabelle.{Markup,XML,YXML}

final case class RoutingSpan(start:Int,stop:Int)
final case class RoutingAlternative(index:Int,operation:Int,literals:Vector[RoutingSpan])
final case class RoutingDetails(status:String,alternatives:Vector[RoutingAlternative],
  blockedLiterals:Vector[Vector[RoutingSpan]])

/** Read-only native reader projection; no request or selection is minted. */
private[service] object RoutingDetailsProtocol {
  def read(reply:ResidentSupervisor.Reply,original:Array[Byte]):RoutingDetails={
    require(original.length<=256 && reply.tag=="routing_details" && reply.payload=="math/1" &&
      reply.artifacts.size==1 && reply.artifacts.head.size<=8192,"native routing details reply")
    val frame=reply.artifacts.head.text
    require(frame.forall(c=>c==5 || c==6 || (c>=32 && c<=126)),"native routing details encoding")
    def attrs(values:List[(String,String)],keys:Set[String]):Map[String,String]={
      require(values.size==keys.size && values.map(_._1).toSet==keys,"native routing details fields");values.toMap
    }
    def number(s:String,max:Int):Int={
      require(s.matches("0|[1-9][0-9]{0,2}"),"native routing details number")
      val n=s.toInt;require(n<=max,"native routing details bound");n
    }
    val (root,children)=YXML.parse_body(YXML.Source(frame)) match {
      case List(XML.Elem(Markup("routing-details",a),body))=>(attrs(a,Set("version","status")),body)
      case _=>throw new IllegalArgumentException("native routing details root")
    }
    require(root("version")=="1" && Set("readings","literal","budget","unrecognized","structure_blocked").contains(root("status")),
      "native routing details status/version")
    require(children.size<=256,"native routing details candidate bound")
    var totalSpans=0
    def spans(body:List[XML.Tree]):Vector[RoutingSpan]={
      totalSpans+=body.size;require(totalSpans<=512,"native routing literal bound")
      body.map {
        case XML.Elem(Markup("literal",properties),Nil)=>
          val a=attrs(properties,Set("start","stop"))
          val start=number(a("start"),original.length);val stop=number(a("stop"),original.length)
          require(start<=stop,"native routing literal interval")
          RoutingSpan(start,stop)
        case _=>throw new IllegalArgumentException("native routing literal structure")
      }.toVector
    }
    val alternatives=Vector.newBuilder[RoutingAlternative]
    val blocked=Vector.newBuilder[Vector[RoutingSpan]]
    var nextIndex=0;var blockedSeen=false
    children.foreach {
      case XML.Elem(Markup("alternative",properties),body)=>
        require(!blockedSeen,"native routing candidate order")
        val a=attrs(properties,Set("index","operation"));val index=number(a("index"),255)
        require(index==nextIndex,"native routing candidate index");nextIndex+=1
        val literalSpans=spans(body);require(literalSpans.size==2,"native routing fixed binary arity")
        alternatives+=RoutingAlternative(index,number(a("operation"),4),literalSpans)
      case XML.Elem(Markup("blocked",Nil),body)=>blockedSeen=true;blocked+=spans(body)
      case _=>throw new IllegalArgumentException("native routing candidate structure")
    }
    val result=RoutingDetails(root("status"),alternatives.result(),blocked.result())
    require(result.status!="readings" || result.alternatives.nonEmpty,"native routing missing readings")
    require(result.status!="literal" || (result.alternatives.isEmpty && result.blockedLiterals.nonEmpty),"native routing missing blocked literal")
    require(result.status!="structure_blocked" || (result.alternatives.isEmpty && result.blockedLiterals.isEmpty),"native routing blocked structure")
    result
  }
}
