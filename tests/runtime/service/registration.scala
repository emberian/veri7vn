import scala.language.unsafeNulls
@main def packageDescriptorRegistration():Unit=isabelle.Command_Line.tool {
  val matches=isabelle.Scala.functions.filter(_.name=="veri7vn.package_descriptor_v1")
  require(matches.size==1 && matches.head.single && matches.head.bytes,"fixed descriptor function not registered exactly once")
  val function=matches.head match {
    case value:isabelle.Scala.Fun_Bytes=>value
    case _=>throw new IllegalStateException("descriptor function is not fixed byte adapter")
  }
  val bytes=isabelle.Bytes(java.nio.file.Files.readAllBytes(java.nio.file.Path.of("schemas/fixtures/package/valid-blank-development.json")))
  val reply=function.apply(bytes)
  require(reply.size<=65536 && isabelle.YXML.parse_body(isabelle.YXML.Source(reply.text)).exists {
    case isabelle.XML.Elem(isabelle.Markup("package-descriptor",attrs),_)=>attrs.contains("version"->"1")
    case _=>false
  },"registered parser did not return closed descriptor frame")
  println("PACKAGE_DESCRIPTOR_REGISTRATION_PASS")
}
