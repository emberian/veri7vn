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
  val objectPermanenceStage = accepts
    ("^(?:(?:in |at )?(?:which|what)(?: piaget| developmental| cognitive)? stage "
     ^ "(?:does|did) object permanence (?:develop|emerge|appear)"
     ^ "|object permanence (?:develops|emerges|appears) (?:in|at) (?:which|what) stage)" ^ finish)

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

  (* A creator question must surround exactly the known work title. A
     matched title inside a question about a thief, restoration or replica
     does not authorize returning its original artist. *)
  fun titleQuestion sid i prefix q =
    case Regex.search (compiled (rowGuard sid i)) q of
      NONE => false
    | SOME {start,stop,...} =>
        accepts ("^(?:" ^ prefix ^ ")[\"']?$") (String.substring(q,0,start))
        andalso accepts ("^[\"']?" ^ finish) (String.extract(q,stop,NONE))
  val artistPrefix =
    "who (?:painted|sculpted|created|made) (?:the |a )?(?:painting |sculpture |artwork )?"
    ^ "|(?:which|what) artist (?:painted|sculpted|created|made) (?:the )?"
    ^ "|name the (?:artist|painter|sculptor) who (?:painted|sculpted|created|made) (?:the )?"
    ^ "|who is the (?:artist|painter|sculptor) (?:of|behind) (?:the )?"
    ^ "|name the (?:artist|painter|sculptor) (?:of|behind) (?:the )?"
  val poetPrefix =
    "who (?:wrote|composed|penned) (?:the poem )?"
    ^ "|(?:which|what) poet (?:wrote|composed|penned) (?:the poem )?"
    ^ "|who is the author of (?:the poem )?"
    ^ "|name the (?:author|poet) (?:of|behind) (?:the poem )?"
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
  val rowScopeGroups =
    List.tabulate (17,fn i => ("worldhistory",i,datedRow i)) @
    List.tabulate (34,fn i => ("arthistory",i,titleQuestion "arthistory" i artistPrefix)) @
    List.tabulate (11,fn j => let val i=j+10 in ("poetry",i,titleQuestion "poetry" i poetPrefix) end)

  val scopedRows : (string * (string -> bool)) list =
    map (fn (sid,i,accept) => (rowGuard sid i,accept))
      (rowScopeGroups @ [("medicine",0,humanMeasurement "body temperature"),
       ("medicine",1,humanMeasurement "resting (?:heart rate|pulse)"),
       ("medicine",2,humanMeasurement "blood pressure"),
       ("pets",6,adultTeeth "(?:dog|canine)" "(?:dogs|canines)"),
       ("pets",7,adultTeeth "(?:cat|feline)" "(?:cats|felines)"),
       ("law",8,marburyPrinciple),
       ("psychology",2,attribution "classical conditioning"),
       ("psychology",3,attribution "operant conditioning"),
       ("childdev",3,objectPermanenceStage),
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
       ("etiquette",15,breadPlatePlacement)])

  (* The admitted creator grammar surrounds exactly this row's known title.
     Preserve that matched title as answer context, never arbitrary question
     qualifiers. Regex span extraction and rendering remain untrusted. *)
  fun sourceSubject sid i q =
    if sid = "arthistory" orelse (sid = "poetry" andalso i >= 10) then
      let val text = normalize q
      in case Regex.search (compiled (rowGuard sid i)) text of
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
