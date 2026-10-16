package veri7vn.runtime.service

import scala.language.unsafeNulls
import veri7vn.runtime.host.WorkspaceStore
import java.nio.file.Files

/** Real SQLite store, controlled bridge fault seam. These are NOT generated HOL tests. */
object CoordinatorTests {
  import AuthorityCoordinator.*
  private[service] final class ControlledBridge(store: WorkspaceStore, phase: String,
    sourceGuard:Option[WorkspaceStore.NativeSourceGuard]=None,ackHook:()=>Unit=()=>()) extends NativeBridge {
    var prepares=0
    var invalidations=0
    private[service] override def invalidate():Unit={invalidations+=1}
    private[service] def recover(record: WorkspaceStore.NativeRecord)=true
    private[service] def prepare(token: EventToken): Either[String,Prepared] = {
      prepares+=1
      if(phase=="prepare") throw new IllegalStateException("native prepare interrupted")
      Right(new Prepared("operation",store.latestNative.get.sequence,0,0,Array[Byte](1),Array[Byte](2),sourceGuard=sourceGuard))
    }
    private[service] def validatePrecommit(p: Prepared)=true
    private[service] def acknowledge(p: Prepared): Boolean = {
      ackHook()
      if(phase=="ack") throw new IllegalStateException("native acknowledgement interrupted")
      if(phase=="interrupt") throw new InterruptedException("native cancellation")
      true
    }
  }
  def main(args: Array[String]): Unit = {
    for(editBefore<-Vector(true,false)){
      val store=new WorkspaceStore(Files.createTempDirectory("veri7vn-source-commit-race-"))
      require(store.commitNative("seed",0,0,0,Array[Byte](0),Array[Byte](0)).nonEmpty)
      val original="a"*64;val changed="b"*64
      require(store.compareAndAppend("draft",None,original))
      val registration=store.registerManagedResource("draft",original,new WorkspaceStore.ManagedResourceOwner {
        def invalidate():Unit=()
        def stopAndRelease():Unit=()
      })
      val ackEntered=new java.util.concurrent.CountDownLatch(1)
      val releaseAck=new java.util.concurrent.CountDownLatch(1)
      val bridge=new ControlledBridge(store,"normal",Some(registration.currentGuard),()=>{
        ackEntered.countDown();require(releaseAck.await(5,java.util.concurrent.TimeUnit.SECONDS))
      })
      val coordinator=new AuthorityCoordinator(store,bridge)
      require(coordinator.restore()==Committed(1,"seed"))
      if(editBefore){
        require(store.compareAndAppend("draft",Some(original),changed))
        var denied=false
        try coordinator.submit(new EventToken("guarded",NativeAdmission("test")))
        catch {case _:IllegalArgumentException=>denied=true}
        require(denied && store.latestNative.get.sequence==1,"stale source committed")
      }else{
        val pool=java.util.concurrent.Executors.newFixedThreadPool(2)
        try {
          val committed=pool.submit(new java.util.concurrent.Callable[Outcome]{def call():Outcome=
            coordinator.submit(new EventToken("guarded",NativeAdmission("test")))})
          require(ackEntered.await(5,java.util.concurrent.TimeUnit.SECONDS))
          val editing=new java.util.concurrent.CountDownLatch(1)
          val edit=pool.submit(new java.util.concurrent.Callable[Boolean]{def call():Boolean={
            editing.countDown();store.compareAndAppend("draft",Some(original),changed)}})
          require(editing.await(5,java.util.concurrent.TimeUnit.SECONDS))
          var blocked=false
          try edit.get(50,java.util.concurrent.TimeUnit.MILLISECONDS)
          catch {case _:java.util.concurrent.TimeoutException=>blocked=true}
          require(blocked,"source edit slipped between commit and acknowledgement")
          releaseAck.countDown()
          require(committed.get(5,java.util.concurrent.TimeUnit.SECONDS).isInstanceOf[Committed])
          require(edit.get(5,java.util.concurrent.TimeUnit.SECONDS))
        }finally {releaseAck.countDown();pool.shutdownNow();pool.awaitTermination(5,java.util.concurrent.TimeUnit.SECONDS)}
      }
      coordinator.close();registration.release();store.close()
    }
    for(phase<-Vector("prepare","commit_after","ack","interrupt")) {
      val root=Files.createTempDirectory("veri7vn-coordinator-fault-")
      var store=new WorkspaceStore(root)
      require(store.commitNative("seed",0,0,0,Array[Byte](0),Array[Byte](0)).nonEmpty)
      val bridge=new ControlledBridge(store,phase)
      val coordinator=new AuthorityCoordinator(store,bridge)
      require(coordinator.restore()==Committed(1,"seed"))
      coordinator.requireReady()
      var liveRestoreRejected=false
      try coordinator.restore() catch {case _:IllegalArgumentException=>liveRestoreRejected=true}
      require(liveRestoreRejected,"live restore bypassed startup boundary")
      coordinator.requireReady()
      var duplicate=false
      try new AuthorityCoordinator(store,bridge) catch {case _: IllegalArgumentException=>duplicate=true}
      require(duplicate,"second authority coordinator accepted")
      if(phase=="commit_after") store.afterNativeCommit=()=>throw new IllegalStateException("lost after DB commit")
      var failed=false
      try coordinator.submit(new EventToken("native-owned",AuthenticatedPolicy("fixture")))
      catch {case _: IllegalStateException=>failed=true; case _: InterruptedException=>failed=true}
      require(failed)
      require(coordinator.submit(new EventToken("never-retry",AuthenticatedPolicy("fixture"))).isInstanceOf[Unavailable])
      require(bridge.prepares==1,"event retried after indeterminate failure")
      require(bridge.invalidations==1,"failed native worker was not invalidated")
      require(store.latestNative.get.sequence==(if(phase=="prepare")1 else 2))
      coordinator.close(); store.close(); store=new WorkspaceStore(root)
      val unavailable=new AuthorityCoordinator(store,MissingNativeBridge)
      require(unavailable.restore().isInstanceOf[Unavailable],"checkpoint bytes minted native authority")
      unavailable.close(); store.close()
    }
    var oversize=false
    try new Prepared("oversize",0,0,0,Array[Byte](0),new Array[Byte](1024*1024+1))
    catch {case _:IllegalArgumentException=>oversize=true}
    require(oversize,"unrestorable checkpoint accepted")
    println("COORDINATOR_FAULT_PASS prepare committed_without_ack ack_throw interruption fail_closed no_retry missing_native_restore")
  }
}
