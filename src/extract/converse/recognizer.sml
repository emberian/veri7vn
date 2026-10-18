(* UNTRUSTED. The surface reader for the conversation kernel: a hand-port of
   the regex layer of upstream/root/wander-train/oracle_release_runtime_ao.py
   (the M53 meta-fold runtime). Everything it does is decide WHICH typed
   reading a turn's surface has; the kernel (Converse.rewrite / .form, from
   Converse.thy) owns the referent resolution, the constructions, the probe
   gate and the fallback, and its theorems hold for every reading produced
   here.

   Ported VERBATIM, including one quirk: in the organ, REPAIR and OPENER are
   compiled WITHOUT re.I while ELLIPSIS, BARE, DEICTIC and CONTINUATION carry
   it - so "I meant volcanoes" converts but "I meant Volcanoes" does not, and
   capitalized openers ("Tell me about earthquakes.") never match OPENER even
   though the M53 cluster support table that motivated the construction lists
   them capitalized. That is reproduced here (case-sensitive match on the
   preserved-case surface for those two; lowercased text for the re.I ones)
   rather than silently fixed; the quirk is reported in the scout report.

   Two documented, decision-neutral differences: text lowercased for the
   case-insensitive patterns makes captured groups lowercase (the organ keeps
   case in the rewritten form); and Python's rstrip("?.!") for the PREDICATE_OF
   key lookup is reproduced (trailing punctuation only). *)
structure Recognizer =
struct
  structure R = Regex
  structure K = Converse

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)
  fun lower s = String.map Char.toLower s
  fun rstrip_punct s =
    let fun go n = if n > 0 andalso List.exists (fn c => c = #"?" orelse c = #"!" orelse c = #".")
                                      (String.explode (String.substring (s, n - 1, 1)))
                   then go (n - 1) else n
    in String.substring (s, 0, go (size s)) end

  (* oracle_release_runtime_ao.py lines 25-32, verbatim; the case flags are
     the organ's own (see the header note) *)
  val deictic = R.compile "\\b(it|there|that|this|its|they|them|those|these|the same)\\b"
  val repair = R.compile "^(?:i meant|i mean|no,?\\s+|sorry,?\\s+)(.+?)\\.?$"
  val opener = R.compile "^(?:tell me about|talk about|describe)\\s+(.+?)\\.?$"
  val ellipsis = R.compile "^(?:and|what about|the same for)\\s+(.+?)\\??$"
  val bare = R.compile "^(?:the\\s+)?[a-z][a-z \\-']{2,40}$"
  val continuation =
    R.compile ("^(?:go on|more|tell me more|more about (?:that|it)|what else|continue|"
               ^ "thanks|thank you|ok|okay|got it|great|why|how do you know|"
               ^ "what is your source|why did you say that)[?.!]*$")

  (* the PREDICATE_OF keys, in the organ's order; the templates live in the
     kernel's predicate_of table (checked against the Python dict by
     tables_check.py) *)
  val pred_keys =
    ["what lives there", "is it big", "where is it", "how old is it",
     "who discovered it", "what is it made of", "is that true"]

  (* _live_topic's grounding walk (ao lines 61-73): the opener forms that make
     a turn a GROUNDING turn, and the conversion form that carries a resolved
     topic *)
  val opens_topic = R.compile "^(?:summari[sz]e|what is|tell me about|describe)\\s+(.+?)[.?!]*$"
  val conv_topic = R.compile "^summari[sz]e\\s+(.+?)[.?!]*$"

  fun group1 (m : R.match) (s : string) : string = valOf (R.group s m 1)

  (* read : string -> K.reading - one typed reading, by _convert's precedence *)
  fun read (raw : string) : K.reading =
    let
      val s = collapse raw                       (* ao normalizes whitespace *)
      val low_all = lower s                      (* for the re.I patterns *)
      fun is_deictic t = isSome (R.search deictic t)
    in
      case R.search repair s of                  (* case-sensitive, verbatim *)
        SOME m => K.Repair (group1 m s, is_deictic (group1 m s))
      | NONE =>
      case R.search opener s of                  (* case-sensitive, verbatim *)
        SOME m => K.Opener (group1 m s, is_deictic (group1 m s))
      | NONE =>
      case R.search ellipsis low_all of
        SOME m => K.Ellipsis (group1 m low_all, is_deictic (group1 m low_all))
      | NONE =>
        (* the bare-phrase branch: <= 4 words, no question mark, not owned by
           the acts layer *)
        if isSome (R.search bare low_all)
           andalso length (String.tokens Char.isSpace s) <= 4
           andalso not (String.isSuffix "?" s)
           andalso (R.search continuation low_all = NONE)
        then K.Bare s
        else
          (* the deictic branch: a known predicate row, or a free surface split
             around its FIRST deictic occurrence (DEICTIC.sub topic s count=1) *)
          (case List.find (fn k => k = rstrip_punct low_all) pred_keys of
             SOME k => K.Pred k
           | NONE =>
               (case R.search deictic low_all of
                  SOME {start, stop, ...} =>
                    K.Free_deictic (String.substring (low_all, 0, start),
                                    String.extract (low_all, stop, NONE))
                | NONE =>
                    if isSome (R.search continuation low_all) then K.Continuation else K.Plain))
    end

  (* grounded : string -> string -> string option
     the topic a dispatched turn opened: the opener forms on the ORIGINAL
     surface (the transition shows the original), else the conversion's
     resolved "Summarize <topic>." form *)
  fun grounded (surface : string) (dispatched : string) : string option =
    case R.search opens_topic (lower surface) of
      SOME m => SOME (collapse (group1 m (lower surface)))
    | NONE =>
        (case R.search conv_topic (lower dispatched) of
           SOME m => SOME (collapse (group1 m (lower dispatched)))
         | NONE => NONE)
end
