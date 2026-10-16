package veri7vn.packages.intake

import scala.language.unsafeNulls
import java.nio.file.{Files, Path}
import java.nio.charset.StandardCharsets.UTF_8
import java.io.ByteArrayOutputStream
import java.util.zip.{ZipEntry, ZipOutputStream}
import Intake.*

object IntakeTests {
  def main(args: Array[String]): Unit = {
    val root=Files.createTempDirectory("veri7vn-intake-test-").toRealPath()
    var passed=0
    def test(name: String)(body: => Unit): Unit = {body;passed+=1;println("INTAKE_PASS "+name)}
    def reject(code: String)(body: => Any): Unit = {
      try {body;throw new AssertionError("Expected rejection: "+code)}
      catch {case e: Rejected => assert(e.code==code,s"Expected $code, got ${e.code}: ${e.getMessage}")}
    }
    def zipBytes(entries: Vector[(String,Array[Byte])]): Array[Byte] = {
      val bytes=new ByteArrayOutputStream();val z=new ZipOutputStream(bytes)
      entries.foreach {case(n,b)=>z.putNextEntry(new ZipEntry(n));z.write(b);z.closeEntry()};z.close();bytes.toByteArray
    }
    def archive(bytes: Array[Byte]): Path = {val p=Files.createTempFile(root,"archive-",".zip");Files.write(p,bytes);p}
    def contents(s: String)=s.getBytes(UTF_8)
    val originals=Vector(
      "fixture/manifest.json"->contents("{\"id\":\"fixture\"}"),
      "fixture/organ.py"->contents("raise RuntimeError('INTAKE MUST NOT EXECUTE')"),
      "fixture/scorer.py"->contents("raise RuntimeError('NO SCORER EXECUTION')"),
      "fixture/panel.json"->contents("{\"heldout\":[]}"),
      "fixture/exam_log.jsonl"->contents("{\"heldout_sha\":\"sender-panel\",\"sender\":\"fixture\"}\n"),
      "fixture/verdict_heldout.json"->contents("{\"decision\":\"ADMIT\"}"))
    val bytes=zipBytes(originals);val path=archive(bytes)
    val staged=zip(path,Format.Oracle7Original)
    try {
      test("examined original preserves exact JSONL and unresolved executable bytes") {
        assert(staged.exposure.size==1 && staged.exposure.head.content.bytes.sameElements(originals(4)._2))
        assert(staged.unresolved.size==2)
        assert(staged.entries.exists(_.role==Role.SenderVerdict))
        assert(staged.originalArchive.get.bytes.sameElements(bytes))
      }
      test("deterministic identities ignore archive compression and order") {
        val other=zip(archive(zipBytes(originals.reverse)),Format.Oracle7Original)
        assert(other.identity==staged.identity)
      }
      test("content immutable defensive copies") {
        val raw=contents("abc");val c=Content(raw);raw(0)=0;val copy=c.bytes;copy(0)=0
        assert(new String(c.bytes,UTF_8)=="abc")
      }
      test("directory intake equals archive without executing Python") {
        val dir=root.resolve("directory");Files.createDirectories(dir)
        originals.foreach {case(n,b)=>Files.write(dir.resolve(n.stripPrefix("fixture/")),b)}
        assert(directory(dir,Format.Oracle7Original).identity==staged.identity)
      }
      test("native source staged unresolved, no theory loading") {
        val native=zip(archive(zipBytes(Vector("package.json"->contents("{}"),"Main.thy"->contents("ML \\u003copen\\u003eerror \\\"do not load\\\"\\u003cclose\\u003e")))),Format.NativeDevelopment)
        assert(native.unresolved.map(_.path)==Vector("Main.thy"))
      }
      test("portable internal spaces preserve original names") {
        val named=zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"notes draft.md"->contents("text")))),Format.Oracle7Original)
        assert(named.entries.exists(_.path=="notes draft.md"))
      }
      test("traversal and platform ambiguous paths") {
        for(name<-List("../escape","/absolute","a/../b","a//b","a\\b","C:drive","a."," a.txt","a.txt ","CON.txt","e\u0301.txt"))
          reject("path"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),name->contents("bad")))),Format.Oracle7Original)}
      }
      test("case duplicates and file-parent collisions") {
        reject("duplicate"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"A.py"->contents("a"),"a.py"->contents("b")))),Format.Oracle7Original)}
        reject("path"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"a"->contents("x"),"a/b"->contents("y")))),Format.Oracle7Original)}
      }
      test("Unicode case-fold collision") {
        reject("duplicate"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"straße.txt"->contents("a"),"STRASSE.txt"->contents("b")))),Format.Oracle7Original)}
      }
      test("file ancestor of explicit empty ZIP directory rejected; valid hierarchy accepted") {
        reject("path"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"a"->contents("file"),"a/b/"->Array.emptyByteArray))),Format.Oracle7Original)}
        val valid=zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"a/"->Array.emptyByteArray,"a/b.txt"->contents("child")))),Format.Oracle7Original)
        assert(valid.entries.exists(_.path=="a/b.txt"))
      }
      test("exact duplicate members") {
        val b=zipBytes(Vector("manifest.json"->contents("{}"),"a.txt"->contents("x"),"b.txt"->contents("y")))
        // Replace equal-length ASCII name in both local and central header to construct otherwise-valid duplicate.
        for(i<-0 to b.length-5 if new String(b.slice(i,i+5),UTF_8)=="b.txt")b(i)='a'.toByte
        reject("duplicate"){zip(archive(b),Format.Oracle7Original)}
      }
      test("link ZIP external attributes") {
        val b=bytes.clone();val buffer=java.nio.ByteBuffer.wrap(b).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        val at=(0 until b.length-46).find(i=>buffer.getInt(i)==0x02014b50).get
        buffer.putInt(at+38,0xa1ff0000)
        reject("link"){zip(archive(b),Format.Oracle7Original)}
      }
      test("directory links refused") {
        val dir=root.resolve("linked");Files.createDirectory(dir);Files.write(dir.resolve("manifest.json"),contents("{}"))
        Files.createSymbolicLink(dir.resolve("escape"),root)
        reject("link"){directory(dir,Format.Oracle7Original)}
      }
      test("archive and expanded resource bounds") {
        reject("bounds"){zip(path,Format.Oracle7Original,Limits(maxArchiveBytes=20))}
        reject("bounds"){zip(path,Format.Oracle7Original,Limits(maxFileBytes=8))}
        reject("bounds"){zip(path,Format.Oracle7Original,Limits(maxTotalBytes=20))}
        reject("bounds"){zip(path,Format.Oracle7Original,Limits(maxEntries=2))}
        reject("bounds"){zip(archive(zipBytes(Vector("manifest.json"->contents("{}"),"bomb.txt"->new Array[Byte](100000)))),Format.Oracle7Original,Limits(maxCompressionRatio=2))}
      }
      test("stored members and bounded directory traversal") {
        val out=new ByteArrayOutputStream();val z=new ZipOutputStream(out)
        val payload=contents("{}")
        val crc=new java.util.zip.CRC32();crc.update(payload)
        val member=new ZipEntry("manifest.json");member.setMethod(ZipEntry.STORED)
        member.setSize(payload.length);member.setCompressedSize(payload.length);member.setCrc(crc.getValue)
        z.putNextEntry(member);z.write(payload);z.closeEntry();z.close()
        assert(zip(archive(out.toByteArray),Format.Oracle7Original).entries.head.content.bytes.sameElements(payload))
        reject("bounds"){directory(root.resolve("directory"),Format.Oracle7Original,Limits(maxEntries=2))}
        reject("bounds"){directory(root.resolve("directory"),Format.Oracle7Original,Limits(maxTotalBytes=1))}
      }
      test("truncation, junk, local/central disagreement") {
        reject("zip"){zip(archive(bytes.take(bytes.length-10)),Format.Oracle7Original)}
        reject("zip"){zip(archive(contents("not a zip")),Format.Oracle7Original)}
        val b=bytes.clone();b(30)='z'.toByte
        reject("zip"){zip(archive(b),Format.Oracle7Original)}
      }
      val theory="theory Draft imports Main begin\n(* recipe α *)\nlemma expert: \"x = x\" by simp\nend\n"
      val src=root.resolve("source");Files.createDirectory(src);Files.write(src.resolve("package.json"),contents("{}"));Files.write(src.resolve("Draft.thy"),contents(theory))
      val initialRevision=initial(directory(src,Format.NativeDevelopment))
      val old=contents("(* recipe α *)");val all=contents(theory)
      val start=new String(all,UTF_8).indexOf("(* recipe") // ASCII prefix => byte offset unchanged here
      val edit=Edit("Draft.thy",start,start+old.length,Content(old),Content(contents("(* new recipe β *)")))
      val next=patch(initialRevision,initialRevision.id,Vector(edit))
      test("exact byte patch preserves expert block") {
        val result=next.entries.find(_.path=="Draft.thy").get.content.bytes
        assert(new String(result,UTF_8).contains("lemma expert: \"x = x\" by simp"))
        assert(result.drop(start+edit.replacement.size).sameElements(all.drop(edit.end)))
        assert(next.parent.contains(initialRevision.id))
      }
      test("stale revision and source span atomically rejected") {
        reject("conflict"){patch(next,initialRevision.id,Vector(edit))}
        reject("conflict"){patch(initialRevision,initialRevision.id,Vector(edit.copy(expected=Content(contents("wrong")))))}
        assert(initialRevision.entries.find(_.path=="Draft.thy").get.content.bytes.sameElements(all))
      }
      test("encoding, overlap and output limits") {
        val alpha=all.indices.find(i=>(all(i)&255)==0xce).get
        reject("patch"){patch(initialRevision,initialRevision.id,Vector(Edit("Draft.thy",alpha+1,alpha+2,Content(Array(all(alpha+1))),Content(Array.emptyByteArray))))}
        reject("encoding"){patch(initialRevision,initialRevision.id,Vector(edit.copy(replacement=Content(Array(0xff.toByte)))))}
        reject("patch"){patch(initialRevision,initialRevision.id,Vector(edit,edit))}
        reject("bounds"){patch(initialRevision,initialRevision.id,Vector(edit),Limits(maxFileBytes=10))}
      }
      val storeRoot=root.resolve("store");val store=new SourceObjects(storeRoot)
      val locator=store.revision(initialRevision)
      test("immutable source-store enforces its own lower limits before publication") {
        val bounded=new SourceObjects(root.resolve("bounded-store"),Limits(maxFileBytes=1))
        reject("bounds"){bounded.preserve(staged)}
        try {bounded.revision(initialRevision);throw new AssertionError("lower source limit ignored")}
        catch {case _: IllegalArgumentException => ()}
        val entries=Files.list(root.resolve("bounded-store"))
        try assert(entries.count()==0) finally entries.close()
      }
      test("immutable recovery after new store instance") {
        val restored=new SourceObjects(storeRoot).recover(locator)
        assert(restored.id==initialRevision.id)
        assert(restored.entries.map(e=>e.path->e.content.sha256)==initialRevision.entries.map(e=>e.path->e.content.sha256))
        val intake=store.preserve(staged)
        assert(store.content(intake.archive.get).bytes.sameElements(bytes))
        val recovered=store.recoverIntake(intake.record)
        assert(recovered.exposure.head.content.sha256==staged.exposure.head.content.sha256)
        assert(recovered.originalArchive.get.sha256==staged.originalArchive.get.sha256)
      }
      class Journal extends DraftJournal {
        var current:Option[String]=None
        override def head(draft:String)=synchronized{current}
        override def withHead[A](draft:String)(materialize:String=>A):Option[A]=synchronized{current.map(materialize)}
        override def compareAndAppend(draft:String,expected:Option[String],next:String)=synchronized {
          if(current!=expected)false else {current=Some(next);true}
        }
      }
      val journal=new Journal;val drafts=new Drafts(store,journal)
      val head=drafts.create("fixture",directory(src,Format.NativeDevelopment))
      test("draft CAS rejects conflicting updates and duplicate create") {
        val changed=drafts.edit("fixture",head,initialRevision.id,Vector(edit))
        reject("conflict"){drafts.edit("fixture",head,initialRevision.id,Vector(edit))}
        reject("conflict"){drafts.create("fixture",directory(src,Format.NativeDevelopment))}
        assert(journal.head("fixture").contains(changed))
        assert(store.originRecord(changed)==store.originRecord(head))
        assert(store.originRecord(head).nonEmpty)
        val closure=store.referenceClosure(changed)
        assert(closure.contains(changed) && closure.contains(store.originRecord(changed).get))
        assert(store.recover(changed).entries.forall(e=>closure(e.content.sha256)))
        val original=store.recoverIntake(store.originRecord(changed).get)
        assert(original.entries.forall(e=>closure(e.content.sha256)))
      }
      test("lost CAS cannot publish prepared revision") {
        val racing=new Journal {override def compareAndAppend(d:String,e:Option[String],n:String)=false}
        racing.current=Some(head)
        reject("conflict"){new Drafts(store,racing).edit("fixture",head,initialRevision.id,Vector(edit))}
        assert(racing.current.contains(head))
      }
      test("actual host journal source create/edit/revoke/reopen") {
        val hostRoot=root.resolve("host-journal")
        var live=new veri7vn.runtime.host.WorkspaceStore(hostRoot)
        try {
          val adapter=new HostDraftJournal(live)
          val hostDrafts=new Drafts(store,adapter)
          val created=hostDrafts.create("host_fixture",directory(src,Format.NativeDevelopment))
          val changed=hostDrafts.edit("host_fixture",created,initialRevision.id,Vector(edit))
          assert(live.head("host_fixture").contains(changed))
          live.close();live=new veri7vn.runtime.host.WorkspaceStore(hostRoot)
          assert(live.head("host_fixture").contains(changed))
          assert(store.recover(changed).parent.contains(initialRevision.id))
          assert(store.originRecord(changed).nonEmpty)
          val original=store.recoverIntake(store.originRecord(changed).get)
          assert(original.entries.find(_.path=="Draft.thy").get.content.bytes.sameElements(all))
          assert(live.revokeSource("host_fixture"))
          reject("conflict"){new Drafts(store,new HostDraftJournal(live)).edit("host_fixture",changed,next.id,Vector(edit))}
          live.close();live=new veri7vn.runtime.host.WorkspaceStore(hostRoot)
          assert(live.head("host_fixture").isEmpty)
          val denied=new Drafts(store,new HostDraftJournal(live))
          assert(denied.read("host_fixture").isEmpty && denied.originals("host_fixture").isEmpty)
          assert(!live.compareAndAppend("host_fixture",None,changed))
        } finally live.close()
      }
      test("stale edit locator cannot materialize after deterministic host revocation") {
        val isolated=new SourceObjects(root.resolve("interleaving-objects"))
        val live=new veri7vn.runtime.host.WorkspaceStore(root.resolve("interleaving-host"))
        try {
          val initial=new Drafts(isolated,new HostDraftJournal(live))
          val stale=initial.create("interleave",directory(src,Format.NativeDevelopment))
          var callbackCount=0;var revokeCount=0
          def revokeAndPoison(): Unit = {
            assert(live.revokeSource("interleave"));revokeCount+=1
            // Any forbidden raw recovery now fails integrity, making the former bypass observable.
            Files.write(isolated.root.resolve(stale),contents("poisoned after revoke"))
          }
          val crossing=new DraftJournal {
            override def head(d:String):Option[String]={val cached=live.head(d);revokeAndPoison();cached}
            override def withHead[A](d:String)(materialize:String=>A):Option[A]={
              revokeAndPoison()
              live.withSourceHead(d) { locator => callbackCount+=1;materialize(locator) }
            }
            override def compareAndAppend(d:String,e:Option[String],n:String):Boolean=live.compareAndAppend(d,e,n)
          }
          reject("conflict"){new Drafts(isolated,crossing).edit("interleave",stale,initialRevision.id,Vector(edit))}
          assert(revokeCount==1 && callbackCount==0 && live.head("interleave").isEmpty)
        } finally live.close()
      }
      test("corrupt immutable object fails recovery without changing existing revision") {
        val bad=root.resolve("corrupt");Files.createDirectories(bad)
        Files.write(bad.resolve(locator),contents("corrupt"))
        try {new SourceObjects(bad).recover(locator);throw new AssertionError("corruption accepted")}
        catch {case _: IllegalArgumentException=>()}
        assert(store.recover(locator).id==initialRevision.id)
      }
      println(s"INTAKE_SUMMARY $passed PASS; no interpreters, theory loading, activation or remote services")
    } finally {
      val paths=Files.walk(root)
      try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p)) finally paths.close()
    }
  }
}
