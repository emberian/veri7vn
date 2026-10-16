package veri7vn.runtime.service
import isabelle.{Bytes,Markup,XML,YXML}
object EffectSourceProtocolTests {
  def main(args:Array[String]):Unit={
    val workspace="a"*32
    val attrs=List("version"->"1","workspace"->workspace,"source"->"31","attempt"->"10","request"->"11",
      "configuration"->"12","packet"->"13","semantic"->"32","status"->"confirmed","projection"->("b"*64),
      "payload"->("c"*64),"bytes"->"123","protocol"->"local-mcp/1","representation"->"decoded-json/1",
      "owner_incarnation"->"7","state_version"->"9","sequence"->"12")
    def reply(properties:List[(String,String)],children:List[XML.Tree]=Nil)=ResidentSupervisor.Reply(1,"effect_source_owner","31",
      List(Bytes(YXML.string_of_body(List(XML.Elem(Markup("effect-source-owner",properties),children))))))
    val owner=EffectSourceProtocol.read(reply(attrs),workspace,BigInt(31)).get
    assert(owner.identity.source==31 && owner.sequence==12 && owner.semantic==32 && owner.ownerIncarnation==7 && owner.stateVersion==9)
    assert(EffectSourceProtocol.read(ResidentSupervisor.Reply(1,"effect_source_unavailable","31",Nil),workspace,BigInt(31)).isEmpty)
    def denied(properties:List[(String,String)],children:List[XML.Tree]=Nil):Unit={
      var rejected=false;try EffectSourceProtocol.read(reply(properties,children),workspace,BigInt(31))
      catch {case _:IllegalArgumentException=>rejected=true};assert(rejected)
    }
    def change(key:String,value:String)=attrs.map((k,v)=>k->(if(k==key)value else v))
    denied(attrs:+("source"->"31"));denied(attrs.filterNot(_._1=="sequence"))
    denied(change("workspace","d"*32));denied(change("source","33"))
    denied(change("semantic","0"));denied(change("owner_incarnation","0"));denied(change("state_version","01"))
    denied(change("sequence","9223372036854775808"));denied(change("sequence","0"))
    denied(change("bytes","65537"));denied(change("status","accepted_exact"))
    denied(change("protocol","other/1"));denied(change("representation","wire/1"))
    denied(change("payload","x"*64));denied(attrs,List(XML.Text("unlicensed response bytes")))
    println("EFFECT_SOURCE_PROTOCOL_PASS fixed_owner freshness_fields namespace exact_representation no_payload_in_reply")
  }
}
