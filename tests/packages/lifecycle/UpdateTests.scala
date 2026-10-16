package veri7vn.packages.lifecycle
import scala.language.unsafeNulls
object UpdateTests {
  def main(args:Array[String]):Unit={
    import PackageUpdates.*
    val source=Dependency(Component.Source,"reader")
    val consumers=new Consumers(Vector(
      Consumer("absence",Set(source),Set.empty),Consumer("ranking",Set(source),Set.empty),
      Consumer("followup",Set.empty,Set("absence")),Consumer("unrelated",Set.empty,Set.empty)))
    assert(consumers.affected(Set(source))==Vector("absence","followup","ranking"))
    assert(consumers.affected(Set(Dependency(Component.Policy,"other"))).isEmpty)
    val pin=Pin("semantic","bundle","snapshot","parser","policy")
    val observations=Observations(Some("1"),Some("monotonic:origin:20"),Vector("sensor"->"event-1"),Some("units-v1"))
    val key=ReuseKey(pin,observations,"premises","request")
    assert(reusable(key,key))
    assert(!reusable(key,key.copy(observed=observations.copy(sessionRevision=Some("2")))))
    assert(!reusable(key,key.copy(observed=observations.copy(clock=Some("monotonic:origin:21")))))
    assert(!reusable(key,key.copy(observed=observations.copy(configuration=Some("units-v2")))))
    assert(!reusable(key,key.copy(pin=pin.copy(executable="other-bundle"))))
    assert(key.pin==pin) // an update never rewrites a historical request pin
    val directory=java.nio.file.Files.createTempDirectory("v7-updates-").toRealPath()
    try {
      val descriptor=java.nio.file.Files.readAllBytes(java.nio.file.Path.of("schemas/fixtures/package/valid-data.json"))
      java.nio.file.Files.write(directory.resolve("package.json"),descriptor)
      java.nio.file.Files.writeString(directory.resolve("observations.json"),"[]")
      val old=veri7vn.packages.intake.Intake.initial(veri7vn.packages.intake.Intake.directory(directory,
        veri7vn.packages.intake.Intake.Format.NativeDevelopment))
      val before=current("workspace","reader","manifest",old)
      val data=old.entries.find(_.path=="observations.json").get.content
      val next=veri7vn.packages.intake.Intake.patch(old,old.id,Vector(veri7vn.packages.intake.Intake.Edit(
        "observations.json",0,2,data,veri7vn.packages.intake.Intake.Content("[1]".getBytes(java.nio.charset.StandardCharsets.UTF_8)))))
      val after=current("workspace","reader","next-manifest",next)
      val inspection=inspect(before.development,old,after.development,next)
      assert(inspection.files.map(_.path)==Vector("observations.json"))
      val update=plan(inspection,pin,consumers,None)
      assert(update.cost==PackageModel.Growth.RevalidateDataOrRecipe)
      assert(update.affectedConsumers==Vector("absence","followup","ranking"))
      assert(update.baseline==pin && update.sourceRevision==next.id)
    } finally {
      java.nio.file.Files.deleteIfExists(directory.resolve("package.json"))
      java.nio.file.Files.deleteIfExists(directory.resolve("observations.json"))
      java.nio.file.Files.deleteIfExists(directory)
    }
    println("PACKAGE_UPDATES_PASS dependency closure and exact observation reuse")
  }
}
