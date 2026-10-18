(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   and the Regex matcher come from commons.sml (src/extract/commons). All
   reply content (status, response, value) comes from the HOL kernel's
   Wordprob.reply_checkeda (the generator spelling of reply_checked') over the untyped recognizer's request list; this file
   only frames it. The path is the head's own organ path for the word organ
   (fold w488): organ:math>word:<schema>. *)
structure Main =
struct
  val theorems = String.concatWith "," (map (fn s => "\"" ^ s ^ "\"")
    ["reply_answered_iff", "response_template", "printed_rounds_value", "printed_rounds_value_percent",
     "stated6_sound", "stated4_sound", "round_dec_error", "rl_round_dec_bound", "round_tie_up", "round_dec_tie_up", "money_round_tie_up",
     "money_tie_example", "negative_given_declines", "unsigned_given_unchanged", "checked_answered_iff",
     "round_sig_sound", "round_at_error", "percent_of_value", "simple_interest_value",
     "total_cost_value", "sale_off_value", "sale_pct_value",
     "motion_dist_value", "rect_area_value", "rect_perim_value", "circle_area_value",
     "circle_circ_value", "cyl_vol_value", "convert_roundtrip", "unit_price_guard", "unit_price_answered_guard", "unit_price_total_cost", "percent_of_total_sym", "percent_of_total_range", "motion_speed_dist", "cone_cyl_ratio", "sphere_four_cones", "cyl_base_height"])

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  fun reply (id : string) (q : string) : string =
    let
      val t0 = Time.now ()
      val (neg, (rnd, reqs)) = Recognizer.answer q
      val r = Wordprob.reply_checkeda neg (rnd, reqs)
      val schema = Wordprob.schema r
    in
      if Wordprob.answered r then
        "{\"id\": " ^ id ^ ", \"status\": \"answered\""
        ^ ", \"response\": " ^ Json.quote (Wordprob.response r)
        ^ ", \"path\": " ^ Json.quote ("organ:math>word:" ^ schema)
        ^ ", \"kind\": " ^ Json.quote schema
        ^ (case Wordprob.stated r of SOME v => ", \"value\": " ^ Json.quote v | NONE => "")
        ^ ", \"provenance\": {\"taken\": true, \"organ\": \"word_problems_v1\""
        ^ ", \"specialist_ms\": " ^ ms t0
        ^ ", \"kernel\": \"Wordprob.reply_checkeda\", \"session\": \"Veri7vn_Wordprob\", \"theorems\": ["
        ^ theorems ^ "]}}"
      else
        let val taken = not (null reqs)
        in
          "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": "
          ^ Json.quote (if taken then "organ:math>word:" ^ schema else "")
          ^ ", \"kind\": " ^ Json.quote schema
          ^ ", \"provenance\": {\"taken\": " ^ Bool.toString taken
          ^ ", \"organ\": \"word_problems_v1\", \"kernel\": \"Wordprob.reply_checkeda\""
          ^ ", \"specialist_ms\": " ^ ms t0 ^ "}}"
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
