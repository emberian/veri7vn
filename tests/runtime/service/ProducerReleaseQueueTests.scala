package veri7vn.runtime.service
import scala.language.unsafeNulls
import java.nio.file.Files
import veri7vn.runtime.host.{ManagedSources,WorkspaceStore}
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.effects.ResourceBudget

object ProducerReleaseQueueTests {
  def main(args:Array[String]):Unit={
    val base=Files.createTempDirectory("producer-release-").toRealPath()
    val source=Files.createDirectory(base.resolve("source"))
    Files.writeString(source.resolve("ROOT"),"session Input = HOL + theories Input\n")
    Files.writeString(source.resolve("Input.thy"),"theory Input imports Main begin end\n")
    Files.writeString(source.resolve("package.json"),"""{"format":"veri7vn.package/0","package":{"id":"test.queue","version":"1.0.0","title":"Queue","description":"Queue"},"files":[{"path":"Input.thy","role":"source"}],"requires":[],"native":{"session":"Input","theories":["Input"]},"capabilities":[]}""")
    val stores=(0 until 2).map(i=>new WorkspaceStore(base.resolve("store"+i))).toVector
    val transports=Vector.fill(2)(new NativeBuildIngressTests.ControlledTransport("normal"))
    val ingresses=stores.zip(transports).map((store,transport)=>new NativeBuildIngress(transport,store))
    val inputs=stores.zipWithIndex.map {(store,index)=>
      val sources=new ManagedSources(store);val drafts=new ManagedDrafts(sources)
      require(drafts.create("create","draft",Intake.directory(source,Intake.Format.NativeDevelopment)).isInstanceOf[ManagedDrafts.Recorded])
      val head=sources.withHead("draft")((h,_)=>h).get
      NativeBuildInputs.materialize(sources,"draft",head,ResourceBudget(BigInt(index+1),512L*1024*1024,4096,4,2048,64L*1024*1024,512,24,1)).get
    }
    try {
      val prepared=ingresses.zip(inputs).map((ingress,input)=>ingress.prepare(input,"Input.thy"))
      transports.foreach(_.retainConsumer())
      transports.head.releaseUnavailable=true
      val queue=new ProducerReleaseQueue
      prepared.foreach(queue.enqueue)
      for(i<-0 until 10)queue.pump(i.toLong*60000000000L)
      assert(queue.pendingCount==1 && queue.failures.size==1 && queue.failures.head.attempts==8 &&
        queue.failures.head.reason.contains("release currently unavailable"),"exhaustion was not exposed with its cause")
      assert(inputs.head.isLive && !inputs(1).isLive && transports.forall(_.consumerLeases==1),
        "failed producer lost ownership or blocked successful sibling/consumer")
      val attempts=transports.head.releases
      queue.pump(20L*60000000000L)
      assert(transports.head.releases==attempts,"exhaustion silently restarted retries")
      transports.head.releaseUnavailable=false
      queue.retryExhausted();queue.pump(21L*60000000000L)
      assert(queue.pendingCount==0 && queue.failures.isEmpty && !inputs.head.isLive)
      transports.foreach(_.releaseConsumer())
    } finally {
      transports.foreach(_.releaseUnavailable=false)
      ingresses.foreach(_.close());inputs.foreach(_.close());stores.foreach(_.close())
    }
    println("PRODUCER_RELEASE_QUEUE_PASS")
  }
}
