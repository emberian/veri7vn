(* Native token source_of is compact Symbol.DEL-padded inner input, not the
   original lexical bytes. Derive spans only from native symbol positions and
   the retained original byte string; never unparse or normalize source text. *)
signature VERI7VN_NATIVE_SOURCE_TOKENS =
sig
  type located = {token:Token.T,start:int,stop:int}
  val tokenize: Keyword.keywords -> string -> located list
end;
structure Veri7vn_Native_Source_Tokens :> VERI7VN_NATIVE_SOURCE_TOKENS =
struct
  type located = {token:Token.T,start:int,stop:int};
  fun tokenize keywords original =
    let
      val symbols=Symbol.explode original;
      (* Symbol.explode normalizes CR/CRLF and legacy encoded ASCII control
         bytes. Count their ORIGINAL lengths, then verify every native symbol
         against the exact consumed raw slice. UTF-8 and named Isabelle symbols
         otherwise retain their original source bytes. *)
      fun raw_length offset symbol =
        let
          val n=size original;
          fun byte i=Char.ord(String.sub(original,i));
          val count=if offset<n andalso byte offset=13 then
              if offset+1<n andalso byte(offset+1)=10 then 2 else 1
            else if offset+1<n andalso byte offset=192 andalso
                byte(offset+1)>=128 andalso byte(offset+1)<160 andalso
                (offset+2>=n orelse byte(offset+2)<128) then 2
            else size symbol;
          val _=if count>0 andalso offset+count<=n andalso
            Symbol.explode(String.substring(original,offset,count))=[symbol] then ()
            else error "Native symbol positions do not match original source bytes";
        in count end;
      fun prefixes [] offset found=
            if offset=size original then Vector.fromList(rev(offset::found))
            else error "Native symbols omit original source bytes"
        | prefixes (symbol::rest) offset found=
            prefixes rest (offset+raw_length offset symbol) (offset::found);
      val bytes=prefixes symbols 0 [];
      fun byte_position position =
        (case Position.offset_of position of SOME n =>
          if n>=1 andalso n<=Vector.length bytes then Vector.sub(bytes,n-1)
          else error "Native token position outside original source"
        | NONE=>error "Native token has no original source position");
      val located=map (fn token=>{token=token,start=byte_position(Token.pos_of token),
        stop=byte_position(#2(Token.range_of [token]))})
        (Token.explode keywords Position.start original);
      val final=fold (fn {start,stop,...}:located => fn previous=>
        if start=previous andalso stop>=start then stop
        else error "Native token ranges do not cover exact original source") located 0;
      val _=if final=size original then ()
        else error "Native tokens omit original source bytes";
      val reconstructed=implode(map (fn {start,stop,...}:located =>
        String.substring(original,start,stop-start)) located);
      val _=if reconstructed=original then ()
        else error "Native token slices do not preserve original source bytes";
    in located end;
end;
