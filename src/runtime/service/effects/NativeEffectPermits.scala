package veri7vn.runtime.service.effects

import veri7vn.runtime.service.{ResidentNativeBridge,ResidentSupervisor}

/** Parent-owned issuer; the fixed leaf receives only its path-dependent view.
  * Issuing is a service trust boundary, not an interpretation of wire data.
  * The parent issues solely from the acknowledged retained native entry, inside
  * the coordinator critical section after durable unknown-start installation.
  */
private[service] object NativeEffectPermits {
  final class ConsumedStart private[NativeEffectPermits](val command:NativeEffectCommand,
      val gateToken:String,val entryIncarnation:BigInt,val permitIdentity:BigInt,
      private[service] val supervisor:ResidentSupervisor)
  trait View {
    type Permit
    def consume(permit:Permit,expectedSupervisor:AnyRef):ConsumedStart
  }
  final class Issuer private[service] (supervisor:ResidentSupervisor) {
    private var live=true
    final class Permit private[Issuer](private[Issuer] val command:NativeEffectCommand,
        private[Issuer] val acknowledged:ResidentNativeBridge.AcknowledgedEffect) {
      private[Issuer] val owner:Issuer=Issuer.this
      private[Issuer] var consumed=false
    }
    val view:View {type Permit=Issuer.this.Permit}=new View {
      type Permit=Issuer.this.Permit
      def consume(permit:Permit,expectedSupervisor:AnyRef):ConsumedStart=Issuer.this.synchronized {
        require((permit.owner eq Issuer.this) && live && !permit.consumed,"native effect permit unavailable")
        permit.consumed=true
        require(supervisor eq expectedSupervisor,"native effect permit belongs to another prepared source resident")
        val acknowledged=permit.acknowledged
        new ConsumedStart(permit.command,acknowledged.gateToken,acknowledged.entryIncarnation,
          acknowledged.permitIdentity,supervisor)
      }
    }
    private[service] def issue(acknowledged:ResidentNativeBridge.AcknowledgedEffect):view.Permit=synchronized {
      require(live,"native effect issuer retired")
      acknowledged.requireSupervisor(supervisor)
      new Permit(acknowledged.consumeForHandoff(),acknowledged)
    }
    private[service] def retire():Unit=synchronized {live=false}
  }
}
