package veri7vn.sources
import scala.language.unsafeNulls
import java.io.{OutputStream,ByteArrayOutputStream,DataOutputStream}
import java.nio.file.{Path,Files,LinkOption}
import java.sql.{Connection,DriverManager,ResultSet}

/** External SQLite observation of a declared inert local file. This is not a
  * verified SQLite implementation or a proof of the SQL query's world coverage.
  * The emitted wire is consumed by the owned native source-row/2 decoder. */
object SqliteObservation {
  final case class Limits(maxColumns:Int=1024,maxCellBytes:Int=1000000,
    maxRowBytes:Int=2000000,maxRows:Long=1000000,maxWireBytes:Long=16000000) {
    require(maxColumns>=0 && maxColumns<=65536 && maxCellBytes>=0 && maxRowBytes>0 &&
      maxRows>=0 && maxWireBytes>=16)
  }
  final case class Column(name:String,declaredType:String,notNull:Boolean,primaryKeyPosition:Int,synthetic:Boolean=false)
  sealed trait Equality { def column:String }
  final case class IntegerEquals(column:String,value:Long) extends Equality
  final case class TextEquals(column:String,value:String) extends Equality
  final case class Report(engineVersion:String,driverVersion:String,databaseEncoding:String,
    sql:String,bindings:Vector[Equality],alternatives:Vector[Vector[Equality]],descending:Vector[String],limits:Limits,columns:Vector[Column],rows:Long,cursorEOF:Boolean,disposition:String) {
    /** Canonical inert extraction descriptor for the source manifest. EOF is
      * separately observed; these configured bounds never assert source coverage. */
    def selectionPolicy:String={
      def field(s:String)=s.length.toString+":"+s
      val bound=Vector(limits.maxColumns.toString,limits.maxCellBytes.toString,
        limits.maxRowBytes.toString,limits.maxRows.toString,limits.maxWireBytes.toString)
      "sqlite-selected-view/2"+field(sql)+bindings.size.toString+":"+
        bindings.map {
          case IntegerEquals(c,v)=>"I"+field(c)+field(v.toString)
          case TextEquals(c,v)=>"T"+field(c)+field(v)
        }.mkString+bound.map(field).mkString
    }
  }
  private def quote(s:String):String={require(s.nonEmpty && !s.contains('\u0000'));"\""+s.replace("\"","\"\"")+"\""}
  private def scalar(c:Connection,sql:String):String={
    val s=c.createStatement();try {val r=s.executeQuery(sql);try {require(r.next());r.getString(1)} finally r.close()} finally s.close()
  }
  private def bytesCell(out:DataOutputStream,tag:Int,b:Array[Byte],limit:Int):Unit={
    require(b!=null && b.length<=limit,"source.cell_budget_or_shape")
    out.writeByte(tag);out.writeInt(b.length);out.write(b)
  }
  private def row(r:ResultSet,count:Int,limits:Limits):Array[Byte]={
    val buffer=new ByteArrayOutputStream();val out=new DataOutputStream(buffer);out.writeByte(82)
    var i=0
    while(i<count){
      val kind=r.getString(i*3+1);val byteLength=r.getLong(i*3+2);val value=i*3+3
      require((kind!="text" && kind!="blob") || (byteLength>=0 && byteLength<=limits.maxCellBytes),"source.cell_budget")
      kind match {
        case "null"=>out.writeByte(0)
        case "integer"=>
          val n=BigInt(r.getLong(value));val raw=n.abs.toByteArray
          val magnitude=if(n==0)Array.emptyByteArray else if(raw(0)==0)raw.drop(1) else raw
          require(magnitude.length<=limits.maxCellBytes,"source.cell_budget")
          out.writeByte(1);out.writeByte(if(n<0)1 else 0);out.writeInt(magnitude.length);out.write(magnitude)
        case "real"=>require(limits.maxCellBytes>=8,"source.cell_budget");out.writeByte(4);out.writeLong(java.lang.Double.doubleToRawLongBits(r.getDouble(value)))
        case "text"=>bytesCell(out,2,r.getBytes(value),limits.maxCellBytes)
        case "blob"=>bytesCell(out,3,r.getBytes(value),limits.maxCellBytes)
        case _=>throw new IllegalArgumentException("source.unsupported_dynamic_class")
      }
      require(buffer.size()<=limits.maxRowBytes,"source.row_budget");i+=1
    }
    out.flush();buffer.toByteArray
  }
  /** `orderBy` is a declared extraction policy; no ordering is guessed from schema
    * names. Duplicate rows keep their separate ordered positions. */
  def observeLocal(path:Path,table:String,orderBy:Vector[String],output:OutputStream,
    limits:Limits=Limits(),includeRowid:Boolean=false,
    selection:Vector[Equality]=Vector.empty,
    alternatives:Vector[Vector[Equality]]=Vector.empty,descending:Vector[String]=Vector.empty):Report={
    require(Files.isRegularFile(path,LinkOption.NOFOLLOW_LINKS),"source must be an inert local regular file")
    require(alternatives.size<=64 && alternatives.forall(_.nonEmpty) &&
      selection.size.toLong+alternatives.foldLeft(0L)(_+_.size)<=limits.maxColumns,"source.selection_budget")
    val bindings=selection++alternatives.flatten
    require(bindings.foldLeft(0L) {case (n,TextEquals(_,v))=>n+Option(v).fold(0L)(_.length.toLong);case (n,_)=>n}<=limits.maxWireBytes/3,
      "source.selection_total_text_budget")
    require(bindings.forall {case TextEquals(_,v)=>v!=null && v.length<=limits.maxCellBytes && java.nio.charset.StandardCharsets.UTF_8.newEncoder().canEncode(v);case _=>true},"source.selection_text_budget")
    require(descending.distinct.size==descending.size && descending.forall(orderBy.contains),"source.order_direction")
    require(orderBy.nonEmpty && orderBy.size<=limits.maxColumns,"explicit bounded order policy required")
    Class.forName("org.sqlite.JDBC")
    val uri=path.toAbsolutePath.normalize().toUri.toASCIIString
    val c=DriverManager.getConnection("jdbc:sqlite:"+uri+"?mode=ro")
    try {
      val p=c.createStatement();try p.execute("PRAGMA query_only=ON") finally p.close()
      c.setAutoCommit(false)
      val engine=scalar(c,"SELECT sqlite_version()")
      val encoding=scalar(c,"PRAGMA encoding")
      require(encoding=="UTF-8","source.unsupported_database_encoding")
      val schema=c.createStatement()
      val columns=try {
        val r=schema.executeQuery("PRAGMA table_info("+quote(table)+")")
        val b=Vector.newBuilder[Column];var n=0
        try {while(r.next()){
          require(n<limits.maxColumns,"source.column_budget")
          b+=Column(r.getString("name"),Option(r.getString("type")).getOrElse(""),r.getInt("notnull")!=0,r.getInt("pk"));n+=1
        };b.result()} finally r.close()
      } finally schema.close()
      require(columns.nonEmpty,"source.table_unavailable")
      val rowidAlias=if(!includeRowid)None else
        Some(Vector("rowid","_rowid_","oid").find(a=> !columns.exists(_.name==a))
          .getOrElse(throw new IllegalArgumentException("source.hidden_rowid_shadowed")))
      rowidAlias.foreach { alias=>
        val check=c.createStatement()
        try {val r=check.executeQuery("SELECT "+alias+" FROM "+quote(table)+" LIMIT 0");r.close()} finally check.close()
      }
      require(orderBy.forall(n=>columns.exists(_.name==n) || rowidAlias.contains(n)),"source.unknown_order_column")
      require(bindings.forall(x=>columns.exists(_.name==x.column) || rowidAlias.contains(x.column)),"source.unknown_selection_column")
      val projected=rowidAlias.toVector.map(a=>(Column("sqlite-rowid:"+a,"INTEGER",true,0,true),a))++
        columns.map(x=>(x,quote(x.name)))
      require(projected.size<=limits.maxColumns,"source.column_budget")
      val select=projected.flatMap { case (_,q)=>
        Vector("typeof("+q+")","length(CAST("+q+" AS BLOB))",
          "CASE WHEN typeof("+q+")='text' THEN CAST("+q+" AS BLOB) ELSE "+q+" END")
      }.mkString(",")
      def columnSql(n:String)=if(rowidAlias.contains(n))n else quote(n)
      def conjunction(xs:Vector[Equality])=xs.map(x=>columnSql(x.column)+" = ?").mkString(" AND ")
      val clauses=selection.map(x=>columnSql(x.column)+" = ?")++
        (if(alternatives.isEmpty)Vector.empty else Vector(alternatives.map(xs=>"("+conjunction(xs)+")").mkString("("," OR ",")")))
      val where=if(clauses.isEmpty)"" else " WHERE "+clauses.mkString(" AND ")
      val sql="SELECT "+select+" FROM "+quote(table)+where+" ORDER BY "+
        orderBy.map(n=>columnSql(n)+(if(descending.contains(n))" DESC" else " ASC")).mkString(",")
      val s=c.prepareStatement(sql)
      bindings.zipWithIndex.foreach { case (binding,index)=>binding match {
        case IntegerEquals(_,v)=>s.setLong(index+1,v)
        case TextEquals(_,v)=>s.setString(index+1,v)
      }}
      var rows=0L;var wireBytes=6L;var eof=false;var disposition="source.complete_query_observation"
      val out=new DataOutputStream(output);out.writeByte(83);out.writeByte(50);out.writeInt(projected.size)
      try {
        val r=s.executeQuery()
        try {
          var continue=true
          while(continue){
            if(Thread.currentThread().isInterrupted){disposition="source.cancelled";continue=false}
            else if(!r.next()){eof=true;continue=false}
            else if(rows>=limits.maxRows){disposition="source.row_budget";continue=false}
            else {
              val encoded=try Some(row(r,projected.size,limits)) catch {
                case _:IllegalArgumentException=>disposition="source.cell_or_row_budget_or_shape";None
              }
              encoded match {
                case None=>continue=false
                case Some(b)=>
                  if(b.length.toLong>limits.maxWireBytes-wireBytes-10){disposition="source.wire_budget";continue=false}
                  else {out.write(b);wireBytes+=b.length;rows+=1}
              }
            }
          }
        } finally r.close()
      } finally s.close()
      out.writeByte(69);out.writeByte(if(eof)1 else 0);out.writeLong(rows);out.flush()
      Report(engine,c.getMetaData.getDriverVersion,encoding,sql,bindings,alternatives,descending,limits,projected.map(_._1),rows,eof,disposition)
    } finally {try c.rollback() finally c.close()}
  }
}
