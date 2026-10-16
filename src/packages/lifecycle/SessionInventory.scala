package veri7vn.packages.lifecycle
import isabelle.{Sessions,Options,Path,Position,Bytes}
import scala.language.unsafeNulls
import veri7vn.packages.intake.Intake

/** Isabelle's own declared session/theory/ML-file dependency inventory.
  * This reads source without evaluating theories or ML. A successful inventory is
  * not a successful build, an executable closure, or an admission receipt.
  */
object SessionInventory {
  final case class Source(path:String,sha256:String,size:Long)
  final case class Session(name:String,parent:Option[String],theories:Vector[String])
  final case class Inventory(selected:String,roots:Vector[String],sessions:Vector[Session],sources:Vector[Source])
  def inspect(selected:String,roots:Vector[java.nio.file.Path],maxSourceBytes:Long=256L*1024*1024):Inventory={
    require(selected.nonEmpty && roots.nonEmpty && roots.size<=128 && maxSourceBytes>0)
    roots.foreach(p=>require(java.nio.file.Files.isDirectory(p),"Session root unavailable"))
    val structure=Sessions.load_structure(Options.init(),dirs=roots.map(p=>Path.explode(p.toRealPath().toString)).toList)
      .selection(selected)
    val deps=Sessions.deps(structure,inlined_files=true).check_errors
    val names=structure.imports_topological_order
    require(names.size<=1024,"Session dependency count limit")
    val declared=names.flatMap(name=>deps(name).all_sources.map{case(path,digest)=>(path,Some(digest))})
    val rootFiles=names.flatMap(name=>Position.File.unapply(structure(name).pos).map(p=>(Path.explode(p),None)))
    val navigation=roots.flatMap(p=>Vector("ROOT","ROOTS").map(p.resolve(_)).filter(p=>java.nio.file.Files.isRegularFile(p)).map(p=>(Path.explode(p.toString),None)))
    val files=(declared++rootFiles++navigation).groupBy(_._1.expand.implode).toVector.sortBy(_._1)
    require(files.size<=32768,"Session dependency file limit")
    var total=0L
    val sources=files.map {case(_,entries)=>
      val path=entries.head._1.expand
      val actual=path.file.toPath.toRealPath()
      val size=java.nio.file.Files.size(actual)
      require(size>=0 && size<=64L*1024*1024 && total+size<=maxSourceBytes,"Session source byte budget")
      total+=size
      val in=java.nio.file.Files.newInputStream(actual,java.nio.file.LinkOption.NOFOLLOW_LINKS)
      val raw=try in.readNBytes(size.toInt+1) finally in.close()
      val bytes=Bytes(raw)
      require(bytes.size==size && entries.forall{case(_,expected)=>expected.forall(_==bytes.sha1_digest)},
        "Session source changed during dependency inventory")
      Source(actual.toString,Intake.hash(raw),size)
    }
    Inventory(selected,roots.map(_.toRealPath().toString),names.map {name=>Session(name,structure(name).parent,
      deps(name).proper_session_theories.map(_.theory).toVector)}.toVector,sources)
  }
}
