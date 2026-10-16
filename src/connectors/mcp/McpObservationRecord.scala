package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.sources.LocalSnapshot

/** Inert retained source record. Its bytes are an observed decoded JSON response,
  * not a theorem, evaluation oracle, effect permit or original transport framing.
  * Native upload/lifecycle and DeliverEffectObservation bind the actual record. */
object McpObservationRecord {
  final class Candidate private[McpObservationRecord] (
      private val content:Array[Byte],private val witness:Array[Byte],val identity:String,
      private val staged:McpIngress.StagedPacket) extends AutoCloseable {
    private val live=new java.util.concurrent.atomic.AtomicBoolean(true)
    private[runtime] def withBytes[A](consume:java.nio.ByteBuffer=>A):A=staged.withBytes {_=>synchronized {
      require(live.get(),"MCP response record released");consume(java.nio.ByteBuffer.wrap(content).asReadOnlyBuffer())
    }}
    private[runtime] def withWitness[A](consume:java.nio.ByteBuffer=>A):A=staged.withBytes {_=>synchronized {
      require(live.get(),"MCP response witness released");consume(java.nio.ByteBuffer.wrap(witness).asReadOnlyBuffer())
    }}
    private[mcp] def invalidate():Unit=live.set(false)
    def close():Unit=synchronized {
      live.set(false);java.util.Arrays.fill(content,0.toByte);java.util.Arrays.fill(witness,0.toByte)
    }
    override def toString:String="McpObservedResponse(<retained source candidate>)"
  }
  private def source(draft:String,head:String,member:String,sha:String,size:Int):Map[String,Any]=
    Map("draft"->draft,"head"->head,"member"->member,"sha256"->sha,"size"->size)
  /** Fixed producer calls this while its installation/packet/observation guards
    * are held. A publicly constructed Observation is not accepted by this method
    * as authority; native parent still authenticates actual attempt/result ingress. */
  private[runtime] def capture(staged:McpIngress.StagedPacket,observed:McpWorkflow.Observation):Candidate=
      staged.installation.withCurrent {staged.withBytes { _=>
    require(observed.attempt.inputArtifact==staged.packet.inputArtifact &&
      observed.operation==staged.packet.operation,"MCP response attempt/packet mismatch")
    require(observed.schemaIdentity==staged.packet.schemaIdentity ||
      (observed.operation==McpWorkflow.Operation.Discover && observed.schemaIdentity.nonEmpty),"MCP response schema mismatch")
    val response=McpWire.encode(observed.response)
    val receiptBytes=try {
      require(LocalSnapshot.hash(response)==observed.receiptArtifact,"MCP response receipt mismatch")
      java.util.Base64.getEncoder.encodeToString(response)
    } finally java.util.Arrays.fill(response,0.toByte)
    val packet=staged.descriptor
    val config=staged.installation.nativeConfiguration.descriptor
    val attempt=observed.attempt
    val record=Map[String,Any]("format"->"veri7vn-mcp-observed-response/1",
      "label"->"observed MCP response","representation"->"decoded-json/1",
      "protocol"->"local-mcp/1","server"->"veri7vn-local-counter","origin"->"local-fixture","operation"->observed.operation.toString,"status"->observed.status.toString,
      "workspace"->attempt.workspace,"attempt"->attempt.attempt.toString,
      "request"->attempt.request.toString,"capability"->attempt.capability.toString,
      "inputArtifact"->attempt.inputArtifact,"configuration"->staged.installation.configurationLabel,
      "configurationSource"->source(config.draft,config.head,config.member,config.sha256,config.size),
      "configurationEpoch"->config.epoch.toString,
      "packetSource"->source(packet.draft,packet.head,packet.member,packet.sha256,packet.size),
      "schema"->observed.schemaIdentity.getOrElse(""),"receiptArtifact"->observed.receiptArtifact,
      "receiptEncoding"->"JSON.Format/1","receiptBytes"->receiptBytes,
      "response"->observed.response)
    staged.retainResponse {
      val bytes=canonical(record).getBytes(UTF_8)
      if(bytes.length>65536) {java.util.Arrays.fill(bytes,0.toByte);throw new IllegalArgumentException("MCP retained response bound")}
      try new Candidate(bytes,encodingWitness(record,observed.response),LocalSnapshot.hash(bytes),staged)
      catch {case failure:Throwable=>java.util.Arrays.fill(bytes,0.toByte);throw failure}
    }
  }}
  final case class View(label:String,status:String,operation:String,request:String,attempt:String,
      configuration:String,schema:String,response:Map[String,Any],receiptArtifact:String,server:String,origin:String)
  /** Source bytes must already be accessed under the retained managed/native
    * observation owner. This decoder returns a historical display projection only;
    * it cannot authorize invocation, restore a live executor or mint acceptance. */
  private[runtime] def inspectRetained(view:java.nio.ByteBuffer):View={
    require(view.remaining()<=65536,"MCP retained source bound")
    val raw=new Array[Byte](view.remaining())
    val record=try {
      view.get(raw)
      veri7vn.packages.lifecycle.InertJSON.objectValue(
        veri7vn.packages.lifecycle.InertJSON.parse(veri7vn.packages.intake.Intake.Content(raw),65536,24,16384))
    } finally java.util.Arrays.fill(raw,0.toByte)
    require(record.keySet==Set("format","label","representation","protocol","server","origin","operation","status",
      "workspace","attempt","request","capability","inputArtifact","configuration","configurationSource",
      "configurationEpoch","packetSource","schema","receiptArtifact","receiptEncoding","receiptBytes","response"),
      "MCP retained source fields")
    def text(key:String):String=McpWire.text(record(key))
    require(text("format")=="veri7vn-mcp-observed-response/1" && text("label")=="observed MCP response" &&
      text("representation")=="decoded-json/1" && text("protocol")=="local-mcp/1" &&
      text("receiptEncoding")=="JSON.Format/1" && text("server")=="veri7vn-local-counter" &&
      text("origin")=="local-fixture","MCP retained representation")
    require(Set("Discover","QualifyCounter","InvokeCounter").contains(text("operation")) &&
      Set("ConfirmedResponse","RejectedResponse").contains(text("status")),"MCP retained outcome")
    List("request","attempt","capability","configurationEpoch").foreach(k=>
      require(text(k).matches("[0-9]{1,128}"),"MCP retained numeric identity"))
    val receiptValue=record("receiptBytes") match {
      case s:String if s.length<=24576=>java.util.Base64.getDecoder.decode(s)
      case _=>throw new IllegalArgumentException("MCP retained receipt byte bound")
    }
    try {
      require(LocalSnapshot.hash(receiptValue)==text("receiptArtifact"),"MCP retained receipt identity")
      require(McpWire.decode(receiptValue)==McpWire.obj(record("response")),"MCP retained receipt response differs")
    } finally java.util.Arrays.fill(receiptValue,0.toByte)
    val packet=McpWire.obj(record("packetSource"));val config=McpWire.obj(record("configurationSource"))
    List(packet,config).foreach(s=>{
      require(s.keySet==Set("draft","head","member","sha256","size") &&
        McpWire.text(s("member"))==McpWire.text(s("sha256")) &&
        List("head","member").forall(k=>McpWire.text(s(k)).matches("[0-9a-f]{64}")) &&
        McpWire.integer(s("size"))>0,"MCP retained source descriptor")
    })
    require(text("inputArtifact")==McpWire.text(packet("member")),"MCP retained packet identity")
    require(text("configuration").matches("binding-[0-9]{1,128}-epoch-"+text("configurationEpoch")),"MCP retained configuration epoch")
    require(text("schema").isEmpty || text("schema").matches("[0-9a-f]{64}"),"MCP retained schema identity")
    View(text("label"),text("status"),text("operation"),text("request"),text("attempt"),
      text("configuration"),text("schema"),McpWire.obj(record("response")),text("receiptArtifact"),text("server"),text("origin"))
  }
  /** Fixed counter response subset, with two independently encoded ordered trees.
    * String values use ASCII decimal scalars so YXML control bytes cannot become
    * markup. Receipt object order matches the actual JSON.Format receipt hash. */
  private[mcp] def encodingWitness(record:Map[String,Any],receipt:Map[String,Any]):Array[Byte]={
    import isabelle.{XML,Markup,YXML}
    var nodes=0
    def elem(name:String,body:List[XML.Tree]=Nil):XML.Tree=XML.Elem(Markup(name,Nil),body)
    def text(name:String,s:String):XML.Tree=elem(name,if(s.isEmpty)Nil else List(XML.Text(s)))
    def scalars(s:String):String={
      val values=s.codePoints().toArray
      // A bounded 16KiB receipt becomes up to 21848 base64 scalars in the record.
      require(values.length<=24576 && values.forall(n=>n>=0 && n<=0x10ffff && (n<0xd800 || n>0xdfff)),
        "MCP witness Unicode scalar bound")
      values.mkString(",")
    }
    def tree(value:Any,sorted:Boolean,depth:Int):XML.Tree={
      nodes+=1;require(nodes<=4096 && depth<=24,"MCP witness tree bound")
      value match {
        case null=>elem("null")
        case b:Boolean=>text("bool",if(b)"1"else"0")
        case s:String=>text("string",scalars(s))
        case m:Map[?,?]=>
          val entries=McpWire.obj(m).toList
          require(entries.map(_._1).distinct.size==entries.size &&
            entries.forall(_._1.forall(c=>c>=32 && c<=126)),"MCP witness ASCII object keys")
          val ordered=if(sorted)entries.sortBy(_._1)else entries
          elem("object",ordered.map {case(k,v)=>
            elem("entry",List(tree(k,sorted,depth+1),tree(v,sorted,depth+1)))})
        case xs:List[?]=>elem("array",xs.map(tree(_,sorted,depth+1)))
        case _=>text("int",McpWire.integer(value).toString)
      }
    }
    val encoded=YXML.string_of_body(List(XML.Elem(Markup("effect-observation-witness",List("version"->"1")),
      List(elem("record",List(tree(record,true,0))),elem("receipt",List(tree(receipt,false,0))))))).getBytes(UTF_8)
    if(encoded.length>524288) {java.util.Arrays.fill(encoded,0.toByte);throw new IllegalArgumentException("MCP witness byte bound")}
    encoded
  }
  /** Stable object-key order; arrays and string/codepoint values retain meaning.
    * This encoding deliberately makes no claim to retain wire whitespace/order. */
  private[mcp] def canonical(value:Any):String=value match {
    case map:Map[?,?]=>
      val objectValue=McpWire.obj(map)
      objectValue.keys.toList.sorted.map(k=>isabelle.JSON.Format(k)+":"+canonical(objectValue(k))).mkString("{",",","}")
    case list:List[?]=>list.map(canonical).mkString("[",",","]")
    case null=>"null"
    case b:Boolean=>b.toString
    case s:String=>
      require(s.codePoints().toArray.forall(n=>n<0xd800 || n>0xdfff),"MCP canonical Unicode scalar string")
      isabelle.JSON.Format(s)
    case _=>McpWire.integer(value).toString
  }
}
