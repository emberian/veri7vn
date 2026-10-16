package veri7vn.runtime.service

import isabelle.{Bytes,Scala,Scala_Project,XML,Markup,YXML}
import veri7vn.packages.intake.Intake
import veri7vn.packages.lifecycle.PackageModel

/** Fixed metadata adapter, called on the native ingress's retained original
  * descriptor. Its result is an expectation, never admission or activation. */
object PackageDescriptorFunction extends Scala.Fun_Bytes("veri7vn.package_descriptor_v1") {
  val here=Scala_Project.here
  def apply(input:Bytes):Bytes={
    require(input.size>0 && input.size<=1000000,"native package descriptor byte bound")
    val original=input.make_array
    val descriptor=try PackageModel.descriptor(Intake.Content(original))
      finally java.util.Arrays.fill(original,0.toByte)
    def elem(name:String,attrs:List[(String,String)],body:XML.Body=Nil):XML.Tree=
      XML.Elem(Markup(name,attrs),body)
    def locator(name:String,value:PackageModel.Locator):XML.Tree=
      elem(name,List("theory"->value.theory,"name"->value.name))
    val theories=descriptor.native.toList.flatMap(_.theories).map(name=>elem("theory",List("name"->name)))
    val files=descriptor.files.toList.map {file=>
      val role=file.role match {
        case PackageModel.FileRole.Source=>"source"
        case PackageModel.FileRole.Examples=>"example"
        case PackageModel.FileRole.Documentation=>"documentation"
        case PackageModel.FileRole.Data=>"data"
      }
      elem("file",List("path"->file.path,"role"->role))
    }
    val dependencies=descriptor.dependencies.toList.map(key=>elem("dependency",List("id"->key.id,"version"->key.version)))
    val exports=descriptor.exports.toList.map(capability=>elem("export",List("id"->capability.id),
      locator("specification",capability.specification)::
        (capability.contracts.toList.map(locator("contract",_))++capability.executable.toList.map(locator("executable",_)))))
    val frame=Bytes(YXML.string_of_body(List(elem("package-descriptor",List("version"->"1",
      "id"->descriptor.key.id,"package_version"->descriptor.key.version,
      "session"->descriptor.native.map(_.session).getOrElse("")),theories++files++dependencies++exports))))
    require(frame.size<=65536,"native package descriptor expectation bound")
    frame
  }
}

class PackageDescriptorFunctions extends Scala.Functions(PackageDescriptorFunction)
