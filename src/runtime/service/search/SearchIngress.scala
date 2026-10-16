package veri7vn.runtime.service.search

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.nio.charset.{CodingErrorAction,StandardCharsets}
import isabelle.{Bytes,Markup,XML,YXML}
import veri7vn.runtime.service.{ResidentSupervisor,ResidentAuthorityService}

object SearchIngress {
  enum Action {
    case Retrieve,Split,Introduce,Assume
    case Apply(index:Int)
    case Simplify(indices:Vector[Int])
  }
  final case class Budget(expansions:Int,frontier:Int,successors:Int,milliseconds:Int) {
    require(expansions>0 && expansions<=10000,"Search expansion bound")
    require(frontier>0 && frontier<=1000,"Search frontier bound")
    require(successors>0 && successors<=16,"Search successor bound")
    require(milliseconds>0 && milliseconds<=30000,"Search time bound")
  }
  final class Context private[SearchIngress](private[SearchIngress] val owner:SearchIngress,
    val id:BigInt,val semantic:BigInt,val label:String)
  final class Request private[SearchIngress](private[SearchIngress] val owner:SearchIngress,
    val request:BigInt,val goal:BigInt,val slot:BigInt,val context:BigInt,val semantic:BigInt)
  final case class Step(index:Int,action:String,route:String,subgoals:Vector[String])
  final case class Progress(expansions:Int,trace:Vector[Step],traceTotal:Int,remaining:Vector[Vector[String]],
    remainingTotal:Int,detailsTruncated:Boolean) {
    def traceTruncated:Boolean=trace.size<traceTotal
    def remainingTruncated:Boolean=remaining.size<remainingTotal
  }
  /** These are read-only native projections, never serialized native theorems.
    * Proved is emitted only for an already licensed binding in current authority. */
  sealed trait Result
  case object Pending extends Result
  final case class Proved(proposition:String,evidence:BigInt,semantic:BigInt,proofSemantic:BigInt,
    dependencies:Vector[BigInt],progress:Progress) extends Result
  /** A retained native theorem under current source/history access. It grants
    * no active request, execution ticket, or current result binding. */
  final case class Historical(proof:Proved) extends Result
  enum Stop { case Exhausted,Budget,Deadline,Cancelled,Failed,Unavailable }
  final case class Unresolved(reason:Stop,diagnostic:String,progress:Progress) extends Result

