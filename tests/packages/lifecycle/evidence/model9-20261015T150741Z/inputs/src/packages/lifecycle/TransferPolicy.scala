package veri7vn.packages.lifecycle

import veri7vn.packages.intake.Intake
import Intake.Content

/** Local retention/export policy over source artifacts. Does not confer native acceptance. */
object TransferPolicy {
  enum Class {case AuthoredPublic, PrivateSource, Transcript, GapExample, Feedback, LearnedState, Cache, SecretReference}
  enum Kind {case Descriptor, Theory, Example, Source, Original, ExposureHistory, InspectionReceipt, Other}
  final case class Artifact(id:String,path:String,content:Content,classification:Class,kind:Kind,
    derivedFrom:Set[String],requiredForReplay:Set[String],nativeAssociations:Set[String]=Set.empty)
  final class Graph(input:Vector[Artifact]) {
    require(input.size<=2048 && input.forall(_.id.matches("[A-Za-z0-9_-]{1,128}")),"Artifact graph bounds/identity")
    require(input.map(_.id).distinct.size==input.size,"Duplicate artifact identity")
    val artifacts:Map[String,Artifact]=input.map(a=>a.id->a).toMap
    input.foreach(a=>require((a.derivedFrom++a.requiredForReplay).subsetOf(artifacts.keySet),"Unknown artifact dependency"))
    private var memo=Map.empty[String,Set[String]]
    def ancestors(id:String):Set[String]={
      def walk(current:String,stack:Set[String]):Set[String]={
        require(!stack(current) && stack.size<64,"Artifact provenance cycle/depth")
        memo.get(current) match {case Some(found)=>return found;case None=>()}
        val a=artifacts.getOrElse(current,throw new IllegalArgumentException("Unknown artifact"))
        val result=a.derivedFrom.flatMap(p=>walk(p,stack+current))+current
        memo+=current->result;result
      }
      walk(id,Set.empty)
    }
    input.foreach(a=>ancestors(a.id))
    def derivatives(roots:Set[String]):Set[String]={
      require(roots.subsetOf(artifacts.keySet));var result=roots;var changed=true
      while(changed) {val next=result++input.filter(a=>a.derivedFrom.exists(result)).map(_.id);changed=next!=result;result=next}
      result
    }
  }
  final case class Preview private[lifecycle](included:Vector[Artifact],omittedReplay:Set[String],
    explicitPrivate:Set[String],curatedCopies:Set[String],sourceFingerprint:String)
  private def fingerprint(graph:Graph):String={
    val bytes=new java.io.ByteArrayOutputStream();val out=new java.io.DataOutputStream(bytes)
    def string(s:String):Unit={val raw=s.getBytes(java.nio.charset.StandardCharsets.UTF_8);out.writeInt(raw.length);out.write(raw)}
    def strings(xs:Iterable[String]):Unit={out.writeInt(xs.size);xs.toVector.sorted.foreach(string)}
    graph.artifacts.values.toVector.sortBy(_.id).foreach(a=>{
      string(a.id);string(a.path);string(a.content.sha256);string(a.classification.toString);string(a.kind.toString)
      strings(a.derivedFrom);strings(a.requiredForReplay);strings(a.nativeAssociations)
    })
    out.flush();Intake.hash(bytes.toByteArray)
  }
  /** Curated-copy permission is explicit for each selected artifact with private ancestry;
    * it never silently reclassifies/exports the private parents. */
  def preview(graph:Graph,selected:Set[String],explicitPrivate:Set[String]=Set.empty,
    curatedCopies:Set[String]=Set.empty):Preview={
    require(selected.nonEmpty && selected.subsetOf(graph.artifacts.keySet),"Export selection")
    require(explicitPrivate.subsetOf(selected) && curatedCopies.subsetOf(selected),"Permission outside selected closure")
    val contents=selected.toVector.sorted.map(graph.artifacts)
    contents.foreach { a=>
      require(a.classification!=Class.SecretReference,"Credentials/secret references are never portable payloads")
      val privateParents=graph.ancestors(a.id).exists(id=>graph.artifacts(id).classification!=Class.AuthoredPublic)
      if(a.classification!=Class.AuthoredPublic)require(explicitPrivate(a.id),"Private payload requires explicit selection")
      if(privateParents && a.classification==Class.AuthoredPublic)require(curatedCopies(a.id),"Derived private copy requires explicit curation")
      Intake.portablePath(a.path)
    }
    val paths=contents.map(_.path.toUpperCase(java.util.Locale.ROOT).toLowerCase(java.util.Locale.ROOT))
    require(paths.distinct.size==paths.size,"Ambiguous export paths")
    paths.foreach(p=>paths.filter(_!=p).foreach(other=>require(!other.startsWith(p+"/"),"File-parent collision")))
    var required=contents.flatMap(_.requiredForReplay).toSet
    var changed=true
    while(changed){val next=required++required.flatMap(id=>graph.artifacts(id).requiredForReplay);changed=next!=required;required=next}
    Preview(contents,required--selected,explicitPrivate,curatedCopies,fingerprint(graph))
  }
  def revalidate(graph:Graph,p:Preview):Preview={
    require(fingerprint(graph)==p.sourceFingerprint,"Export preview stale after content/classification/dependency change")
    preview(graph,p.included.map(_.id).toSet,p.explicitPrivate,p.curatedCopies)
  }
  /** Writes bytes only after exact closure revalidation; never overwrites an existing export. */
  def exportZip(graph:Graph,p:Preview,target:java.nio.file.Path,maxBytes:Long=64L*1024*1024):Unit={
    val checked=revalidate(graph,p)
    require(checked.included.map(_.content.size.toLong).sum<=maxBytes,"Export byte limit")
    val parent=target.toAbsolutePath.getParent
    require(java.nio.file.Files.isDirectory(parent,java.nio.file.LinkOption.NOFOLLOW_LINKS),"Export parent")
    val temp=java.nio.file.Files.createTempFile(parent,"v7-export-",".tmp")
    try {
      val zip=new java.util.zip.ZipOutputStream(java.nio.file.Files.newOutputStream(temp))
      try checked.included.sortBy(_.path).foreach(a=>{val e=new java.util.zip.ZipEntry(a.path);e.setTime(0L)
        zip.putNextEntry(e);zip.write(a.content.bytes);zip.closeEntry()}) finally zip.close()
      val channel=java.nio.channels.FileChannel.open(temp,java.nio.file.StandardOpenOption.WRITE)
      try channel.force(true) finally channel.close()
      java.nio.file.Files.createLink(target.toAbsolutePath,temp)
      val directory=java.nio.channels.FileChannel.open(parent,java.nio.file.StandardOpenOption.READ)
      try directory.force(true) finally directory.close()
    } finally java.nio.file.Files.deleteIfExists(temp)
  }
  final case class ForgetPlan(affected:Set[String],curatedChoiceRequired:Set[String],nativeAssociations:Set[String])
  def forgetPreview(graph:Graph,roots:Set[String]):ForgetPlan={
    val affected=graph.derivatives(roots)
    ForgetPlan(affected,affected.filter(id=>graph.artifacts(id).classification==Class.AuthoredPublic && !roots(id)),
      affected.flatMap(id=>graph.artifacts(id).nativeAssociations))
  }
  enum ForgetStatus {case PendingGeneratedTransition, SourceErasedNativeReleasePending, Complete}
  // Completion must be supplied by joined host/native lifecycle service, not a source tombstone.
}
