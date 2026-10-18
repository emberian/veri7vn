(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   kind, response, value) comes from the HOL kernel's Finance.reply_of; this
   file only frames it.

   Usage: finance [--specialist ID]
     ID is one of finance, finance-v2, finance-v2-r2, economics, retail: only
     that manifest's organ is asked. Without it the family is asked in the
     recognizer's fixed order. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"kernel_exact_sound\",\"kernel_cents_sound\",\"kernel_approx_sound\",\"kernel_underspecified\",\"kernel_impossible\",\"quant_sound\"]"

  (* Exact values come from the actual typed request and checked kernel result.
     The outer JSON serialization and its binding to the sentence are untrusted. *)
  fun rational x =
    let val (n, d) = Finance.rat_parts x
        fun decimal i = if i < 0 then "-" ^ IntInf.toString (~i) else IntInf.toString i
    in "{\"num\":" ^ Json.quote (decimal n) ^ ",\"den\":" ^ Json.quote (decimal d) ^ "}" end

  fun evidence request =
    case request of
      Finance.R_DiscountTax (price, discounts, tax) =>
        (case Finance.discount_tax_value request of
           NONE => ""
         | SOME result =>
           ", \"evidence\": {\"checked_computation\": {\"schema_version\":1,\"kind\":\"discount_tax\",\"inputs\":{\"price\":"
           ^ rational price ^ ",\"discounts_percent\":[" ^ String.concatWith "," (map rational discounts)
           ^ "],\"tax_rate\":" ^ rational tax ^ "},\"result\":" ^ rational result
           ^ ",\"checker\":\"Finance.check_discount_tax\",\"accepted\":"
           ^ Bool.toString (Finance.check_discount_tax price discounts tax result)
           ^ ",\"assumptions\":[\"English recognition supplied these exact inputs.\",\"Tax applies after every listed discount; discounts are percentages and tax_rate is a fraction.\"]}}")
    | _ => ""

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: finance [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Recognizer.replyOf request
          val kind = Finance.reply_kind r
          val value = case Finance.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Finance.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Finance.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Finance.reply_of\", \"session\": \"Veri7vn_Finance\", \"theorems\": "
          ^ theorems ^ evidence request ^ "}}"
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
