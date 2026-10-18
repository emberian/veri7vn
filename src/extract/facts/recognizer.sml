(* UNTRUSTED question interpretation for the FactsOrgan family.
   The recognizer supplies narrative classification and candidate row features.
   Explicit subject/attribute grammars below replace broad regex matches for
   selected rows; remaining patterns use the case-insensitive shared matcher.
   The exported HOL answerer independently checks literal word/phrase occurrence
   and conjoins that check with this candidate feature, preserving its narrowing.
   Patterns come from the HOL tables and are compiled once and cached. This
   interface does not claim that natural-language meaning is proved. *)
structure Recognizer =
struct
  fun normalize (t : string) : string = String.concatWith " " (String.tokens Char.isSpace t)

  (* narrow_v1, verbatim patterns *)
  val relation = Regex.compileI
    ("\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}(?:more|less|fewer|longer|shorter)\\s+than\\b|"
     ^ "\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b")
  val rate = Regex.compileI "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
  val sentence_break = Regex.compileI "(?<=[.!?])\\s+"

  fun strip s = normalize s   (* only emptiness and sentence breaks matter below *)

  fun sentences (t : string) : int =
    let val s = strip t
    in if s = "" then 0 else 1 + length (Regex.findall sentence_break s) end

  fun narrative (t : string) : bool =
    sentences t >= 3 orelse length (String.tokens Char.isSpace t) > 40
    orelse Option.isSome (Regex.search relation t) orelse Option.isSome (Regex.search rate t)

  (* pattern cache: a small string-keyed hash table *)
  val buckets : (string * Regex.regex) list Array.array = Array.array (1024, [])
  fun hash (s : string) : int =
    CharVector.foldl (fn (c, h) => (h * 31 + Char.ord c) mod 1048573) 7 s mod 1024
  fun compiled (p : string) : Regex.regex =
    let val i = hash p
    in case List.find (fn (q, _) => q = p) (Array.sub (buckets, i)) of
         SOME (_, r) => r
       | NONE => let val r = Regex.compileI p
                 in Array.update (buckets, i, (p, r) :: Array.sub (buckets, i)); r end
    end

  (* Normalize equivalent question constructions, retaining trailing scope.
     In particular a largest-animal query restricted to Loch Ness must still
     fail the store's deliberately anchored unrestricted-size rule. *)
  fun rewrite p f text =
    case Regex.search (compiled p) text of
      NONE => text
    | SOME (m as {start, stop, ...}) =>
        String.substring (text, 0, start) ^ f (fn n => valOf (Regex.group text m n))
        ^ String.extract (text, stop, NONE)

  fun canonical t =
    let
      val t = rewrite "^define anomie$" (fn _ => "What does anomie mean") t
      val t = rewrite "^describe\\s+" (fn _ => "What is ") t
      val t = rewrite "\\bwhat is the function of ([a-z]+)\\b"
        (fn g => "What do " ^ g 1 ^ " do") t
      val t = rewrite "\\bwhich (animal|creature|mammal|fish|bird) is (?:the )?(largest|biggest|fastest)\\b(?=(?: that has ever lived| ever| alive| on earth| in the world| in the (?:ocean|sea)s?| when diving| while diving| in a dive)?\\s*\\??\\s*$)"
        (fn g => "What is the " ^ g 2 ^ " " ^ g 1) t
      val t = rewrite "\\bwhich (animals?) are the only ones with\\b"
        (fn g => "Which are the only " ^ g 1 ^ " with") t
    in t end

  (* Quoted wording is the object of a literary query, not the speaker's
     ranking. Apostrophes within words are not opening quotation marks. *)
  fun withoutQuotes text =
    let val n = size text
        fun word c = Char.isAlphaNum c orelse c = #"_"
        fun close c j =
          if j >= n then NONE
          else if String.sub (text,j) = c andalso (j+1=n orelse not (word (String.sub(text,j+1))))
          then SOME j else close c (j+1)
        fun go i acc =
          if i >= n then String.concat (rev acc)
          else let val c = String.sub(text,i)
               in if (c = #"\"" orelse c = #"'") andalso (i=0 orelse not (word (String.sub(text,i-1))))
                  then (case close c (i+1) of SOME j => go (j+1) (" "::acc)
                       | NONE => go (i+1) (String.str c::acc))
                  else go (i+1) (String.str c::acc)
               end
    in go 0 [] end

  val literatureBlock = case Facts.organ_by_id "literature-v2" of
      SOME og => Facts.store_block (Facts.organ_store og)
    | NONE => NONE

  (* Each typed question grammar is attached to the actual exported row
     guard. It selects a subject and requested attribute; it does not add a
     source fact or turn the untrusted English parser into a proof. *)
  fun accepts p q = Option.isSome (Regex.search (compiled p) q)
  val finish = "\\s*[?.]?\\s*$"
  fun humanMeasurement metric = accepts
    ("^(?:what (?:is|are)(?: considered)?|what's|tell me) (?:the |a )?"
     ^ "(?:normal|typical|healthy|usual) (?:(?:human|adult) )?" ^ metric
     ^ "(?: range)?(?: (?:of|for|in) (?:a |an |the )?(?:human|adult|person|humans|adults|people))?" ^ finish)
  fun adultTeeth singular plural = accepts
    ("^(?:how many (?:permanent |adult )?teeth (?:does (?:a |an |the )?(?:adult |domestic )?"
     ^ singular ^ " have|do (?:adult |domestic )?" ^ plural ^ " have)"
     ^ "|what is (?:a |an |the )?(?:adult |domestic )?" ^ singular
     ^ "'s (?:permanent )?(?:tooth|teeth) count)" ^ finish)
  fun attribution topic = accepts
    ("^(?:who (?:first )?(?:discovered|described|developed|pioneered) " ^ topic
     ^ "|(?:which|what) (?:psychologist|researcher|scientist) (?:is|was) "
     ^ "(?:associated with|credited with|known for) " ^ topic ^ ")" ^ finish)
  val marburyPrinciple = accepts
    ("^(?:(?:what|which)(?: (?:power|principle|doctrine))? did marbury(?: v\\.? madison)? "
     ^ "(?:establish|established)|(?:what|which) (?:power|principle|doctrine) "
     ^ "(?:was established by|came from) marbury(?: v\\.? madison)?)" ^ finish)
  val globalRange = "(?: (?:in the world|on earth|alive|alive today|living today))?"
  val oceanRange = "(?: (?:in the world|on earth|in the ocean|in the seas?|alive))?"
  val largestFish = accepts
    ("^(?:(?:what|which) is the (?:largest|biggest) fish(?: species)?"
     ^ "|which fish (?:is the (?:largest|biggest)|grows (?:the )?largest))" ^ oceanRange ^ finish)
  val largestBird = accepts
    ("^(?:(?:what|which) is the (?:largest|biggest|heaviest|tallest) (?:living )?bird"
     ^ "|(?:what|which) bird is the (?:largest|biggest|heaviest|tallest))" ^ globalRange ^ finish)
  val smallestBird = accepts
    ("^(?:(?:what|which) is the smallest (?:living )?bird(?: species)?"
     ^ "|(?:what|which) bird is the smallest|name the smallest bird(?: species)?)" ^ globalRange ^ finish)
  val widestWingspan = accepts
    ("^(?:(?:what|which) (?:living )?bird has the (?:largest|widest|longest|greatest) wingspan"
     ^ "|(?:what|which) bird's wingspan is (?:the )?(?:largest|widest|longest|greatest))" ^ globalRange ^ finish)
  val plantPhotosynthesis = accepts
    ("^(?:where does photosynthesis (?:take place|occur|happen)(?: in (?:a |the )?(?:plant cell|plant cells|plants|green plants))?"
     ^ "(?:\\? which organelle)?|(?:in )?which organelle (?:do plant cells (?:perform|carry out) photosynthesis"
     ^ "|does photosynthesis (?:occur|take place)))" ^ finish)
  val insectAppendages = accepts
    ("^(?:where are (?:an? )?insect(?:'s)? (?:legs|wings) attached(?:\\? which body part)?"
     ^ "|(?:to )?which (?:body )?(?:part|segment) do insect(?:'s)? (?:legs|wings) attach"
     ^ "|where do insect(?:'s)? (?:legs|wings) attach)" ^ finish)

  val fungalWallMaterial = accepts
    ("^(?:what (?:are|is) (?:the |a )?(?:fungal cell walls?|cell walls? of fungi) made of"
     ^ "|what is the (?:main )?material in fungal cell walls"
     ^ "|(?:what|which) (?:substance|material|polymer) (?:forms|makes up) fungal cell walls"
     ^ "|what do fungi have in (?:their )?cell walls(?: instead of cellulose)?)" ^ finish)
  val breadPlatePlacement = accepts
    ("^(?:in a formal place setting,? )?(?:where (?:does|should) (?:the |a )?bread plate "
     ^ "(?:go|belong)|(?:what|which) (?:position|location) is (?:the |a )?bread plate in)"
     ^ "(?: in a (?:formal )?place setting)?" ^ finish)

  fun rowGuard sid i =
    case Facts.organ_by_id sid of
      SOME og => List.nth (Facts.row_guards og, i)
    | NONE => raise Fail ("missing scope table " ^ sid)
  (* These adult CPR rows have no infant, animal, or multiple-rescuer
     model. A closed vocabulary retains the original row's metric guard but
     rejects additional subjects/settings rather than guessing their scope. *)
  fun closedRow sid i vocabulary q =
    let val allowed = String.tokens Char.isSpace vocabulary
        val tokens = String.tokens (fn c => not (Char.isAlphaNum c)) (String.map Char.toLower q)
    in List.all (fn token => List.exists (fn w => w = token) allowed) tokens
       andalso accepts (rowGuard sid i) q
    end
  val adultCPRWords =
    "what which is are the a an correct normal recommended recommendation usual for in during on "
    ^ "adult adults human humans person cpr chest compression compressions breaths breath ratio to "
    ^ "rate speed depth deep fast how many much per minute should you give perform push be "
    ^ "at do does of single rescuer one each 30 follow between and"

  val authorGuardPrefix = "(?=.*\\b(?:wrote|written|author\\w*|writer|penned)\\b).*"
  val publicationGuardPrefix = "(?=.*\\b(?:when|what year|which year|in what year)\\b)(?=.*\\b(?:published|publication|come out|came out|released|first appear\\w*)\\b).*"
  fun titleGuard sid i =
    let val guard=rowGuard sid i
    in if sid="literature-v2" andalso i>=25 then
         if String.isPrefix authorGuardPrefix guard then String.extract(guard,size authorGuardPrefix,NONE)
         else raise Fail "literature author guard shape changed"
       else if sid="literature-v2" andalso i>=9 andalso i<=14 then
         if String.isPrefix publicationGuardPrefix guard then String.extract(guard,size publicationGuardPrefix,NONE)
         else raise Fail "literature publication guard shape changed"
       else guard
    end
  (* A creator question must surround exactly the known work title. A
     matched title inside a question about a thief, restoration or replica
     does not authorize returning its original artist. *)
  fun titleRelation sid i prefix suffix q =
    case Regex.search (compiled (titleGuard sid i)) q of
      NONE => false
    | SOME {start,stop,...} =>
        accepts ("^(?:" ^ prefix ^ ")[\"']?$") (String.substring(q,0,start))
        andalso accepts ("^[\"']?" ^ suffix ^ finish) (String.extract(q,stop,NONE))
  fun titleQuestion sid i prefix q = titleRelation sid i prefix "" q
  (* The source names particular works, not every work with a shared title.
     This small medium inventory is untrusted source metadata: David/Thinker
     are sculpture, the Great Wave aliases are print, other stored works are
     paintings. It constrains the requested creation verb and role. *)
  fun artistPrefix i =
    let val guard=rowGuard "arthistory" i
        val sculpture = guard="\\bdavid\\b" orelse guard="\\bthe thinker\\b"
        val printWork = guard="\\bthe great wave\\b" orelse guard="\\bthe great wave off kanagawa\\b"
        val verb = if sculpture then "sculpted" else if printWork then "designed" else "painted"
        val role = if sculpture then "sculptor" else if printWork then "printmaker" else "painter"
        val medium = if sculpture then "sculpture" else if printWork then "print" else "painting"
        val action="(?:" ^ verb ^ "|created|made)"
        val person="(?:artist|" ^ role ^ ")"
    in "who " ^ action ^ " (?:the |a )?(?:" ^ medium ^ " |artwork )?"
     ^ "|(?:which|what) artist " ^ action ^ " (?:the )?"
     ^ "|name the " ^ person ^ " who " ^ action ^ " (?:the )?"
     ^ "|who is the " ^ person ^ " (?:of|behind) (?:the )?"
     ^ "|name the " ^ person ^ " (?:of|behind) (?:the )?"
    end
  val poetPrefix =
    "who (?:wrote|composed|penned) (?:the poem )?"
    ^ "|(?:which|what) poet (?:wrote|composed|penned) (?:the poem )?"
    ^ "|who is the author of (?:the poem )?"
    ^ "|name the (?:author|poet) (?:of|behind) (?:the poem )?"
  val authorPrefix =
    "who (?:wrote|authored|penned) (?:the book )?"
    ^ "|(?:which|what) (?:author|writer) (?:wrote|penned) (?:the book )?"
    ^ "|who is the (?:author|writer) of (?:the book )?"
    ^ "|name the (?:author|writer) of (?:the book )?"
  fun publicationYear i q =
    titleRelation "literature-v2" i "(?:when|(?:in )?(?:what|which) year) was (?:the book )?"
      " (?:first |originally )?(?:published|released)" q
    orelse titleRelation "literature-v2" i "(?:when|(?:in )?(?:what|which) year) did (?:the book )?"
      " (?:first |originally )?(?:come out|appear)" q
  fun lineCount form = accepts
    ("^how many lines (?:does (?:a |the )?" ^ form ^ " have|are (?:there )?in (?:a |the )?" ^ form ^ ")" ^ finish)
  fun rhymeScheme form = accepts
    ("^(?:what is the rhyme scheme of (?:a |the )?" ^ form
      ^ "|what rhyme scheme does (?:a |the )?" ^ form ^ " use)" ^ finish)
  val haikuPattern = accepts
    ("^(?:what is the (?:syllable )?pattern of (?:a |the )?haiku"
      ^ "|how many syllables (?:are there )?(?:per|in each) line (?:in|of) (?:a |the )?haiku)" ^ finish)
  val iambicSyllables = accepts
    ("^how many syllables (?:are (?:there )?in (?:a |one )?line of iambic pentameter"
      ^ "|does (?:a |one )?line of iambic pentameter have)" ^ finish)
  val pentameterFeet = accepts
    ("^how many (?:feet|iambs) (?:are (?:there )?in (?:a |one )?(?:line of )?(?:iambic )?pentameter"
      ^ "|does (?:a |one )?line of (?:iambic )?pentameter have)" ^ finish)
  (* A date request binds both the named subject and its stored event.
     Merely asking a year about a familiar subject is not enough: sealing,
     destruction, reissue and commemoration are different events. *)
  val warOne = "(?:world war i|world war one|first world war|ww1|wwi)"
  val warTwo = "(?:world war ii|world war two|second world war|ww2|wwii)"
  fun warEvent war event = "did (?:the )?" ^ war ^ " " ^ event
  val dateClauses = [
    "(?:did the western roman empire fall|was the fall of the western roman empire)",
    "(?:was (?:the )?magna carta (?:first |originally )?(?:sealed|signed)|did (?:king )?john seal (?:the )?magna carta)",
    "(?:was the battle of hastings(?: fought)?|did the battle of hastings (?:take place|occur|happen))",
    "did (?:christopher )?columbus (?:first )?(?:reach|arrive in|land in|sail to) (?:the )?(?:americas|new world)",
    "(?:did (?:the )?(?:protestant )?reformation (?:begin|start)|did (?:martin )?luther post (?:his |the )?(?:95|ninety-five) theses|were (?:luther's |the )?(?:95|ninety-five) theses posted)",
    "(?:did the french revolution (?:begin|start)|was the storming of the bastille|did the storming of the bastille (?:take place|occur))",
    "(?:was the (?:battle of )?waterloo(?: fought)?|did the battle of waterloo (?:take place|occur|happen))",
    warEvent warOne "(?:begin|start|break out)",
    warEvent warOne "(?:end|finish)",
    "(?:was the (?:russian|bolshevik|october) revolution|did the (?:russian|bolshevik|october) revolution (?:take place|occur|happen))",
    warEvent warTwo "(?:begin|start|break out)",
    warEvent warTwo "(?:end|finish)",
    "was the united nations (?:founded|established|created)",
    "(?:did india (?:gain|achieve) independence(?: from (?:britain|british rule))?|was india's independence)",
    "was the people'?s republic of china (?:founded|established|proclaimed)",
    "(?:did the berlin wall (?:fall|come down)|was the berlin wall torn down)",
    "did the (?:soviet union|ussr) (?:dissolve|collapse|break up|end)"]
  fun datedRow i q =
    accepts ("^(?:when|(?:in )?(?:what|which) year) " ^ List.nth(dateClauses,i) ^ finish) q
    andalso accepts (rowGuard "worldhistory" i) q
  val historyPeople = [
    "who (?:was|is) the first (?:human|person|man) in space",
    "who (?:was|is) the first (?:roman emperor|emperor of rome)",
    "who (?:was|is) the first emperor of (?:a unified )?china",
    "(?:who founded the mongol empire|who (?:was|is) the founder of the mongol empire)",
    "(?:who unified germany|who led (?:german unification|the unification of germany))",
    "who was (?:the )?(?:british prime minister|prime minister (?:of|in) britain) (?:during|for most of) (?:the )?(?:world war ii|second world war|wwii)"]
  fun historyPerson j = accepts ("^" ^ List.nth(historyPeople,j) ^ finish)
  (* The supplied class rows use the US source classification. The question
     must be unqualified or explicitly US-scoped; other jurisdictions and
     mixed/unknown fuels are not interpreted using this table. *)
  val usFirePrefix = "(?:in the (?:us|united states),? )?"
  val usFireSuffix = "(?: in the (?:us|united states))?"
  val fireFuels = ["(?:cooking oils?(?: and (?:grease|fats?))?|cooking fats?|grease)",
    "(?:electrical|electric|energized electrical equipment|wiring)",
    "(?:gasoline|petrol|flammable liquids?|solvents?)", "(?:combustible metals?|magnesium|titanium|sodium)",
    "(?:wood|paper|cloth|ordinary combustibles?)"]
  fun fireClassFuel j = accepts
    ("^" ^ usFirePrefix ^ "(?:(?:which|what) (?:extinguisher (?:class|type)|(?:class|type)(?: of (?:fire(?: extinguisher)?))?) "
     ^ "(?:is (?:used |meant )?(?:for|on)|involves) (?:a |an )?(?:burning )?" ^ List.nth(fireFuels,j) ^ "(?: fires?)?"
     ^ "|(?:which|what) (?:fire )?(?:class|type) (?:is|are) (?:a |an )?" ^ List.nth(fireFuels,j) ^ " fires?)"
     ^ usFireSuffix ^ finish)
  val classLetters=["a","b","c","d","k"]
  fun fireClassMeaning j =
    let val c=List.nth(classLetters,j)
    in accepts ("^" ^ usFirePrefix ^ "(?:what (?:is a|are) class " ^ c ^ " fires?"
      ^ "|what kinds? of fires? (?:is|are) class " ^ c ^ " fires?"
      ^ "|what kind of material burns in a class " ^ c ^ " fire"
      ^ "|class " ^ c ^ " extinguishers are for fires involving what"
      ^ "|what (?:does a class " ^ c ^ " fire|do class " ^ c ^ " fires) involve)"
      ^ usFireSuffix ^ finish) end
  (* Exact source-language identity, with only explicit source aliases. The
     supplied family is checked when the request names it; arbitrary qualifiers
     cannot be discarded to select a spoken language inside a signed language. *)
  fun languageScope i q =
    let val fields = Facts.language_field (Facts.nat_of_integer(IntInf.fromInt i))
        val (name,family) = case fields of SOME(n,(f,_)) => (n,f) | NONE => ("basque","isolate")
        val language = "(?:" ^ name ^ (if name="mandarin" orelse name="cantonese" then "(?: chinese)?" else "") ^ ")"
        val subject = "(?:the language )?[\"'(]?" ^ language ^ "[\"')]?"
        val familyWord = "(?:language )?family"
        fun forms attribute =
          "(?:(?:what|which) " ^ attribute ^ " (?:does " ^ subject ^ " belong to|is " ^ subject ^ " (?:in|part of))"
          ^ "|to which " ^ attribute ^ " does " ^ subject ^ " belong"
          ^ "|" ^ subject ^ " belongs to (?:what|which) " ^ attribute ^ ")"
        val familyRequest = accepts ("^" ^ forms familyWord ^ finish) q
        val branchRequest = i>0 andalso
          (accepts ("^" ^ forms "(?:language )?branch" ^ finish) q
          orelse accepts ("^(?:what|which) branch of " ^ family ^ " (?:is " ^ subject
            ^ "|does " ^ subject ^ " belong to)" ^ finish) q)
        val isolateRequest = i=0 andalso accepts
          ("^(?:is basque (?:a language isolate|related to any other language)(?:\\? what family is it)?)" ^ finish) q
    in familyRequest orelse branchRequest orelse isolateRequest end

  fun literaryNarrator i =
    let val titles=["moby[- ]dick","(?:the )?great gatsby","(?:the )?(?:sherlock )?holmes(?: stories)?","great expectations"]
        val title=List.nth(titles,i)
    in accepts ("^(?:who (?:narrates|tells the story (?:of|in)) (?:the (?:novel|book) )?" ^ title
      ^ "|who is the narrator of (?:the (?:novel|book) )?" ^ title ^ ")" ^ finish) end
  fun literarySetting title = accepts
    ("^(?:where (?:is|was) " ^ title ^ " set|where does " ^ title ^ " take place"
     ^ "|what is the setting of " ^ title
     ^ "|in which (?:country|city) is (?:shakespeare's )?" ^ title ^ " set)" ^ finish)
  val literaryShip = accepts
    ("^(?:what (?:is|was) (?:the name of )?(?:captain )?ahab's ship"
     ^ "|what (?:is|was) the (?:name of the )?ship in moby[- ]dick"
     ^ "|what ship (?:does|did) (?:captain )?ahab (?:captain|command))" ^ finish)
  val literarySquire = accepts
    ("^(?:who (?:is|was) don quixote's squire|what (?:is|was) the name of don quixote's squire)" ^ finish)
  fun literaryCharacter name = accepts
    ("^(?:(?:which|what) (?:novel|book|work|story) (?:features|includes|contains) (?:the character )?" ^ name
     ^ "|(?:which|what) (?:novel|book|work|story) (?:is|does) " ^ name ^ " (?:from|in|appear in)"
     ^ "|in (?:which|what) (?:novel|book|work|story) (?:does|is) " ^ name ^ " (?:appear|feature|a character)"
     ^ "|" ^ name ^ " (?:appears|is a character|is the protagonist) in (?:which|what) (?:novel|book|work|story))" ^ finish)
  val characterNames=["jean valjean","raskolnikov","heathcliff","(?:ebenezer )?scrooge",
    "(?:abraham )?van helsing","(?:elizabeth bennet|mr\\.? darcy|elizabeth bennet and mr\\.? darcy)","(?:captain )?ahab"]
  (* These legal definition rows provide general source meanings, not named
     fictional rules, jurisdictions, remedies or facts about a person's case. *)
  fun legalDefinition term article = accepts
    ("^(?:what (?:is|does) " ^ article ^ term ^ "(?: mean)?"
     ^ "|what is the (?:meaning|definition) of " ^ term
     ^ "|define " ^ term ^ "|who is " ^ article ^ term ^ ")"
     ^ "(?: in (?:law|legal terminology|a case))?" ^ finish)

  val hierarchy = "(?:maslow's (?:hierarchy(?: of needs)?)|the hierarchy of needs)"
  fun hierarchyLevel position = accepts
    ("^what (?:is|are) (?:at )?the " ^ position ^ "(?: (?:level|need|needs))? (?:of|in) " ^ hierarchy ^ finish)
  val pavlovAnimals = accepts
    ("^(?:what|which) animals? (?:did|does) pavlov (?:use|study)(?: in (?:his )?(?:conditioning )?experiments)?" ^ finish)
  val obedienceActor = accepts
    ("^who (?:conducted|led|performed|ran) (?:the )?(?:famous )?(?:obedience(?:-to-authority)? (?:experiments|study)|milgram's obedience experiments)" ^ finish)
  val stanfordActor = accepts
    ("^who (?:conducted|led|performed|ran) (?:the )?stanford prison experiment" ^ finish)
  val boboActor = accepts
    ("^who (?:conducted|led|performed|ran) (?:the )?bobo doll experiment" ^ finish)
  val bigFiveList = accepts
    ("^(?:what are|name|list) the big five(?: personality)? traits" ^ finish)
  val millerCapacity = accepts
    ("^(?:what (?:is|was) the (?:estimated )?capacity of short-term memory"
      ^ "|how many items can short-term memory hold)(?: according to (?:george )?miller)?" ^ finish)
  val freudModel = accepts
    ("^(?:who (?:proposed|developed) (?:the )?(?:model of the )?id,? ego and superego"
      ^ "|whose (?:model|theory) (?:includes|contains) the id,? ego and superego)" ^ finish)
  val laboratoryFounder = accepts
    ("^(?:who (?:founded|established) the first (?:experimental )?psychology laboratory|who is known as the father of (?:experimental|modern) psychology)" ^ finish)
  val harlowAnimals = accepts
    ("^(?:what|which) animals? did (?:harry )?harlow study(?: (?:in his attachment research|for attachment))?" ^ finish)
  fun studyRow i actor q = actor q orelse
    (case Projection.studyRequest q of SOME(row,_)=>row=i | NONE=>false)
  val childdevRequests = [
    "^(?:how many (?:stages|cognitive stages|stages of cognitive development) did piaget (?:describe|propose|identify)|how many stages are in piaget's (?:theory|model)(?: of cognitive development)?)\\s*[?.]?\\s*$",
    "^(?:(?:what is piaget's (?:first|earliest) (?:stage|stage of cognitive development)|which stage comes first in piaget's theory)|what is the (?:first|earliest) of piaget's stages)\\s*[?.]?\\s*$",
    "^(?:what is piaget's (?:last|final|fourth) (?:stage|stage of cognitive development)|which stage comes last in piaget's theory)\\s*[?.]?\\s*$",
    "^(?:(?:in |at )?(?:which|what) (?:piaget|developmental|cognitive)? ?stage (?:does|did) object permanence (?:develop|emerge|appear)|object permanence (?:develops|emerges|appears) (?:in|at) (?:which|what) stage)\\s*[?.]?\\s*$",
    "^(?:(?:(?:in |at )?(?:which|what) (?:piaget's? )?stage (?:do children master|is) conservation(?: mastered)?|(?:in |at )?(?:which|what) stage of piaget's theory (?:is conservation mastered|do children master conservation))|(?:conservation(?: of (?:volume|mass|number))? is mastered in which of piaget's stages|which stage of piaget's includes (?:understanding|mastering) conservation(?: of (?:volume|mass|number))?))\\s*[?.]?\\s*$",
    "^(?:what (?:is|are) the (?:age|ages|age range) (?:of|for) the sensorimotor stage|when (?:is|does) the sensorimotor stage (?:occur|take place)?|how long does the sensorimotor stage last)\\s*[?.]?\\s*$",
    "^(?:(?:what (?:is|are) the (?:age|ages|age range) (?:of|for) the preoperational stage|when does the preoperational stage (?:occur|take place))|at what ages is a child in the preoperational stage)\\s*[?.]?\\s*$",
    "^(?:how many (?:psychosocial )?stages did erikson (?:describe|propose|identify)|how many stages are in erikson's (?:theory|model))\\s*[?.]?\\s*$",
    "^(?:(?:what is erikson's (?:first|infancy|infant) stage|which erikson stage occurs in infancy)|what is erikson's first stage of psychosocial development)\\s*[?.]?\\s*$",
    "^(?:(?:what is erikson's (?:adolescent|teenage) stage|which erikson stage occurs (?:during|in) adolescence)|which erikson stage belongs to adolescence)\\s*[?.]?\\s*$",
    "^(?:who (?:proposed|developed|introduced) (?:the (?:concept|idea) of )?(?:the )?zone of proximal development|the zone of proximal development comes from which theorist)\\s*[?.]?\\s*$",
    "^who (?:devised|developed|created) the strange situation(?: procedure|test)?\\s*[?.]?\\s*$",
    "^who (?:developed|proposed|introduced) attachment theory\\s*[?.]?\\s*$",
    "^(?:(?:what (?:sleeping|sleep) position is recommended for (?:infants|babies)|(?:in )?what position should (?:infants|babies) be placed to sleep|how should (?:infants|babies) be positioned for sleep)|(?:how should (?:infants|babies) be placed to sleep|should (?:infants|babies) sleep on their backs? or their stomachs?))\\s*[?.]?\\s*$"];
  val anniversaryOrdinals = ["(?:1st|first)","(?:5th|fifth)","(?:10th|tenth)",
    "(?:15th|fifteenth)","(?:20th|twentieth)","(?:25th|twenty-fifth)","(?:30th|thirtieth)",
    "(?:35th|thirty-fifth)","(?:40th|fortieth)","(?:45th|forty-fifth)","(?:50th|fiftieth)",
    "(?:55th|fifty-fifth)","(?:60th|sixtieth)"]
  fun weddingGift i =
    let val ordinal=List.nth(anniversaryOrdinals,i)
        val anniversary="(?:a |the )?" ^ ordinal ^ " (?:wedding )?anniversary"
    in accepts ("^(?:what is the (?:traditional )?(?:gift|material|present) for " ^ anniversary
      ^ "|what is the (?:traditional )?" ^ ordinal ^ " (?:wedding )?anniversary (?:gift|material|present)"
      ^ "|which material is traditional for " ^ anniversary
      ^ "|what gift marks " ^ anniversary ^ ")(?: traditionally)?" ^ finish) end
  fun utensilPlace utensil = accepts
    ("^(?:which side of the plate (?:do|does) the " ^ utensil ^ " go on"
      ^ "|where (?:do|does|should) the " ^ utensil ^ " go(?: in a (?:formal )?place setting)?)" ^ finish)
  val glassPlace = accepts
    ("^where (?:do|does) the (?:glass|glasses|drinks) go in a (?:formal )?place setting" ^ finish)
  val unknownLetterClose = accepts
    ("^(?:how do you sign off a letter that starts dear sir or madam"
     ^ "|how (?:do|should) you sign (?:off )?a formal letter to an (?:unnamed|unknown) recipient"
     ^ "|what (?:closing|sign-off) is used (?:for|in) a formal letter to an (?:unnamed|unknown) recipient)" ^ finish)
  val namedLetterClose = accepts
    ("^(?:if you know the recipient's name,? how should you sign a formal letter"
     ^ "|how (?:do|should) you sign (?:off )?a formal letter to a named recipient"
     ^ "|what (?:closing|sign-off) is used (?:for|in) a formal letter to a named recipient)" ^ finish)
  val rowScopeGroups =
    List.tabulate(13,fn i=>("etiquette",i,weddingGift i)) @
    List.tabulate(14,fn i=>("childdev",i,accepts(List.nth(childdevRequests,i)))) @
    List.tabulate(4,fn i=>("literature-v2",i,literaryNarrator i)) @
    List.tabulate(7,fn j=>("literature-v2",j+18,literaryCharacter(List.nth(characterNames,j)))) @
    List.tabulate(44,fn i=>("linguistics",i,languageScope i)) @
    List.tabulate(6,fn j=>("worldhistory",j+17,historyPerson j)) @
    List.tabulate(6,fn j=>let val i=j+9 in ("literature-v2",i,publicationYear i) end) @
    List.tabulate(5,fn j=>("firesafety-v2",j+2,fireClassFuel j)) @
    List.tabulate(5,fn j=>("firesafety-v2",j+7,fireClassMeaning j)) @
    List.tabulate (51,fn j => let val i=j+25 in ("literature-v2",i,titleQuestion "literature-v2" i authorPrefix) end) @
    List.tabulate (17,fn i => ("worldhistory",i,datedRow i)) @
    List.tabulate (34,fn i => ("arthistory",i,titleQuestion "arthistory" i (artistPrefix i))) @
    List.tabulate (11,fn j => let val i=j+10 in ("poetry",i,titleQuestion "poetry" i poetPrefix) end)

  val scopedRows : (string * (string -> bool)) list =
    map (fn (sid,i,accept) => (rowGuard sid i,accept))
      (rowScopeGroups @ [("etiquette",13,utensilPlace "forks?"),
       ("etiquette",14,utensilPlace "(?:knife|knives)"),
       ("etiquette",16,glassPlace),
       ("etiquette",17,unknownLetterClose),
       ("etiquette",18,namedLetterClose),("psychology",0,hierarchyLevel "(?:top|highest|peak)"),
       ("psychology",1,hierarchyLevel "(?:base|bottom|lowest)"),
       ("psychology",4,pavlovAnimals),
       ("psychology",5,studyRow 5 obedienceActor),
       ("psychology",6,studyRow 6 stanfordActor),
       ("psychology",7,studyRow 7 boboActor),
       ("psychology",8,bigFiveList),
       ("psychology",9,millerCapacity),
       ("psychology",10,freudModel),
       ("psychology",11,studyRow 11 laboratoryFounder),
       ("psychology",12,fn q => attribution "cognitive dissonance(?: theory)?" q orelse
          accepts ("^who is the psychologist behind cognitive dissonance(?: theory)?" ^ finish) q),
       ("psychology",13,studyRow 13 harlowAnimals),("literature-v2",4,literaryShip),
       ("literature-v2",8,literarySquire),
       ("literature-v2",15,literarySetting "romeo and juliet"),
       ("literature-v2",16,literarySetting "hamlet"),
       ("law",2,fn q => legalDefinition "habeas corpus" "" q orelse accepts ("^what is the writ of habeas corpus used for" ^ finish) q),
       ("law",3,legalDefinition "mens rea" ""),
       ("law",4,legalDefinition "actus reus" ""),
       ("law",5,legalDefinition "tort" "(?:a )?"),
       ("law",6,legalDefinition "plaintiff" "(?:a |the )?"),
       ("law",7,legalDefinition "defendant" "(?:a |the )?"),
       ("medicine",0,humanMeasurement "body temperature"),
       ("medicine",1,humanMeasurement "resting (?:heart rate|pulse)"),
       ("medicine",2,humanMeasurement "blood pressure"),
       ("pets",6,adultTeeth "(?:dog|canine)" "(?:dogs|canines)"),
       ("pets",7,adultTeeth "(?:cat|feline)" "(?:cats|felines)"),
       ("law",8,marburyPrinciple),
       ("psychology",2,attribution "classical conditioning"),
       ("psychology",3,attribution "operant conditioning"),
       ("marinebio",1,largestFish),
       ("ornithology",2,largestBird),
       ("ornithology",3,smallestBird),
       ("ornithology",4,widestWingspan),
       ("botany",7,plantPhotosynthesis),
       ("entomology",11,insectAppendages),
       ("firstaid",0,closedRow "firstaid" 0 adultCPRWords),
       ("firstaid",1,closedRow "firstaid" 1 adultCPRWords),
       ("firstaid",2,closedRow "firstaid" 2 adultCPRWords),
       ("mycology",0,fungalWallMaterial),
       ("etiquette",15,breadPlatePlacement),
       ("poetry",0,lineCount "sonnet"),
       ("poetry",1,rhymeScheme "shakespearean sonnet"),
       ("poetry",2,haikuPattern),
       ("poetry",3,lineCount "haiku"),
       ("poetry",4,lineCount "limerick"),
       ("poetry",5,rhymeScheme "limerick"),
       ("poetry",6,lineCount "villanelle"),
       ("poetry",7,lineCount "sestina"),
       ("poetry",8,iambicSyllables),
       ("poetry",9,pentameterFeet),
       ("sociology",1,fn q => Projection.anomieMeaning q orelse Projection.anomieAuthor q),
       ("mycelial",1,fn q => Option.isSome(Projection.direction q))])

  (* The admitted creator grammar surrounds exactly this row's known title.
     Preserve that matched title as answer context, never arbitrary question
     qualifiers. Regex span extraction and rendering remain untrusted. *)
  fun sourceSubject sid i q =
    if sid = "arthistory" orelse (sid = "poetry" andalso i >= 10) orelse (sid="literature-v2" andalso i>=25) then
      let val text = normalize q
      in case Regex.search (compiled (titleGuard sid i)) text of
           SOME {start,stop,...} => SOME (String.substring(text,start,stop-start))
         | NONE => NONE
      end
    else NONE

  fun features (t : string) : string -> bool =
    let val raw = normalize t
        val n = canonical raw
        val unquoted = withoutQuotes n
    in fn p => case List.find (fn (guard,_) => guard = p) scopedRows of
         SOME (_,accept) => accept raw
       | NONE => Option.isSome (Regex.search (compiled p)
           (if SOME p = literatureBlock then unquoted else n)) end
end
