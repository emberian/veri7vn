(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The Regex
   matcher and the JSON reader/writer come from commons.sml
   (src/extract/commons). All reply content (status,
   kind, response, value) comes from the HOL kernel's Quantity.reply_of; this
   file frames it and attaches optional untrusted typed-request unit metadata.
   Temperature roles are deliberately not scalar anchors (see output_unit).

   Usage: quantity [--specialist ID]
     ID is one of densities, units, units-v3, springs, fluids, fuels: only that
     manifest's organ is asked. Without it the whole family is asked in the
     recognizer's fixed order. *)

structure Main =
struct
  val theorems = "[\"kernel_exact_sound\",\"kernel_approx_sound\",\"kernel_underspecified\",\"kernel_mismatch\",\"kernel_impossible\",\"stated_dec_sound\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: quantity [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  (* UNTRUSTED metadata adapter, not a new kernel theorem. Target units come
     from typed requests and HOL unit labels, never from rendered answer text.
     Fixed N, N/m and Hz name the existing kernel's SI output conventions; they
     are not qunit constructors. Every request constructor is explicit here.
     Native-v1 anchors carry a unit string but no affine point/difference role,
     so both temperature forms intentionally omit an anchor, including kelvin. *)
  fun output_unit request =
    case request of
      Quantity.Density _ => SOME (Quantity.unit_label Quantity.U_kilogram ^ "/" ^ Quantity.unit_label Quantity.U_cubic_metre)
    | Quantity.MassOf (_, _, u) => SOME (Quantity.unit_label u)
    | Quantity.VolumeOf (_, _, u) => SOME (Quantity.unit_label u)
    | Quantity.Floats _ => NONE
    | Quantity.Convert (_, Quantity.Lin _, Quantity.Lin u) => SOME (Quantity.unit_label u)
    | Quantity.Convert _ => NONE
    | Quantity.ConvertDelta _ => NONE
    | Quantity.SpringForce _ => SOME "N"
    | Quantity.SpringExtension _ => SOME (Quantity.unit_label Quantity.U_metre)
    | Quantity.SpringConstant _ => SOME ("N/" ^ Quantity.unit_label Quantity.U_metre)
    | Quantity.SpringEnergy _ => SOME (Quantity.unit_label Quantity.U_joule)
    | Quantity.SpringPeriod _ => SOME (Quantity.unit_label Quantity.U_second)
    | Quantity.SpringFrequency _ => SOME "Hz"
    | Quantity.PressureGauge _ => SOME (Quantity.unit_label Quantity.U_pascal)
    | Quantity.PressureAbs _ => SOME (Quantity.unit_label Quantity.U_pascal)
    | Quantity.Buoyant _ => SOME "N"
    | Quantity.Submerged _ => SOME "1"
    | Quantity.FuelEnergy (_, _, u) => SOME (Quantity.unit_label u)
    | Quantity.FuelCO2 _ => SOME (Quantity.unit_label Quantity.U_kilogram)
    | Quantity.FuelMassNeeded _ => SOME (Quantity.unit_label Quantity.U_kilogram)
    | Quantity.FuelNCV _ => SOME (Quantity.unit_label Quantity.U_megajoule ^ "/" ^ Quantity.unit_label Quantity.U_kilogram)
    | Quantity.Hydrostatic _ => SOME (Quantity.unit_label Quantity.U_pascal)
    | Quantity.FuelUsefulEnergy (_, _, u, _) => SOME (Quantity.unit_label u)
    | Quantity.FuelUsefulMass _ => SOME (Quantity.unit_label Quantity.U_kilogram)
    | Quantity.UnsupportedCondition _ => NONE

  fun unit_field request r =
    case (Quantity.answered r, Quantity.stated r, output_unit request) of
      (true, SOME _, SOME unit) => ", \"unit\": " ^ Json.quote unit
    | _ => ""

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Quantity.reply_of request
          val kind = Quantity.reply_kind r
          val unit = unit_field request r
          val value = case Quantity.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Quantity.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Quantity.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value ^ unit
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Quantity.reply_of\", \"session\": \"Veri7vn_Quantity\", \"theorems\": "
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
