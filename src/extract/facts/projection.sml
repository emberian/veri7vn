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
  (* Whole-question field interpretation; source assertions remain untrusted.
     The first component binds the request to its checked source row. *)
  val laboratoryEvent = "(?:was the first (?:experimental )?psychology (?:laboratory|lab) (?:founded|established)"
    ^ "|did (?:wilhelm )?wundt (?:found|establish) the first (?:experimental )?psychology (?:laboratory|lab))"
  val obedienceExperiments = "(?:milgram's |the )?obedience(?:-to-authority)? experiments"
  val studyRequests =
    [(5,Facts.StudyTopic,"what (?:did|does) (?:stanley )?milgram study"),
     (13,Facts.StudyTopic,"what (?:did|does) (?:harry )?harlow study"),
     (5,Facts.StudyDate,"when (?:were " ^ obedienceExperiments ^ " conducted|did " ^ obedienceExperiments ^ " (?:take place|occur)|was the obedience study conducted)"),
     (6,Facts.StudyDate,"(?:when|(?:in )?(?:what|which) year) (?:was the stanford prison experiment conducted|did the stanford prison experiment (?:take place|occur))"),
     (7,Facts.StudyFinding,"what (?:did|does) the bobo doll (?:experiment|study) (?:demonstrate|show)"),
     (11,Facts.StudyDate,"(?:when|(?:in )?(?:what|which) year) " ^ laboratoryEvent),
     (11,Facts.StudyPlace,"(?:where|in (?:which|what) city) " ^ laboratoryEvent),
     (13,Facts.StudyFinding,"what (?:did|does) harlow's attachment (?:research|study|experiments) (?:demonstrate|show)")]
  fun studyRequest q =
    case List.find(fn(_,_,p)=>accepts("^" ^ p ^ finish)q)studyRequests of
      SOME(row,attribute,_)=>SOME(row,attribute) | NONE=>NONE
  fun languageBranch q = accepts "\\bbranch\\b" q
  fun requestFor organ q =
    if organ="sociology" then (if anomieMeaning q then SOME Facts.AnomieMeaning else NONE)
    else if organ="mycelial" then direction q
    else if organ="linguistics" then (if languageBranch q then SOME Facts.LanguageBranch else NONE)
    else if organ="psychology" then
      (case studyRequest q of SOME(_,attribute)=>SOME(Facts.SourceAttribute attribute) | NONE=>NONE)
    else NONE
  fun describe (Facts.SourceAttribute _) value = value
    | describe Facts.LanguageBranch value = "The language belongs to the " ^ value ^ " branch."
    | describe Facts.AnomieMeaning value = "Anomie means " ^ value ^ "."
    | describe (Facts.ExchangeDirection(Facts.Plant,Facts.Fungus)) value =
        "In a mycorrhiza, the plant supplies the fungus with " ^ value ^ "."
    | describe (Facts.ExchangeDirection(Facts.Fungus,Facts.Plant)) value =
        "In a mycorrhiza, the fungus supplies the plant with " ^ value ^ "."
    | describe _ value = value
  fun label (Facts.SourceAttribute Facts.StudyTopic) = "study_topic"
    | label (Facts.SourceAttribute Facts.StudyDate) = "study_date"
    | label (Facts.SourceAttribute Facts.StudyPlace) = "study_place"
    | label (Facts.SourceAttribute Facts.StudyFinding) = "study_finding"
    | label (Facts.SourceAttribute Facts.ConceptMeaning) = "concept_meaning"
    | label Facts.LanguageBranch = "language_branch"
    | label Facts.AnomieMeaning = "concept_meaning"
    | label (Facts.ExchangeDirection(Facts.Plant,Facts.Fungus)) = "plant_to_fungus"
    | label (Facts.ExchangeDirection(Facts.Fungus,Facts.Plant)) = "fungus_to_plant"
    | label _ = "unsupported"
end
