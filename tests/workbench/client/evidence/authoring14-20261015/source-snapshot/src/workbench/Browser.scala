package veri7vn.workbench
import scala.language.unsafeNulls
import com.sun.net.httpserver.{HttpServer,HttpExchange}
import java.net.{InetSocketAddress,URLDecoder}
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Path
import java.util.UUID
import veri7vn.packages.intake.Intake

/** Loopback-only authoring surface sharing the CLI's actual managed operations. */
final class Browser(author:Authoring) extends AutoCloseable {
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
  server.createContext("/",(exchange:HttpExchange)=>{
    var body=""
    try {
      require(exchange.getRequestURI.getPath=="/","Unknown page")
      if(exchange.getRequestMethod=="POST") {
        require(exchange.getRequestHeaders.getFirst("Origin")==null || exchange.getRequestHeaders.getFirst("Origin")==url.stripSuffix("/"),"Foreign browser origin")
        val bytes=exchange.getRequestBody.readNBytes(2*1024*1024+1);require(bytes.length<=2*1024*1024,"Form too large")
        val p=fields(new String(bytes,UTF_8));require(p.get("token").contains(token),"Expired form")
        p("action") match {
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
            body="<p>"+escape(Authoring.resultMessage(result))+"</p>"+
              editor(p("draft"),p("file"),p("manifest"),p("revision"),p("original"),p("replacement"))
          case "Inspect"=>
            val s=author.inspect(p("draft"));body="<h2>"+escape(s.draft)+"</h2><ul>"+s.revision.entries.map(e=>"<li>"+escape(e.path)+" — "+e.content.size+" bytes</li>").mkString+"</ul>"
          case "Migration"=>body="<h2>Original specialist</h2>"+author.migration(p("draft")).diagnostics.map(d=>"<p>"+escape(d.path.getOrElse("Package")+": "+d.message)+"</p>").mkString
          case _=>throw new IllegalArgumentException("Unknown action")
        }
      }
    } catch {case e:Exception=>body="<p role=alert>"+escape(Option(e.getMessage).getOrElse(e.getClass.getSimpleName))+"</p>"}
    val listing=try "<h2>Packages</h2><ul>"+author.list().map(id=>"<li>"+escape(id)+"</li>").mkString+"</ul>"
      catch {case e:IllegalArgumentException=>"<p>"+escape(e.getMessage)+"</p>"}
    val html="<!doctype html><html><meta charset=utf-8><meta name=viewport content='width=device-width'><title>Specialist workspace</title><style>body{max-width:960px;margin:32px auto;padding:16px;font:16px system-ui}input,button,textarea{font:inherit;margin:5px;max-width:100%}textarea{box-sizing:border-box;width:100%}form{margin:20px 0;padding:12px;background:#eef2f5}li{margin:8px}</style><h1>Specialist workspace</h1><p>Import and edit local package source. Imported programs remain unchecked; running specialists is not connected here yet.</p>"+listing+body+
      form("Import","Package name "+input("draft")+" Local directory or ZIP "+input("path")+"<select name=format><option value=native>Native package</option><option value=original>Original specialist</option></select>")+
      form("Inspect","Package name "+input("draft"))+form("Open","Package name "+input("draft")+" File "+input("file"))+
      form("Migration","Original package name "+input("draft"))+"</html>"
    val bytes=html.getBytes(UTF_8);exchange.getResponseHeaders.set("Content-Type","text/html; charset=utf-8")
    exchange.getResponseHeaders.set("Cache-Control","no-store");exchange.getResponseHeaders.set("X-Content-Type-Options","nosniff")
    exchange.sendResponseHeaders(200,bytes.length);val out=exchange.getResponseBody;try out.write(bytes)finally out.close()
  })
  def url:String="http://127.0.0.1:"+server.getAddress.getPort+"/"
  def start():Unit=server.start()
  def close():Unit=server.stop(0)
}
