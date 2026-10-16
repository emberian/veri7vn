package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.host.{WorkspaceStore,ManagedSources}

object McpManagedConfigurationTests {
  def main(args:Array[String]):Unit={
    val directory=Files.createTempDirectory("mcp-managed-config-")
    val store=new WorkspaceStore(directory)
    try {
      val sources=new ManagedSources(store)
      val raw=McpWire.encode(Map("protocol"->"local-mcp/1","endpoint"->"local-mcp://counter",
        "schema"->"mcp-counter/1","mapping"->"fixed-counter/1","quality"->"source-response/1"))
      val stage=sources.begin("mcp-config",Array[Byte](1),"mcp-configuration",None) match {
        case ManagedSources.Fresh(value)=>value;case _=>sys.error("configuration stage")
      }
      val member=stage.put(raw)
      require(stage.commit(member,Vector(member)).isInstanceOf[ManagedSources.Published])
      val installation=McpIngress.stage(sources,"mcp-configuration",member,member,1,18,0,0).get
      try {
        installation.withBytes {view=>require(view.remaining()==raw.length)}
        require(installation.descriptor.member==member && installation.descriptor.sha256==member)
        require(installation.toString=="McpStagedConfiguration(<managed protected source>)")
        val edited=sources.begin("mcp-config-edit",Array[Byte](2),"mcp-configuration",Some(member)) match {
          case ManagedSources.Fresh(value)=>value;case _=>sys.error("configuration edit stage")
        }
        val nextMember=edited.put(raw++Array[Byte](10))
        require(edited.commit(nextMember,Vector(nextMember)).isInstanceOf[ManagedSources.Published])
        var oldHeadDenied=false
        try installation.withBytes(_=>())
        catch {case _:IllegalArgumentException=>oldHeadDenied=true;case _:IllegalStateException=>oldHeadDenied=true}
        require(oldHeadDenied,"changed configuration source head reused old preparation")
        // Retirement of the actual managed configuration reaches the owned local
        // server/session. A retained proposal object does not restore access.
        store.revokeSource("mcp-configuration")
        var denied=false
        try installation.withBytes(_=>())
        catch {case _:IllegalArgumentException=>denied=true;case _:IllegalStateException=>denied=true}
        require(denied,"forgotten configuration remained usable")
      } finally installation.close()
      println("MCP_MANAGED_CONFIGURATION_PASS")
    } finally store.close()
  }
}
