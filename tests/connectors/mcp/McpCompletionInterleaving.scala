package veri7vn.runtime.service.effects

import java.util.concurrent.{CountDownLatch,TimeUnit}

/** Hook for the real resident-gate fixture: construct this around its actual Bound
  * BEFORE the parent hands off its actual acknowledged native permit. No profile,
  * grant, source UID, receipt or permit is created by this regression helper. */
private[service] final class McpCompletionInterleaving(bound:PreparedMcpOperation#Bound) {
  private val constructed=new CountDownLatch(1)
  private val release=new CountDownLatch(1)
  bound.holdCompletionForTest(constructed,release)
  /** Call after the parent actually handed off. The source/protocol result already
    * exists at this point, but no terminal receipt may escape before the atomic
    * receipt+response publication. Always release the owned worker on failure. */
  def verifyAfterActualHandoff():Unit={
    try {
      require(constructed.await(10,TimeUnit.SECONDS),"actual MCP executor did not reach completion publication gate")
      require(bound.completionSnapshot()==PreparedMcpOperation.Completion.Unknown,
        "actual executor exposed receipt before response publication")
      require(bound.reconcile()==PreparedMcpOperation.Completion.Unknown,
        "concurrent reconciliation foreclosed an uncommitted response")
    } finally release.countDown()
    require(bound.awaitCompletionForTest(10000),"actual MCP response completion did not publish")
    bound.completionSnapshot() match {
      case PreparedMcpOperation.Completion.ResponseReady(candidate)=>
        require(candidate.identity.matches("[0-9a-f]{64}"),"actual response source identity")
        candidate.withBytes(view=>require(view.hasRemaining,"actual response source missing bytes"))
      case _=>throw new IllegalStateException("actual response downgraded or missing after atomic publication")
    }
  }
}