  private[service] trait Transport {
    def exchange(operation:String,payload:String="",artifacts:List[Bytes]=Nil):ResidentSupervisor.Reply
  }
  private val utf8=StandardCharsets.UTF_8
  private def text(bytes:Array[Byte]):String=utf8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
    .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString
  private def safe(value:String,bound:Int):String={
    require(value.length<=bound && !value.exists(c=>c=='\u0005' || c=='\u0006'),"Search XML text bound/control")
    value
  }
  private def id(value:String):BigInt={
    require(value.matches("[1-9][0-9]{0,127}"),"Search native identity encoding");BigInt(value)
  }
  private def number(value:String,max:Int):Int={
    require(value.matches("0|[1-9][0-9]{0,8}"),"Search bounded integer encoding")
    val n=value.toInt;require(n<=max,"Search integer bound");n
  }
  private def attrs(raw:List[(String,String)],keys:Set[String]):Map[String,String]={
    require(raw.map(_._1).distinct.size==raw.size && raw.map(_._1).toSet==keys,"Search response attributes")
    raw.toMap
  }
  private def plain(body:XML.Body,bound:Int):String=body match {
    case Nil=>""
    case List(XML.Text(value))=>safe(value,bound)
    case _=>throw new IllegalArgumentException("Search plain text expected")
  }
  private def parse(body:String):XML.Tree={
    require(body.getBytes(utf8).length<=1048576,"Search response byte bound")
    YXML.parse_body(YXML.Source(body)) match {
      case List(tree)=>tree
      case _=>throw new IllegalArgumentException("Search response root")
    }
  }
  private def actionTree(action:Action,catalogueSize:Int):XML.Tree={
    def index(i:Int):Unit=require(i>=0 && i<catalogueSize,"Search fact index")
    val (kind,indices)=action match {
      case Action.Retrieve=>("retrieve",Vector.empty)
      case Action.Split=>("split",Vector.empty)
      case Action.Introduce=>("introduce",Vector.empty)
      case Action.Assume=>("assume",Vector.empty)
      case Action.Apply(i)=>index(i);("apply",Vector(i))
      case Action.Simplify(is)=>require(is.size<=128,"Search simplification bound");is.foreach(index);("simplify",is)
    }
    XML.Elem(Markup("action",List("kind"->kind,"indices"->indices.mkString(","))),Nil)
  }
  /** One inert packet; the native receiver reparses the original bytes in the
    * selected actual P context and resolves managed catalogue owners itself. */
  private[service] def encode(context:BigInt,original:Array[Byte],budget:Budget,
    actions:Vector[Action],catalogue:Vector[String]):Array[Byte]={
    require(context>0 && context.toString.length<=128,"Search context identity")
    require(original.nonEmpty && original.length<=65536,"Search proposition byte bound")
    safe(text(original),65536) // strict UTF-8; retain the original bytes below
    require(actions.nonEmpty && actions.size<=64 && catalogue.size<=128,"Search policy bound")
    catalogue.foreach(name=>require(safe(name,512).nonEmpty && name.getBytes(utf8).length<=512,"Search catalogue name"))
    val fields=List("version"->"1","context"->context.toString,"expansions"->budget.expansions.toString,
      "frontier"->budget.frontier.toString,"successors"->budget.successors.toString,"milliseconds"->budget.milliseconds.toString)
    val body=List(XML.Elem(Markup("search-policy",fields),List(
      XML.Elem(Markup("catalogue",Nil),catalogue.toList.map(name=>XML.Elem(Markup("fact",Nil),List(XML.Text(name))))),
      XML.Elem(Markup("actions",Nil),actions.toList.map(actionTree(_,catalogue.size))))))
    val header=YXML.string_of_body(body).getBytes(utf8)
    require(header.length<=131072,"Search policy byte bound")
    val prefix=f"${header.length}%08d\n".getBytes(StandardCharsets.US_ASCII)
    val out=new Array[Byte](prefix.length+header.length+original.length)
    System.arraycopy(prefix,0,out,0,prefix.length)
    System.arraycopy(header,0,out,prefix.length,header.length)
    System.arraycopy(original,0,out,prefix.length+header.length,original.length)
    out
  }
  private[service] def decodeResult(wire:String,request:Request):Result=parse(wire) match {
    case XML.Elem(Markup("search-result",raw),body)=>
      val a=attrs(raw,Set("version","request","goal","slot","status"))
      require(a("version")=="1" && id(a("request"))==request.request && id(a("goal"))==request.goal &&
        id(a("slot"))==request.slot,"Search result child mismatch")
      if(a("status")=="pending") {require(body.isEmpty,"Pending search payload");Pending}
      else {
        require(body.size==2,"Search result sections")
        val progress=body(1) match {
          case XML.Elem(Markup("progress",raw),List(XML.Elem(Markup("trace",Nil),steps),XML.Elem(Markup("remaining",Nil),states)))=>
            val p=attrs(raw,Set("expansions","trace_total","remaining_total","details_truncated"))
            require(steps.size<=256 && states.size<=64,"Search progress projection bound")
            val trace=steps.toVector.map {
              case XML.Elem(Markup("step",raw),goals)=>
                val s=attrs(raw,Set("index","action","route"))
                require(Set("retrieve","apply","simplify","split","introduce","assume").contains(s("action")) &&
                  Set("advanced","failed","blocked","timed_out").contains(s("route")),"Search trace variant")
                require(goals.size<=32,"Search trace subgoal bound")
                Step(number(s("index"),10000),s("action"),s("route"),goals.toVector.map {
                  case XML.Elem(Markup("subgoal",Nil),text)=>plain(text,2048)
                  case _=>throw new IllegalArgumentException("Search trace subgoal")
                })
              case _=>throw new IllegalArgumentException("Search trace step")
            }
            val remaining=states.toVector.map {
              case XML.Elem(Markup("state",Nil),goals)=>
                require(goals.size<=32,"Search remaining subgoal bound")
                goals.toVector.map {
                  case XML.Elem(Markup("subgoal",Nil),text)=>plain(text,2048)
                  case _=>throw new IllegalArgumentException("Search remaining subgoal")
                }
              case _=>throw new IllegalArgumentException("Search remaining state")
            }
            val total=number(p("trace_total"),10000);val remainingTotal=number(p("remaining_total"),1000)
            require(trace.size<=total && remaining.size<=remainingTotal,"Search projection totals")
            require(Set("true","false").contains(p("details_truncated")),"Search detail truncation encoding")
            Progress(number(p("expansions"),10000),trace,total,remaining,remainingTotal,p("details_truncated")=="true")
          case _=>throw new IllegalArgumentException("Search progress")
        }
        if(a("status")=="proved" || a("status")=="historical_proved")body.head match {
          case XML.Elem(Markup("proof",raw),List(XML.Elem(Markup("proposition",Nil),proposition),XML.Elem(Markup("dependencies",Nil),deps)))=>
            val p=attrs(raw,Set("evidence","semantic","proof_semantic","route"))
            require(p("route")=="kernel_consequence" && deps.size<=1024,"Search proof projection route/dependency bound")
            val dependencies=deps.toVector.map {
              case XML.Elem(Markup("dependency",raw),Nil)=>id(attrs(raw,Set("id"))("id"))
              case _=>throw new IllegalArgumentException("Search dependency projection")
            }
            require(dependencies.distinct==dependencies,"Search duplicate dependencies")
            val semantic=id(p("semantic"));val proofSemantic=id(p("proof_semantic"))
            require(semantic==request.semantic && semantic!=proofSemantic && dependencies.contains(semantic) && dependencies.contains(proofSemantic),
              "Search original receiver/proof provenance missing or merged")
            val proof=Proved(plain(proposition,65536),id(p("evidence")),semantic,proofSemantic,dependencies,progress)
            if(a("status")=="historical_proved")Historical(proof) else proof
          case _=>throw new IllegalArgumentException("Search proof projection")
        } else {
          val reason=a("status") match {
            case "exhausted"=>Stop.Exhausted
            case "budget"=>Stop.Budget
            case "deadline"=>Stop.Deadline
            case "cancelled"=>Stop.Cancelled
            case "failed"=>Stop.Failed
            case "unavailable"=>Stop.Unavailable
            case _=>throw new IllegalArgumentException("Unknown search outcome")
          }
          body.head match {
            case XML.Elem(Markup("diagnostic",Nil),message)=>Unresolved(reason,plain(message,2048),progress)
            case _=>throw new IllegalArgumentException("Search unresolved diagnostic")
          }
        }
      }
    case _=>throw new IllegalArgumentException("Search result root")
  }
}

