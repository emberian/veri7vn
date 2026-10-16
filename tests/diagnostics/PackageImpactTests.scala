package veri7vn.diagnostics

import scala.language.unsafeNulls
import veri7vn.packages.lifecycle.{PackageModel,PackageUpdates}

object PackageImpactTests {
  def run():Unit={
    def key(name:String,version:String="1.0.0")=PackageModel.PackageKey("example."+name,version)
    def description(name:String,deps:Vector[PackageModel.PackageKey]=Vector.empty)=
      PackageUpdates.SourceDescription(PackageModel.Descriptor(key(name),name,"",Vector.empty,deps,None,Vector.empty),name+"-revision",Vector.empty)
    val inputs=Vector("base"->description("base"),"child"->description("child",Vector(key("base"))),
      "leaf"->description("leaf",Vector(key("child"))),"other"->description("other"))
    val view=PackageImpact.inspect(inputs,Vector.empty,"base")
    assert(view.computed && view.affected.map(_.consumer.draft)==Vector("child","leaf"))
    assert(view.affected.last.pathToTarget==Vector("leaf","child","base") && view.issues.isEmpty)
    val missing=PackageImpact.inspect(inputs:+("wrong-version"->description("wrong",Vector(key("base","2.0.0")))),Vector.empty,"base")
    assert(missing.issues.exists{case PackageImpact.Issue.MissingProvider("wrong-version",_)=>true;case _=>false})
    assert(!missing.affected.exists(_.consumer.draft=="wrong-version"))
    val duplicate=PackageImpact.inspect(inputs:+("alias"->description("base")),Vector.empty,"base")
    assert(duplicate.issues.exists{case PackageImpact.Issue.AmbiguousProvider(_,drafts)=>drafts==Vector("alias","base");case _=>false})
    val unavailable=PackageImpact.inspect(inputs.filterNot(_._1=="base"),Vector(PackageImpact.Unavailable("base","Invalid descriptor")),"base")
    assert(!unavailable.computed && unavailable.affected.isEmpty && unavailable.issues.nonEmpty)
    val cycle=PackageImpact.inspect(Vector("x"->description("x",Vector(key("y"))),"y"->description("y",Vector(key("x")))),Vector.empty,"x")
    assert(cycle.affected.map(_.consumer.draft)==Vector("y"))
    def bounded(body: => Any,expected:String):Unit={
      var reason="";try body catch{case e:IllegalArgumentException=>reason=e.getMessage}
      assert(reason.contains(expected) && reason.contains("no impact view was computed"))
    }
    val sameProvider=description("base",Vector(key("base")))
    val dense=Vector.tabulate(8192)(i=>("provider-"+i,sameProvider))
    bounded(PackageImpact.inspect(dense,Vector.empty,"provider-0"),"expanded edge bound")
    def chain(size:Int)=Vector.tabulate(size){i=>
      val name="chain"+i
      name->description(name,if(i==0)Vector.empty else Vector(key("chain"+(i-1))))
    }
    val long=PackageImpact.inspect(chain(200),Vector.empty,"chain0")
    assert(long.affected.size==199)
    val last=long.affected.find(_.consumer.draft=="chain199").get.pathToTarget
    assert(last==Vector.tabulate(200)(i=>"chain"+(199-i)))
    bounded(PackageImpact.inspect(chain(1024),Vector.empty,"chain0"),"explanation path bound")
    println("PACKAGE_IMPACT_PASS shared planner transitive paths exact release keys unresolved duplicate providers cycles expanded-edge preflight8192 bounded long-chain explanations; declaration scope only")
  }
}
