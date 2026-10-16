package veri7vn.workbench

import veri7vn.runtime.service.{RuntimeService,DialogueClient}

/** Read-only native projections and fixed native proposal/lifecycle operations. */
final class ResidentExecution(service:RuntimeService) extends Execution with AutoCloseable {
  private val dialogue=new DialogueClient(service.client)
  def route(original:Array[Byte]):Execution.Route={
    val inspected=dialogue.inspect(original)
    Execution.Route(inspected.handle,inspected.status,inspected.alternatives)
  }
  def select(handle:Long,index:Int):BigInt=dialogue.select(handle,index)
  def result(id:BigInt):Execution.Result={
    val native=service.client.mathematicsResult(id)
    Execution.Result(native.status,native.html)
  }
  def provenance(id:BigInt):Vector[(String,String)]={
    val native=service.client.requestInspection(id)
    native.provenance++native.reading.toVector.flatMap(reading=>Vector(
      "Reading"->reading.description,"Selected native reading"->reading.index.toString,"Mathematics operation"->reading.operation.toString,
      "Original input bytes"->reading.inputBytes.toString)++reading.literals.zipWithIndex.map((span,index)=>
        ("Literal "+(index+1)+" byte range",span.startByte+"–"+span.endByte)))++
      native.readingUnavailable.toVector.map(reason=>"Reading unavailable"->reason)
  }
  def cancel(id:BigInt):Unit=service.client.cancel(id)
  def forget(id:BigInt):Unit=service.client.forget(id)
  def close():Unit=dialogue.close()
}
