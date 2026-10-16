package veri7vn.packages.lifecycle
import veri7vn.packages.intake.Intake
import Intake.{Content,Staged,Format}

/** Controlled import of the shipped panel data shape. This parses data only;
  * it neither executes scorer source nor admits original requests/answers as truth.
  */
object LegacyPanel {
  val shippedScorerSHA256="a723ac247dc906d7610d25db07ce0d7abd35f0bd018e324fe26249d9ffcfbcd5"
  enum Expected {case StatedGold(value:String);case Decline, Unknown}
  final case class Row(split:String,index:Int,question:String,gold:Option[String],valid:Boolean,
    kind:Option[String],fields:Map[String,Any],nativeProposal:Expected,repairs:Vector[String])
  enum Scorer {case LegacyScore(sourceSHA256:String);case Unresolved(sourceSHA256:Option[String])}
  final case class Imported(original:Content,scorer:Scorer,rows:Vector[Row],metadata:Map[String,Any],
    bridgeObligations:Vector[String])
  private def scalarString(s:String):String={
    require(!s.codePoints().anyMatch(n=>n>=0xd800 && n<=0xdfff),"Unpaired surrogate in panel string")
    s
  }
  def read(panel:Content,scorerSource:Option[Content]):Imported={
    val root=InertJSON.objectValue(InertJSON.parse(panel,maxBytes=8*1024*1024,maxTokens=262144))
    require(root.contains("dev") && root.contains("heldout"),"Legacy panel requires dev and heldout lists")
    def split(name:String):Vector[Row]=root(name) match {
      case xs:List[?]=>
        require(xs.size<=2048,"Legacy panel case bound")
        xs.zipWithIndex.map {case(value,index)=>
          val item=InertJSON.objectValue(value)
          val question=item.get("q") match {case Some(s:String)=>scalarString(s);case _=>throw new IllegalArgumentException("Panel question must be a string")}
          val gold=item.get("a") match {case None=>None;case Some(s:String)=>Some(scalarString(s));case _=>throw new IllegalArgumentException("Panel expected answer must be a string")}
          val valid=item.get("valid") match {case None=>true;case Some(b:Boolean)=>b;case _=>throw new IllegalArgumentException("Panel validity must be Boolean; Python truthiness is not silently coerced")}
          val kind=item.get("kind") match {case None=>None;case Some(s:String)=>Some(scalarString(s));case _=>throw new IllegalArgumentException("Panel kind must be a string")}
          val proposal=if(!valid)Expected.Decline else gold.filter(_.nonEmpty).map(Expected.StatedGold.apply).getOrElse(Expected.Unknown)
          val repairs=if(valid && gold.forall(_.isEmpty))Vector("Native unknown expectation is unscored; LegacyScore would accept any answered response for blank/missing gold") else Vector.empty
          Row(name,index,question,gold,valid,kind,item,proposal,repairs)
        }.toVector
      case _=>throw new IllegalArgumentException("Legacy panel split must be a list")
    }
    val rows=split("dev")++split("heldout");require(rows.size<=2048,"Legacy panel total case bound")
    val scorer=scorerSource match {
      case Some(source) if source.sha256==shippedScorerSHA256=>Scorer.LegacyScore(source.sha256)
      case other=>Scorer.Unresolved(other.map(_.sha256))
    }
    Imported(panel,scorer,rows,root--Set("dev","heldout"),Vector(
      "Imported split labels/history remain sender attribution; recipient eligibility is Unknown, never fresh by import",
      "Bind each original question to actual native family request/interpretation profile without claiming the whole Python organ migrated",
      "Bind actual native result/status/renderer view and installed matcher operation; profile declarations alone cannot execute",
      "LegacyScore preserves answered-status, numeric-substring binary floating tolerance and lowercase-substring policy; native typed scoring is a distinct policy",
      "Preserve original scorer bytes; this recognized source pin characterizes policy and does not execute or formally lift Python",
      "Known blank/missing expected values require explicit repair; they never silently become correct native examples"))
  }
  def inspect(source:Staged):Imported={
    require(source.format==Format.Oracle7Original,"Original Oracle7 source required")
    val panel=source.entries.find(_.path=="panel.json").getOrElse(throw new IllegalArgumentException("Original panel.json unavailable"))
    read(panel.content,source.entries.find(_.path=="scorer.py").map(_.content))
  }
}
