(* Scalar-value UTF-8 validation only: no decoding, replacement or normalization.
   Every byte of the original source is retained exactly. *)
structure Veri7vn_Search_UTF8 :>
sig val valid: string -> bool end =
struct
  fun valid bytes =
    let val length=size bytes;
      fun at i=if i<length then Char.ord(String.sub(bytes,i)) else ~1;
      fun between lo hi b=lo<=b andalso b<=hi;
      fun continuation i=between 128 191 (at i);
      fun scan i=if i=length then true else
        let val b=at i in
          if between 0 127 b then scan(i+1)
          else if between 194 223 b then continuation(i+1) andalso scan(i+2)
          else if b=224 then between 160 191(at(i+1)) andalso continuation(i+2) andalso scan(i+3)
          else if between 225 236 b orelse between 238 239 b then
            continuation(i+1) andalso continuation(i+2) andalso scan(i+3)
          else if b=237 then between 128 159(at(i+1)) andalso continuation(i+2) andalso scan(i+3)
          else if b=240 then between 144 191(at(i+1)) andalso
            continuation(i+2) andalso continuation(i+3) andalso scan(i+4)
          else if between 241 243 b then continuation(i+1) andalso
            continuation(i+2) andalso continuation(i+3) andalso scan(i+4)
          else if b=244 then between 128 143(at(i+1)) andalso
            continuation(i+2) andalso continuation(i+3) andalso scan(i+4)
          else false
        end;
    in scan 0 end;
end;
