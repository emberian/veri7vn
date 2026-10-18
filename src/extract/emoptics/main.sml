(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   kind, response, value) comes from the HOL kernel's Emoptics.reply_of; this
   file only frames it.

   Usage: emoptics [--specialist ID]
     ID is one of electrical, electronics, electronics-r2, wiring, optics,
     optics-v2, optics-v3, optics-v5, optics-v5-r2: only that manifest's organ
     is asked. Without it the whole family is asked in the recognizer's fixed
     order. Lane S04: copied from lane G's quantity/main.sml. The kernel writes
     the ohm sign and micro as the ASCII tokens @OHM@ and @MU@; this driver
     writes the UTF-8 symbols (U+03A9, U+00B5) the electronics scorer reads. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"kernel_exact_sound\",\"kernel_approx_sound\",\"kernel_reflect_sound\",\"kernel_underspecified\",\"kernel_impossible\",\"kernel_judgement\",\"stated_dec_sound\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: emoptics [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  (* replace every occurrence of pat in s by by *)
  fun subst (pat : string) (by : string) (s : string) : string =
    let
      val n = size pat
      fun go i acc =
        if i + n > size s then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (s, i, n) = pat then go (i + n) (by :: acc)
        else go (i + 1) (String.substring (s, i, 1) :: acc)
    in go 0 [] end
  fun symbols s = subst "@MU@" "\194\181" (subst "@OHM@" "\206\169" s)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Emoptics.reply_of request
          val kind = Emoptics.reply_kind r
          val value = case Emoptics.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Emoptics.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (symbols (Emoptics.response r))
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Emoptics.reply_of\", \"session\": \"Veri7vn_Emoptics\", \"theorems\": "
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
