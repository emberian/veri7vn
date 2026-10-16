package veri7vn.runtime.connectors.mcp

import scala.language.unsafeNulls
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.sources.LocalSnapshot

/** Decoder conformance using a real fixture response. Metadata here is inert test
  * data, never a native installation/permit or evidence of governed publication. */
object McpObservationRecordTests {
  def main(args:Array[String]):Unit={
    val server=new LocalMcpServer();val client=new LocalMcpClient(server)
    try {
      val schema=client.discover(1000).schemaIdentity
      val response=client.invoke(schema,2,"record-component-attempt",1000)
      val receipt=McpWire.encode(response)
      val receiptHash=LocalSnapshot.hash(receipt)
      val packet=McpWorkflow.prepare(McpWorkflow.Operation.InvokeCounter,Some(schema),2,"binding-17-epoch-1")
      def source(member:String):Map[String,Any]=Map("draft"->"component-source","head"->member,
        "member"->member,"sha256"->member,"size"->12)
      val record=Map[String,Any]("format"->"veri7vn-mcp-observed-response/1","label"->"observed MCP response",
        "representation"->"decoded-json/1","protocol"->"local-mcp/1",
        "server"->"veri7vn-local-counter","origin"->"local-fixture","operation"->"InvokeCounter",
        "status"->"ConfirmedResponse","workspace"->"component-workspace","attempt"->"1","request"->"2",
        "capability"->"3","inputArtifact"->packet.inputArtifact,"configuration"->"binding-17-epoch-1",
        "configurationSource"->source("a"*64),"configurationEpoch"->"1","packetSource"->source(packet.inputArtifact),
        "schema"->schema,"receiptArtifact"->receiptHash,"receiptEncoding"->"JSON.Format/1",
        "receiptBytes"->java.util.Base64.getEncoder.encodeToString(receipt),"response"->response)
      def inspect(data:Map[String,Any]):McpObservationRecord.View=
        McpObservationRecord.inspectRetained(ByteBuffer.wrap(McpObservationRecord.canonical(data).getBytes(UTF_8)))
      val restored=inspect(record)
      require(restored.label=="observed MCP response" && restored.status=="ConfirmedResponse" && restored.receiptArtifact==receiptHash)
      require(server.counter==2,"historical decoding reexecuted the tool")
      def denied(data:Map[String,Any]):Boolean=try {inspect(data);false} catch {case _:IllegalArgumentException=>true}
      require(denied(record.updated("response",Map("isError"->false))),"changed response escaped receipt binding")
      require(denied(record.updated("inputArtifact","b"*64)),"changed original packet escaped binding")
      require(denied(record.updated("status","Accepted")),"theorem status leaked into source record")
      require(denied(record.updated("status","Unknown")),"unknown remote outcome manufactured an observation")
      val witness=McpObservationRecord.encodingWitness(record,response)
      val witnessBody=isabelle.YXML.parse_body(new String(witness,UTF_8))
      require(witnessBody.nonEmpty,"actual response witness missing")
      // Independent byte-conformance check: this decoder is test data plumbing,
      // not the generated native checker or an observation admission path.
      def decode(tree:isabelle.XML.Tree):Any=tree match {
        case isabelle.XML.Elem(isabelle.Markup(tag,Nil),body)=>
          def text=body.map {case isabelle.XML.Text(s)=>s;case _=>throw new IllegalArgumentException("witness text")}.mkString
          tag match {
            case "null"=>null
            case "bool"=>text=="1"
            case "int"=>text.toInt
            case "string"=>
              val builder=new java.lang.StringBuilder
              if(text.nonEmpty)text.split(",").foreach(s=>builder.appendCodePoint(s.toInt))
              builder.toString
            case "array"=>body.map(decode)
            case "object"=>
              scala.collection.immutable.ListMap.from(body.map {
                case isabelle.XML.Elem(isabelle.Markup("entry",Nil),List(key,value))=>decode(key).asInstanceOf[String]->decode(value)
                case _=>throw new IllegalArgumentException("witness entry")
              })
            case _=>throw new IllegalArgumentException("witness tag")
          }
        case _=>throw new IllegalArgumentException("witness tree")
      }
      witnessBody match {
        case List(isabelle.XML.Elem(isabelle.Markup("effect-observation-witness",List(("version","1"))),
            List(isabelle.XML.Elem(isabelle.Markup("record",Nil),List(recordTree)),
              isabelle.XML.Elem(isabelle.Markup("receipt",Nil),List(receiptTree)))))=>
          require(McpObservationRecord.canonical(decode(recordTree))==McpObservationRecord.canonical(record),"canonical witness differs")
          require(java.util.Arrays.equals(McpWire.encode(McpWire.obj(decode(receiptTree))),receipt),"receipt order/bytes changed in witness")
        case _=>throw new IllegalArgumentException("witness envelope")
      }
      def witnessDenied(value:Any):Boolean=try {
        McpObservationRecord.encodingWitness(Map("value"->value),Map.empty);false
      } catch {case _:IllegalArgumentException=>true}
      require(witnessDenied(0.5) && witnessDenied(Double.NaN) && witnessDenied(2147483648L),"unsupported witness numbers admitted")
      require(witnessDenied("\ud800") && witnessDenied(Map("\u00e9"->1)),"unsupported scalar/key admitted")
      val base64Envelope=java.util.Base64.getEncoder.encodeToString(new Array[Byte](16384))
      require(base64Envelope.length==21848 &&
        McpObservationRecord.encodingWitness(Map("receiptBytes"->base64Envelope),Map.empty).nonEmpty,
        "bounded receipt base64 does not fit witness scalar bound")
      val scalarRecord=Map[String,Any]("value"->"\u0005\u0006\b\f\n\r\t\u007f\u009f\u00e9\ud83d\ude00")
      require(McpObservationRecord.encodingWitness(scalarRecord,scalarRecord).forall(b=>b>=0 && b<128),"raw Unicode/YXML delimiter in scalar witness")
      java.util.Arrays.fill(witness,0.toByte)
      java.util.Arrays.fill(receipt,0.toByte)
      println("MCP_OBSERVATION_RECORD_PASS")
    } finally server.close()
  }
}
