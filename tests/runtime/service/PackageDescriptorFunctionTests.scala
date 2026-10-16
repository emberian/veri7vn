package veri7vn.runtime.service

import isabelle.{Bytes,YXML,XML,Markup}

object PackageDescriptorFunctionTests {
  def main(args:Array[String]):Unit={
    val source="""{"format":"veri7vn.package/0","package":{"id":"v7.example","version":"1.0.0","title":"Example","description":"Example"},"files":[{"path":"Example.thy","role":"source"}],"requires":[],"native":{"session":"Example","theories":["Example"]},"capabilities":[]}"""
    val original=Bytes(source)
    val frame=PackageDescriptorFunction(original)
    require(original.text==source,"descriptor adapter changed its input")
    val root=YXML.parse_body(YXML.Source(frame.text)) match {
      case List(XML.Elem(Markup("package-descriptor",attributes),children))=>(attributes.toMap,children)
      case _=>throw new IllegalStateException("descriptor adapter root")
    }
    require(root._1==Map("version"->"1","id"->"v7.example","package_version"->"1.0.0","session"->"Example"))
    require(root._2==List(XML.Elem(Markup("theory",List("name"->"Example")),Nil),
      XML.Elem(Markup("file",List("path"->"Example.thy","role"->"source")),Nil)),"zero-export descriptor invented output or lost source")
    var rejected=false
    try PackageDescriptorFunction(Bytes(source.replace("Example.thy","../Example.thy")))
    catch {case _:IllegalArgumentException=>rejected=true}
    require(rejected,"descriptor adapter bypassed existing portable-path validation")
    println("PACKAGE_DESCRIPTOR_FUNCTION_PASS existing_parser zero_exports original_bytes portable_path")
  }
}
