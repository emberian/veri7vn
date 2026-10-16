package veri7vn.packages.lifecycle
import scala.language.unsafeNulls
import java.nio.file.Files
import veri7vn.packages.intake.Intake
import Intake.Content
import PackageModel.*
import TransferPolicy.*
object ModelTests {
  def main(args:Array[String]):Unit={
    var passed=0
    def test(name:String)(body: =>Unit):Unit={body;passed+=1;println("PACKAGE_MODEL_PASS "+name)}
    def rejected(body: =>Any):Unit={try{body;throw new AssertionError("Expected rejection")}catch{case _:IllegalArgumentException=>()}}
    def c(s:String)=Content(s.getBytes(java.nio.charset.StandardCharsets.UTF_8))
    val fixture=java.nio.file.Paths.get("schemas/fixtures/package")
    test("existing schema corpus matches strict descriptor loader") {
      val files=Files.list(fixture)
      try files.forEach(p=>{val bytes=Content(Files.readAllBytes(p));if(p.getFileName.toString.startsWith("valid-"))descriptor(bytes)else rejected{descriptor(bytes)}}) finally files.close()
    }
    test("dependency closure rejects substitution, cycles, missing and version conflicts") {
      val base=descriptor(Content(Files.readAllBytes(fixture.resolve("valid-data.json"))))
      def dev(id:String,version:String="1.0.0",requires:Vector[PackageKey]=Vector.empty)=
        Development("workspace","draft","locator",id+version,base.copy(key=PackageKey(id,version),dependencies=requires),None)
      val leaf=dev("test.leaf");val middle=dev("test.middle",requires=Vector(leaf.descriptor.key))
      val root=dev("test.root",requires=Vector(middle.descriptor.key))
      val available=Map(leaf.descriptor.key->leaf,middle.descriptor.key->middle)
      assert(dependencyOrder(root,available)==Vector(leaf,middle,root))
      rejected{dependencyOrder(root,Map.empty)}
      rejected{dependencyOrder(root,available.updated(middle.descriptor.key,leaf))}
      val cycle=middle.copy(descriptor=middle.descriptor.copy(dependencies=Vector(root.descriptor.key)))
      rejected{dependencyOrder(root,available.updated(middle.descriptor.key,cycle)+(root.descriptor.key->root))}
      val other=dev("test.leaf","2.0.0")
      val conflict=root.copy(descriptor=root.descriptor.copy(dependencies=Vector(middle.descriptor.key,other.descriptor.key)))
      rejected{dependencyOrder(conflict,available+(other.descriptor.key->other))}
    }
    test("duplicate keys and JSON nesting rejected") {
      rejected{descriptor(c("{\"format\":\"a\",\"format\":\"b\"}"))}
      rejected{descriptor(c("["*40+"0"+"]"*40))}
    }
    test("native tokenizer recipe patch preserves expert bytes and rejects command injection") {
      val syntax=isabelle.Outer_Syntax.empty + ("v7_math_formula","thy_decl") + ("lemma","thy_decl") + ("by","thy_decl")
      val original=c("(* preserved λ *)\nv7_math_formula sample = \"Rational (1/2)\"\nlemma expert: \"x = x\" by simp\n")
      val span=SourceProjection.spans(original,syntax).head
      val replacement=c("v7_math_formula sample = \"Rational (3/4)\"")
      val edit=SourceProjection.edit("Example.thy",original,span,replacement,syntax)
      val raw=original.bytes
      val patched=raw.take(edit.start)++edit.replacement.bytes++raw.drop(edit.end)
      assert(new String(patched,java.nio.charset.StandardCharsets.UTF_8).contains("lemma expert: \"x = x\" by simp"))
      rejected{SourceProjection.edit("Example.thy",original,span,c("v7_math_formula sample = \"Rational 1\"\nlemma injected: \"False\""),syntax)}
    }
    test("actual Isabelle declared dependency inventory finds included ML without executing it") {
      val root=Files.createTempDirectory("v7-session-inventory-").toRealPath()
      try {
        Files.writeString(root.resolve("ROOT"),"session Veri7vn_Package_Inventory_Fixture = HOL +\n  options [document=false]\n  theories Inventory\n")
        Files.writeString(root.resolve("Inventory.thy"),"theory Inventory imports Main begin\nML_file \"helper.ML\"\nend\n")
        Files.writeString(root.resolve("helper.ML"),"val _ = error \"Inventory must never execute source\";\n")
        val inventory=SessionInventory.inspect("Veri7vn_Package_Inventory_Fixture",Vector(root))
        val byPath=inventory.sources.map(s=>s.path->s).toMap
        assert(byPath.contains(root.resolve("Inventory.thy").toString))
        assert(byPath.contains(root.resolve("helper.ML").toString))
        assert(byPath.contains(root.resolve("ROOT").toString))
        assert(byPath(root.resolve("helper.ML").toString).sha256==Content(Files.readAllBytes(root.resolve("helper.ML"))).sha256)
        assert(inventory.sessions.exists(_.name=="HOL"))
      } finally {val paths=Files.walk(root);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()}
    }
    test("source operation identity binds exact span, replacement and expected source head") {
      val e=Intake.Edit("A.thy",0,1,c("a"),c("b"))
      val a=OperationIdentity.edit("draft","locator","revision",Vector(e))
      assert(a.sameElements(OperationIdentity.edit("draft","locator","revision",Vector(e))))
      assert(!a.sameElements(OperationIdentity.edit("draft","other","revision",Vector(e))))
      assert(!a.sameElements(OperationIdentity.edit("draft","locator","revision",Vector(e.copy(replacement=c("c"))))))
    }
    test("actual Oracle7 worked source maps only byte-pinned core with explicit remaining behavior") {
      val original=Intake.directory(java.nio.file.Paths.get("upstream/workbench/examples/paint-coverage").toRealPath(),Intake.Format.Oracle7Original)
      val report=LegacyMapping.inspect(original)
      assert(report.candidates.size==1 && report.unresolved.contains("scorer.py"))
      assert(report.candidates.head.remainingObligations.exists(_.contains("rounding")))
      val root=Files.createTempDirectory("v7-unknown-organ-").toRealPath()
      try {
        original.entries.foreach(e=>Files.write(root.resolve(e.path),if(e.path=="organ_paint_coverage.py")c("different Python bytes").bytes else e.content.bytes))
        assert(LegacyMapping.inspect(Intake.directory(root,Intake.Format.Oracle7Original)).candidates.isEmpty)
      } finally {val paths=Files.walk(root);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()}
    }
    val public=Artifact("theory","Theory.thy",c("theory bytes"),Class.AuthoredPublic,Kind.Theory,Set.empty,Set.empty)
    val privateSource=Artifact("private","private.csv",c("private source"),Class.PrivateSource,Kind.Source,Set.empty,Set.empty,Set("native_assoc"))
    val derived=Artifact("example","Examples.json",c("private copied example"),Class.AuthoredPublic,Kind.Example,Set("private"),Set("private"))
    val secret=Artifact("secret","secret.txt",c("reference-only"),Class.SecretReference,Kind.Other,Set.empty,Set.empty)
    val graph=new Graph(Vector(public,privateSource,derived,secret))
    test("private-derived export needs explicit curation and source omission visible") {
      rejected{preview(graph,Set("example"))}
      val selected=preview(graph,Set("example"),curatedCopies=Set("example"))
      assert(selected.omittedReplay==Set("private"))
      rejected{preview(graph,Set("private"))}
      rejected{preview(graph,Set("secret"),explicitPrivate=Set("secret"))}
    }
    test("classification change invalidates exact export preview") {
      val selected=preview(graph,Set("theory"))
      val changed=new Graph(Vector(public.copy(classification=Class.Transcript),privateSource,derived,secret))
      rejected{revalidate(changed,selected)}
    }
    test("forget preview includes derivatives and native release scope") {
      val plan=forgetPreview(graph,Set("private"))
      assert(plan.affected==Set("private","example"))
      assert(plan.curatedChoiceRequired==Set("example") && plan.nativeAssociations==Set("native_assoc"))
    }
    test("export preserves exact selected bytes and refuses overwrite") {
      val root=Files.createTempDirectory("v7-transfer-test-").toRealPath()
      try {
        val output=root.resolve("selected.zip");exportZip(graph,preview(graph,Set("theory")),output)
        val zip=new java.util.zip.ZipFile(output.toFile)
        try {assert(zip.size()==1);val in=zip.getInputStream(zip.getEntry("Theory.thy"));try assert(in.readAllBytes().sameElements(public.content.bytes)) finally in.close()} finally zip.close()
        try {exportZip(graph,preview(graph,Set("theory")),output);throw new AssertionError("Overwritten export")}
        catch{case _:java.nio.file.FileAlreadyExistsException=>()}
      } finally {val paths=Files.walk(root);try paths.sorted(java.util.Comparator.reverseOrder()).forEach(p=>Files.delete(p))finally paths.close()}
    }
    println(s"PACKAGE_MODEL_SUMMARY $passed PASS; descriptor/export policy only, no native admission/activation")
  }
}
