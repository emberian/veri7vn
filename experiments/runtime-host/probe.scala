import isabelle.*
import scala.language.unsafeNulls
import java.util.concurrent.{LinkedBlockingQueue, TimeUnit}

@main def runtimeHostProbe(): Unit = {
val events = new LinkedBlockingQueue[String]()
class Handler extends Session.Protocol_Handler {
  override def functions = List("veri7vn_host_v1" -> ((m: Prover.Protocol_Output) => { events.put(m.text); true }))
}
def awaitEvent(expected: String): Unit = {
  val got = events.poll(20, TimeUnit.SECONDS)
  require(got == expected, s"expected $expected got $got")
  println("HOST_EVENT " + got)
}
val opts = Options.init() + "threads=2"
val start = System.nanoTime()
val resources = Headless.Resources.make(opts, "Veri7vn_Runtime_Host", Logger.none,
  session_dirs = List(Path.explode("experiments/runtime-host")))
val session = resources.start_session()
try {
  session.init_protocol_handler(new Handler)
  println("HOST_STARTUP_MS " + (System.nanoTime() - start) / 1000000)
  def command(parts: String*) = session.protocol_command_raw("veri7vn_host_v1", parts.toList.map(Bytes.apply))
  for (i <- 1 to 5) {
    val t = System.nanoTime(); command("1", i.toString, "ping"); awaitEvent(i.toString + ":pong")
    println("HOST_WARM_MS " + (System.nanoTime() - t) / 1000000.0)
  }
  command("0", "bad", "ping"); awaitEvent("protocol:version_or_shape_rejected")
  command("1", "long", "run"); awaitEvent("long:started")
  val cancelStart = System.nanoTime()
  command("1", "stop", "cancel")
  val cancelled = Set(events.poll(20, TimeUnit.SECONDS), events.poll(20, TimeUnit.SECONDS))
  require(cancelled == Set("stop:cancelled", "long:interrupted"), cancelled.toString)
  println("HOST_CANCEL_MS " + (System.nanoTime() - cancelStart) / 1000000.0)
  println("HOST_CANCEL_PASS " + cancelled)
} finally { session.stop() }
println("HOST_PROTOCOL_PASS")
val restarted = resources.start_session()
try {
  restarted.init_protocol_handler(new Handler)
  restarted.protocol_command_raw("veri7vn_host_v1", List("1", "restart", "ping").map(Bytes.apply))
  awaitEvent("restart:pong")
} finally { restarted.stop() }
println("HOST_WORKER_RESTART_PASS")

}
