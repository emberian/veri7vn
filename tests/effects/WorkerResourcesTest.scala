package veri7vn.runtime.effects
import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.util.concurrent.{CountDownLatch,TimeUnit}
import java.util.concurrent.atomic.AtomicReference
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}
object WorkerResourcesTest {
  def main(args:Array[String]):Unit={
    val workspace=Files.createTempDirectory("effects-resources-store-")
    val store=new WorkspaceStore(workspace)
    try {
      val sources=new ManagedSources(store)
      val stage=sources.begin("resource-input",Array[Byte](1),"resource-draft",None) match {
        case ManagedSources.Fresh(value)=>value;case other=>throw new IllegalStateException(other.toString)
      }
      val member=stage.put(Array[Byte](4,5,6))
      assert(stage.commit(member,Vector(member)).isInstanceOf[ManagedSources.Published])
      val budget=ResourceBudget(1,128,4,4,4,128,128,8,2)
      def denied(action: => Unit):Boolean={
        try {action;false} catch {
          case _:IllegalArgumentException=>true
          case _:IllegalStateException=>true
        }
      }
      def retainedInspection(erase:Boolean):Unit={
        val draft=if(erase)"historical-forget" else "historical-revoke"
        val initial=sources.begin(draft+"-initial",Array[Byte](1),draft,None) match {
          case ManagedSources.Fresh(value)=>value
          case other=>throw new IllegalStateException(other.toString)
        }
        val original=initial.put(Array[Byte](4,5,6))
        assert(initial.commit(original,Vector(original)).isInstanceOf[ManagedSources.Published])
        val (owner,parsed,originalView)=WorkerResources.withCurrentCapture(sources,draft,original,budget) {capture=>
          val originalView=capture.read(original,3).readOnly
          val root=capture.resources.reserveRoot[Vector[Int]](16)
          root.install(Vector.tabulate(originalView.limit())(i=>originalView.get(i).toInt))
          assert(root.withValue(_.sum)==15 && root.withRetainedValue(_.sum)==15)
          (capture.resources,root,originalView)
        }.get
        try {
          val edit=sources.begin(draft+"-edit",Array[Byte](2),draft,Some(original)) match {
            case ManagedSources.Fresh(value)=>value
            case other=>throw new IllegalStateException(other.toString)
          }
          val updated=edit.put(Array[Byte](8,9))
          assert(edit.commit(updated,Vector(updated)).isInstanceOf[ManagedSources.Published])
          assert(denied(parsed.withValue(_=>())))
          assert(parsed.withRetainedValue(_==Vector(4,5,6)))
          if(erase)sources.forget(draft) else assert(store.revokeSource(draft))
          assert(denied(parsed.withValue(_=>())))
          assert(denied(parsed.withRetainedValue(_=>())))
        } finally owner.close()
        assert(denied(parsed.withRetainedValue(_=>())))
        assert((0 until originalView.limit()).forall(originalView.get(_)==0.toByte))
      }
      retainedInspection(false)
      retainedInspection(true)
      def transferLifetime():Unit={
        val draft="tracked-transfer"
        val initial=sources.begin("transfer-initial",Array[Byte](1),draft,None) match {
          case ManagedSources.Fresh(value)=>value
          case other=>throw new IllegalStateException(other.toString)
        }
        val original=initial.put(Array[Byte](4,5,6))
        assert(initial.commit(original,Vector(original)).isInstanceOf[ManagedSources.Published])
        val (owner,parsed)=WorkerResources.withCurrentCapture(sources,draft,original,budget) {capture=>
          val bytes=capture.read(original,3).readOnly
          val root=capture.resources.reserveRoot[Vector[Int]](16)
          root.install(Vector.tabulate(bytes.limit())(i=>bytes.get(i).toInt))
          (capture.resources,root)
        }.get
        val entered=new CountDownLatch(1)
        val stop=new CountDownLatch(1)
        val failure=new AtomicReference[Throwable]()
        val borrowed=new AtomicReference[java.nio.ByteBuffer]()
        class TransferJob extends WorkerLifetime {
          val thread=new Thread(()=>{
            try {
              (0 until 4).foreach {_=>
                var completedView:java.nio.ByteBuffer=null
                owner.withTransfer(this,3)(parsed.withValue(_.map(_.toByte).toArray)) {view=>
                  completedView=view;assert(view.get(0)==4.toByte)
                }
                assert((0 until completedView.limit()).forall(completedView.get(_)==0.toByte))
              }
              owner.withTransfer(this,3)(parsed.withValue(_.map(_.toByte).toArray)) {view=>
              borrowed.set(view);entered.countDown();require(stop.await(5,TimeUnit.SECONDS))
              // Forget must signal/join outside the store monitor, and it must
              // join this consumer before clearing the registered transfer clone.
              store.currentRevision
              assert((0 until view.limit()).map(view.get(_)).toVector==Vector[Byte](4,5,6))
              }
            } catch {case problem:Throwable=>failure.compareAndSet(null,problem);entered.countDown()}
            ()
          })
          def invalidate():Unit=stop.countDown()
          def awaitStopped():Unit={thread.join(4000);require(!thread.isAlive,"transfer joined while source lock held")}
        }
        val job=new TransferJob
        try {
          var evaluated=false
          assert(denied(owner.withTransfer(job,3) {evaluated=true;Array[Byte](4,5,6)}(_=>())))
          assert(!evaluated)
          owner.attachWorker(job);job.thread.start();assert(entered.await(3,TimeUnit.SECONDS))
          Option(failure.get()).foreach(throw _)
          val edited=new CountDownLatch(1)
          val editThread=new Thread(()=>{
            try {
              val stage=sources.begin("transfer-edit",Array[Byte](2),draft,Some(original)) match {
                case ManagedSources.Fresh(value)=>value
                case other=>throw new IllegalStateException(other.toString)
              }
              val updated=stage.put(Array[Byte](8,9))
              assert(stage.commit(updated,Vector(updated)).isInstanceOf[ManagedSources.Published])
              assert(parsed.withRetainedValue(_.sum)==15)
            } catch {case problem:Throwable=>failure.compareAndSet(null,problem)}
            finally edited.countDown()
            ()
          })
          editThread.start()
          val sourceUnlocked=edited.await(3,TimeUnit.SECONDS)
          if(!sourceUnlocked)job.invalidate()
          editThread.join(4000)
          assert(sourceUnlocked,"native transfer consumer retained source monitor")
          Option(failure.get()).foreach(throw _)
          val forgotten=new CountDownLatch(1)
          val forgetThread=new Thread(()=>{
            try sources.forget(draft)
            catch {case problem:Throwable=>failure.compareAndSet(null,problem)}
            finally forgotten.countDown()
            ()
          })
          forgetThread.start();assert(forgotten.await(5,TimeUnit.SECONDS));forgetThread.join(1000)
          job.thread.join(1000);Option(failure.get()).foreach(throw _)
          assert(!job.thread.isAlive && !forgetThread.isAlive)
          val old=borrowed.get();assert((0 until old.limit()).forall(old.get(_)==0.toByte))
        } finally {job.invalidate();owner.close()}
      }
      transferLifetime()
      // A real partial derivative exists when the producer fails. The same
      // durable registration clears bytes and removes only its inventoried paths.
      var failedDirectory:Path=null
      var failedView:java.nio.ByteBuffer=null
      var partialRejected=false
      try WorkerResources.withCurrentCapture(sources,"resource-draft",member,budget) {capture=>
        failedView=capture.read(member,3).readOnly
        failedDirectory=capture.resources.createDirectory()
        val slot=capture.resources.reserveFile("partial/input",3)
        slot.writeFrom {
          Files.write(slot.path,Array[Byte](4))
          throw new IllegalStateException("injected partial producer failure")
        }
      } catch {case failure:IllegalStateException=>
        assert(failure.getMessage=="injected partial producer failure");partialRejected=true
      }
      assert(partialRejected && !Files.exists(failedDirectory))
      assert((0 until failedView.limit()).forall(failedView.get(_)==0.toByte))
      val captured=new CountDownLatch(1);val releaseCapture=new CountDownLatch(1)
      val forgetStarted=new CountDownLatch(1);val forgotten=new CountDownLatch(1)
      val workerCancel=new CountDownLatch(1);val workerStopped=new CountDownLatch(1)
      val error=new AtomicReference[Throwable]()
      val resource=new AtomicReference[WorkerResources]()
      val view=new AtomicReference[java.nio.ByteBuffer]()
      val directory=new AtomicReference[Path]()
      val worker=new Thread(()=>{
        try {workerCancel.await();store.currentRevision;workerStopped.countDown()}
        catch {case failure:Throwable=>error.compareAndSet(null,failure);()}
        ()
      })
      val captureThread=new Thread(()=>{
        try WorkerResources.withCurrentCapture(sources,"resource-draft",member,budget) {capture=>
          val owner=capture.resources;resource.set(owner)
          view.set(capture.read(member,3).readOnly)
          val parsed=owner.reserveRoot[Vector[Int]](16);parsed.install(Vector(4,5,6))
          assert(parsed.withValue(_.sum)==15)
          val root=owner.createDirectory();directory.set(root)
          assert(root.getParent==workspace.resolve("managed-workers"))
          owner.reserveFile("nested/input",3).writeFrom(Array[Byte](4,5,6))
          owner.attachWorker(new WorkerLifetime {
            def invalidate():Unit=workerCancel.countDown()
            def awaitStopped():Unit={worker.join(3000);require(!worker.isAlive,"worker join retained source lock")}
          })
          worker.start();captured.countDown();require(releaseCapture.await(3,TimeUnit.SECONDS))
        } catch {case failure:Throwable=>error.compareAndSet(null,failure);captured.countDown()}
        ()
      })
      val forgetThread=new Thread(()=>{
        try {forgetStarted.countDown();sources.forget("resource-draft");forgotten.countDown()}
        catch {case failure:Throwable=>error.compareAndSet(null,failure);forgotten.countDown()}
        ()
      })
      captureThread.start();assert(captured.await(3,TimeUnit.SECONDS));forgetThread.start()
      assert(forgetStarted.await(3,TimeUnit.SECONDS))
      // The capture still owns the actual source lock: Forget cannot erase its files.
      assert(!forgotten.await(100,TimeUnit.MILLISECONDS))
      releaseCapture.countDown();captureThread.join(4000);forgetThread.join(4000)
      Option(error.get()).foreach(throw _)
      assert(!captureThread.isAlive && !forgetThread.isAlive && workerStopped.getCount==0)
      assert(!resource.get().isLive && !Files.exists(directory.get()))
      val old=view.get();assert((0 until old.limit()).forall(old.get(_)==0.toByte))
      var lateDenied=false
      try resource.get().withCurrent {throw new AssertionError("late handoff executed")}
      catch {case _:IllegalArgumentException=>lateDenied=true;case _:IllegalStateException=>lateDenied=true}
      assert(lateDenied && WorkerResources.withCurrentCapture(sources,"resource-draft",member,budget)(_=>()).isEmpty)
    } finally store.close()
    println("VERI7VN_EFFECTS worker_resources PASS")
  }
}
