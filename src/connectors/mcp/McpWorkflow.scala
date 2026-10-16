package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import java.util.concurrent.atomic.AtomicLong
import veri7vn.runtime.connectors.{CapturedAcquisitionConfiguration,LocalAcquisitionBinding}
import veri7vn.runtime.effects.*
import veri7vn.sources.LocalSnapshot

/** These are proposal/observation data, not authorization or proof objects. */
object McpWorkflow {
  enum Operation { case Discover, QualifyCounter, InvokeCounter }
  enum Completion {
    case Unknown
    case ResponseReady(receipt:ExecutorReceipt,observation:Observation)
    case StatusOnly(receipt:ExecutorReceipt,reason:String,status:ResponseStatus)
  }
  final case class Discovery(schemaIdentity:String,tool:Map[String,Any])
  final case class Selection(discovery:Discovery,tool:String)
  enum ResponseStatus { case ConfirmedResponse, RejectedResponse }
  final case class Observation(operation:Operation,attempt:AttemptIdentity,
      schemaIdentity:Option[String],response:Map[String,Any],receiptArtifact:String,status:ResponseStatus)
  final class Prepared private[mcp] (val operation:Operation,val schemaIdentity:Option[String],
      val delta:Int,val configurationLabel:String,private[mcp] val packet:Map[String,Any]) {
    def bytes:Array[Byte]=McpWire.encode(packet)
    def inputArtifact:String=LocalSnapshot.hash(bytes)
    override def toString:String=s"McpPrepared($operation,<bounded input>)"
  }
  final case class Preview(operation:String,tool:Option[String],arguments:Map[String,Any],
      schemaIdentity:Option[String],effect:String,configuration:String)
  def describe(prepared:Prepared):Preview=Preview(prepared.operation.toString,
    if(prepared.operation==Operation.Discover)None else Some("counter.add"),
    if(prepared.operation==Operation.Discover)Map.empty else Map("delta"->prepared.delta),
    prepared.schemaIdentity,
    if(prepared.operation==Operation.Discover)"Initialize the fixed local server and list its tools."
    else s"Call counter.add and change the local counter by ${prepared.delta}. This includes qualification probes.",
    prepared.configurationLabel)
  def discovered(observation:Observation):Discovery={
    require(observation.operation==Operation.Discover && observation.schemaIdentity.nonEmpty,"MCP discovery observation required")
    Discovery(observation.schemaIdentity.get,McpWire.obj(observation.response("tool")))
  }
  private[mcp] def prepare(operation:Operation,schema:Option[String],delta:Int,configuration:String):Prepared={
    require(delta>= -100 && delta<=100,"MCP exact delta bound")
    require(schema.forall(_.matches("[0-9a-f]{64}")),"MCP schema identity")
    new Prepared(operation,schema,delta,configuration,Map("protocol"->"local-mcp/1",
      "operation"->operation.toString,"schema"->schema.getOrElse(""),"delta"->delta,"configuration"->configuration))
  }
  def select(discovered:Discovery,tool:String):Selection={
    require(tool=="counter.add" && discovered.tool.get("name").contains(tool),"MCP tool not discovered")
    Selection(discovered,tool)
  }
}

