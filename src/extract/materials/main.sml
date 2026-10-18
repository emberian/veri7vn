(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   kind, response, value) comes from the HOL kernel's Materials.reply_of; this
   file only frames it.

   Usage: materials [--specialist ID]
     ID is one of additive-v2, materials-v2, soil, soil-r2, water, water-r3: only that
     manifest's organ is asked. Without it the whole family is asked in the
     recognizer's fixed order. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"kernel_exact_sound\",\"kernel_approx_sound\",\"kernel_class_sound\",\"kernel_decline_iff\",\"stated_of_sound\",\"enclose_sound\"]"

  (* The selected request determines the additional model theorem; English recognition remains untrusted. *)
  fun supporting request =
    case request of
      Materials.HookeStress _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"hooke_stress_binding\"]"
    | Materials.MeshVertices _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"mesh_vertices_discrete\"]"
    | Materials.MeshEdges _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"mesh_edges_discrete\"]"
    | Materials.MeshFaces _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"mesh_faces_discrete\"]"
    | Materials.ScaleAmount (Materials.ScaleDivide, _, Materials.ScaleLength, _, _) => String.substring (theorems, 0, size theorems - 1) ^ ",\"scale_amount_binding\",\"scale_composes\",\"scale_divide_length\"]"
    | Materials.ScaleAmount (Materials.ScaleIncrease, _, Materials.ScaleLength, _, _) => String.substring (theorems, 0, size theorems - 1) ^ ",\"scale_amount_binding\",\"scale_composes\",\"scale_increase_length\"]"
    | Materials.ScaleAmount (Materials.ScaleDecrease, _, Materials.ScaleLength, _, _) => String.substring (theorems, 0, size theorems - 1) ^ ",\"scale_amount_binding\",\"scale_composes\",\"scale_decrease_length\"]"
    | Materials.ScaleAmount _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"scale_amount_binding\",\"scale_composes\"]"
    | Materials.HookeStrain _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"hooke_strain_balance\"]"
    | Materials.CtTime _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"ct_time_balance\"]"
    | Materials.CtConcentration _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"ct_concentration_balance\"]"
    | Materials.CtValue _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"ct_value\"]"
    | Materials.Dilution _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"dilution_balance\",\"dilution_volume_bounds\"]"
    | Materials.BulkDensity _ => String.substring (theorems, 0, size theorems - 1) ^ ",\"soil_bulk_density\"]"
    | _ => theorems

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: materials [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Materials.reply_of request
          val kind = Materials.reply_kind r
          val value = case Materials.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Materials.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Materials.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Materials.reply_of\", \"session\": \"Veri7vn_Materials\", \"theorems\": "
          ^ supporting request ^ "}}"
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
