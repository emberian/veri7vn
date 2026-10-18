(* UNTRUSTED. The English recognizer for the humanities family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/music-v2/organ_music_v1.py, organ_music_v2.py
     upstream/root/specialists/music-v2-r2/organ_music_v2_r2.py
     upstream/root/specialists/grammar/organ_grammar_v1.py
     upstream/root/specialists/mythology/organ_mythology_v1.py
     upstream/root/specialists/ushistory/organ_ushistory_v1.py
     upstream/root/specialists/library/organ_library_v1.py
     upstream/root/specialists/government/organ_government_v1.py
   and of their shared narrowing rule narrow_v1.py. It reads numbers, words and
   pattern hits off the question and builds a typed request for the verified
   kernel (Humanities.mreply, greply, yreply, hreply, lreply, vreply); it
   computes nothing. NONE means the organ returns None (not taken).

   Tables are not duplicated: row names come from the exported HOL tables
   (g2r_rows, r2g_rows, presidents, subject_order, ivl_order). What is ported by
   hand, and so untrusted, is the patterns, the branch order and the lists of
   rule patterns (events, government topics and facts), which tables_check.py
   compares with the organ files.

   Matching: text is lower-cased by the caller and patterns are written in lower
   case, except the music note patterns, which are case sensitive in the organ
   and are matched on the original text. The sharp and flat signs are mapped to
   # and b first. \w and \d are ASCII here. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Humanities.reply) option
end =
struct
  structure H = Humanities
  infix 1 |>
  fun x |> f = f x

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  val cacheCS : (string * Regex.regex) list ref = ref []
  fun reCS p =
    case List.find (fn (q, _) => q = p) (!cacheCS) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compileCS p in cacheCS := (p, r) :: !cacheCS; r end

  fun search p s = Regex.search (re p) s
  fun searchCS p s = Regex.search (reCS p) s
  fun findallCS p s = Regex.findall (reCS p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  fun replaceStr (pat : string) (rep : string) (s : string) : string =
    let
      val n = size pat
      fun go i acc =
        if i > size s - n then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (s, i, n) = pat then go (i + n) (rep :: acc)
        else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in if size s < n then s else go 0 [] end

  (* U+266F sharp sign, U+266D flat sign *)
  fun plainAccidentals s = replaceStr "\226\153\173" "b" (replaceStr "\226\153\175" "#" s)

  fun trimSet (cs : string) s =
    let
      val n = size s
      fun l i = if i < n andalso Char.contains cs (String.sub (s, i)) then l (i + 1) else i
      fun r j = if j > 0 andalso Char.contains cs (String.sub (s, j - 1)) then r (j - 1) else j
      val a = l 0
      val b = r n
    in if b <= a then "" else String.substring (s, a, b - a) end
  fun trim s = trimSet " \t\n\r" s

  (* decimal numeral to an exact rational, "1,000.50" allowed *)
  fun ratOf (lit0 : string) : H.rat =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val den = IntInf.pow (10, size fp)
    in H.mk_rat num den end
  fun ratIsPositive (lit : string) = List.exists (fn c => c >= #"1" andalso c <= #"9") (String.explode lit)

  fun mkInt (i : int) = H.Int_of_integer (IntInf.fromInt i)
  fun mkNat (i : int) = H.nat_of_integer (IntInf.fromInt i)
  fun intOfString s = valOf (Int.fromString s)

  (* ---------- narrow_v1 ---------- *)
  structure Narrow =
  struct
    fun words t = length (String.tokens Char.isSpace t)
    fun splits ends t =
      let
        val t = collapse t
        val n = size t
        fun go i acc =
          if i >= n then rev acc
          else if Char.isSpace (String.sub (t, i)) andalso i > 0
                  andalso Char.contains ends (String.sub (t, i - 1))
          then let fun skip j = if j < n andalso Char.isSpace (String.sub (t, j)) then skip (j + 1) else j
               in go (skip i) (i :: acc) end
          else go (i + 1) acc
      in (t, go 0 []) end
    fun sentences t =
      let val (s, sp) = splits ".!?" t in if s = "" then 0 else 1 + length sp end
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  (* the organs' wrapper: a withheld reply is kept only for a short direct question *)
  fun finish text (r : H.reply option) : H.reply option =
    case r of
      NONE => NONE
    | SOME rep =>
        if H.reply_kind rep = "silent" then NONE
        else if H.answered rep then SOME rep
        else if Narrow.short_direct text then SOME rep
        else NONE

  datatype res = Ret of H.reply option | Fall
  fun chain [] = NONE
    | chain (f :: fs) = case f () of Ret x => x | Fall => chain fs
  fun ret x = Ret x

  (* ====================== music ====================== *)
  structure Music =
  struct
    val NOTE = "\\b([A-G])(##|bb|#|b|x)?(?:\\s*(sharp|flat))?(-?\\d)?(?![\\w#])"
    val KEY = "\\b([A-G])(#|b)?(?:\\s*(sharp|flat))?\\s*(major|minor|maj|min)\\b"
    val noteWords = ["to", "and", "up", "down", "above", "below", "in", "at", "is", "or", "with", "has", "flat",
                     "sharp", "major", "minor", "than", "going", "ascending", "descending", "then"]
    fun letterOf c =
      case c of
        "C" => H.N_C | "D" => H.N_D | "E" => H.N_E | "F" => H.N_F | "G" => H.N_G | "A" => H.N_A | _ => H.N_B
    fun acc s =
      case s of "#" => 1 | "b" => ~1 | "##" => 2 | "x" => 2 | "bb" => ~2 | "sharp" => 1 | "flat" => ~1 | _ => 0
    fun lstrip s =
      let val n = size s
          fun go i = if i < n andalso Char.isSpace (String.sub (s, i)) then go (i + 1) else i
      in String.extract (s, go 0, NONE) end
    fun alphaPrefix s =
      let val n = size s
          fun go i = if i < n andalso Char.isAlpha (String.sub (s, i)) then go (i + 1) else i
      in String.substring (s, 0, go 0) end

    type pn = {letter : H.letter, acc : int, oct : int option}
    fun parse t (m : Regex.match) : pn =
      let
        val l = g1 t m
        val a1 = getOpt (grp t m 2, "")
        val a2 = getOpt (grp t m 3, "")
        val oc = Option.map intOfString (grp t m 4)
      in {letter = letterOf l, acc = acc a1 + acc a2, oct = oc} end

    (* notes_in: note tokens, skipping the article "A" and key names *)
    fun notesIn t : pn list =
      let
        fun keep (m as {stop, ...} : Regex.match) =
          let
            val rest = lstrip (String.extract (t, stop, NONE))
            val nxt = alphaPrefix rest
            val whole = Regex.whole t m
            val article = whole = "A" andalso nxt <> "" andalso Char.isLower (String.sub (nxt, 0))
                          andalso not (List.exists (fn w => w = lower nxt) noteWords)
            val isKey = nxt <> "" andalso List.exists (fn w => w = lower nxt) ["major", "minor", "maj", "min"]
          in not article andalso not isKey end
      in map (parse t) (List.filter keep (findallCS NOTE t)) end

    fun pnote (n : pn) = (#letter n, mkInt (#acc n))
    fun octOpt (n : pn) = Option.map mkInt (#oct n)

    val ivlHits = fn low => map (fn (name, _) => has ("\\b" ^ name ^ "\\b") low) H.ivl_order

    fun durOf s =
      case s of
        "whole" => H.D_whole | "half" => H.D_half | "quarter" => H.D_quarter | "eighth" => H.D_eighth
      | "sixteenth" => H.D_sixteenth | _ => H.D_thirty_second

    fun answer1 (t : string) : H.reply option =
      let
        val low = lower t
        val notes = notesIn t
        val key = case searchCS KEY t of
                    SOME m =>
                      let val a1 = getOpt (grp t m 2, "")
                          val a2 = getOpt (grp t m 3, "")
                          val mode = valOf (grp t m 4)
                      in SOME ((letterOf (g1 t m), acc a1 + acc a2), String.isPrefix "min" mode) end
                  | NONE => NONE
        val keyq = fn p => has p low
        fun cents () =
          if not (has "\\bcents?\\b" low) then Fall
          else
            let val fs = map (fn m => g1 low m) (findall "(\\d+(?:\\.\\d+)?)\\s*hz\\b" low)
            in case fs of
                 a :: b :: _ =>
                   if ratIsPositive a andalso ratIsPositive b
                   then ret (SOME (H.mreply (H.MCents (ratOf a, ratOf b))))
                   else ret NONE
               | _ => ret NONE
            end
        fun duration () =
          case (search "(\\d+(?:\\.\\d+)?)\\s*(?:bpm|beats per minute)\\b" low,
                search "\\b(dotted\\s+)?(whole|half|quarter|eighth|sixteenth|thirty-second)[- ]notes?\\b" low) of
            (SOME bm, SOME dm) =>
              if has "\\bhow long\\b|\\bduration\\b|\\bseconds\\b|\\bhow many (?:seconds|ms|milliseconds)\\b|\\blast\\b" low
              then
                let val b = g1 low bm
                in if not (ratIsPositive b) then ret NONE
                   else ret (SOME (H.mreply (H.MDur (ratOf b, isSome (grp low dm 1), durOf (valOf (grp low dm 2))))))
                end
              else Fall
          | _ => Fall
        fun keysig () =
          case key of
            SOME (n, minor) =>
              if keyq "\\bhow many (?:sharps|flats)\\b|\\bkey signature\\b|\\bsharps or flats\\b|\\bnumber of (?:sharps|flats)\\b"
              then ret (SOME (H.mreply (H.MKey ((#1 n, mkInt (#2 n)), minor)))) else Fall
          | NONE => Fall
        fun relative () =
          case key of
            SOME (n, minor) =>
              if keyq "\\brelative (?:major|minor)\\b"
              then ret (SOME (H.mreply (H.MRel ((#1 n, mkInt (#2 n)), minor)))) else Fall
          | NONE => Fall
        fun scale () =
          case key of
            SOME (n, minor) =>
              if keyq "\\bscale\\b" andalso keyq "\\bnotes?\\b|\\bspell\\b|\\bwhat (?:is|are)\\b|\\blist\\b"
              then
                (if minor andalso keyq "\\bharmonic\\b|\\bmelodic\\b" then ret NONE
                 else ret (SOME (H.mreply (H.MScale ((#1 n, mkInt (#2 n)), minor)))))
              else Fall
          | NONE => Fall
        fun semis () =
          if has "\\bhow many (?:semitones|half[- ]steps)\\b" low then
            let val hits = ivlHits low
            in if List.exists (fn x => x) hits then ret (SOME (H.mreply (H.MSemis hits))) else Fall end
          else Fall
        fun between () =
          if has "\\binterval\\b|\\bhow many (?:semitones|half[- ]steps)\\b" low andalso length notes >= 2 then
            let
              val n1 = List.nth (notes, 0)
              val n2 = List.nth (notes, 1)
              val asks = has "\\bhow many (?:semitones|half[- ]steps)\\b" low
            in ret (SOME (H.mreply (H.MBetween (pnote n1, octOpt n1, pnote n2, octOpt n2, asks)))) end
          else Fall
        fun midiNote () =
          case search "\\bmidi (?:note )?(?:number )?(\\d{1,3})\\b" low of
            SOME mm =>
              if has "\\bwhat note\\b|\\bwhich note\\b|\\bnote name\\b|\\bis what\\b" low
              then ret (SOME (H.mreply (H.MMidiNote (mkInt (intOfString (g1 low mm))))))
              else Fall
          | NONE => Fall
        fun midiNumber () =
          if has "\\bmidi (?:note )?number\\b|\\bwhat midi\\b|\\bmidi note (?:is|for|of)\\b" low andalso not (null notes) then
            let val n = List.nth (notes, 0)
                val (pnt, oc) = if has "\\bmiddle c\\b" low then ((H.N_C, mkInt 0), SOME (mkInt 4))
                                else (pnote n, octOpt n)
            in ret (SOME (H.mreply (H.MMidiNum (pnt, oc)))) end
          else Fall
        fun frequency () =
          if has "\\bfrequency\\b|\\bhz\\b|\\bhertz\\b|\\bpitch of\\b" low andalso (not (null notes) orelse has "\\bmiddle c\\b" low)
          then
            let
              val (pnt, oc) = if has "\\bmiddle c\\b" low then ((H.N_C, mkInt 0), SOME (mkInt 4))
                              else let val n = List.nth (notes, 0) in (pnote n, octOpt n) end
              val a = case search "\\ba4?\\s*(?:=|is|at)\\s*(\\d{3}(?:\\.\\d+)?)\\s*(?:hz)?\\b|\\b(\\d{3}(?:\\.\\d+)?)\\s*hz\\s*(?:tuning|reference|concert pitch)\\b" low of
                        SOME m => (case grp low m 1 of SOME s => ratOf s | NONE => ratOf (valOf (grp low m 2)))
                      | NONE => ratOf "440"
            in ret (SOME (H.mreply (H.MFreq (pnt, oc, a)))) end
          else Fall
      in
        chain [cents, duration, keysig, relative, scale, semis, between, midiNote, midiNumber, frequency]
      end

    val REL = "\\bwhich\\s+(major|minor)\\s+key\\s+is\\s+(?:the\\s+)?relative\\s+(?:of|to)\\s+([a-g](?:#|b)?\\s*(?:major|minor))\\b"
    val REF = "\\b(a4|a)\\s*(?:=|is tuned to|tuned to|at|is)\\s*(\\d{3}(?:\\.\\d+)?)\\s*(?:hz)?\\b"
    val NOT_MINE = "\\b(?:wavelength|speed of sound|in air|degrees c|metres?|meters?|m/s)\\b"
    val MINE = "\\b(?:note|notes|octave|a4|c4|semitones?|intervals?|chords?|scales?|key of|tempo|bpm)\\b"

    fun rtrimSet cs s =
      let fun r j = if j > 0 andalso Char.contains cs (String.sub (s, j - 1)) then r (j - 1) else j
      in String.substring (s, 0, r (size s)) end

    (* organ_music_v2_r2 (boundary), organ_music_v2 (reference and relative-key rewrites), then
       organ_music_v1.MusicOrgan.answer *)
    fun answer (r2 : bool) (text0 : string) : H.reply option =
      let
        val t0 = collapse (plainAccidentals text0)
        val low0 = lower t0
      in
        if r2 andalso has NOT_MINE low0 andalso not (has MINE low0) then NONE
        else
          let
            val t1 =
              case search REL low0 of
                SOME m => "What is the relative " ^ lower (g1 low0 m) ^ " of " ^ valOf (grp t0 m 2) ^ "?"
              | NONE => t0
            val low1 = lower t1
            val t2 =
              case search REF low1 of
                SOME (m as {start, stop, ...}) =>
                  if has "\\bfrequency\\b|\\bhz\\b|\\bhertz\\b|\\bpitch\\b" low1 then
                    let
                      val rest = trimSet " ,;:" (String.substring (t1, 0, start) ^ String.extract (t1, stop, NONE))
                      val rest2 =
                        case search "^(?:tuning|tuned|with|using|if)\\b\\s*(?:to\\b)?\\s*[,;:]?\\s*" (lower rest) of
                          SOME m2 => String.extract (rest, #stop m2, NONE)
                        | NONE => rest
                    in rtrimSet "?. " rest2 ^ " with A4 = " ^ valOf (grp low1 m 2) ^ " Hz?" end
                  else t1
              | NONE => t1
          in
            if Narrow.narrative t2 then NONE else finish t2 (answer1 (collapse t2))
          end
      end
  end

  (* ====================== grammar ====================== *)
  structure Grammar =
  struct
    fun quotesToApos s =
      List.foldl (fn (pat, s) => replaceStr pat "'" s) s
        ["\226\128\156", "\226\128\157", "\226\128\152", "\226\128\153", "\""]
    fun answer (text : string) : H.reply option =
      if Narrow.narrative text then NONE
      else
        let
          val low = quotesToApos (lower (collapse text))
          val wm = search "['\"]([a-z]+)['\"]|\\b(?:of|for|verb|noun|adjective|adverb|word)\\s+(?:the\\s+(?:verb|noun|word|adjective)\\s+)?([a-z]+)\\b" low
        in
          case wm of
            NONE => NONE
          | SOME m =>
              let
                val w = case grp low m 1 of SOME x => x | NONE => valOf (grp low m 2)
                val quoted = map (fn q => g1 low q) (findall "['\"]([a-z]+)['\"]" low)
                val cands = w :: List.filter (fn x => x <> w) quoted
                val req = H.GReq (has "\\bpast participle\\b" low,
                                  has "\\bpast (?:tense|simple)\\b|\\bsimple past\\b|\\bpreterite\\b" low,
                                  has "\\bplural\\b" low,
                                  has "\\bcomparative\\b|\\bsuperlative\\b" low,
                                  has "\\bsuperlative\\b" low,
                                  cands)
              in finish text (SOME (H.greply req)) end
        end
  end

  (* ====================== mythology ====================== *)
  structure Myth =
  struct
    (* Complete requests keep a known name from swallowing a different relation,
       another figure, a cultural qualifier or a second requested attribute.
       These finite English forms remain untrusted; the kernel owns all values. *)
    val endQuestion = "[?.]?$"
    fun answer (text : string) : H.reply option =
      if Narrow.narrative text then NONE
      else
        let
          val low = lower (collapse (trim text))
          fun whole p = has ("^(?:" ^ p ^ ")" ^ endQuestion) low
          (* An explicit goddess qualifier requires a supporting role row.
             The source's generic "god" forms include deities of either sex.
             Missing role evidence withholds instead of inventing a category. *)
          fun goddessCompatible name =
            not (has "\\bgoddess\\b" low) orelse
            (case List.find (fn (key, _) => key = lower name) H.roles of
               SOME (_, (_, description)) => has "\\bgoddess\\b" (lower description)
             | NONE => false)
          fun equivalent target source name =
            let
              val subject = "(?:the )?(?:" ^ source ^ " (?:(?:god|goddess|deity|figure|hero) )?)?" ^ name
              val relation = "(?:name|equivalent|counterpart)"
            in List.exists whole [
              "(?:what|who) is (?:the )?" ^ target ^ " " ^ relation ^ " (?:of|for) " ^ subject,
              "which " ^ target ^ " (?:god|goddess|deity|figure|hero) is (?:the )?(?:equivalent|counterpart) of " ^ subject,
              subject ^ " is (?:known as|called) what in " ^ target ^ " mythology",
              "what is " ^ subject ^ " (?:called|known as) in " ^ target ^ " mythology",
              "what is " ^ name ^ "'s " ^ target ^ " " ^ relation,
              "(?:give|name) (?:the )?" ^ target ^ " " ^ relation ^ " (?:of|for) " ^ subject
            ] end
          fun g2r () =
            let val hits = map (fn (name, _) => equivalent "roman" "greek" name andalso goddessCompatible name) H.g2r_rows
            in if List.exists (fn x => x) hits then ret (SOME (H.yreply (H.YG2R hits))) else Fall end
          fun r2g () =
            let val hits = map (fn (name, (_, greek)) => equivalent "greek" "roman" name andalso goddessCompatible greek) H.r2g_rows
            in if List.exists (fn x => x) hits then ret (SOME (H.yreply (H.YR2G hits))) else Fall end
          fun domain () =
            let
              fun findDomain (label, pantheon) =
                let
                  val deity = "(?:god|goddess|deity)"
                  val domain = "(?:the )?([a-z]+)"
                  val patterns = [
                    "(?:who|what) is (?:the )?" ^ label ^ " " ^ deity ^ " of " ^ domain,
                    "(?:name|identify) (?:the )?" ^ label ^ " " ^ deity ^ " of " ^ domain,
                    "in " ^ label ^ " mythology,? (?:who is|which deity is) (?:the )?" ^ deity ^ " of " ^ domain,
                    "which deity is associated with " ^ domain ^ " in " ^ label ^ " mythology"
                  ]
                  fun seek [] = NONE
                    | seek (pattern :: rest) =
                        (case search ("^(?:" ^ pattern ^ ")" ^ endQuestion) low of
                           NONE => seek rest
                         | SOME m =>
                             let
                               val d = g1 low m
                               val sourceRows = case pantheon of H.P_norse => H.norse_domain | _ => H.greek_domain
                               val compatible = case List.find (fn (key, _) => key = d) sourceRows of
                                   SOME (_, name) => goddessCompatible name | NONE => false
                             in if compatible then SOME (H.yreply (H.YDomain (pantheon, d))) else NONE end)
                in seek patterns end
              fun seek [] = Fall
                | seek (p :: rest) = (case findDomain p of NONE => seek rest | SOME r => ret (SOME r))
            in seek [("greek", H.P_greek), ("roman", H.P_roman),
                     ("norse", H.P_norse), ("viking", H.P_norse), ("scandinavian", H.P_norse)] end
          fun role () =
            let
              val patterns = ["who (?:is|was) ([a-z]+)",
                "what (?:is|was) ([a-z]+) the (?:god|goddess|deity) of",
                "what is the mythological role of ([a-z]+)"]
              fun seek [] = Fall
                | seek (p :: rest) =
                    (case search ("^(?:" ^ p ^ ")" ^ endQuestion) low of
                       NONE => seek rest
                     | SOME m => if goddessCompatible (g1 low m)
                         then ret (SOME (H.yreply (H.YRole (g1 low m)))) else ret NONE)
            in seek patterns end
        in finish text (chain [g2r, r2g, domain, role]) end
  end

  (* ====================== ushistory ====================== *)
  structure UsHistory =
  struct
    fun escape s = String.translate (fn #"." => "\\." | c => String.str c) s
    val OTHER = "\\b(?:canad\\w*|russi\\w*|english|england|britain|british|french|france|spanish|spain|mexic\\w*|irish|chin\\w*|"
      ^ "india\\w*|greek|finnish|nigeria\\w*|lebanese|syrian|korean|bolshevik\\w*)\\b"
    val endQuestion = "\\s*[?.]?\\s*$"
    val usPrefix = "(?:(?:us|u\\.s\\.|american|united states) )?"
    val usAfter = "(?: (?:of|in) the united states| in us history)?"
    val eventClauses = [
      "was the " ^ usPrefix ^ "declaration of independence (?:adopted|signed)",
      "was the " ^ usPrefix ^ "constitution signed",
      "was the " ^ usPrefix ^ "constitution ratified",
      "was the " ^ usPrefix ^ "bill of rights (?:ratified|adopted)",
      "(?:was the louisiana purchase|did the louisiana purchase (?:take place|occur))",
      "did the " ^ usPrefix ^ "civil war (?:begin|start)",
      "did the " ^ usPrefix ^ "civil war (?:end|finish)",
      "was the emancipation proclamation issued",
      "was (?:abraham )?lincoln assassinated",
      "was the (?:first )?(?:us )?transcontinental railroad completed",
      "(?:was the (?:us )?19th amendment ratified|did (?:us |american )?women (?:gain|get) the right to vote)",
      "(?:was (?:the )?(?:us )?(?:stock market crash|black tuesday)|did the (?:us )?stock market crash)",
      "(?:was the attack on pearl harbor|was pearl harbor attacked)",
      "was brown v\\.? board(?: of education)? decided",
      "was the (?:us )?civil rights act (?:signed|passed)",
      "was the (?:us )?voting rights act (?:signed|passed)",
      "(?:was the (?:apollo 11 |first )?moon landing|did apollo 11 land on the moon)",
      "did (?:richard )?nixon resign",
      "(?:were the (?:september 11|9/11) attacks|did the (?:september 11|9/11) attacks (?:occur|happen|take place))"]
    fun ordinalSuffix n = if n mod 100 >= 11 andalso n mod 100 <= 13 then "th"
      else case n mod 10 of 1=>"st"|2=>"nd"|3=>"rd"|_=>"th"
    fun answer (text : string) : H.reply option =
      if Narrow.narrative text then NONE
      else
        let
          val low = lower (collapse text)
          fun nth () =
            case search ("^who (?:was|is|served as) (?:the )?(\\d{1,2})(st|nd|rd|th) "
              ^ usPrefix ^ "president" ^ usAfter ^ endQuestion) low of
              SOME pm =>
                let val n=intOfString(g1 low pm)
                    val ending=valOf(Regex.group low pm 2)
                in if ending=ordinalSuffix n then ret(SOME(H.hreply(H.HNth(mkNat n)))) else ret NONE end
            | NONE => Fall
          fun num () =
            let val hits = map (fn name =>
                  has ("^(?:(?:which|what) number (?:us )?president (?:was|is) " ^ escape(lower name)
                   ^ "|what (?:was|is) " ^ escape(lower name) ^ "'s (?:us )?presidential number)"
                   ^ "(?: in us history| of the united states)?" ^ endQuestion) low) H.presidents
            in if List.exists (fn x => x) hits then ret(SOME(H.hreply(H.HNum hits))) else Fall end
          fun event () =
            let
              val us = has "\\bus\\b|\\bu\\.s\\.|\\bamerican?\\b|\\bunited states\\b" low
              val other = has OTHER low
              val hits = ListPair.mapEq (fn (rx,clause) => has rx low andalso
                has ("^(?:when|(?:in )?(?:what|which) year) " ^ clause ^ usAfter ^ endQuestion) low)
                (Rules.events,eventClauses)
            in if List.exists (fn x=>x) hits then ret(SOME(H.hreply(H.HEvent(hits,us,other)))) else Fall end
        in finish text (chain [nth,num,event]) end
  end

  (* ====================== library ====================== *)
  structure Library =
  struct
    fun digitOf c = if c = #"X" then 10 else Char.ord c - Char.ord #"0"
    fun answer (text : string) : H.reply option =
      if Narrow.narrative text then NONE
      else
        let
          val t = collapse text
          val low = lower t
          (* Prefer an identifier immediately following its own label. The old
             search could consume the target ISBN-13 label and then read the
             "10" in the later ISBN-10 label as part of the identifier. *)
          val isbnMatch =
            case search "\\b(isbn(?:-1[03])?|issn)\\b\\s*[:#]?\\s*([0-9][0-9 -]{5,20}[0-9x]?)" low of
              SOME m => SOME m
            | NONE => search "\\b(isbn(?:-1[03])?|issn)\\b[^0-9x]{0,20}([0-9][0-9 -]{5,20}[0-9x]?)" low
          val isbn =
            case isbnMatch of
              NONE => NONE
            | SOME m =>
                let
                  val kind = g1 low m
                  val raw = trim (valOf (grp t m 2))
                  val digits = List.filter (fn c => c <> #"-" andalso c <> #" ") (String.explode (String.map Char.toUpper raw))
                  val ac = has "\\bcheck digit\\b|\\bmissing (?:last )?digit\\b|\\blast digit\\b" low
                  val av = has "\\bvalid\\b|\\bcorrect\\b|\\bcheck (?:if|whether)\\b|\\bis this\\b" low
                  val cv = has "\\bconvert\\b|\\bisbn-?13\\b.*\\bfrom\\b|\\bto (?:an )?isbn-?13\\b|\\bequivalent isbn-?13\\b|\\bthirteen[- ]digit\\b|\\b13[- ]digit (?:isbn|version|equivalent)\\b" low
                in SOME (H.LIsbn (kind = "issn", map (fn c => mkNat (digitOf c)) digits, raw, ac, av, cv)) end
          fun lcc () =
            if has "\\blibrary of congress\\b|\\blcc\\b|\\blc class\\w*\\b|\\bcall number\\b" low then
              let
                val cm = searchCS "\\b(?:class|classification|subclass|letters?|call number(?:s)? (?:starting|beginning) with)\\s+([A-Z]{1,2})\\b" t
                fun subjects () =
                  let val hits = map (fn (subj, _) => has ("\\b" ^ subj ^ "\\b") low) H.subject_order
                  in if List.exists (fn x => x) hits then ret (SOME (H.lreply (H.LSubject hits))) else ret NONE end
              in
                case cm of
                  SOME m =>
                    if has "\\bwhat\\b|\\bwhich\\b|\\bsubject\\b|\\bcover\\w*\\b|\\bmean\\w*\\b|\\bfor\\b" low
                    then ret (SOME (H.lreply (H.LCode (g1 t m)))) else subjects ()
                | NONE => subjects ()
              end
            else Fall
        in
          case isbn of
            SOME req => finish text (SOME (H.lreply req))
          | NONE => finish text (chain [lcc])
        end
  end

  (* ====================== government ====================== *)
  structure Government =
  struct
    val ordAlt = String.concatWith "|" (map #1 Rules.ords)
    val AMEND = "\\b(\\d{1,2})(?:st|nd|rd|th)\\s+amendment\\b|\\bamendment\\s+(\\d{1,2})\\b|\\b(" ^ ordAlt ^ ")\\s+amendment\\b"
    fun roman s =
      case s of "i" => 1 | "ii" => 2 | "iii" => 3 | "iv" => 4 | "v" => 5 | "vi" => 6 | "vii" => 7 | d => intOfString d
    (* Closed requests for the source's structural counts, term lengths and
       age thresholds. Attendance, vacancy, quorum, particular-person ages and
       historical/foreign counts are different fields and are not discarded. *)
    val factRequests = [
      "^(?:how many (?:us |united states )?senators are there(?: in (?:the )?(?:us|united states|senate))?|what is the total number of (?:us|united states) senators|how many seats (?:are there|are) in the (?:us |united states )?senate)\\s*[?.]?\\s*$",
      "^(?:how many (?:voting )?(?:members|seats) (?:are )?in the (?:us )?house(?: of representatives)?|how many (?:voting )?(?:representatives|house members|members of the house) are there|what is the (?:size|total number of voting members) of the (?:us )?house of representatives)\\s*[?.]?\\s*$",
      "^(?:how many electors are there(?: in total| in the electoral college)?|how many electoral votes are there(?: in total)?|what is the total (?:number of )?(?:electors in the electoral college|electoral votes))\\s*[?.]?\\s*$",
      "^(?:how many electoral votes (?:are )?(?:needed|required|does it take) to (?:win|win the presidency|become president)|a candidate needs how many electoral votes to (?:become president|win the presidency))\\s*[?.]?\\s*$",
      "^(?:how many amendments does the (?:us |united states )?constitution have|how many times has the (?:us |united states )?constitution been amended)\\s*[?.]?\\s*$",
      "^(?:how many (?:judges|justices) (?:sit|are) on the (?:us |united states )?supreme court|how many supreme court justices are there)\\s*[?.]?\\s*$",
      "^(?:how long (?:is a|are) (?:us )?senat\\w* terms?|what is the (?:length of a senate term|term of a senator)|how many years does a senator serve per term)\\s*[?.]?\\s*$",
      "^(?:how long (?:is a|are) (?:house|representative\\w*) terms?|what is the (?:length of a house term|term of a representative)|how many years does a representative serve per term)\\s*[?.]?\\s*$",
      "^(?:how long (?:is a|are) presidential terms?|what is the (?:length of a presidential term|term of (?:the|a) president)|how many years does a president serve per term)\\s*[?.]?\\s*$",
      "^(?:what is the (?:minimum|youngest) age (?:to be|to become|at which someone can become) (?:the )?(?:us )?president|how old (?:must|does) (?:someone|one|a person) (?:be|have to be) to (?:be|become) (?:the )?(?:us )?president)\\s*[?.]?\\s*$",
      "^(?:what is the minimum age to (?:be|become) (?:a )?(?:us )?senator|how old (?:must|does) (?:someone|one|a person) (?:be|have to be) to (?:be|become) (?:a )?(?:us )?senator)\\s*[?.]?\\s*$",
      "^(?:what is the minimum age to (?:be|become) (?:a )?(?:us )?representative|how old (?:must|does) (?:someone|one|a person) (?:be|have to be) to (?:be|become) (?:a )?(?:us )?representative)\\s*[?.]?\\s*$",
      "^(?:how many amendments (?:are |are there )?in the bill of rights|the bill of rights (?:contains|has) how many amendments)\\s*[?.]?\\s*$"]
    fun answer (text : string) : H.reply option =
      if Narrow.narrative text then NONE
      else
        let
          val low = lower (collapse text)
          fun topic () =
            if has "\\bwhich amendment\\b|\\bwhat amendment\\b|\\bwhich constitutional amendment\\b|\\bwhat constitutional amendment\\b" low then
              let val hits = ListPair.mapEq (fn (i, rx) => has rx low orelse
                    (i = 6 andalso has "\\blimit\\w*\\b.*\\bpresident\\b.*\\btwo terms\\b" low))
                    (List.tabulate (length Rules.topics, fn i => i), Rules.topics)
              in if List.exists (fn x => x) hits then ret (SOME (H.vreply (H.VTopic hits))) else ret NONE end
            else Fall
          fun amend () =
            case search AMEND low of
              SOME am =>
                if has "\\bwhat\\b|\\bwhich\\b|\\babout\\b|\\bsay\\b|\\bprotect\\w*\\b|\\bcover\\w*\\b|\\bdo\\b|\\bguarantee\\w*\\b" low then
                  let val n = case grp low am 1 of
                                SOME d => intOfString d
                              | NONE => (case grp low am 2 of
                                           SOME d => intOfString d
                                         | NONE => #2 (valOf (List.find (fn (w, _) => w = valOf (grp low am 3)) Rules.ords)))
                  in ret (SOME (H.vreply (H.VAmend (mkNat n)))) end
                else Fall
            | NONE => Fall
          fun article () =
            case search "\\barticle\\s+(vii|vi|iv|v|iii|ii|i|[1-7])\\b(?:\\s+of the constitution)?" low of
              SOME ar =>
                if has "\\bconstitution\\b|\\bwhat\\b|\\bestablish\\w*\\b|\\bcover\\w*\\b|\\babout\\b" low
                then ret (SOME (H.vreply (H.VArticle (mkNat (roman (g1 low ar)))))) else Fall
            | NONE => Fall
          fun fact () =
            let val hits = map (fn pattern => has pattern low) factRequests
            in if List.exists (fn x => x) hits then ret (SOME (H.vreply (H.VFact hits))) else ret NONE end
        in
          if has "\\b(?:democrat|republican|biden|trump|obama|should|better|best|worst|vote for|opinion|agree)\\w*\\b" low then NONE
          else finish text (chain [topic, amend, article, fact])
        end
  end

  (* ====================== dispatch ====================== *)
  val organs = ["music-v2", "music-v2-r2", "grammar", "mythology", "ushistory", "library", "government"]

  fun run organ (q : string) : H.reply option =
    case organ of
      "music-v2" => Music.answer false q
    | "music-v2-r2" => Music.answer true q
    | "grammar" => Grammar.answer q
    | "mythology" => Myth.answer q
    | "ushistory" => UsHistory.answer q
    | "library" => Library.answer q
    | "government" => Government.answer q
    | _ => NONE

  (* family order: the identifier families first (they need an ISBN or a letter code), then the
     rest, music last *)
  val familyOrder = ["library", "government", "ushistory", "mythology", "grammar", "music-v2-r2"]

  fun recognize (mode : string) (q : string) : (string * H.reply) option =
    if mode = "family" then
      let fun go [] = NONE
            | go (og :: os) = (case run og q of SOME r => SOME (og, r) | NONE => go os)
      in go familyOrder end
    else (case run mode q of SOME r => SOME (mode, r) | NONE => NONE)
end
