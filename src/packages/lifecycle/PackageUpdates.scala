package veri7vn.packages.lifecycle

import veri7vn.packages.intake.Intake
import PackageModel.*

/** Inspection and invalidation plans only. Neither a source digest nor a plan is
  * native admission, operational qualification, or permission to publish. */
object PackageUpdates {
  enum Component {
    case Source, Interpretation, Assumptions, Contract, Implementation, Policy,
      Observation, Session, Clock, Executable
  }
  final case class Dependency(component:Component,id:String) { require(id.nonEmpty) }
  final case class Consumer(id:String,dependencies:Set[Dependency],dependsOn:Set[String]) {
    require(id.nonEmpty)
  }
  final class Consumers(input:Vector[Consumer]) {
    require(input.size<=8192 && input.map(_.id).distinct.size==input.size,"Consumer graph bounds/duplicates")
    private val index=input.map(c=>c.id->c).toMap
    require(input.forall(_.dependsOn.subsetOf(index.keySet)),"Unknown consumer dependency")
    /** Conservative whole-dependency invalidation includes negative/ranking/aggregate
      * observations by depending on the full source snapshot, never just witnesses. */
    def affected(changed:Set[Dependency]):Vector[String]={
      var found=input.filter(_.dependencies.exists(changed)).map(_.id).toSet
      var growing=true
      while(growing) {
        val next=found++input.filter(_.dependsOn.exists(found)).map(_.id)
        growing=next!=found;found=next
      }
      found.toVector.sorted
    }
  }
  final case class Pin(semantic:String,executable:String,source:String,interpretation:String,policy:String) {
    require(Vector(semantic,executable,source,interpretation,policy).forall(_.nonEmpty))
  }
  /** These are exact observed values, not current-time requests. Clock includes
    * its origin/basis; source event identity is distinct from poll receipt. */
  final case class Observations(sessionRevision:Option[String],clock:Option[String],
    sourceEvents:Vector[(String,String)],configuration:Option[String]) {
    require(sourceEvents.map(_._1).distinct.size==sourceEvents.size,"Duplicate source observation")
  }
  final case class ReuseKey(pin:Pin,observed:Observations,assumptions:String,request:String)
  def reusable(saved:ReuseKey,current:ReuseKey):Boolean=saved==current

  final case class SourceDescription(descriptor:Descriptor,revision:String,files:Vector[(String,String,Int,Option[FileRole])])
  def describe(source:Intake.Revision):SourceDescription={
    val entry=source.entries.find(_.path=="package.json").getOrElse(
      throw new IllegalArgumentException("Missing package.json"))
    val descriptor=PackageModel.descriptor(entry.content)
    val roles=descriptor.files.map(f=>f.path->f.role).toMap
    require(roles.keySet.subsetOf(source.entries.map(_.path).toSet),"Declared file missing")
    require(descriptor.native.isEmpty || descriptor.files.exists(f=>f.role==FileRole.Source && f.path.endsWith(".thy")),
      "Native payload needs editable theory source")
    SourceDescription(descriptor,source.id,source.entries.map(e=>(e.path,e.content.sha256,e.content.size,roles.get(e.path))))
  }
  final case class Current(development:Development,files:Vector[(String,String,Int,Option[FileRole])])
  def current(workspace:String,draft:String,manifest:String,source:Intake.Revision):Current={
    val development=PackageModel.load(workspace,draft,manifest,source,None)
    val roles=development.descriptor.files.map(f=>f.path->f.role).toMap
    Current(development,source.entries.map(e=>(e.path,e.content.sha256,e.content.size,roles.get(e.path))))
  }
  final case class FileChange(path:String,before:Option[String],after:Option[String],role:Option[FileRole])
  final case class Inspection(before:Development,after:Development,files:Vector[FileChange],
    dependenciesChanged:Boolean,exportsChanged:Boolean,nativeSetupChanged:Boolean) {
    def unchanged:Boolean=before.revision==after.revision
  }
  def inspect(before:Development,oldSource:Intake.Revision,after:Development,newSource:Intake.Revision):Inspection={
    require(before.workspace==after.workspace && before.draft==after.draft,"Different development")
    require(before.descriptor.key.id==after.descriptor.key.id,"Package identity replacement")
    require(before.revision==oldSource.id && after.revision==newSource.id,"Stale source inspection")
    val old=oldSource.entries.map(e=>e.path->e.content.sha256).toMap
    val next=newSource.entries.map(e=>e.path->e.content.sha256).toMap
    val roles=(before.descriptor.files++after.descriptor.files).map(f=>f.path->f.role).toMap
    val changes=(old.keySet++next.keySet).toVector.sorted.filter(p=>old.get(p)!=next.get(p))
      .map(p=>FileChange(p,old.get(p),next.get(p),roles.get(p)))
    Inspection(before,after,changes,before.descriptor.dependencies!=after.descriptor.dependencies,
      before.descriptor.exports!=after.descriptor.exports,before.descriptor.native!=after.descriptor.native)
  }
  final case class Plan(sourceRevision:String,baseline:Pin,cost:Growth,
    changed:Set[Dependency],affectedConsumers:Vector[String],checks:Vector[String])
  /** The native build service supplies classification for changed native source.
    * Never infer code-equation safety from filenames or source-text heuristics. */
  def plan(i:Inspection,baseline:Pin,consumers:Consumers,native:Option[ChangePlan],
    additional:Set[Dependency]=Set.empty):Plan={
    val sourceIndexChanged=i.before.descriptor.files.filter(_.role==FileRole.Source)!=
      i.after.descriptor.files.filter(_.role==FileRole.Source)
    val nativeSource=i.files.exists(f=>f.role.contains(FileRole.Source) ||
      (f.role.isEmpty && f.path!="package.json")) || sourceIndexChanged || i.dependenciesChanged ||
      i.exportsChanged || i.nativeSetupChanged
    require(!nativeSource || native.nonEmpty,"Native change requires build-service classification")
    val classification=native.getOrElse(ChangePlan(Growth.RevalidateDataOrRecipe,
      "Indexed non-native content changed",Vector.empty))
    require(!i.nativeSetupChanged || classification.cost==Growth.CompileExecutableBundle,
      "Changed native session/setup requires executable classification")
    val changed=additional++(if(i.unchanged)Set.empty[Dependency]
      else Set(Dependency(Component.Source,i.before.draft)))
    Plan(i.after.revision,baseline,classification.cost,changed,consumers.affected(changed),
      classification.requiredNativeChecks)
  }
}
