package veri7vn.runtime.service

import scala.language.unsafeNulls
import java.io.{ByteArrayInputStream, ByteArrayOutputStream, DataInputStream, DataOutputStream}

/** Finite generated metadata only. Decoding never grants event origin or native evidence. */
object MetadataFrame {
  sealed trait Wire
  final case class Atom(value: BigInt) extends Wire
  final case class Node(tag: Int, children: Vector[Wire]) extends Wire
  final case class Limits(maxBytes: Int=1024*1024,maxDepth: Int=64,maxNodes: Int=65536,maxDigits: Int=128) {
    require(maxBytes>0 && maxDepth>0 && maxDepth<=256 && maxNodes>0 && maxDigits>0 && maxDigits<=4096)
  }
  def encode(value: Wire, limits: Limits=Limits()): Array[Byte] = {
    val bytes=new ByteArrayOutputStream(); val out=new DataOutputStream(bytes); var nodes=0
    def loop(w: Wire, depth: Int): Unit = {
      nodes+=1; require(depth<=limits.maxDepth && nodes<=limits.maxNodes,"metadata shape limit")
      w match {
        case Atom(n)=>
          require(n>=0 && n.bitLength.toLong<=limits.maxDigits.toLong*4,"metadata natural bound")
          val digits=n.toString; require(digits.length<=limits.maxDigits,"metadata digits bound")
          require(bytes.size().toLong+5+digits.length<=limits.maxBytes,"metadata byte limit")
          out.writeByte(0); out.writeInt(digits.length); out.write(digits.getBytes(java.nio.charset.StandardCharsets.US_ASCII))
        case Node(tag,children)=>
          require(tag>=0 && children.size<=limits.maxNodes-nodes,"metadata node bound")
          require(bytes.size().toLong+9<=limits.maxBytes,"metadata byte limit")
          out.writeByte(1); out.writeInt(tag); out.writeInt(children.size); children.foreach(loop(_,depth+1))
      }
    }
    loop(value,1); out.flush(); bytes.toByteArray
  }
  def decode(bytes: Array[Byte], limits: Limits=Limits()): Wire = {
    require(bytes.length<=limits.maxBytes,"metadata byte limit")
    val in=new DataInputStream(new ByteArrayInputStream(bytes)); var nodes=0
    def loop(depth: Int): Wire = {
      nodes+=1; require(depth<=limits.maxDepth && nodes<=limits.maxNodes,"metadata shape limit")
      in.readUnsignedByte() match {
        case 0=>
          val length=in.readInt(); require(length>0 && length<=limits.maxDigits && length<=in.available(),"metadata natural length")
          val digits=new Array[Byte](length); in.readFully(digits)
          require(digits.forall(b=>b>=48 && b<=57) && (length==1 || digits(0)!=48),"noncanonical natural")
          Atom(BigInt(new String(digits,java.nio.charset.StandardCharsets.US_ASCII)))
        case 1=>
          val tag=in.readInt(); val count=in.readInt()
          require(tag>=0 && count>=0 && count<=limits.maxNodes-nodes && count<=in.available(),"metadata node arity")
          Node(tag,Vector.fill(count)(loop(depth+1)))
        case _=>throw new IllegalArgumentException("unknown metadata frame tag")
      }
    }
    val value=loop(1); require(in.available()==0,"trailing metadata bytes"); value
  }
}
