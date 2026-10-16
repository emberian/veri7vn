package veri7vn.runtime.service

import java.nio.file.Path
import scala.language.unsafeNulls
import veri7vn.runtime.host.WorkspaceStore

/** Owns one workspace writer and one fixed resident native service. */
final class RuntimeService private(private val store:WorkspaceStore,
  val client:ResidentAuthorityService,private val buildIngress:NativeBuildIngress) extends AutoCloseable {
  val managedSources=new veri7vn.runtime.host.ManagedSources(store)
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
    try {
      supervisor=new ResidentSupervisor(sessionName,sessionRoots.map(p=>isabelle.Path.explode(p.toAbsolutePath.toString)),new DeploymentImages(images))
      ingress=new NativeBuildIngress(supervisor,store)
      val bridge=new ResidentNativeBridge(supervisor,store,Some(ingress))
      coordinator=new AuthorityCoordinator(store,bridge)
      val result=if(store.latestNative.isEmpty)coordinator.initialize() else coordinator.restore()
      require(result.isInstanceOf[AuthorityCoordinator.Committed],"native startup unavailable: "+result)
      new RuntimeService(store,new ResidentAuthorityService(supervisor,coordinator,Some(ingress)),ingress)
    } catch {case problem:Throwable=>
      def cleanup(action: => Unit):Unit=try action catch {case failure:Throwable=>problem.addSuppressed(failure)}
      if(ingress!=null)cleanup(ingress.close())
      if(supervisor!=null)cleanup(supervisor.close())
      if(coordinator!=null)cleanup(coordinator.close())
      cleanup(store.close())
      throw problem
    }
  }
}
