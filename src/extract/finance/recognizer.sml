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
  val replyOf : Finance.request -> Finance.reply
end =
struct
  structure F = Finance

  (* The narrowing steps ask "does the kernel answer this request?", which builds the whole reply; the driver then needs
     that same reply. Keep the last one (same request object) so each question is computed once. Untrusted bookkeeping. *)
  val memo : (F.request * F.reply) option ref = ref NONE
  fun replyOf (req : F.request) : F.reply =
    case !memo of
      SOME (r, rep) => if r = req then rep else let val rep = F.reply_of req in memo := SOME (req, rep); rep end
    | NONE => let val rep = F.reply_of req in memo := SOME (req, rep); rep end
  fun answersM (req : F.request) : bool = F.answered (replyOf req)

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

  exception UnboundNumericToken
  val QNUM = "(qnum[0-9]+q)"
  fun withNumbers original read =
    case ExactNumeric.mask original of
      NONE => NONE
    | SOME {text, numbers} =>
        let fun number marker =
              case List.find (fn (key, _) => key = marker) numbers of
                SOME (_, value) => value
              | NONE => raise UnboundNumericToken
        in read text number handle UnboundNumericToken => NONE end
  fun roleNumber original pattern = withNumbers original
    (fn text => fn number => Option.map (fn m => number (g1 text m)) (search pattern text))
  fun rates original =
    case withNumbers original (fn text => fn number => SOME
      (map (fn m => number (g1 text m)) (findall (QNUM ^ "\\s*(?:%|percent\\b)") text))) of
        SOME xs => xs | NONE => []

  (* ====================== finance ====================== *)
  (* Consume a complete signed decimal, never the tail of a malformed token. *)
  val DECIMAL = "-?(?:(?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?|\\.\\d+)"
  val SIGNED_N = "(?<![\\w.,+\\-])(" ^ DECIMAL ^ ")(?![\\w,]|\\.\\d)"
  val PCT0 = SIGNED_N ^ "\\s*(?:%|percent\\b)"
  val PCT = PCT0
  val FIN_MONEY = "\\bborrow\\w*\\b|" ^ "\\binterest\\b|\\bloan\\b|\\bmortgage\\b|\\bapr\\b|\\bapy\\b|\\bsav(?:e|ings)\\b|\\binvest\\w*\\b|\\bcompound\\w*\\b|\\bdoubl\\w*\\b|\\bdeposit\\b"
  val ADVICE = "\\bshould i\\b|\\bis it (?:a )?(?:good|bad|smart|wise)\\b|\\bworth it\\b|\\bwhich (?:stock|fund|etf|crypto|coin|bank|card)\\b|"
    ^ "\\bbest (?:investment|stock|fund|way to invest)\\b|\\bwhat (?:should|to) (?:i )?(?:buy|invest)\\b|\\brecommend\\b|\\bwill .* go up\\b"

  fun frate low = Option.map (fn x => fdivi x 100)
    (roleNumber low (QNUM ^ "\\s*(?:%|percent\\b)"))
  fun fyears low =
    case roleNumber low (QNUM ^ "\\s*years?\\b") of
      SOME y => SOME y
    | NONE => Option.map (fn m => fdivi m 12) (roleNumber low (QNUM ^ "\\s*months?\\b"))
  fun fprincipal low = withNumbers low (fn text => fn number =>
    case search ("\\$\\s*" ^ QNUM ^ "\\s*(k|thousand|million)?\\b") text of
      NONE => NONE
    | SOME m => SOME (fmul (number (g1 text m)) (mult (grp text m 2))))

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

  (* Quantity names in an explicit exclusion are not the requested output. *)
  fun quantityScope low = replaceAll
    "\\b(?:not|rather than|instead of)\\s+(?:the\\s+)?(?:gross\\s+)?(?:margin|mark[- ]?up|interest|total|savings?)\\b" " " low
  datatype money_target = InterestAmount | FinalBalance | UnknownTarget
  (* Only an identified requested quantity selects an arithmetic result.  A
     compound-interest topic alone is not a request for a final balance. *)
  fun moneyTarget low =
    let
      val q = replaceAll "\\bwhat['\226\128\153]s\\b" "what is" (quantityScope low)
      val det = "(?:(?:the|my|our|your|its|their)\\s+)?"
      val ask = "(?:what(?: is| was| will be| would be)?|calculate|compute|find|determine|work out)\\s+"
      val noun = "(?:(?:total|compound|simple|net|accrued|earned|paid|accumulated)\\s+)*interest\\b(?=\\s*(?:[,?!.;:]|$|\\b(?:is|are|was|were|will|would|on|from|for|over|after|if|at|earned|paid|accrued|excluding|that)\\b))"
      val interest = has ("\\b(?:how much\\s+(?:(?:money|dollars?)\\s+)?(?:(?:in|of|as)\\s+)?|how many dollars?\\s+(?:of|in|as)\\s+|" ^ ask ^ det ^ "(?:amount of\\s+)?)" ^ noun) q
        orelse has ("\\bhow much\\s+(?:money\\s+)?(?:will|would|do|did)\\b[^!?;]{0,45}\\b(?:in|as)\\s+" ^ noun) q
        orelse has ("(?:^|[.!?;]\\s*)\\s*" ^ det ^ noun ^ "(?:\\s+(?:is|was|will be|would be))?\\s+earned\\s*\\??\\s*$") q
        orelse has ("^\\s*simple interest\\s+on\\b") q
      val balance = has ("\\b" ^ ask ^ det ^ "(?:(?:total|final|future|accumulated)\\s+)?(?:balance|amount|value)\\b(?=\\s*(?:[,?!.;:]|$|\\b(?:is|was|will|would|on|from|for|over|after|if|at|including|excluding|that)\\b))") q
        orelse has "\\bhow much\\b[^!?;]{0,35}\\b(?:will|would) (?:i|we|you|it) have\\b|\\bwhat (?:will|would)\\b[^!?;]{0,45}\\bbe worth\\b|\\bwhat (?:will|would|does)\\b[^!?;]{0,45}\\bgrow to\\b" q
        orelse has "\\bwhat(?: (?:will|would))?\\b[^!?;]{0,45}\\bbecomes?\\b|\\bgrows? to what\\b|\\bwhat (?:will|would) (?:i|we|you|it) have\\b" q
        orelse has "\\bwhat (?:is|will|would) (?:it|the balance|the amount|the value) (?:be|worth)\\b" q
        orelse has "\\b(?:what (?:total|final) amount|future value)\\b(?=\\s*(?:[,?!.;:]|$|\\b(?:is|was|will|would|on|from|for|over|after|if|at|including|excluding|that|of)\\b))" q
      val targetNoun = "(?:(?:the|my|our|your|total|final|future|compound|simple|net|accrued|earned|paid|accumulated)\\s+)*(?:interest|balance|amount|value)\\b"
      val multiple = has ("\\b" ^ targetNoun ^ "\\s+(?:and|plus|as well as)\\s+" ^ targetNoun) q
        orelse has "\\bboth\\b[^!?;]{0,45}\\binterest\\b" q
    in if multiple then UnknownTarget
       else case (interest, balance) of
         (true, false) => InterestAmount
       | (false, true) => FinalBalance
       | _ => UnknownTarget
    end
  fun wantsSavings low = has
    "\\bhow much\\b[^!?;]{0,55}\\b(?:save|saved)\\b|\\b(?:what|calculate|compute|find|determine)\\b[^!?;]{0,35}\\bsavings?\\b"
    (quantityScope low)

  (* B-lane: forward value of equal monthly deposits ("I deposit $200 a month at 6% for 10 years; how much will I have?").
     Strict: one dollar amount (the deposit), one percent figure, a term, a monthly deposit, deposits at the END of the
     month (the kernel's ordinary annuity), compounding monthly or unstated; anything else stays withheld. *)
  val MONTHLY_DEP = "\\$\\s*" ^ QNUM ^ "\\s*(?:a|each|every|per)\\s+month\\b|\\bmonthly (?:deposits?|contributions?|payments?) of\\s*\\$\\s*" ^ QNUM
  fun monthlyDeposit low = withNumbers low (fn text => fn number =>
    case search MONTHLY_DEP text of NONE => NONE
    | SOME m => SOME (number (valOf (firstGroup text m [1, 2]))))
  fun annuityOk low =
    isSome (monthlyDeposit low)
    andalso has "\\b(?:deposit|deposits|deposited|depositing|save|saves|saving|invest|invests|contribute|contributes|put|add)\\b" low
    andalso has "\\bhow much\\b|\\bwhat (?:will|would)\\b|\\bfuture value\\b|\\bbalance\\b|\\bworth\\b" low
    andalso length (findall "\\$" low) = 1
    andalso length (rates low) = 1
    andalso isSome (fyears low)
    andalso not (has "\\b(?:beginning|start|first day|advance|due)\\b|\\bannuity due\\b|\\b(?:initial|starting|opening|existing|already)\\b|\\bloan\\b|\\bmortgage\\b|\\bwithdraw\\w*\\b" low)
    andalso (case freqOf low of NONE => true | SOME F.Fq_monthly => true | SOME _ => false)
    andalso not (has "\\bcontinuous(?:ly)?\\b" low)
    andalso moneyTarget low = FinalBalance
  fun annuityReq low =
    Option.map (fn dep => F.F_Annuity (SOME (rat dep), ratO (frate low), ratO (fyears low))) (monthlyDeposit low)

  (* Forward equal monthly cashflows: separately bind opening balance and
     deposit, rather than choosing the first currency token. *)
  fun cashflowReq original = withNumbers original (fn low => fn number =>
    let
      val depPattern = "\\$\\s*" ^ QNUM ^ "\\s*(?:(?:at\\s+)?the\\s+(?:beginning|start|end|finish)\\s+of\\s+)?(?:a|each|every|per)\\s+month\\b|\\bmonthly (?:deposits?|contributions?) of\\s*\\$\\s*" ^ QNUM
      val openingPattern = "\\b(?:initial|starting|opening) (?:balance|principal)(?: of| is| =)?\\s*\\$\\s*" ^ QNUM ^ "|\\b(?:start|begin) with\\s*\\$\\s*" ^ QNUM ^ "|\\balready have\\s*\\$\\s*" ^ QNUM
      val deposits = findall depPattern low
      val openings = findall openingPattern low
      fun selected m groups = Option.map number (firstGroup low m groups)
      val dep = case deposits of [m] => selected m [1,2] | _ => NONE
      val opening = case openings of [m] => selected m [1,2,3]
        | [] => if length (findall "\\$" low) = 1 andalso not (has "\\b(?:initial|starting|opening|already)\\b" low) then SOME (fint 0) else NONE
        | _ => NONE
      val openingNamed = has "\\b(?:initial|starting|opening|already|start with|begin with)\\b" low
      val cashflowTopic = has "\\b(?:deposit|deposits|depositing|contribute|contributes|contributions|save|saving)\\b" low
        andalso has "\\bmonthly\\b|\\b(?:each|every|per|a) month\\b" low
      val starts = has "\\b(?:beginning|start)(?: and (?:end|finish))? of (?:each|every|the) month\\b|\\bannuity due\\b" low
      val ends = has "\\b(?:end|finish)(?: and (?:beginning|start))? of (?:each|every|the) month\\b" low
      val target = moneyTarget original
      val frequencyOk = case freqOf original of NONE => true | SOME F.Fq_monthly => true | SOME _ => false
      val scopeOk = frequencyOk andalso not (starts andalso ends)
        andalso not (has "\\bwithdraw\\w*\\b|\\b(?:weekly|yearly|annual) deposits?\\b" low)
        andalso length (findall "\\$" low) = length deposits + length openings
        andalso length (rates original) <= 1
        andalso length (findall (QNUM ^ "\\s*(?:years?|months?)\\b") low) <= 1
        andalso not (has "\\b(?:then|thereafter|withdrawals?|fees?|tax(?:es)?|apy|effective annual)\\b" low)
    in if null deposits andalso not cashflowTopic then NONE
       else if null deposits then SOME F.F_UnknownTarget
       else if not scopeOk orelse target = UnknownTarget orelse (openingNamed andalso not (isSome opening)) then SOME F.F_UnknownTarget
       else SOME (F.F_Cashflow (ratO opening, ratO dep, ratO (frate original), ratO (fyears original),
         if starts then F.At_Start else F.At_End,
         if target = InterestAmount then F.CF_Interest else F.CF_Balance))
    end)
  datatype loan_target = LoanPayment | LoanInterest | LoanUnknown
  fun loanTarget low =
    let
      val q = quantityScope low
      val det = "(?:(?:the|my|our|your|its|their)\\s+)?"
      val ask = "(?:what(?: is| was| will be| would be)?|calculate|compute|find|determine|work out)\\s+"
      val endRole = "(?=\\s*(?:[,?!.;:]|$|\\b(?:is|are|was|were|will|would|on|from|for|over|after|if|at|to|of|including|excluding|that)\\b))"
      val payment = has ("\\b" ^ ask ^ det ^ "(?:monthly\\s+)?payment\\b" ^ endRole) q
        orelse has "\\bhow much\\s+(?:(?:will|would|must|should|do)\\s+(?:i|we|you)\\s+)?pay\\s+(?:each|every|per|a)\\s+month\\b" q
        orelse has ("^\\s*" ^ det ^ "monthly\\s+payment\\b" ^ endRole) q
      val interest = moneyTarget q = InterestAmount
        orelse has "\\bhow much\\s+(?:total\\s+)?interest\\s+(?:do|will|would|did)\\s+(?:i|we|you)\\s+pay\\b" q
        orelse has ("^\\s*" ^ det ^ "(?:total\\s+)?interest\\b" ^ endRole) q
      val multiple = has "\\b(?:interest|payment)\\s+(?:and|plus|as well as)\\s+(?:(?:the|total|monthly)\\s+)*(?:interest|payment)\\b" q
    in if multiple then LoanUnknown
       else case (payment, interest) of
         (true,false) => LoanPayment | (false,true) => LoanInterest | _ => LoanUnknown
    end

  fun finCore low : F.request option =
    if not (has FIN_MONEY low) orelse not (isSome (ExactNumeric.mask low)) then NONE
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
            else if has "\\bloan\\b|\\bmortgage\\b|\\bborrow" low then
              (case loanTarget low of LoanInterest => SOME (F.F_LoanInterest (P,r,y))
               | LoanPayment => SOME (F.F_LoanPayment (P,r,y))
               | LoanUnknown => SOME F.F_UnknownTarget)
            else if has ("\\bhow much (?:should|do|would|must) i (?:save|deposit|put)\\b|"
                         ^ "\\bmonthly (?:deposit|saving|contribution)\\b.*\\b(?:reach|goal|have)\\b|\\bto (?:reach|have|save up)\\b") low
                    andalso has "\\bmonth" low then
              SOME (F.F_Savings (P, y, r))
            else if has "\\bsimple interest\\b" low then
              (case moneyTarget low of InterestAmount => SOME (F.F_Simple (P, r, y))
               | FinalBalance => SOME (F.F_SimpleTotal (P, r, y)) | UnknownTarget => SOME F.F_UnknownTarget)
            else if isSome (cashflowReq low) then cashflowReq low
            else if annuityOk low then annuityReq low
            else if isSome (monthlyDeposit low) then
              (if moneyTarget low = UnknownTarget then SOME F.F_UnknownTarget else NONE)
            else if has ("\\bannuit|\\b(?:per|each|every|a) (?:month|week|year)\\b(?![^.?]*\\bcompound)|"
                         ^ "\\bmonthly (?:deposits?|payments?|contributions?|earnings|savings)\\b") low then
              (if moneyTarget low = UnknownTarget then SOME F.F_UnknownTarget else NONE)
            else
              let
                val low_nc = replaceAll "\\bcompounded\\s+(?:annually|yearly|monthly|quarterly|weekly|daily|semi-?annually|continuously)\\b" " " low
              in
                if has ("\\b(?:saved?|saving|deposit(?:ed|s|ing)?|invest(?:ed|s|ing)?|contribut(?:ed|es|ing)|put (?:away|aside|in)|paid in|adds?)\\b[^.?]*?"
                        ^ "\\b(?:annually|yearly|monthly|quarterly|weekly|each (?:year|month|quarter|week)|every (?:year|month|quarter|week)|per (?:year|month|quarter|week))\\b") low_nc
                then NONE
                else if has ("\\bcompound\\w*\\b|\\bgrow\\b|\\bbe worth\\b|\\bwill (?:i|it) have\\b|\\bfuture value\\b|"
                             ^ "\\bafter \\d+ years?\\b.*\\b(?:balance|worth|have)\\b|\\binvest\\w*\\b.*\\bat\\b") low
                then (case moneyTarget low of
                  InterestAmount => SOME (F.F_CompoundInterest (P, r, y, freqOf low))
                | FinalBalance => SOME (F.F_Compound (P, r, y, freqOf low))
                | UnknownTarget => SOME F.F_UnknownTarget)
                else NONE
              end
          end
      end

  val PHASE = "\\b(?:and\\s+then|then\\s+\\d|for\\s+the\\s+(?:next|following|remaining)|after\\s+that|thereafter|afterwards)\\b"
  fun distinct xs = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] xs

  (* B-lane: exactly "R1% compounded F1 for Y1 years, and then R2% compounded F2 for the next Y2 years" on one dollar
     amount; anything looser stays the in-domain multi-phase decline. *)
  val NUMW = "(qnum[0-9]+q|one|two|three|four|five|six|seven|eight|nine|ten)"
  val PHASE1 = QNUM ^ "\\s*(?:%|percent\\b)[^.?;]{0,40}?compounded\\s+(annually|yearly|semi-?annually|quarterly|monthly|weekly|daily)"
               ^ "[^.?;%]{0,25}?for\\s+(?:the\\s+(?:next|following)\\s+)?" ^ NUMW ^ "\\s+years?\\b"
  fun numWord "one" = SOME (fint 1) | numWord "two" = SOME (fint 2) | numWord "three" = SOME (fint 3)
    | numWord "four" = SOME (fint 4) | numWord "five" = SOME (fint 5) | numWord "six" = SOME (fint 6)
    | numWord "seven" = SOME (fint 7) | numWord "eight" = SOME (fint 8) | numWord "nine" = SOME (fint 9)
    | numWord "ten" = SOME (fint 10) | numWord w = SOME (fr_of w)
  fun twoPhase original : F.request option = withNumbers original (fn low => fn number =>
    case findall PHASE1 low of
      [m1, m2] =>
        if length (findall "\\$" low) = 1 andalso length (rates original) = 2 andalso length (findall "\\byears?\\b" low) = 2
           andalso has "\\band\\s+then\\b|\\bthen\\b|\\bfor the next\\b|\\bafter that\\b" low
           andalso has "\\bgrow|\\bworth\\b|\\bbalance\\b|\\bhave\\b|\\bend up\\b|\\bvalue\\b" low
           andalso not (has "\\bshould\\b|\\bdeposit\\w*\\s+(?:each|every|a)\\b|\\bwithdraw\\w*\\b|\\bper (?:month|year)\\b" low)
        then
          (case (fprincipal original, freqWord (valOf (grp low m1 2)), freqWord (valOf (grp low m2 2)),
                 (case List.find (fn w => w = valOf (grp low m1 3)) ["one","two","three","four","five","six","seven","eight","nine","ten"] of SOME w => numWord w | NONE => SOME (number (valOf (grp low m1 3)))), (case List.find (fn w => w = valOf (grp low m2 3)) ["one","two","three","four","five","six","seven","eight","nine","ten"] of SOME w => numWord w | NONE => SOME (number (valOf (grp low m2 3))))) of
             (SOME p, SOME f1, SOME f2, SOME y1, SOME y2) =>
               SOME (F.F_TwoPhase (SOME (rat p), SOME (rat (fdivi (number (g1 low m1)) 100)), SOME (rat y1), SOME f1,
                                   SOME (rat (fdivi (number (g1 low m2)) 100)), SOME (rat y2), SOME f2))
           | _ => NONE)
        else NONE
    | _ => NONE)

  (* variant 1 = finance, 2 = finance-v2, 3 = finance-v2-r2 *)
  fun finance variant text =
    let
      val low0 = lower (collapse text)
      val tx = if variant >= 2
               then replaceAll "\\bdoubl(?:es|ed|ing)\\b" "double"
                      (replaceWith "\\b(\\d+(?:\\.\\d+)?)[- ](year|month)s?\\b(?!\\s+(?:old|ago))"
                         (fn s => fn m => g1 s m ^ " " ^ valOf (grp s m 2) ^ "s") low0)
               else low0
      val a = if has "-\\s*\\$" tx then NONE else finCore tx
      (* organ_finance_v1.answer: advice passes; narrative turns and unanswerable short turns are dropped *)
      val a1 = case a of
                 NONE => NONE
               | SOME F.F_Advice => a
               | SOME F.F_UnknownTarget => a
               | SOME req =>
                   if Narrow.narrative tx then NONE
                   else if not (answersM req) andalso (not (Narrow.short_direct tx) orelse Narrow.numbers tx = 0) then NONE
                   else a
      (* numbers_rule_v1: an "I need X" with numbers in the turn is silence *)
      val a2 = if variant >= 2 then
                 (case a1 of
                    SOME F.F_Advice => a1
                  | SOME F.F_UnknownTarget => a1
                  | SOME (F.F_Annuity _) => a1
                  | SOME req => if F.reply_kind (replyOf req) = "impossible" then a1
                                else if not (answersM req) andalso Narrow.numbers low0 >= 1 then NONE else a1
                  | NONE => NONE)
               else a1
    in
      if variant >= 3 then
        (case a2 of
           SOME req =>
             if answersM req
                andalso (length (rates low0) >= 2
                         orelse (has PHASE low0 andalso has PCT low0))
             then (case twoPhase low0 of SOME req => SOME req | NONE => SOME F.F_MultiPhase) else a2
         | NONE => NONE)
      else a2
    end

  (* ====================== economics ====================== *)
  (* Mask complete exact tokens once; every quantity and calendar role resolves
     through this invocation's table. Generated marker IDs are never values. *)
  fun econMasked original : F.request option = withNumbers original (fn low => fn fr_of =>
    let
      val N = QNUM
      val NM = "\\$?\\s*" ^ QNUM
      fun year marker =
        let val (n,d) = fr_of marker
        in if d = 1 andalso n >= 1900 andalso n <= 2099 then n
           else raise UnboundNumericToken end
      fun localRole pattern = Option.map (fn m => fr_of (g1 low m)) (search pattern low)
  fun fnum low m i = fr_of (valOf (grp low m i))
  fun scaled low m ni si = fmul (fnum low m ni) (mult (grp low m si))

  (* "A from X to Y" / "A in YEAR ... B in YEAR" (earlier year first) *)
  fun from_to low subject : (fr * fr) option =
    case search ("(?:" ^ subject ^ ")[^.?;]{0,40}?\\bfrom\\s+" ^ NM ^ SCALE ^ "(?:\\s*\\w+)?\\s+(?:in\\s+qnum[0-9]+q\\s+)?to\\s+" ^ NM ^ SCALE) low of
      SOME m => SOME (scaled low m 1 2, scaled low m 3 4)
    | NONE =>
        if not (has subject low) then NONE
        else
          let
            val yrs0 = findall (NM ^ SCALE ^ "\\s*(?:\\w+\\s+){0,2}?(?:in|for)\\s+(qnum[0-9]+q)\\b") low
            (* B-lane: "in 2022 the CPI stood at 260; in 2021 it was 250" (year first); groups are (year, number, scale) *)
            val yrsB = findall ("\\bin\\s+(qnum[0-9]+q)\\b[^.;?]{0,40}?\\b(?:stood at|was|were|is|reached|of|at|=|:)\\s*" ^ NM ^ SCALE) low
            val yrs = if length yrs0 >= 2 then map (fn m => (m, 3, 1, 2)) yrs0 else map (fn m => (m, 1, 2, 3)) yrsB
          in
            case yrs of
              (m1, gy1, gn1, gs1) :: (m2, gy2, gn2, gs2) :: _ =>
                let
                  val y1 = year (valOf (grp low m1 gy1))
                  val y2 = year (valOf (grp low m2 gy2))
                  val v1 = scaled low m1 gn1 gs1
                  val v2 = scaled low m2 gn2 gs2
                  (* sorted((year, value)) *)
                  val ((ya, va), (yb, vb)) =
                    if y1 < y2 orelse (y1 = y2 andalso fle v1 v2) then ((y1, v1), (y2, v2)) else ((y2, v2), (y1, v1))
                in if ya <> yb then SOME (va, vb) else NONE end
            | _ => NONE
          end

  val LABELLED_EU = "^\\s*employed\\s*:?\\s*" ^ NM ^ SCALE ^ "\\s*[.;]\\s*unemployed\\s*:?\\s*" ^ NM ^ SCALE
                    ^ "\\s*[.;]\\s*(?:what'?s|what is) the unemployment rate\\s*\\??\\s*$"

  fun pctChange w = if String.isPrefix "f" w orelse String.isPrefix "d" w then ~1 else 1

  fun econCore low : F.request option =
    if has "\\bwill\\b.*\\b(?:rise|fall|go up|go down|crash|recession)\\b|\\bpredict\\w*\\b|\\bforecast\\w*\\b|\\bshould i\\b|\\bbuy\\b|\\binvest\\b" low then NONE
    else
      let
        val mpc = search "\\bmpc\\b[^.;?]{0,25}?(qnum[0-9]+q)|\\bmarginal propensity to consume\\b[^.;?]{0,25}?(qnum[0-9]+q)" low
        val mps = search "\\bmps\\b[^.;?]{0,25}?(qnum[0-9]+q)|\\bmarginal propensity to save\\b[^.;?]{0,25}?(qnum[0-9]+q)" low
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
            fun firstNumber p1 p2 = case localRole p1 of SOME x => SOME x | NONE => localRole p2
            val nom = firstNumber
              ("\\bnominal (?:interest )?rate\\s*(?:of|is|=|:)?\\s*" ^ QNUM ^ "\\s*%")
              (QNUM ^ "\\s*%\\s*nominal")
            val inf = firstNumber
              ("\\binflation(?: rate)?\\s*(?:of|is|=|:)?\\s*" ^ QNUM ^ "\\s*%")
              (QNUM ^ "\\s*%\\s*inflation")
          in
            if isSome nom andalso isSome inf andalso has "\\breal (?:interest )?rate\\b|\\breal return\\b" low then
              SOME ((if has "\\bapproximat|\\bnominal minus inflation\\b|\\bsubtract\\b" low then F.E_RealRate else F.E_Fisher)
                (rat (valOf nom), rat (valOf inf)))
            else if has "\\bunemployment rate\\b" low then econUnemp low
            else if has "\\bparticipation rate\\b" low then econPartic low
            else if has "\\bgdp deflator\\b|\\bdeflator\\b" low then econDeflator low
            else if has "\\brule of 70\\b" original
                    orelse (has "\\bdouble\\b|\\bdoubling\\b" low
                            andalso has "\\bgdp\\b|\\beconomy\\b|\\bper capita\\b|\\bincome\\b|\\bpopulation\\b" low) then
              (case search "(qnum[0-9]+q)\\s*%" low of
                 NONE => SOME (F.E_Rule70 NONE)
               | SOME m => let val gr = fr_of (g1 low m)
                           in if fle gr (fint 0) then NONE else SOME (F.E_Rule70 (SOME (rat gr))) end)
            else if has "\\belasticity\\b|\\belastic\\b" low then econElast low
            else if has "\\bcpi\\b|\\bconsumer price index\\b|\\bprice index\\b" low
                    andalso has "\\binflation\\b|\\bhow much (?:did )?prices\\b|\\bpercent(?:age)? (?:change|increase)\\b|\\bby what percent(?:age)?\\b" low
                    andalso not (has "\\bworth\\b|\\bdollars\\b|\\badjust\\w*\\b" low) then
              (case from_to low "\\bcpi\\b|\\bconsumer price index\\b|\\bprice index\\b" of
                 NONE => SOME (F.E_Inflation NONE)
               | SOME (a, b) => if fle a (fint 0) then NONE else SOME (F.E_Inflation (SOME (rat a, rat b))))
            else if has "\\bcpi\\b|\\bconsumer price index\\b" low
                    andalso has "\\bworth\\b|\\bin (?:qnum[0-9]+q|today'?s) dollars\\b|\\badjust\\w*\\b|\\bequivalent\\b" low then
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
      val lf = search ("\\blabou?r force\\s*(?:of|is|=|:)?\\s*\\(?" ^ NM ^ SCALE ^ "|" ^ NM ^ SCALE ^ "\\s*(?:people\\s+)?in the labou?r force") low
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
      val lf = search ("\\blabou?r force\\s*(?:of|is|=|:)?\\s*\\(?" ^ NM ^ SCALE ^ "|" ^ NM ^ SCALE ^ "\\s*(?:people\\s+)?in the labou?r force") low
      val pop = search ("\\b(?:working[- ]age|adult|civilian noninstitutional) population\\s*(?:of|is|=|:)?\\s*\\(?" ^ NM ^ SCALE
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
      (* B-lane: "What is real GDP if nominal GDP is $24 trillion and the GDP deflator is 120?" -> nominal / deflator x 100,
         in the units the question used. A deflator below 10 is probably a ratio, not an index near 100: withheld. *)
      val dm = search ("\\bdeflator\\s*(?:of|is|was|=|:)?\\s*" ^ N ^ "(?!\\s*(?:trillion|billion|million|thousand|%))") low
      val asksReal = has "\\b(?:what|find|compute|calculate|determine)\\b[^.?]{0,30}\\breal gdp\\b" low
    in
      case (nm, rm, dm) of
        (SOME n, NONE, SOME d) =>
          if asksReal andalso not (has "\\bwhat is the (?:gdp )?deflator\\b|\\bcompute the (?:gdp )?deflator\\b" low) then
            let val dv = fr_of (g1 low d)
            in if fle dv (fint 10) then NONE
               else SOME (F.E_RealGdp (SOME (rat (fnum low n 1)), SOME (rat dv),
                                       (case grp low n 2 of SOME u => " " ^ u | NONE => "")))
            end
          else SOME (F.E_Deflator (NONE, NONE))
      | _ =>
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
            val pp = search ("\\bprices?\\b[^.;%]{0,30}?\\b" ^ verbs ^ "\\s+(?:by\\s+)?(qnum[0-9]+q)\\s*%") low
            val qp = search ("\\bquantit(?:y|ies)(?: demanded)?\\b[^.;%]{0,30}?\\b" ^ verbs ^ "\\s+(?:by\\s+)?(qnum[0-9]+q)\\s*%") low
            (* B-lane: "A 5% price cut raises quantity demanded by 2%" *)
            val pp2 = search "(qnum[0-9]+q)\\s*%\\s*price\\s+(cut|drop|decrease|reduction|increase|rise|hike)\\b" low
            val qp2 = search "\\b(raises?|boosts?|increases?|lowers?|reduces?|decreases?|cuts?|drops?)\\s+(?:the\\s+)?quantit(?:y|ies)(?: demanded)?\\s+by\\s+(qnum[0-9]+q)\\s*%" low
            fun sgn2 w = if List.exists (fn p => String.isPrefix p w) ["cut", "drop", "decrease", "reduc", "lower"] then ~1 else 1
          in
            case (pp, qp) of
              (NONE, NONE) =>
                (case (pp2, qp2) of
                   (SOME pm, SOME qm) =>
                     let
                       val dp = fmul (fint (sgn2 (valOf (grp low pm 2)))) (fr_of (valOf (grp low pm 1)))
                       val dq = fmul (fint (sgn2 (valOf (grp low qm 1)))) (fr_of (valOf (grp low qm 2)))
                     in if feq dp (fint 0) then NONE else SOME (F.E_ElasticityPct (SOME (rat dp), SOME (rat dq))) end
                 | _ => SOME (F.E_Elasticity (NONE, NONE)))
            | (SOME pm, SOME qm) =>
                let
                  val dp = fmul (fint (pctChange (g1 low pm))) (fr_of (valOf (grp low pm 2)))
                  val dq = fmul (fint (pctChange (g1 low qm))) (fr_of (valOf (grp low qm 2)))
                in if feq dp (fint 0) then NONE else SOME (F.E_ElasticityPct (SOME (rat dp), SOME (rat dq))) end
            | _ => SOME (F.E_Elasticity (NONE, NONE))
          end
    end

  and econRealValue low =
    let
      val am = search ("\\$(qnum[0-9]+q)" ^ SCALE ^ "(?:\\s+\\w+){0,3}?\\s+(?:in|from)\\s+(qnum[0-9]+q)") low
      val tg = search "\\bin\\s+(qnum[0-9]+q)\\s+dollars\\b" low
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
            val _ = List.app (fn m => setdef (year (valOf (grp rest m 2))) (fnum rest m 1))
                      (findall "(qnum[0-9]+q)\\s+(?:in|for)\\s+(qnum[0-9]+q)\\b" rest)
            val _ = List.app (fn m => setdef (year (valOf (grp rest m 1))) (fnum rest m 2))
                      (findall "\\b(qnum[0-9]+q)\\s+(?:cpi|consumer price index)\\s*(?:of|was|is|=|:)?\\s*(qnum[0-9]+q)" rest)
            val _ = List.app (fn m => setdef (year (valOf (grp rest m 1))) (fnum rest m 2))
                      (findall "\\b(?:cpi|consumer price index)\\s+(?:in|for)\\s+(qnum[0-9]+q)\\s*(?:of|was|is|=|:)?\\s*(qnum[0-9]+q)" rest)
            val y0 = year (valOf (grp low a 3))
            val y1 = year (g1 low t)
            fun look y = Option.map (fn (_, v) => rat v) (List.find (fn (k, _) => k = y) (!cp))
            val X = scaled low a 1 2
          in
            SOME (F.E_RealValue (rat X, look y0, look y1, F.mk_rat y0 1, F.mk_rat y1 1))
          end
      | _ => NONE
    end


    in
      if Narrow.narrative original andalso not (has LABELLED_EU low) then NONE
      else econCore low
    end)

  fun economics text =
    let val t = collapse text
    in case econMasked (lower t) of
         NONE => NONE
       | SOME req => if not (answersM req) andalso not (Narrow.short_direct t)
                     then NONE else SOME req
    end

  (* ====================== retail ====================== *)
  (* Source periods remain typed until the kernel converts them. Every numeric
     occurrence in these inventory requests must have exactly one role. *)
  fun inventoryReq low number =
    let
      val N = QNUM
      val U = "(hours?|hrs?|days?|weeks?|wks?|years?)\\b(?!\\s*(?:[/^*\194\183\195\151]|per\\b))"
      val isRop = has "\\breorder point\\b|\\bwhen (?:should|do) (?:i|we) reorder\\b|\\brop\\b" low
      val isDays = has "\\bdays of inventory\\b|\\bdays inventory\\b|\\binventory days\\b" low
      val isTurnover = has "\\binventory turnover\\b|\\bturnover ratio\\b" low
      fun unit u = if has "^(?:hour|hr)" u then F.IT_Hour
        else if has "^day" u then F.IT_Day
        else if has "^(?:week|wk)" u then F.IT_Week else F.IT_Year365
      fun scan p = findall p low
      fun key m i = valOf (grp low m i)
      fun value m i = number (key m i)
      fun valopt m i = Option.map number (grp low m i)
      val allKeys = map (fn m => key m 1) (scan N)
      fun coverage keys = length keys = length allKeys andalso
        List.all (fn k => List.exists (fn x => k=x) keys) allKeys
      fun optionKeys m i = case grp low m i of NONE => [] | SOME k => [k]
      fun amount m = fmul (value m 1) (mult (grp low m 2))
      val targetPhrase = if isRop then "\\b(?:reorder point|rop)\\b" else if isTurnover then "\\b(?:inventory turnover|turnover ratio)\\b" else "\\b(?:days of inventory|inventory days|days inventory)\\b"
      val targetEnd = "(?=\\s*(?:[,.?!;:]|$|\\b(?:is|are|for|over|with|given|if|when|at|using|of)\\b))"
      val targetKnown = length (scan targetPhrase) = length (scan (targetPhrase ^ targetEnd))
      val badModel = not targetKnown orelse (length (List.filter (fn b => b) [isRop,isDays,isTurnover]) > 1) orelse has "\\b(?:months?|monthly|quarters?|quarterly|business days?|working days?|seasonal|changing|variable demand|varies|varying|360[- ]day)\\b" low
      fun refuse () = SOME (F.R_InventoryModel isRop)
    in
      if not (isRop orelse isDays orelse isTurnover) then NONE
      else if badModel then refuse ()
      else if isRop then
        let
          val explicit = scan (N ^ "\\s*(?:units?|items?)\\s*(?:/|a\\b|per\\b|each\\b)\\s*(?:" ^ N ^ "\\s*)?" ^ U)
          val daily = scan ("\\bdaily (?:demand|usage|sales)\\s*(?:of|is|=)?\\s*" ^ N)
          val leads = scan ("\\blead time\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*" ^ U)
          val leadsSuffix = scan (N ^ "[- ]" ^ U ^ "\\s+lead time\\b")
          val stocks = scan ("\\bsafety stock\\s*(?:of|is|=)?\\s*" ^ N ^ "(?=\\s*(?:units?\\b|items?\\b|and\\b|[,.;?]|$))")
          val stocksSuffix = scan (N ^ "\\s*(?:units?\\s*)?(?:of\\s*)?safety stock\\b")
          val demands = distinct (map (fn m => (value m 1,
            case valopt m 2 of SOME n => n | NONE => fint 1,
            unit (key m 3), key m 1 :: optionKeys m 2)) explicit @
            map (fn m => (value m 1, fint 1, F.IT_Day, [key m 1])) daily)
          val ls = map (fn m => (value m 1,unit (key m 2),key m 1)) (leads @ leadsSuffix)
          val stockMention = has "\\bsafety stock\\b" low
          val zeroStock = has "\\b(?:no|without) safety stock\\b|\\bsafety stock\\s*(?:is|of|=)\\s*zero\\b" low
          val ss = map (fn m => (value m 1,key m 1)) (stocks @ stocksSuffix)
        in case (demands, ls, ss) of
          ([(d,n,u,ks)], [(l,w,lk)], []) =>
            if (not stockMention orelse zeroStock) andalso coverage (lk::ks) then SOME (F.R_ROPPeriod (rat d,rat n,u,rat l,w,rat (fint 0))) else refuse ()
        | ([(d,n,u,ks)], [(l,w,lk)], [(st,sk)]) =>
            if coverage (sk::lk::ks) then SOME (F.R_ROPPeriod (rat d,rat n,u,rat l,w,rat st)) else refuse ()
        | _ => refuse ()
        end
      else
        let
          val costPat = "\\b(?:cogs|cost of goods sold)\\s*(?:of|is|was|=)?\\s*\\$\\s*" ^ N ^ "\\s*(k|m|million|thousand)?"
          val cs = scan costPat
          val avs = scan ("\\baverage inventory\\s*(?:of|is|was|=)?\\s*\\$\\s*" ^ N ^ "\\s*(k|m|million|thousand)?")
          val periods = scan (costPat ^ "\\s*(?:over|for|during|in|per|a|each)\\s*(?:the\\s+)?(?:" ^ N ^ "\\s*)?" ^ U)
          val annual = scan ("\\bannual\\s+" ^ costPat) @ scan (costPat ^ "\\s*annually\\b")
          val weekly = scan ("\\bweekly\\s+" ^ costPat) @ scan (costPat ^ "\\s*weekly\\b")
          val daily = scan ("\\bdaily\\s+" ^ costPat) @ scan (costPat ^ "\\s*daily\\b")
          val hourly = scan ("\\bhourly\\s+" ^ costPat) @ scan (costPat ^ "\\s*hourly\\b")
          val ps = map (fn m => (case valopt m 3 of SOME n => n | NONE => fint 1,
              unit (key m 4),optionKeys m 3)) periods @
            map (fn _ => (fint 1,F.IT_Year365,[])) annual @
            map (fn _ => (fint 1,F.IT_Week,[])) weekly @
            map (fn _ => (fint 1,F.IT_Day,[])) daily @
            map (fn _ => (fint 1,F.IT_Hour,[])) hourly
          val namedTargets =
            (if has "\\b(?:annual|annualized|yearly)\\s+(?:inventory turnover|turnover ratio)\\b|\\bannualiz(?:e|ing)\\b" low then [(fint 1,F.IT_Year365,[])] else []) @
            (if has "\\bweekly\\s+(?:inventory turnover|turnover ratio)\\b" low then [(fint 1,F.IT_Week,[])] else []) @
            (if has "\\bdaily\\s+(?:inventory turnover|turnover ratio)\\b" low then [(fint 1,F.IT_Day,[])] else []) @
            (if has "\\bhourly\\s+(?:inventory turnover|turnover ratio)\\b" low then [(fint 1,F.IT_Hour,[])] else [])
          val explicitTargets = scan ("\\b(?:inventory turnover|turnover ratio)\\s*(?:for|over)\\s*(?:(?:that|the|a)\\s*)?" ^ N ^ "[- ]*" ^ U)
          val targets = namedTargets @ map (fn m => (value m 1,unit (key m 2),[key m 1])) explicitTargets
          val unknownPeriod = has "\\b(?:over|during|per|weekly|daily|hourly)\\b|\\b(?:hours?|weeks?|years?)\\b" low
          fun finish c a (n,u,ks) =
            if isTurnover then
              (case targets of
                 [] => if coverage (key c 1::key a 1::ks)
                   then SOME (F.R_TurnoverPeriod (rat (amount c),rat (amount a),rat n,u,rat n,u)) else refuse ()
               | [(m,w,ts)] => if coverage (key c 1::key a 1::(ks @ ts))
                   then SOME (F.R_TurnoverPeriod (rat (amount c),rat (amount a),rat n,u,rat m,w)) else refuse ()
               | _ => refuse ())
            else if coverage (key c 1::key a 1::ks)
              then SOME (F.R_DaysPeriod (rat (amount c),rat (amount a),rat n,u)) else refuse ()
        in case (cs,avs,ps) of
          ([c],[a],[period]) => finish c a period
        | ([c],[a],[]) => if isTurnover then
            (* An explicit target period is not a source observation period. *)
            if coverage (key c 1::key a 1::List.concat (map #3 targets))
              andalso not (has (costPat ^ "\\s*(?:over|for|during|in|per|a|each|weekly|daily|hourly|annually)\\b") low)
            then finish c a (fint 1,F.IT_Year365,[]) else refuse ()
          else if not unknownPeriod andalso coverage [key c 1,key a 1]
            then SOME (F.R_Days (SOME (rat (amount c)),SOME (rat (amount a)))) else refuse ()
        | _ => refuse ()
        end
    end

  fun retail text =
    let
      val t = collapse text
      val low = lower t
    in
      case retailCore low of
        NONE => NONE
      | SOME (req as F.R_InventoryModel _) => SOME req
      | SOME (req as F.R_TurnoverPeriod _) => SOME req
      | SOME (req as F.R_DaysPeriod _) => SOME req
      | SOME (req as F.R_ROPPeriod _) => SOME req
      | SOME F.R_TaxModel => SOME F.R_TaxModel
      | SOME (req as F.R_DiscountTax _) => SOME req
      | SOME (req as F.R_TaxQuery _) => SOME req
      | SOME req => if Narrow.narrative t orelse
          (not (answersM req) andalso not (Narrow.short_direct t)) then NONE else SOME req
    end
  and retailCore original : F.request option = withNumbers original (fn low => fn fr_of =>
    let
      val N = QNUM
      val SIGNED_N = QNUM
      val cost = search ("\\b(?:cost|costs|wholesale|unit cost)\\s*(?:of|is|=|at)?\\s*\\$\\s*" ^ N ^ "|\\$\\s*" ^ N ^ "\\s*(?:to make|cost|wholesale)") low
      val price = search ("\\b(?:sells? (?:it )?for|selling price|retail price|price(?:d)?(?: at)?|sell (?:it )?at|sale price of)\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N) low
      val c = Option.map (fn m => fr_of (valOf (firstGroup low m [1, 2]))) cost
      val p = Option.map (fn m => fr_of (g1 low m)) price
      val pct = search (SIGNED_N ^ "\\s*%") low
      (* Each percentage occurrence has a fresh numeric-token identity. Claim
         it by a quantity role, then require exhaustive, disjoint coverage. *)
      val percent = "\\s*(?:%|percent\\b)"
      fun roleKeys pats = distinct (List.concat (map (fn pat =>
        map (fn m => g1 low m) (findall pat low)) pats))
      val percentKeys = map (fn m => g1 low m) (findall (N ^ percent) low)
      val discountKeys = roleKeys [N ^ percent ^ "\\s*(?:off|discount)\\b",
        "\\bdiscount(?:ed|s)?\\s*(?:by|of|at|is|=)?\\s*" ^ N ^ percent,
        "\\b(?:reduced|reduction|marked down)\\s*(?:by|of)?\\s*" ^ N ^ percent]
      val taxKeys = roleKeys [N ^ percent ^ "\\s*(?:sales\\s+)?tax\\b",
        "\\b(?:sales\\s+)?tax(?:ed)?\\s*(?:rate\\s*)?(?:of|at|is|=|by)?\\s*" ^ N ^ percent]
      val orderedDiscounts = List.filter (fn k => List.exists (fn d => d=k) discountKeys) percentKeys
      fun separateStages [] = true
        | separateStages [_] = true
        | separateStages (a::b::rest) =
            let val ma = valOf (search a low)
                val mb = valOf (search b low)
                val between = String.substring (low, #stop ma, #start mb - #stop ma)
                val clarification = has "\\b(?:meaning|equivalently|equivalent|namely)\\b|\\bin other words\\b|\\bthat is\\b|\\bi\\.e\\." between
                val succession = has "\\b(?:then|additional|further|another|next)\\b|\\bfollowed by\\b" between
                  orelse has "\\b(?:successive|stacked|sequential)\\b" low
            in not clarification andalso succession andalso separateStages (b::rest) end
      val stagesKnown = separateStages orderedDiscounts
      val discountIntent = has "\\bdiscount(?:ed|s|ing)?\\b|\\boff\\b|\\breduc(?:ed|tion)\\b|\\bmarked down\\b" low
      val taxIntent = has "\\btax(?:ed|es)?\\b" low
      fun claimed keys = length keys = length percentKeys andalso
        List.all (fn k => List.exists (fn c => c=k) keys) percentKeys
      val rolesDisjoint = not (List.exists (fn d => List.exists (fn x => x=d) taxKeys) discountKeys)
      val baseWords = "((?:[a-z]+\\s+){0,5}[a-z]+)"
      val baseLink = "\\s*(?:on|of|applies to|based on)\\s+(?!qnum[0-9]+q\\b)"
      val baseClaims = List.concat (map (fn pat => map (fn m => g1 low m) (findall pat low))
        ["(?:%|percent\\b)\\s*(?:sales\\s+)?tax\\s*(?:is\\s+calculated\\s*)?" ^ baseLink ^ baseWords,
         "\\btax(?:ed)?\\s*(?:rate\\s*)?(?:is|at|of|=|by)?\\s*qnum[0-9]+q\\s*(?:%|percent\\b)" ^ baseLink ^ baseWords,
         "\\btax(?:ed)?\\s*(?:is\\s*)?(?:calculated\\s*)?" ^ baseLink ^ baseWords])
      val basesKnown = List.all (fn b => has
        "^(?:the\\s+)?(?:original|full|undiscounted|discounted|sale)\\s+(?:price|amount|cost)$" b) baseClaims
      fun firstOf pats = List.mapPartial (fn pt => search pt low) pats
      fun first1 pats = case firstOf pats of m :: _ => SOME m | [] => NONE
      fun money1 pat = Option.map (fn m => fr_of (g1 low m)) (search pat low)
      val inventory = inventoryReq low fr_of
    in
      if isSome inventory then inventory
      else if has "\\bbreak[- ]?even\\b" low then
        let
          val fm = case search ("\\bfixed costs?\\s*(?:of|are|is|=)?\\s*\\$\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 ("\\$\\s*" ^ N ^ "\\s*(?:in |of |a month in |per month in )?fixed")
          val vm = case search ("\\bvariable cost\\s*(?:of|is|=)?\\s*\\$\\s*" ^ N) low of
                     SOME m => SOME (fr_of (g1 low m))
                   | NONE => money1 ("\\$\\s*" ^ N ^ "\\s*(?:variable|per unit (?:to make|in variable))")
          (* B-lane: "a $25 price" (amount before the word) *)
          val p = case p of SOME x => SOME x
                  | NONE => money1 ("\\$\\s*" ^ N ^ "\\s+(?:selling |sale )?price\\b")
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
          val target = quantityScope low
          val want_markup = has "\\bmark[- ]?up\\b" target andalso not (has "\\bmargin\\b" target)
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
      (* Combined retail arithmetic cannot fall back to a one-rate operation. *)
      else if discountIntent andalso taxIntent andalso has ("\\$\\s*" ^ SIGNED_N) low then
        let
          val offs = map fr_of discountKeys
          val original = has "\\b(?:tax|taxed)\\b[^!?;]{0,30}?\\b(?:on|of|applies to|based on)\\s+(?:the\\s+)?(?:original|full|undiscounted)\\b|\\bof (?:the )?(?:original|full|undiscounted) price[^.!?]{0,20}\\btax\\b" low
          val discounted = has "\\b(?:tax|taxed)\\b[^!?;]{0,30}?\\b(?:on|of|applies to|based on)\\s+(?:the\\s+)?(?:discounted|sale) price\\b" low
          val saving = wantsSavings low
          val taxOnly = has "\\btax amount\\b|\\bhow much (?:sales )?tax\\b|\\bwhat is the (?:sales )?tax\\b(?!\\s+rate)" low
          val savingBasis = has "\\b(?:full|original) price\\b[^.!?]*\\b(?:with|including|plus) tax\\b" low
        in
          case taxKeys of
            [taxKey] =>
              if length (findall "\\$" low) = 1 andalso not (null offs)
                 andalso stagesKnown andalso rolesDisjoint andalso claimed (discountKeys @ taxKeys)
                 andalso not (has "\\btax[- ]free\\b|\\bbefore tax\\b|-\\s*\\$" low)
                 andalso basesKnown andalso not (original andalso discounted)
                 andalso not (saving andalso (taxOnly orelse not savingBasis))
              then
                let val base = rat (fr_of (g1 low (valOf (search ("\\$\\s*" ^ SIGNED_N) low))))
                    val ds = map rat offs
                    val rate = rat (fdivi (fr_of taxKey) 100)
                in SOME (if saving then F.R_TaxQuery (base, ds, rate, original, F.RT_Saving)
                         else if taxOnly then F.R_TaxQuery (base, ds, rate, original, F.RT_Tax)
                         else if original then F.R_TaxQuery (base, ds, rate, true, F.RT_Final)
                         else F.R_DiscountTax (base, ds, rate)) end
              else SOME F.R_TaxModel
          | _ => SOME F.R_TaxModel
        end
      else if discountIntent andalso has ("\\$\\s*" ^ SIGNED_N) low then
        if length (findall "\\$" low) = 1 andalso not (null discountKeys)
           andalso null taxKeys andalso stagesKnown andalso claimed discountKeys then
          let val base = fr_of (g1 low (valOf (search ("\\$\\s*" ^ SIGNED_N) low)))
              val offs = map fr_of discountKeys
          in SOME (if wantsSavings low
                   then F.R_TaxQuery (rat base, map rat offs, rat (fint 0), false, F.RT_Saving)
                   else F.R_Discount (rat base, map rat offs)) end
        else SOME F.R_TaxModel
      else if taxIntent andalso has ("\\$\\s*" ^ SIGNED_N) low then
        (case taxKeys of
           [taxKey] => if length (findall "\\$" low) = 1 andalso null discountKeys andalso basesKnown andalso claimed taxKeys
             then let val base = fr_of (g1 low (valOf (search ("\\$\\s*" ^ SIGNED_N) low)))
                  in SOME (F.R_WithTax (rat base, rat (fdivi (fr_of taxKey) 100))) end
             else SOME F.R_TaxModel
         | _ => SOME F.R_TaxModel)
      else NONE
    end)

  (* ---------- dispatch ---------- *)
  val organs = ["finance", "finance-v2", "finance-v2-r2", "economics", "retail"]

  fun byId "finance" = finance 3
    | byId "finance-v2" = finance 3
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
