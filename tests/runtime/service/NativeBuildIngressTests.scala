package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import java.util.concurrent.{CountDownLatch,TimeUnit,TimeoutException}
import isabelle.{Bytes,YXML,XML,Markup}
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.ManagedDrafts
import veri7vn.packages.native_build.NativeBuildInputs
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
import veri7vn.runtime.effects.ResourceBudget

/** Controlled protocol loss with the actual registered host source/worker
  * ownership. This checks host arbitration, not native replay or admission. */
object NativeBuildIngressTests {
  final class ControlledTransport(mode:String) extends NativeBuildIngress.Transport {
    @volatile var staged=false
    @volatile var nativePrepared=false
    @volatile var accepted=false
    @volatile var releaseUnavailable=mode=="release_unavailable"
    @volatile var releases=0
    @volatile var discarded=0
    @volatile var consumerLeases=0
    val finishEntered=new CountDownLatch(1)
    val finishReturn=new CountDownLatch(1)
    private var nonce=""
    private def reply(tag:String,payload:String)=ResidentSupervisor.Reply(1,tag,payload)
    def exchange(operation:String,payload:String,artifacts:List[Bytes]):ResidentSupervisor.Reply=operation match {
      case "build_input_begin"=>
        val attributes=YXML.parse_body(YXML.Source(artifacts.head.text)) match {
          case List(XML.Elem(Markup("build-input",attrs),_))=>attrs.toMap
          case _=>throw new AssertionError("unexpected ingress packet")
        }
        nonce=attributes("upload_nonce");assert(nonce.matches("[0-9a-f]{32}"))
        staged=true;accepted=false
        if(mode=="lost_begin")throw new java.io.IOException("begin committed, reply lost")
        reply("build_input_ready","1")
      case "build_input_write"=>assert(staged);reply("build_input_written","1")
      case "build_input_finish"=>
        assert(staged);staged=false;nativePrepared=true;finishEntered.countDown()
        if(mode=="late_finish"){
          var released=false
          while(!released)try {released=finishReturn.await(5,TimeUnit.SECONDS)} catch {case _:InterruptedException=>()}
        }
        if(mode=="lost_finish")throw new java.io.IOException("finish committed, reply lost")
        reply("build_input_prepared","10")
      case "build_input_accept"=>
        assert(payload==s"$nonce,10" && nativePrepared);accepted=true
        if(mode=="lost_accept" || mode=="release_unavailable")throw new java.io.IOException("accept committed, reply lost")
        reply("build_input_accepted",payload)
      case "build_input_release"=>
        assert(payload=="10");releases+=1
        if(releaseUnavailable)throw new java.io.IOException("release currently unavailable")
        nativePrepared=false;reply("build_input_released",payload)
      case "build_input_discard"=>
        assert(payload==nonce);discarded+=1;staged=false
        if(!accepted)nativePrepared=false
        reply("build_input_discarded",payload)
      case "build_input_settle"=>assert(payload==nonce);reply("build_input_settled",payload)
      case other=>throw new AssertionError("unexpected ingress command: "+other)
    }
    def retainConsumer():Unit={assert(nativePrepared && accepted);consumerLeases+=1}
    def releaseConsumer():Unit={assert(consumerLeases>0);consumerLeases-=1}
  }
  def main(args:Array[String]):Unit={
    for(mode<-List("normal","lost_begin","lost_finish","lost_accept","late_finish","release_unavailable","foreign_store")){
      val source=Files.createTempDirectory("v7-ingress-source-").toRealPath()
      Files.writeString(source.resolve("ROOT"),"session Input = HOL + theories Input\n")
      Files.writeString(source.resolve("Input.thy"),"theory Input imports Main begin end\n")
      Files.writeString(source.resolve("package.json"),"""{"format":"veri7vn.package/0","package":{"id":"test.input","version":"1.0.0","title":"Input","description":"Input"},"files":[{"path":"Input.thy","role":"source"}],"requires":[],"native":{"session":"Input","theories":["Input"]},"capabilities":[]}""")
      val store=new WorkspaceStore(Files.createTempDirectory("v7-ingress-store-"))
      val sources=new ManagedSources(store)
      val drafts=new ManagedDrafts(sources)
      def captured(name:String):NativeBuildInputs.Owned={
        assert(drafts.create("create_"+name,name,Intake.directory(source,Intake.Format.NativeDevelopment)).isInstanceOf[ManagedDrafts.Recorded])
        val head=sources.withHead(name)((head,_)=>head).get
        NativeBuildInputs.materialize(sources,name,head,
          ResourceBudget(BigInt(7),512L*1024*1024,4096,4,2048,64L*1024*1024,512,24,1)).get
      }
      val input=captured("first")
      val transport=new ControlledTransport(mode)
      val foreign=if(mode=="foreign_store")Some(new WorkspaceStore(Files.createTempDirectory("v7-ingress-foreign-")))else None
      val ingress=new NativeBuildIngress(transport,foreign.getOrElse(store),NativeBuildIngress.Limits(
        prepareWaitMillis=if(mode=="late_finish")500 else 5000,
        workerJoinMillis=if(mode=="late_finish")25 else 1000,maxOwnedInputs=1))
      try {
        var failure:Option[Throwable]=None
        var result:Option[ingress.PreparedInput]=None
        try result=Some(ingress.prepare(input,"Input.thy")) catch {case problem:Throwable=>failure=Some(problem)}
        if(mode=="normal"){
          assert(result.nonEmpty && failure.isEmpty && ingress.preparedCount==1 && transport.accepted)
          assert(input.isLive,"accepted input lost its owner")
          transport.retainConsumer()
          transport.releaseUnavailable=true
          var retained=false
          try ingress.releaseProducer(result.get) catch {case _:java.io.IOException=>retained=true}
          assert(retained && ingress.retirementCount==1 && input.isLive && transport.consumerLeases==1 && transport.nativePrepared,
            "failed producer release dropped its owner or independent consumer")
          transport.releaseUnavailable=false
          ingress.releaseProducer(result.get)
          val released=transport.releases
          ingress.releaseProducer(result.get)
          assert(transport.releases==released && transport.consumerLeases==1 && !input.isLive && ingress.preparedCount==0,
            "producer release changed consumer lease or was not idempotent")
          transport.releaseConsumer()
          // More authored builds than the native pool size must reuse capacity
          // after each independently owned result takes over its producer.
          for(index<-0 until 70){
            val next=captured("repeat_"+index)
            val prepared=ingress.prepare(next,"Input.thy")
            transport.retainConsumer()
            ingress.releaseProducer(prepared)
            assert(ingress.preparedCount==0 && ingress.retirementCount==0 && !next.isLive && transport.consumerLeases==1,
              "repeated producer release retained pool capacity")
            transport.releaseConsumer()
          }
        }else if(mode=="foreign_store"){
          assert(failure.nonEmpty && result.isEmpty && input.isLive && ingress.retirementCount==0 &&
            !transport.staged && !transport.nativePrepared,"foreign source owner crossed native ingress")
          input.close()
        }else{
          assert(failure.nonEmpty && result.isEmpty && ingress.preparedCount==0,"failed prepare published a handle")
          if(mode=="late_finish"){
            assert(failure.get.isInstanceOf[TimeoutException] && ingress.retirementCount==1 && input.isLive,
              "unfinished canceled transfer lost its tracked owner")
            transport.finishReturn.countDown()
            val deadline=System.nanoTime()+5L*1000*1000*1000
            while(ingress.retirementCount>0 && System.nanoTime()<deadline){
              try ingress.retryCleanup() catch {case _:NativeBuildIngress.CleanupPending=>Thread.sleep(5)}
            }
          }
          if(mode=="release_unavailable"){
            assert(ingress.retirementCount==1 && input.isLive && transport.nativePrepared,
              "indeterminate accepted lease was forgotten")
            val other=captured("second")
            var refused=false
            try ingress.prepare(other,"Input.thy") catch {case _:IllegalArgumentException=>refused=true}
            assert(refused && ingress.retirementCount==1,"capacity evicted unresolved ownership")
            other.close()
            transport.releaseUnavailable=false;ingress.retryCleanup()
          }
          assert(ingress.retirementCount==0 && !transport.nativePrepared && !transport.staged && !input.isLive,
            "reconciled prepare retained native or host ownership")
          assert(transport.discarded>0)
          if(mode=="lost_accept" || mode=="release_unavailable")assert(transport.releases>0,
            "accepted native lease was incorrectly cleaned by nonce discard alone")
        }
      } finally {
        transport.finishReturn.countDown();transport.releaseUnavailable=false
        ingress.close();input.close();foreign.foreach(_.close());store.close()
      }
      assert(!transport.nativePrepared && !transport.staged)
      if(mode=="normal")assert(transport.discarded==0,"settled accepted close recreated abandoned nonce")
    }
    println("NATIVE_BUILD_INGRESS_HOST_PASS accepted lost_begin lost_finish lost_accept late_offer retained_cleanup capacity_refusal")
  }
}
