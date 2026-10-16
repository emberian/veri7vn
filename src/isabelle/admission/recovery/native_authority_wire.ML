(* Canonical inert AuthorityWire framing. No generated event/ledger carriers or
   native authority are exposed here. Fixed consumers convert this bounded AST
   into their own generated universe. *)
structure Veri7vn_Native_Authority_Wire =
struct
  datatype value=Atom of IntInf.int | Node of int * value list;
  datatype 'a shape=Natural of IntInf.int | Branch of IntInf.int * 'a list;
  val max_bytes=1048576;
  val max_nodes=65536;
  val max_depth=64;
  val max_digits=128;
  fun guard true _=()|guard false message=error message;
  fun read bytes=
    let val _=guard(size bytes<=max_bytes) "metadata byte limit"
      val position=Unsynchronized.ref 0
      val nodes=Unsynchronized.ref 0
      fun take n=
        let val _=guard(n>=0 andalso n<=size bytes- !position) "truncated metadata"
          val chunk=String.substring(bytes,!position,n)
          val _=position:= !position+n
        in chunk end
      fun u32()=
        let val n=fold(fn c=>fn v=>v*256+IntInf.fromInt(Char.ord c))
            (String.explode(take 4))(0:IntInf.int)
          val _=guard(n<=2147483647) "metadata integer bound"
        in IntInf.toInt n end
      fun loop depth=
        let val _=nodes:= !nodes+1
          val _=guard(depth<=max_depth andalso !nodes<=max_nodes) "metadata shape limit"
        in case Char.ord(String.sub(take 1,0))of
          0=>let val length=u32()
              val _=guard(length>0 andalso length<=max_digits) "metadata digit limit"
              val digits=take length
              val _=guard(forall(fn c=> #"0"<=c andalso c<= #"9")(String.explode digits) andalso
                (length=1 orelse String.sub(digits,0)<> #"0")) "noncanonical metadata natural"
            in Atom(the(IntInf.fromString digits))end
        |1=>let val tag=u32() val count=u32()
              val _=guard(count<=max_nodes- !nodes andalso count<=size bytes- !position) "metadata arity limit"
            in Node(tag,map(fn _=>loop(depth+1))(1 upto count))end
        |_=>error "unknown metadata frame tag"end
      val value=loop 1
      val _=guard(!position=size bytes) "trailing metadata bytes"
    in value end;
  (* The destructor is a fixed data conversion, not an authority callback. Bounds
     precede every recursive descent, including for generated carrier values. *)
  fun write_with shape value=
    let val total=Unsynchronized.ref 0
      val nodes=Unsynchronized.ref 0
      val chunks=Unsynchronized.ref([]:string list)
      fun add s=(guard(size s<=max_bytes- !total) "metadata byte limit";
        total:= !total+size s;chunks:=s:: !chunks)
      fun u32 n=(guard(n>=0 andalso n<=2147483647) "metadata integer bound";
        add(String.implode(map(fn divisor=>Char.chr((n div divisor)mod 256))[16777216,65536,256,1])))
      fun loop depth wire=
        (nodes:= !nodes+1;
         guard(depth<=max_depth andalso !nodes<=max_nodes) "metadata shape limit";
         case shape wire of Natural number=>
           let val _=guard(number>=0 andalso number<IntInf.pow(10,max_digits)) "metadata digit limit"
             val digits=IntInf.toString number
           in add(str(Char.chr 0));u32(size digits);add digits end
         |Branch(tag,children)=>
           (guard(tag>=0 andalso tag<=2147483647) "metadata integer bound";
            add(str(Char.chr 1));u32(IntInf.toInt tag);
            guard(length children<=max_nodes- !nodes) "metadata node limit";
            u32(length children);List.app(loop(depth+1))children))
      val _=loop 1 value
    in String.concat(rev(!chunks))end;
  val write=write_with(fn Atom number=>Natural number
    |Node(tag,children)=>Branch(IntInf.fromInt tag,children));
end;