/** Finite resident search client. It owns neither a scheduler nor admission;
  * every operation goes through the existing resident authority and event pump. */
final class SearchIngress private[service](transport:SearchIngress.Transport,
  available:()=>Unit,cancelParent:BigInt=>Unit) {
  import SearchIngress.*
  private[service] def this(supervisor:ResidentSupervisor,client:ResidentAuthorityService)=this(
    new SearchIngress.Transport {
      def exchange(operation:String,payload:String,artifacts:List[Bytes]):ResidentSupervisor.Reply=
        supervisor.exchange(operation,payload,artifacts)
    },()=>(),request=>client.cancel(request))
  def contexts():Vector[Context]={
    available()
    val reply=transport.exchange("search_contexts")
    require(reply.tag=="search_contexts" && reply.payload=="1" && reply.artifacts.size==1,"Native search context response")
    parse(reply.artifacts.head.text) match {
      case XML.Elem(Markup("search-contexts",List(("version","1"))),children)=>
        require(children.size<=256,"Search context list bound")
        val contexts=children.toVector.map {
          case XML.Elem(Markup("context",raw),label)=>
            val a=attrs(raw,Set("id","semantic"))
            new Context(this,id(a("id")),id(a("semantic")),plain(label,512))
          case _=>throw new IllegalArgumentException("Search context projection")
        }
        require(contexts.map(_.id).distinct.size==contexts.size,"Search duplicate context")
        contexts
      case _=>throw new IllegalArgumentException("Search context list root")
    }
  }
  /** Reconnect uses actual currently retained native Search child associations.
    * Arbitrary persisted IDs cannot construct a handle. The native producer
    * intersects authority-required children with its exact typed associations. */
  def requests():Vector[Request]={
    available()
    val reply=transport.exchange("search_requests")
    require(reply.tag=="search_requests" && reply.payload=="1" && reply.artifacts.size==1,"Native retained search response")
    parse(reply.artifacts.head.text) match {
      case XML.Elem(Markup("search-requests",List(("version","1"))),children)=>
        require(children.size<=256,"Retained search request list bound")
        val values=children.toVector.map {
          case XML.Elem(Markup("request",raw),Nil)=>
            val a=attrs(raw,Set("id","goal","slot","context","semantic"))
            new Request(this,id(a("id")),id(a("goal")),id(a("slot")),id(a("context")),id(a("semantic")))
          case _=>throw new IllegalArgumentException("Retained search child projection")
        }
        require(values.map(r=>(r.request,r.goal,r.slot)).distinct.size==values.size,"Duplicate retained search child")
        values
      case _=>throw new IllegalArgumentException("Retained search request list root")
    }
  }
  def propose(context:Context,original:Array[Byte],budget:Budget,actions:Vector[Action],
    catalogue:Vector[String]=Vector.empty):Request={
    available();require(context.owner eq this,"Search context belongs to another resident")
    val owned=original.clone()
    val packet=try encode(context.id,owned,budget,actions,catalogue)
      finally java.util.Arrays.fill(owned,0.toByte)
    val reply=try transport.exchange("propose_search",artifacts=List(Bytes(packet)))
      finally java.util.Arrays.fill(packet,0.toByte)
    val fields=reply.payload.split(",",-1)
    require(reply.tag=="search_proposed" && fields.length==3 && reply.artifacts.isEmpty,"Native search proposal response")
    new Request(this,id(fields(0)),id(fields(1)),id(fields(2)),context.id,context.semantic)
  }
  def poll(request:Request):Result={
    available();require(request.owner eq this,"Search request belongs to another resident")
    val key=s"${request.request},${request.goal},${request.slot}"
    val reply=transport.exchange("poll_search",key)
    require(reply.tag=="search_result" && reply.payload==key && reply.artifacts.size==1,"Native search result response")
    decodeResult(reply.artifacts.head.text,request)
  }
  def cancel(request:Request):Unit={
    available();require(request.owner eq this,"Search request belongs to another resident")
    cancelParent(request.request)
  }
}
