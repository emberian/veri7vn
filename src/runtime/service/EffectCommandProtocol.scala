package veri7vn.runtime.service

import scala.language.unsafeNulls
import isabelle.{Markup,XML,YXML}
import veri7vn.runtime.service.effects.{NativeEffectCommand,NativeEffectCost}

/** Closed generated-command decoding. These values carry no handoff authority. */
private[service] object EffectCommandProtocol {
  final case class Binding(phase:String,prepared:BigInt,configuration:BigInt,incarnation:BigInt,
    attempt:BigInt,request:BigInt,response:BigInt,operation:String,artifact:String)
  private def natural(s:String):BigInt={
    require(s.matches("0|[1-9][0-9]{0,127}"),"native effect command natural");BigInt(s)
  }
  private def vector(s:String):Vector[BigInt]={
    val entries=if(s.isEmpty)Vector.empty else s.split(",",-1).toVector
    require(entries.size<=8192,"native effect command vector bound")
    entries.map(natural)
  }
  def binding(reply:ResidentSupervisor.Reply,token:String):Option[Binding]={
    require(token.matches("[1-9][0-9]{0,17}") && reply.payload==token,"native effect binding token")
    if(reply.tag=="effect_binding_none"){
      require(reply.artifacts.isEmpty,"native effect absent binding artifacts");None
    }else{
      require(reply.tag=="effect_binding" && reply.artifacts.size==1 && reply.artifacts.head.size<=4096,
        "native effect binding reply")
      val text=reply.artifacts.head.text
      require(text.forall(c=>c==5 || c==6 || (c>=32 && c<=126)),"native effect binding encoding")
      val attrs=YXML.parse_body(YXML.Source(text)) match {
        case List(XML.Elem(Markup("effect-binding",properties),Nil))=>properties
        case _=>throw new IllegalArgumentException("native effect binding root")
      }
      val keys=Set("version","token","phase","prepared","configuration","incarnation","attempt","request",
        "response","operation","protocol","artifact")
      require(attrs.size==keys.size && attrs.map(_._1).toSet==keys,"native effect binding fields")
      val a=attrs.toMap
      require(a("version")=="1" && a("token")==token && a("protocol")=="local-mcp/1" &&
        a("artifact").matches("[0-9a-f]{64}") &&
        Set("support","reserve","stage","start","observation").contains(a("phase")) &&
        Set("Discover","QualifyCounter","InvokeCounter").contains(a("operation")),"native effect binding profile")
      def positive(key:String):BigInt={val n=natural(a(key));require(n>0,"native effect binding positive identity");n}
      val response=natural(a("response"))
      require(if(a("phase")=="observation")response>0 else response==0,"native effect response binding phase")
      Some(Binding(a("phase"),positive("prepared"),positive("configuration"),positive("incarnation"),
        positive("attempt"),positive("request"),response,a("operation"),a("artifact")))
    }
  }
  def read(frame:isabelle.Bytes):NativeEffectCommand={
    require(frame.size<=16384,"native effect command frame bound")
    val text=frame.text
    require(text.forall(c=>c==5 || c==6 || (c>=32 && c<=126)),"native effect command encoding")
    val properties=YXML.parse_body(YXML.Source(text)) match {
      case List(XML.Elem(Markup("effect-start-command",attributes),Nil))=>attributes
      case _=>throw new IllegalArgumentException("native effect command root")
    }
    val keys=Set("version","attempt","request","target","capability","prestate","epoch",
      "profile","code_generation","operation","step","units","sources","dependencies")
    require(properties.size==keys.size && properties.map(_._1).toSet==keys,"native effect command fields")
    val a=properties.toMap;require(a("version")=="1","native effect command version")
    NativeEffectCommand(natural(a("attempt")),natural(a("request")),natural(a("target")),
      natural(a("capability")),vector(a("sources")),vector(a("dependencies")),
      natural(a("prestate")),natural(a("epoch")),NativeEffectCost(natural(a("profile")),
        natural(a("code_generation")),natural(a("operation")),natural(a("step")),natural(a("units"))))
  }
}
