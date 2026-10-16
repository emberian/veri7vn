package veri7vn.authoring.assistance

import scala.language.unsafeNulls
import java.nio.file.Files
import java.nio.charset.StandardCharsets.UTF_8
import veri7vn.runtime.service.ResidentAuthorityService
import veri7vn.workbench.Authoring
import veri7vn.packages.intake.Intake

/** Actual native suggestion and existing managed editor, reused in the resident
  * workbench trial. Source recording is deliberately not capability admission. */
object GrowthCommandsChecks {
  def run(client:ResidentAuthorityService,author:Authoring,entry:Option[Array[String]=>Unit]=None):Unit={
    val root=Files.createTempDirectory("veri7vn-growth-review-").toRealPath()
    val draft="growth-review-"+java.util.UUID.randomUUID().toString
    val marker="(* editable recipe *)"
    val text="theory Recipe imports Mathematics_Exact begin\n"+marker+"\nend\n"
    Files.write(root.resolve("Recipe.thy"),text.getBytes(UTF_8))
    Files.write(root.resolve("package.json"),"{}".getBytes(UTF_8))
    author.importSource("import-"+draft,draft,root,Intake.Format.NativeDevelopment)
    val before=author.inspect(draft)
    val request="square then increment"
    val proposal=client.suggestGrowth(request)
    require(proposal.unsupported.isEmpty && proposal.source.nonEmpty,"Actual numeric suggestion unavailable")
    val start=text.indexOf(marker);val stop=start+marker.length
    def command(reply:String,operation:String):String={
      val out=new java.io.ByteArrayOutputStream()
      val input=new java.io.ByteArrayInputStream((reply+"\n").getBytes(UTF_8))
      Console.withOut(new java.io.PrintStream(out,true,"UTF-8")){
        Console.withIn(input){
          val args=Array("suggest",draft,"Recipe.thy",start.toString,stop.toString,request,
            "ChangeSpecification","Author chooses this ordered numeric recipe",operation)
          entry match {case Some(run)=>run(args);case None=>GrowthCommands.run(client,author,args)}
        }
      }
      out.toString("UTF-8")
    }
    val cancelled=command("cancel","cancel-"+draft)
    require(cancelled.contains(proposal.source) && author.inspect(draft).revision.id==before.revision.id,
      "Cancelled proposal changed managed source or hid native candidate")
    val saved=command("apply","apply-"+draft)
    require(saved.contains("Saved.") && author.source(draft,"Recipe.thy").text==text.replace(marker,proposal.source),
      "Actual native proposal did not become exact reviewed editable source")
    println("ASSISTANCE_GROWTH_COMMANDS_PASS actual_native_suggestion_review_cancel_managed_edit")
  }
}
