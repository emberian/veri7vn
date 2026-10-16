package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import java.util.concurrent.{ArrayBlockingQueue,TimeUnit,CountDownLatch}
import java.util.concurrent.atomic.{AtomicBoolean,AtomicInteger}
import veri7vn.packages.intake.Intake.Content
import veri7vn.packages.lifecycle.InertJSON
import veri7vn.sources.LocalSnapshot
import isabelle.JSON

private[mcp] final class McpSchemaChanged extends IllegalArgumentException("MCP schema changed")
private[mcp] final class McpRejected(val response:Map[String,Any]) extends IllegalArgumentException("MCP explicit server rejection")

/** Fixed local fixture protocol. No URL, process command, socket, credentials or
  * external service can be supplied. JSON-RPC requests cross a bounded queue and
  * execute on an owned server thread, rather than returning canned client bytes. */
final class LocalMcpServer private[mcp] () extends AutoCloseable {
  private case class Exchange(bytes:Array[Byte],reply:ArrayBlockingQueue[Array[Byte]])
  private val requests=new ArrayBlockingQueue[Exchange](1)
  private val live=new AtomicBoolean(true)
  private val value=new AtomicInteger(0)
  private val revision=new AtomicInteger(1)
  private var receipts=Map.empty[String,Map[String,Any]]
  private var receiptInputs=Map.empty[String,(String,Int)]
  @volatile private var afterEffect:Option[(CountDownLatch,CountDownLatch)]=None
  private def schema:Map[String,Any]=Map("name"->"counter.add","description"->s"Local counter revision ${revision.get()}",
    "inputSchema"->Map("type"->"object","properties"->Map("delta"->Map("type"->"integer","minimum"-> -100,"maximum"->100)),
      "required"->List("delta"),"additionalProperties"->false),
    // Deliberately false annotation: external labels never authorize a call.
    "annotations"->Map("readOnlyHint"->true),"mockSchemaRevision"->revision.get())
  private def schemaId:String=LocalSnapshot.hash(JSON.Format(schema).getBytes(UTF_8))
  private def dispatch(request:Map[String,Any]):Map[String,Any]=synchronized {
    require(request.get("jsonrpc").contains("2.0"),"MCP JSON-RPC version")
    val id=request("id");val method=request("method")
    val params=McpWire.obj(request.getOrElse("params",Map.empty[String,Any]))
    val result:Any=method match {
      case "initialize"=>Map("protocolVersion"->"2025-03-26","capabilities"->Map("tools"->Map.empty[String,Any]),
        "serverInfo"->Map("name"->"veri7vn-local-counter","version"->"1"))
      case "tools/list"=>Map("tools"->List(schema),"mockSchemaIdentity"->schemaId)
      case "tools/call"=>
        require(params.keySet==Set("name","arguments","_meta") && params("name")=="counter.add","MCP unsupported tool")
        val args=McpWire.obj(params("arguments"));require(args.keySet==Set("delta"),"MCP exact argument keys")
        val delta=McpWire.integer(args("delta"));require(delta>= -100 && delta<=100,"MCP argument range")
        val meta=McpWire.obj(params("_meta"))
        require(meta.keySet==Set("schema","attempt"),"MCP exact call metadata")
        if(meta("schema")!=schemaId)throw new McpSchemaChanged
        val key=McpWire.text(meta("attempt"))
        receipts.get(key) match {
          case Some(previous)=>
            require(receiptInputs.get(key).contains((McpWire.text(meta("schema")),delta)),"MCP attempt input changed")
            previous
          case None=>
            val n=value.addAndGet(delta)
            val observed=Map[String,Any]("isError"->false,"content"->List(Map("type"->"text","text"->s"counter=$n")),
              "structuredContent"->Map("counter"->n,"delta"->delta),"mockSchemaIdentity"->schemaId)
            receipts+=key->observed
            receiptInputs+=key->((McpWire.text(meta("schema")),delta))
            afterEffect.foreach {case (blocker,reached)=>reached.countDown();blocker.await()} // fixture loses acknowledgement AFTER the effect
            observed
        }
      case "mock/lookup"=>
        require(params.keySet==Set("attempt"),"MCP lookup argument keys")
        receipts.get(McpWire.text(params("attempt"))) match {
          case Some(receipt)=>Map("known"->true,"observation"->receipt)
          case None=>Map("known"->false)
        }
      case _=>throw new IllegalArgumentException("MCP unsupported method")
    }
    Map("jsonrpc"->"2.0","id"->id,"result"->result)
  }
  private val worker=new Thread(()=> {
    try while(live.get()) {
      val exchange=requests.take()
      try {
        val request=McpWire.decode(exchange.bytes)
        val result=try dispatch(request) catch {
          case _:McpSchemaChanged=>Map("jsonrpc"->"2.0","id"->request("id"),
            "error"->Map("code"-> -32010,"message"->"schema_changed"))
          case _:IllegalArgumentException=>Map("jsonrpc"->"2.0","id"->request("id"),
            "error"->Map("code"-> -32602,"message"->"Rejected fixed MCP request"))
        }
        exchange.reply.offer(McpWire.encode(result))
      } finally java.util.Arrays.fill(exchange.bytes,0.toByte)
    } catch {case _:InterruptedException=>()}
  },"veri7vn-local-mcp")
  worker.setDaemon(true);worker.start()
  private[mcp] def exchange(bytes:Array[Byte],timeoutMillis:Long):Array[Byte]={
    require(live.get() && bytes.length<=16384 && timeoutMillis>0,"MCP transport bounds")
    val deadline=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
    val reply=new ArrayBlockingQueue[Array[Byte]](1)
    val item=Exchange(bytes.clone(),reply)
    if(!requests.offer(item,timeoutMillis,TimeUnit.MILLISECONDS)) {
      java.util.Arrays.fill(item.bytes,0.toByte);throw new java.util.concurrent.TimeoutException("MCP handoff unknown")
    }
    val remaining=math.max(0L,deadline-System.nanoTime())
    val result=reply.poll(remaining,TimeUnit.NANOSECONDS)
    if(result==null)throw new java.util.concurrent.TimeoutException("MCP acknowledgement unknown")
    result
  }
  private[mcp] def counter:Int=value.get()
  private[mcp] def changeSchema():Unit=synchronized {revision.incrementAndGet();()}
  private[mcp] def holdAfterEffect(blocker:CountDownLatch,reached:CountDownLatch):Unit={afterEffect=Some((blocker,reached))}
  def close():Unit={
    live.set(false);worker.interrupt();worker.join(5000)
    require(!worker.isAlive,"MCP local server did not stop")
    synchronized {receipts=Map.empty;receiptInputs=Map.empty}
    var item=requests.poll()
    while(item!=null) {java.util.Arrays.fill(item.bytes,0.toByte);item=requests.poll()}
  }
}
private[mcp] object McpWire {
  def obj(value:Any):Map[String,Any]=InertJSON.objectValue(value)
  def text(value:Any):String=value match {
    case s:String if s.length<=4096=>s
    case _=>throw new IllegalArgumentException("MCP bounded string required")
  }
  def integer(value:Any):Int=value match {
    case n:Int=>n
    case n:Long if n>=Int.MinValue && n<=Int.MaxValue=>n.toInt
    case n:Double if n.isValidInt && n==n.toInt.toDouble=>n.toInt
    case _=>throw new IllegalArgumentException("MCP exact integer required")
  }
  def encode(value:Map[String,Any]):Array[Byte]={
    val bytes=JSON.Format(value).getBytes(UTF_8);require(bytes.length<=16384,"MCP wire bound");bytes
  }
  def decode(bytes:Array[Byte]):Map[String,Any]=obj(InertJSON.parse(Content(bytes),16384,16,4096))
}
