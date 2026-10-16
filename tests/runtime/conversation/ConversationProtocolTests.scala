package veri7vn.runtime.conversation

import isabelle.{Markup,XML,YXML}
import java.nio.charset.StandardCharsets.UTF_8
import scala.language.unsafeNulls

object ConversationProtocolTests {
  private def node(name:String,properties:(String,String)*)(body:XML.Body=Nil):XML.Tree=
    XML.Elem(Markup(name,properties.toList),body)
  private def observed(version:String,session:String="12"):XML.Tree=
    node("observation","session"->session,"version"->version)(List(
      node("clock","kind"->"source_event","origin_hex"->"73656e736f72","ticks"->"-9")(),
      node("reads")(List(node("read","object"->"91","version"->"4")()))))
  private def ref(id:String):XML.Tree=node("ref","id"->id)()
  private def quote(observation:XML.Tree=observed("0")):XML.Tree=
    node("quotation","claim"->"21","target"->"22","interpretation"->"23","evidence"->"24",
      "semantic_generation"->"25","executable_generation"->"none","route"->"kernel_consequence",
      "kind"->"source_observation","modality"->"conditional","collection"->"prefix:5","optimality"->"feasible")(
      List(node("premises")(List(ref("90"))),node("dependencies")(List(ref("91"))),observation,
        node("answer")(List(XML.Text("<p>Reported under premise 90; five displayed rows.</p>")))))
  private def view(body:XML.Body,state:String="active",revision:String="1"):String=
    YXML.string_of_body(List(node("veri7vn-conversation","version"->"1","id"->"12","revision"->revision,
      "status"->state,"complete"->"true")(body)))
  private def turn(parts:XML.Body,original:XML.Tree=observed("0")):XML.Tree=node("turn","request"->"30","utterance"->"31")(
    List(node("input","encoding"->"hex","source_encoding"->"UTF-8")(List(XML.Text("612020620a"))),original)++parts)
  private def part(status:String,body:XML.Body):XML.Tree=
    node("part","goal"->"32","slot"->"33","status"->status)(node("predecessors")()::body)
  private def rejects(body: => Any):Unit={
    var rejected=false
    try body catch {case _:IllegalArgumentException=>rejected=true}
    assert(rejected,"malformed conversation frame was accepted")
  }
  def main(args:Array[String]):Unit={
    import ConversationProtocol.*
    val original=view(List(observed("1"),turn(List(part("historical",List(quote()))))))
    val parsed=readView(original,12)
    val history=parsed.turns.head.parts.head.quotation.get
    assert(parsed.status==Status.Active && parsed.version==1 && parsed.complete)
    assert(parsed.turns.head.originalBytes.sameElements("a  b\n".getBytes(UTF_8)))
    assert(parsed.turns.head.inputEncoding=="UTF-8")
    assert(history.claim.premises==Vector(BigInt(90)) && history.claim.dependencies==Vector(BigInt(91)))
    assert(history.claim.modality=="conditional" && history.claim.collection=="prefix:5" && history.claim.optimality=="feasible")
    assert(history.claim.executableGeneration.isEmpty && history.observation.clock.get.ticks== -9)
    assert(history.observation.reads==Vector(Read(91,4)) && history.observation.version==0)
    assert(parsed.turns.head.observation==history.observation)
    rejects(readView(original,13))
    rejects(readView(view(List(observed("1"),turn(List(part("pending",List(quote())))))),12))
    rejects(readView(view(List(observed("1"),turn(List(part("historical",Nil))))),12))
    rejects(readView(view(List(observed("1"),turn(List(part("historical",List(quote(observed("1")))))))),12))
    rejects(readView(view(List(observed("1"),turn(List(part("historical",List(quote(observed("0","13")))))))),12))
    rejects(readView(view(List(observed("1")),"expired"),12))
    assert(readView(view(Nil,"expired"),12).turns.isEmpty)
    assert(readView(view(Nil,"unavailable"),12).observation.isEmpty)
    rejects(readView(view(List(observed("1"),turn(List(part("accepted_exact",Nil))))),12))
    rejects(readView(view(List(observed("1"),turn(List(part("pending",Nil),part("pending",Nil))))),12))
    val unavailable=node("part","goal"->"34","slot"->"35","status"->"unavailable")(
      List(node("predecessors")()))
    val dependent=node("part","goal"->"36","slot"->"37","status"->"pending")(
      List(node("predecessors")(List(
        node("dependency","kind"->"logical","goal"->"32")(),
        node("dependency","kind"->"artifact","goal"->"34")()))))
    val graph=readView(view(List(observed("1"),turn(List(part("pending",Nil),unavailable,dependent)))),12)
    assert(graph.turns.head.parts.last.predecessors==Vector(Predecessor("logical",32),Predecessor("artifact",34)))
    assert(graph.turns.head.observation.version==0 && graph.turns.head.parts(1).quotation.isEmpty)
    rejects(readView(view(List(observed("1"),turn(List(part("pending",Nil),dependent)))),12))
    rejects(readView("\u0005\u0006n\u0005"*11+"\u0005\u0006\u0005"*11,12))
    rejects(readView("x"*(maxFrameBytes+1),12))
    val index=YXML.string_of_body(List(node("veri7vn-conversations","version"->"1","complete"->"false")(
      List(node("conversation","id"->"12","revision"->"1","status"->"active","utterances"->"2","adopted"->"1")()))))
    assert(!readIndex(index).complete && readIndex(index).conversations.head.id==12)
    println("CONVERSATION_PROTOCOL_PASS historical_conditions exact_original_bytes original_clock_reads nonaccepted_context typed_predecessors unavailable_placeholder no_current_relabel withheld_payload wrong_session duplicate_child bounds partial_index")
  }
}
