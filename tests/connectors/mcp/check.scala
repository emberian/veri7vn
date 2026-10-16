import scala.language.unsafeNulls
import java.nio.file.Files
@main def mcpConnectorCheck():Unit={
  val out=Files.createTempDirectory("mcp-connector-classes-")
  val sources=List("src/runtime/host/WorkspaceStore.scala","src/runtime/host/ManagedSources.scala",
    "src/runtime/effects/WorkerResources.scala","src/runtime/effects/OperationProfile.scala",
    "src/runtime/effects/Executor.scala","src/sources/import/LocalSnapshot.scala",
    "src/packages/intake/Intake.scala","src/packages/lifecycle/InertJSON.scala",
    "src/connectors/LocalAcquisitionBinding.scala",
    "src/connectors/mcp/LocalMcp.scala","src/connectors/mcp/McpWorkflow.scala",
    "src/connectors/mcp/McpObservationRecord.scala","src/connectors/mcp/McpExecutor.scala","src/connectors/mcp/LocalMcpFixture.scala","src/connectors/mcp/McpIngress.scala",
    "src/runtime/service/effects/NativeMcpConfiguration.scala","src/runtime/service/effects/NativeMcpPacket.scala","src/runtime/service/effects/NativeEffectCommand.scala",
    "tests/runtime/service/effects/NativeEffectCommandTests.scala",
    "tests/connectors/mcp/LocalMcpClientTests.scala","tests/connectors/mcp/McpManagedConfigurationTests.scala","tests/connectors/mcp/McpObservationRecordTests.scala")
  val args=(List("-classpath",System.getProperty("java.class.path"),"-d",out.toString)++sources).toArray
  require(!dotty.tools.dotc.Main.process(args).hasErrors,"MCP connector compilation")
  val loader=new java.net.URLClassLoader(Array(out.toUri.toURL),getClass.getClassLoader)
  try List("veri7vn.runtime.connectors.mcp.LocalMcpClientTests","veri7vn.runtime.connectors.mcp.McpManagedConfigurationTests",
    "veri7vn.runtime.service.effects.NativeEffectCommandTests","veri7vn.runtime.connectors.mcp.McpObservationRecordTests").foreach(name=>
    loader.loadClass(name).getMethod("main",classOf[Array[String]]).invoke(null,Array.empty[String].asInstanceOf[Object])) finally loader.close()
}
