package veri7vn.runtime.service
import isabelle.{Bytes,Markup,XML,YXML}
object ServiceCapabilitiesTests {
  def main(args:Array[String]):Unit={
    def family(name:String,propose:String,poll:String)=XML.Elem(Markup("family",
      List("name"->name,"version"->"1","propose"->propose,"poll"->poll)),Nil)
    val math=family("mathematics","propose_math","poll_result")
    val build=family("native-build","propose_build","poll_build")
    def reply(body:List[XML.Tree])=ResidentSupervisor.Reply(1,"service_capabilities","1",
      List(Bytes(YXML.string_of_body(List(XML.Elem(Markup("service-capabilities",List("version"->"1")),body))))))
    assert(!ServiceCapabilities.nativeBuild(reply(List(math))))
    assert(ServiceCapabilities.nativeBuild(reply(List(math,build))))
    assert(ServiceCapabilities.read(reply(List(math,build))).contains(Vector(
      ("mathematics","1","propose_math","poll_result"),("native-build","1","propose_build","poll_build"))))
    assert(!ServiceCapabilities.nativeBuild(ResidentSupervisor.Reply(1,"rejected","operation_or_frame_bound")))
    assert(ServiceCapabilities.read(ResidentSupervisor.Reply(1,"rejected","operation_or_frame_bound")).isEmpty)
    def denied(body:List[XML.Tree]):Unit={
      var rejected=false;try ServiceCapabilities.nativeBuild(reply(body))
      catch {case _:IllegalArgumentException=>rejected=true};assert(rejected)
    }
    denied(List(build,build));denied(List(family("native-build","propose_math","poll_build")))
    denied(List(family("unknown","propose_build","poll_build")));denied(List(XML.Text("native-build")))
    var failed=false
    try ServiceCapabilities.nativeBuild(ResidentSupervisor.Reply(1,"rejected","native_rpc_worker_failed"))
    catch {case _:IllegalArgumentException=>failed=true};assert(failed)
    println("SERVICE_CAPABILITIES_PASS installed_tuple no_inferred_build malformed_rejection transport_failure_visible")
  }
}
