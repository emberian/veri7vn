package veri7vn.runtime.conversation

import isabelle.{Markup,XML,YXML}
import java.nio.charset.StandardCharsets.UTF_8
import scala.language.unsafeNulls

/** Inspection of the resident's existing session state. These values carry no
  * execution or admission authority. Every open is checked again by the native
  * owner; an old View cannot authorize a subsequent proposal or quotation. */
object ConversationProtocol {
  val maxFrameBytes=262144
  val maxTurns=128
  val maxParts=64
  enum Status { case Active, Expired, Unavailable }
  final case class Read(objectId:BigInt,version:BigInt)
  final case class Clock(kind:String,originHex:String,ticks:BigInt)
  final case class Observation(session:BigInt,version:BigInt,clock:Option[Clock],reads:Vector[Read])
  final case class Summary(id:BigInt,version:BigInt,status:Status,utterances:Int,adopted:Int)
  final case class Index(conversations:Vector[Summary],complete:Boolean)
  final case class Claim(claim:BigInt,target:BigInt,interpretation:BigInt,evidence:BigInt,
    semanticGeneration:BigInt,executableGeneration:Option[BigInt],route:String,kind:String,
    modality:String,collection:String,optimality:String,premises:Vector[BigInt],dependencies:Vector[BigInt])
  /** Quotation preserves the original observation, rather than claiming that a
    * previous request remains fresh after the session revision advances. */
  final case class Quotation(claim:Claim,observation:Observation,html:String)
  final case class Predecessor(kind:String,goal:BigInt)
  final case class Part(goal:BigInt,slot:BigInt,status:String,predecessors:Vector[Predecessor],quotation:Option[Quotation])
  final case class Turn(request:BigInt,utterance:BigInt,inputEncoding:String,inputHex:String,observation:Observation,parts:Vector[Part]) {
    def originalBytes:Array[Byte]=decodeHex(inputHex,256)
  }
  final case class View(id:BigInt,version:BigInt,status:Status,observation:Option[Observation],
    turns:Vector[Turn],complete:Boolean)

