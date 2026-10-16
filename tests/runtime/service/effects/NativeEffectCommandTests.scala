package veri7vn.runtime.service.effects

object NativeEffectCommandTests {
  def main(args:Array[String]):Unit={
    val original=NativeEffectCommand(1,2,3,4,Vector(5,6),Vector(7,8),9,10,NativeEffectCost(11,12,13,14,1))
    original.requireExact(original.copy())
    val changed=Vector(original.copy(attempt=11),original.copy(request=11),
      original.copy(target=11),original.copy(capability=11),
      original.copy(sources=Vector(6,5)),original.copy(dependencies=Vector(8,7)),
      original.copy(prestate=11),original.copy(epoch=11),original.copy(cost=original.cost.copy(units=2)),
      original.copy(cost=original.cost.copy(codeGeneration=99)),
      original.copy(cost=original.cost.copy(operation=original.cost.step,step=original.cost.operation)))
    changed.foreach {command=>
      var rejected=false
      try command.requireExact(original) catch {case _:IllegalArgumentException=>rejected=true}
      assert(rejected,"changed generated command was accepted")
    }
    val identity=original.identity("workspace","packet")
    assert(identity.attempt==1 && identity.request==2 && identity.capability==4 &&
      identity.inputArtifact=="packet")
    println("NATIVE_EFFECT_COMMAND exact_association PASS")
  }
}
