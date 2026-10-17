(* UNTRUSTED. A small JSON reader and writer for the stores driver: the
   answerer-contract requests and replies, and the fetch shim's row replies.
   String decoding (escapes, \u with surrogate pairs to UTF-8) follows lane D's
   src/extract/acoustics/main.sml as copied by lane G. Numbers are kept as their
   source text, so a store value "28.3495" reaches the kernel as the exact
   fraction 283495/10000. *)
structure Js =
struct
  datatype v = Null | Bool of bool | Num of string | Str of string | Arr of v list | Obj of (string * v) list

  exception Parse of string

  fun utf8 (cp : int) : string =
    let fun ch x = String.str (Char.chr x)
    in if cp < 0x80 then ch cp
       else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
       else if cp < 0x10000 then
         ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
       else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64)
            ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
    end

  fun parse (s : string) : v =
    let
      val n = size s
      fun ws i = if i < n andalso Char.isSpace (String.sub (s, i)) then ws (i + 1) else i
      fun hex4 i =
        case StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) of
          SOME v => v
        | NONE => raise Parse "bad \\u escape"
      fun str i =
        let
          fun go j acc =
            if j >= n then raise Parse "unterminated string"
            else case String.sub (s, j) of
              #"\"" => (String.concat (rev acc), j + 1)
            | #"\\" =>
                (case String.sub (s, j + 1) of
                   #"\"" => go (j + 2) ("\"" :: acc)
                 | #"\\" => go (j + 2) ("\\" :: acc)
                 | #"/" => go (j + 2) ("/" :: acc)
                 | #"b" => go (j + 2) ("\b" :: acc)
                 | #"f" => go (j + 2) ("\f" :: acc)
                 | #"n" => go (j + 2) ("\n" :: acc)
                 | #"r" => go (j + 2) ("\r" :: acc)
                 | #"t" => go (j + 2) ("\t" :: acc)
                 | #"u" =>
                     let val hi = hex4 (j + 2)
                     in if hi >= 0xD800 andalso hi < 0xDC00 andalso j + 11 < n
                           andalso String.sub (s, j + 6) = #"\\" andalso String.sub (s, j + 7) = #"u"
                        then go (j + 12) (utf8 (0x10000 + (hi - 0xD800) * 1024 + (hex4 (j + 8) - 0xDC00)) :: acc)
                        else go (j + 6) (utf8 hi :: acc)
                     end
                 | _ => raise Parse "bad escape")
            | c => go (j + 1) (String.str c :: acc)
        in go (i + 1) [] end
      fun value i =
        let val i = ws i
        in if i >= n then raise Parse "unexpected end"
           else case String.sub (s, i) of
             #"\"" => let val (x, j) = str i in (Str x, j) end
           | #"{" =>
               let
                 fun mem j acc =
                   let val j = ws j
                   in if String.sub (s, j) = #"}" then (Obj (rev acc), j + 1)
                      else
                        let
                          val (k, j) = str (ws j)
                          val j = ws j
                          val _ = if String.sub (s, j) = #":" then () else raise Parse "expected :"
                          val (x, j) = value (j + 1)
                          val j = ws j
                        in case String.sub (s, j) of
                             #"," => mem (j + 1) ((k, x) :: acc)
                           | #"}" => (Obj (rev ((k, x) :: acc)), j + 1)
                           | _ => raise Parse "expected , or }"
                        end
                   end
               in mem (i + 1) [] end
           | #"[" =>
               let
                 fun el j acc =
                   let val j = ws j
                   in if String.sub (s, j) = #"]" then (Arr (rev acc), j + 1)
                      else
                        let val (x, j) = value j
                            val j = ws j
                        in case String.sub (s, j) of
                             #"," => el (j + 1) (x :: acc)
                           | #"]" => (Arr (rev (x :: acc)), j + 1)
                           | _ => raise Parse "expected , or ]"
                        end
                   end
               in el (i + 1) [] end
           | #"t" => (Bool true, i + 4)
           | #"f" => (Bool false, i + 5)
           | #"n" => (Null, i + 4)
           | _ =>
               let fun sc j = if j < n andalso not (Char.contains ",}] \t\r\n" (String.sub (s, j))) then sc (j + 1) else j
                   val j = sc i
               in (Num (String.substring (s, i, j - i)), j) end
        end
    in #1 (value 0) end

  fun field (Obj kvs) k = (case List.find (fn (k', _) => k' = k) kvs of SOME (_, x) => x | NONE => Null)
    | field _ _ = Null

  fun str (Str s) = s
    | str (Num s) = s
    | str _ = raise Parse "expected a string"

  fun arr (Arr xs) = xs
    | arr Null = []
    | arr _ = raise Parse "expected an array"

  fun int (Num s) = valOf (IntInf.fromString s)
    | int (Str s) = valOf (IntInf.fromString s)
    | int _ = raise Parse "expected an integer"

  fun bool (Bool b) = b
    | bool _ = false

  fun quote (s : string) : string =
    let
      fun esc c =
        case c of
          #"\"" => "\\\""
        | #"\\" => "\\\\"
        | #"\n" => "\\n"
        | #"\r" => "\\r"
        | #"\t" => "\\t"
        | c => if Char.ord c < 0x20 then
                 "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
               else String.str c
    in "\"" ^ String.translate esc s ^ "\"" end

  fun write (x : v) : string =
    case x of
      Null => "null"
    | Bool b => if b then "true" else "false"
    | Num s => s
    | Str s => quote s
    | Arr xs => "[" ^ String.concatWith ", " (map write xs) ^ "]"
    | Obj kvs => "{" ^ String.concatWith ", " (map (fn (k, y) => quote k ^ ": " ^ write y) kvs) ^ "}"
end
