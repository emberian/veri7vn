package veri7vn.runtime.service

/** Development measurement seam over the actual resident/native coordinator.
  * Compile with actual service sources/Isabelle classpath after D34 migration.
  * No event/token constructor or stand-in native bridge is accepted here.
  * Unexecuted until the native admitted fixture issuer is integrated.
  */
object ResidentServiceMeasurement {
  final case class Sample(wallNanos: Long, sequence: Long, eventId: String)
  def sampleAuthorized(supervisor: ResidentSupervisor, coordinator: AuthorityCoordinator): Option[Sample] = {
    supervisor.pollAuthorizedToken().map { token =>
      val start=System.nanoTime()
      val result=coordinator.submit(token)
      val elapsed=System.nanoTime()-start
      result match {
        case AuthorityCoordinator.Committed(sequence,id) => Sample(elapsed,sequence,id)
        case other => throw new IllegalStateException("measurement did not commit: "+other)
      }
    }
  }
}
