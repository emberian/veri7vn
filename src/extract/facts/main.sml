(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md) for the
   FactsOrgan family: one JSON request per line on stdin, one JSON reply per
   line on stdout, flushed, exit on EOF. The JSON reader is lane D's via lane G
   (src/extract/quantity/main.sml). Status, kind, value, sentence and row come
   from the HOL kernel (Facts.organ_reply / Facts.family_reply); this file frames
   them and decodes the tables' 7-bit text escape (\uXXXX, \\) to UTF-8.

   Usage: facts [--specialist ID]   (ID one of the 22 manifests; without it the
   family is asked in Facts.organs order and the first organ that answers wins) *)
structure Json =
struct
  exception Parse of string

  (* Skip whitespace *)
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

  (* Parse a string starting at the opening quote; return (decoded, next index) *)
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

  (* Skip any JSON value; return the index after it *)
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
  (* Object members from index i (just after '{'); f receives (key, valueStart, valueEnd) *)
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

  (* The top-level object's fields as (key, raw value text) *)
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
  val theorems = "[\"first_match\",\"no_rule_no_answer\",\"guard_exact\",\"answer_from_table\",\"organ_silent\",\"boundary_narrows\",\"family_first\",\"tables_well_formed\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  (* the tables' text escape: \uXXXX is a code point, \\ a backslash *)
  fun decode (s : string) : string =
    let
      val n = size s
      fun go i acc =
        if i >= n then String.concat (rev acc)
        else if String.sub (s, i) = #"\\" andalso i + 1 < n andalso String.sub (s, i + 1) = #"\\"
        then go (i + 2) ("\\" :: acc)
        else if String.sub (s, i) = #"\\" andalso i + 5 < n andalso String.sub (s, i + 1) = #"u"
        then go (i + 6) (Json.utf8 (Json.hex4 s (i + 2)) :: acc)
        else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in go 0 [] end

  fun usage () = (TextIO.output (TextIO.stdErr, "usage: facts [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  val mode : Facts.organ option =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        (case Facts.organ_by_id id of
           SOME og => SOME og
         | NONE => (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure))
    | [] => NONE
    | _ => usage ()

  (* compile every pattern once, before the first question *)
  val _ = List.app (fn og => List.app (ignore o Recognizer.compiled) (Facts.organ_patterns og))
            (case mode of SOME og => [og] | NONE => Facts.organs)

  fun silence_name s =
    case s of
      Facts.Boundary => "boundary" | Facts.Narrative => "narrative" | Facts.Off_gate => "off_gate"
    | Facts.Blocked => "blocked" | Facts.Not_asked => "not_asked" | Facts.No_rule => "no_rule"

  fun reply (id : string) (q : string) : string =
    let
      val t0 = Time.now ()
      val narr = Recognizer.narrative q
      val m = Recognizer.features q
      val result =
        case mode of
          SOME og => (Facts.organ_id og, Facts.organ_reply narr m og)
        | NONE => (case Facts.family_reply narr m Facts.organs of
                     SOME r => r
                   | NONE => ("family", Facts.Silent Facts.No_rule))
    in
      case result of
        (organ, Facts.Silent why) =>
          "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
          ^ ", \"provenance\": {\"taken\": false, \"organ\": " ^ Json.quote organ
          ^ ", \"silence\": \"" ^ silence_name why ^ "\", \"specialist_ms\": " ^ ms t0 ^ "}}"
      | (organ, Facts.Answer (kind, value, sentence, store, row)) =>
          let val rowS = IntInf.toString (Facts.integer_of_nat row)
          in
          "{\"id\": " ^ id ^ ", \"status\": \"answered\""
          ^ ", \"response\": " ^ Json.quote (decode sentence)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind ^ ">" ^ store ^ "#" ^ rowS)
          ^ ", \"kind\": " ^ Json.quote kind ^ ", \"value\": " ^ Json.quote (decode value)
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"store\": " ^ Json.quote store ^ ", \"row\": " ^ rowS
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Facts.organ_reply\", \"session\": \"Veri7vn_Facts\", \"theorems\": "
          ^ theorems ^ "}}"
          end
    end

  fun handle_line (line : string) : string =
    let
      val fs = Json.fields line
      val id = case List.find (fn (k, _) => k = "id") fs of SOME (_, raw) => raw | NONE => "null"
    in
      (case List.find (fn (k, _) => k = "q") fs of
         SOME (_, raw) => reply id (Json.stringValue raw)
       | NONE => "{\"id\": " ^ id ^ ", \"error\": \"request has no q\"}")
      handle e => "{\"id\": " ^ id ^ ", \"error\": " ^ Json.quote (exnMessage e) ^ "}"
    end
    handle e => "{\"id\": null, \"error\": " ^ Json.quote (exnMessage e) ^ "}"

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME line =>
        (if List.all Char.isSpace (String.explode line) then ()
         else (TextIO.output (TextIO.stdOut, handle_line line ^ "\n"); TextIO.flushOut TextIO.stdOut);
         loop ())
end

val _ = Main.loop ()
