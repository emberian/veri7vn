package veri7vn.diagnostics

import veri7vn.packages.lifecycle.{PackageUpdates,PackageModel}

/** Read-only source-declaration consumer of the existing affected-set planner.
  * No runtime dependency ledger, source lookup, or invalidation operation. */
object PackageImpact {
  final case class Unavailable(draft:String,reason:String)
  final case class Package(draft:String,key:PackageModel.PackageKey,revision:String)
  enum Issue {
    case MissingProvider(consumer:String,key:PackageModel.PackageKey)
    case AmbiguousProvider(key:PackageModel.PackageKey,drafts:Vector[String])
    case DescriptorUnavailable(draft:String,reason:String)
  }
  final case class Affected(consumer:Package,pathToTarget:Vector[String])
  def issueText(issue:Issue):String=issue match {
    case Issue.MissingProvider(consumer,key)=>s"$consumer requires ${key.id} ${key.version}, which is not among the inspected valid package declarations."
    case Issue.AmbiguousProvider(key,drafts)=>s"${key.id} ${key.version} has multiple inspected providers: ${drafts.mkString(", ")}. The graph includes each possible provider."
    case Issue.DescriptorUnavailable(draft,reason)=>s"$draft could not be inspected: $reason"
  }
  final case class View(targetDraft:String,target:Option[Package],affected:Vector[Affected],
    inspected:Vector[Package],issues:Vector[Issue]) {
    def computed:Boolean=target.nonEmpty
    def scope:String="Source package declarations at the listed inspected revisions. This does not predict native result invalidation, running requests, physical erasure, or replacement-source contents."
    def qualification:String=if(!computed)"Target descriptor unavailable; impact was not computed."
      else if(issues.nonEmpty)"Declared dependencies that may be affected; unresolved or ambiguous providers prevent an exact workspace impact claim."
      else "Affected set for this inspected package-declaration graph. Reinspect after edits; these revisions were read individually."
  }
  def inspect(descriptions:Vector[(String,PackageUpdates.SourceDescription)],
    unavailable:Vector[Unavailable],targetDraft:String):View={
    val allDrafts=descriptions.map(_._1)++unavailable.map(_.draft)
    require(allDrafts.size<=8192 && allDrafts.distinct.size==allDrafts.size && allDrafts.forall(_.nonEmpty),
      "Package impact inventory bounds/duplicates")
    require(descriptions.map(_._2.descriptor.dependencies.size.toLong).sum<=65536,
      "Package impact declared dependency edge bound")
    val packages=descriptions.map{case(draft,d)=>Package(draft,d.descriptor.key,d.revision)}.sortBy(_.draft)
    val byDraft=packages.map(p=>p.draft->p).toMap
    val providers=packages.groupBy(_.key)
    // A single declared key can expand to thousands of possible providers.
    // Reject before allocating any expanded edge collections.
    var expandedEdges=0L
    descriptions.foreach{case(_,description)=>description.descriptor.dependencies.distinct.foreach {key=>
      expandedEdges+=providers.get(key).map(_.size.toLong).getOrElse(0L)
      require(expandedEdges<=65536,"Package impact expanded edge bound exceeded; no impact view was computed")
    }}
    val issues=Vector.newBuilder[Issue]
    unavailable.foreach(u=>issues+=Issue.DescriptorUnavailable(u.draft,u.reason))
    providers.toVector.sortBy{case(k,_)=>k.id+"@"+k.version}.foreach{case(key,values)=>
      if(values.size>1)issues+=Issue.AmbiguousProvider(key,values.map(_.draft).sorted)
    }
    val graph=descriptions.map{case(draft,description)=>
      val parents=description.descriptor.dependencies.distinct.flatMap {key=>
        providers.get(key) match {
          case Some(found)=>found.map(_.draft)
          case None=>issues+=Issue.MissingProvider(draft,key);Vector.empty
        }
      }.toSet
      draft->parents
    }.toMap
    val consumers=new PackageUpdates.Consumers(packages.map(p=>PackageUpdates.Consumer(p.draft,
      Set(PackageUpdates.Dependency(PackageUpdates.Component.Source,p.draft)),graph(p.draft))))
    // One deterministic traversal explains all returned rows. It does not select
    // the affected set, which remains the shared planner's responsibility.
    val reverse=graph.toVector.flatMap{case(child,parents)=>parents.toVector.map(parent=>parent->child)}
      .groupMap(_._1)(_._2).view.mapValues(_.sorted).toMap
    val predecessor=scala.collection.mutable.Map.empty[String,String]
    val distance=scala.collection.mutable.Map.empty[String,Int]
    if(byDraft.contains(targetDraft)){
      val queue=scala.collection.mutable.Queue(targetDraft)
      distance(targetDraft)=0
      while(queue.nonEmpty){
        val parent=queue.dequeue()
        reverse.getOrElse(parent,Vector.empty).foreach {child=>
          if(!distance.contains(child)){
            predecessor(child)=parent;distance(child)=distance(parent)+1;queue.enqueue(child)
          }
        }
      }
    }
    def path(start:String):Vector[String]={
      val route=Vector.newBuilder[String];var current=start
      route+=current
      while(current!=targetDraft){
        current=predecessor.getOrElse(current,
          throw new IllegalStateException("Shared planner returned a consumer without a source dependency path"))
        route+=current
      }
      route.result()
    }
    val affected=byDraft.get(targetDraft).toVector.flatMap {target=>
      val ids=consumers.affected(Set(PackageUpdates.Dependency(PackageUpdates.Component.Source,target.draft)))
        .filterNot(_==target.draft)
      val pathNodes=ids.map(draft=>distance.getOrElse(draft,
        throw new IllegalStateException("Shared planner returned a consumer without a source dependency distance")).toLong+1L).sum
      require(pathNodes<=65536,"Package impact explanation path bound exceeded; no impact view was computed")
      ids.map(draft=>Affected(byDraft(draft),path(draft)))
    }
    View(targetDraft,byDraft.get(targetDraft),affected,packages,issues.result())
  }
}
