(* UNTRUSTED. The replay driver for the precision-guard kernel. It reads one
   JSON request per line on stdin and writes one JSON reply per line on stdout,
   flushing after each, exiting on EOF. The JSON reader is lane D's (through
   lane G's and S12's).

   A request is one recorded core-panel item with the synthesized organ reply
   (see replay.py):
     {"id": 66,
      "q": "Name the painter of the Sistine Chapel ceiling",
      "route": "compose:bridge",            the organ reply's path
      "reply": "It was painted in 1512. ...", the organ reply the guard judged
      "human": null | true | false,          w516 S1's relstore answer
      "premise": null | {"label": "Mona Lisa", "year": 1950,
                         "years": [1503, 1519]}}   w532/w534 G3's relstore answer

   human and premise are recognizer-side inputs: they are facts read from the
   relation store, not from the text; the driver accepts them pre-read (the
   Python replay reads them from relations_v1.sqlite3). Everything else the
   recognizer computes from the raw text inside this binary.

   The reply carries the kernel's decision: which guard fires (code + fold
   layer) or none. All deciding is Guards.decision_auto; this file only frames.

   Usage: guards [--selftest] *)
structure Json =
struct
  exception Parse of string

  fun ws s i = if i < size s andalso Char.isSpace (String.sub (s, i)) then ws s (i + 1) else i

  fun utf8 (cp : int) : string =
    let fun ch x = String.str (Char.chr x)
    in if cp < 0x80 then ch cp
       else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
       else if cp < 0x10000 then
         ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
       else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64)
            ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
    end

  fun hex4 s i =
    case StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) of
      SOME v => v
    | NONE => raise Parse "bad \\u escape"

  fun str s i =
    let
      fun go j acc =
        if j >= size s then raise Parse "unterminated string"
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
                 let val hi = hex4 s (j + 2)
                 in if hi >= 0xD800 andalso hi < 0xDC00 andalso j + 11 < size s
                       andalso String.sub (s, j + 6) = #"\\" andalso String.sub (s, j + 7) = #"u"
                    then let val lo = hex4 s (j + 8)
                         in go (j + 12) (utf8 (0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)) :: acc) end
                    else go (j + 6) (utf8 hi :: acc)
                 end
             | _ => raise Parse "bad escape")
        | c => go (j + 1) (String.str c :: acc)
    in go (i + 1) [] end

  fun skip s i =
    let val i = ws s i
    in if i >= size s then raise Parse "unexpected end"
       else case String.sub (s, i) of
         #"\"" => #2 (str s i)
       | #"{" => members s (ws s (i + 1)) (fn _ => ())
       | #"[" =>
           let fun elems j =
                 let val j = ws s j
                 in if String.sub (s, j) = #"]" then j + 1
                    else let val k = ws s (skip s j)
                         in case String.sub (s, k) of
                              #"," => elems (k + 1)
                            | #"]" => k + 1
                            | _ => raise Parse "bad array"
                         end
                 end
           in elems (i + 1) end
       | _ =>
           let fun scalar j = if j < size s andalso not (Char.contains ",}] \t\r\n" (String.sub (s, j)))
                              then scalar (j + 1) else j
           in scalar i end
    end
  and members s i f =
    if String.sub (s, i) = #"}" then i + 1
    else
      let
        val (key, j) = str s (ws s i)
        val j = ws s j
        val _ = if String.sub (s, j) = #":" then () else raise Parse "expected :"
        val vstart = ws s (j + 1)
        val vend = skip s vstart
        val _ = f (key, vstart, vend)
        val k = ws s vend
      in
        case String.sub (s, k) of
          #"," => members s (ws s (k + 1)) f
        | #"}" => k + 1
        | _ => raise Parse "expected , or }"
      end

  fun fields (line : string) : (string * string) list =
    let
      val i = ws line 0
      val _ = if i < size line andalso String.sub (line, i) = #"{" then () else raise Parse "not an object"
      val acc = ref []
      val _ = members line (ws line (i + 1))
                (fn (k, a, b) => acc := (k, String.substring (line, a, b - a)) :: !acc)
    in rev (!acc) end

  fun stringValue raw =
    if size raw > 0 andalso String.sub (raw, 0) = #"\"" then #1 (str raw 0)
    else raise Parse "expected a string"

  fun intList raw =
    let val t = String.translate (fn c => if c = #"[" orelse c = #"]" orelse Char.isSpace c
                                          then "" else String.str c) raw
    in case t of "" => [] | _ => map (Option.valOf o Int.fromString) (String.tokens (fn c => c = #",") t) end

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
end

structure Main =
struct
  fun field fs k = Option.map #2 (List.find (fn (k', _) => k' = k) fs)

  fun fieldStr line fs k = Option.map Json.stringValue (field fs k)

  fun humanOf fs =
    case field fs "human" of
      NONE => NONE
    | SOME raw => if raw = "null" then NONE
                  else if raw = "true" then SOME true
                  else if raw = "false" then SOME false
                  else NONE

  fun premiseOf line fs =
    case field fs "premise" of
      NONE => NONE
    | SOME raw =>
        if raw = "null" then NONE
        else
          let val pfs = Json.fields raw
              fun digitsOf s = String.translate (fn c => if Char.isDigit c then String.str c else "") s
              val lab = Option.map Json.stringValue (field pfs "label")
              val yr = Option.mapPartial (Int.fromString o digitsOf) (field pfs "year")
              val yrs = Option.map Json.intList (field pfs "years")
          in case (lab, yr, yrs) of
               (SOME l, SOME y, SOME ys) => SOME (l, y, ys)
             | _ => NONE
          end

  fun reply (line : string) : string =
    let
      val fs = Json.fields line
      val id = case field fs "id" of SOME raw => raw | NONE => "null"
    in
      case (fieldStr line fs "q", fieldStr line fs "route", fieldStr line fs "reply") of
        (SOME q, SOME route, SOME rp) =>
          let
            val status = Option.getOpt (fieldStr line fs "status", "answered")
            val F = Recognizer.featsOf {status = status, q = q, route = route, reply = rp,
                                        human = humanOf fs, premise = premiseOf line fs}
          in
            case Guards.decision_auto F of
              NONE =>
                "{\"id\": " ^ id ^ ", \"status\": \"answered\", \"code\": null}"
            | SOME (L, c) =>
                "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"code\": "
                ^ Json.quote (Recognizer.kstr (Guards.code_name c))
                ^ ", \"layer\": " ^ Json.quote (Recognizer.kstr (Guards.layer_name L))
                ^ ", \"path\": " ^ Json.quote (Recognizer.kstr (Guards.withheld_path c F))
                ^ "}"
          end
      | _ => "{\"id\": " ^ id ^ ", \"error\": \"request needs q, route and reply\"}"
    end
    handle e => "{\"id\": null, \"error\": " ^ Json.quote (exnMessage e) ^ "}"

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME line =>
        (if List.all Char.isSpace (String.explode line) then ()
         else (TextIO.output (TextIO.stdOut, reply line ^ "\n"); TextIO.flushOut TextIO.stdOut);
         loop ())
end

val _ =
  case CommandLine.arguments () of
    ["--selftest"] =>
      (TextIO.output (TextIO.stdOut,
        "self_test=" ^ Bool.toString Guards.self_test ^ "\n");
       if Guards.self_test then () else OS.Process.exit OS.Process.failure)
  | [] => Main.loop ()
  | _ => (TextIO.output (TextIO.stdErr, "usage: guards [--selftest]\n");
          OS.Process.exit OS.Process.failure)
