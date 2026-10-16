package veri7vn.workbench

import scala.language.unsafeNulls
import java.nio.file.{Files,Path}
import java.nio.charset.{StandardCharsets,CodingErrorAction}
import java.nio.ByteBuffer
import veri7vn.packages.intake.{Intake,SourceObjects,ByteObjects}
import veri7vn.packages.lifecycle.{ManagedDrafts,LegacyMapping,LegacyPanel}
import veri7vn.runtime.host.ManagedSources

/** Shared local authoring operations. No parallel package index or acceptance state. */
final class Authoring(managed:ManagedSources) {
  private val drafts=new ManagedDrafts(managed)
  import Authoring.*
  def list(limit:Int=256):Vector[String]=managed.listDrafts(limit)
  def inspect(draft:String):Snapshot=managed.withHead(draft){(locator,scope)=>
    val objects=new SourceObjects(new ByteObjects {
      def put(bytes:Array[Byte]):String=throw new UnsupportedOperationException("Read only")
      def read(id:String,maxBytes:Long):Array[Byte]=scope.read(id,maxBytes)
    },Intake.Limits())
    val revision=objects.recover(locator)
    Snapshot(draft,locator,revision)
  }.getOrElse(throw new IllegalArgumentException("Package unavailable: "+draft))
  def describe(draft:String):veri7vn.packages.lifecycle.PackageUpdates.SourceDescription=
    veri7vn.packages.lifecycle.PackageUpdates.describe(inspect(draft).revision)
  def importSource(operation:String,draft:String,path:Path,format:Intake.Format):ManagedDrafts.Result={
    val source=if(Files.isDirectory(path))Intake.directory(path,format)else Intake.zip(path,format)
    drafts.create(operation,draft,source)
  }
  def source(draft:String,path:String):Source={
    val snapshot=inspect(draft)
    val entry=snapshot.revision.entries.find(_.path==path).getOrElse(throw new IllegalArgumentException("Source file unavailable"))
    Source(snapshot,entry,decode(entry.content))
  }
  def edit(operation:String,draft:String,manifest:String,revision:String,path:String,start:Int,stop:Int,
    expected:Array[Byte],replacement:Array[Byte]):ManagedDrafts.Result=
    drafts.edit(operation,draft,manifest,revision,Vector(Intake.Edit(path,start,stop,Intake.Content(expected),Intake.Content(replacement))))
  def migration(draft:String):LegacyMapping.Report={
    val original=drafts.originals(draft).getOrElse(throw new IllegalArgumentException("Original source unavailable"))
    LegacyMapping.inspect(original)
  }
  def panel(draft:String):LegacyPanel.Imported={
    val original=drafts.originals(draft).getOrElse(throw new IllegalArgumentException("Original source unavailable"))
    LegacyPanel.inspect(original)
  }
}
object Authoring {
  def resultMessage(result:ManagedDrafts.Result):String=result match {
    case ManagedDrafts.Recorded(receipt,replayed)=>receipt.status.toString match {
      case "Committed"=>if(replayed)"Saved earlier; this request was already completed."else "Saved."
      case "Aborted"=>"This edit was rejected earlier. Reopen the source before trying a corrected edit."
      case _=>"The source changed before this save. Reopen it and review your changes."
    }
    case ManagedDrafts.Conflict=>"The source changed before this save. Reopen it and review your changes."
    case ManagedDrafts.IdentityMismatch=>"This request name was already used for different changes. Choose a new request name."
    case ManagedDrafts.Unavailable=>"This package is no longer available. Refresh the package list."
  }
  final case class Snapshot(draft:String,manifest:String,revision:Intake.Revision)
  final case class Source(snapshot:Snapshot,entry:Intake.Entry,text:String)
  def decode(content:Intake.Content):String=StandardCharsets.UTF_8.newDecoder()
    .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
    .decode(ByteBuffer.wrap(content.bytes)).toString
}
