package veri7vn.packages.lifecycle
import isabelle.JSON
import scala.language.unsafeNulls
import veri7vn.packages.intake.Intake.Content

/** Bounded inert JSON data parsing. Does not interpret executable/scorer/HOL semantics. */
object InertJSON {
  private object StrictJSON extends JSON.Parsers {
    override def json_object: Parser[JSON.Object.T] =
      $$$("{") ~> repsep(string ~ ($$$(":") ~> json_value) ^^ {case a ~ b => (a,b)},$$$(",")) <~ $$$("}") ^^ { entries =>
        require(entries.map(_._1).distinct.size==entries.size,"Duplicate JSON object key")
        entries.toMap
      }
  }
  def parse(content: Content,maxBytes:Int=256*1024,maxDepth:Int=32,maxTokens:Int=32768):Any = {
    require(maxBytes>0 && maxBytes<=8*1024*1024 && maxDepth>0 && maxDepth<=64 && maxTokens>0 && maxTokens<=262144)
    require(content.size<=maxBytes,"JSON byte limit")
    val decoder=java.nio.charset.StandardCharsets.UTF_8.newDecoder()
      .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
      .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
    val text=try decoder.decode(java.nio.ByteBuffer.wrap(content.bytes)).toString
      catch {case e:java.nio.charset.CharacterCodingException=>throw new IllegalArgumentException("Malformed UTF-8 JSON",e)}
    val scanner=new JSON.Lexer.Scanner(isabelle.Scan.char_reader(text))
    var tokens:scala.util.parsing.input.Reader[JSON.Token]=scanner;var depth=0;var count=0
    while(!tokens.atEnd) {
      val t=tokens.first;count+=1
      if(t.is_keyword("{") || t.is_keyword("[")) depth+=1
      if(t.is_keyword("}") || t.is_keyword("]")) depth-=1
      require(depth<=maxDepth && count<=maxTokens,"JSON nesting/token limit")
      tokens=tokens.rest
    }
    try StrictJSON.parse(text,true)
    catch {case isabelle.ERROR(_) => throw new IllegalArgumentException("Malformed JSON")}
  }
  def objectValue(value: Any): Map[String,Any] = value match {
    case m: Map[?,?] if m.keys.forall(_.isInstanceOf[String]) => m.asInstanceOf[Map[String,Any]]
    case _ => throw new IllegalArgumentException("Expected JSON object")
  }
}
