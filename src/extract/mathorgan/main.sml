(* UNTRUSTED answerer-contract framing. Json comes from commons.sml.
   Answer content comes from the exported Mathkernel reply functions. *)
structure Main =
struct
  structure K = Mathkernel
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

  fun legacyReply (id : string) (q : string) : string =
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
    handle Recognizer.Reject reason =>
      "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": " ^ Json.quote reason
      ^ ", \"path\": \"mathorgan>unsupported_input\", \"provenance\": {\"taken\": true,"
      ^ "\"recognizer_rejection\": true, \"recognition_trusted\": false}}"

  fun affineReply id q (left,right) =
    let val l=AffineParser.kernel left
        val r=AffineParser.kernel right
        val result=K.affine_candidate l r
        val accepted=K.check_affine l r result
        fun rat q = AffineParser.ratJson(AffineParser.bounded(K.affine_rat_components q))
        fun pair (a,b) = "{\"coefficient\":" ^ rat a ^ ",\"constant\":" ^ rat b ^ "}"
        val (classification,root,value) = case result of
            K.AffineUnique x => ("unique",rat x,",\"value\":" ^ Json.quote(K.affine_exact x))
          | K.AffineAll => ("all","null","")
          | K.AffineNone => ("none","null","")
          | K.AffineUnsupported => ("unsupported","null","")
    in if not accepted then
      "{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"path\":\"mathorgan>unsupported_affine\",\"response\":" ^
      Json.quote(K.affine_response K.AffineUnsupported) ^
      ",\"provenance\":{\"taken\":true,\"recognition_trusted\":false,\"kernel\":\"Mathkernel.affine_candidate\"}}"
    else
      "{\"id\":" ^ id ^ ",\"status\":\"answered\",\"kind\":\"affine_equation\",\"path\":\"algebra:solved\",\"response\":" ^
      Json.quote(K.affine_response result) ^ value ^
      ",\"provenance\":{\"request_text\":" ^ Json.quote q ^ ",\"taken\":true,\"recognition_trusted\":false,\"kernel\":\"Mathkernel.check_affine\",\"session\":\"Veri7vn_MathOrgan\",\"evidence\":{\"checked_computation\":{" ^
      "\"schema_version\":1,\"kind\":\"affine_equation\",\"checker\":\"Mathkernel.check_affine\",\"accepted\":true," ^
      "\"assumptions\":[\"The typed equation represents the requested equation.\"]," ^
      "\"inputs\":{\"variable\":\"x\",\"left\":" ^ AffineParser.json left ^ ",\"right\":" ^ AffineParser.json right ^ "}," ^
      "\"result\":{\"classification\":" ^ Json.quote classification ^ ",\"root\":" ^ root ^
      ",\"left_affine\":" ^ pair(valOf(K.affine_norm l)) ^ ",\"right_affine\":" ^ pair(valOf(K.affine_norm r)) ^ "}}}}}"
    end

  fun closedReply id q expression =
    let val e=AffineParser.kernel expression
    in case K.closed_value e of
      NONE => "{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"path\":\"mathorgan>undefined_expression\",\"response\":\"This closed expression is undefined or outside the supported arithmetic grammar.\",\"provenance\":{\"taken\":true,\"recognition_trusted\":false,\"kernel\":\"Mathkernel.closed_value\"}}"
    | SOME value =>
      let val components=AffineParser.bounded(K.affine_rat_components value)
          val accepted=K.check_closed e value
          val _=if accepted then () else raise Fail "closed candidate failed its checker"
      in "{\"id\":" ^ id ^ ",\"status\":\"answered\",\"kind\":\"closed_expression\",\"path\":\"organ:math>evaluate\",\"response\":" ^
        Json.quote(K.closed_response value) ^ ",\"value\":" ^ Json.quote(K.affine_exact value) ^
        ",\"provenance\":{\"request_text\":" ^ Json.quote q ^ ",\"taken\":true,\"recognition_trusted\":false,\"kernel\":\"Mathkernel.check_closed\",\"session\":\"Veri7vn_MathOrgan\",\"evidence\":{\"checked_computation\":{" ^
        "\"schema_version\":1,\"kind\":\"closed_expression\",\"checker\":\"Mathkernel.check_closed\",\"accepted\":true," ^
        "\"assumptions\":[\"The typed expression represents the requested expression.\"]," ^
        "\"inputs\":{\"expression\":" ^ AffineParser.json expression ^ "},\"result\":" ^ AffineParser.ratJson components ^ "}}}}"
      end
    end

  fun reply id q =
    (case (if mode="family" orelse mode="algebra" then AffineParser.request q else NONE) of
        SOME equation => affineReply id q equation
      | NONE =>
        (case (if mode="family" orelse mode="closed" orelse mode="ops" then AffineParser.closedRequest q else NONE) of
            SOME expression => closedReply id q expression
          | NONE => legacyReply id q))
    handle AffineParser.Reject reason =>
      "{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"path\":\"mathorgan>unsupported_input\",\"response\":" ^
      Json.quote reason ^ ",\"provenance\":{\"taken\":true,\"recognizer_rejection\":true,\"recognition_trusted\":false}}"

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
