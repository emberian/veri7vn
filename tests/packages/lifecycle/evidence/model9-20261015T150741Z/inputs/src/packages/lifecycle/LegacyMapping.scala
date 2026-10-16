package veri7vn.packages.lifecycle

import veri7vn.packages.intake.Intake
import Intake.{Staged,Format,Role}

/** Byte-pinned source mapping proposals, never Python evaluation or completed-lift labels. */
object LegacyMapping {
  final case class Diagnostic(code:String,path:Option[String],message:String)
  final case class RecipeProposal(originalPath:String,originalSHA256:String,command:String,
    parameterMeanings:Vector[String],remainingObligations:Vector[String],intentionalRepairs:Vector[String])
  final case class Report(originalIdentity:String,preservedPaths:Vector[String],exposurePaths:Vector[String],
    candidates:Vector[RecipeProposal],unresolved:Vector[String],diagnostics:Vector[Diagnostic])
  private val paintOrgan="35ca95a96df508b215eab49a74b0350d1cb8d7b4f2606c58ada81dcaf016609c"
  def inspect(source:Staged):Report={
    require(source.format==Format.Oracle7Original,"Original Oracle7 source required")
    val known=source.entries.filter(e=>e.path=="organ_paint_coverage.py" && e.content.sha256==paintOrgan)
    val candidates=known.map(e=>RecipeProposal(e.path,e.content.sha256,
      "v7_math_formula litres_scalar = \"Divide (Times (Times (Parameter 0) (Parameter 1)) (Parameter 2)) (Parameter 3)\"",
      Vector("0: width scalar in selected length unit","1: height scalar in same length unit",
        "2: coat count","3: spread-rate scalar; unit/model must be supplied"),
      Vector("Bridge original floating behavior versus exact rational evaluation, including rounding",
        "Native input/routing parser, positive dimension guards and missing-size clarification",
        "Typed area/length/spread-rate unit profile and exact 0.3048 foot conversion",
        "Default spread rate 10 is an explicitly adopted model, not a world-truth axiom",
        "Preserve card/source qualifications and exposure; qualify composed interception/decline behavior",
        "Actual executable linkage/admission and baseline/candidate qualification before deployment"),
      Vector("A zero spread rate must return a scoped domain failure/undefined result; original Python divides by zero")))
    val mappedPaths=known.map(_.path).toSet
    val unresolved=source.entries.filter(e=>e.role==Role.UnresolvedExecutable || e.role==Role.Other)
      .filterNot(e=>mappedPaths(e.path)).map(_.path)
    val diagnostics=Vector(Diagnostic("migration.originals_retained",None,"All original bytes remain in the linked intake record"),
      Diagnostic("migration.sender_exposure",None,"Sender panel/log/verdict remain attributed historical material; no native acceptance or recipient freshness inferred"))++
      candidates.map(c=>Diagnostic("migration.partial_mathematical_core",Some(c.originalPath),"Recognized exact shipped bytes; only a recipe proposal, not the entire organ lift"))++
      unresolved.map(p=>Diagnostic("migration.unresolved_executable",Some(p),"Requires actual native semantics/implementation bridge; not executed during intake"))
    Report(source.identity,source.entries.map(_.path),source.exposure.map(_.path),candidates,unresolved,diagnostics)
  }
}
