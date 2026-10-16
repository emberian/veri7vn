package veri7vn.runtime.service.effects

import veri7vn.runtime.service.ResidentSupervisor

/** Uploaded source association only. Delivery requires the separate generated
  * staged-observation transition, durable installation and exact native ack. */
private[service] final class NativeMcpResponse private[service](
    val candidate:PreparedMcpOperation.ObservationCandidate,
    val responseHandle:BigInt,val sourceUID:BigInt,
    private[service] val supervisor:ResidentSupervisor) {
  require(responseHandle>0 && sourceUID>0 && responseHandle.toString.length<=128 &&
    sourceUID.toString.length<=128,"native MCP response identity bound")
  require(supervisor eq candidate.consumedStart.supervisor,
    "native MCP response differs from consumed-start supervisor")
  require(supervisor eq candidate.packet.supervisor,
    "native MCP response differs from original packet supervisor")
  private[service] def requireCandidate(expected:PreparedMcpOperation.ObservationCandidate):Unit=
    require(candidate eq expected,"native MCP response staging owner mismatch")
}
