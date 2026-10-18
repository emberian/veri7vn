(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md) for the
   FactsOrgan family: one JSON request per line on stdin, one JSON reply per
   line on stdout, flushed, exit on EOF. The JSON reader is lane D's via lane G
   (src/extract/quantity/main.sml). Status, kind, value, sentence and row come
   from the HOL kernel (Facts.organ_reply / Facts.family_reply); this file frames
   them and decodes the tables' 7-bit text escape (\uXXXX, \\) to UTF-8.

   Usage: facts [--specialist ID]   (ID one of the 22 manifests; without it the
   family is asked in Facts.organs order and the first organ that answers wins) *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

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
