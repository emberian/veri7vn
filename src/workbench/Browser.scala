package veri7vn.workbench
import scala.language.unsafeNulls
import com.sun.net.httpserver.{HttpServer,HttpExchange}
import java.net.{InetSocketAddress,URLDecoder}
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Path
import java.util.UUID
import veri7vn.packages.intake.Intake
import veri7vn.diagnostics.{Diagnostics,Repair}
import veri7vn.authoring.assistance.Assistance

/** Loopback-only authoring surface sharing the CLI's actual managed operations. */
final class Browser(author:Authoring,execution:Option[Execution]=None,builds:Option[BuildWorkspace]=None) extends AutoCloseable {
  private val reviews=new ReviewTickets
  private val reviewFields=Set("draft","file","manifest","revision","obligation","context","start","stop","choice","meaning","reason","replacement")
  private val token=UUID.randomUUID().toString
  private val server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0)
  private def escape(s:String)=s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;")
  private def fields(raw:String)=raw.split("&").filter(_.nonEmpty).map {part=>
    val pair=part.split("=",2);URLDecoder.decode(pair(0),UTF_8)->URLDecoder.decode(if(pair.length==2)pair(1)else "",UTF_8)
  }.toMap
  private def input(name:String,value:String="")="<input name=\""+name+"\" value=\""+escape(value)+"\">"
  private def hidden(name:String,value:String)="<input type=hidden name=\""+name+"\" value=\""+escape(value)+"\">"
  private def form(action:String,body:String)="<form method=post>"+hidden("token",token)+hidden("action",action)+body+"<button>"+action+"</button></form>"
  private def workspaceURL(draft:String,file:Option[String]=None,view:Option[String]=None):String={
    def encoded(value:String)=java.net.URLEncoder.encode(value,UTF_8)
    "/?package="+encoded(draft)+file.map(path=>"&file="+encoded(path)).getOrElse("")+view.map(name=>"&view="+encoded(name)).getOrElse("")
  }
  private def packageLink(draft:String):String="<p><a href=\""+escape(workspaceURL(draft))+"\">Back to "+escape(draft)+" package workspace</a></p>"
  private def sourceView(draft:String,file:String):String={
    val source=author.source(draft,file);val snapshot=source.snapshot
    packageLink(draft)+"<h2>"+escape(file)+"</h2><p>Source revision "+escape(snapshot.revision.id)+"</p>"+
      editor(snapshot.draft,file,snapshot.manifest,snapshot.revision.id,java.util.Base64.getEncoder.encodeToString(source.entry.content.bytes),source.text)
  }
  private def assistanceForm(draft:String,file:String,manifest:String,revision:String,text:String,
    start:Int=0,stop:Option[Int]=None,context:String="unreviewed",proposal:Option[String]=None):String=
    "<details><summary>Review a source change</summary><p>Choose an obligation, condition or proposed example, then review its effect on meaning. "+(if(context=="unreviewed")"This is author-selected context, not a native check result."else "This review starts from a native diagnostic at the matching current source revision; an edit is not a proof or admission result.")+"</p>"+
    form("Preview source change",hidden("draft",draft)+hidden("file",file)+hidden("manifest",manifest)+hidden("revision",revision)+
      "<label>Work item "+input("obligation")+"</label>"+hidden("context",context)+
      "<label>Change kind <select name=choice><option>Obligation</option><option>Condition</option><option>Example</option></select></label>"+
      "<label>Effect on meaning <select required name=meaning><option value=''>Choose an effect</option><option value=PreserveMeaning>Preserve meaning</option><option value=RestrictDomain>Restrict the domain</option><option value=ChangeSpecification>Change the specification</option></select></label>"+
      "<label>Reason "+input("reason")+"</label><details><summary>Source byte range</summary>Start "+input("start",start.toString)+" End "+input("stop",stop.getOrElse(text.getBytes(UTF_8).length).toString)+"</details>"+
      "<label>Proposed replacement<textarea name=replacement rows=12>"+escape(proposal.getOrElse(text))+"</textarea></label>")+"</details>"
  private def editor(draft:String,file:String,manifest:String,revision:String,original:String,replacement:String):String=
    form("Save",hidden("draft",draft)+hidden("file",file)+hidden("manifest",manifest)+hidden("revision",revision)+
      hidden("original",original)+"<textarea name=replacement rows=24 cols=100>"+escape(replacement)+"</textarea>")+
      assistanceForm(draft,file,manifest,revision,replacement)
  private def currentReview(p:Map[String,String]):Assistance.Session={
    val snapshot=author.inspect(p("draft"))
    require(snapshot.manifest==p("manifest") && snapshot.revision.id==p("revision"),"Source changed since this review. Reopen the file and review the current source.")
    require(Assistance.Choice.values.exists(_.toString==p("choice")),"Choose an obligation, condition or example")
    require(Repair.Meaning.values.exists(_.toString==p("meaning")),"Choose the effect on meaning")
    require(p("reason").trim.nonEmpty,"Give a reason for this source change")
    require(p("start").matches("[0-9]{1,9}") && p("stop").matches("[0-9]{1,9}"),"Source byte bounds must be whole numbers")
    val plan=Assistance.plan(snapshot,p("obligation"),p("context"),p("file"),p("start").toInt,p("stop").toInt)
    Assistance.review(plan,Assistance.Choice.valueOf(p("choice")),Repair.Meaning.valueOf(p("meaning")),p("reason"),Intake.Content(p("replacement").getBytes(UTF_8)))
  }
  private def submittedChange(p:Map[String,String],message:String):String=
    packageLink(p("draft"))+"<p role=alert>"+escape(message)+"</p><h2>Your submitted replacement</h2><p>Review the current file before starting another review. This replacement is not merged automatically.</p>"+
      "<p>Submitted work item: "+escape(p("obligation"))+"</p><p>"+escape(p("choice")+" — "+p("meaning"))+"</p><p>"+escape(p("reason"))+"</p>"+
      "<p>Submitted target: "+escape(p("file"))+", revision "+escape(p("revision"))+".</p>"+
      "<textarea readonly rows=12 aria-label='Unapplied submitted replacement'>"+escape(p("replacement"))+"</textarea>"+
      form("Open current source",hidden("draft",p("draft"))+hidden("file",p("file")))
  private def packageView(draft:String):String={
    val snapshot=author.inspect(draft)
    val description=try {
      val info=veri7vn.packages.lifecycle.PackageUpdates.describe(snapshot.revision)
      val d=info.descriptor
      "<h3>"+escape(d.title)+"</h3><p>"+escape(d.description)+"</p><p>"+escape(d.key.id+" @ "+d.key.version)+"</p>"+
        "<p>Pinned dependencies: "+escape(d.dependencies.map(k=>k.id+" @ "+k.version).mkString(", "))+"</p>"+
        "<h3>Declared capabilities</h3><ul>"+d.exports.map(e=>"<li>"+escape(e.title+" ("+e.id+") — "+e.specification.theory+"."+e.specification.name)+"</li>").mkString+"</ul>"+
        "<p>These are source declarations; inspection does not establish native admission.</p>"
    } catch {case e:IllegalArgumentException=>"<p role=alert>Package descriptor needs attention: "+escape(e.getMessage)+". Source files remain available below.</p>"}
    val buildPaths=if(builds.isEmpty)Vector.empty[String]else try {
      val descriptor=veri7vn.packages.lifecycle.PackageUpdates.describe(snapshot.revision).descriptor
      if(descriptor.dependencies.nonEmpty || descriptor.native.isEmpty)Vector.empty[String]
      else descriptor.files.filter(file=>file.role==veri7vn.packages.lifecycle.PackageModel.FileRole.Source && file.path.endsWith(".thy")).map(_.path)
    }catch {case _:IllegalArgumentException=>Vector.empty[String]}
    "<h2>"+escape(snapshot.draft)+" package workspace</h2><p>Source revision "+escape(snapshot.revision.id)+"</p><p>Manifest "+escape(snapshot.manifest)+"</p>"+description+
      builds.map(_=>buildPaths.map(path=>
        form("Build native source",hidden("draft",draft)+hidden("manifest",snapshot.manifest)+hidden("file",path)+
          "<p>Check "+escape(path)+" from this captured revision. A build artifact does not activate or admit the package.</p>")).mkString).getOrElse("")+
      (if(builds.nonEmpty && buildPaths.isEmpty)"<p>Building here requires a native descriptor with declared theory source. Packages with dependencies also need admitted parent selection.</p>"else "")+
      "<p><a href=\""+escape(workspaceURL(draft,view=Some("impact")))+"\">Inspect affected package declarations</a></p>"+
      execution.map(_=>"<section><h3>Inspect a retained run</h3><p>Enter a request ID to inspect its actual native provenance beside this package. Opening a package does not associate that request with its edited source.</p><form method=get>"+hidden("package",draft)+"<label>Request ID "+input("request")+"</label><button>Inspect retained run</button></form></section>").getOrElse("")+
      "<p><a href=\""+escape(workspaceURL(draft,view=Some("migration")))+"\">Inspect original-source mapping and obligations</a></p><h3>Package source files</h3><ul>"+snapshot.revision.entries.map(e=>"<li><a href=\""+escape(workspaceURL(draft,Some(e.path)))+"\">"+escape(e.path)+"</a>"+" — "+e.content.size+" bytes"+form("Open",hidden("draft",snapshot.draft)+hidden("file",e.path))+"</li>").mkString+"</ul>"
  }
  private def impactView(draft:String):String={
    val view=author.impact(draft)
    packageLink(draft)+"<h2>Change impact for "+escape(draft)+"</h2><p>"+escape(view.scope)+"</p><p role=status>"+escape(view.qualification)+"</p>"+
      view.target.map(target=>"<p>Selected source revision "+escape(target.revision)+".</p>").getOrElse("")+
      "<h3>Inspected dependency paths</h3><ul>"+view.affected.map(row=>"<li><a href=\""+escape(workspaceURL(row.consumer.draft))+"\">"+escape(row.consumer.draft)+"</a>: "+escape(row.pathToTarget.mkString(" → "))+"; inspected revision "+escape(row.consumer.revision)+"</li>").mkString+"</ul>"+
      (if(view.computed && view.affected.isEmpty)"<p>No dependent package was found in the inspected declaration graph. Unavailable descriptors and missing providers are listed below.</p>"else "")+
      "<h3>Inspection limits</h3><ul>"+view.issues.map(issue=>"<li>"+escape(veri7vn.diagnostics.PackageImpact.issueText(issue))+"</li>").mkString+"</ul>"+
      "<details><summary>Inspected source revisions</summary><ul>"+view.inspected.map(pkg=>"<li>"+escape(pkg.draft+" — "+pkg.key.id+" @ "+pkg.key.version+" — "+pkg.revision)+"</li>").mkString+"</ul></details>"
  }
  private def migrationView(draft:String):String={
    val report=author.migration(draft)
    packageLink(draft)+"<h2>Original specialist</h2>"+report.diagnostics.map(d=>"<p>"+escape(d.path.getOrElse("Package")+": "+d.message)+"</p>").mkString+
              report.candidates.map(c=>"<section><h3>Proposed native formula</h3><p>This is a source mapping proposal; its obligations remain open.</p><p>Original source: "+
                escape(c.originalPath)+"</p><details><summary>Original byte identity</summary><code>"+escape(c.originalSHA256)+"</code></details><pre>"+escape(c.command)+"</pre>"+
                "<h4>Parameter meanings</h4><ul>"+c.parameterMeanings.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul><h4>Remaining obligations</h4><ul>"+
                c.remainingObligations.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul><h4>Intentional repairs</h4><ul>"+
                c.intentionalRepairs.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul></section>").mkString
  }
  private def buildActions(id:BigInt):String=
    form("Refresh build",hidden("build",id.toString))+form("Cancel build",hidden("build",id.toString))+
      form("Forget build",hidden("build",id.toString)+"<label><input type=checkbox required name=confirm value=yes> Remove this build and its dependent retained results</label>")
  private def buildView(id:BigInt):String={
    val native=builds.getOrElse(throw new IllegalArgumentException("Resident native build support is unavailable"))
    val inspected=try native.inspect(id) catch {case _:Exception=>None}
    inspected match {
      case None=>"<h2>Build "+id+"</h2><p role=alert>This build cannot currently be opened. No retained source or result is displayed. Cancellation and Forget are checked separately by the native service.</p>"+buildActions(id)
      case Some(view)=>
        "<section><h2>Build "+view.request+"</h2><p role=status>"+escape(view.state)+"</p>"+
          view.source.map(source=>packageLink(source.draft)+"<p>Captured source: "+escape(source.path)+"; revision "+escape(source.revision)+".</p>"+
            "<p><a href=\""+escape(workspaceURL(source.draft,Some(source.path)))+"\">Open current source</a></p>").getOrElse("<p>Captured source is unavailable.</p>")+
          view.candidate.map(candidate=>"<p>Native artifact "+candidate+" is available. This does not establish package admission or activation.</p>").getOrElse("")+
          view.diagnostic.map(d=>"<h3>Native build diagnostic</h3><p>"+escape(d.description)+"</p><pre>"+escape(d.message)+"</pre>"+
            view.source.toVector.flatMap(source=>d.currentSpan.filter((start,stop)=>start>=0 && stop>start).toVector.flatMap {case(start,stop)=>
              val current=try Some(author.source(source.draft,source.path)) catch {case _:IllegalArgumentException=>None}
              current.filter(s=>s.snapshot.manifest==source.manifest && s.snapshot.revision.id==source.revision).map {s=>
                val original=s.entry.content.bytes
                val selected=try {require(stop<=original.length,"Native diagnostic span differs from current source");Authoring.decode(Intake.Content(java.util.Arrays.copyOfRange(original,start,stop)))} finally java.util.Arrays.fill(original,0.toByte)
                assistanceForm(source.draft,source.path,source.manifest,source.revision,s.text,start,Some(stop),d.code,Some(selected))
              }
            }).mkString).getOrElse("")+
          "<p>Refreshing this page never starts another attempt. Edit the current package and explicitly build again to revalidate.</p>"+
          buildActions(id)+"</section>"
    }
  }
  private def requestView(id:BigInt):String={
    val result=execution.get.result(id)
    val diagnosis=Diagnostics.explain(result.status)
    val inspection=try execution.get.provenance(id)
      catch {case problem:Exception=>Vector("Inspection unavailable"->Option(problem.getMessage).getOrElse("Refresh to retry"))}
    val reading=inspection.filter((key,_)=>key=="Reading" || key.startsWith("Literal ")).map((key,value)=>"<p>"+escape(key)+": "+escape(value)+"</p>").mkString
    val provenance=inspection.filterNot((key,_)=>key=="Reading" || key.startsWith("Literal ")).map((key,value)=>"<dt>"+escape(key)+"</dt><dd>"+escape(value)+"</dd>").mkString
    "<section><h2>Request "+id+"</h2><p role=status>"+escape(result.status)+"</p><h3>"+escape(diagnosis.title)+"</h3><p>"+escape(diagnosis.detail)+"</p>"+reading+"<details><summary>Request interpretation and provenance</summary><p>Execution identity names the planned execution; status reports its current outcome.</p><dl>"+provenance+"</dl></details>"+
      result.html.map(html=>"<iframe sandbox title=\"Licensed native result\" srcdoc=\""+escape(html)+"\"></iframe>").getOrElse("")+
      "<p>Keep this request ID to inspect the retained result after reopening the workspace.</p>"+
      form("Refresh result",hidden("request",id.toString))+
      form("Cancel request",hidden("request",id.toString))+
      form("Forget request",hidden("request",id.toString)+"<label><input type=checkbox required name=confirm value=yes> Remove this request and its dependent retained results</label>")+"</section>"
  }
  server.createContext("/",(exchange:HttpExchange)=>{
    var body=""
    var redirect:Option[String]=None
    try {
      require(exchange.getRequestURI.getPath=="/","Unknown page")
      if(exchange.getRequestMethod=="GET") {
        val query=Option(exchange.getRequestURI.getRawQuery).getOrElse("")
        require(query.length<=1024,"Query too large")
        val parameters=fields(query)
        parameters.get("package").foreach {draft=>
          body=parameters.get("file") match {
            case Some(file)=>sourceView(draft,file)
            case None if parameters.get("view").contains("migration")=>migrationView(draft)
            case None if parameters.get("view").contains("impact")=>impactView(draft)
            case None=>packageView(draft)
          }
        }
        parameters.get("request").foreach(id=>body=body+requestView(BigInt(id)))
        parameters.get("build").foreach(id=>body=body+buildView(BigInt(id)))
      }
      if(exchange.getRequestMethod=="POST") {
        require(exchange.getRequestHeaders.getFirst("Origin")==null || exchange.getRequestHeaders.getFirst("Origin")==url.stripSuffix("/"),"Foreign browser origin")
        val bytes=exchange.getRequestBody.readNBytes(2*1024*1024+1);require(bytes.length<=2*1024*1024,"Form too large")
        val p=fields(new String(bytes,UTF_8));require(p.get("token").contains(token),"Expired form")
        p("action") match {
          case "Build native source"=>
            val native=builds.getOrElse(throw new IllegalArgumentException("Resident native build support is unavailable"))
            redirect=Some("/?build="+native.start(p("draft"),p("manifest"),p("file")))
          case "Refresh build"=>redirect=Some("/?build="+BigInt(p("build")))
          case "Cancel build"=>
            builds.get.cancel(BigInt(p("build")));redirect=Some("/?build="+BigInt(p("build")))
          case "Forget build"=>
            require(p.get("confirm").contains("yes"),"Confirm removal before forgetting a build")
            builds.get.forget(BigInt(p("build")));redirect=Some("/?build="+BigInt(p("build")))
          case "Run mathematics"=>
            val native=execution.getOrElse(throw new IllegalArgumentException("Resident execution is unavailable in this source-only workspace"))
            val original=p("question").getBytes(UTF_8)
            val route=try native.route(original) finally java.util.Arrays.fill(original,0.toByte)
            body=route.status match {
              case "ready"=>require(route.alternatives.size==1,"Native reading shape");redirect=Some("/?request="+native.select(route.handle,route.alternatives.head));""
              case "clarification"=>"<h2>Choose a native interpretation</h2><p>The installed reader found multiple alternatives. Choose its index to run the retained original input.</p>"+
                form("Select interpretation",hidden("handle",route.handle.toString)+route.alternatives.map(index=>
                  "<label><input type=radio required name=selection value=\""+index+"\"> Native interpretation "+index+"</label>").mkString)
              case other=>"<p role=alert>The installed reader could not prepare this input: "+escape(other)+". Review the question before starting a new request.</p>"
            }
          case "Select interpretation"=>redirect=Some("/?request="+execution.get.select(p("handle").toLong,p("selection").toInt))
          case "Refresh result"=>redirect=Some("/?request="+BigInt(p("request")))
          case "Cancel request"=>execution.get.cancel(BigInt(p("request")));redirect=Some("/?request="+BigInt(p("request")))
          case "Forget request"=>
            require(p.get("confirm").contains("yes"),"Confirm removal before forgetting a request")
            execution.get.forget(BigInt(p("request")))
            redirect=Some("/?request="+BigInt(p("request")))
          case "Preview source change"=>
            val captured=reviewFields.toVector.map(key=>key->p(key)).toMap
            val session=currentReview(captured)
            val id=reviews.issue(captured)
            val target=session.review.plan.target
            val location=SourceLocation.locate(target.snapshot,target.path,target.start,target.stop,target.snapshot.revision.id)
            body=packageLink(captured("draft"))+"<h2>Review source change</h2><p>Work item: "+escape(target.obligation)+"</p><p>"+escape(captured("choice")+" — "+captured("meaning"))+"</p><p>"+escape(captured("reason"))+"</p>"+
              "<p>"+escape(target.path)+", line "+location.line+", column "+location.column+".</p><details><summary>Captured source identity</summary>Revision "+escape(captured("revision"))+", bytes "+target.start+"–"+target.stop+".</details><h3>Original</h3><pre>"+escape(Authoring.decode(target.original))+"</pre><h3>Replacement</h3><pre>"+escape(captured("replacement"))+"</pre>"+
              "<p>Applying records editable source only. Native revalidation remains a separate operation.</p>"+
              form("Apply reviewed change",hidden("review",id)+captured.toVector.sortBy(_._1).map((key,value)=>hidden(key,value)).mkString)+
              form("Cancel reviewed change",hidden("review",id))
          case "Apply reviewed change"=>
            val captured=reviewFields.toVector.map(key=>key->p(key)).toMap
            if(!reviews.consume(p("review"),captured))
              body=submittedChange(captured,"Review expired, changed or already used. Preview the change again.")
            else {
              val attempted=try Right(currentReview(captured).applyTo("review-"+p("review"),author))
                catch {case problem:Exception=>Left(Option(problem.getMessage).getOrElse("The source change could not be confirmed. Inspect the current source before retrying."))}
              body=attempted match {
                case Right(result @ Assistance.Saved(veri7vn.packages.lifecycle.ManagedDrafts.Recorded(receipt,_))) if receipt.status.toString=="Committed"=>
                  packageLink(captured("draft"))+"<p role=status>"+escape(Assistance.resultMessage(result))+"</p>"+form("Open current source",hidden("draft",captured("draft"))+hidden("file",captured("file")))
                case Right(result)=>submittedChange(captured,Assistance.resultMessage(result))
                case Left(message)=>submittedChange(captured,message)
              }
            }
          case "Cancel reviewed change"=>
            require(reviews.cancel(p("review")),"Review expired or already used")
            body="<p role=status>Review cancelled. No source change was applied.</p>"
          case "Import"=>
            val result=author.importSource(UUID.randomUUID().toString,p("draft"),Path.of(p("path")),
              if(p.get("format").contains("original"))Intake.Format.Oracle7Original else Intake.Format.NativeDevelopment)
            body="<p>Import result: "+escape(Authoring.resultMessage(result))+"</p>"+packageLink(p("draft"))
          case "Open"|"Open current source"=>
            body=sourceView(p("draft"),p("file"))
          case "Save"=>
            val original=java.util.Base64.getDecoder.decode(p("original"))
            val result=author.edit(UUID.randomUUID().toString,p("draft"),p("manifest"),p("revision"),p("file"),0,original.length,original,p("replacement").getBytes(UTF_8))
            val latest=author.source(p("draft"),p("file"))
            val committed=result match {
              case veri7vn.packages.lifecycle.ManagedDrafts.Recorded(receipt,_)=>receipt.status.toString=="Committed"
              case _=>false
            }
            body=packageLink(p("draft"))+"<p role=status>"+escape(Authoring.resultMessage(result))+"</p>"+
              (if(committed)editor(latest.snapshot.draft,p("file"),latest.snapshot.manifest,latest.snapshot.revision.id,
                java.util.Base64.getEncoder.encodeToString(latest.entry.content.bytes),latest.text)
               else editor(p("draft"),p("file"),p("manifest"),p("revision"),p("original"),p("replacement")))
          case "Inspect"=>body=packageView(p("draft"))
          case "Migration"=>
            body=migrationView(p("draft"))
          case _=>throw new IllegalArgumentException("Unknown action")
        }
      }
    } catch {case e:Exception=>body="<p role=alert>"+escape(Option(e.getMessage).getOrElse(e.getClass.getSimpleName))+"</p>"}
    val listing=try "<h2>Packages</h2><ul>"+author.list().map(id=>"<li><a href=\""+escape(workspaceURL(id))+"\">"+escape(id)+"</a>"+form("Inspect",hidden("draft",id))+"</li>").mkString+"</ul>"
      catch {case e:IllegalArgumentException=>"<p>"+escape(e.getMessage)+"</p>"}
    val running=execution.map(_=>"<section><h2>Ask the installed mathematics specialist</h2><p>Requests use the installed native capability. Editing a package does not change this specialist. Retained result HTML is supplied only by the native service.</p>"+
      form("Run mathematics","<label>Question "+input("question")+"</label>")+
      form("Refresh result","<label>Retained request ID "+input("request")+"</label>")+"</section>").getOrElse("<p>Source-only workspace. Start the runtime with --workbench serve to run the installed native specialist.</p>")
    val introduction=if(builds.nonEmpty)"Import and edit package source, build native artifacts, and review diagnostics. Package admission and activation remain separate."else "Import and edit local package source. Imported programs remain unchecked until native construction and admission are available."
    val html="<!doctype html><html><meta charset=utf-8><meta name=viewport content='width=device-width'><title>Specialist workspace</title><style>body{max-width:960px;margin:32px auto;padding:16px;font:16px system-ui}input,button,textarea{font:inherit;margin:5px;max-width:100%}textarea{box-sizing:border-box;width:100%}pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:12px;background:#eef2f5}iframe{width:100%;min-height:140px;border:1px solid #bac6cf}section{padding:16px;border:1px solid #bac6cf;margin:20px 0}form{margin:20px 0;padding:12px;background:#eef2f5}li{margin:8px}</style><h1>Specialist workspace</h1><p>"+introduction+"</p>"+running+body+listing+
      form("Import","Package name "+input("draft")+" Local directory or ZIP "+input("path")+"<select name=format><option value=native>Native package</option><option value=original>Original specialist</option></select>")+
      form("Inspect","Package name "+input("draft"))+form("Open","Package name "+input("draft")+" File "+input("file"))+
      form("Migration","Original package name "+input("draft"))+"</html>"
    if(redirect.nonEmpty) {
      exchange.getResponseHeaders.set("Location",redirect.get)
      exchange.getResponseHeaders.set("Cache-Control","no-store")
      exchange.sendResponseHeaders(303,-1);exchange.close()
    } else {
    val bytes=html.getBytes(UTF_8);exchange.getResponseHeaders.set("Content-Type","text/html; charset=utf-8")
    exchange.getResponseHeaders.set("Cache-Control","no-store");exchange.getResponseHeaders.set("X-Content-Type-Options","nosniff")
    exchange.sendResponseHeaders(200,bytes.length);val out=exchange.getResponseBody;try out.write(bytes)finally out.close()
    }
  })
  def url:String="http://127.0.0.1:"+server.getAddress.getPort+"/"
  def start():Unit=server.start()
  def close():Unit={server.stop(0);reviews.clear()}
}
