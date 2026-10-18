(* UNTRUSTED. The English recognizer for the finance family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/finance/organ_finance_v1.py        (FinanceOrgan)
     upstream/root/specialists/finance-v2/organ_finance_v2.py     (FinanceOrganV2)
     upstream/root/specialists/finance-v2-r2/organ_finance_v2r2.py (FinanceOrganV2R2)
     upstream/root/specialists/economics/organ_economics_v1.py    (EconomicsOrgan)
     upstream/root/specialists/retail/organ_retail_v1.py          (RetailOrgan)
   and of their shared narrowing rule narrow_v1.py and numbers rule
   numbers_rule_v1.py. It reads numbers and words off the question and builds a
   typed Finance.request; it computes nothing that is stated. Every value,
   decline and response text comes from the verified HOL kernel
   (Finance.reply_of). NONE means the question is not taken (the organ
   returns None).

   Numbers are read as exact decimal fractions (num, den) and handed to the
   kernel through Finance.mk_rat; the few comparisons the organs make before
   calling a formula (a silent None on a degenerate input) are made here on
   those fractions.

   The text is lower-cased once at entry (every organ pattern is applied to
   lower-cased text or compiled case-insensitively). \w and \d are ASCII.

   Differences from the organs, none on the panels: arithmetic is exact where
   the organs use floats; inputs on which an organ raises ZeroDivisionError
   (zero-month loan term, zero holding cost, zero average inventory) reach the
   kernel, which declines them as impossible. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Finance.request) option
