
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
        val low = lower(collapse text)
        fun fin r = gate text (L.f_reply r)
        fun unread() = gate text L.f_unread
        val tokens = ExactNumeric.scan low
        val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
        fun parts(ExactNumeric.Number{start,stop,value,...}) = SOME(start,stop,value,String.substring(low,0,start),String.extract(low,stop,NONE))
          | parts _ = NONE
        val numbers=List.mapPartial parts tokens
        fun rat(n,d)=L.mk_rat n d
        fun scale(n,d)(a,b)=(n*a,d*b)
        fun lengthUnit post =
          case search ⟦^[- ]*(inches|inch|in\b|"|feet|foot|ft\b|cm\b|centimeters?|centimetres?|mm\b|millimeters?|millimetres?|m\b|meters?|metres?)\b⟧ post of
            SOME m => SOME(g1 post m) | NONE=>NONE
        fun metres v u = if String.isPrefix "in" u orelse u="\"" then scale v (127,5000)
          else if String.isPrefix "f" u then scale v (381,1250)
          else if String.isPrefix "c" u then scale v (1,100)
          else if String.isPrefix "mm" u orelse String.isPrefix "milli" u then scale v(1,1000)
          else v
        fun inUnit v u metric = scale (metres v u) (if metric then (100,1) else (5000,127))
        val lengths=List.mapPartial(fn(start,stop,v,pre,post)=>Option.map(fn u=>(start,stop,v,u,pre,post))(lengthUnit post)) numbers
        fun eyeRole(pre,_) = has ⟦\beye (?:height|level)\s*(?:of|is|=)?\s*$⟧ pre
        fun diamRole(pre,post) = has ⟦\b(?:dbh|diameter(?: at breast height)?)\s*(?:of|is|=)?\s*$⟧ pre orelse
          has ⟦^[- ]*(?:inches|inch|in\b|"|cm|centimeters?|centimetres?|mm|millimeters?|millimetres?)\s*(?:dbh|diameter|small[- ]end)\b⟧ post
        fun countRole(_,_,_,_,post) = has ⟦^\s*trees\s*(?:per|an|/)\s*acre\b⟧ post
        val counts=List.filter countRole numbers
        val diameters=List.filter(fn(_,_,_,_,pre,post)=>diamRole(pre,post)) lengths
        fun tuple(_,_,v,u,_,_)=rat(inUnit v u false)
        val forest = has ⟦\btrees?\b|\blogs?\b|\bdbh\b|\bbasal area\b|\bstand\b|\btimber\b|\bforest\w*\b|\bclinometer\b|\bdoyle\b|\bsmalian\b|\bseedlings?\b|\bplanting\b⟧ low
      in
        if not forest then NONE
        else if bad then unread()
        else if has ⟦\bdoyle\b|\bsmalian\b|\blog volume\b|\bcubic (?:feet|foot) (?:in|of) (?:the |a |this )?log\b⟧ low then
          let
            val ds=List.filter(fn(_,_,_,u,_,_)=>String.isPrefix "in" u orelse u="\"" orelse String.isPrefix "c" u) lengths
            val ls=List.filter(fn(_,_,_,u,pre,post)=>not(eyeRole(pre,post)) andalso (String.isPrefix "f" u orelse u="m" orelse String.isPrefix "meter" u orelse String.isPrefix "metre" u)) lengths
            fun feet(_,_,v,u,_,_)=rat(scale(metres v u)(1250,381))
          in
            if has ⟦\bdoyle\b⟧ low then
              (case(ds,ls)of([d],[l])=>fin(L.F_Doyle(tuple d,feet l))|_=>unread())
            else(case(ds,ls)of([d1,d2],[l])=>fin(L.F_Smalian(tuple d1,tuple d2,feet l))|_=>unread())
          end
        else if has ⟦\bheight\b|\bhow tall\b⟧ low andalso has ⟦\bangle\b|\bdegrees?\b|°|\bclinometer\b⟧ low then
          let
            val angles=List.filter(fn(_,_,_,_,post)=>has ⟦^\s*(?:degrees?\b|°)⟧ post) numbers
            val eyes=List.filter(fn(_,_,_,_,pre,post)=>eyeRole(pre,post)) lengths
            val ds=List.filter(fn(_,_,_,_,pre,post)=>not(eyeRole(pre,post))) lengths
            val outFeet=has ⟦\b(?:height|tall)[^?;]*\bin\s*(?:feet|ft)\b⟧ low
            val outMetres=has ⟦\b(?:height|tall)[^?;]*\bin\s*(?:m|meters?|metres?)\b⟧ low
            fun convert v u ft=rat(scale(metres v u)(if ft then(1250,381)else(1,1)))
          in
            if has ⟦\bslope\b|\bsloping\b|\binclined\b|\bbase angle\b⟧ low orelse (outFeet andalso outMetres) then unread()
            else case(ds,angles,eyes)of
              ([(_,_,dv,du,_,_)],[(_,_,a,_,_)],[])=>let val ft=outFeet orelse(not outMetres andalso String.isPrefix "f" du)
                in fin(L.F_Height(convert dv du ft,rat a,NONE,ft))end
            | ([(_,_,dv,du,_,_)],[(_,_,a,_,_)],[(_,_,ev,eu,_,_)])=>let val ft=outFeet orelse(not outMetres andalso String.isPrefix "f" du)
                in fin(L.F_Height(convert dv du ft,rat a,SOME(convert ev eu ft),ft))end
            | _=>unread()
          end
        else if has ⟦\bbasal area\b⟧ low then
          let
            val metric=has ⟦\b(?:m2|m²|square met(?:er|re)s?)\b⟧ low orelse
              (not(has ⟦\b(?:sq(?:uare)?\s*ft|square feet)\b⟧ low) andalso List.exists(fn(_,_,_,u,_,_)=>String.isPrefix "c" u orelse String.isPrefix "m" u)diameters)
            val explicitMean=has ⟦\barithmetic mean\b|\bmean arithmetic\b⟧ low
            fun dval(_,_,v,u,_,_)=rat(inUnit v u metric)
            fun nval(_,_,v,_,_)=rat v
            fun pair([],[])=SOME []
              | pair((d as (dp,_,_,_,_,_))::dr,(n as(np,ns,_,_,_))::nr)=
                  if np<dp andalso (case nr of(nnp,_,_,_,_)::_=>dp<nnp|[]=>true)
                  then Option.map(fn rest=>(dval d,nval n)::rest)(pair(dr,nr))else NONE
              | pair _=NONE
          in
            if explicitMean then unread()
            else case(diameters,counts)of
              ([d],[])=>if has ⟦\bper acre\b|\bstand\b⟧ low then unread()
                         else if metric then fin(L.F_BAm(dval d))else fin(L.F_BA(dval d))
            | ([d],[n])=>fin(L.F_BAStand(metric,[(dval d,nval n)]))
            | _=>(case pair(diameters,counts)of SOME(xs as _::_)=>fin(L.F_BAStand(metric,xs))|_=>unread())
          end
        else if has ⟦\bspac\w*\b|\bplant\w*\b|\bgrid\b⟧ low andalso
                has ⟦\bper acre\b|\ban acre\b|\bhow many (?:trees|seedlings)\b⟧ low then
          (case numbers of
            [(_,s1,v1,_,_), (s2,_,v2,_,post2)]=>
              if has ⟦^\s*(?:ft|feet|foot|')?\s*(?:x|×|by)\s*$⟧(String.substring(low,s1,s2-s1)) andalso
                 has ⟦^\s*(?:ft|feet|foot|')\b⟧ post2
              then fin(L.F_Tpa(rat v1,rat v2))else unread()
          | _=>unread())
        else NONE
      end

  (* ---------- wildlife ---------- *)
  val MARK = ⟦(?:marked|tagged|banded|marking|tagging|banding)⟧
  val CAP = ⟦(?:caught|captured|trapped|netted|sampled|collected|seined)⟧

  fun roles low =
    let
      val outM = ref (NONE : IntInf.int option)
      val outC = ref (NONE : IntInf.int option)
      val outR = ref (NONE : IntInf.int option)
      val conflict = ref false
      val invalid = ref false
      fun assign r v = case !r of NONE => r := SOME v | SOME old => if old = v then () else conflict := true
      fun step (ExactNumeric.Malformed _) = (conflict := true)
        | step (ExactNumeric.Number {start=s,stop=e,value=(v,d)}) =
        let
          fun setdef r value = (if value < 0 orelse d <> 1 then invalid := true else (); assign r value)
          val b0 = Int.max (0, s - 45)
          val bef = String.substring (low, b0, s - b0)
          val aft0 = String.substring (low, e, Int.min (60, size low - e))
          val aft = hd (String.fields (fn c => c = #"," orelse c = #";" orelse c = #".") aft0)
          val ofthe = anchored ⟦\s+of\s+the\s+(\d+(?:,\d{3})*)⟧ aft
        in
          if isSome ofthe andalso not (isSome (!outR)) then
            (setdef outR v; setdef outC (bigOf (g1 aft (valOf ofthe))))
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
      val _ = List.app step (ExactNumeric.scan low)
    in (!outM, !outC, !outR, !conflict, !invalid) end

  val animals = ⟦(?:animals|fish|deer|birds|turtles|frogs|mice|rabbits|butterflies|beetles|trout|salamanders|individuals|lizards|bats|squirrels)⟧

  (* Exact numeric roles are complete tokens. Area input and output units
     are separate fields; densities do not silently retain the input unit. *)
  fun wNumbers low = List.mapPartial
    (fn ExactNumeric.Number {start,stop,value,...} => SOME(value,String.substring(low,0,start),String.extract(low,stop,NONE)) | _ => NONE)
    (ExactNumeric.scan low)
  fun wMalformed low = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) (ExactNumeric.scan low)
  fun wOne xs = case xs of [v] => SOME v | _ => NONE
  val wAreaPat = ⟦(hectares?|ha|acres?|km2|km²|square kilomet(?:er|re)s?|sq\.?\s*km|square miles?|sq\.?\s*mi|mi2)⟧
  fun wUnit t = if has ⟦^(?:hectare|ha)⟧ t then L.Hectare
                else if has ⟦^acre⟧ t then L.Acre
                else if has ⟦(?:mile|mi)⟧ t then L.SquareMile else L.SquareKm
  fun wArea suffix = case search (⟦^\s*⟧ ^ wAreaPat ^ ⟦\b⟧) suffix of
      SOME m => SOME(wUnit(g1 suffix m)) | NONE => NONE

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
              val (m, c, r, conflict, invalid) = roles low
              val onat = Option.map natOf
            in fin (L.w_reply (if invalid then L.W_BadCount
                 else if conflict orelse has ⟦\b(?:third|fourth|multiple) (?:sample|capture|occasion|survey)\b⟧ low then L.W_Unread
                 else L.W_Lincoln (onat m, onat c, onat r, has ⟦\bchapman\b⟧ low))) end
          else if has ⟦\bdensity\b|\bper (?:hectare|acre|km|square)\b⟧ low then
            let
              val nums = wNumbers low
              val count = wOne(List.filter (fn (_,_,aft) => has (⟦^\s+⟧ ^ animals ^ ⟦\b⟧) aft) nums)
              val area = wOne(List.mapPartial (fn ((n,d),bef,aft) =>
                if has ⟦\b(?:in|on|across|over)\s+(?:an?\s+)?$⟧ bef
                then Option.map(fn u=>((n,d),u))(wArea aft) else NONE) nums)
              val targets = findall (⟦\bper\s+⟧ ^ wAreaPat ^ ⟦\b⟧) low
              val target = case targets of [] => NONE | [m] => SOME(wUnit(g1 low m)) | _ => NONE
            in
              if wMalformed low orelse length targets > 1 orelse (has ⟦\bper\b⟧ low andalso null targets) then fin(L.w_reply L.W_Unread)
              else case (count,area) of
                (SOME((n,d),_,_),SOME((a,b),u)) =>
                  if n < 0 orelse d <> 1 then fin(L.w_reply L.W_BadCount)
                  else fin(L.w_reply(L.W_DensityUnit(natOf n,L.mk_rat a b,u,case target of SOME v=>v|NONE=>u)))
              | _ => fin(L.w_reply L.W_Unread)
            end
          else wSurv low fin
        end
    end
  and wSurv low fin : L.reply option =
    if not(has ⟦\bsurvival\b|\bmortality\b|\bdeath rate\b⟧ low) then NONE
    else let
      val nums = wNumbers low
      fun starting (_,bef,aft) = has ⟦\b(?:of|out of|from)\s*$⟧ bef orelse
         (not(has ⟦^\s+of\b⟧ aft) andalso has ⟦^\s+(?:\w+\s+){0,2}?(?:were )?(?:released|tagged|collared|monitored|hatched|born)\b⟧ aft)
      val starts = List.filter starting nums
      fun survivor (row as (_,bef,aft)) = not(starting row) andalso
        (has ⟦^\s+(?:of\s+[+−\-\d.,/e]+\s+)?(?:\w+\s+){0,3}?(?:survived|were still alive|remained alive|lived)\b⟧ aft orelse
         has ⟦\b(?:survivors|surviving)\s*(?:=|:|was|were)?\s*$⟧ bef)
      val survivors = List.filter survivor nums
      val invalid = List.exists (fn ((n,d),_,_)=>n<0 orelse d<>1) (starts@survivors)
      val mort = has ⟦\bmortality\b|\bdeath rate\b⟧ low
      val asks = findall ⟦\b(?:what|calculate|find|determine)\b⟧ low
      val target = case rev asks of (m:Regex.match)::_ => String.extract(low,#start m,NONE) | [] => low
      val cumulative = has ⟦\boverall\b|\bcumulative\b|\b(?:over|across|for) (?:both|the two|two|2) (?:years|periods)\b⟧ target
      val conditional = has ⟦\b(?:during|in|for) (?:the )?second (?:year|period)\b⟧ target
      val annual = has ⟦\bannual(?:ized)?\b|\bper year\b⟧ target
      val multiYear = List.exists(fn((n,d),bef,aft)=>has ⟦\b(?:over|after|for|across)\s*$⟧ bef andalso has ⟦^\s*years?\b⟧ aft andalso n<>d) nums
      fun periodUnit text = if has ⟦\byears?\b|\bannual(?:ized)?\b|\byearly\b⟧ text then SOME "year"
        else if has ⟦\bmonths?\b|\bmonthly\b⟧ text then SOME "month"
        else if has ⟦\bweeks?\b|\bweekly\b⟧ text then SOME "week"
        else if has ⟦\bdays?\b|\bdaily\b⟧ text then SOME "day" else NONE
      val outputPeriod = case search ⟦\b(?:annual(?:ized)?|yearly|monthly|weekly|daily|per (?:year|month|week|day))\b⟧ target of
        SOME m=>periodUnit(Regex.whole target m) | NONE=>NONE
      val durations = List.mapPartial(fn((n,d),bef,aft)=>
        if has ⟦\b(?:over|after|for|across)\s*$⟧ bef then
          (case search ⟦^\s*(years?|months?|weeks?|days?)\b⟧ aft of
             SOME m=>SOME(n,d,periodUnit(g1 aft m))|NONE=>NONE) else NONE) nums
      val incompatiblePeriod = case outputPeriod of NONE=>false | SOME u=>
        (case durations of [] => has ⟦\b(?:two|three|four|five|several|multiple) (?:years|months|weeks|days)\b⟧ low
                          orelse (u<>"year" andalso has ⟦\b(?:first|second) year\b⟧ low)
         | [(n,d,SOME v)]=>n<>d orelse u<>v | _=>true)
      fun period aft = case search ⟦\b(?:survived|were still alive|remained alive|lived)\s+(?:the )?(first|second) (?:year|period)\b⟧ aft of SOME m=>SOME(g1 aft m)|NONE=>NONE
      fun unread() = fin(L.w_reply L.W_Unread)
    in
      if wMalformed low then unread()
      else if invalid then fin(L.w_reply L.W_BadCount)
      else case (starts,survivors) of
        ([((n,_),_,_)],[((s,_),_,_)]) =>
          if incompatiblePeriod orelse (annual andalso multiYear) then unread()
          else fin(L.w_reply(L.W_Surv(natOf s,natOf n,mort)))
      | ([((n,_),_,_)],[((s1,_),_,a1),((s2,_),_,a2)]) =>
          if (conditional <> cumulative) andalso not annual then
            (case (period a1,period a2) of
               (SOME "first",SOME "second") => fin(L.w_reply(L.W_Interval(natOf s1,natOf s2,natOf n,conditional,mort)))
             | (SOME "second",SOME "first") => fin(L.w_reply(L.W_Interval(natOf s2,natOf s1,natOf n,conditional,mort)))
             | _ => unread())
          else unread()
      | _ => unread()
    end
