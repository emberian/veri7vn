package veri7vn.sources.conceptnet

import scala.language.unsafeNulls
import java.io.OutputStream
import java.nio.file.Path
import veri7vn.sources.SqliteObservation

/** Source-owned extraction policy; all parsing stays in the existing source-row/2
  * importer. Output is an observation candidate, never an admitted graph result.
  * The actual acquisition manifest must retain this policy and Report unchanged. */
object ConceptNetObservation {
  val profile="conceptnet-edge-exact/1"
  val columns=Vector("rel","start","start_pos","end","end_pos","weight","surface_text","dataset")
  // Explicit deterministic full-row order. Equal rows keep their multiplicity;
  // ordinal identity refers to the retained observation, not a SQLite rowid.
  val order=Vector("rel","start","end","weight","start_pos","end_pos","surface_text","dataset")
  val selection="all edge rows; bounded prefix in declared full-row SQL order; no corpus completeness inference"
  val interpretation="exact UTF8 labels; no case/plural/sense equivalence; confidence ranking only; unit hop cost"
  def observe(path:Path,output:OutputStream,limits:SqliteObservation.Limits=SqliteObservation.Limits()):SqliteObservation.Report={
    val report=SqliteObservation.observeLocal(path,"edge",order,output,limits)
    require(report.columns.map(_.name)==columns,"conceptnet.schema_mismatch")
    report
  }
  val chainOrder=Vector("end","start","weight","start_pos","end_pos","surface_text","dataset","rel")
  /** A proposal-selected view, not discovery of all source paths. It retains a
    * proposed first hop plus target incoming assertions for the observed degree
    * guard. The native checker independently validates every resulting path. */
  def observeChainView(path:Path,source:String,via:String,target:String,output:OutputStream,
    limits:SqliteObservation.Limits=SqliteObservation.Limits(maxRows=45)):SqliteObservation.Report={
    require(Vector(source,via,target).forall(s=>s.nonEmpty && s.length<=65536),"conceptnet.label_budget")
    val report=SqliteObservation.observeLocal(path,"edge",chainOrder,output,limits,
      selection=Vector(SqliteObservation.TextEquals("rel","IsA")),
      alternatives=Vector(
        Vector(SqliteObservation.TextEquals("start",source),SqliteObservation.TextEquals("end",via)),
        Vector(SqliteObservation.TextEquals("end",target))))
    require(report.columns.map(_.name)==columns,"conceptnet.schema_mismatch")
    report
  }

}
