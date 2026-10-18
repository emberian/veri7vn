(* UNTRUSTED JSON framing for the exported finite conversation policy. *)
structure Main = struct
  structure K = Converse
  fun raw fs key = case List.find (fn (k,_) => k=key) fs of SOME (_,v) => v | NONE => "null"
  fun text fs key = Json.stringValue(raw fs key)
  fun kind "person" = K.Person | kind "thing" = K.Thing | kind "unknown" = K.Unknown
    | kind _ = raise Fail "unknown entity kind"
  fun entity "null" = NONE
    | entity s = let val fs=Json.fields s in SOME(K.Entity(text fs "qid",kind(text fs "entity_kind"))) end
  fun reference "person" = K.Person_ref | reference "thing" = K.Thing_ref
    | reference "answer_thing" = K.Answer_thing_ref | reference "subject" = K.Subject_ref
    | reference "number" = K.Number_ref | reference "variable" = K.Variable_ref
    | reference _ = raise Fail "unknown reference"
  fun result K.Query_slot = "query" | result K.Answer_slot = "answer"
    | result K.Number_slot = "number" | result K.Variable_slot = "variable"
    | result K.Missing = "missing" | result K.Ambiguous = "ambiguous"
  fun outcome "unrecognized" = K.Unrecognized | outcome "answered" = K.Answered
    | outcome "refused" = K.Refused | outcome "failed" = K.Failed
    | outcome _ = raise Fail "unknown outcome"
  fun candidate "null" = NONE | candidate s = SOME(outcome(Json.stringValue s))
  fun boolean "true" = true | boolean "false" = false | boolean _ = raise Fail "expected boolean"
  fun resolved fs = K.resolve (reference(text fs "reference"))
    (entity(raw fs "query")) (entity(raw fs "answer")) (boolean(raw fs "number")) (boolean(raw fs "variable"))
  fun interpretation K.Raw_question = "raw" | interpretation K.Context_question = "context"
    | interpretation K.Clarify_reference = "clarify"
  fun respond fs =
    case text fs "op" of
      "resolve" => "\"resolution\":" ^ Json.quote(result(resolved fs))
    | "interpret" => let val r=resolved fs in
        "\"resolution\":" ^ Json.quote(result r) ^ ",\"interpretation\":" ^
        Json.quote(interpretation(K.choose_query (boolean(raw fs "complete")) r)) end
    | "select" => "\"selection\":" ^ Json.quote(case K.select (outcome(text fs "raw")) (candidate(raw fs "candidate")) of
         K.Original => "original" | K.Rewritten => "rewritten")
    | _ => raise Fail "unknown operation"
  fun line s = let val fs=Json.fields s val id=raw fs "id" in
     ("{\"id\":" ^ id ^ ",\"status\":\"answered\"," ^ respond fs ^ "}")
     handle e => "{\"id\":" ^ id ^ ",\"status\":\"withheld\",\"error\":" ^ Json.quote(exnMessage e) ^ "}"
    end handle e => "{\"id\":null,\"error\":" ^ Json.quote(exnMessage e) ^ "}"
  fun loop () = case TextIO.inputLine TextIO.stdIn of NONE => () | SOME s =>
    (TextIO.output(TextIO.stdOut,line s ^ "\n"); TextIO.flushOut TextIO.stdOut; loop())
end
val _ = Main.loop()
