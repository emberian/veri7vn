package veri7vn.packages.lifecycle

import isabelle.JSON
import scala.language.unsafeNulls
import veri7vn.packages.intake.Intake
import Intake.{Content, Revision, Staged, Format}

/** Descriptor indexes canonical native source. None of these records can admit a theorem. */
object PackageModel {
  private object StrictJSON extends JSON.Parsers {
    override def json_object: Parser[JSON.Object.T] =
      $$$("{") ~> repsep(string ~ ($$$(":") ~> json_value) ^^ {case a ~ b => (a,b)},$$$(",")) <~ $$$("}") ^^ { entries =>
        require(entries.map(_._1).distinct.size==entries.size,"Duplicate JSON object key")
        entries.toMap
      }
  }
  private def json(content: Content): Map[String,Any] = {
    require(content.size<=256*1024,"Descriptor limit")
    val decoder=java.nio.charset.StandardCharsets.UTF_8.newDecoder()
      .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
      .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
    val text=decoder.decode(java.nio.ByteBuffer.wrap(content.bytes)).toString
    val scanner=new JSON.Lexer.Scanner(isabelle.Scan.char_reader(text))
    var tokens:scala.util.parsing.input.Reader[JSON.Token]=scanner;var depth=0;var count=0
    while(!tokens.atEnd) {
      val t=tokens.first;count+=1
      if(t.is_keyword("{") || t.is_keyword("[")) depth+=1
      if(t.is_keyword("}") || t.is_keyword("]")) depth-=1
      require(depth<=32 && count<=32768,"Descriptor nesting/token limit")
      tokens=tokens.rest
    }
    try obj(StrictJSON.parse(text,true))
    catch {case isabelle.ERROR(_) => throw new IllegalArgumentException("Malformed package descriptor JSON")}
  }
  private def obj(value: Any): Map[String,Any] = value match {
    case m: Map[?,?] if m.keys.forall(_.isInstanceOf[String]) => m.asInstanceOf[Map[String,Any]]
    case _ => throw new IllegalArgumentException("Expected descriptor object")
  }
  private def fields(m:Map[String,Any],required:Set[String],optional:Set[String]=Set.empty): Unit =
    require(required.subsetOf(m.keySet) && m.keySet.subsetOf(required++optional),"Descriptor fields missing/unsupported")
  private def str(m:Map[String,Any],name:String):String=m.get(name) match {
    case Some(s:String) if s.nonEmpty => s
    case _=>throw new IllegalArgumentException("Expected nonempty "+name)
  }
  private def list(m:Map[String,Any],name:String):List[Any]=m.get(name) match {
    case Some(xs:List[?])=>xs.asInstanceOf[List[Any]]
    case _=>throw new IllegalArgumentException("Expected array "+name)
  }
  private def unique[A](values:Vector[A],name:String):Vector[A]={require(values.distinct.size==values.size,"Duplicate "+name);values}
  final case class PackageKey(id:String,version:String) {
    require(id.matches("[a-z][a-z0-9_-]*(\\.[a-z][a-z0-9_-]*)+"),"Package id")
    require(version.matches("[0-9]+\\.[0-9]+\\.[0-9]+(-[a-z0-9][a-z0-9.-]*)?"),"Package version")
  }
  enum FileRole {case Source, Examples, Documentation, Data}
  final case class FileIndex(path:String,role:FileRole)
  final case class Locator(theory:String,name:String)
  final case class Export(id:String,title:String,specification:Locator,contracts:Vector[Locator],executable:Option[Locator])
  final case class Native(session:String,theories:Vector[String])
  final case class Descriptor(key:PackageKey,title:String,description:String,files:Vector[FileIndex],
    dependencies:Vector[PackageKey],native:Option[Native],exports:Vector[Export])
  private def locator(v:Any):Locator={val m=obj(v);fields(m,Set("theory","name"));Locator(str(m,"theory"),str(m,"name"))}
  def descriptor(content:Content):Descriptor={
    val m=json(content);fields(m,Set("format","package","files","requires","capabilities"),Set("native"))
    require(str(m,"format")=="veri7vn.package/0","Descriptor format")
    val p=obj(m("package"));fields(p,Set("id","version","title","description"))
    val key=PackageKey(str(p,"id"),str(p,"version"))
    val files=list(m,"files").map {v=>val f=obj(v);fields(f,Set("path","role"));val path=str(f,"path")
      require(path.matches("[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*"),"Descriptor portable path")
      Intake.portablePath(path)
      val role=str(f,"role") match {case "source"=>FileRole.Source;case "example"=>FileRole.Examples
        case "documentation"=>FileRole.Documentation;case "data"=>FileRole.Data
        case _=>throw new IllegalArgumentException("Unknown file role")}
      FileIndex(path,role)
    }.toVector
    require(files.nonEmpty);unique(files.map(_.path),"file path")
    val dependencies=list(m,"requires").map {v=>val d=obj(v);fields(d,Set("package_id","version"));PackageKey(str(d,"package_id"),str(d,"version"))}.toVector
    unique(dependencies.map(_.id),"dependency id")
    val native=m.get("native").map {v=>val n=obj(v);fields(n,Set("session","theories"))
      val theories=list(n,"theories").map {case s:String if s.nonEmpty=>s;case _=>throw new IllegalArgumentException("Theory name")}.toVector
      require(theories.nonEmpty);unique(theories,"theory");Native(str(n,"session"),theories)}
    val exports=list(m,"capabilities").map {v=>val e=obj(v);fields(e,Set("id","title","specification","contracts"),Set("executable"))
      val id=str(e,"id");require(id.matches("[a-z][a-z0-9_-]*"),"Capability id")
      Export(id,str(e,"title"),locator(e("specification")),unique(list(e,"contracts").map(locator).toVector,"contract"),e.get("executable").map(locator))
    }.toVector
    unique(exports.map(_.id),"capability id");require(exports.isEmpty || native.nonEmpty,"Callable exports require native payload")
    exports.foreach(e=>(Vector(e.specification)++e.contracts++e.executable.toVector).foreach(l=>require(native.exists(_.theories.contains(l.theory)),"Export theory not declared")))
    Descriptor(key,str(p,"title"),str(p,"description"),files,dependencies,native,exports)
  }
  final case class Development(workspace:String,draft:String,sourceLocator:String,revision:String,descriptor:Descriptor,originRecord:Option[String])
  def load(workspace:String,draft:String,sourceLocator:String,source:Revision,origin:Option[String]):Development={
    val descriptorFile=source.entries.find(_.path=="package.json").getOrElse(throw new IllegalArgumentException("Missing package.json"))
    val index=descriptor(descriptorFile.content)
    val byPath=source.entries.map(e=>e.path->e).toMap
    index.files.foreach(f=>require(byPath.contains(f.path),"Declared file missing: "+f.path))
    require(index.native.isEmpty || index.files.exists(f=>f.role==FileRole.Source && f.path.endsWith(".thy")),"Native payload needs editable theory source")
    Development(workspace,draft,sourceLocator,source.id,index,origin)
  }
  /** Resolve descriptor dependencies to exact source revisions. Native import/build closure remains explicit. */
  def dependencyOrder(root:Development,available:Map[PackageKey,Development]):Vector[Development]={
    val result=Vector.newBuilder[Development];var done=Set.empty[PackageKey];var visiting=Set.empty[PackageKey]
    var versions=Map.empty[String,String]
    def visit(p:Development):Unit={
      val key=p.descriptor.key
      require(!visiting(key),"Package dependency cycle")
      versions.get(key.id).foreach(v=>require(v==key.version,"Conflicting dependency versions"));versions+=key.id->key.version
      if(!done(key)) {visiting+=key
        p.descriptor.dependencies.foreach(d=>visit(available.getOrElse(d,throw new IllegalArgumentException("Missing pinned dependency "+d))))
        visiting-=key;done+=key;result+=p}
    }
    visit(root);result.result()
  }
  enum Growth {case RevalidateDataOrRecipe, CheckNativeDeclarations, CompileExecutableBundle}
  final case class BuildInputs(sourceRevision:String,dependencies:Vector[(PackageKey,String)],toolchain:String,
    executableBundle:String,sourceFiles:Vector[(String,String)],trustedExpert:Boolean)
  def buildInputs(development:Development,source:Revision,deps:Vector[Development],toolchain:String,bundle:String,trustedExpert:Boolean):BuildInputs={
    require(development.revision==source.id,"Stale build source")
    val indexed=development.descriptor.files.filter(_.role==FileRole.Source).map(_.path).toSet
    BuildInputs(source.id,deps.map(d=>d.descriptor.key->d.revision),toolchain,bundle,
      source.entries.filter(e=>indexed(e.path)).map(e=>e.path->e.content.sha256),trustedExpert)
  }
  // Growth category is a native build-service result, never guessed from arbitrary source-text diff.
  final case class ChangePlan(cost:Growth,reason:String,requiredNativeChecks:Vector[String])
}
