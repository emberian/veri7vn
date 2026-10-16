package veri7vn.workbench

/** Actual resident build operations. Request reopening belongs to the native
  * service and its durable source binding, never a browser-side handle table. */
trait BuildWorkspace {
  def start(draft:String,expectedManifest:String,theoryPath:String):BigInt
  def inspect(request:BigInt):Option[BuildWorkspace.View]
  def cancel(request:BigInt):Unit
  def forget(request:BigInt):Unit
}
object BuildWorkspace {
  final case class Source(draft:String,manifest:String,revision:String,path:String)
  final case class Diagnostic(description:String,message:String,code:String,currentSpan:Option[(Int,Int)])
  final case class View(request:BigInt,state:String,source:Option[Source],
    candidate:Option[BigInt],diagnostic:Option[Diagnostic])
}
