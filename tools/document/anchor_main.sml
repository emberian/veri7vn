(* UNTRUSTED JSON framing around the extracted Document_Anchors decision.
   Source authenticity and alias completeness are premises, not checked flags. *)
structure Json = struct
  datatype t = Null | Bool of bool | Num of IntInf.int | Str of string | Arr of t list | Obj of (string * t) list
  exception Bad of string

  fun utf8 (cp : int) : string =
    let fun ch n = String.str (Char.chr n) in
      if cp < 0x80 then ch cp
      else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
      else if cp < 0x10000 then ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
      else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64) ^ ch (0x80 + (cp div 64) mod 64)
           ^ ch (0x80 + cp mod 64)
    end

  fun parse (s : string) : t =
    let
      val n = String.size s
      fun peek i = if i < n then String.sub (s, i) else #"\000"
      fun ws i = if i < n andalso Char.isSpace (String.sub (s, i)) then ws (i + 1) else i
      fun expect (c, i) = if peek i = c then i + 1 else raise Bad ("expected " ^ String.str c)
      fun hex4 i =
        case (if i + 4 <= n then StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) else NONE)
          of SOME v => v | NONE => raise Bad "bad \\u escape"
      fun str (i, acc) =
        case peek i of
          #"\"" => (String.concat (rev acc), i + 1)
        | #"\\" =>
            (case peek (i + 1) of
               #"\"" => str (i + 2, "\"" :: acc) | #"\\" => str (i + 2, "\\" :: acc)
             | #"/" => str (i + 2, "/" :: acc) | #"b" => str (i + 2, "\b" :: acc)
             | #"f" => str (i + 2, "\012" :: acc) | #"n" => str (i + 2, "\n" :: acc)
             | #"r" => str (i + 2, "\r" :: acc) | #"t" => str (i + 2, "\t" :: acc)
             | #"u" =>
                 let val hi = hex4 (i + 2) in
                   if hi >= 0xD800 andalso hi < 0xDC00 andalso peek (i + 6) = #"\\" andalso peek (i + 7) = #"u"
                   then let val lo = hex4 (i + 8)
                        in str (i + 12, utf8 (0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)) :: acc) end
                   else str (i + 6, utf8 hi :: acc)
                 end
             | _ => raise Bad "bad escape")
        | #"\000" => raise Bad "unterminated string"
        | c => str (i + 1, String.str c :: acc)
      fun num i =
        let fun go j = if Char.isDigit (peek j) orelse (j = i andalso peek j = #"-") then go (j + 1) else j
            val j = go i
        in case IntInf.fromString (String.substring (s, i, j - i)) of
             SOME v => (Num v, j) | NONE => raise Bad "bad number"
        end
      fun value i =
        let val i = ws i in
          case peek i of
            #"{" => obj (ws (i + 1), [])
          | #"[" => arr (ws (i + 1), [])
          | #"\"" => let val (v, j) = str (i + 1, []) in (Str v, j) end
          | #"t" => if String.isPrefix "true" (String.extract (s, i, NONE)) then (Bool true, i + 4) else raise Bad "t"
          | #"f" => if String.isPrefix "false" (String.extract (s, i, NONE)) then (Bool false, i + 5) else raise Bad "f"
          | #"n" => if String.isPrefix "null" (String.extract (s, i, NONE)) then (Null, i + 4) else raise Bad "n"
          | _ => num i
        end
      and arr (i, acc) =
        if peek i = #"]" then (Arr (rev acc), i + 1)
        else let val (v, j) = value i val j = ws j in
          case peek j of #"," => arr (ws (j + 1), v :: acc) | #"]" => (Arr (rev (v :: acc)), j + 1)
                       | _ => raise Bad "array" end
      and obj (i, acc) =
        if peek i = #"}" then (Obj (rev acc), i + 1)
        else let val (k, j) = str (expect (#"\"", i), []) val j = expect (#":", ws j)
                 val (v, j) = value j val j = ws j in
          case peek j of #"," => obj (ws (j + 1), (k, v) :: acc) | #"}" => (Obj (rev ((k, v) :: acc)), j + 1)
                       | _ => raise Bad "object" end
      val (v, j) = value 0
    in if ws j = n then v else raise Bad "trailing input" end

  fun quote (s : string) : string =
    let fun esc c =
          case c of #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r" | #"\t" => "\\t"
          | c => if Char.ord c < 0x20 then "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
                 else String.str c
    in "\"" ^ String.translate esc s ^ "\"" end

  fun field (Obj kvs) k = (case List.find (fn (k', _) => k' = k) kvs of SOME (_, v) => v | NONE => Null)
    | field _ _ = Null
  fun bool v = case v of Bool b => b | _ => raise Bad "bool"
  fun int v = case v of Num i => i | _ => raise Bad "int"
  fun string v = case v of Str x => x | _ => raise Bad "string"
  fun list v = case v of Arr xs => xs | Null => [] | _ => raise Bad "list"
  fun show v =
    case v of Null => "null" | Bool b => (if b then "true" else "false") | Num i => IntInf.toString i
    | Str x => quote x | Arr xs => "[" ^ String.concatWith "," (map show xs) ^ "]"
    | Obj kvs => "{" ^ String.concatWith "," (map (fn (k, x) => quote k ^ ":" ^ show x) kvs) ^ "}"
end


structure Main = struct
  structure D = Document_Anchors_Code
  open Json
  fun hs s = map (fn ch => D.char_of_integer (IntInf.fromInt (Char.ord ch))) (String.explode s)
  fun sh cs = String.implode (map (fn c => Char.chr (IntInf.toInt (D.integer_of_char c))) cs)
  fun hstr v = hs (string v)
  fun kind v = case string v of "cause" => D.ECause | "process" => D.EProcess | "when" => D.EWhen | "discourse" => D.EDiscourse
    | _ => raise Bad "explanatory kind"
  fun request r = D.Explain_request_ext (kind (field r "kind"), hstr (field r "question"),
    hstr (field r "topic"), hstr (field r "prefix"), hstr (field r "article"),
    hstr (field r "verb"), hstr (field r "punctuation"), ())
  fun title r = D.Title_witness_ext (hstr (field r "alias"), hstr (field r "page_id"),
    hstr (field r "title"), ())
  fun row r = D.Sentence_witness_ext (hstr (field r "page_id"), hstr (field r "source_page_id"), hstr (field r "id"),
    hstr (field r "page"), hstr (field r "sentence"), ())
  fun handle_line line =
    let
      val input = parse line
      val req = request (field input "request")
      val aliases = map title (list (field input "aliases"))
      val rows = map row (list (field input "rows"))
      val out = D.anchored_decide req aliases rows
      val cites = map (fn c => Str (sh (D.claim_id c))) (D.anchored_cites out)
    in show (Obj [("id", field input "id"), ("status", Str (D.anchored_status out)),
      ("response", Str (sh (D.anchored_response req out))),
      ("path", Str (D.anchored_path (kind (field (field input "request") "kind")))),
      ("cites", Arr cites), ("provenance", Obj [
        ("taken", Bool (D.anchored_taken out)),
        ("kind", Str "veri7vn_document_anchors"),
        ("decision", Str "Document_Anchors.anchored_decide"),
        ("kernel_outcome", Str (D.anchored_reason out)),
        ("source_scope", field input "source_scope"),
        ("typed_request", field input "request"),
        ("supplied_aliases", field input "aliases"),
        ("evidence", Obj [("declaration", Str "Checked question shape, alias/page agreement and direct source clause; source truth and complete alias coverage remain assumptions"),
                          ("checks", Obj [("selected_citations", Arr cites)])])])]) end
    handle Bad msg => show (Obj [("error", Str msg)])
  fun loop () = case TextIO.inputLine TextIO.stdIn of NONE => () | SOME line =>
    (TextIO.output (TextIO.stdOut, handle_line line ^ "\n"); TextIO.flushOut TextIO.stdOut; loop ())
end
val _ = if Main.D.anchor_self_test then () else
  (TextIO.output (TextIO.stdErr, "document anchor self test failed\n"); OS.Process.exit OS.Process.failure)
val _ = Main.loop ()
