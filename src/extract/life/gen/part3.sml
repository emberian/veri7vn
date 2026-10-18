
  (* ---------- microbiology v2 ---------- *)
  val SCI = ⟦(\d+(?:\.\d+)?)\s*(?:(?:x|×|\*)\s*10\s*\^?\s*([+-]?\d+)|e([+-]?\d+))?⟧
  val TU = ⟦\s*(minutes?|min|hours?|hrs?|h|days?)\b⟧
  val ASKS = ⟦\?|\b(?:find|calculate|compute|determine|estimate|what|how many|how long|give)\b⟧

  fun signedInt s =
    if String.isPrefix "+" s then valOf (Int.fromString (String.extract (s, 1, NONE)))
    else if String.isPrefix "-" s then ~ (valOf (Int.fromString (String.extract (s, 1, NONE))))
    else valOf (Int.fromString s)

  fun sciVal low m =
    let val e = case firstGroup low m [2, 3] of SOME x => signedInt x | NONE => 0
    in ratSci (g1 low m) e end

  fun ratTimes lit (k : int) =
    let val (n, d) = decParts lit in L.mk_rat (IntInf.* (n, IntInf.fromInt k)) d end
  fun ratDiv lit (k : int) =
    let val (n, d) = decParts lit in L.mk_rat n (IntInf.* (d, IntInf.fromInt k)) end

  fun minutesOf lit unit =
    ratTimes lit (if String.isPrefix "h" unit then 60 else if String.isPrefix "d" unit then 1440 else 1)

  (* Dilution powers and colon ratios are domain notation. Normalize only
     complete powers, then let shared exact tokenization preserve all signs,
     fractions and malformed runs. Never search a valid-looking numeric tail. *)
  fun microNotation low =
    let
      fun inverseExponent e = if String.isPrefix "-" e then String.extract (e,1,NONE)
        else "-" ^ (if String.isPrefix "+" e then String.extract(e,1,NONE) else e)
      val reciprocal = subWith ⟦(?<![\w.,+\-/^−])([+\-]?1)\s*[:/]\s*10\s*\^\s*(?:\(\s*([+-]?\d+)\s*\)|([+-]?\d+))(?![\d.\^\)])⟧
        (fn t => fn m => g1 t m ^ "e" ^ inverseExponent (valOf (firstGroup t m [2,3]))) low
      val paren = subWith ⟦(?<![\w.,+\-/^−])10\s*\^\s*\(\s*([+-]?\d+)\s*\)(?![\d.\^])⟧
                    (fn t => fn m => "1e" ^ g1 t m) reciprocal
      val power = subWith ⟦(?<![\w.,+\-/^−])10\s*\^\s*([+-]?\d+)(?![\d.\^\)])⟧
                    (fn t => fn m => "1e" ^ g1 t m) paren
      val ratio = subWith ⟦(?<=\d)\s*:\s*(?=[+\-−.\d])⟧ (fn _ => fn _ => "/") power
    in ratio end

  fun microDil low tokens : L.rat option =
    let
      fun binding (ExactNumeric.Number {start, stop, value, ...}) =
            let val prefix = String.substring (low, 0, start)
                val after = String.extract (low, stop, NONE)
            in if has ⟦^\s*dilution\b⟧ after orelse
                  has ⟦\bdilution\s*(?:factor\s*)?(?:of|is|=|:)?\s*$⟧ prefix
               then SOME value else NONE end
        | binding _ = NONE
    in case List.mapPartial binding tokens of
         [(n,d)] => SOME (L.mk_rat n d)
       | _ => NONE
    end

  fun microV1 t : L.mreq option =
    let
      val low = microNotation (lower t)
    in
      if has ⟦\bcfu\b|\bcolon(?:y|ies)\b|\bplate count\b⟧ low andalso has ⟦\bdilution\b|10\s*\^|\b1\s*[:/]\s*\d⟧ low then
        let
          val tokens = ExactNumeric.scan low
          val malformed = has ⟦\^⟧ low orelse List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
          fun role pat = List.mapPartial
            (fn ExactNumeric.Number {stop, value, ...} =>
                  let val rest = String.extract (low, stop, NONE)
                  in if has pat rest then SOME (value, rest) else NONE end
              | _ => NONE) tokens
          val colonies = role ⟦^\s*colon(?:y|ies)\b⟧
          val volumes = role ⟦^\s*(?:ml|µl|ul|microlit\w+|millilit\w+)\b⟧
          val dil = microDil low tokens
        in
          if malformed then SOME L.M_Unread
          else case (colonies, dil, volumes) of
            ([((cn, cd), _)], SOME d, [((vn, vd), unit)]) =>
              let
                val micro = has ⟦^\s*(?:µl|ul|microlit\w+)\b⟧ unit
                val vol = L.mk_rat vn (if micro then vd * 1000 else vd)
              in SOME (L.M_CFU (L.mk_rat cn cd, d, vol)) end
          | _ => SOME L.M_Unread
        end
      else
        case search ⟦\b(\d+|two|three|four|five|six)\s+(?:serial\s+)?(?:1\s*[:/]\s*(\d+)|(\d+)[- ]fold)\s+(?:serial\s+)?dilutions?\b⟧ low of
          SOME sm =>
            if has ⟦\btotal\b|\bfinal\b|\boverall\b⟧ low then
              let
                val ks = g1 low sm
                val k = case ks of "two" => 2 | "three" => 3 | "four" => 4 | "five" => 5 | "six" => 6 | _ => intOf ks
                val f = intOf (valOf (firstGroup low sm [2, 3]))
              in SOME (L.M_Serial (natI f, natI k)) end
            else microGrowth low
        | NONE => microGrowth low
    end
  and microGrowth low : L.mreq option =
    if not (has ⟦\bbacteri\w*\b|\bcells?\b|\bgeneration\b|\bdoubl\w*\b|\bbinary fission\b|\bculture\b|\be\.? coli\b|\bpopulation\b⟧ low) then NONE
    else
      let
        val gt = search (⟦\b(?:generation|doubling) time\s*(?:of|is|=)?\s*⟧ ^ N ^ TU ^ ⟦|\b(?:divides?|doubles?)\s+every\s+⟧ ^ N ^ TU) low
        val tt = search (⟦\b(?:after|in|for|over)\s+⟧ ^ N ^ TU) low
        val n0 = case search (⟦\b(?:starts? with|initial(?:ly)?|beginning with|begins with|starting with|inoculated with)\s+(?:a\s+)?⟧ ^ SCI ^ ⟦\s*(?:cells|bacteria|cfu)?⟧) low of
                   SOME m => SOME m
                 | NONE => search (SCI ^ ⟦\s*(?:cells|bacteria)\s*(?:initially|at the start|to start)⟧) low
        val nf = search (⟦\b(?:to|reaches|reach|grows? to|final(?: count| population)?(?: of| is)?|ends? with)\s+⟧ ^ SCI ^ ⟦\s*(?:cells|bacteria|cfu)?⟧) low
        fun gMin m = minutesOf (valOf (firstGroup low m [1, 3])) (valOf (firstGroup low m [2, 4]))
        fun tMin m = minutesOf (g1 low m) (valOf (grp low m 2))
      in
        case (gt, tt) of
          (SOME g, SOME t) =>
            if isSome n0 andalso has ⟦\bhow many\b|\bpopulation\b|\bnumber of (?:cells|bacteria)\b⟧ low
               andalso not (has ⟦\bhow many generations\b⟧ low)
            then SOME (L.M_GrowthN (sciVal low (valOf n0), gMin g, tMin t))
            else if has ⟦\bhow many generations\b⟧ low then SOME (L.M_Gens (tMin t, gMin g))
            else microTime low n0 nf tt
        | _ => microTime low n0 nf tt
      end
  and microTime low n0 nf tt : L.mreq option =
    case (n0, nf, tt) of
      (SOME a, SOME b, SOME t) =>
        if has ⟦\bgeneration time\b|\bdoubling time\b⟧ low
        then SOME (L.M_GenTime (sciVal low a, sciVal low b, minutesOf (g1 low t) (valOf (grp low t 2))))
        else NONE
    | _ => NONE

  fun micro text : L.reply option =
    let
      val t0 = collapse text
      val low0 = lower t0
    in
      if Narrow.narrative text andalso not (has ASKS low0) then NONE
      else
        let
          val NUM2 = ⟦(\d+(?:,\d{3})*(?:\.\d+)?(?:\s*(?:x|×|\*)\s*10\s*\^?\s*[+-]?\d+|e[+-]?\d+)?)⟧
          val UNIT2 = ⟦(?:cells|bacteria|bacterial cells|cfu|organisms)⟧
          val s1 = subWith (⟦\bfrom\s+⟧ ^ NUM2 ^ ⟦\s*⟧ ^ UNIT2 ^ ⟦\s+to\s+⟧ ^ NUM2 ^ ⟦\s*⟧ ^ UNIT2 ^ ⟦?|\bfrom\s+⟧ ^ NUM2 ^ ⟦\s+to\s+⟧ ^ NUM2 ^ ⟦\s*⟧ ^ UNIT2)
                     (fn t => fn m =>
                        "starting with " ^ valOf (firstGroup t m [1, 3]) ^ " cells, reaches " ^ valOf (firstGroup t m [2, 4]) ^ " cells") t0
          val s2 = subWith (⟦\b(?:a |the )?(?:bacterial )?(?:population|culture|sample|colony|inoculum) of\s+⟧ ^ NUM2 ^ ⟦\s*⟧ ^ UNIT2)
                     (fn t => fn m => "a culture starting with " ^ g1 t m ^ " cells") s1
          val s3 = subWith ⟦\btenfold\b⟧ (fn _ => fn _ => "10-fold") s2
          val s4 = subWith ⟦\bhundredfold\b⟧ (fn _ => fn _ => "100-fold") s3
          val t = subWith ⟦\b(successive|consecutive|sequential|repeated)\s+(?=1\s*[:/]|\d+[- ]fold)⟧ (fn _ => fn _ => "") s4
          val low = lower t
        in
          case microV1 t of
            SOME req =>
              let val r = L.m_reply req
              in if not (L.answered r) andalso not (has ⟦\d⟧ t) then NONE else SOME r end
          | NONE =>
              if has ⟦\d⟧ low andalso has ASKS low
                 andalso ((has ⟦\bdoubl\w*\b|\bgeneration\w*\b|\bbinary fission\b⟧ low
                           andalso has ⟦\bbacteri\w*\b|\bcells?\b|\bculture\b|\be\.? coli\b|\bpopulation\b⟧ low)
                          orelse (has ⟦\bcfu\b|\bcolon(?:y|ies)\b⟧ low andalso has ⟦\bdilution\b|10\s*\^⟧ low)
                          orelse has ⟦\bserial dilutions?\b⟧ low)
              then SOME (L.m_reply L.M_Unread)
              else NONE
        end
    end

  (* ---------- dispatch ---------- *)
  val organs = ["genetics-v2", "biology", "ecology", "forestry", "wildlife", "microbiology-v2"]

  fun byId id text : L.reply option =
    (case id of
       "genetics-v2" => genetics text
     | "biology" => biology text
     | "ecology" => ecology text
     | "forestry" => forestry text
     | "wildlife" => wildlife text
     | "microbiology-v2" => micro text
     | _ => NONE)
    handle e => (TextIO.output (TextIO.stdErr, "recognizer exception in " ^ id ^ ": " ^ exnMessage e ^ "\n"); NONE)

  (* family order: the organs whose trigger words are most specific first; a
     withheld reply (a decline) from an earlier organ is kept only if no later
     organ answers *)
  val familyOrder = ["genetics-v2", "biology", "wildlife", "forestry", "ecology", "microbiology-v2"]

  fun recognize mode text =
    if mode = "family" then
      let
        fun go [] kept = kept
          | go (id :: ids) kept =
              case byId id text of
                SOME r => if L.answered r then SOME (id, r)
                          else go ids (case kept of NONE => SOME (id, r) | k => k)
              | NONE => go ids kept
      in go familyOrder NONE end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
