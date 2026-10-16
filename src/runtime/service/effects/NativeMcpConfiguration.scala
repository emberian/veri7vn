package veri7vn.runtime.service.effects

import veri7vn.runtime.connectors.mcp.McpIngress

/** Returned association with the actual native configuration owner. Only the
  * protected service bridge constructs it, after matching the response against
  * its retained upload and the same live supervisor. No UID-only factory exists.
  */
private[runtime] final class NativeMcpConfiguration private[service](
    private[runtime] val descriptor:McpIngress.ConfigurationSource,
    private[runtime] val sourceUID:BigInt,
    private[service] val nativeHandle:BigInt,
    private[service] val supervisor:AnyRef,
    private val stagingOwner:AnyRef) {
  require(sourceUID>0 && nativeHandle>0 && sourceUID.toString.length<=128 &&
    nativeHandle.toString.length<=128,"native MCP configuration association bound")
  private var consumed=false
  private[runtime] def claim(expected:McpIngress.ConfigurationSource,owner:AnyRef):BigInt=synchronized {
    require(!consumed && (owner eq stagingOwner) && descriptor==expected,
      "native MCP configuration association differs or consumed")
    consumed=true
    sourceUID
  }
}
