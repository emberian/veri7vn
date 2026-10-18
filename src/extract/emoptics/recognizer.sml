(* UNTRUSTED. The English recognizer for the electrical / electronics / wiring /
   optics family: a hand port of the regular expressions and branch order of
     upstream/root/specialists/electrical/organ_electrical_v1.py        (ElectricalOrgan)
     upstream/root/specialists/electronics{,-r2}/organ_circuits_v1.py   (CircuitsOrgan)
     upstream/root/specialists/wiring/organ_wiring_v1.py                (WiringOrgan)
     upstream/root/specialists/optics*/organ_optics_v{1,2,3,4,5,5_r2}.py (OpticsOrgan and its versions)
   and of their shared narrowing rule narrow_v1.py. It reads numbers, unit words
   and words off the question and builds a typed Emoptics.request; it computes
   nothing. Every value, decline and response text comes from the verified HOL
   kernel (Emoptics.reply_of). NONE means the question is not taken.

   Unit words are looked up in the HOL tables (Emoptics.names_xxx tables), whose factors
   tables_check.py compares with the organs' dictionaries. What is ported by
   hand, and so untrusted, is the patterns and the branch order.

   Matching is case-insensitive by lower-casing the text (patterns are written
   in lower case). Circuits reads SI-prefix case (capital M mega against small m milli)
   from the original text at the matched position.
   Where the organ raises ZeroDivisionError (a zero turn count, a zero object
   distance), the kernel declines as impossible instead. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Emoptics.request) option
