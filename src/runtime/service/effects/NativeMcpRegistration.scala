package veri7vn.runtime.service.effects

import veri7vn.runtime.effects.OperationIdentity
import veri7vn.runtime.service.ResidentSupervisor

/** Same-resident registration association, not execution permission. The fixed
  * bridge constructs this only from its actual retained native entry/command and
  * installed executable-pin reply. No wire decoder can issue a start permit. */
private[service] final class NativeMcpRegistration private[service](
    private val packet:NativeMcpPacket,private val command:NativeEffectCommand,
    operation:String,implementationArtifact:String,
    private val supervisor:ResidentSupervisor) {
  require(packet.supervisor eq supervisor,"MCP registration belongs to another resident")
  require(Set("Discover","QualifyCounter","InvokeCounter").contains(operation),"MCP fixed registration operation")
  require(command.cost.units==1,"MCP fixed registration cost")
  private val identity=OperationIdentity(command.cost.profile,command.capability,
    command.cost.codeGeneration,implementationArtifact,operation,command.cost.operation,
    command.cost.profile,command.cost.step)
  private var consumed=false
  private[service] def claim(expectedPacket:NativeMcpPacket,expectedCommand:NativeEffectCommand):OperationIdentity=synchronized {
    require(!consumed && (packet eq expectedPacket),"MCP registration packet differs or consumed")
    command.requireExact(expectedCommand)
    consumed=true
    identity
  }
}
