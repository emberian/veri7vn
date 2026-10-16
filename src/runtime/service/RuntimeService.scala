package veri7vn.runtime.service

import java.nio.file.Path
import scala.language.unsafeNulls
import veri7vn.runtime.host.WorkspaceStore

/** Owns one workspace writer and one fixed resident native service. */
final class RuntimeService private(private val store:WorkspaceStore,
  val client:ResidentAuthorityService,private val buildIngress:NativeBuildIngress,private val bridge:ResidentNativeBridge,val managedSources:veri7vn.runtime.host.ManagedSources) extends AutoCloseable {
  lazy val search=client.search
  def producerCleanupFailures:Vector[ProducerReleaseQueue.Failure]=bridge.producerCleanupFailures
  def retryProducerCleanup():Unit=bridge.retryProducerCleanup()
  def sourceCleanupFailures:Vector[(BigInt,Int,String)]=bridge.sourceCleanupFailures
  def retrySourceCleanup():Unit=bridge.retrySourceCleanup()
  def close():Unit={
    var failure:Throwable=null
    try buildIngress.close() catch {case problem:Throwable=>failure=problem}
    try client.close() catch {case problem:Throwable=>if(failure==null)failure=problem else failure.addSuppressed(problem)}
    try store.close() catch {case problem:Throwable=>if(failure==null)failure=problem else failure.addSuppressed(problem)}
    if(failure!=null)throw failure
  }
}
object RuntimeService {
  val sessionName="Veri7vn_Runtime_Service"
  /** Requires an already built installed session; never builds or loads mutable ML. */
  def open(workspace:Path,images:Path,sessionRoots:List[Path]):RuntimeService={
    val store=new WorkspaceStore(workspace)
    var supervisor:ResidentSupervisor=null
    var coordinator:AuthorityCoordinator=null
    var ingress:NativeBuildIngress=null
    var history:veri7vn.runtime.service.build.BuildHistory=null
    try {
      val sources=new veri7vn.runtime.host.ManagedSources(store)
      history=new veri7vn.runtime.service.build.BuildHistory(store,sources)
      supervisor=new ResidentSupervisor(sessionName,sessionRoots.map(p=>isabelle.Path.explode(p.toAbsolutePath.toString)),new DeploymentImages(images))
      ingress=new NativeBuildIngress(supervisor,store)
      val bridge=new ResidentNativeBridge(supervisor,store,Some(ingress))
      coordinator=new AuthorityCoordinator(store,bridge)
      val result=if(store.latestNative.isEmpty)coordinator.initialize() else coordinator.restore()
      require(result.isInstanceOf[AuthorityCoordinator.Committed],"native startup unavailable: "+result)
      new RuntimeService(store,new ResidentAuthorityService(supervisor,coordinator,Some(ingress),Some(sources),Some(history)),ingress,bridge,sources)
    } catch {case problem:Throwable=>
      def cleanup(action: => Unit):Unit=try action catch {case failure:Throwable=>problem.addSuppressed(failure)}
      if(history!=null)cleanup(history.close())
      if(ingress!=null)cleanup(ingress.close())
      if(supervisor!=null)cleanup(supervisor.close())
      if(coordinator!=null)cleanup(coordinator.close())
      cleanup(store.close())
      throw problem
    }
  }
}