end =
struct
  structure E = Emoptics

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)
  fun firstGroup s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE
  fun startOf ({start, ...} : Regex.match) = start

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* "1,000.50", "-12.5", ".9", "1e-3" -> exact rational (numerator, denominator) *)
  fun ratParts (lit0 : string) : IntInf.int * IntInf.int =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) (lower lit0)
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (mant, ex) =
        case String.fields (fn c => c = #"e") body of
          [a] => (a, 0)
        | [a, b] => (a, valOf (Int.fromString (if String.isPrefix "+" b then String.extract (b, 1, NONE) else b)))
        | _ => raise Fail ("bad numeral " ^ lit0)
      val (ip, fp) = case String.fields (fn c => c = #".") mant of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val e = ex - size fp
      val (n, d) = if e >= 0 then (IntInf.* (num, IntInf.pow (10, e)), 1) else (num, IntInf.pow (10, ~e))
    in (if neg then IntInf.~ n else n, d) end
  fun ratOf lit = let val (n, d) = ratParts lit in E.mk_rat n d end
  (* sign tests on a numeral, without touching the opaque rational type *)
  fun nonPos lit = let val (n, _) = ratParts lit in n <= 0 end
  fun isZero lit = let val (n, _) = ratParts lit in n = 0 end
  fun gtOne lit = let val (n, d) = ratParts lit in n > d end
  fun ltOne lit = let val (n, d) = ratParts lit in n < d end

  (* ---------- narrow_v1 (as lane G's recognizer) ---------- *)
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

  (* a question the organ answered or declined: declines only count for a short direct question *)
  fun narrowed text r =
    if Narrow.narrative text then NONE
    else case r of
      NONE => NONE
    | SOME req => if Narrow.short_direct text orelse E.answered (E.reply_of req) then SOME req else NONE

  val NUM = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  fun orStr xs = String.concatWith "|" xs

  (* organ val(low, units, scale): the first "N unit" in the text, as (amount, unit-table entry) *)
  fun valOf' low units names =
    case search (NUM ^ "\\s*(" ^ orStr units ^ ")\\b") low of
      NONE => NONE
    | SOME m => (case E.lookup names (valOf (grp low m 2)) of
                   SOME u => SOME (ratOf (g1 low m), u)
                 | NONE => raise Fail "unit word not in HOL table")

  (* ---------- electrical ---------- *)
  fun zeroRat () = E.mk_rat 0 1
  fun pfStr low =
    case search "\\b(?:power factor|pf)\\s*(?:of|is|=)?\\s*(\\d*\\.?\\d+)\\b" low of
      SOME m => SOME (g1 low m)
    | NONE => (case search "(\\d*\\.?\\d+)\\s*(?:power factor|pf)\\b" low of
                 SOME m => SOME (g1 low m)
               | NONE => NONE)

  (* organ val(low, units, scale) keeps the numeral too, for truthiness tests *)
  fun valS low units names =
    case search (NUM ^ "\\s*(" ^ orStr units ^ ")\\b") low of
      NONE => NONE
    | SOME m => (case E.lookup names (valOf (grp low m 2)) of
                   SOME u => SOME (g1 low m, u)
                 | NONE => raise Fail "unit word not in HOL table")

  fun electricalRaw text : E.request option =
    let
      val t = collapse text
      val low = lower t
      val hp = search (NUM ^ "\\s*(?:hp|horsepower)\\b") low
      val kwm = search (NUM ^ "\\s*(?:kw|kilowatts?)\\b") low
    in
      if isSome hp andalso has "\\bkw\\b|\\bkilowatts?\\b|\\bwatts\\b" low
         andalso has "\\bhow many\\b|\\bconvert\\b|\\bin (?:kw|kilowatts|watts)\\b|\\bequal\\w*\\b|\\bwhat is\\b" low
         andalso not (has "\\befficien" low)
      then SOME (E.E_HpKw (ratOf (g1 low (valOf hp))))
      else if isSome kwm andalso has "\\bhorsepower\\b|\\bhp\\b" low
              andalso has "\\bhow many\\b|\\bconvert\\b|\\bin (?:hp|horsepower)\\b" low
      then SOME (E.E_KwHp (ratOf (g1 low (valOf kwm))))
      else
        let
          val turns = search "\\b(\\d+(?:\\.\\d+)?)\\s*:\\s*(\\d+(?:\\.\\d+)?)\\b" low
          val np_ = search ("\\bprimary\\s*(?:winding\\s*)?(?:has\\s*|of\\s*|with\\s*)?" ^ NUM ^ "\\s*turns|" ^ NUM ^ "\\s*turns?\\s*(?:on (?:the )?)?primary|" ^ NUM ^ "\\s*primary turns") low
          val ns_ = search ("\\bsecondary\\s*(?:winding\\s*)?(?:has\\s*|of\\s*|with\\s*)?" ^ NUM ^ "\\s*turns|" ^ NUM ^ "\\s*turns?\\s*(?:on (?:the )?)?secondary|" ^ NUM ^ "\\s*secondary turns") low
        in
          if has "\\btransformer\\b" low andalso (isSome turns orelse (isSome np_ andalso isSome ns_)) then
            let
              val (np, ns) =
                if isSome np_ andalso isSome ns_ then
                  (ratOf (valOf (firstGroup low (valOf np_) [1, 2, 3])), ratOf (valOf (firstGroup low (valOf ns_) [1, 2, 3])))
                else (ratOf (g1 low (valOf turns)), ratOf (valOf (grp low (valOf turns) 2)))
              val vp = search ("\\bprimary (?:voltage )?(?:of |is |=)?\\s*" ^ NUM ^ "\\s*v\\b|" ^ NUM ^ "\\s*v\\s*(?:on (?:the )?)?primary|\\b" ^ NUM ^ "\\s*v\\s*(?:input|in)\\b") low
              val ip = search ("\\bprimary current\\s*(?:of|is|=)?\\s*" ^ NUM ^ "\\s*a\\b|" ^ NUM ^ "\\s*a\\s*(?:(?:on|in) (?:the )?)?primary") low
            in
              if has "\\bsecondary voltage\\b|\\boutput voltage\\b|\\bvoltage (?:on|at|across) the secondary\\b|\\bwhat voltage\\b" low andalso isSome vp then
                SOME (E.E_XfmrV (np, ns, ratOf (valOf (firstGroup low (valOf vp) [1, 2, 3]))))
              else if has "\\bsecondary current\\b|\\boutput current\\b|\\bcurrent (?:in|on) the secondary\\b" low andalso isSome ip then
                SOME (E.E_XfmrI (np, ns, ratOf (valOf (firstGroup low (valOf ip) [1, 2]))))
              else NONE
            end
          else if has "\\bcorrect\\w*\\b|\\bimprove\\w*\\b|\\braise\\b" low andalso has "\\bpower factor\\b|\\bpf\\b" low
                  andalso has "\\bkvar\\b|\\bcapacitor\\w*\\b" low then
            let
              val m = search "\\bfrom\\s+(\\d*\\.\\d+)\\s+to\\s+(\\d*\\.\\d+)" low
              val p = valOf' low ["kw", "mw", "w"] E.names_w
            in
              case (m, p) of
                (SOME m, SOME pu) => SOME (E.E_PfCorr (pu, ratOf (g1 low m), ratOf (valOf (grp low m 2))))
              | _ => NONE
            end
          else
            let
              val three = has "\\bthree[- ]phase\\b|\\b3[- ]phase\\b|\\b3\206\134(?!\\w)|\\b3-ph\\b" low
              val V = valS low ["kv", "v", "volts"] E.names_v
              val I = valS low ["ka", "a", "amps", "amperes"] E.names_a
              val pfs = pfStr low
              val pf = Option.map ratOf pfs
              fun mkv (s, u) = (ratOf s, u)
              val vOk = (case V of SOME (s, _) => not (isZero s) | NONE => false)
              val iOk = (case I of SOME (s, _) => not (isZero s) | NONE => false)
              fun tri b = SOME (E.E_Tri (pf, b))
              val wyeRx = "\\bphase voltage\\s*(?:of|is|=)?\\s*" ^ NUM
              val deltaRx = "\\bphase current\\s*(?:of|is|=)?\\s*" ^ NUM
            in
              if (case pfs of SOME s => gtOne s | NONE => false) then tri (E.T_Wye (zeroRat ()))
              else if three andalso has "\\bwye\\b|\\bstar\\b" low andalso has "\\bline[- ](?:to[- ]line )?voltage\\b" low
                      andalso has wyeRx low then
                tri (E.T_Wye (ratOf (g1 low (valOf (search wyeRx low)))))
              else if three andalso has "\\bdelta\\b" low andalso has "\\bline current\\b" low andalso has deltaRx low then
                tri (E.T_Delta (ratOf (g1 low (valOf (search deltaRx low)))))
              else if three andalso vOk andalso iOk andalso has "\\bpower\\b|\\bkw\\b|\\bkva\\b" low
                      andalso not (has "\\bwhat (?:is )?(?:the )?current\\b" low) then
                let val v = mkv (valOf V) val i = mkv (valOf I)
                in if has "\\bapparent\\b|\\bkva\\b" low andalso not (has "\\breal\\b|\\bkw\\b|\\btrue\\b" low)
                   then tri (E.T_Kva (v, i)) else tri (E.T_Kw (v, i)) end
              else
                let
                  val P = valS low ["kw", "mw", "w", "watts"] E.names_w
                  val S = valS low ["kva", "mva", "va"] E.names_va
                in
                  if three andalso vOk andalso isSome P andalso has "\\bcurrent\\b|\\bamps\\b|\\bhow many amps\\b" low then
                    tri (E.T_Cur (mkv (valOf V), mkv (valOf P)))
                  else if isSome P andalso isSome S andalso has "\\bpower factor\\b|\\breactive\\b|\\bkvar\\b" low then
                    if has "\\breactive\\b|\\bkvar\\b" low then tri (E.T_React (mkv (valOf P), mkv (valOf S)))
                    else tri (E.T_Pf (mkv (valOf P), mkv (valOf S)))
                  else NONE
                end
            end
        end
    end

  fun electrical text = narrowed text (electricalRaw text)

  (* ---------- wiring ---------- *)
  fun gauge low =
    case search "\\b(\\d{1,2})[- ]?(?:awg|gauge)\\b|\\b(?:awg|gauge)\\s*(\\d{1,2})\\b|#\\s*(\\d{1,2})\\s*(?:awg|wire|copper|aluminum)" low of
      NONE => NONE
    | SOME m => let val n = valOf (Int.fromString (valOf (firstGroup low m [1, 2, 3])))
                in if 0 <= n andalso n <= 40 then SOME n else NONE end

  fun lenAmt low rx names =
    case search (NUM ^ "\\s*(" ^ rx ^ ")\\b") low of
      NONE => NONE
    | SOME m => (case E.lookup names (valOf (grp low m 2)) of
                   SOME u => SOME (ratOf (g1 low m), u)
                 | NONE => raise Fail "wiring length unit not in HOL table")

  fun wiringRaw text : E.request option =
    let
      val low = lower (collapse text)
      val n = gauge low
      val metal = if has "\\balumin(?:um|ium)\\b" low then E.Aluminium else E.Copper
      val natN = Option.map (fn k => E.mk_nat (IntInf.fromInt k)) n
      val im = search (NUM ^ "\\s*(?:a|amps?|amperes?)\\b") low
    in
      if has "\\bis (?:it|this|that) (?:safe|to code|up to code|code[- ]compliant|legal)\\b|\\bpass inspection\\b" low then SOME E.W_Judgement
      else if has "\\bcontinuous\\b" low andalso has "\\bbreaker\\b|\\bcircuit\\b" low
              andalso has "\\b(\\d+)\\s*(?:a|amp|amps|ampere)\\b" low then
        SOME (E.W_Continuous (ratOf (g1 low (valOf (search "\\b(\\d+)\\s*(?:a|amp|amps|ampere)\\b" low)))))
      else if has "\\bvoltage drop\\b" low andalso
              (isSome n orelse has "\\bwire|\\bawg\\b|\\bcable|\\bfeet\\b|\\bmeters?\\b|\\bft\\b" low) then
        let
          val lm = lenAmt low "ft|feet|foot|m|meters?|metres?" E.names_wlen
          val vm = search (NUM ^ "\\s*(?:v|volts?)\\b") low
        in
          SOME (E.W_Vdrop (metal, natN, Option.map (fn m => ratOf (g1 low m)) im, lm,
                           Option.map (fn m => ratOf (g1 low m)) vm))
        end
      else if isSome n andalso has "\\bresistance\\b|\\bohms?\\b" low then
        SOME (E.W_Res (metal, valOf natN, lenAmt low "ft|feet|foot|m|meters?|metres?|km" E.names_wlen))
      else if isSome n andalso has "\\bdiameter\\b|\\bhow thick\\b|\\bcross[- ]section\\w*\\b|\\barea\\b" low then
        (if has "\\barea\\b|\\bcross[- ]section" low then SOME (E.W_Area (valOf natN)) else SOME (E.W_Diam (valOf natN)))
      else
        let
          val pm = search (NUM ^ "\\s*(kw|w|watts?|kilowatts?)\\b") low
          val vm = search (NUM ^ "\\s*(?:v|volts?)\\b") low
        in
          if isSome pm andalso isSome vm andalso has "\\bcurrent\\b|\\bamps?\\b|\\bamperage\\b|\\bhow many amps\\b|\\bdraw\\b" low then
            let
              val pu = if String.isPrefix "k" (valOf (grp low (valOf pm) 2)) then E.PU_kW else E.PU_W
              val p = (ratOf (g1 low (valOf pm)), pu)
              val v = ratOf (g1 low (valOf vm))
            in
              if has "\\bthree[- ]phase\\b|\\b3[- ]phase\\b" low then
                let val pfm = search "\\b(?:power factor|pf)\\s*(?:of|is|=)?\\s*(0?\\.\\d+|1(?:\\.0)?)" low
                in SOME (E.W_Cur3 (p, v, Option.map (fn m => ratOf (g1 low m)) pfm)) end
              else SOME (E.W_Cur (p, v))
            end
          else NONE
        end
    end

  fun wiring text = narrowed text (wiringRaw text)

  (* ---------- electronics (circuits) ---------- *)
  (* the organ's text may carry mu and omega signs; map them to ASCII before matching *)
  fun asciiUnits s =
    let
      val reps = [("\206\169", " ohm"), ("\207\137", " ohm"), ("\226\132\166", " ohm"),
                  ("\194\181", "u"), ("\206\188", "u")]
      fun rep1 (pat, by) str =
        let
          val n = size pat
          fun go i acc =
            if i > size str - n then String.concat (rev (String.extract (str, i, NONE) :: acc))
            else if String.substring (str, i, n) = pat then go (i + n) (by :: acc)
            else go (i + 1) (String.substring (str, i, 1) :: acc)
        in if size str < n then str else go 0 [] end
    in foldl (fn (r, acc) => rep1 r acc) s reps end

  val Q_RX = "(-?(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?)\\s*(p|n|u|m|k)?\\s*(volts?|v|amps?|amperes?|a|ohms?|watts?|w|farads?|f)\\b"

  fun circuitsRaw text : E.request option =
    let
      val t = collapse (asciiUnits text)
      val low = lower t
    in
      if t = "" orelse not (has "\\b(?:resist\\w*|current|voltage|volts?|amps?|ohms?|watts?|power|capacitor|circuit|led|divider|series|parallel|time constant)\\b" low)
      then NONE
      else
        let
          val ms = findall Q_RX low
          fun amt m =
            let
              val pfxRaw = case grp low m 2 of
                             SOME _ => (case Regex.group t m 2 of SOME s => s | NONE => "")
                           | NONE => ""
              val p = case E.lookup E.names_pfx pfxRaw of SOME p => p | NONE => E.P_1
              val u = E.lookup E.names_cq (valOf (grp low m 3))
            in (ratOf (g1 low m), p, valOf u) end
          val all = map amt ms
          fun ofKind k = List.mapPartial (fn (x, p, q) => if q = k then SOME (x, p) else NONE) all
          val vs = ofKind E.CQ_V and as_ = ofKind E.CQ_A and rs = ofKind E.CQ_R
          val ws = ofKind E.CQ_W and cs = ofKind E.CQ_C
          val res = has "\\bresist" low
          (* a zero resistance is a rational compare after scaling; the kernel does it, we ask by value *)
          fun hd1 l = case l of x :: _ => SOME x | [] => NONE
          fun mk b = SOME (E.C_Circ (res, rs, b))
          val zeroR = List.exists (fn m => nonPos (g1 low m) andalso
                                   (case E.lookup E.names_cq (valOf (grp low m 3)) of SOME E.CQ_R => true | _ => false)) ms
        in
          if zeroR andalso res then mk (E.CB_Series rs)
          else if has "\\b(?:series|parallel)\\b" low andalso length rs >= 2 then
            (if has "parallel" low then mk (E.CB_Parallel rs) else mk (E.CB_Series rs))
          else if has "divider" low andalso not (null vs) andalso length rs >= 2 then
            mk (E.CB_Divider (hd vs, List.nth (rs, 0), List.nth (rs, 1)))
          else if has "\\btime constant\\b|\\brc\\b" low andalso not (null rs) andalso not (null cs) then
            mk (E.CB_Rc (hd rs, hd cs))
          else if has "\\bled\\b" low andalso length vs >= 2 andalso not (null as_) then
            mk (E.CB_Led (vs, hd as_))
          else
            let
              val want =
                if has "\\bhow much current\\b|\\bwhat current\\b|\\bcurrent (?:flows|through|draw)\\b|\\bhow many amps\\b|\\bfind the current\\b" low then SOME "A"
                else if has "\\bwhat voltage\\b|\\bvoltage (?:across|drop)\\b|\\bhow many volts\\b|\\bfind the voltage\\b" low then SOME "V"
                else if has "\\bwhat resist\\w*\\b|\\bwhich resist\\w*\\b|\\bhow many ohms\\b|\\bfind the resist\\w*\\b|\\bresistance (?:needed|required)\\b" low then SOME "R"
                else if has "\\bhow much power\\b|\\bwhat power\\b|\\bpower (?:dissipat\\w*|used|consumed)\\b|\\bhow many watts\\b|\\bfind the power\\b" low then SOME "W"
                else NONE
              val V = hd1 vs and A = hd1 as_ and R = hd1 rs and W = hd1 ws
            in
              case want of
                SOME "A" => mk (E.CB_Cur (V, R, W))
              | SOME "V" => mk (E.CB_Volt (A, R, W))
              | SOME "R" => mk (E.CB_Res (V, A))
              | SOME "W" => mk (E.CB_Pow (V, A, R))
              | _ => NONE
            end
        end
    end

  fun circuits text = circuitsRaw text

  (* ---------- optics ---------- *)
  structure Optics =
  struct
    val ON = "(-?\\d+(?:\\.\\d+)?(?:e[+-]?\\d+)?)"
    type idx = int * Emoptics.rat * string option   (* position, value, medium name *)
    val mediaNames = ["vacuum", "air", "water", "diamond"]

    (* v1 _indices: numbers after "index"/"n =" and named media, in order of mention *)
    fun raw low : idx list =
      let
        val nums = map (fn m => (startOf m, ratOf (g1 low m), NONE))
                     (findall ("\\b(?:index(?: of refraction)?|refractive index|n\\d?|to|into|toward)\\s*(?:of|=|is)?\\s*" ^ ON) low)
        val named = List.concat (map (fn nm =>
                      map (fn m => (startOf m, E.medium_n (valOf (E.lookup E.names_medium nm)), SOME nm))
                          (findall ("\\b" ^ nm ^ "\\b") low)) mediaNames)
        fun ins (x as (p, _, _), []) = [x]
          | ins (x as (p, _, _), (y as (q, _, _)) :: ys) = if p <= q then x :: y :: ys else y :: ins (x, ys)
      in foldl ins [] (nums @ named) end

    fun pos ((p, _, _) : idx) = p
    fun same ((p, _, _) : idx) ((q, _, _) : idx) = p = q
    fun valEq ((_, a, _) : idx) ((_, b, _) : idx) = a = b

    (* v2: the medium right after "from" is the incident one *)
    fun v2idx low : idx list =
      let val found = raw low
      in
        case search "\\b(?:from|leaving|leaves|exits?|out of)\\b" low of
          SOME fm =>
            if length found >= 2 then
              (case List.filter (fn f => pos f > startOf fm) found of
                 n1 :: _ => n1 :: List.filter (fn f => not (same f n1)) found
               | [] => found)
            else found
        | NONE => found
      end

    (* v3: both roles from grammar *)
    fun v3idx low : idx list =
      let val found = raw low
      in
        if length found < 2 then found
        else
          let
            val fm = search "\\b(?:from|leaving|leaves|exits?|out of|inside|within)\\b" low
            val tms = findall "\\b(?:to|toward|into|enters?|entering|reaches|hits a boundary with|boundary with)\\b" low
            val n1 = case fm of
                       SOME f => (case List.filter (fn x => pos x > startOf f) found of x :: _ => SOME x | [] => NONE)
                     | NONE => NONE
            fun n2of [] = NONE
              | n2of (m :: rest) =
                  let
                    val c = List.filter (fn f => pos f > startOf m andalso
                              (case n1 of NONE => true | SOME a => not (same f a))) found
                    (* Equal indices are valid; medium identity is its role, not its value. *)
                  in case c of x :: _ => SOME x | [] => n2of rest end
          in
            case n1 of
              NONE => v2idx low
            | SOME a =>
                let
                  val n2 = case n2of tms of
                             SOME b => SOME b
                           | NONE => (case List.filter (fn f => not (same f a)) found of x :: _ => SOME x | [] => NONE)
                in
                  case n2 of
                    NONE => [a]
                  | SOME b => a :: b :: List.filter (fn f => not (same f a) andalso not (same f b)) found
                end
          end
      end

    fun value ((_, v, _) : idx) = v

    val AWAY = "\\bobject\\s+(?:is\\s+)?(?:at\\s+a\\s+distance\\s+of\\s+|distance\\s+(?:of\\s+|is\\s+)?)?(\\d+(?:\\.\\d+)?)\\s*(cm|mm|m)\\s*(?:away|from the lens|in front of the lens)?"
    val SPEED = "\\bat what speed does light travel\\b|\\bhow fast (?:does )?light travels?\\b|\\blight travels\\b|\\bspeed at which light travels\\b"
    val NOT_MINE = "\\b(?:siren|horn|whistle|pipe|pipes|string|guitar|violin|piano|speaker|loudspeaker|sound|sounds|hear|heard|audible|echo|decibels?|db|pitch|tuning fork|harmonics?|overtones?)\\b"
    val MINE = "\\b(?:light|laser|photons?|lens|lenses|mirror|refract\\w*|optic\\w*|visible|rays?|nm|nanomet\\w*|thz|telescope|microscope)\\b"

    fun replaceAll p rep s =
      let
        fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
          | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
              go stop ms (rep m :: String.substring (s, i, start - i) :: acc)
      in go 0 (findall p s) [] end

    fun inToIn s =
      replaceAll "\\b(?:inside|through|within)\\b" (fn _ => "in") s

    fun lenAmt low rx =
      case search (ON ^ "\\s*(" ^ rx ^ ")\\b") low of
        NONE => NONE
      | SOME m => SOME (m, ratOf (g1 low m), valOf (E.lookup E.names_len (valOf (grp low m 2))))

    (* photon energy / frequency / wavelength: SOME when the organ returns here, NONE to fall through *)
    fun photon low : E.request option =
      let
        val lm = lenAmt low "nm|nanomet(?:er|re)s|um|micrometers|mm|cm|m"
        val fm = search (ON ^ "\\s*(thz|ghz|mhz|khz|hz)\\b") low
        fun fr m = (ratOf (g1 low m), valOf (E.lookup E.names_freq (valOf (grp low m 2))))
        fun viaF () =
          case fm of
            SOME m2 => if has "\\bwavelength\\b" low then SOME (E.O_Wavelength (fr m2))
                       else if has "\\benergy\\b" low then SOME (E.O_EnergyF (fr m2)) else NONE
          | NONE => NONE
      in
        case lm of
          SOME (m, x, u) =>
            if nonPos (g1 low m) then SOME (E.O_EnergyL (x, u))
            else if has "\\benergy\\b" low then SOME (E.O_EnergyL (x, u))
            else if has "\\bfrequency\\b" low then SOME (E.O_Frequency (x, u))
            else viaF ()
        | NONE => viaF ()
      end

    fun optics2 low indices : E.request option =
      let
        val none1 = (NONE : Emoptics.rat option)
      in
        (* lens power *)
        if has "\\bpower\\b" low andalso has "\\blens\\b" low andalso has "\\bfocal[- ]length\\b" low then
          let
            val m = case search ("\\bfocal length\\s*(?:of|=|is)?\\s*" ^ ON ^ "\\s*(mm|cm|m)\\b") low of
                      SOME m => SOME m
                    | NONE => search (ON ^ "\\s*(mm|cm|m)\\s*focal[- ]length") low
          in
            case m of
              NONE => SOME (E.O_LensPower NONE)
            | SOME m => SOME (E.O_LensPower (SOME (ratOf (g1 low m), valOf (E.lookup E.names_len (valOf (grp low m 2))))))
          end
        (* Thin-lens distances are read with units and normalized by the HOL
           helper to centimetres. Roles must be explicit; a bare image number
           cannot be silently treated as an object distance. *)
        else if has "\\blens\\b|\\bmirror\\b" low andalso has "\\bimage\\b|\\bmagnification\\b|\\bfocal length\\b" low then
          let
            val unitRx = "\\s*(mm|cm|m)\\b"
            val fm = search ("\\bfocal[- ]length\\s*(?:of|=|is)?\\s*" ^ ON ^ unitRx) low
            fun distance role = search ("\\b" ^ role ^ "\\s*(?:is\\s*)?(?:(?:placed|sits|lies|stands|located|positioned)\\s*)?(?:at\\s*)?(?:(?:a\\s+)?distance\\s*)?(?:of|is|=)?\\s*" ^ ON ^ unitRx) low
            val om = distance "object"
            val im = distance "image"
            fun amount m = E.lens_cm (ratOf (g1 low m), valOf (E.lookup E.names_len (valOf (grp low m 2))))
            val f = Option.map amount fm
            val d = Option.map amount om
            val i = Option.map amount im
            fun asks target = has ("\\b(?:what|find|give|calculate|determine)\\s+(?:is\\s+)?(?:(?:the|its)\\s+)?" ^ target ^ "\\b") low
            val wantObject = asks "object[- ]distance" orelse has "\\bwhere is the object\\b" low
            val wantFocal = asks "focal[- ]length"
          in
            if wantObject then SOME (E.O_Object (f, i))
            else if wantFocal then SOME (E.O_Focal (d, i))
            else if isSome fm andalso isSome om andalso has "\\bmagnification\\b" low
               andalso not (has "\\bimage distance\\b|\\bwhere\\b" low)
            then SOME (E.O_Mag (f, d))
            else SOME (E.O_Image (f, d))
          end
        (* critical angle *)
        else if has "\\bcritical angle\\b" low then
          (case indices low of
             a :: b :: _ => SOME (E.O_Crit (SOME (value a), SOME (value b)))
           | _ => SOME (E.O_Crit (none1, none1)))
        (* speed of light in a medium *)
        else if has "\\bspeed of light\\b|\\bhow fast (?:does|is) light\\b|\\blight travel\\b" low
                andalso has "\\bin\\b" low then
          (case indices low of
             a :: _ => SOME (E.O_Speed (SOME (value a)))
           | [] => SOME (E.O_Speed none1))
        else
          let
            val mi = search "\\b(?:refractive index|index of refraction)\\s+(?:of|for)\\s+(\\w+)\\b" low
          in
            if isSome mi andalso not (has "\\bdegrees?\\b|\194\176|\\bangle\\b" low) then
              (case E.lookup E.names_medium (g1 low (valOf mi)) of
                 SOME m => SOME (E.O_Index m)
               | NONE => NONE)
            else if has "\\brefract|\\bsnell\\b|\\bangle of refraction\\b" low then
              let
                val am = case search ("\\b(?:at|angle of incidence(?: of| is)?|incident at|incidence of)\\s*" ^ ON ^ "\\s*(?:degrees|deg|\194\176)") low of
                           SOME m => SOME m
                         | NONE => search (ON ^ "\\s*(?:degrees|deg|\194\176)") low
              in
                case (am, indices low) of
                  (SOME m, a :: b :: _) => SOME (E.O_Snell (SOME (ratOf (g1 low m)), SOME (value a), SOME (value b)))
                | _ => SOME (E.O_Snell (none1, none1, none1))
              end
            else NONE
          end
      end

    fun answer v text : E.request option =
      let
        val low0 = lower (collapse text)
        (* All historical wrappers use the corrected direction and phrasing semantics. *)
        val v = 52
      in
        if v = 52 andalso has NOT_MINE low0 andalso not (has MINE low0) then NONE
        else
          let
            val low1 =
              if v >= 5 then
                let
                  val a = if has "\\blens\\b|\\bmirror\\b" low0 andalso has "\\bimage\\b|\\bmagnification\\b" low0
                          then replaceAll AWAY (fn m => "object placed " ^ g1 low0 m ^ " " ^ valOf (grp low0 m 2) ^ " from the lens") low0
                          else low0
                in if has SPEED a then inToIn (replaceAll SPEED (fn _ => "speed of light") a) else a end
              else low0
            val low =
              if v >= 2 andalso has "\\bspeed of light\\b|\\bhow fast\\b" low1 then inToIn low1 else low1
            val indices = if v >= 3 then v3idx else if v = 2 then v2idx else raw
          in
            if has "\\bphoton\\b|\\bwavelength\\b|\\bfrequency\\b" low andalso not (has "\\blens\\b|\\bmirror\\b|\\bsound\\b|\\bangle\\b" low)
               andalso isSome (photon low)
            then photon low
            else optics2 low indices
          end
      end
  end

  fun optics v text = Optics.answer v text

  (* ---------- dispatch ---------- *)
  val organs = ["electrical", "electronics", "electronics-r2", "wiring", "optics", "optics-v2", "optics-v3", "optics-v5", "optics-v5-r2"]

  fun byId "electrical" = electrical
    | byId "electronics" = circuits
    | byId "electronics-r2" = circuits
    | byId "wiring" = wiring
    | byId "optics" = optics 1
    | byId "optics-v2" = optics 2
    | byId "optics-v3" = optics 3
    | byId "optics-v5" = optics 5
    | byId "optics-v5-r2" = optics 52
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each manifest's organ in a fixed order, the first that takes the question answers
     it: electrical, optics, wire-specific wiring questions, then circuits.
     Wiring requires wire/gauge/length context before taking voltage drop. *)
  val familyOrder = ["electrical", "optics-v5-r2", "wiring", "electronics-r2"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
