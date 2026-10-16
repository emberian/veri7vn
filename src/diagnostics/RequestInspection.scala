package veri7vn.diagnostics

import isabelle.{XML,Markup,YXML}

/** Closed owner inspection frame. Metadata describes an authentic resident
  * request, not a portable proof or permission to execute it. No source payloads. */
object RequestInspection {
  final case class Span(startByte:Int,endByte:Int)
  enum Operation { case Sum, Difference, Product, Quotient, SubtractFrom }
  final case class Reading(index:Int,operation:Operation,inputBytes:Int,literals:Vector[Span]) {
    def description:String=operation match {
      case Operation.Sum=>"Add the two captured integers."
      case Operation.Difference=>"Subtract the second captured integer from the first."
      case Operation.Product=>"Multiply the two captured integers."
      case Operation.Quotient=>"Divide the first captured integer by the second."
      case Operation.SubtractFrom=>"Subtract the first captured integer from the second."
    }
  }
  final case class Identity(request:BigInt,goal:BigInt,interpretation:BigInt,decision:BigInt,
    capability:BigInt,operation:BigInt,semanticGeneration:BigInt,executableGeneration:BigInt,execution:BigInt)
  final case class Inspection(identity:Identity,status:String,reading:Option[Reading],
    readingUnavailable:Option[String]) {
    def explanation:Diagnostics.Explanation=Diagnostics.explain(status)
    def provenance:Vector[(String,String)]=Vector("Request"->identity.request.toString,
      "Goal"->identity.goal.toString,"Interpretation"->identity.interpretation.toString,
      "Selection decision"->identity.decision.toString,"Capability"->identity.capability.toString,
      "Operation"->identity.operation.toString,"Semantic generation"->identity.semanticGeneration.toString,
      "Executable generation"->identity.executableGeneration.toString,"Execution"->identity.execution.toString)
  }
  private val identityKeys=Set("request","goal","interpretation","decision","capability","operation",
    "semantic_generation","executable_generation","execution")
  private val statuses=Set("pending","accepted_exact","undefined","missing_parameters","invalid_syntax",
    "budget","cancelled","execution.failure","execution.handoff_rejected")
  private def attributes(properties:List[(String,String)],keys:Set[String]):Map[String,String]={
    require(properties.size==keys.size && properties.map(_._1).toSet==keys,"Inspection attributes differ from v1 schema")
    properties.toMap
  }
  private def natural(value:String,max:Int):Int={
    require(value.matches("0|[1-9][0-9]{0,8}"),"Inspection natural number")
    val number=value.toInt;require(number<=max,"Inspection numeric bound");number
  }
  private def identity(value:String):BigInt={
    require(value.matches("[1-9][0-9]{0,127}"),"Inspection identity");BigInt(value)
  }
  def parse(frame:String,expectedRequest:BigInt):Inspection={
    require(frame.length<=8192,"Inspection frame exceeds bound")
    val root=YXML.parse_body(YXML.Source(frame)) match {
      case List(XML.Elem(Markup("veri7vn-request-inspection",properties),body))=>
        val attrs=attributes(properties,Set("version","status","family"));require(attrs("version")=="1" && attrs("family")=="mathematics" && statuses(attrs("status")),"Inspection version/status")
        (attrs("status"),body)
      case _=>throw new IllegalArgumentException("Inspection root")
    }
    val (ids,reading,unavailable)=root._2 match {
      case List(XML.Elem(Markup("identity",properties),Nil),XML.Elem(Markup("reading",rp),spans))=>
        val attrs=attributes(rp,Set("index","operation","input_bytes"))
        val operation=attrs("operation") match {
          case "sum"=>Operation.Sum
          case "difference"=>Operation.Difference
          case "product"=>Operation.Product
          case "quotient"=>Operation.Quotient
          case "subtract_from"=>Operation.SubtractFrom
          case _=>throw new IllegalArgumentException("Inspection operation")
        }
        val length=natural(attrs("input_bytes"),256)
        require(spans.size==2,"Inspection binary literal arity")
        val literals=spans.map {
          case XML.Elem(Markup("literal",p),Nil)=>
            val a=attributes(p,Set("start","stop"));val start=natural(a("start"),length);val stop=natural(a("stop"),length)
            require(start<stop,"Inspection literal span");Span(start,stop)
          case _=>throw new IllegalArgumentException("Inspection literal")
        }.toVector
        require(literals.head.endByte<=literals(1).startByte,"Inspection literal order")
        (properties,Some(Reading(natural(attrs("index"),255),operation,length,literals)),None)
      case List(XML.Elem(Markup("identity",properties),Nil),XML.Elem(Markup("reading-unavailable",p),Nil))=>
        val attrs=attributes(p,Set("reason"));require(Set("released","not_retained","invalidated")(attrs("reason")),"Inspection unavailable reason")
        (properties,None,Some(attrs("reason")))
      case _=>throw new IllegalArgumentException("Inspection body")
    }
    val a=attributes(ids,identityKeys)
    val result=Identity(identity(a("request")),identity(a("goal")),identity(a("interpretation")),identity(a("decision")),
      identity(a("capability")),identity(a("operation")),identity(a("semantic_generation")),identity(a("executable_generation")),identity(a("execution")))
    require(result.request==expectedRequest,"Inspection request mismatch")
    Inspection(result,root._1,reading,unavailable)
  }
}
