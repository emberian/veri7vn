package veri7vn.runtime.host
import scala.language.unsafeNulls
import java.nio.file.Files
object ManagedSourcesTests {
  def main(args:Array[String]):Unit={
    import ManagedSources.*
    val root=Files.createTempDirectory("veri7vn-managed-sources-")
    var store=new WorkspaceStore(root)
    var managed=new ManagedSources(store,Limits(1024,4096,16))
    val request=Array[Byte](1,2)
    val first=managed.begin("op1",request,"draft",None).asInstanceOf[Fresh].stage
    request(0)=9
    val blob=first.put(Array[Byte](10,20))
    val oldOnly=first.put(Array[Byte](99))
    val manifest=first.put("manifest".getBytes)
    require(first.commit(manifest,Vector(manifest,blob,oldOnly))==Published(Receipt("op1")))
    require(managed.begin("op1",Array[Byte](1,2),"draft",None)==Replay(Receipt("op1")))
    require(managed.begin("op1",Array[Byte](1,3),"draft",None)==IdentityMismatch)
    var expired:Option[ManagedSources#ReadScope]=None
    require(managed.withHead("draft"){(head,scope)=>expired=Some(scope);require(head==manifest);scope.read(blob,2).toVector}.contains(Vector[Byte](10,20)))
    var denied=false;try expired.get.read(blob,2) catch {case _:IllegalArgumentException=>denied=true};require(denied)
    val shared=managed.begin("op2",Array[Byte](3),"other",None).asInstanceOf[Fresh].stage
    require(shared.put(Array[Byte](10,20))==blob)
    val sharedManifest=shared.put("other".getBytes)
    require(shared.commit(sharedManifest,Vector(sharedManifest,blob))==Published(Receipt("op2")))
    val edit=managed.begin("edit",Array[Byte](5),"draft",Some(manifest)).asInstanceOf[Fresh].stage
    val nextManifest=edit.put("manifest2".getBytes)
    require(edit.commit(nextManifest,Vector(nextManifest,blob))==Published(Receipt("edit")))
    managed.withHead("draft"){(head,scope)=>
      require(head==nextManifest && scope.read(blob,2).toVector==Vector[Byte](10,20))
      var oldDenied=false
      try scope.read(oldOnly,1) catch {case _:IllegalArgumentException=>oldDenied=true}
      require(oldDenied,"old object authorized under new manifest")
    }
    require(edit.read(oldOnly,1).toVector==Vector[Byte](99),"explicit retained-stage access lost")
    val stale=managed.begin("stale",Array[Byte](4),"draft",None).asInstanceOf[Fresh].stage
    val staleManifest=stale.put("stale".getBytes)
    require(stale.commit(staleManifest,Vector(staleManifest))==Conflict)
    require(managed.begin("stale",Array[Byte](4),"draft",None)==Replay(Receipt("stale",OperationStatus.Conflict)))
    require(managed.forget("draft")==StorageErased("draft"))
    require(managed.begin("op1",Array[Byte](9),"draft",None)==Unavailable)
    require(managed.withHead("draft")((_,_)=>sys.error("forgotten callback")).isEmpty)
    denied=false;try first.read(blob,2) catch {case _:IllegalArgumentException=>denied=true};require(denied)
    require(shared.read(blob,2).toVector==Vector[Byte](10,20),"shared object erased")
    store.close();store=new WorkspaceStore(root);managed=new ManagedSources(store,Limits(1024,4096,16))
    require(managed.begin("op1",Array[Byte](1,2),"draft",None)==Unavailable,"forgotten operation revived")
    require(managed.withHead("other")((_,scope)=>scope.read(blob,2).toVector).contains(Vector[Byte](10,20)))
    managed.forget("other")
    require(!Files.exists(root.resolve("managed-sources/objects").resolve(blob)),"unreferenced managed object retained")
    store.close()
    val raceStore=new WorkspaceStore(Files.createTempDirectory("veri7vn-managed-budget-"))
    val race=new ManagedSources(raceStore,Limits(4,4,16))
    val entered=new java.util.concurrent.CountDownLatch(2)
    val release=new java.util.concurrent.CountDownLatch(1)
    race.afterBeginPreflight=()=>{entered.countDown();require(release.await(5,java.util.concurrent.TimeUnit.SECONDS))}
    val outcomes=new java.util.concurrent.LinkedBlockingQueue[String]()
    def contender(id:String)=new Thread(()=>{
      try {race.begin(id,Array[Byte](1,2,3),"draft",None);outcomes.add("fresh")}
      catch {case _:IllegalArgumentException=>outcomes.add("bounded")}
      ()
    })
    val a=contender("a");val b=contender("b");a.start();b.start()
    require(entered.await(5,java.util.concurrent.TimeUnit.SECONDS));release.countDown()
    a.join(5000);b.join(5000);require(!a.isAlive && !b.isAlive)
    require(Vector(outcomes.poll(),outcomes.poll()).sorted==Vector("bounded","fresh"),"concurrent request budget exceeded")
    raceStore.close()
    println("MANAGED_SOURCES_PASS exact_replay mismatch protected_scope cas forget_restart shared_refs")
  }
}
