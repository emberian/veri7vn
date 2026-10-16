import isabelle.*
import scala.language.unsafeNulls

@main def checkDeploymentLaunch():Unit=Command_Line.tool {
  // Steward runs this only after selecting a freshly qualified staged image.
  val builder=new ProcessBuilder("python3","tools/deploy/launch_check.py","var/deployment-application",
    "--output","var/deployment-launch-check-"+java.util.UUID.randomUUID().toString)
  builder.inheritIO()
  require(builder.start().waitFor()==0,"actual staged public main launch/restart failed")
}
