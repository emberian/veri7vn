(* Physical labels are part of input identity. Binary and native-term bytes are
   never decoded as source text; UTF-8 uses RFC 3629 scalar-value encoding. *)
structure Veri7vn_Native_Recovery_Encoding =
struct
  fun utf8 bytes=
    let val count=size bytes
      fun at i=Char.ord(String.sub(bytes,i))
      fun between low high value=low<=value andalso value<=high
      fun following i low high=i<count andalso between low high(at i)
      fun continuation i=following i 128 191
      fun scan i=if i=count then true else
        let val first=at i
        in if first<=127 then scan(i+1)
          else if between 194 223 first then continuation(i+1) andalso scan(i+2)
          else if between 224 239 first then
            following(i+1)(if first=224 then 160 else 128)(if first=237 then 159 else 191) andalso
            continuation(i+2) andalso scan(i+3)
          else if between 240 244 first then
            following(i+1)(if first=240 then 144 else 128)(if first=244 then 143 else 191) andalso
            continuation(i+2) andalso continuation(i+3) andalso scan(i+4)
          else false end
    in scan 0 end;
  fun valid "UTF-8" bytes=utf8 bytes
    |valid "binary" _=true
    |valid "native-term/1" _=true
    |valid _ _=false;
end;
