(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml), through lane G's. All reply
   content (status, kind, response, value) comes from the HOL kernel's
   Discrete.reply_of; this file only frames it.

   Usage: discrete [--specialist ID]
     ID is one of games-v3, logic-v3, dataformats, algorithms, calculus: only
     that manifest's organ is asked. Without it the whole family is asked in
     the recognizer's fixed order. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"anagram_equation\",\"atleast_value\",\"atleast_range\",\"card_k_ordered\",\"card_k_too_many\",\"dist_ways\",\"sum_dist\",\"classify_taut\",\"argument_valid\",\"l_formula_table_bound\",\"l_argument_table_bound\",\"sp_found_sound\",\"a_mst_minimal\",\"a_sorted_sound\",\"bsearch_found\",\"isort_correct\",\"pder_n_derivative\",\"c_partial_sound\",\"c_partial_at_sound\",\"pint_derivative\",\"from_to_digits\",\"f_signed_base_sound\",\"b64_roundtrip\",\"pct_roundtrip\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: discrete [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun bytesOf (l : Discrete.nat list) : string =
    String.implode (map (fn n => Char.chr (IntInf.toInt (Discrete.integer_of_nat n))) l)

  fun pieceText (p : Discrete.piece) : string =
    case Discrete.piece_lit p of
      SOME s => s
    | NONE => bytesOf (Discrete.piece_raw p)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Discrete.reply_of request
          val kind = Discrete.reply_kind r
          val text = String.concat (map pieceText (Discrete.response r))
          val value = case Discrete.stated r of
                        Discrete.JNone => ""
                      | Discrete.JRaw v => ", \"value\": " ^ v
                      | Discrete.JStr l => ", \"value\": " ^ Json.quote (bytesOf l)
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Discrete.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote text
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Discrete.reply_of\", \"session\": \"Veri7vn_Discrete\", \"theorems\": "
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
