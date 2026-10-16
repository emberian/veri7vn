package veri7vn.runtime.service

import java.nio.file.Paths
import scala.language.unsafeNulls

/** Local line-oriented client for the fixed installed resident service. */
object RuntimeMain {
  def main(args:Array[String]):Unit=isabelle.Command_Line.tool {
    var workspace:Option[java.nio.file.Path]=None
    var images:Option[java.nio.file.Path]=None
    var roots=List.empty[java.nio.file.Path]
    var index=0
    while(index<args.length){
      require(index+1<args.length,"expected --workspace PATH --images PATH [--session-root PATH ...]")
      val value=Paths.get(args(index+1))
      args(index) match {
        case "--workspace"=>require(workspace.isEmpty);workspace=Some(value)
        case "--images"=>require(images.isEmpty);images=Some(value)
        case "--session-root"=>roots=roots:+value
        case other=>throw new IllegalArgumentException("unknown argument: "+other)
      }
      index+=2
    }
    scala.util.Using.resource(RuntimeService.open(workspace.getOrElse(throw new IllegalArgumentException("--workspace required")),
      images.getOrElse(throw new IllegalArgumentException("--images required")),roots)){service=>
      def nextProposal():Option[Array[Byte]]={
        val buffer=new Array[Byte](256)
        try {
          var count=0
          var next=System.in.read()
          if(next<0)return None
          while(next>=0 && next!=10){
            require(count<buffer.length,"proposal line exceeds 256 bytes")
            buffer(count)=next.toByte;count+=1;next=System.in.read()
          }
          val length=if(count>0 && buffer(count-1)==13)count-1 else count
          Some(java.util.Arrays.copyOf(buffer,length))
        } finally java.util.Arrays.fill(buffer,0.toByte)
      }
      var proposal=nextProposal()
      while(proposal.nonEmpty){
        val bytes=proposal.get
        val request=try service.client.proposeMathematics(bytes) finally java.util.Arrays.fill(bytes,0.toByte)
        val deadline=System.nanoTime()+60L*1000*1000*1000
        var result=service.client.mathematicsResult(request)
        while(result.status=="pending" && System.nanoTime()<deadline){Thread.sleep(25);result=service.client.mathematicsResult(request)}
        println(result.html.getOrElse(result.status))
        proposal=nextProposal()
      }
    }
  }
}