end =
struct
  structure F = Finance

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

  fun replaceWith p (rep : string -> Regex.match -> string) s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (rep s m :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end
  fun replaceAll p r s = replaceWith p (fn _ => fn _ => r) s

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* ---------- exact decimal fractions (numerator, positive denominator) ---------- *)
  type fr = IntInf.int * IntInf.int
  fun fr_of (lit0 : string) : fr =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val ip = if ip = "" then "0" else ip
      val num = valOf (IntInf.fromString (ip ^ fp))
    in (if neg then IntInf.~ num else num, IntInf.pow (10, size fp)) end
  fun fint (n : int) : fr = (IntInf.fromInt n, 1)
  fun fadd ((a, b) : fr) ((c, d) : fr) : fr = (a * d + c * b, b * d)
  fun fsub ((a, b) : fr) ((c, d) : fr) : fr = (a * d - c * b, b * d)
  fun fmul ((a, b) : fr) ((c, d) : fr) : fr = (a * c, b * d)
  fun fdivi ((a, b) : fr) (k : IntInf.int) : fr = (a, b * k)
  fun fcmp ((a, b) : fr) ((c, d) : fr) : order = IntInf.compare (a * d, c * b)
  fun fle x y = fcmp x y <> GREATER
  fun feq x y = fcmp x y = EQUAL
  fun fpos (x : fr) = fcmp x (fint 0) = GREATER
  fun rat ((a, b) : fr) : F.rat = F.mk_rat a b
  fun ratO NONE = NONE
    | ratO (SOME x) = SOME (rat x)

  fun mult NONE = fint 1
    | mult (SOME "trillion") = (IntInf.pow (10, 12), 1)
    | mult (SOME "billion") = (IntInf.pow (10, 9), 1)
    | mult (SOME "million") = (IntInf.pow (10, 6), 1)
    | mult (SOME "thousand") = (1000, 1)
    | mult (SOME "k") = (1000, 1)
    | mult (SOME "m") = (IntInf.pow (10, 6), 1)
    | mult (SOME _) = fint 1

  (* ---------- narrow_v1 (copied from lane G's recognizer) ---------- *)
  structure Narrow =
  struct
    fun strip s = collapse s
    fun words t = length (String.tokens Char.isSpace t)
    fun splits ends t =
      let
        val t = strip t
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
    val NUMRE = "(?<![\\w.])\\d+(?:\\.\\d+)?(?!\\w|\\.\\d)"
    fun numbers t = length (findall NUMRE (lower t))
  end

  val N = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val NM = "\\$?" ^ N                       (* economics' N *)
  val SCALE = "\\s*(trillion|billion|million|thousand)?"

  (* ====================== finance ====================== *)
  val FIN_MONEY = "\\binterest\\b|\\bloan\\b|\\bmortgage\\b|\\bapr\\b|\\bapy\\b|\\bsav(?:e|ings)\\b|\\binvest\\w*\\b|\\bcompound\\w*\\b|\\bdoubl\\w*\\b|\\bdeposit\\b"
  val ADVICE = "\\bshould i\\b|\\bis it (?:a )?(?:good|bad|smart|wise)\\b|\\bworth it\\b|\\bwhich (?:stock|fund|etf|crypto|coin|bank|card)\\b|"
    ^ "\\bbest (?:investment|stock|fund|way to invest)\\b|\\bwhat (?:should|to) (?:i )?(?:buy|invest)\\b|\\brecommend\\b|\\bwill .* go up\\b"

  fun frate low = case search (N ^ "\\s*%") low of
                    NONE => NONE
                  | SOME m => SOME (fdivi (fr_of (g1 low m)) 100)
  fun fyears low =
    case search (N ^ "\\s*years?\\b") low of
      SOME m => SOME (fr_of (g1 low m))
    | NONE => (case search (N ^ "\\s*months?\\b") low of
                 SOME m => SOME (fdivi (fr_of (g1 low m)) 12)
               | NONE => NONE)
  fun fprincipal low =
    case search ("\\$\\s*" ^ N ^ "\\s*(k|thousand|million)?\\b") low of
      NONE => NONE
    | SOME m => SOME (fmul (fr_of (g1 low m)) (mult (grp low m 2)))

  fun freqWord "annually" = SOME F.Fq_annual
    | freqWord "yearly" = SOME F.Fq_annual
    | freqWord "annual" = SOME F.Fq_annual
    | freqWord "semiannually" = SOME F.Fq_semi
    | freqWord "semi-annually" = SOME F.Fq_semi
    | freqWord "quarterly" = SOME F.Fq_quarterly
    | freqWord "monthly" = SOME F.Fq_monthly
    | freqWord "weekly" = SOME F.Fq_weekly
    | freqWord "daily" = SOME F.Fq_daily
    | freqWord _ = NONE
  fun freqOf low =
    if has "\\bcontinuous(?:ly)?\\b" low then SOME F.Fq_continuous
    else case search "\\bcompounded\\s+(\\w+(?:-\\w+)?)|\\b(annually|semiannually|semi-annually|quarterly|monthly|weekly|daily)\\b" low of
           NONE => NONE
         | SOME m => (case firstGroup low m [1, 2] of NONE => NONE | SOME w => freqWord w)

  fun finCore low : F.request option =
    if not (has FIN_MONEY low) then NONE
    else
      let
        val calc = has "\\bhow (?:much|long|many)\\b" low andalso isSome (fprincipal low) andalso isSome (fyears low)
      in
        if has ADVICE low andalso not calc then SOME F.F_Advice
        else
          let
            val r = ratO (frate low)
            val P = ratO (fprincipal low)
            val y = ratO (fyears low)
          in
            if has "\\bapy\\b|\\beffective annual\\b" low andalso has "\\bapr\\b|\\bnominal\\b|\\bcompounded\\b" low then
              SOME (F.F_Apy (r, freqOf low))
            else if has "\\bdouble\\b|\\bdoubling\\b" low then SOME (F.F_Doubling r)
            else if has "\\bloan\\b|\\bmortgage\\b|\\bborrow" low
                    andalso has "\\bpayment\\b|\\bpay (?:each|per|a) month\\b|\\bmonthly\\b|\\btotal interest\\b|\\bhow much interest\\b" low then
              SOME (if has "\\btotal interest\\b|\\bhow much interest\\b" low then F.F_LoanInterest (P, r, y)
                    else F.F_LoanPayment (P, r, y))
            else if has ("\\bhow much (?:should|do|would|must) i (?:save|deposit|put)\\b|"
                         ^ "\\bmonthly (?:deposit|saving|contribution)\\b.*\\b(?:reach|goal|have)\\b|\\bto (?:reach|have|save up)\\b") low
                    andalso has "\\bmonth" low then
              SOME (F.F_Savings (P, y, r))
            else if has "\\bsimple interest\\b" low then SOME (F.F_Simple (P, r, y))
            else if has ("\\bannuit|\\b(?:per|each|every|a) (?:month|week|year)\\b(?![^.?]*\\bcompound)|"
                         ^ "\\bmonthly (?:deposits?|payments?|contributions?|earnings|savings)\\b") low then NONE
            else
              let
                val low_nc = replaceAll "\\bcompounded\\s+(?:annually|yearly|monthly|quarterly|weekly|daily|semi-?annually|continuously)\\b" " " low
              in
                if has ("\\b(?:saved?|saving|deposit(?:ed|s|ing)?|invest(?:ed|s|ing)?|contribut(?:ed|es|ing)|put (?:away|aside|in)|paid in|adds?)\\b[^.?]*?"
                        ^ "\\b(?:annually|yearly|monthly|quarterly|weekly|each (?:year|month|quarter|week)|every (?:year|month|quarter|week)|per (?:year|month|quarter|week))\\b") low_nc
                then NONE
                else if has ("\\bcompound\\w*\\b|\\bgrow\\b|\\bbe worth\\b|\\bwill (?:i|it) have\\b|\\bfuture value\\b|"
                             ^ "\\bafter \\d+ years?\\b.*\\b(?:balance|worth|have)\\b|\\binvest\\w*\\b.*\\bat\\b") low
                then SOME (F.F_Compound (P, r, y, freqOf low))
                else NONE
              end
          end
      end

  val PCT = "\\d+(?:\\.\\d+)?\\s*(?:%|percent\\b)"
  val PHASE = "\\b(?:and\\s+then|then\\s+\\d|for\\s+the\\s+(?:next|following|remaining)|after\\s+that|thereafter|afterwards)\\b"
  fun distinct xs = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] xs

  (* variant 1 = finance, 2 = finance-v2, 3 = finance-v2-r2 *)
  fun finance variant text =
    let
      val low0 = lower (collapse text)
      val tx = if variant >= 2
               then replaceAll "\\bdoubl(?:es|ed|ing)\\b" "double"
                      (replaceWith "\\b(\\d+(?:\\.\\d+)?)[- ](year|month)s?\\b(?!\\s+(?:old|ago))"
                         (fn s => fn m => g1 s m ^ " " ^ valOf (grp s m 2) ^ "s") low0)
               else low0
      val a = finCore tx
      (* organ_finance_v1.answer: advice passes; narrative turns and unanswerable short turns are dropped *)
      val a1 = case a of
                 NONE => NONE
               | SOME F.F_Advice => a
               | SOME req =>
                   if Narrow.narrative tx then NONE
                   else if not (F.answers req) andalso (not (Narrow.short_direct tx) orelse Narrow.numbers tx = 0) then NONE
                   else a
      (* numbers_rule_v1: an "I need X" with numbers in the turn is silence *)
      val a2 = if variant >= 2 then
                 (case a1 of
                    SOME F.F_Advice => a1
                  | SOME req => if not (F.answers req) andalso Narrow.numbers low0 >= 1 then NONE else a1
                  | NONE => NONE)
               else a1
    in
      if variant >= 3 then
        (case a2 of
           SOME req =>
             if F.answers req
                andalso (length (distinct (map (fn m => replaceAll "\\s" "" (Regex.whole low0 m)) (findall PCT low0))) >= 2
                         orelse (has PHASE low0 andalso has PCT low0))
             then SOME F.F_MultiPhase else a2
         | NONE => NONE)
      else a2
    end

  (* ====================== economics ====================== *)
  fun fnum low m i = fr_of (valOf (grp low m i))
  fun scaled low m ni si = fmul (fnum low m ni) (mult (grp low m si))

  (* "A from X to Y" / "A in YEAR ... B in YEAR" (earlier year first) *)
  fun from_to low subject : (fr * fr) option =
    case search ("(?:" ^ subject ^ ")[^.?;]{0,40}?\\bfrom\\s+" ^ NM ^ SCALE ^ "(?:\\s*\\w+)?\\s+(?:in\\s+\\d{4}\\s+)?to\\s+" ^ NM ^ SCALE) low of
      SOME m => SOME (scaled low m 1 2, scaled low m 3 4)
    | NONE =>
        if not (has subject low) then NONE
        else
          let
            val yrs = findall (NM ^ SCALE ^ "\\s*(?:\\w+\\s+){0,2}?(?:in|for)\\s+((?:19|20)\\d{2})\\b") low
          in
            case yrs of
              m1 :: m2 :: _ =>
                let
                  val y1 = valOf (IntInf.fromString (valOf (grp low m1 3)))
                  val y2 = valOf (IntInf.fromString (valOf (grp low m2 3)))
                  val v1 = scaled low m1 1 2
                  val v2 = scaled low m2 1 2
                  (* sorted((year, value)) *)
                  val ((ya, va), (yb, vb)) =
                    if y1 < y2 orelse (y1 = y2 andalso fle v1 v2) then ((y1, v1), (y2, v2)) else ((y2, v2), (y1, v1))
                in if ya <> yb then SOME (va, vb) else NONE end
            | _ => NONE
          end

  fun pctChange w = if String.isPrefix "f" w orelse String.isPrefix "d" w then ~1 else 1

  fun economics text =
    let
      val t = collapse text
      val low = lower t
    in
      if Narrow.narrative t then NONE
      else
        let
          val r = econCore low
        in
          case r of
            NONE => NONE
          | SOME req => if not (F.answers req) andalso not (Narrow.short_direct t) then NONE else r
        end
    end
  and econCore low : F.request option =
    if has "\\bwill\\b.*\\b(?:rise|fall|go up|go down|crash|recession)\\b|\\bpredict\\w*\\b|\\bforecast\\w*\\b|\\bshould i\\b|\\bbuy\\b|\\binvest\\b" low then NONE
    else
      let
        val mpc = search "\\bmpc\\b[^0-9]{0,25}?(\\d+(?:\\.\\d+)?|\\.\\d+)|\\bmarginal propensity to consume\\b[^0-9]{0,25}?(\\d+(?:\\.\\d+)?|\\.\\d+)" low
        val mps = search "\\bmps\\b[^0-9]{0,25}?(\\d+(?:\\.\\d+)?|\\.\\d+)|\\bmarginal propensity to save\\b[^0-9]{0,25}?(\\d+(?:\\.\\d+)?|\\.\\d+)" low
      in
        if (isSome mpc orelse isSome mps) andalso has "\\bmultiplier\\b" low then
          let
            val c = case mpc of
                      SOME m => fr_of (valOf (firstGroup low m [1, 2]))
                    | NONE => fsub (fint 1) (fr_of (valOf (firstGroup low (valOf mps) [1, 2])))
          in
            SOME (if has "\\btax multiplier\\b" low then F.E_TaxMultiplier (rat c) else F.E_Multiplier (rat c))
          end
        else
          let
            val nom = search "\\bnominal (?:interest )?rate\\b[^0-9%]{0,25}?(\\d+(?:\\.\\d+)?)\\s*%|(\\d+(?:\\.\\d+)?)\\s*%\\s*nominal" low
            val inf = search "\\binflation(?: rate)?\\b[^0-9%]{0,25}?(-?\\d+(?:\\.\\d+)?)\\s*%|(-?\\d+(?:\\.\\d+)?)\\s*%\\s*inflation" low
          in
            if isSome nom andalso isSome inf andalso has "\\breal (?:interest )?rate\\b|\\breal return\\b" low then
              SOME (F.E_RealRate (rat (fr_of (valOf (firstGroup low (valOf nom) [1, 2]))),
                                  rat (fr_of (valOf (firstGroup low (valOf inf) [1, 2])))))
            else if has "\\bunemployment rate\\b" low then econUnemp low
            else if has "\\bparticipation rate\\b" low then econPartic low
            else if has "\\bgdp deflator\\b|\\bdeflator\\b" low then econDeflator low
            else if has "\\brule of 70\\b" low
                    orelse (has "\\bdouble\\b|\\bdoubling\\b" low
                            andalso has "\\bgdp\\b|\\beconomy\\b|\\bper capita\\b|\\bincome\\b|\\bpopulation\\b" low) then
              (case search "(\\d+(?:\\.\\d+)?)\\s*%" low of
                 NONE => SOME (F.E_Rule70 NONE)
               | SOME m => let val gr = fr_of (g1 low m)
                           in if fle gr (fint 0) then NONE else SOME (F.E_Rule70 (SOME (rat gr))) end)
            else if has "\\belasticity\\b|\\belastic\\b" low then econElast low
            else if has "\\bcpi\\b|\\bconsumer price index\\b|\\bprice index\\b" low
                    andalso has "\\binflation\\b|\\bhow much (?:did )?prices\\b|\\bpercent(?:age)? (?:change|increase)\\b" low
                    andalso not (has "\\bworth\\b|\\bdollars\\b|\\badjust\\w*\\b" low) then
              (case from_to low "\\bcpi\\b|\\bconsumer price index\\b|\\bprice index\\b" of
                 NONE => SOME (F.E_Inflation NONE)
               | SOME (a, b) => if fle a (fint 0) then NONE else SOME (F.E_Inflation (SOME (rat a, rat b))))
            else if has "\\bcpi\\b|\\bconsumer price index\\b" low
                    andalso has "\\bworth\\b|\\bin (?:\\d{4}|today'?s) dollars\\b|\\badjust\\w*\\b|\\bequivalent\\b" low then
              econRealValue low
            else if has "\\bgrowth rate\\b|\\bgrew\\b|\\bgrowth\\b|\\bpercent(?:age)? (?:change|increase|growth)\\b" low
                    andalso has "\\bgdp\\b|\\boutput\\b|\\bpopulation\\b|\\bincome\\b|\\bper capita\\b" low then
              (case from_to low "\\bgdp\\b|\\boutput\\b|\\bpopulation\\b|\\bincome\\b|\\bper capita\\b" of
                 NONE => NONE
               | SOME (a, b) => if fle a (fint 0) then NONE else SOME (F.E_Growth (rat a, rat b)))
            else NONE
          end
      end

  and econUnemp low =
    let
      val u = search (NM ^ SCALE ^ "\\s*(?:people\\s+)?(?:are\\s+|were\\s+)?unemployed|\\bunemployed\\s*(?:people)?\\s*(?:of|is|are|=|:)?\\s*" ^ NM ^ SCALE) low
      val lf = search ("\\blabou?r force\\s*(?:of|is|=|:)?\\s*" ^ NM ^ SCALE ^ "|" ^ NM ^ SCALE ^ "\\s*(?:people\\s+)?in the labou?r force") low
      val e = search (NM ^ SCALE ^ "\\s*(?:people\\s+)?(?:are\\s+|were\\s+)?employed|\\bemployed\\s*(?:people)?\\s*(?:of|is|are|=|:)?\\s*" ^ NM ^ SCALE) low
      fun val4 m = if isSome (grp low m 1) then scaled low m 1 2 else scaled low m 3 4
    in
      case u of
        NONE => SOME (F.E_Unemployment (NONE, NONE))
      | SOME um =>
          let val U = val4 um
          in case lf of
               SOME lm => SOME (F.E_Unemployment (SOME (rat U), SOME (rat (val4 lm))))
             | NONE => (case e of
                          SOME em => SOME (F.E_Unemployment (SOME (rat U), SOME (rat (fadd U (val4 em)))))
                        | NONE => SOME (F.E_Unemployment (SOME (rat U), NONE)))
          end
    end

  and econPartic low =
    let
      val lf = search ("\\blabou?r force\\s*(?:of|is|=|:)?\\s*" ^ NM ^ SCALE ^ "|" ^ NM ^ SCALE ^ "\\s*(?:people\\s+)?in the labou?r force") low
      val pop = search ("\\b(?:working[- ]age|adult|civilian noninstitutional) population\\s*(?:of|is|=|:)?\\s*" ^ NM ^ SCALE
                        ^ "|" ^ NM ^ SCALE ^ "\\s*(?:working[- ]age|adults?)\\b") low
      fun val4 m = if isSome (grp low m 1) then scaled low m 1 2 else scaled low m 3 4
    in
      case (lf, pop) of
        (SOME lm, SOME pm) => SOME (F.E_Participation (SOME (rat (val4 lm)), SOME (rat (val4 pm))))
      | _ => SOME (F.E_Participation (NONE, NONE))
    end

  and econDeflator low =
    let
      val nm = search ("\\bnominal gdp\\s*(?:of|is|was|=|:)?\\s*" ^ NM ^ SCALE) low
      val rm = search ("\\breal gdp\\s*(?:of|is|was|=|:)?\\s*" ^ NM ^ SCALE) low
    in
      case (nm, rm) of
        (SOME n, SOME r) =>
          let val nv = scaled low n 1 2
              val rv = scaled low r 1 2
          in if fle rv (fint 0) then NONE else SOME (F.E_Deflator (SOME (rat nv), SOME (rat rv))) end
      | _ => SOME (F.E_Deflator (NONE, NONE))
    end

  and econElast low =
    let
      val pr = from_to low "\\bprices?\\b"
      val qt = from_to low "\\bquantit(?:y|ies)\\b"
    in
      case (pr, qt) of
        (SOME (p1, p2), SOME (q1, q2)) =>
          if feq p1 p2 orelse feq (fadd p1 p2) (fint 0) orelse feq (fadd q1 q2) (fint 0) then NONE
          else SOME (F.E_Elasticity (SOME (rat p1, rat p2), SOME (rat q1, rat q2)))
      | _ =>
          let
            val verbs = "(rises?|rose|increases?|increased|goes up|went up|falls?|fell|drops?|dropped|decreases?|decreased)"
            val pp = search ("\\bprices?\\b[^.;%]{0,30}?\\b" ^ verbs ^ "\\s+(?:by\\s+)?(\\d+(?:\\.\\d+)?)\\s*%") low
            val qp = search ("\\bquantit(?:y|ies)(?: demanded)?\\b[^.;%]{0,30}?\\b" ^ verbs ^ "\\s+(?:by\\s+)?(\\d+(?:\\.\\d+)?)\\s*%") low
          in
            case (pp, qp) of
              (SOME pm, SOME qm) =>
                let
                  val dp = fmul (fint (pctChange (g1 low pm))) (fr_of (valOf (grp low pm 2)))
                  val dq = fmul (fint (pctChange (g1 low qm))) (fr_of (valOf (grp low qm 2)))
                in if feq dp (fint 0) then NONE else SOME (F.E_ElasticityPct (SOME (rat dp), SOME (rat dq))) end
            | _ => SOME (F.E_Elasticity (NONE, NONE))
          end
    end

  and econRealValue low =
    let
      val am = search ("\\$(\\d+(?:,\\d{3})*(?:\\.\\d+)?)" ^ SCALE ^ "(?:\\s+\\w+){0,3}?\\s+in\\s+((?:19|20)\\d{2})") low
      val tg = search "\\bin\\s+((?:19|20)\\d{2})\\s+dollars\\b" low
    in
      case (am, tg) of
        (SOME a, SOME t) =>
          let
            val rest0 = String.substring (low, 0, #start a) ^ " " ^ String.extract (low, #stop a, NONE)
            val tgs = Regex.whole low t
            fun repl s =
              let
                val n = size tgs
                fun go i acc =
                  if i > size s - n then String.concat (rev (String.extract (s, i, NONE) :: acc))
                  else if String.substring (s, i, n) = tgs then go (i + n) (" " :: acc)
                  else go (i + 1) (String.str (String.sub (s, i)) :: acc)
              in if n = 0 then s else go 0 [] end
            val rest = repl rest0
            val cp : (IntInf.int * fr) list ref = ref []
            fun setdef y v = if List.exists (fn (k, _) => k = y) (!cp) then () else cp := (y, v) :: !cp
            val _ = List.app (fn m => setdef (valOf (IntInf.fromString (valOf (grp rest m 2)))) (fnum rest m 1))
                      (findall "(\\d+(?:\\.\\d+)?)\\s+(?:in|for)\\s+((?:19|20)\\d{2})\\b" rest)
            val _ = List.app (fn m => setdef (valOf (IntInf.fromString (valOf (grp rest m 1)))) (fnum rest m 2))
                      (findall "\\b((?:19|20)\\d{2})\\s+(?:cpi|consumer price index)\\s*(?:of|was|is|=|:)?\\s*(\\d+(?:\\.\\d+)?)" rest)
            val _ = List.app (fn m => setdef (valOf (IntInf.fromString (valOf (grp rest m 1)))) (fnum rest m 2))
                      (findall "\\b(?:cpi|consumer price index)\\s+(?:in|for)\\s+((?:19|20)\\d{2})\\s*(?:of|was|is|=|:)?\\s*(\\d+(?:\\.\\d+)?)" rest)
            val y0 = valOf (IntInf.fromString (valOf (grp low a 3)))
            val y1 = valOf (IntInf.fromString (g1 low t))
            fun look y = Option.map (fn (_, v) => rat v) (List.find (fn (k, _) => k = y) (!cp))
            val X = scaled low a 1 2
          in
            SOME (F.E_RealValue (rat X, look y0, look y1, F.mk_rat y0 1, F.mk_rat y1 1))
          end
      | _ => NONE
    end

  (* ====================== retail ====================== *)
  fun retail text =
    let
      val t = collapse text
      val low = lower t
    in
      if Narrow.narrative t then NONE
      else
        case retailCore low of
          NONE => NONE
        | SOME req => if not (F.answers req) andalso not (Narrow.short_direct t) then NONE else SOME req
    end
  and retailCore low : F.request option =
    let
      val cost = search ("\\b(?:cost|costs|wholesale|unit cost)\\s*(?:of|is|=|at)?\\s*\\$\\s*" ^ N ^ "|\\$\\s*" ^ N ^ "\\s*(?:to make|cost|wholesale)") low
      val price = search ("\\b(?:sells? (?:it )?for|selling price|retail price|price(?:d)?(?: at)?|sell (?:it )?at|sale price of)\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N) low
      val c = Option.map (fn m => fr_of (valOf (firstGroup low m [1, 2]))) cost
      val p = Option.map (fn m => fr_of (g1 low m)) price
      val pct = search (N ^ "\\s*%") low
      fun firstOf pats = List.mapPartial (fn pt => search pt low) pats
      fun first1 pats = case firstOf pats of m :: _ => SOME m | [] => NONE
      fun money1 pat = Option.map (fn m => fr_of (g1 low m)) (search pat low)
    in
      if has "\\bbreak[- ]?even\\b" low then
        let
          val fm = case search ("\\bfixed costs?\\s*(?:of|are|is|=)?\\s*\\$\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 ("\\$\\s*" ^ N ^ "\\s*(?:in |of |a month in |per month in )?fixed")
          val vm = case search ("\\bvariable cost\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 ("\\$\\s*" ^ N ^ "\\s*(?:variable|per unit (?:to make|in variable))")
        in SOME (F.R_BreakEven (ratO fm, ratO p, ratO vm)) end
      else if has "\\beoq\\b|\\beconomic order quantity\\b" low then
        let
          val dm = case search ("\\b(?:annual demand|demand)\\s*(?:of|is|=)?\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 (N ^ "\\s*units? (?:a|per) year\\b")
          val sm = money1 ("\\b(?:order(?:ing)? cost|setup cost|cost per order)\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N)
          val hm = money1 ("\\b(?:holding cost|carrying cost)\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N)
        in SOME (F.R_EOQ (ratO dm, ratO sm, ratO hm)) end
      else if has "\\breorder point\\b|\\bwhen (?:should|do) (?:i|we) reorder\\b|\\brop\\b" low then
        let
          val dm = case search (N ^ "\\s*(?:units?|items?|cases?)?\\s*(?:a|per|each) day\\b") low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 ("\\b(?:daily (?:demand|usage|sales))\\s*(?:of|is|=)?\\s*" ^ N)
          val lm = case search ("\\blead time\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*days?|" ^ N ^ "[- ]days? lead time") low of
                     SOME m => SOME (fr_of (valOf (firstGroup low m [1, 2])))
                   | NONE => NONE
          val ss = case search ("\\bsafety stock\\s*(?:of|is|=)?\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 (N ^ "\\s*(?:units? )?(?:of )?safety stock")
          val s = case ss of SOME x => x | NONE => fint 0
        in SOME (F.R_ROP (ratO dm, ratO lm, rat s)) end
      else if has "\\binventory turnover\\b|\\bturnover ratio\\b|\\bdays of inventory\\b|\\bdays inventory\\b|\\binventory days\\b" low then
        let
          fun amt pat = Option.map (fn m => fmul (fr_of (g1 low m)) (mult (grp low m 2))) (search pat low)
          val cg = amt ("\\b(?:cogs|cost of goods sold)\\s*(?:of|is|was|=)?\\s*\\$\\s*" ^ N ^ "\\s*(k|m|million|thousand)?")
          val ai = amt ("\\baverage inventory\\s*(?:of|is|was|=)?\\s*\\$\\s*" ^ N ^ "\\s*(k|m|million|thousand)?")
        in
          SOME (if has "\\bdays\\b" low then F.R_Days (ratO cg, ratO ai) else F.R_Turnover (ratO cg, ratO ai))
        end
      else if has "\\bmargin\\b|\\bmark[- ]?up\\b" low then
        let
          val want_markup = has "\\bmark[- ]?up\\b" low andalso not (has "\\bmargin\\b" low)
        in
          case (c, p) of
            (SOME cc, SOME pp) => SOME (if want_markup then F.R_Markup (rat cc, rat pp) else F.R_Margin (rat cc, rat pp))
          | _ =>
              (case (c, pct) of
                 (SOME cc, SOME pm) =>
                   if has ("\\bwhat (?:price|should i charge|should it sell)\\b|\\bprice (?:do i need|should i set|to (?:get|hit|reach))\\b|"
                           ^ "\\bsell (?:it )?for\\b|\\bset the price\\b") low
                   then let val m = fdivi (fr_of (g1 low pm)) 100
                        in SOME (if want_markup then F.R_PriceMarkup (rat cc, rat m) else F.R_PriceMargin (rat cc, rat m)) end
                   else NONE
               | _ => NONE)
        end
      else if has "\\bdiscount\\b|\\b% off\\b|\\boff\\b|\\bsale\\b" low andalso has ("\\$\\s*" ^ N) low andalso isSome pct then
        let
          val base = fr_of (g1 low (valOf (search ("\\$\\s*" ^ N) low)))
          val offs = case findall (N ^ "\\s*%\\s*off\\b") low of
                       [] => [fr_of (g1 low (valOf pct))]
                     | ms => map (fn m => fr_of (g1 low m)) ms
        in SOME (F.R_Discount (rat base, map rat offs)) end
      else if has "\\bsales tax\\b|\\bwith tax\\b|\\bincluding tax\\b|\\bafter tax\\b" low andalso has ("\\$\\s*" ^ N) low andalso isSome pct then
        let
          val base = fr_of (g1 low (valOf (search ("\\$\\s*" ^ N) low)))
          val r = fdivi (fr_of (g1 low (valOf pct))) 100
        in SOME (F.R_WithTax (rat base, rat r)) end
      else NONE
    end

  (* ---------- dispatch ---------- *)
  val organs = ["finance", "finance-v2", "finance-v2-r2", "economics", "retail"]

  fun byId "finance" = finance 1
    | byId "finance-v2" = finance 2
    | byId "finance-v2-r2" = finance 3
    | byId "economics" = economics
    | byId "retail" = retail
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: economics and retail first (their trigger words are specific), then the newest finance organ. *)
  val familyOrder = ["economics", "retail", "finance-v2-r2"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
