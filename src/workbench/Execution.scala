package veri7vn.workbench

/** A view of the authoritative resident service. No result or acceptance state is
  * stored in the browser; request IDs can be inspected after reopening it. */
trait Execution {
  def route(original:Array[Byte]):Execution.Route
  def select(handle:Long,index:Int):BigInt
  def provenance(request:BigInt):Vector[(String,String)]
  def result(request:BigInt):Execution.Result
  def cancel(request:BigInt):Unit
  def forget(request:BigInt):Unit
}
object Execution {
  final case class Route(handle:Long,status:String,alternatives:List[Int])
  final case class Result(status:String,html:Option[String])
}
