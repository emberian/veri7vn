package veri7vn.workbench
import scala.language.unsafeNulls
import com.sun.net.httpserver.{HttpServer,HttpExchange}
import java.net.{InetSocketAddress,URLDecoder}
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Path
import java.util.UUID
import veri7vn.packages.intake.Intake
import veri7vn.diagnostics.Diagnostics

/** Loopback-only authoring surface sharing the CLI's actual managed operations. */
final class Browser(author:Authoring,execution:Option[Execution]=None) extends AutoCloseable {
  private val token=UUID.randomUUID().toString
  private val server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0)
  private def escape(s:String)=s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\"","&quot;")
  private def fields(raw:String)=raw.split("&").filter(_.nonEmpty).map {part=>
    val pair=part.split("=",2);URLDecoder.decode(pair(0),UTF_8)->URLDecoder.decode(if(pair.length==2)pair(1)else "",UTF_8)
  }.toMap
  private def input(name:String,value:String="")="<input name=\""+name+"\" value=\""+escape(value)+"\">"
  private def hidden(name:String,value:String)="<input type=hidden name=\""+name+"\" value=\""+escape(value)+"\">"
  private def form(action:String,body:String)="<form method=post>"+hidden("token",token)+hidden("action",action)+body+"<button>"+action+"</button></form>"
  private def editor(draft:String,file:String,manifest:String,revision:String,original:String,replacement:String):String=
    form("Save",hidden("draft",draft)+hidden("file",file)+hidden("manifest",manifest)+hidden("revision",revision)+
      hidden("original",original)+"<textarea name=replacement rows=24 cols=100>"+escape(replacement)+"</textarea>")
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
    "<h2>"+escape(snapshot.draft)+"</h2><p>Source revision "+escape(snapshot.revision.id)+"</p><p>Manifest "+escape(snapshot.manifest)+"</p>"+description+
      "<ul>"+snapshot.revision.entries.map(e=>"<li>"+escape(e.path)+" — "+e.content.size+" bytes"+form("Open",hidden("draft",snapshot.draft)+hidden("file",e.path))+"</li>").mkString+"</ul>"
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
    var redirect:Option[BigInt]=None
    try {
      require(exchange.getRequestURI.getPath=="/","Unknown page")
      if(exchange.getRequestMethod=="GET") {
        val query=Option(exchange.getRequestURI.getRawQuery).getOrElse("")
        require(query.length<=1024,"Query too large")
        fields(query).get("request").foreach(id=>body=requestView(BigInt(id)))
      }
      if(exchange.getRequestMethod=="POST") {
        require(exchange.getRequestHeaders.getFirst("Origin")==null || exchange.getRequestHeaders.getFirst("Origin")==url.stripSuffix("/"),"Foreign browser origin")
        val bytes=exchange.getRequestBody.readNBytes(2*1024*1024+1);require(bytes.length<=2*1024*1024,"Form too large")
        val p=fields(new String(bytes,UTF_8));require(p.get("token").contains(token),"Expired form")
        p("action") match {
          case "Run mathematics"=>
            val native=execution.getOrElse(throw new IllegalArgumentException("Resident execution is unavailable in this source-only workspace"))
            val original=p("question").getBytes(UTF_8)
            val route=try native.route(original) finally java.util.Arrays.fill(original,0.toByte)
            body=route.status match {
              case "ready"=>require(route.alternatives.size==1,"Native reading shape");redirect=Some(native.select(route.handle,route.alternatives.head));""
              case "clarification"=>"<h2>Choose a native interpretation</h2><p>The installed reader found multiple alternatives. Choose its index to run the retained original input.</p>"+
                form("Select interpretation",hidden("handle",route.handle.toString)+route.alternatives.map(index=>
                  "<label><input type=radio required name=selection value=\""+index+"\"> Native interpretation "+index+"</label>").mkString)
              case other=>"<p role=alert>The installed reader could not prepare this input: "+escape(other)+". Review the question before starting a new request.</p>"
            }
          case "Select interpretation"=>redirect=Some(execution.get.select(p("handle").toLong,p("selection").toInt))
          case "Refresh result"=>redirect=Some(BigInt(p("request")))
          case "Cancel request"=>execution.get.cancel(BigInt(p("request")));redirect=Some(BigInt(p("request")))
          case "Forget request"=>
            require(p.get("confirm").contains("yes"),"Confirm removal before forgetting a request")
            execution.get.forget(BigInt(p("request")))
            redirect=Some(BigInt(p("request")))
          case "Import"=>
            val result=author.importSource(UUID.randomUUID().toString,p("draft"),Path.of(p("path")),
              if(p.get("format").contains("original"))Intake.Format.Oracle7Original else Intake.Format.NativeDevelopment)
            body="<p>Import result: "+escape(Authoring.resultMessage(result))+"</p>"
          case "Open"=>
            val source=author.source(p("draft"),p("file"));val s=source.snapshot
            body="<h2>"+escape(p("file"))+"</h2><p>Source revision "+escape(s.revision.id)+"</p>"+
              editor(s.draft,p("file"),s.manifest,s.revision.id,java.util.Base64.getEncoder.encodeToString(source.entry.content.bytes),source.text)
          case "Save"=>
            val original=java.util.Base64.getDecoder.decode(p("original"))
            val result=author.edit(UUID.randomUUID().toString,p("draft"),p("manifest"),p("revision"),p("file"),0,original.length,original,p("replacement").getBytes(UTF_8))
            val latest=author.source(p("draft"),p("file"))
            val committed=result match {
              case veri7vn.packages.lifecycle.ManagedDrafts.Recorded(receipt,_)=>receipt.status.toString=="Committed"
              case _=>false
            }
            body="<p role=status>"+escape(Authoring.resultMessage(result))+"</p>"+
              (if(committed)editor(latest.snapshot.draft,p("file"),latest.snapshot.manifest,latest.snapshot.revision.id,
                java.util.Base64.getEncoder.encodeToString(latest.entry.content.bytes),latest.text)
               else editor(p("draft"),p("file"),p("manifest"),p("revision"),p("original"),p("replacement")))
          case "Inspect"=>body=packageView(p("draft"))
          case "Migration"=>
            val report=author.migration(p("draft"))
            body="<h2>Original specialist</h2>"+report.diagnostics.map(d=>"<p>"+escape(d.path.getOrElse("Package")+": "+d.message)+"</p>").mkString+
              report.candidates.map(c=>"<section><h3>Proposed native formula</h3><p>This is a source mapping proposal; its obligations remain open.</p><p>Original source: "+
                escape(c.originalPath)+"</p><details><summary>Original byte identity</summary><code>"+escape(c.originalSHA256)+"</code></details><pre>"+escape(c.command)+"</pre>"+
                "<h4>Parameter meanings</h4><ul>"+c.parameterMeanings.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul><h4>Remaining obligations</h4><ul>"+
                c.remainingObligations.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul><h4>Intentional repairs</h4><ul>"+
                c.intentionalRepairs.map(v=>"<li>"+escape(v)+"</li>").mkString+"</ul></section>").mkString
          case _=>throw new IllegalArgumentException("Unknown action")
        }
      }
    } catch {case e:Exception=>body="<p role=alert>"+escape(Option(e.getMessage).getOrElse(e.getClass.getSimpleName))+"</p>"}
    val listing=try "<h2>Packages</h2><ul>"+author.list().map(id=>"<li>"+escape(id)+form("Inspect",hidden("draft",id))+"</li>").mkString+"</ul>"
      catch {case e:IllegalArgumentException=>"<p>"+escape(e.getMessage)+"</p>"}
    val running=execution.map(_=>"<section><h2>Ask the installed mathematics specialist</h2><p>Requests use the installed native capability. Editing a package does not change this specialist. Retained result HTML is supplied only by the native service.</p>"+
      form("Run mathematics","<label>Question "+input("question")+"</label>")+
      form("Refresh result","<label>Retained request ID "+input("request")+"</label>")+"</section>").getOrElse("<p>Source-only workspace. Start the runtime with --workbench serve to run the installed native specialist.</p>")
    val html="<!doctype html><html><meta charset=utf-8><meta name=viewport content='width=device-width'><title>Specialist workspace</title><style>body{max-width:960px;margin:32px auto;padding:16px;font:16px system-ui}input,button,textarea{font:inherit;margin:5px;max-width:100%}textarea{box-sizing:border-box;width:100%}pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:12px;background:#eef2f5}iframe{width:100%;min-height:140px;border:1px solid #bac6cf}section{padding:16px;border:1px solid #bac6cf;margin:20px 0}form{margin:20px 0;padding:12px;background:#eef2f5}li{margin:8px}</style><h1>Specialist workspace</h1><p>Import and edit local package source. Imported programs remain unchecked until native construction and admission are available.</p>"+running+body+listing+
      form("Import","Package name "+input("draft")+" Local directory or ZIP "+input("path")+"<select name=format><option value=native>Native package</option><option value=original>Original specialist</option></select>")+
      form("Inspect","Package name "+input("draft"))+form("Open","Package name "+input("draft")+" File "+input("file"))+
      form("Migration","Original package name "+input("draft"))+"</html>"
    if(redirect.nonEmpty) {
      exchange.getResponseHeaders.set("Location","/?request="+redirect.get)
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
  def close():Unit=server.stop(0)
}
