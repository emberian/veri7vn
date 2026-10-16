package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.util.concurrent.CountDownLatch

/** Actual bounded client/server protocol component test. It deliberately does not
  * stand in for native authorization: production handoff tests belong to the shared
  * effects service consumer and must use the same fixed executor. */
object LocalMcpClientTests {
  def main(args:Array[String]):Unit={
    val server=new LocalMcpServer()
    val client=new LocalMcpClient(server)
    try {
      val discovery=client.discover(1000)
      require(server.counter==0,"discovery called a tool")
      require(discovery.tool("annotations")==Map("readOnlyHint"->true))
      val selected=McpWorkflow.select(discovery,"counter.add")
      require(selected.tool=="counter.add" && server.counter==0,"selection called a tool")
      val probe=McpWorkflow.prepare(McpWorkflow.Operation.QualifyCounter,Some(discovery.schemaIdentity),2,"binding-17-epoch-1")
      val preview=McpWorkflow.describe(probe)
      require(preview.effect.contains("change the local counter") && preview.effect.contains("qualification"))
      require(server.counter==0,"qualification preview executed a probe")
      var outOfRange=false
      try McpWorkflow.prepare(McpWorkflow.Operation.InvokeCounter,Some(discovery.schemaIdentity),101,"binding-17-epoch-1")
      catch {case _:IllegalArgumentException=>outOfRange=true}
      require(outOfRange && server.counter==0,"out-of-range preview invoked or escaped validation")
      val first=client.invoke(discovery.schemaIdentity,2,"component-attempt-1",1000)
      require(server.counter==2 && first("isError")==false,"effectful fixture call failed")
      require(client.reconcile("component-attempt-1",1000).contains(first))
      require(server.counter==2,"lookup executed tool again")
      // This fixture explicitly supports attempt-key deduplication; generic MCP
      // servers need not. The executor itself never blindly repeats tools/call.
      require(client.invoke(discovery.schemaIdentity,2,"component-attempt-1",1000)==first)
      require(server.counter==2,"fixture protocol idempotency failed")
      var changedRetry=false
      try client.invoke(discovery.schemaIdentity,3,"component-attempt-1",1000)
      catch {case _:IllegalArgumentException=>changedRetry=true}
      require(changedRetry && server.counter==2,"same idempotency key accepted different arguments")
      server.changeSchema()
      var stale=false
      try client.invoke(discovery.schemaIdentity,1,"component-attempt-stale",1000)
      catch {case rejected:McpRejected=>stale=rejected.response.get("message").contains("schema_changed")}
      require(stale && server.counter==2,"changed schema executed stale preparation")
      var fractional=false
      try McpWire.integer(1.5) catch {case _:IllegalArgumentException=>fractional=true}
      require(fractional,"fractional argument truncated to integer")
      val current=client.discover(1000)
      require(current.schemaIdentity!=discovery.schemaIdentity && server.counter==2)
      val gate=new CountDownLatch(1);val reached=new CountDownLatch(1);server.holdAfterEffect(gate,reached)
      var uncertain=false
      try client.invoke(current.schemaIdentity,3,"component-attempt-unknown",30)
      catch {case _:java.util.concurrent.TimeoutException=>uncertain=true}
      require(uncertain && reached.await(5,java.util.concurrent.TimeUnit.SECONDS) && server.counter==5,
        "fixture must observe actual effect before testing lost acknowledgement")
      gate.countDown()
      require(client.reconcile("component-attempt-unknown",1000).nonEmpty)
      require(server.counter==5,"reconciliation duplicated unknown action")
      println("LOCAL_MCP_CLIENT_PASS")
    } finally server.close()
  }
}
