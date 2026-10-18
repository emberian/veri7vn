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
  val theorems = "[\"text_answer_word_occurs\",\"checked_feature_narrows\",\"text_answer_first_row\",\"first_match\",\"no_rule_no_answer\",\"guard_exact\",\"answer_from_table\",\"organ_silent\",\"boundary_narrows\",\"family_first\",\"tables_well_formed\",\"projection_requires_source\",\"attribute_projection_exact\",\"source_attribute_lookup_sound\",\"source_attributes_unique\",\"branch_projection_exact\",\"language_field_bound\",\"language_family_rows\",\"transferred_exact\",\"exchange_reverse_disjoint\"]"

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

  fun jsReply id q t0 request =
    let
      fun withheld () = SOME ("{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"response\":\"\",\"path\":\"\",\"provenance\":{\"taken\":false,\"organ\":\"javascript\",\"silence\":\"unsupported_expression_or_request\"}}")
      fun answered value response kernel evidence = SOME (
        "{\"id\":" ^ id ^ ",\"status\":\"answered\",\"kind\":\"javascript\",\"value\":" ^ Json.quote value
        ^ ",\"response\":" ^ Json.quote response ^ ",\"path\":\"specialist:javascript>javascript\",\"provenance\":{\"taken\":true,\"organ\":\"javascript\",\"session\":\"Veri7vn_Facts\",\"kernel\":"
        ^ Json.quote kernel ^ ",\"computation\":" ^ Json.quote evidence ^ ",\"parser\":\"untrusted whole ASCII expression\",\"specialist_ms\":" ^ ms t0 ^ "}}")
    in case request of
      Javascript.NotJS => NONE
    | Javascript.Rejected => withheld ()
    | Javascript.Expression expression =>
        (case Facts.js_eval expression of NONE => withheld () | SOME value =>
          let val display = case value of Facts.JStr text => Json.quote text | _ => Facts.js_text value
              val (_,sourceExpression)=Javascript.frame q
          in answered display (sourceExpression ^ " evaluates to " ^ display ^ ".")
              "Facts.js_eval" "finite safe-integer primitive semantics; not full ECMAScript" end)
    | Javascript.TableRow row =>
        (case Facts.js_table_row (Facts.nat_of_integer(IntInf.fromInt row)) of NONE=>withheld()
         | SOME(value,sentence)=>answered (decode value) (decode sentence)
             "Facts.js_table_row" "exact whole-expression or static-fact source table")
    end

  fun reply (id : string) (q : string) : string =
    let
      val t0 = Time.now ()
      val js = case mode of
          SOME og => if Facts.organ_id og="javascript" then jsReply id q t0 (Javascript.request true q) else NONE
        | NONE => jsReply id q t0 (Javascript.request false q)
      val narr = Recognizer.narrative q
      val m = Recognizer.features q
      val textBytes = Facts.question_bytes (map (fn c => IntInf.fromInt (Char.ord c)) (String.explode q))
      val result =
        case mode of
          SOME og => (Facts.organ_id og, Facts.text_organ_reply narr textBytes m og)
        | NONE => (case Facts.text_family_reply narr textBytes m Facts.organs of
                     SOME r => r
                   | NONE => ("family", Facts.Silent Facts.No_rule))
    in
      case js of SOME rendered => rendered | NONE =>
      (case result of
        (organ, Facts.Silent why) =>
          "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
          ^ ", \"provenance\": {\"taken\": false, \"organ\": " ^ Json.quote organ
          ^ ", \"silence\": \"" ^ silence_name why ^ "\", \"specialist_ms\": " ^ ms t0 ^ "}}"
      | (organ, Facts.Answer (kind, value, sentence, store, row)) =>
          let val rowS = IntInf.toString (Facts.integer_of_nat row)
              val sourceSentence = decode sentence
              val sourceSubject = Recognizer.sourceSubject organ (IntInf.toInt (Facts.integer_of_nat row)) q
              val sourceScope = if organ="firesafety-v2" andalso Facts.integer_of_nat row>=2
                                   andalso Facts.integer_of_nat row<=11 then SOME "US fire classification" else NONE
              val baseResponse = case (sourceScope,sourceSubject) of
                  (SOME scope,_) => scope ^ ": " ^ sourceSentence
                | (_,SOME title) => title ^ ": " ^ sourceSentence
                | _ => sourceSentence
              val requestedProjection = Projection.requestFor organ q
              val projection = case requestedProjection of NONE=>NONE | SOME request=>
                (case Facts.projected_value request (Facts.Answer(kind,value,sentence,store,row)) of
                  NONE=>NONE | SOME projected=>SOME(request,projected))
              val (valueText,response,field) = case projection of
                  NONE => (decode value,baseResponse,"null")
                | SOME(request,projected) => (projected,(case request of Facts.LanguageBranch => sourceSentence | Facts.SourceAttribute _ => sourceSentence | _ => Projection.describe request projected),
                                              Json.quote(Projection.label request))
              val guardEvidence = case Facts.organ_by_id organ of
                  NONE => "null"
                | SOME og => (case Facts.answer_word_guard og row of
                    NONE => "{\"row_guard\":\"untrusted_regex\"}"
                  | SOME word => "{\"row_guard\":\"checked_ascii_literal\",\"literal\":" ^ Json.quote word ^ ",\"other_checks\":\"untrusted\"}")
          in
          if Option.isSome requestedProjection andalso not(Option.isSome projection) then
            "{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"response\":\"\",\"path\":\"\",\"provenance\":{\"taken\":false,\"organ\":"
            ^ Json.quote organ ^ ",\"silence\":\"unsupported_source_field\"}}"
          else
          "{\"id\": " ^ id ^ ", \"status\": \"answered\""
          ^ ", \"response\": " ^ Json.quote response
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind ^ ">" ^ store ^ "#" ^ rowS)
          ^ ", \"kind\": " ^ Json.quote kind ^ ", \"value\": " ^ Json.quote valueText
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"store\": " ^ Json.quote store ^ ", \"row\": " ^ rowS
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"recognition\": " ^ guardEvidence
          ^ ", \"projection\": " ^ field
          ^ ", \"source_sentence\": " ^ Json.quote sourceSentence
          ^ ", \"source_scope\": " ^ (case sourceScope of NONE=>"null" | SOME scope=>Json.quote scope)
          ^ ", \"source_subject\": " ^ (case sourceSubject of NONE => "null" | SOME title => Json.quote title)
          ^ ", \"kernel\": " ^ Json.quote (case projection of NONE=>"Facts.text_organ_reply" | SOME _=>"Facts.projected_value(Facts.text_organ_reply)")
          ^ ", \"session\": \"Veri7vn_Facts\", \"theorems\": "
          ^ theorems ^ "}}"
          end)
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
