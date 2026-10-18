(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   response, value, path) comes from the HOL kernel's Mathkernel.reply_of; this
   file only frames it.

   Usage: mathorgan [--route ID]
     ID is one of algebra, ops, word, guards: only that route is asked.
     Without it the whole chain runs in its fixed order. *)
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
  val theorems = "[\"eval_closed_ignores_reading\",\"dec_expansion_sound\",\"isqrt_interval\",\"isqrt_unique\"," ^
    "\"isqrt_square\",\"newton_last_isqrt\",\"euc_res_gcd\",\"percent_value\",\"convert_exact\",\"convert_composes\"," ^
    "\"sqrt_of_square\",\"sqrt_value_is_interval\",\"gcd_value_divides\",\"lcm_value_identity\",\"solve_linear_sound\"," ^
    "\"solve_linear_complete\",\"solve_echo_iff\",\"eval_value_independent\",\"guard_P7_rule\",\"guard_G6_rule\"," ^
    "\"guard_G5_rule\",\"guard_english_rule\",\"reply_answered_iff\",\"reply_states_value\",\"reply_withheld_names_decline\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--route", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown route " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: mathorgan [--route ID]\n"); OS.Process.exit OS.Process.failure)

  (* the kind: the route segment of the path, as the harness reports it *)
  fun kindOf path =
    let
      fun afterPipe s = case String.fields (fn c => c = #"|") s of [_, r] => r | _ => s
      val p = afterPipe path
    in case rev (String.fields (fn c => c = #">") p) of
         k :: _ => k
       | [] => p
    end

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (route, request) =>
        let
          val r = Mathkernel.reply_of request
          val path = Mathkernel.path_lit r
          val value = case Mathkernel.value_lit r of
                        SOME v => ", \"value\": " ^ Json.quote v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Mathkernel.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Mathkernel.response r)
          ^ ", \"path\": " ^ Json.quote path
          ^ ", \"kind\": " ^ Json.quote (kindOf path) ^ value
          ^ ", \"provenance\": {\"taken\": true, \"route\": " ^ Json.quote route
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Mathkernel.reply_of\", \"session\": \"Veri7vn_MathOrgan\", \"theorems\": "
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
