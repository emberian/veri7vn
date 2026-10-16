package veri7vn.workbench

import veri7vn.runtime.service.RuntimeService
import veri7vn.diagnostics.{BuildFailure,SourceDiagnostic}

/** No handle table or source cache: every read reopens the committed host/native
  * association. The matching resident facade owns capture, budgets and lifetime. */
final class ResidentBuildWorkspace(service:RuntimeService,author:Authoring) extends BuildWorkspace {
  def start(draft:String,expectedManifest:String,theoryPath:String):BigInt={
    val request=service.client.proposeManagedBuild(draft,expectedManifest,theoryPath)
    try request.request finally request.close()
  }

  def inspect(id:BigInt):Option[BuildWorkspace.View]=service.client.openBuild(id).map {request=>
    try {
    val result=service.client.buildResult(request)
    val captured=request.original
    val source=if(result.sourceAvailable)Some(BuildWorkspace.Source(captured.draft,captured.manifest,captured.revision,captured.path))else None
    val head=if(source.isEmpty)None else try {
      val current=author.inspect(captured.draft)
      Some(SourceDiagnostic.Head(current.manifest,current.revision.id))
    }catch {case _:IllegalArgumentException=>None}
    val diagnostic=result.diagnostic.map {native=>
      try service.client.withBuildFailureSource(native) {(original,bytes,failure)=>
        val located=SourceDiagnostic.locate(original,bytes,failure,head)
        val message=failure.message match {
          case BuildFailure.Message.Text(value)=>value
          case BuildFailure.Message.Unavailable=>"The native diagnostic message is unavailable."
        }
        BuildWorkspace.Diagnostic(failure.title+". "+located.description,message,failure.code,
          located.location.filter(_=>located.hasCurrentSpan).map(location=>(location.startByte,location.endByte)))
      }catch {case _:IllegalArgumentException|_:IllegalStateException=>
        BuildWorkspace.Diagnostic("The captured diagnostic source is unavailable; no failure text was opened.","","unavailable",None)
      }
    }
    BuildWorkspace.View(request.request,result.state.toString,source,result.candidate,diagnostic)
    } finally request.close()
  }
  // Lifecycle authority belongs to the native service; source-read revocation
  // must not prevent an otherwise authorized cancellation or erasure request.
  def cancel(id:BigInt):Unit=service.client.cancel(id)
  def forget(id:BigInt):Unit=service.client.forget(id)
}
