
  (* ---------- microbiology v2 ---------- *)
  val ASKS = ⟦\?|\b(?:find|calculate|compute|determine|estimate|what|how many|how long|give)\b⟧

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
      else if has ⟦\bserial dilutions?\b|\bfold\s+dilutions?\b|\b1\s*/\s*\d+\s+(?:serial\s+)?dilutions?\b⟧ low
      then microSerial low
      else microGrowth low
    end
  and microSerial low : L.mreq option =
    let
      val text = subWith ⟦\b(two|three|four|five|six)\s+(?=(?:serial\s+)?(?:1\s*/|\d+[- ]fold))⟧
        (fn t => fn m => (case g1 t m of "two" => "2 " | "three" => "3 " | "four" => "4 " | "five" => "5 " | _ => "6 ")) low
      val tokens = ExactNumeric.scan text
      val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
      fun factors (ExactNumeric.Number {start,stop,value=(n,d),...}) =
            let val after = String.extract(text,stop,NONE)
            in if has ⟦^[- ]fold\s+(?:serial\s+)?dilutions?\b⟧ after
               then SOME(start,n,d)
               else if has ⟦^\s+(?:serial\s+)?dilutions?\b⟧ after andalso n=1
               then SOME(start,d,1) else NONE end
        | factors _ = NONE
      fun steps factorStart (ExactNumeric.Number {stop,value,...}) =
            if stop <= factorStart andalso has ⟦^\s+(?:serial\s+)?$⟧ (String.substring(text,stop,factorStart-stop))
            then SOME value else NONE
        | steps _ _ = NONE
    in
      if bad then SOME L.M_Unread
      else case List.mapPartial factors tokens of
        [(factorStart,f,1)] =>
          (case List.mapPartial (steps factorStart) tokens of
             [(k,1)] => if f>=0 andalso k>=0 andalso k<=10000 andalso IntInf.fromInt(size(IntInf.toString f))*k<=10000
                        then SOME (L.M_Serial(natOf f,natOf k))
                        else SOME L.M_Unread
           | _ => SOME L.M_Unread)
      | _ => SOME L.M_Unread
    end
  and microGrowth low : L.mreq option =
    if not (has ⟦\bbacteri\w*\b|\bcells?\b|\bgeneration\b|\bdoubl\w*\b|\bbinary fission\b|\bculture\b|\be\.? coli\b|\bpopulation\b⟧ low) then NONE
    else
      let
        val tokens = ExactNumeric.scan low
        val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
        fun parts (ExactNumeric.Number {start,stop,value,...}) = SOME(String.substring(low,0,start),String.extract(low,stop,NONE),value)
          | parts _ = NONE
        val quantities = List.mapPartial parts tokens
        fun count pred = List.mapPartial (fn (pre,post,value) =>
          if pred(pre,post) andalso has ⟦^\s*(?:(?:cells?|bacteria|cfu|organisms)\b|,|and\b|to\b|[?.;]|$)⟧ post
          then SOME value else NONE) quantities
        val initial = count(fn(pre,post) =>
          has ⟦\b(?:starts? with|initial(?:ly)?(?: count| population)?(?: of| is| =)?|beginning with|begins with|starting with|inoculated with|from|(?:population|culture|sample|colony|inoculum) of)\s+(?:a\s+)?$⟧ pre
          orelse has ⟦^\s*(?:cells|bacteria)\s*(?:initially|at the start|to start)\b⟧ post)
        val final = count(fn(pre,_) => has ⟦\b(?:to|reaches|reach|grows? to|final(?: count| population)?(?: of| is| =)?|ends? with)\s+$⟧ pre)
        fun scale (n,d) unit =
          if String.isPrefix "s" unit then (n,d*60)
          else if String.isPrefix "h" unit then (n*60,d)
          else if String.isPrefix "d" unit then (n*1440,d) else (n,d)
        fun time role = List.mapPartial (fn(pre,post,value) =>
          if has role pre then
            (case search ⟦^\s*(seconds?|sec|s|minutes?|mins?|hours?|hrs?|h|days?)\b⟧ post of
              SOME m => SOME(scale value (g1 post m)) | NONE => NONE)
          else NONE) quantities
        val generation = time ⟦\b(?:(?:generation|doubling) time\s*(?:(?:of|is|=)\s*)?|(?:divides?|doubles?)\s+every\s*)$⟧
        val elapsed = time ⟦\b(?:after|in|for|over)\s+$⟧
        fun rat(n,d)=L.mk_rat n d
        val askGens = has ⟦\bhow many generations\b|\bnumber of generations\b⟧ low
        val askTime = has ⟦(?:what|find|calculate|compute|determine|give)[^?;]*\b(?:generation|doubling) time\b⟧ low
        val targetText = case search ⟦\b(?:what|find|calculate|compute|determine|give)\b⟧ low of
            SOME m => String.extract(low,#start m,NONE) | NONE => low
        val outputUnits = List.mapPartial (fn(pat,u) => if has pat targetText then SOME u else NONE)
          [(⟦\bin\s+(?:seconds?|sec|s)\b⟧,L.M_Seconds),
           (⟦\bin\s+(?:minutes?|mins?)\b⟧,L.M_Minutes),
           (⟦\bin\s+(?:hours?|hrs?|h)\b⟧,L.M_Hours),
           (⟦\bin\s+days?\b⟧,L.M_Days)]
        val badUnit = askTime andalso (length outputUnits>1 orelse has ⟦\bin\s+(?:weeks?|months?|years?)\b⟧ targetText)
        val outputUnit = case outputUnits of [u] => u | _ => L.M_Minutes
      in
        if bad orelse badUnit then SOME L.M_Unread
        else if askGens then
          (case (elapsed,generation) of ([t],[g]) => SOME(L.M_Gens(rat t,rat g)) | _ => SOME L.M_Unread)
        else if askTime then
          (case (initial,final,elapsed,generation) of
             ([a],[b],[t],[]) => SOME(L.M_GenTimeIn(outputUnit,rat a,rat b,rat t))
           | _ => SOME L.M_Unread)
        else case (initial,generation,elapsed,final) of
          ([a],[g],[t],[]) => SOME(L.M_GrowthN(rat a,rat g,rat t))
        | _ => SOME L.M_Unread
      end

  fun micro text : L.reply option =
    let
      val t0 = collapse text
      val low0 = lower t0
    in
      if Narrow.narrative text andalso not (has ASKS low0) then NONE
      else
        let
          val s2 = subWith ⟦(?<![\w.,+\-/^−])([+\-]?(?:\d+(?:\.\d*)?|\.\d+))\s*(?:x|×|\*)\s*10\s*\^?\s*([+-]?\d+)(?![\d.\^])⟧
            (fn t => fn m => g1 t m ^ "e" ^ valOf(grp t m 2)) t0
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