/** Fixed transport facade, with no generic remote URL/stdio launcher exposed. */
final class LocalMcpClient private[mcp] (private val server:LocalMcpServer) {
  private val ids=new AtomicLong(0)
  private def call(method:String,params:Map[String,Any],timeout:Long):Map[String,Any]={
    val id=ids.incrementAndGet()
    val request=McpWire.encode(Map("jsonrpc"->"2.0","id"->id,"method"->method,"params"->params))
    var response:Option[Array[Byte]]=None
    try {
      val bytes=server.exchange(request,timeout);response=Some(bytes)
      val result=McpWire.decode(bytes)
      require(result.get("jsonrpc").contains("2.0") && McpWire.integer(result("id"))==id,"MCP response correlation")
      if(result.contains("error"))throw new McpRejected(McpWire.obj(result("error")))
      McpWire.obj(result("result"))
    } finally {java.util.Arrays.fill(request,0.toByte);response.foreach(java.util.Arrays.fill(_,0.toByte))}
  }
  private[mcp] def discover(timeout:Long):McpWorkflow.Discovery={
    call("initialize",Map("protocolVersion"->"2025-03-26","capabilities"->Map.empty[String,Any],
      "clientInfo"->Map("name"->"veri7vn-local-mcp","version"->"1")),timeout)
    val result=call("tools/list",Map.empty,timeout)
    val tools=result("tools") match {case xs:List[?]=>xs;case _=>throw new IllegalArgumentException("MCP tools shape")}
    require(tools.size==1,"MCP fixed tool inventory")
    val tool=McpWire.obj(tools.head)
    require(tool.get("name").contains("counter.add"),"MCP fixed tool schema")
    McpWorkflow.Discovery(McpWire.text(result("mockSchemaIdentity")),tool)
  }
  private[mcp] def invoke(schema:String,delta:Int,key:String,timeout:Long):Map[String,Any]=
    call("tools/call",Map("name"->"counter.add","arguments"->Map("delta"->delta),
      "_meta"->Map("schema"->schema,"attempt"->key)),timeout)
  private[mcp] def reconcile(key:String,timeout:Long):Option[Map[String,Any]]={
    val result=call("mock/lookup",Map("attempt"->key),timeout)
    if(result.get("known").contains(true))Some(McpWire.obj(result("observation"))) else None
  }
}

/** Local configuration/resource owner only. Native ClaimStart and profile
  * installation are mandatory independent shared service checks. Creating or
  * selecting a preview here cannot call tools or produce a grant/permit. */
final class McpConnectorSession private[runtime] (
    private[mcp] val configuration:CapturedAcquisitionConfiguration,
    private[mcp] val binding:LocalAcquisitionBinding,private[mcp] val client:LocalMcpClient) extends AutoCloseable {
  import McpWorkflow.*
  @volatile private var executors=Vector.empty[McpExecutor]
  private val active=new java.util.concurrent.atomic.AtomicBoolean(true)
  @volatile private var sourceOwner:Option[WorkerResources]=None
  binding.register(new WorkerLifetime {
    def invalidate():Unit=McpConnectorSession.this.synchronized {executors.foreach(_.invalidateLocal())}
    def awaitStopped():Unit={
      val owned=McpConnectorSession.this.synchronized {executors}
      owned.foreach(_.releaseLocal())
      McpConnectorSession.this.synchronized {executors=Vector.empty}
    }
  })
  private[mcp] def attachSource(owner:WorkerResources):Unit=synchronized {
    require(sourceOwner.isEmpty,"MCP source ownership already attached");sourceOwner=Some(owner)
  }
  private[mcp] def current[A](action: => A):A={
    def checked:A=binding.withCurrent(configuration) {
      require(active.get(),"MCP configured source unavailable");action
    }
    sourceOwner match {case Some(owner)=>owner.withCurrent(checked);case None=>checked}
  }
  private[mcp] def invalidate():Unit={active.set(false);executors.foreach(_.invalidateLocal())}
  private[mcp] def register(executor:McpExecutor):Unit=current {synchronized {
    require(executors.size<32,"MCP session operation bound");executors :+= executor
  }}
  private[runtime] def discoverPreview:Prepared=current {
    McpWorkflow.prepare(Operation.Discover,None,0,configuration.observationConfiguration)
  }
  private[runtime] def preview(selection:Selection,operation:Operation,delta:Int):Prepared=current {
    require(operation!=Operation.Discover && selection.tool=="counter.add" &&
      selection.discovery.tool.get("name").contains("counter.add"),"MCP selected call operation")
    McpWorkflow.prepare(operation,Some(selection.discovery.schemaIdentity),delta,configuration.observationConfiguration)
  }
  private[runtime] def executor(prepared:Prepared,inputDraft:String,inputHead:String):McpExecutor=current {
    require(inputDraft.nonEmpty && inputDraft.length<=256 && inputHead.matches("[0-9a-f]{64}"),"MCP managed packet identity")
    require(prepared.configurationLabel==configuration.observationConfiguration,"MCP configuration changed")
    new McpExecutor(this,prepared,inputDraft,inputHead)
  }
  private[runtime] def retireForReplacement(next:CapturedAcquisitionConfiguration):Unit=binding.retireForReplacement(next)
  def close():Unit={invalidate();binding.retire()}
}
