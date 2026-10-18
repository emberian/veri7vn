(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   kind, response, value) comes from the HOL kernel's Chemistry.reply_of; this
   file only frames it.

   Usage: chemistry [--specialist ID]
     ID is one of chemistry, chemistry-v3, decay, labsolutions, labsolutions-r2: only that
     manifest's organ is asked. Without it the whole family is asked in the
     recognizer's fixed order. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"reply_of_measured_net_value\",\"measured_net_conservation_certificate\",\"mass_inventory_conserves_grams\",\"amount_conversion_conserves_quantity\",\"reply_of_solution_value\",\"directed_stock_conserves_solute\",\"directed_stock_unique\",\"solvent_volume_conservation\",\"solution_amount_conservation\",\"solution_molarity_conservation\",\"solution_dilution_conservation\",\"mass_solution_conservation\",\"zero_stock_zero_final\",\"measured_molar_mass_value\",\"measured_solution_mass_value\",\"measured_molarity_value\",\"measured_moles_value\",\"reply_of_measured_mass\",\"measured_remaining_answered\",\"measured_decay_time_answered\",\"convert_mass_conserves_grams\",\"molar_mass_value\",\"grams_to_moles_value\",\"percent_value\",\"property_value\",\"mass_needed_value\",\"dilution_value\",\"remaining_amount_value\",\"time_to_fraction_value\",\"ndec_sound\",\"reply_of_net_reaction_certificate\",\"checked_net_conservation\",\"checked_net_inventory_conservation\",\"checked_net_limiting_extent\",\"spectator_does_not_limit\",\"reply_of_reaction_certificate\",\"balanced_reaction_conserves_every_element\",\"reaction_extent_greatest\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: chemistry [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Chemistry.reply_of request
          val kind = Chemistry.reply_kind r
          val value = case Chemistry.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Chemistry.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Chemistry.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Chemistry.reply_of\", \"session\": \"Veri7vn_Chemistry\", \"theorems\": "
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
