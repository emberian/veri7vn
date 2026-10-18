
  fun litPos lit = IntInf.> (#1 (decParts lit), 0)

  (* ---------- ecology ---------- *)
  fun ecoCounts low : IntInf.int list option =
    case search ⟦\b(?:counts?|abundances?|individuals|numbers?)\b[^0-9]{0,30}?((?:\d+(?:,\d{3})*\s*(?:,|and|;)\s*)+\d+(?:,\d{3})*)⟧ low of
      NONE => NONE
    | SOME m =>
        let
          val g = g1 low m
          val g' = subWith ⟦(\d),(\d{3})\b⟧ (fn t => fn mm => g1 t mm ^ valOf (grp t mm 2)) g
          val vals = map (fn mm => bigOf (Regex.whole g' mm)) (findall ⟦\d+(?:,\d{3})*⟧ g')
        in if length vals >= 2 then SOME vals else NONE end

  val ecoUnits = ⟦(years?|generations?|days?|hours?|months?)⟧
  val ecoUnits2 = ⟦(years?|generations?|days?|months?)⟧

  fun ecoTime low units =
    case search (⟦\bafter\s+⟧ ^ N ^ ⟦\s*⟧ ^ units ^ ⟦\b|\bin\s+⟧ ^ N ^ ⟦\s*⟧ ^ units ^ ⟦\b⟧) low of
      NONE => NONE
    | SOME m => SOME (ratOf (valOf (firstGroup low m [1, 3])))

  (* Bind quantity roles to full shared numeric tokens. A target clause is
     independent of the input declarations; a supplied growth rate is not
     itself a request to return a growth rate. *)
  fun ecoRest low : L.ereq option =
    let
      val tokens = ExactNumeric.scan low
      val malformed = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
      fun fields prefixPat suffixPat = List.mapPartial
        (fn ExactNumeric.Number {start, stop, value=(n,d)} =>
              let val prefix = String.substring (low, 0, start)
                  val suffix = String.extract (low, stop, NONE)
              in if has prefixPat prefix andalso has suffixPat suffix
                 then SOME ((n,d),suffix) else NONE end
          | _ => NONE) tokens
      fun one rows = case rows of [v] => SOME v | _ => NONE
      fun rat rows = Option.map (fn ((n,d),_) => L.mk_rat n d) (one rows)
      val n = rat (fields ⟦\b(?:(?:initial|starting|current) (?:population|size)|population|n0?)\s*(?:of|is|=)?\s*$⟧ ⟦^⟧)
      val k = rat (fields ⟦\b(?:carrying capacity(?:\s*\(k\))?|k)\s*(?:of|is|=)?\s*$⟧ ⟦^⟧)
      val rate = one (fields ⟦\b(?:(?:intrinsic |per capita )?(?:growth )?rate(?:\s*\(r\))?|r)\s*(?:of|is|=)?\s*$⟧ ⟦^⟧)
      val r = Option.map (fn ((num,den),suffix) => L.mk_rat num
                (if has ⟦^\s*%⟧ suffix then den * 100 else den)) rate
      val timeEntry = one (fields ⟦\b(?:after|in|at(?:\s+t\s*=)?)\s*$⟧ (⟦^\s*⟧ ^ ecoUnits ^ ⟦\b⟧))
      val time = Option.map (fn ((num,den),_) => L.mk_rat num den) timeEntry
      fun namedUnit suffix =
        let val suffix = subWith ⟦^\s*%\s*⟧ (fn _ => fn _ => "") suffix
        in case search (⟦^\s*(?:per\s+|/\s*)?⟧ ^ ecoUnits ^ ⟦\b⟧) suffix of
          SOME m => SOME (String.sub (g1 suffix m, 0)) | NONE => NONE end
      val mixedUnits = case (rate,timeEntry) of
        (SOME (_,rs),SOME (_,ts)) =>
          (case (namedUnit rs,namedUnit ts) of (SOME a,SOME b) => a <> b | _ => false)
      | _ => false
      val asks = findall ⟦\b(?:what|how|calculate|find|estimate|predict|determine)\b⟧ low
      val target = case rev asks of
          (m : Regex.match) :: _ => String.extract (low, #start m, NONE)
        | [] => lower (Narrow.last_sentence low)
      val wantRate = has ⟦\bdn\s*/\s*dt\b|\bhow fast\b|\bgrowth rate\b|\brate of (?:growth|change)\b⟧ target
      val wantDouble = has ⟦\bdoubling time\b|\bhow long to double\b⟧ target
      val wantPopulation = has ⟦\bpopulation\b|\bhow many\b|\bsize\b|\b(?:calculate|find|estimate|predict|determine)\s+n\b⟧ target
      val logistic = has ⟦\blogistic\b|\bcarrying capacity\b⟧ low
      val exponential = has ⟦\bexponential\w*\b|\bgrow\w*\b⟧ low
      val lambda = rat (fields ⟦(?:\blambda(?:\s*\(λ\))?|λ|\bfinite rate of increase)\s*(?:of|is|=)?\s*$⟧ ⟦^⟧)
    in
      if malformed orelse mixedUnits then NONE
      else if logistic then
        (case (r,n,k) of
           (SOME rv,SOME nv,SOME kv) =>
             if wantRate then (case time of
                 SOME tv => SOME (L.E_LogRateAt (rv,nv,kv,tv))
               | NONE => SOME (L.E_LogRate (rv,nv,kv)))
             else if wantPopulation then Option.map (fn tv => L.E_LogN (rv,nv,kv,tv)) time
             else NONE
         | _ => NONE)
      else if exponential andalso not (isSome k) andalso isSome r then
        if wantDouble then Option.map L.E_Doubling r
        else (case (r,n,time) of
          (SOME rv,SOME nv,SOME tv) =>
            if wantRate then SOME (L.E_ExpRateAt (rv,nv,tv))
            else if wantPopulation then SOME (L.E_ExpN (rv,nv,tv)) else NONE
        | _ => NONE)
      else case (lambda,n,time) of
        (SOME lv,SOME nv,SOME tv) => if wantPopulation andalso not wantRate then SOME (L.E_Geom (lv,nv,tv)) else NONE
      | _ => NONE
    end

  fun ecology text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.e_reply r)
        fun rest () = case ecoRest low of NONE => NONE | SOME r => fin r
      in
        if has ⟦\bshannon\b|\bsimpson\w*\b|\bevenness\b|\bdiversity index\b|\bspecies richness\b⟧ low then
          (case ecoCounts low of
             NONE => NONE
           | SOME c =>
               let
                 val total = List.foldl IntInf.+ 0 c
                 val cs = map natOf c
               in
                 if total <= 0 then NONE
                 else if has ⟦\bevenness\b⟧ low then fin (L.E_Evenness cs)
                 else if has ⟦\bshannon\b⟧ low then fin (L.E_Shannon cs)
                 else if has ⟦\bsimpson\w*\b⟧ low then
                   (if total < 2 then NONE
                    else if has ⟦\breciprocal\b|\binverse\b|\b1\s*/\s*d\b⟧ low then fin (L.E_SimpInv cs)
                    else if has ⟦\bdiversity\b|\b1\s*-\s*d\b⟧ low then fin (L.E_SimpDiv cs)
                    else fin (L.E_SimpD cs))
                 else if has ⟦\brichness\b⟧ low then fin (L.E_Richness cs)
                 else rest ()
               end)
        else rest ()
      end

  (* ---------- forestry ---------- *)
  val FN = ⟦(\d+(?:\.\d+)?)⟧

  fun forestry text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.f_reply r)
        val inchPat = FN ^ ⟦[- ]?(?:inch|in\.?|")⟧
      in
        if not (has ⟦\btrees?\b|\blogs?\b|\bdbh\b|\bbasal area\b|\bstand\b|\btimber\b|\bforest\w*\b|\bclinometer\b|\bdoyle\b|\bsmalian\b|\bseedlings?\b|\bplanting\b⟧ low)
        then NONE
        else if has ⟦\bdoyle\b⟧ low then
          let
            val d = search (inchPat ^ ⟦\s*(?:small[- ]end\s*)?(?:diameter|dib|log)?|\bdiameter\s*(?:of|is)?\s*⟧ ^ FN ^ ⟦\s*(?:inches|in)⟧) low
            val l = search (FN ^ ⟦[- ]?(?:foot|feet|ft)\b⟧) low
          in
            case (d, l) of
              (SOME dm, SOME lm) => fin (L.F_Doyle (ratOf (valOf (firstGroup low dm [1, 2])), ratOf (g1 low lm)))
            | _ => NONE
          end
        else if has ⟦\bsmalian\b|\bcubic (?:feet|foot) (?:in|of) (?:the |a |this )?log\b|\blog volume\b⟧ low then
          let
            val ds = map (fn m => g1 low m) (findall inchPat low)
            val l = search (FN ^ ⟦[- ]?(?:foot|feet|ft)\b\s*(?:long)?⟧) low
          in
            case (ds, l) of
              (d1 :: d2 :: _, SOME lm) => fin (L.F_Smalian (ratOf d1, ratOf d2, ratOf (g1 low lm)))
            | _ => NONE
          end
        else
          let
            val sp = search (FN ^ ⟦\s*(?:ft|feet|foot|')?\s*(?:x|×|by)\s*⟧ ^ FN ^ ⟦\s*(?:ft|feet|foot|')\s*(?:spacing|apart|grid)?⟧) low
          in
            if isSome sp andalso has ⟦\bper acre\b|\ban acre\b|\btrees per acre\b|\bhow many (?:trees|seedlings)\b⟧ low
               andalso has ⟦\bspac\w*\b|\bplant\w*\b|\bgrid\b⟧ low
            then
              let val m = valOf sp
                  val a = ratOf (g1 low m) val b = ratOf (valOf (grp low m 2))
              in if not (litPos (g1 low m)) orelse not (litPos (valOf (grp low m 2))) then NONE else fin (L.F_Tpa (a, b)) end
            else if has ⟦\bheight\b|\bhow tall\b⟧ low andalso has ⟦\bangle\b|\bdegrees?\b|°|\bclinometer\b⟧ low then
              let
                val dist = search (FN ^ ⟦\s*(ft|feet|m|meters?|metres?)\s*(?:away|from the (?:tree|base)|from the trunk)|\b(?:standing|distance of|from)\s*⟧ ^ FN ^ ⟦\s*(ft|feet|m|meters?|metres?)⟧) low
                val ang = search (FN ^ ⟦\s*(?:°|degrees?\b)⟧) low
              in
                case (dist, ang) of
                  (SOME dm, SOME am) =>
                    let
                      val (dv, du) = case grp low dm 1 of
                                       SOME v => (v, valOf (grp low dm 2))
                                     | NONE => (valOf (grp low dm 3), valOf (grp low dm 4))
                      val eye = search (⟦\beye (?:height|level)\s*(?:of|is)?\s*⟧ ^ FN ^ ⟦\s*(?:ft|feet|m|meters?)⟧) low
                    in
                      fin (L.F_Height (ratOf dv, ratOf (g1 low am), Option.map (fn m => ratOf (g1 low m)) eye,
                                       String.isPrefix "f" du))
                    end
                | _ => NONE
              end
            else
              let
                val dbh = search (⟦\b(?:dbh|diameter(?: at breast height)?)\s*(?:of|is|=)?\s*⟧ ^ FN ^ ⟦\s*(inches|inch|in\b|"|cm)|⟧ ^ FN ^ ⟦[- ]?(inches|inch|in\b|"|cm)\s*(?:dbh|diameter)⟧) low
              in
                case dbh of
                  SOME m =>
                    if has ⟦\bbasal area\b⟧ low then
                      let
                        val (d, u) = case grp low m 1 of
                                       SOME v => (v, valOf (grp low m 2))
                                     | NONE => (valOf (grp low m 3), valOf (grp low m 4))
                        val tpa = search (FN ^ ⟦\s*trees\s*(?:per|an|/)\s*acre⟧) low
                      in
                        if u = "cm" then fin (L.F_BAm (ratOf d))
                        else case tpa of
                               SOME tm => fin (L.F_BAPA (ratOf d, ratOf (g1 low tm)))
                             | NONE => fin (L.F_BA (ratOf d))
                      end
                    else NONE
                | NONE => NONE
              end
          end
      end

  (* ---------- wildlife ---------- *)
  val MARK = ⟦(?:marked|tagged|banded|marking|tagging|banding)⟧
  val CAP = ⟦(?:caught|captured|trapped|netted|sampled|collected|seined)⟧

  fun roles low : IntInf.int option * IntInf.int option * IntInf.int option =
    let
      val outM = ref (NONE : IntInf.int option)
      val outC = ref (NONE : IntInf.int option)
      val outR = ref (NONE : IntInf.int option)
      fun setdef r v = case !r of NONE => r := SOME v | SOME _ => ()
      fun step (mt : Regex.match) =
        let
          val s = #start mt
          val e = #stop mt
          val v = bigOf (g1 low mt)
          val b0 = Int.max (0, s - 45)
          val bef = String.substring (low, b0, s - b0)
          val aft0 = String.substring (low, e, Int.min (60, size low - e))
          val aft = hd (String.fields (fn c => c = #"," orelse c = #";" orelse c = #".") aft0)
          val ofthe = anchored ⟦\s+of\s+the\s+(\d+(?:,\d{3})*)⟧ aft
        in
          if isSome ofthe andalso not (isSome (!outR)) then
            (outR := SOME v; setdef outC (bigOf (g1 aft (valOf ofthe))))
          else if isSome (anchored ⟦\s+(?:\w+\s+){0,2}?(?:of (?:them|these|which)\b|(?:were|was|had been|are)\s+(?:already|previously)\b|recaptur|(?:marked|tagged|banded) ones\b|carried|bore|had (?:tags|marks|bands)|with (?:tags|marks|bands))⟧ aft)
                  orelse has ⟦\b(?:recaptured|contained|including|found)\s+$⟧ bef
                  orelse has ⟦\b(?:recaptured|recaptures|recapture count)\s*(?:of|was|were|=|:)?\s*$⟧ bef
          then setdef outR v
          else if has (⟦\bsecond (?:sample|capture|survey|session|trapping)\s+of\s+$⟧) bef
                  orelse has (⟦\b(?:later|again|second|next|afterwards)\b[^.;]{0,30}⟧ ^ CAP ^ ⟦\s+$⟧) bef
                  orelse (has (CAP ^ ⟦\s+$⟧) bef
                          andalso has ⟦^\s+\w*\s*(?:in|during|on)\s+(?:the|a)\s+second\b|^[^.;]{0,40}\b(?:second|later|again)\b⟧ aft)
                  orelse isSome (anchored (⟦\s+(?:\w+\s+){0,2}?⟧ ^ CAP ^ ⟦\s+(?:in|during|on)\s+(?:the|a)\s+(?:second|recapture)⟧) aft)
                  orelse (has (⟦\b⟧ ^ CAP ^ ⟦\s+$⟧) bef andalso has ⟦\b(?:later|second|again)\b⟧ bef)
          then setdef outC v
          else if has (MARK ^ ⟦\s+(?:and released\s+)?$⟧) bef
                  orelse isSome (anchored (⟦\s+(?:\w+\s+){0,2}?(?:were |was |had been |are )?⟧ ^ MARK ^ ⟦\b⟧) aft)
          then setdef outM v
          else ()
        end
      val _ = List.app step (findall ⟦(?<![\d.,])(\d+(?:,\d{3})*)(?![\d.,]*\d)⟧ low)
    in (!outM, !outC, !outR) end

  val animals = ⟦(?:animals|fish|deer|birds|turtles|frogs|mice|rabbits|butterflies|beetles|trout|salamanders|individuals|lizards|bats|squirrels)⟧

  fun wildlife text : L.reply option =
    let
      val t0 = String.concatWith " " (String.tokens Char.isSpace text)
      val low0 = lower t0
      val mr = has ⟦\b(?:marked|tagged|banded|recaptur\w*|mark[- ](?:and[- ])?recapture)\b⟧ low0
      val mrTurn = mr andalso Narrow.sentences t0 <= 4 andalso Narrow.words t0 <= 60
    in
      if Narrow.narrative text andalso not mrTurn then NONE
      else
        let
          val low = low0
          fun fin (r : L.reply) =
            if L.answered r orelse Narrow.short_direct text orelse mrTurn then SOME r else NONE
          val mrGate = has ⟦\bmark[- ](?:and[- ])?recapture\b|\blincoln[- ]petersen\b|\bchapman\b|\brecaptur\w*\b|\btagged\b|\bbanded\b|\bmarked\b⟧ low
                       andalso has ⟦\bestimate\w*\b|\bpopulation\b|\bhow many\b⟧ low
        in
          if mrGate then
            let
              val (m, c, r) = roles low
              val onat = Option.map natOf
            in fin (L.w_reply (L.W_Lincoln (onat m, onat c, onat r, has ⟦\bchapman\b⟧ low))) end
          else
            let
              val dens = search (N ^ ⟦\s+⟧ ^ animals ^ ⟦\b[^.?]{0,40}?\b(?:in|on|across|over)\s+(?:an?\s+)?(\d+(?:\.\d+)?)\s*(hectares?|ha|acres?|km2|km²|square (?:kilomet(?:er|re)s?|miles?)|sq mi|mi2)⟧) low
            in
              case dens of
                SOME dm =>
                  if has ⟦\bdensity\b|\bper (?:hectare|acre|km|square)\b⟧ low then
                    let
                      val a = ratOf (valOf (grp low dm 2))
                      val u0 = valOf (grp low dm 3)
                      val u = if String.isSuffix "s" u0 then String.substring (u0, 0, size u0 - 1) else u0
                    in
                      if not (litPos (valOf (grp low dm 2))) then NONE else fin (L.w_reply (L.W_Density (natS (g1 low dm), a, u)))
                    end
                  else wSurv low fin
              | NONE => wSurv low fin
            end
        end
    end
  and wSurv low fin : L.reply option =
    let
      val surv = search (N ^ ⟦\s+(?:of\s+\d+(?:,\d{3})*\s+)?(?:\w+\s+){0,2}?(?:survived|were still alive|remained alive|lived)\b⟧) low
      (* Explicit "s of n" roles take precedence over a nearby monitored verb.
         Otherwise the old leftmost match can read "75 of 100 monitored" as
         75 starting animals and silently turn mortality into zero. *)
      val start = case search ⟦\b(?:of|out of|from)\s+(\d+(?:,\d{3})*)\b⟧ low of
          SOME m => SOME m
        | NONE => search ⟦(\d+(?:,\d{3})*)\s+(?:\w+\s+){0,2}?(?:were )?(?:released|tagged|collared|monitored|hatched|born)\b⟧ low
    in
      case (surv, start) of
        (SOME sm, SOME st) =>
          if has ⟦\bsurvival\b|\bmortality\b|\bdeath rate\b⟧ low then
            let
              val s = bigOf (g1 low sm)
              val n0 = bigOf (valOf (firstGroup low st [1, 2]))
            in
              if n0 <= 0 orelse s > n0 then NONE
              else fin (L.w_reply (L.W_Surv (natOf s, natOf n0, has ⟦\bmortality\b|\bdeath rate\b⟧ low)))
            end
          else NONE
      | _ => NONE
    end
