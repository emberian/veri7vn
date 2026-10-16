package veri7vn.diagnostics

import isabelle.{XML,Markup,YXML}

object BuildFailureTests {
  def run():Unit={
    def element(name:String,p:List[(String,String)],body:List[XML.Tree]=Nil)=XML.Elem(Markup(name,p),body)
    def frame(message:XML.Tree,location:XML.Tree=element("span",List("start"->"3","stop"->"7"))):String=
      YXML.string_of_body(List(element("veri7vn-build-failure",List("version"->"1","phase"->"replay",
        "source_revision"->"101","manifest"->"102"),List(location,message))))
    def rejects(body: => Any):Unit={var failed=false;try body catch{case _:IllegalArgumentException=>failed=true};assert(failed)}
    val text=element("message",Nil,List(XML.Text("Unknown fact λ")))
    val parsed=BuildFailure.parse(frame(text),BigInt(101),BigInt(102))
    assert(parsed.phase==BuildFailure.Phase.Replay && parsed.span.contains(BuildFailure.Span(3,7)))
    assert(parsed.message==BuildFailure.Message.Text("Unknown fact λ"))
    assert(parsed.code=="build.replay_failed" && Diagnostics.explain(parsed.code).outcome==Diagnostics.Outcome.Failed)
    assert(parsed.copy(phase=BuildFailure.Phase.Export).code=="build.export_failed")
    rejects(BuildFailure.parse(frame(text),BigInt(100),BigInt(102)))
    rejects(BuildFailure.parse(frame(text).replace("phase=replay","phase=timeout"),BigInt(101),BigInt(102)))
    rejects(BuildFailure.parse(frame(element("message",Nil,List(element("b",Nil)))),BigInt(101),BigInt(102)))
    rejects(BuildFailure.parse(frame(element("message",Nil,List(XML.Text("λ"*2049)))),BigInt(101),BigInt(102)))
    val missing=BuildFailure.parse(frame(element("message-unavailable",List("reason"->"exceeds_bound")),
      element("span-unavailable",List("reason"->"not_reported"))),BigInt(101),BigInt(102))
    assert(missing.span.isEmpty && missing.message==BuildFailure.Message.Unavailable)
    println("BUILD_FAILURE_CODEC_PASS closed phases exact native associations Unicode byte bounds text-only messages unavailable!=empty assumptions; native producer unchecked")
  }
}
