package veri7vn.packages.intake

import scala.language.unsafeNulls
import java.io.{ByteArrayInputStream, ByteArrayOutputStream, InputStream}
import java.nio.{ByteBuffer, ByteOrder}
import java.nio.charset.{CodingErrorAction, StandardCharsets}
import java.nio.file.{Files, Path, LinkOption, StandardCopyOption, StandardOpenOption, FileVisitResult, SimpleFileVisitor, SecureDirectoryStream, OpenOption}
import java.nio.file.attribute.BasicFileAttributes
import java.nio.channels.FileChannel
import java.security.MessageDigest
import java.text.Normalizer
import java.util.Locale
import java.util.zip.{CRC32, ZipInputStream}
import scala.collection.mutable

/** Inert bytes only. No source language interpreter, module loader, or publication path. */
object Intake {
  final class Rejected(val code: String, message: String) extends IllegalArgumentException(message)
  private def reject(code: String, message: String): Nothing = throw new Rejected(code, message)
  final case class Limits(maxArchiveBytes: Int = 32 * 1024 * 1024,
    maxFileBytes: Int = 8 * 1024 * 1024, maxTotalBytes: Long = 64L * 1024 * 1024,
    maxEntries: Int = 2048, maxPathBytes: Int = 512, maxDepth: Int = 24,
    maxCompressionRatio: Int = 200) {
    require(maxArchiveBytes > 0 && maxFileBytes > 0 && maxTotalBytes > 0 &&
      maxEntries > 0 && maxPathBytes > 0 && maxDepth > 0 && maxCompressionRatio > 0)
  }
  final class Content private (private val value: Array[Byte]) {
    val sha256: String = hash(value)
    def size: Int = value.length
    def bytes: Array[Byte] = value.clone()
    private[intake] def raw: Array[Byte] = value // only this package's storage/parser may access
  }
  object Content { def apply(bytes: Array[Byte]): Content = new Content(bytes.clone()) }
  def hash(bytes: Array[Byte]): String = MessageDigest.getInstance("SHA-256")
    .digest(bytes).map(b => f"${b & 255}%02x").mkString
  enum Format { case Oracle7Original, NativeDevelopment }
  enum Role { case Descriptor, Documentation, Examples, Exposure, SenderVerdict,
    UnresolvedExecutable, SourceData, Other }
  final case class Entry(path: String, content: Content, role: Role)
  final case class Staged(format: Format, entries: Vector[Entry], identity: String,
    originalArchive: Option[Content], originLabel: String) {
    def exposure: Vector[Entry] = entries.filter(_.role == Role.Exposure)
    def unresolved: Vector[Entry] = entries.filter(e => e.role == Role.UnresolvedExecutable || e.role == Role.Other)
  }
  private def utf8(bytes: Array[Byte]): String =
    try StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
      .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString
    catch { case _: java.nio.charset.CharacterCodingException => reject("encoding", "Malformed UTF-8") }
  private val reserved = "(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)?".r
  def portablePath(name: String, limits: Limits = Limits()): String = {
    val n = Normalizer.normalize(name, Normalizer.Form.NFC)
    if (n != name || name.isEmpty || name.getBytes(StandardCharsets.UTF_8).length > limits.maxPathBytes ||
      name.exists(c => c < ' ' || c == '\\' || c == ':' || c == '\u007f' || "<>\"|?*".contains(c)) || name.startsWith("/") || name.contains('\ufffd') || utf8(name.getBytes(StandardCharsets.UTF_8)) != name)
      reject("path", "Nonportable path: " + name.take(120))
    val parts = name.split("/", -1)
    if (parts.length > limits.maxDepth || parts.exists(p => p.isEmpty || p != p.trim || p == "." || p == ".." ||
      p.endsWith(".") || reserved.matches(p))) reject("path", "Ambiguous path: " + name.take(120))
    n
  }
  private def role(path: String): Role = {
    val name = path.split('/').last.toLowerCase(Locale.ROOT)
    if (name == "exam_log.jsonl" || name == "exposure.jsonl") Role.Exposure
    else if (name.startsWith("verdict_") || name.startsWith("shared_verdict_")) Role.SenderVerdict
    else if (name == "manifest.json" || name == "package.json") Role.Descriptor
    else if (name.endsWith(".py") || name.endsWith(".thy") || name.endsWith(".ml") ||
      name.endsWith(".scala") || name.endsWith(".sh") ||
      List(".jar", ".class", ".exe", ".dll", ".so", ".dylib", ".js", ".wasm").exists(name.endsWith)) Role.UnresolvedExecutable
    else if (name.endsWith(".md") || name.endsWith(".txt")) Role.Documentation
    else if (name == "panel.json") Role.Examples
    else if (name.endsWith(".csv") || name.endsWith(".tsv")) Role.SourceData
    else Role.Other
  }
  private def pathKey(path: String): String = Normalizer.normalize(
    path.toUpperCase(Locale.ROOT).toLowerCase(Locale.ROOT),Normalizer.Form.NFC)
  private def checkedPaths(paths: Iterable[String], limits: Limits): Unit = {
    val seen = mutable.HashSet[String]()
    paths.foreach { path =>
      portablePath(path, limits)
      val key = pathKey(path)
      if (!seen.add(key)) reject("duplicate", "Duplicate/case-ambiguous path: " + path)
    }
    seen.foreach { p =>
      val parts = p.split('/')
      for (i <- 1 until parts.length)
        if (seen.contains(parts.take(i).mkString("/"))) reject("path", "File/directory collision")
    }
  }
  private def digestEntries(entries: Vector[Entry], parent: Option[String] = None): String = {
    val md = MessageDigest.getInstance("SHA-256")
    def field(b: Array[Byte]): Unit = { md.update(ByteBuffer.allocate(8).putLong(b.length.toLong).array()); md.update(b) }
    field("veri7vn-inert-source-v1".getBytes(StandardCharsets.UTF_8))
    parent.foreach(p => field(p.getBytes(StandardCharsets.US_ASCII)))
    entries.sortBy(_.path).foreach { e =>
      field(e.path.getBytes(StandardCharsets.UTF_8)); field(e.content.raw)
    }
    md.digest().map(b => f"${b & 255}%02x").mkString
  }
  private def stage(files: Vector[(String, Content)], format: Format, origin: String,
    archive: Option[Content], limits: Limits): Staged = {
    if (files.isEmpty) reject("format", "Empty package")
    if (files.size>limits.maxEntries || files.exists(_._2.size>limits.maxFileBytes) ||
      files.map(_._2.size.toLong).sum>limits.maxTotalBytes) reject("bounds", "Package source exceeds limits")
    checkedPaths(files.map(_._1), limits)
    val descriptor = if (format == Format.Oracle7Original) "manifest.json" else "package.json"
    // Accept a package-root directory or one common archive wrapper directory, never arbitrary flattening.
    val names = files.map(_._1)
    val root = if (names.contains(descriptor)) "" else {
      val first = names.map(_.takeWhile(_ != '/')).distinct
      if (first.size != 1 || !names.contains(first.head + "/" + descriptor))
        reject("format", "Missing package-root " + descriptor)
      first.head + "/"
    }
    val entries = files.map { case (p, b) =>
      val path = p.substring(root.length); Entry(path, b, role(path))
    }.sortBy(_.path)
    checkedPaths(entries.map(_.path), limits)
    Staged(format, entries, digestEntries(entries), archive, origin)
  }
  private def bounded(in: InputStream, max: Long): Array[Byte] = {
    val out = new ByteArrayOutputStream(); val buffer = new Array[Byte](8192)
    var total = 0L; var count = in.read(buffer)
    while (count != -1) {
      total += count
      if (total > max) reject("bounds", "Input exceeds byte limit")
      out.write(buffer, 0, count); count = in.read(buffer)
    }
    out.toByteArray
  }
  private case class ZipMeta(path: String, directory: Boolean, size: Long,
    compressed: Long, crc: Long, offset: Long, method: Int, flags: Int)
  private def central(bytes: Array[Byte], limits: Limits): Vector[ZipMeta] = {
    val b = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
    def u16(i: Int): Int = b.getShort(i) & 65535
    def u32(i: Int): Long = b.getInt(i).toLong & 0xffffffffL
    def range(i: Long, n: Long): Unit =
      if (i < 0 || n < 0 || i > bytes.length.toLong - n) reject("zip", "Truncated ZIP structure")
    // Require terminal EOCD, so arbitrary trailer bytes/concatenated archives cannot hide entries.
    val min = math.max(0, bytes.length - 65557)
    val end = (bytes.length - 22 to min by -1).find { i =>
      i >= 0 && u32(i) == 0x06054b50L && i.toLong + 22 + u16(i + 20) == bytes.length
    }.getOrElse(reject("zip", "Missing ZIP end record"))
    if (u16(end+4) != 0 || u16(end+6) != 0 || u16(end+8) != u16(end+10))
      reject("zip", "Multi-disk archives unsupported")
    val count = u16(end+10); val size = u32(end+12); val start = u32(end+16)
    if (count == 65535 || size == 0xffffffffL || start == 0xffffffffL)
      reject("zip", "ZIP64 unsupported; use a bounded ordinary ZIP")
    if (count > limits.maxEntries) reject("bounds", "Too many entries")
    range(start,size)
    if (start+size != end) reject("zip", "Ambiguous central directory")
    var pos = start.toInt; var total = 0L
    val entries = Vector.newBuilder[ZipMeta]
    for (_ <- 0 until count) {
      range(pos,46)
      if (u32(pos) != 0x02014b50L) reject("zip", "Bad central entry")
      val flags=u16(pos+8); val method=u16(pos+10)
      if ((flags & ~0x080e) != 0 || (flags & 1) != 0 || (method != 0 && method != 8))
        reject("zip", "Unsupported compression/encryption/flags")
      val compressed=u32(pos+20); val length=u32(pos+24)
      val nl=u16(pos+28); val xl=u16(pos+30); val cl=u16(pos+32)
      range(pos.toLong+46,nl.toLong+xl+cl)
      if (u16(pos+34) != 0) reject("zip", "Entry disk unsupported")
      val raw = java.util.Arrays.copyOfRange(bytes,pos+46,pos+46+nl)
      if ((flags & 0x800)==0 && raw.exists(x => (x & 255)>127)) reject("encoding", "ZIP names must use UTF-8")
      val path = utf8(raw); val directory=path.endsWith("/")
      portablePath(if (directory) path.dropRight(1) else path,limits)
      val mode=((u32(pos+38) >>> 16) & 0xf000).toInt
      if (mode != 0 && mode != (if (directory) 0x4000 else 0x8000))
        reject("link", "Links and special archive members are forbidden")
      // Reject ZIP64 and alternate Unicode-path extras: central/local names alone are authoritative.
      var x=pos+46+nl; val xe=x+xl
      while(x < xe) {
        if(x+4>xe) reject("zip", "Malformed extra field")
        val tag=u16(x); val len=u16(x+2)
        if(x.toLong+4+len>xe || tag==1 || tag==0x7075) reject("zip", "Unsupported/ambiguous extra field")
        x+=4+len
      }
      total+=length
      if(length>limits.maxFileBytes || total>limits.maxTotalBytes ||
        length>math.max(1L,compressed)*limits.maxCompressionRatio || (directory && length != 0))
        reject("bounds", "Expanded size or compression ratio exceeds limit")
      val offset=u32(pos+42); range(offset,30)
      if(offset>=start || u32(offset.toInt)!=0x04034b50L) reject("zip", "Bad local header offset")
      entries += ZipMeta(path,directory,length,compressed,u32(pos+16),offset,method,flags)
      pos+=46+nl+xl+cl
    }
    if(pos.toLong != start+size) reject("zip", "Central directory length mismatch")
    val result=entries.result()
    var localEnd=0L
    result.foreach { e =>
      if(e.offset!=localEnd) reject("zip", "Overlapping, reordered or hidden local members")
      val at=e.offset.toInt
      val nl=u16(at+26);val xl=u16(at+28);range(e.offset+30,nl.toLong+xl+e.compressed)
      if(u16(at+6)!=e.flags || u16(at+8)!=e.method ||
        utf8(java.util.Arrays.copyOfRange(bytes,at+30,at+30+nl))!=e.path)
        reject("zip", "Local/central header disagreement")
      var x=at+30+nl;val xe=x+xl
      while(x<xe) {
        if(x+4>xe || x.toLong+4+u16(x+2)>xe || u16(x)==1 || u16(x)==0x7075)
          reject("zip", "Ambiguous local extra field")
        x+=4+u16(x+2)
      }
      localEnd=e.offset+30+nl+xl+e.compressed
      if((e.flags & 8)!=0) {
        range(localEnd,12)
        val signature=u32(localEnd.toInt)==0x08074b50L
        val dd=(localEnd+(if(signature)4 else 0)).toInt;range(dd,12)
        if(u32(dd)!=e.crc || u32(dd+4)!=e.compressed || u32(dd+8)!=e.size)
          reject("zip", "Data descriptor mismatch")
        localEnd=dd.toLong+12
      } else if(u32(at+14)!=e.crc || u32(at+18)!=e.compressed || u32(at+22)!=e.size)
        reject("zip", "Local size/CRC disagreement")
    }
    if(localEnd!=start) reject("zip", "Unlisted bytes before central directory")
    val canonical=result.map(e => if(e.directory)e.path.dropRight(1) else e.path)
    if(canonical.map(pathKey).distinct.size != canonical.size)
      reject("duplicate", "Duplicate/ambiguous ZIP members")
    checkedPaths(result.filterNot(_.directory).map(_.path),limits)
    // Empty directory members also inhabit the namespace: a file cannot be an ancestor.
    val files=result.filterNot(_.directory).map(e => pathKey(e.path)).toSet
    result.foreach { entry =>
      val parts=pathKey(if(entry.directory)entry.path.dropRight(1)else entry.path).split('/')
      for(i <- 1 until parts.length)
        if(files.contains(parts.take(i).mkString("/"))) reject("path","File/directory collision")
    }
    result
  }
  def zip(path: Path, format: Format, limits: Limits = Limits()): Staged = {
    if(!Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS)) reject("link", "Archive must be a regular file")
    val in=Files.newInputStream(path,LinkOption.NOFOLLOW_LINKS)
    val bytes=try bounded(in,limits.maxArchiveBytes) finally in.close()
    val metadata=central(bytes,limits)
    val stream=new ZipInputStream(new ByteArrayInputStream(bytes),StandardCharsets.UTF_8)
    val files=Vector.newBuilder[(String,Content)]
    var index=0; var total=0L
    try {
      var entry=stream.getNextEntry()
      while(entry != null) {
        if(index>=metadata.size) reject("zip", "Unlisted local member")
        val meta=metadata(index)
        if(entry.getName != meta.path || entry.getMethod != meta.method)
          reject("zip", "Local and central member order/name mismatch")
        val content=bounded(stream,math.min(limits.maxFileBytes.toLong,limits.maxTotalBytes-total))
        total+=content.length
        val crc=new CRC32();crc.update(content)
        if(content.length.toLong!=meta.size || crc.getValue!=meta.crc ||
          entry.getCompressedSize!=meta.compressed) reject("zip", "Member size/CRC mismatch")
        if(!meta.directory) files += meta.path -> Content(content)
        stream.closeEntry(); index+=1; entry=stream.getNextEntry()
      }
      if(index != metadata.size) reject("zip", "Missing local members")
    } catch { case r: Rejected => throw r
      case e: java.util.zip.ZipException => reject("zip", "Malformed compressed data: " + e.getMessage)
      case e: java.io.EOFException => reject("zip", "Truncated compressed data")
    } finally stream.close()
    stage(files.result(),format,path.getFileName.toString,Some(Content(bytes)),limits)
  }
  def directory(root: Path, format: Format, limits: Limits = Limits()): Staged = {
    // Secure relative traversal refuses symlinks in root ancestors as well as package members.
    // There is deliberately no unsafe provider fallback.
    val absolute=root.toAbsolutePath.normalize()
    def secure(path: Path): SecureDirectoryStream[Path] = Files.newDirectoryStream(path) match {
      case stream: SecureDirectoryStream[Path] => stream
      case stream => stream.close(); reject("provider", "Secure directory streams required")
    }
    var handle=secure(absolute.getRoot)
    try {
      val components=absolute.iterator()
      while(components.hasNext) {
        val next=handle.newDirectoryStream(components.next(),LinkOption.NOFOLLOW_LINKS)
        handle.close(); handle=next
      }
      val files=Vector.newBuilder[(String,Content)]; var count=0;var total=0L
      def attrs(dir: SecureDirectoryStream[Path], name: Path): BasicFileAttributes =
        dir.getFileAttributeView(name,classOf[java.nio.file.attribute.BasicFileAttributeView],
          LinkOption.NOFOLLOW_LINKS).readAttributes()
      def visit(dir: SecureDirectoryStream[Path], prefix: String): Unit = {
        val it=dir.iterator()
        while(it.hasNext) {
          val item=it.next().getFileName; val name=prefix+item.toString
          count+=1; if(count>limits.maxEntries) reject("bounds", "Too many directory entries")
          portablePath(name,limits)
          val before=attrs(dir,item)
          if(before.isSymbolicLink) reject("link", "Links forbidden")
          if(before.isDirectory) {
            val child=dir.newDirectoryStream(item,LinkOption.NOFOLLOW_LINKS)
            try visit(child,name+"/") finally child.close()
          } else {
            if(!before.isRegularFile) reject("link", "Only regular files accepted")
            val options=new java.util.HashSet[OpenOption]()
            options.add(StandardOpenOption.READ); options.add(LinkOption.NOFOLLOW_LINKS)
            val channel=dir.newByteChannel(item,options)
            val in=java.nio.channels.Channels.newInputStream(channel)
            val bytes=try bounded(in,math.min(limits.maxFileBytes.toLong,limits.maxTotalBytes-total)) finally in.close()
            total+=bytes.length
            val after=attrs(dir,item)
            if(!after.isRegularFile || after.size()!=before.size() ||
              after.lastModifiedTime()!=before.lastModifiedTime() || after.fileKey()!=before.fileKey())
              reject("changed", "Source changed during intake")
            files+=name -> Content(bytes)
          }
        }
      }
      visit(handle,"")
      stage(files.result(),format,absolute.getFileName.toString,None,limits)
    } catch { case r: Rejected => throw r
      case _: java.nio.file.FileSystemException => reject("link", "Unsafe or changing directory member")
    } finally handle.close()
  }

  final case class Revision private[intake](id: String, parent: Option[String], entries: Vector[Entry])
  final case class Edit(path: String, start: Int, end: Int, expected: Content, replacement: Content)
  def initial(staged: Staged): Revision = Revision(digestEntries(staged.entries),None,staged.entries)
  private[intake] def recoverStage(format: Format, entries: Vector[Entry], id: String,
    archive: Option[Content], label: String, limits: Limits): Staged = {
    val value=stage(entries.map(e => e.path -> e.content),format,label,archive,limits)
    require(value.identity==id,"Intake identity mismatch");value
  }
  private[intake] def recoverRevision(id: String, parent: Option[String], entries: Vector[Entry], limits: Limits): Revision = {
    checkedPaths(entries.map(_.path),limits)
    val classified=entries.map(e => e.copy(role=role(e.path)))
    require(digestEntries(classified,parent)==id,"Source revision identity mismatch")
    Revision(id,parent,classified)
  }
  /** Exact UTF-8 byte spans; offsets are not PIDE or JavaScript character offsets. */
  def patch(current: Revision, expectedRevision: String, edits: Vector[Edit], limits: Limits = Limits()): Revision = {
    if(current.id != expectedRevision) reject("conflict", "Draft revision changed")
    if(edits.size>limits.maxEntries) reject("bounds", "Too many edits")
    if(edits.isEmpty) reject("patch", "Empty patch")
    val groups=edits.groupBy(_.path)
    if(!groups.keySet.subsetOf(current.entries.map(_.path).toSet)) reject("patch", "Unknown document")
    val entries=current.entries.map { entry => groups.get(entry.path) match {
      case None => entry
      case Some(changes) =>
        val bytes=entry.content.raw; utf8(bytes)
        val ordered=changes.sortBy(_.start)
        if(ordered.map(_.start).distinct.size!=ordered.size) reject("patch", "Ambiguous same-position edits")
        var previous=0
        val out=new ByteArrayOutputStream()
        def boundary(i: Int): Boolean = i==bytes.length || i==0 || (bytes(i)&0xc0)!=0x80
        ordered.foreach { e =>
          if(e.start<previous || e.start<0 || e.end<e.start || e.end>bytes.length ||
            !boundary(e.start) || !boundary(e.end)) reject("patch", "Overlapping/invalid UTF-8 byte span")
          if(!java.util.Arrays.equals(java.util.Arrays.copyOfRange(bytes,e.start,e.end),e.expected.raw))
            reject("conflict", "Original source span changed")
          utf8(e.replacement.raw)
          if(out.size().toLong + e.start-previous+e.replacement.size > limits.maxFileBytes)
            reject("bounds", "Patched source exceeds limit")
          out.write(bytes,previous,e.start-previous);out.write(e.replacement.raw);previous=e.end
        }
        if(out.size().toLong+bytes.length-previous>limits.maxFileBytes) reject("bounds", "Patched source exceeds limit")
        out.write(bytes,previous,bytes.length-previous)
        entry.copy(content=Content(out.toByteArray))
    }}
    if(entries.map(_.content.size.toLong).sum>limits.maxTotalBytes) reject("bounds", "Revision exceeds total limit")
    Revision(digestEntries(entries,Some(current.id)),Some(current.id),entries)
  }
}
