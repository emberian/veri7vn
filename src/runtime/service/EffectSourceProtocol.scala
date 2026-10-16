package veri7vn.runtime.service

import scala.language.unsafeNulls
import isabelle.{Markup,XML,YXML}
import veri7vn.runtime.host.NativeEffectSources

/** Closed metadata decoding only. Authority is the bridge's private issuer after
  * this reply came from its actual resident under the lifecycle writer lock. */
private[service] object EffectSourceProtocol {
  final case class Owner(identity:NativeEffectSources.Identity,semantic:BigInt,status:String,
    ownerIncarnation:BigInt,stateVersion:BigInt,sequence:Long)
  private def positive(s:String):BigInt={
    require(s.matches("[1-9][0-9]{0,127}"),"effect source owner identity");BigInt(s)
  }
  private def natural(s:String):BigInt={
    require(s.matches("0|[1-9][0-9]{0,127}"),"effect source state version");BigInt(s)
  }
  def read(reply:ResidentSupervisor.Reply,workspace:String,source:BigInt):Option[Owner]={
    require(source>0 && source.toString.length<=128 && workspace.matches("[0-9a-f]{32}"))
    require(reply.payload==source.toString,"effect source owner query identity")
    if(reply.tag=="effect_source_unavailable"){
      require(reply.artifacts.isEmpty,"effect source unavailable artifacts");None
    }else{
      require(reply.tag=="effect_source_owner" && reply.artifacts.size==1 && reply.artifacts.head.size<=4096,
        "effect source owner reply shape")
      val frame=reply.artifacts.head.text
      require(frame.forall(c=>c==5 || c==6 || (c>=32 && c<=126)),"effect source owner frame encoding")
      val properties=YXML.parse_body(YXML.Source(frame)) match {
        case List(XML.Elem(Markup("effect-source-owner",attributes),Nil))=>attributes
        case _=>throw new IllegalArgumentException("effect source owner root")
      }
      val keys=Set("version","workspace","source","attempt","request","configuration","packet","semantic",
        "status","projection","payload","bytes","protocol","representation","owner_incarnation","state_version","sequence")
      require(properties.size==keys.size && properties.map(_._1).toSet==keys,"effect source owner fields")
      val a=properties.toMap
      require(a("version")=="1" && a("workspace")==workspace && positive(a("source"))==source,
        "effect source owner namespace/version")
      require(a("protocol")=="local-mcp/1" && a("representation")=="decoded-json/1" &&
        Set("confirmed","failed").contains(a("status")),"effect source owner representation/status")
      require(a("bytes").matches("[1-9][0-9]{0,4}"),"effect source owner byte length")
      val size=a("bytes").toInt;require(size<=65536,"effect source owner byte bound")
      require(a("sequence").matches("[1-9][0-9]{0,18}"),"effect source checkpoint sequence")
      val sequence=BigInt(a("sequence"));require(sequence<=Long.MaxValue,"effect source checkpoint bound")
      Some(Owner(NativeEffectSources.Identity(source,positive(a("attempt")),positive(a("request")),
        positive(a("configuration")),positive(a("packet")),a("projection"),a("payload"),size),
        positive(a("semantic")),a("status"),positive(a("owner_incarnation")),natural(a("state_version")),sequence.toLong))
    }
  }
}
