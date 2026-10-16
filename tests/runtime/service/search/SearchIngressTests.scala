package veri7vn.runtime.service.search

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import isabelle.{Bytes,XML,Markup,YXML}
import veri7vn.runtime.service.ResidentSupervisor

/** Wire/lifetime checks only. The scripted peer cannot establish native evidence. */
object SearchIngressTests {
  private def node(tag:String,attrs:List[(String,String)]=Nil,children:XML.Body=Nil)=XML.Elem(Markup(tag,attrs),children)
  private def xml(tree:XML.Tree)=YXML.string_of_body(List(tree))
  private def denied(action: => Any):Unit={
    var rejected=false
    try action catch {case _:IllegalArgumentException=>rejected=true
      case _:java.nio.charset.CharacterCodingException=>rejected=true}
    assert(rejected,"expected closed protocol rejection")
  }
  final class Peer extends SearchIngress.Transport {
    var original=Array.empty[Byte]
    var proposed=0
    var wrongChild=false
    var mergedProvenance=false
    var omittedProvenance=false
    var duplicateRequests=false
    var status="budget"
    private def reply(tag:String,payload:String,tree:Option[XML.Tree]=None)=
      ResidentSupervisor.Reply(1,tag,payload,tree.toList.map(t=>Bytes(xml(t))))
    def exchange(operation:String,payload:String,artifacts:List[Bytes]):ResidentSupervisor.Reply=operation match {
      case "search_contexts"=>reply("search_contexts","1",Some(node("search-contexts",List("version"->"1"),
        List(node("context",List("id"->"40","semantic"->"41"),List(XML.Text("Installed native package")))))))
      case "search_requests"=>
        val request=node("request",List("id"->"100","goal"->"101","slot"->"102","context"->"40","semantic"->"41"))
        reply("search_requests","1",Some(node("search-requests",List("version"->"1"),
          if(duplicateRequests)List(request,request) else List(request))))
      case "propose_search"=>
        assert(payload.isEmpty && artifacts.size==1)
        val packet=artifacts.head.make_array
        assert(packet(8)=='\n'.toByte)
        val headerLength=new String(packet.take(8),UTF_8).toInt
        val policy=YXML.parse_body(YXML.Source(new String(packet.slice(9,9+headerLength),UTF_8)))
        assert(policy.size==1)
        original=packet.drop(9+headerLength);proposed+=1
        reply("search_proposed","100,101,102")
      case "poll_search"=>
        assert(payload=="100,101,102" && artifacts.isEmpty)
        val progress=node("progress",List("expansions"->"1","trace_total"->"1","remaining_total"->"1","details_truncated"->"false"),
          List(node("trace",children=List(node("step",List("index"->"0","action"->"split","route"->"advanced"),List(node("subgoal",children=List(XML.Text("P & P"))))))),
            node("remaining",children=List(node("state",children=List(node("subgoal",children=List(XML.Text("P")))))))))
        val detail=if(status=="proved" || status=="historical_proved")node("proof",List("evidence"->"200","semantic"->"41","proof_semantic"->(if(mergedProvenance)"41" else "42"),"route"->"kernel_consequence"),
          List(node("proposition",children=List(XML.Text(new String(original,UTF_8)))),node("dependencies",children=List(node("dependency",List("id"->"41")),node("dependency",List("id"->(if(omittedProvenance)"43" else "42"))),node("dependency",List("id"->"40"))))))
          else node("diagnostic",children=List(XML.Text("The proposition remains unresolved.")))
        val children=if(status=="pending")Nil else List(detail,progress)
        reply("search_result",payload,Some(node("search-result",List("version"->"1","request"->"100",
          "goal"->(if(wrongChild)"999" else "101"),"slot"->"102","status"->status),children)))
      case _=>throw new AssertionError(operation)
    }
  }
  def main(args:Array[String]):Unit={
    val peer=new Peer
    var canceled:Option[BigInt]=None
    val ingress=new SearchIngress(peer,()=>(),id=>canceled=Some(id))
    val context=ingress.contexts().head
    val literal="  P --> (P & P)  \n".getBytes(UTF_8)
    val expected=literal.clone()
    val request=ingress.propose(context,literal,SearchIngress.Budget(32,32,2,1000),
      Vector(SearchIngress.Action.Introduce,SearchIngress.Action.Split,SearchIngress.Action.Assume))
    java.util.Arrays.fill(literal,0.toByte)
    assert(java.util.Arrays.equals(peer.original,expected),"original physical bytes changed")
    assert(request.request==100 && request.goal==101 && request.slot==102 && request.context==40 && request.semantic==41)
    val recovered=ingress.requests().head
    assert(recovered.request==request.request && recovered.goal==request.goal && recovered.slot==request.slot &&
      recovered.context==request.context && recovered.semantic==request.semantic)
    peer.duplicateRequests=true;denied(ingress.requests());peer.duplicateRequests=false
    assert(ingress.poll(request).asInstanceOf[SearchIngress.Unresolved].reason==SearchIngress.Stop.Budget)
    peer.status="proved"
    val proof=ingress.poll(request).asInstanceOf[SearchIngress.Proved]
    assert(proof.proposition==new String(expected,UTF_8) && proof.evidence==200 && proof.semantic==41 && proof.proofSemantic==42 && proof.dependencies==Vector(BigInt(41),BigInt(42),BigInt(40)))
    peer.wrongChild=true;denied(ingress.poll(request));peer.wrongChild=false
    peer.mergedProvenance=true;denied(ingress.poll(request));peer.mergedProvenance=false
    peer.omittedProvenance=true;denied(ingress.poll(request));peer.omittedProvenance=false
    peer.status="historical_proved"
    assert(ingress.poll(request)==SearchIngress.Historical(proof),"retained proof was confused with an active result binding")
    for(status<-Vector("exhausted","deadline","cancelled","failed","unavailable")){
      peer.status=status;assert(ingress.poll(request).isInstanceOf[SearchIngress.Unresolved])
    }
    peer.status="pending";assert(ingress.poll(request)==SearchIngress.Pending)
    peer.status="negative";denied(ingress.poll(request))
    val other=new SearchIngress(new Peer,()=>(),_=>())
    denied(other.poll(request));denied(other.propose(context,expected,SearchIngress.Budget(1,1,1,1),Vector(SearchIngress.Action.Assume)))
    denied(ingress.propose(context,Array(0xc3.toByte,0x28.toByte),SearchIngress.Budget(1,1,1,1),Vector(SearchIngress.Action.Assume)))
    denied(ingress.propose(context,expected,SearchIngress.Budget(1,1,1,1),Vector(SearchIngress.Action.Apply(0))))
    denied(ingress.propose(context,expected,SearchIngress.Budget(1,1,1,1),Vector(SearchIngress.Action.Assume),Vector("a\u0005b")))
    ingress.cancel(request);assert(canceled.contains(BigInt(100)))
    println("VERI7VN_SEARCH_INGRESS_TESTS_PASSED")
  }
}
