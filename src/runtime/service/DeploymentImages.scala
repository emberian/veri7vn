package veri7vn.runtime.service

import isabelle.*
import scala.language.unsafeNulls
import java.nio.file.{Files,Path as JPath,StandardOpenOption,StandardCopyOption,LinkOption}
import java.nio.channels.FileChannel
import java.security.MessageDigest

object DeploymentImages {
  private val monitors=new java.util.concurrent.ConcurrentHashMap[String,Object]()
  private[service] def monitor(path:JPath):Object=monitors.computeIfAbsent(path.toRealPath().toString,_=>new Object())
}

/** Managed public deployment images. Private request contexts are never exported
  * here. Existing immutable images are reused; leases prevent owned retirement. */
final class DeploymentImages(root:JPath) {
  private val nofollow=LinkOption.NOFOLLOW_LINKS
  private def directory(path:JPath):JPath={
    if(!Files.exists(path,nofollow)) {
      Files.createDirectory(path)
      Files.setPosixFilePermissions(path,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"))
    }
    require(Files.isDirectory(path,nofollow),"deployment directory shape")
    require(java.nio.file.attribute.PosixFilePermissions.fromString("rwx------").containsAll(Files.getPosixFilePermissions(path)),"deployment directory must be private")
    path
  }
  private val newRoot= !Files.exists(root,nofollow)
  if(newRoot) {
    Files.createDirectories(root)
    Files.setPosixFilePermissions(root,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"))
  }
  directory(root)
  private val ownerMarker=root.resolve("veri7vn-deployment-owner")
  if(newRoot) {
    Files.writeString(ownerMarker,"veri7vn-public-deployment-images/1\n",StandardOpenOption.CREATE_NEW)
    val channel=FileChannel.open(ownerMarker,StandardOpenOption.WRITE)
    try channel.force(true) finally channel.close()
  }
  require(Files.isRegularFile(ownerMarker,nofollow) && Files.size(ownerMarker)<=128 &&
    Files.readString(ownerMarker)=="veri7vn-public-deployment-images/1\n","unowned deployment directory")
  private val images=directory(root.resolve("images"))
  private val pointers=directory(root.resolve("selected"))
  private def locked[A](action: => A):A=DeploymentImages.monitor(root).synchronized {
    val channel=FileChannel.open(root.resolve("installation.lock"),StandardOpenOption.CREATE,StandardOpenOption.WRITE)
    try {val lock=channel.lock();try action finally lock.release()} finally channel.close()
  }
  private def hash(bytes:Array[Byte]):String=MessageDigest.getInstance("SHA-256").digest(bytes).map(b=>f"${b & 255}%02x").mkString
  private def textHash(text:String):String=hash(text.getBytes(java.nio.charset.StandardCharsets.UTF_8))
  private def forceDirectory(path:JPath):Unit={val f=FileChannel.open(path,StandardOpenOption.READ);try f.force(true) finally f.close()}
  private def fileHash(path:JPath,copy:Option[JPath]=None):String={
    require(Files.isRegularFile(path,nofollow),"deployment artifact shape")
    val input=Files.newInputStream(path,nofollow)
    val output=copy.map(p=>FileChannel.open(p,StandardOpenOption.CREATE_NEW,StandardOpenOption.WRITE))
    val digest=MessageDigest.getInstance("SHA-256")
    try {val buffer=new Array[Byte](1024*1024);var n=input.read(buffer)
      while(n != -1){digest.update(buffer,0,n);output.foreach {f=>val bytes=java.nio.ByteBuffer.wrap(buffer,0,n);while(bytes.hasRemaining)f.write(bytes)};n=input.read(buffer)}
      output.foreach(_.force(true));digest.digest().map(b=>f"${b & 255}%02x").mkString
    } finally {input.close();output.foreach(_.close())}
  }
  final class Lease private[DeploymentImages](val identity:String,val manifest:String,val heaps:List[Path],val captureMillis:Double,
    private val marker:JPath) extends AutoCloseable {
    private var closed=false
    def close():Unit=locked {if(!closed){Files.deleteIfExists(marker);forceDirectory(marker.getParent);closed=true}}
  }
  /** Qualifies actual prebuilt heaps once. Future starts use only the private
    * immutable copies; build UUID/options select a deployment, not native truth. */
  private[service] def acquire(resources:Headless.Resources,sessionName:String,options:Options):Lease=locked {
    val started=System.nanoTime()
    val background=resources.parent_background
    val names=background.sessions_structure.selection(sessionName).build_requirements(List(sessionName))
    require(names.nonEmpty && names.size<=128,"deployment heap count")
    val store=resources.store
    val sourceHeaps=store.session_heaps(background,logic=sessionName)
    require(sourceHeaps.size==names.size,"deployment heap mapping")
    val build=names.map {name=>
      val database=store.open_database(name)
      val info=try store.read_build(database,name).getOrElse(sys.error("deployment build metadata missing")) finally database.close()
      require(info.ok,"deployment build incomplete")
      s"$name\n${info.uuid}\n${info.sources_conditions}\n${info.input_heaps}\n${info.output_heap}"
    }.mkString("\n--build--\n")
    val executable=store.ml_settings.polyml_exe.file.toPath
    val toolkit=java.nio.file.Paths.get(classOf[Session].getProtectionDomain.getCodeSource.getLocation.toURI)
    require(Files.isRegularFile(toolkit,nofollow),"immutable Isabelle toolkit artifact required")
    val setup=List("veri7vn-deployment-image/1",sessionName,Isabelle_System.isabelle_id(),fileHash(toolkit),
      Isabelle_System.getenv("ML_PLATFORM"),fileHash(executable),
      textHash(ML_Process.pure_prelude),options.iterator.toList.sortBy(_.name).map(_.print).mkString("\n"),build).mkString("\n--setup--\n")
    require(setup.getBytes(java.nio.charset.StandardCharsets.UTF_8).length<=1024*1024,"deployment setup bound")
    val key=textHash(setup);val pointer=pointers.resolve(key)
    val identity=if(Files.exists(pointer,nofollow)) {
      require(Files.size(pointer)==64 && Files.isRegularFile(pointer,nofollow),"deployment selector shape")
      val id=Files.readString(pointer);require(id.matches("[0-9a-f]{64}"));id
    } else {
      val temporary=directory(images.resolve("install-"+java.util.UUID.randomUUID()))
      try {
        var total=0L
        val entries=sourceHeaps.zipWithIndex.map {case(path,index)=>
          val source=path.file.toPath;val size=Files.size(source)
          require(size>=0 && size<=4L*1024*1024*1024,"deployment heap bound")
          total+=size;require(total<=8L*1024*1024*1024,"deployment total heap bound")
          val target=temporary.resolve(s"heap-$index")
          val digest=fileHash(source,Some(target));require(Files.size(target)==size,"deployment heap changed during capture")
          Files.setPosixFilePermissions(target,java.nio.file.attribute.PosixFilePermissions.fromString("r--------"))
          s"$index:$size:$digest"
        }
        val manifest=setup+"\n--heaps--\n"+entries.mkString("\n")
        require(manifest.getBytes(java.nio.charset.StandardCharsets.UTF_8).length<=1024*1024,"deployment manifest native cap")
        val id=textHash(manifest)
        Files.writeString(temporary.resolve("manifest"),manifest,StandardOpenOption.CREATE_NEW)
        val m=FileChannel.open(temporary.resolve("manifest"),StandardOpenOption.WRITE);try m.force(true) finally m.close()
        Files.setPosixFilePermissions(temporary.resolve("manifest"),java.nio.file.attribute.PosixFilePermissions.fromString("r--------"))
        directory(temporary.resolve("leases"));forceDirectory(temporary)
        val destination=images.resolve(id)
        if(Files.exists(destination,nofollow)) {
          require(Files.readString(destination.resolve("manifest"))==manifest,"deployment identity collision")
          val walk=Files.walk(temporary)
          try walk.sorted(java.util.Comparator.reverseOrder[JPath]()).forEach(p=>Files.deleteIfExists(p)) finally walk.close()
        } else Files.move(temporary,destination,StandardCopyOption.ATOMIC_MOVE)
        forceDirectory(images)
        val selected=Files.createTempFile(pointers,"select-",".tmp")
        Files.writeString(selected,id);val f=FileChannel.open(selected,StandardOpenOption.WRITE);try f.force(true) finally f.close()
        Files.move(selected,pointer,StandardCopyOption.ATOMIC_MOVE);forceDirectory(pointers)
        id
      } catch {case failure:Throwable=>
        if(Files.exists(temporary,nofollow)) {
          val walk=Files.walk(temporary)
          try walk.sorted(java.util.Comparator.reverseOrder[JPath]()).forEach(p=>Files.deleteIfExists(p)) finally walk.close()
        }
        throw failure
      }
    }
    val image=images.resolve(identity);require(Files.isDirectory(image,nofollow) && !Files.exists(image.resolve("retiring"),nofollow),"deployment image missing or retiring")
    val manifestPath=image.resolve("manifest")
    require(Files.isRegularFile(manifestPath,nofollow) && Files.size(manifestPath)<=1024*1024,"deployment manifest bound")
    val manifest=Files.readString(manifestPath);require(textHash(manifest)==identity && manifest.startsWith(setup+"\n--heaps--\n"),"deployment identity mismatch")
    val records=manifest.substring(setup.length+"\n--heaps--\n".length).split("\n",-1).toList
    require(records.size==names.size,"deployment image heap count")
    val heaps=records.zipWithIndex.map {case(record,index)=>
      val fields=record.split(":",-1);require(fields.length==3 && fields(0)==index.toString && fields(1).matches("[0-9]{1,12}") && fields(2).matches("[0-9a-f]{64}"),"deployment heap record")
      val file=image.resolve(s"heap-$index")
      require(Files.isRegularFile(file,nofollow) && Files.size(file)==fields(1).toLong &&
        Files.getPosixFilePermissions(file)==java.nio.file.attribute.PosixFilePermissions.fromString("r--------"),"deployment immutable heap changed")
      Path.explode(file.toString)
    }
    val marker=image.resolve("leases").resolve(java.util.UUID.randomUUID().toString)
    Files.writeString(marker,ProcessHandle.current().pid().toString,StandardOpenOption.CREATE_NEW);forceDirectory(marker.getParent)
    new Lease(identity,manifest,heaps,(System.nanoTime()-started)/1000000.0,marker)
  }
  /** Only this installation's known public images; active/stale leases prevent retirement. */
  def retire(identity:String):Boolean=locked {
    require(identity.matches("[0-9a-f]{64}"));val image=images.resolve(identity)
    if(!Files.exists(image,nofollow))true else {
      val active=if(Files.exists(image.resolve("leases"),nofollow)) {
        val leases=Files.list(image.resolve("leases"));try leases.findAny().isPresent finally leases.close()
      } else false
      if(active)false else {
        val source=if(Files.exists(image.resolve("manifest"),nofollow))image.resolve("manifest") else image.resolve("retiring")
        val manifest=Files.readString(source);require(textHash(manifest)==identity)
        if(!Files.exists(image.resolve("retiring"),nofollow)) {
          Files.writeString(image.resolve("retiring"),manifest,StandardOpenOption.CREATE_NEW)
          val record=FileChannel.open(image.resolve("retiring"),StandardOpenOption.WRITE);try record.force(true) finally record.close()
          forceDirectory(image)
        }
        val heapLines=manifest.split("\n--heaps--\n",-1).last.split("\n").toList
        heapLines.indices.foreach(i=>Files.deleteIfExists(image.resolve(s"heap-$i")))
        Files.deleteIfExists(image.resolve("manifest"));Files.deleteIfExists(image.resolve("leases"));Files.deleteIfExists(image.resolve("retiring"));Files.delete(image)
        val selected=Files.list(pointers)
        try selected.forEach(p=>{if(Files.size(p)==64 && Files.readString(p)==identity)Files.delete(p)}) finally selected.close()
        forceDirectory(images);forceDirectory(pointers);true
      }
    }
  }
}
