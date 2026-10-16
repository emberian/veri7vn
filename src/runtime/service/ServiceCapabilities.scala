package veri7vn.runtime.service

import scala.language.unsafeNulls
import isabelle.{Markup,XML,YXML}

/** Installed dispatcher declarations, never inferred from module availability. */
private[service] object ServiceCapabilities {
  def nativeBuild(reply:ResidentSupervisor.Reply):Boolean={
    if(reply.tag=="rejected" && Set("operation_or_shape","operation_or_frame_bound").contains(reply.payload) && reply.artifacts.isEmpty)return false
    require(reply.tag=="service_capabilities" && reply.payload=="1" && reply.artifacts.size==1 &&
      reply.artifacts.head.size<=8192,"native service capabilities reply")
    val frame=reply.artifacts.head.text
    require(frame.forall(c=>c==5 || c==6 || (c>=32 && c<=126)),"native service capabilities encoding")
    val children=YXML.parse_body(YXML.Source(frame)) match {
      case List(XML.Elem(Markup("service-capabilities",List(("version","1"))),body))=>body
      case _=>throw new IllegalArgumentException("native service capabilities root")
    }
    require(children.size<=16,"native service family bound")
    val families=children.map {
      case XML.Elem(Markup("family",attributes),Nil)=>
        val keys=Set("name","version","propose","poll")
        require(attributes.size==4 && attributes.map(_._1).toSet==keys,"native service family fields")
        val a=attributes.toMap
        require(a("version")=="1","native service family version")
        a("name") match {
          case "mathematics"=>require(a("propose")=="propose_math" && a("poll")=="poll_result","native math dispatcher")
          case "native-build"=>require(a("propose")=="propose_build" && a("poll")=="poll_build","native build dispatcher")
          case _=>throw new IllegalArgumentException("unsupported native service family")
        }
        a("name")
      case _=>throw new IllegalArgumentException("native service family structure")
    }
    require(families.distinct.size==families.size,"duplicate native service family")
    families.contains("native-build")
  }
}
