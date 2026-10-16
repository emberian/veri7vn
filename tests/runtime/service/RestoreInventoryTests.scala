package veri7vn.runtime.service
object RestoreInventoryTests {
  def main(args:Array[String]):Unit={
    val mixed=ResidentNativeBridge.restoreInventory("4","request-child,1,9\nevidence,2,10","source-input,3,pending\nacquired-source,4,confirmed")
    assert(mixed.map(_.association)==Vector(1,2,3,4).map(BigInt(_)))
    assert(mixed.take(2).map(_.semantic)==Vector(Some(BigInt(9)),Some(BigInt(10))))
    assert(mixed.drop(2).forall(_.semantic.isEmpty),"source phase became a native generation")
    assert(ResidentNativeBridge.restoreInventory("4","","source-input,5,recorded\nacquired-source,6,failed").size==2)
    assert(ResidentNativeBridge.restoreInventory("4","effect-request,7,19","").head.semantic.contains(BigInt(19)))
    def denied(version:String,normal:String,source:String):Unit={
      var failed=false;try ResidentNativeBridge.restoreInventory(version,normal,source)
      catch {case _:IllegalArgumentException=>failed=true};assert(failed)
    }
    denied("3","","");denied("2","","")
    denied("4","acquired-source,1,9","")
    denied("4","request-child,1,0","")
    denied("4","effect-request,7,0","")
    denied("4","","effect-request,7,confirmed")
    denied("4","request-child,1,9","source-input,1,pending")
    denied("4","","source-input,1,confirmed")
    denied("4","","acquired-source,1,recorded")
    denied("4","","acquired-source,1,0")
    denied("4","","source-input,01,pending")
    denied("4","","source-input,1,pending\n")
    println("RESTORE_INVENTORY_PASS version4 closed_source_phases no_inferred_generation duplicate_rejection")
  }
}
