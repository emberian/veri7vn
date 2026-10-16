package veri7vn.runtime.service

import java.nio.charset.StandardCharsets.UTF_8
import scala.language.unsafeNulls

/** Runs against the real resident service; no alternative reader or fake authority. */
object DialogueClientChecks {
  def main(args:Array[String]):Unit={
    val root=java.nio.file.Files.createTempDirectory("veri7vn-dialogue-resident-")
    println("DIALOGUE_WORKSPACE "+root)
    scala.util.Using.resource(RuntimeService.open(root.resolve("workspace"),root.resolve("images"),
      args.toList.map(s=>java.nio.file.Paths.get(s)))) {service=>run(service.client)}
    println("DIALOGUE_RESIDENT_PASS")
  }
  private def rejects(body: => Any):Unit={
    var rejected=false
    try body catch {case _:IllegalArgumentException=>rejected=true}
    require(rejected,"invalid dialogue selection was accepted")
  }
  def run(client:ResidentAuthorityService):Unit={
    val dialogue=new DialogueClient(client)
    def inspect(text:String):DialogueClient.Inspection={
      val original=text.getBytes(UTF_8)
      try dialogue.inspect(original) finally java.util.Arrays.fill(original,0.toByte)
    }
    try {
      val sum=inspect("the sum of -2 and 3")
      val product=inspect("what is the product of 6 and 7?")
      require(sum.status=="ready" && sum.alternatives==List(0) && sum.policy=="math/1")
      require(product.status=="ready" && product.alternatives==List(0))
      rejects(dialogue.select(sum.handle,255))
      val sumRequest=dialogue.select(sum.handle,0)
      rejects(dialogue.select(sum.handle,0))
      val productRequest=dialogue.select(product.handle,0)
      def result(id:BigInt):client.Result={
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var value=client.mathematicsResult(id)
        while(value.status=="pending" && System.nanoTime()<deadline){
          Thread.sleep(20);value=client.mathematicsResult(id)
        }
        value
      }
      val sumResult=result(sumRequest)
      val productResult=result(productRequest)
      require(sumResult.status=="accepted_exact" &&
        sumResult.html.contains("<p>The exact sum of -2 and 3 is 1.</p>"),
        "dialogue selection changed original sum or licensed rendering")
      require(productResult.status=="accepted_exact" &&
        productResult.html.contains("<p>The exact product of 6 and 7 is 42.</p>"),
        "dialogue selection mixed concurrent retained originals")
      require(inspect("the sum of nope and 3").status=="literal")
      require(inspect("what is the square root of -1?").status=="unrecognized")
      val undefined=inspect("the quotient of 1 and 0")
      require(undefined.status=="ready" && undefined.alternatives==List(0))
      val undefinedRequest=dialogue.select(undefined.handle,0)
      val undefinedResult=result(undefinedRequest)
      require(undefinedResult.status=="undefined" && undefinedResult.html.isEmpty,
        "undefined quotient lost its native domain outcome or emitted a numeric answer")
      val afterRefusal=inspect("the sum of 4 and 5")
      val afterRefusalRequest=dialogue.select(afterRefusal.handle,0)
      val afterRefusalResult=result(afterRefusalRequest)
      require(afterRefusalResult.status=="accepted_exact" &&
        afterRefusalResult.html.contains("<p>The exact sum of 4 and 5 is 9.</p>"),
        "a refused quotient suppressed an unrelated justified reading")
      val discarded=inspect("the sum of 4 and 5")
      dialogue.discard(discarded.handle)
      rejects(dialogue.select(discarded.handle,0))
      client.forget(sumRequest)
      client.forget(productRequest)
      client.forget(undefinedRequest)
      client.forget(afterRefusalRequest)
      List(sumRequest,productRequest,undefinedRequest,afterRefusalRequest).foreach {id=>
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var value=client.mathematicsResult(id)
        while(value.status!="cancelled" && System.nanoTime()<deadline){
          Thread.sleep(20);value=client.mathematicsResult(id)
        }
        require(value.status=="cancelled" && value.html.isEmpty,"dialogue-owned result survived Forget")
      }
    } finally dialogue.close()
  }
}
