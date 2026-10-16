package veri7vn.packages.lifecycle

import veri7vn.packages.intake.Intake
import Intake.{Edit,Staged}

/** Server-derived exact source-operation identity. Content hashes are byte identities,
  * not native authority; never accept client-asserted hashes in place of actual Content.
  * The host hashes/stores these canonical bytes and independently checks every stage put.
  */
object OperationIdentity {
  private def encode(write:java.io.DataOutputStream=>Unit):Array[Byte]={
    val bytes=new java.io.ByteArrayOutputStream() {
      override def write(b:Int):Unit={require(size()<2*1024*1024,"Operation identity bound");super.write(b)}
      override def write(b:Array[Byte],offset:Int,length:Int):Unit={
        require(length>=0 && size().toLong+length<=2*1024*1024,"Operation identity bound")
        super.write(b,offset,length)
      }
    };val out=new java.io.DataOutputStream(bytes)
    out.writeUTF("veri7vn-source-operation/1");write(out);out.flush()
    require(bytes.size()<=2*1024*1024,"Operation identity bound");bytes.toByteArray
  }
  private def string(out:java.io.DataOutputStream,s:String):Unit={
    val raw=s.getBytes(java.nio.charset.StandardCharsets.UTF_8)
    require(raw.length<=4096,"Operation field bound");out.writeInt(raw.length);out.write(raw)
  }
  private def optional(out:java.io.DataOutputStream,s:Option[String]):Unit={out.writeBoolean(s.nonEmpty);s.foreach(string(out,_))}
  def create(draft:String,staged:Staged):Array[Byte]={
    require(staged.entries.size<=2048)
    encode {out=>
      string(out,"create");string(out,draft);string(out,staged.format.toString);string(out,staged.identity)
      string(out,staged.originLabel);optional(out,staged.originalArchive.map(_.sha256))
      out.writeInt(staged.entries.size)
      staged.entries.sortBy(_.path).foreach(e=>{string(out,e.path);out.writeInt(e.content.size);string(out,e.content.sha256)})
    }
  }
  def edit(draft:String,expectedLocator:String,expectedRevision:String,edits:Vector[Edit]):Array[Byte]={
    require(edits.nonEmpty && edits.size<=2048)
    encode {out=>
      string(out,"edit");string(out,draft);string(out,expectedLocator);string(out,expectedRevision);out.writeInt(edits.size)
      edits.foreach(e=>{string(out,e.path);out.writeInt(e.start);out.writeInt(e.end)
        out.writeInt(e.expected.size);string(out,e.expected.sha256)
        out.writeInt(e.replacement.size);string(out,e.replacement.sha256)})
    }
  }
}
