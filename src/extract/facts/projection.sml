(* UNTRUSTED whole-question interpretation of a source row's requested field.
   The HOL projection receives the actual checked Facts outcome and validates
   its source identity before changing the structured value. *)
structure Projection =
struct
  fun normalize s = String.concatWith " " (String.tokens Char.isSpace s)
  fun accepts pattern q = Option.isSome(Regex.search(Regex.compileI pattern)(normalize q))
  val finish = "\\s*[?.]?\\s*$"
  fun anomieMeaning q = accepts
    ("^(?:what (?:is|does) anomie(?: mean)?|what is the (?:meaning|definition) of anomie|define anomie)" ^ finish) q
  fun anomieAuthor q = accepts
    ("^(?:who (?:developed|introduced|coined) (?:the (?:concept|term) of )?anomie"
     ^ "|which sociologist (?:developed|introduced) the concept of anomie"
     ^ "|whose concept is anomie)" ^ finish) q
  val plant = "(?:the |a )?plants?"
  val fungus = "(?:the |a )?(?:fungus|fungi)"
  val setting = "(?:in (?:a |the )?mycorrhiz(?:a|ae|al (?:exchange|association|symbiosis)),? )?"
  val after = "(?: in (?:a |the )?mycorrhiz(?:a|ae|al (?:exchange|association|symbiosis)))?"
  fun give giver receiver =
    "what (?:does|do) " ^ giver ^ " (?:give|provide|supply)(?: (?:to )?" ^ receiver ^ ")?"
  fun receive receiver giver =
    "what (?:does|do) " ^ receiver ^ " (?:get|receive)(?: from " ^ giver ^ ")?"
  fun direction q =
    if not(accepts "\\bmycorrhiz(?:a|ae|al)\\b" q) then NONE
    else if accepts ("^" ^ setting ^ "(?:" ^ give plant fungus ^ "|" ^ receive fungus plant ^ ")" ^ after ^ finish) q
      then SOME(Facts.ExchangeDirection(Facts.Plant,Facts.Fungus))
    else if accepts ("^" ^ setting ^ "(?:" ^ give fungus plant ^ "|" ^ receive plant fungus ^ ")" ^ after ^ finish) q
      then SOME(Facts.ExchangeDirection(Facts.Fungus,Facts.Plant))
    else NONE
  fun languageBranch q = accepts "\\bbranch\\b" q
  fun request q = if anomieMeaning q then SOME Facts.AnomieMeaning
    else if languageBranch q then SOME Facts.LanguageBranch else direction q
  fun describe Facts.LanguageBranch value = "The language belongs to the " ^ value ^ " branch."
    | describe Facts.AnomieMeaning value = "Anomie means " ^ value ^ "."
    | describe (Facts.ExchangeDirection(Facts.Plant,Facts.Fungus)) value =
        "In a mycorrhiza, the plant supplies the fungus with " ^ value ^ "."
    | describe (Facts.ExchangeDirection(Facts.Fungus,Facts.Plant)) value =
        "In a mycorrhiza, the fungus supplies the plant with " ^ value ^ "."
    | describe _ value = value
  fun label Facts.LanguageBranch = "language_branch"
    | label Facts.AnomieMeaning = "concept_meaning"
    | label (Facts.ExchangeDirection(Facts.Plant,Facts.Fungus)) = "plant_to_fungus"
    | label (Facts.ExchangeDirection(Facts.Fungus,Facts.Plant)) = "fungus_to_plant"
    | label _ = "unsupported"
end
