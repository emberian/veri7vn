package veri7vn.runtime.connectors.mcp

import veri7vn.runtime.effects.WorkerResources
import veri7vn.runtime.connectors.{CapturedAcquisitionConfiguration,LocalAcquisitionBinding}

/** Closed local installed fixture. No external URL, command, bearer token or
  * credential value enters this transport. Its session still needs separately
  * installed operation profiles and generated native handoff permits. */
object LocalMcpFixture {
  final class Owned private[mcp] (private[mcp] val server:LocalMcpServer,
      private[runtime] val session:McpConnectorSession) extends AutoCloseable {
    private[mcp] var resources:Option[WorkerResources]=None
    private[mcp] def releaseFixture():Unit=try session.close() finally server.close()
    def close():Unit=resources match {
      case Some(owner)=>owner.close()
      case None=>releaseFixture()
    }
  }
  private[runtime] def open(configuration:CapturedAcquisitionConfiguration,
      binding:LocalAcquisitionBinding):Owned={
    require(configuration.endpoint=="local-mcp://counter" && configuration.schema=="mcp-counter/1",
      "MCP fixed local configuration")
    val server=new LocalMcpServer()
    try new Owned(server,new McpConnectorSession(configuration,binding,new LocalMcpClient(server)))
    catch {case error:Throwable=>server.close();throw error}
  }
}
