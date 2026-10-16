package veri7vn.runtime.service
import isabelle.{Bytes,Markup,XML,YXML}
object RoutingGrowthProtocolTests {
  def main(args:Array[String]):Unit={
    def node(name:String,attrs:List[(String,String)]=Nil,body:List[XML.Tree]=Nil)=XML.Elem(Markup(name,attrs),body)
    def reply(tag:String,profile:String,root:XML.Tree)=ResidentSupervisor.Reply(1,tag,profile,List(Bytes(YXML.string_of_body(List(root)))))
    val original="the sum of -2 and 3".getBytes(java.nio.charset.StandardCharsets.UTF_8)
    def literal(start:Int,stop:Int)=node("literal",List("start"->start.toString,"stop"->stop.toString))
    def routing(index:String="0",operation:String="0",stop:Int=19)=reply("routing_details","math/1",
      node("routing-details",List("version"->"1","status"->"readings"),List(
        node("alternative",List("index"->index,"operation"->operation),List(literal(11,13),literal(18,stop))))))
    val detail=RoutingDetailsProtocol.read(routing(),original)
    assert(detail.alternatives==Vector(RoutingAlternative(0,0,Vector(RoutingSpan(11,13),RoutingSpan(18,19)))))
    def denied(action: => Any):Unit={var rejected=false;try action catch {case _:IllegalArgumentException=>rejected=true};assert(rejected)}
    denied(RoutingDetailsProtocol.read(routing(index="1"),original))
    denied(RoutingDetailsProtocol.read(routing(operation="5"),original))
    denied(RoutingDetailsProtocol.read(routing(stop=20),original))
    def growth(ops:List[String],source:String,blocked:List[String])=reply("growth_suggestion","numeric/1",
      node("growth-suggestion",List("version"->"1","profile"->"numeric/1","status"->"tentative"),List(
        node("operations",body=ops.map(value=>node("operation",body=List(XML.Text(value))))),
        node("source",body=List(XML.Text(source))),
        node("unsupported",body=blocked.map(value=>node("word",body=List(XML.Text(value))))))))
    val proposal=GrowthSuggestionProtocol.read(growth(List("double","increment"),"tentative declaration",Nil))
    assert(proposal.operations==Vector("double","increment") && proposal.unsupported.isEmpty)
    assert(GrowthSuggestionProtocol.read(growth(List("double"),"",List("sort"))).source.isEmpty)
    denied(GrowthSuggestionProtocol.read(growth(List("sort"),"",Nil)))
    denied(GrowthSuggestionProtocol.read(growth(List("double","double"),"x",Nil)))
    denied(GrowthSuggestionProtocol.read(growth(List("double"),"x",List("sort"))))
    denied(GrowthSuggestionProtocol.read(growth(List("double"),"x"*8193,Nil)))
    println("ROUTING_GROWTH_PROTOCOL_PASS original_byte_spans closed_frames tentative_only bounded_source")
  }
}
