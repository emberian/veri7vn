import isabelle.*
import scala.language.unsafeNulls
import java.nio.file.{Files, StandardCopyOption}
import java.security.MessageDigest

// Feasibility fixture. This monitor is the single writer / retirement coordinator.
class DurableHost(root: java.nio.file.Path) extends AutoCloseable {
  Files.createDirectories(root)
  private val lockChannel=java.nio.channels.FileChannel.open(root.resolve("writer.lock"),
    java.nio.file.StandardOpenOption.CREATE,java.nio.file.StandardOpenOption.WRITE)
  private val writerLock=try {
    val lock=lockChannel.tryLock()
    if(lock==null) {lockChannel.close(); error("workspace writer already active")}
    lock
  } catch {case e: Throwable => lockChannel.close(); throw e}
  val db = SQLite.open_database(Path.explode(root.resolve("journal.db").toString))
  val c = db.connection
  def sql(s: String): Unit = { val q = c.createStatement(); try q.execute(s) finally q.close() }
  sql("PRAGMA journal_mode=WAL"); sql("PRAGMA synchronous=FULL")
  sql("CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY, revision INTEGER, epoch INTEGER)")
  sql("INSERT OR IGNORE INTO state VALUES(1,0,0)")
  sql("CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, revision INTEGER, epoch INTEGER, artifact TEXT)")
  sql("CREATE TABLE IF NOT EXISTS cancellations (id TEXT PRIMARY KEY)")
  sql("CREATE TABLE IF NOT EXISTS attempts (id TEXT PRIMARY KEY, epoch INTEGER, status TEXT)")
  def image: (Long, Long) = synchronized {
    val q = c.createStatement(); try { val r=q.executeQuery("SELECT revision,epoch FROM state"); r.next(); (r.getLong(1),r.getLong(2)) } finally q.close()
  }
  def artifact(bytes: Array[Byte]): String = {
    val hash=MessageDigest.getInstance("SHA-256").digest(bytes).map(b=>f"${b & 255}%02x").mkString
    val dst=root.resolve(hash)
    if (!Files.exists(dst)) {
      val tmp=Files.createTempFile(root,"blob-",".tmp")
      val out=java.nio.channels.FileChannel.open(tmp,java.nio.file.StandardOpenOption.WRITE)
      try { val buffer=java.nio.ByteBuffer.wrap(bytes); while(buffer.hasRemaining) out.write(buffer); out.force(true) } finally out.close()
      Files.move(tmp,dst,StandardCopyOption.ATOMIC_MOVE)
      val dir=java.nio.channels.FileChannel.open(root,java.nio.file.StandardOpenOption.READ)
      try dir.force(true) finally dir.close()
    }
    require(java.util.Arrays.equals(Files.readAllBytes(dst),bytes)); hash
  }
  def commit(id: String, revision: Long, epoch: Long, body: Array[Byte], fault: String=""): String = synchronized {
    require(id.matches("[a-zA-Z0-9_-]+"))
    if (image != ((revision,epoch))) return "conflict"
    val hash=artifact(body)
    c.setAutoCommit(false)
    try {
      val q=c.prepareStatement("INSERT INTO events VALUES(?,?,?,?)")
      try { q.setString(1,id); q.setLong(2,revision+1); q.setLong(3,epoch); q.setString(4,hash); q.executeUpdate() } finally q.close()
      sql(s"UPDATE state SET revision=${revision+1} WHERE id=1")
      if(fault=="halt-before") Runtime.getRuntime.halt(73)
      if(fault=="before") throw new RuntimeException("before commit")
      c.commit()
      if(fault=="halt-after") Runtime.getRuntime.halt(74)
      if(fault=="after") throw new RuntimeException("committed without acknowledgement")
      "ack"
    } catch { case e: Throwable => c.rollback(); throw e } finally c.setAutoCommit(true)
  }
  def committedBody(id: String): Array[Byte] = synchronized {
    val q=c.prepareStatement("SELECT artifact FROM events WHERE id=?")
    try {
      q.setString(1,id); val r=q.executeQuery(); require(r.next())
      val hash=r.getString(1); val body=Files.readAllBytes(root.resolve(hash))
      require(MessageDigest.getInstance("SHA-256").digest(body).map(b=>f"${b & 255}%02x").mkString==hash)
      body
    } finally q.close()
  }
  def attemptStatus(id: String): String = synchronized {
    val q=c.prepareStatement("SELECT status FROM attempts WHERE id=?")
    try { q.setString(1,id); val r=q.executeQuery(); require(r.next()); r.getString(1) } finally q.close()
  }
  def cancel(id: String): Unit = synchronized {
    val q=c.prepareStatement("INSERT OR IGNORE INTO cancellations VALUES(?)")
    try {q.setString(1,id); q.executeUpdate()} finally q.close()
  }
  private def isCancelled(id: String): Boolean = {
    val q=c.prepareStatement("SELECT id FROM cancellations WHERE id=?")
    try {q.setString(1,id); val r=q.executeQuery(); r.next()} finally q.close()
  }
  def retire(): Unit = synchronized { sql("UPDATE state SET epoch=epoch+1 WHERE id=1") }
  def claimAndStart(id: String, epoch: Long, expectedRevision: Long)(handoff: => Unit): String = synchronized {
    require(id.matches("[a-zA-Z0-9_-]+"))
    if(isCancelled(id)) return "cancelled"
    if(image._2 != epoch) return "retired"
    if(image._1 != expectedRevision) return "revision_conflict"
    // Unique durable attempt consumes this lease. Recovery never auto-retries it.
    try sql(s"INSERT INTO attempts VALUES('$id',$epoch,'unknown')")
    catch { case e: java.sql.SQLException if e.getErrorCode == 19 => return "consumed" }
    handoff // handoff itself linearizes dispatch while retirement cannot interleave
    sql(s"UPDATE attempts SET status='handed_off' WHERE id='$id'")
    "started"
  }
  def close(): Unit = { db.close(); writerLock.release(); lockChannel.close() }
}
@main def runtimeHostDurableProbe(): Unit = {
if (sys.env.contains("VERI7VN_HOST_CRASH_ROOT")) {
  val child = new DurableHost(java.nio.file.Path.of(sys.env("VERI7VN_HOST_CRASH_ROOT")))
  val mode=sys.env("VERI7VN_HOST_CRASH_MODE")
  if(mode=="halt-dispatch") child.claimAndStart("child",0,0){Runtime.getRuntime.halt(75)}
  else child.commit("child",0,0,"process crash payload".getBytes,mode)
  error("expected process halt")
} else {
val root=Files.createTempDirectory("veri7vn-host-durable-")
var host=new DurableHost(root)
try {new DurableHost(root); error("second writer accepted")}
catch {case _: java.nio.channels.OverlappingFileLockException => ()}
val commitStart=System.nanoTime()
require(host.commit("one",0,0,"structured state".getBytes)=="ack")
println("HOST_DURABLE_COMMIT_MS " + (System.nanoTime()-commitStart)/1000000.0)
require(host.commit("stale",0,0,Array[Byte](1))=="conflict")
try host.commit("before",1,0,Array[Byte](2),"before") catch { case _: RuntimeException => () }
require(host.image == ((1L,0L)))
try host.commit("after",1,0,Array[Byte](3),"after") catch { case _: RuntimeException => () }
host.close(); host=new DurableHost(root)
require(host.image == ((2L,0L)))
require(new String(host.committedBody("one"),java.nio.charset.StandardCharsets.UTF_8)=="structured state")
var replayRejected=false
try host.commit("one",2,0,Array[Byte](8))
catch {case e: java.sql.SQLException if e.getErrorCode==19 => replayRejected=true}
require(replayRejected && host.image==((2L,0L)))
var launches=0
host.cancel("cancelled")
require(host.claimAndStart("cancelled",0,2){launches+=1}=="cancelled")
require(host.claimAndStart("old_revision",0,1){launches+=1}=="revision_conflict")
require(host.claimAndStart("lease",0,2){launches+=1}=="started")
require(host.claimAndStart("lease",0,2){launches+=1}=="consumed")
host.retire()
require(host.attemptStatus("lease")=="handed_off")
require(host.commit("old_epoch",2,0,Array[Byte](9))=="conflict")
require(host.claimAndStart("retired",0,2){launches+=1}=="retired")
require(launches==1)
try host.claimAndStart("crash",1,2){throw new RuntimeException("handoff uncertain")} catch {case _: RuntimeException=>()}
host.close(); host=new DurableHost(root)
require(host.attemptStatus("crash")=="unknown")
require(host.claimAndStart("crash",1,2){launches+=1}=="consumed")
require(launches==1)
println("HOST_DURABLE_PASS before rollback; after recovered; stale rejected; lease single use; retired rejected; crash unknown")
println("HOST_DURABLE_STATE " + root)
host.close()
// Race: retirement must wait for the actual executor handoff, never a delayed queue.
val race=new DurableHost(Files.createTempDirectory("veri7vn-host-race-"))
val entered=new java.util.concurrent.CountDownLatch(1)
val release=new java.util.concurrent.CountDownLatch(1)
val retired=new java.util.concurrent.CountDownLatch(1)
val raceResult=new java.util.concurrent.atomic.AtomicReference[String]()
val worker=new Thread(new Runnable {def run(): Unit = {raceResult.set(race.claimAndStart("race",0,0){entered.countDown(); release.await()})}})
worker.start(); require(entered.await(5,java.util.concurrent.TimeUnit.SECONDS))
val retirement=new Thread(new Runnable {def run(): Unit = {race.retire(); retired.countDown()}})
retirement.start(); val retirementBlocked= !retired.await(100,java.util.concurrent.TimeUnit.MILLISECONDS)
release.countDown(); worker.join(); retirement.join(); require(retirementBlocked && race.image._2==1 && raceResult.get()=="started")
race.close(); println("HOST_HANDOFF_RETIREMENT_SERIALIZED_PASS")

// Kill the actual JVM at the transaction seam; parent reopens without replay.
for ((fault,code,revision) <- List(("halt-before",73,0L),("halt-after",74,1L),("halt-dispatch",75,0L))) {
  val crashRoot=Files.createTempDirectory("veri7vn-host-process-crash-")
  val command=new ProcessBuilder(Isabelle_System.getenv("ISABELLE_HOME")+"/bin/isabelle",
    "scala", "experiments/runtime-host/durable.scala")
  command.environment().put("VERI7VN_HOST_CRASH_ROOT",crashRoot.toString)
  command.environment().put("VERI7VN_HOST_CRASH_MODE",fault)
  command.inheritIO()
  val process=command.start()
  if(!process.waitFor(90,java.util.concurrent.TimeUnit.SECONDS)) {
    val descendants=process.descendants()
    try descendants.forEach(p => {p.destroyForcibly(); ()}) finally descendants.close()
    process.destroyForcibly(); process.waitFor(); error("crash child timed out")
  }
  require(process.exitValue()==code)
  val recovered=new DurableHost(crashRoot)
  require(recovered.image==((revision,0L)))
  if(revision==1) require(new String(recovered.committedBody("child"))=="process crash payload")
  if(fault=="halt-dispatch") {
    require(recovered.attemptStatus("child")=="unknown")
    require(recovered.claimAndStart("child",0,0){error("must not retry unknown") }=="consumed")
  }
  recovered.close()
  println("HOST_PROCESS_CRASH_PASS " + fault + " revision=" + revision + " root=" + crashRoot)
}
}

}
