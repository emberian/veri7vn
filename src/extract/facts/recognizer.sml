(* UNTRUSTED. The FactsOrgan recognizer (lane O19-facts). It computes the two
   inputs of the HOL kernel (Facts.organ_reply):
     - the narrowing verdict, a port of the shared narrow_v1.narrative
       (3+ sentences, more than 40 words, a RELATION or a RATE phrase);
     - the feature map: for a pattern string from the organ's HOL tables,
       whether Python `re.search(pattern, t, re.I)` would find a match in the
       whitespace-normalised turn t (" ".join(text.split())), computed with the
       backtracking matcher in commons.sml (Regex.compileI: case-insensitive inside the engine;
       patterns are used exactly as written, never lower-cased, so (?-i:...)
       and \S \D \W \B keep their meaning).
   medicine-r2's boundary patterns are matched against the same normalised text
   (the organ uses the raw text; they are single words under \b, so collapsing
   whitespace cannot change them). Patterns are compiled once and cached. *)
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

  (* The human-temperature row previously accepted arbitrary subjects; in
     family order, medicine then stole a dog's question from pets. Recognize
     only explicit human or unqualified constructions for this row. This is
     untrusted narrowing, not a claim to parse arbitrary biological subjects. *)
  val humanTemperatureGuard = "(?=.*\\bnormal\\b)(?=.*\\bbody temperature\\b)"
  val humanTemperatureQuestion = compiled
    "^(?:what is|what's|tell me) (?:the |a )?normal (?:(?:human|adult) )?body temperature(?: (?:of|for|in) (?:a |an |the )?(?:human|adult|person|humans|adults|people))?\\s*[?.]?\\s*$"

  fun features (t : string) : string -> bool =
    let val n = canonical (normalize t)
        val unquoted = withoutQuotes n
    in fn p => (p <> humanTemperatureGuard orelse
                    Option.isSome (Regex.search humanTemperatureQuestion n))
         andalso Option.isSome (Regex.search (compiled p)
         (if SOME p = literatureBlock then unquoted else n)) end
end
