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

  fun features (t : string) : string -> bool =
    let val n = normalize t
    in fn p => Option.isSome (Regex.search (compiled p) n) end
end