  private def attrs(values:List[(String,String)],keys:Set[String]):Map[String,String]={
    require(values.size==keys.size && values.map(_._1).toSet==keys,"conversation schema attributes")
    values.toMap
  }
  private def nat(value:String):BigInt={
    require(value.matches("0|[1-9][0-9]{0,127}"),"conversation natural encoding");BigInt(value)
  }
  private def id(value:String):BigInt={val n=nat(value);require(n>0,"conversation identity");n}
  private def small(value:String,max:Int):Int={val n=nat(value);require(n<=max,"conversation count bound");n.toInt}
  private def bool(value:String):Boolean=value match {
    case "true"=>true
    case "false"=>false
    case _=>throw new IllegalArgumentException("conversation Boolean")
  }
  private def status(value:String):Status=value match {
    case "active"=>Status.Active
    case "expired"=>Status.Expired
    case "unavailable"=>Status.Unavailable
    case _=>throw new IllegalArgumentException("conversation status")
  }
  private def text(body:XML.Body,max:Int):String={
    val value=body match {case Nil=>"";case List(XML.Text(value))=>value
      case _=>throw new IllegalArgumentException("conversation text")}
    require(value.getBytes(UTF_8).length<=max,"conversation text bound");value
  }
  private def hex(value:String,max:Int):String={
    require(value.length<=2*max && value.length%2==0 && value.forall(c=>
      (c>='0' && c<='9') || (c>='a' && c<='f')),"conversation canonical hex");value
  }
  private def decodeHex(value:String,max:Int):Array[Byte]={
    hex(value,max);value.grouped(2).map(Integer.parseInt(_,16).toByte).toArray
  }
  // Check shape before YXML builds a tree, including hostile deeply nested input.
  private def frame(value:String):XML.Body={
    require(value.length<=maxFrameBytes && value.getBytes(UTF_8).length<=maxFrameBytes,"conversation frame bound")
    var depth=0;var nodes=0;var i=0
    while(i<value.length){
      if(value.charAt(i)==5 && i+1<value.length && value.charAt(i+1)==6){
        val end=value.indexOf(5.toChar,i+2);require(end>=0,"conversation YXML framing")
        if(end==i+2){depth-=1;require(depth>=0,"conversation YXML closing")}
        else {depth+=1;nodes+=1;require(depth<=10 && nodes<=16384,"conversation YXML shape bound")}
        i=end+1
      } else i+=1
    }
    require(depth==0,"conversation YXML nesting");YXML.parse_body(YXML.Source(value))
  }
  private def refs(body:XML.Body):Vector[BigInt]={
    require(body.size<=8192,"conversation references bound")
    body.map {case XML.Elem(Markup("ref",properties),Nil)=>id(attrs(properties,Set("id"))("id"))
      case _=>throw new IllegalArgumentException("conversation reference")}.toVector
  }
  private def observation(properties:List[(String,String)],body:XML.Body):Observation={
    val a=attrs(properties,Set("session","version"))
    val (clock,reads)=body match {
      case List(XML.Elem(Markup("clock-unused",Nil),Nil),XML.Elem(Markup("reads",Nil),rs))=>(None,rs)
      case List(XML.Elem(Markup("clock",cp),Nil),XML.Elem(Markup("reads",Nil),rs))=>
        val c=attrs(cp,Set("kind","origin_hex","ticks"))
        require(Set("wall","monotonic","source_event")(c("kind")),"conversation clock basis")
        require(c("ticks").matches("0|-?[1-9][0-9]{0,127}"),"conversation signed clock")
        (Some(Clock(c("kind"),hex(c("origin_hex"),256),BigInt(c("ticks")))),rs)
      case _=>throw new IllegalArgumentException("conversation observation body")
    }
    require(reads.size<=8192,"conversation reads bound")
    val parsed=reads.map {
      case XML.Elem(Markup("read",rp),Nil)=>val r=attrs(rp,Set("object","version"));Read(id(r("object")),nat(r("version")))
      case _=>throw new IllegalArgumentException("conversation read")
    }.toVector
    require(parsed.map(_.objectId).distinct.size==parsed.size,"conversation duplicate read")
    Observation(id(a("session")),nat(a("version")),clock,parsed)
  }
  private val claimKeys=Set("claim","target","interpretation","evidence","semantic_generation",
    "executable_generation","route","kind","modality","collection","optimality")
  private def quotation(properties:List[(String,String)],body:XML.Body):Quotation={
    val a=attrs(properties,claimKeys)
    require(Set("kernel_consequence","refined_execution","oracle_consequence")(a("route")),"conversation assurance route")
    require(Set("mathematical","source_observation","engine_observation","model_prediction","test_observation","optimization")(a("kind")),"conversation claim kind")
    require(Set("asserted","conditional","quoted","hypothetical","fictional")(a("modality")),"conversation modality")
    require(Set("scalar","complete")(a("collection")) ||
      (a("collection").startsWith("prefix:") && {
        nat(a("collection").substring(7));true}),"conversation collection")
    require(Set("unspecified","feasible","optimal","impossible")(a("optimality")),"conversation optimality")
    val (premises,dependencies,observed,html)=body match {
      case List(XML.Elem(Markup("premises",Nil),ps),XML.Elem(Markup("dependencies",Nil),ds),
          XML.Elem(Markup("observation",op),ob),XML.Elem(Markup("answer",Nil),answer))=>
        (refs(ps),refs(ds),observation(op,ob),text(answer,32768))
      case _=>throw new IllegalArgumentException("conversation quotation conditions")
    }
    require(html.nonEmpty,"conversation quotation missing licensed rendering")
    Quotation(Claim(id(a("claim")),id(a("target")),id(a("interpretation")),id(a("evidence")),
      id(a("semantic_generation")),if(a("executable_generation")=="none")None else Some(id(a("executable_generation"))),
      a("route"),a("kind"),a("modality"),a("collection"),a("optimality"),premises,dependencies),observed,html)
  }
  private def part(tree:XML.Tree):Part=tree match {
    case XML.Elem(Markup("part",properties),body)=>
      val a=attrs(properties,Set("goal","slot","status"))
      require(Set("pending","historical","declined","inconclusive","failed","cancelled","unavailable","artifact")(a("status")),"conversation part status")
      val (predecessors,remaining)=body match {
        case XML.Elem(Markup("predecessors",Nil),edges)::rest=>
          require(edges.size<=256,"conversation predecessor bound")
          val parsed=edges.map {
            case XML.Elem(Markup("dependency",dp),Nil)=>
              val d=attrs(dp,Set("kind","goal"));require(Set("logical","artifact")(d("kind")),"conversation dependency kind")
              Predecessor(d("kind"),id(d("goal")))
            case _=>throw new IllegalArgumentException("conversation predecessor")
          }.toVector
          (parsed,rest)
        case _=>throw new IllegalArgumentException("conversation missing original predecessors")
      }
      val quote=remaining match {
        case Nil=>None
        case List(XML.Elem(Markup("quotation",qp),qb))=>Some(quotation(qp,qb))
        case _=>throw new IllegalArgumentException("conversation part body")
      }
      require((a("status")=="historical")==quote.nonEmpty,"conversation quotation status")
      Part(id(a("goal")),id(a("slot")),a("status"),predecessors,quote)
    case _=>throw new IllegalArgumentException("conversation part")
  }
  def readIndex(value:String):Index=frame(value) match {
    case List(XML.Elem(Markup("veri7vn-conversations",properties),body))=>
      val a=attrs(properties,Set("version","complete"));require(a("version")=="1","conversation index version")
      require(body.size<=128,"conversation index bound")
      val summaries=body.map {
        case XML.Elem(Markup("conversation",sp),Nil)=>
          val s=attrs(sp,Set("id","revision","status","utterances","adopted"))
          Summary(id(s("id")),nat(s("revision")),status(s("status")),small(s("utterances"),8192),small(s("adopted"),8192))
        case _=>throw new IllegalArgumentException("conversation summary")
      }.toVector
      require(summaries.map(_.id).distinct.size==summaries.size,"conversation duplicate summary")
      Index(summaries,bool(a("complete")))
    case _=>throw new IllegalArgumentException("conversation index root")
  }
  def readView(value:String,expectedId:BigInt):View=frame(value) match {
    case List(XML.Elem(Markup("veri7vn-conversation",properties),body))=>
      val a=attrs(properties,Set("version","id","revision","status","complete"))
      require(a("version")=="1" && id(a("id"))==expectedId,"conversation view identity/version")
      val state=status(a("status"));val revision=nat(a("revision"))
      if(state!=Status.Active){
        require(body.isEmpty,"unavailable conversation disclosed payload")
        View(expectedId,revision,state,None,Vector.empty,bool(a("complete")))
      } else {
        val (observed,turnTrees)=body match {
          case XML.Elem(Markup("observation",op),ob)::rest=>(observation(op,ob),rest)
          case _=>throw new IllegalArgumentException("conversation view observation")
        }
        require(observed.session==expectedId && observed.version==revision && turnTrees.size<=maxTurns,"conversation revision/turn bound")
        val turns=turnTrees.map {
          case XML.Elem(Markup("turn",tp),XML.Elem(Markup("input",ip),input)::
              XML.Elem(Markup("observation",op),ob)::parts)=>
            val t=attrs(tp,Set("request","utterance"));val i=attrs(ip,Set("encoding","source_encoding"))
            require(i("encoding")=="hex" && Set("UTF-8","binary","native-term/1")(i("source_encoding")) &&
              parts.nonEmpty && parts.size<=maxParts,"conversation turn shape")
            val parsed=parts.map(part).toVector
            require(parsed.map(_.goal).distinct.size==parsed.size && parsed.map(_.slot).distinct.size==parsed.size,"conversation duplicate child")
            parsed.foldLeft(Set.empty[BigInt]) {case (previous,p)=>
              require(p.predecessors.forall(d=>previous(d.goal)),"conversation dangling/late predecessor")
              previous+p.goal
            }
            val original=observation(op,ob)
            require(original.session==expectedId && original.version<=revision &&
              parsed.flatMap(_.quotation).forall(_.observation==original),"conversation original turn observation")
            Turn(id(t("request")),id(t("utterance")),i("source_encoding"),hex(text(input,512),256),original,parsed)
          case _=>throw new IllegalArgumentException("conversation turn")
        }.toVector
        require(turns.map(_.request).distinct.size==turns.size && turns.map(_.utterance).distinct.size==turns.size,"conversation duplicate turn")
        require(turns.map(_.parts.size).sum<=1024,"conversation total parts bound")
        require(turns.flatMap(_.parts.flatMap(_.quotation)).forall(q=>
          q.observation.session==expectedId && q.observation.version<revision),"conversation historical revision")
        View(expectedId,revision,state,Some(observed),turns,bool(a("complete")))
      }
    case _=>throw new IllegalArgumentException("conversation view root")
  }
}
