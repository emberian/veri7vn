package veri7vn.runtime.service.effects

import veri7vn.runtime.connectors.mcp.McpIngress

/** Same-supervisor association returned by native packet upload, tied to the
  * original staged packet and its already installed configuration owner. */
private[runtime] final class NativeMcpPacket private[service](
    private val descriptor:McpIngress.PacketSource,
    private[service] val preparedHandle:BigInt,
    private[service] val supervisor:AnyRef,
    private val stagingOwner:McpIngress.StagedPacket,
    private val configuration:NativeMcpConfiguration) {
  require(preparedHandle>0 && preparedHandle.toString.length<=128,"native MCP packet handle bound")
  require(supervisor eq configuration.supervisor,"native MCP packet/configuration supervisor mismatch")
  private var consumed=false
  private[service] def claim(staged:McpIngress.StagedPacket):Unit=synchronized {
    require(!consumed && (staged eq stagingOwner) && staged.descriptor==descriptor &&
      (staged.installation.nativeConfiguration eq configuration),"native MCP packet association differs or consumed")
    consumed=true
  }
}
