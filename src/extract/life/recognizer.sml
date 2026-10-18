(* UNTRUSTED. The English recognizer for the life-science family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/genetics-v2/organ_genetics_v{1,2}.py  (GeneticsOrganV2)
     upstream/root/specialists/biology/organ_biology_v1.py           (BiologyOrgan)
     upstream/root/specialists/ecology/organ_ecology_v1.py           (EcologyOrgan)
     upstream/root/specialists/forestry/organ_forestry_v1.py         (ForestryOrgan)
     upstream/root/specialists/wildlife/organ_wildlife_v1.py         (WildlifeOrgan)
     upstream/root/specialists/microbiology-v2/organ_micro_v{1,2}.py (MicroOrganV2)
   and of their shared narrowing rule narrow_v1.py. It reads numbers, genotypes,
   sequences and words off the question and builds typed Life requests; it
   computes nothing. Every value, decline and response text comes from the
   verified HOL kernels (Life.*_reply). The only decisions made here are the
   organs' own routing decisions (which branch a question belongs to, and the
   narrowing rule that hands word problems to the head).

   Patterns are written as in the organs and passed to the matcher as written;
   the question text is lower-cased by the caller where the organ matches
   case-insensitively (genotype tokens are matched on the original text, as the
   organ does). Differences from the organs, none of them on the panels: a
   division by zero in the organ (1 in 0, a zero doubling time) reaches the
   kernel, which declines it. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Life.reply) option
end =
struct
  structure L = Life

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
  fun anchored p s = search ("^(?:" ^ p ^ ")") s
  fun gstart ({groups, ...} : Regex.match) g = Option.map #1 (Vector.sub (groups, g))

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* regex substitution over the original text, matched on its lower-cased copy
     (ASCII lower-casing keeps every byte position) *)
  fun subWith p (f : string -> Regex.match -> string) t =
    let
      fun go i [] acc = String.concat (rev (String.extract (t, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (f t m :: String.substring (t, i, start - i) :: acc)
    in go 0 (findall p (lower t)) [] end

  fun stripCommas s = String.translate (fn #"," => "" | c => String.str c) s
  fun bigOf s = valOf (IntInf.fromString (stripCommas s))
  fun natOf (v : IntInf.int) : L.nat = L.nat_of_integer v
  fun natS s = natOf (bigOf s)
  fun natI (i : int) : L.nat = natOf (IntInf.fromInt i)

  (* decimal literal "1,000.50" / "-12.5" / ".5" as an exact rational *)
  fun decParts (lit0 : string) : IntInf.int * IntInf.int =
    let
      val lit = stripCommas lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString ((if ip = "" then "0" else ip) ^ fp))
    in (if neg then IntInf.~ num else num, IntInf.pow (10, size fp)) end
  fun ratOf lit = let val (n, d) = decParts lit in L.mk_rat n d end
  (* lit * 10^e *)
  fun ratSci lit (e : int) =
    let val (n, d) = decParts lit
    in if e >= 0 then L.mk_rat (IntInf.* (n, IntInf.pow (10, e))) d
       else L.mk_rat n (IntInf.* (d, IntInf.pow (10, ~e))) end
  (* lit / 100 *)
  fun ratPercent lit = let val (n, d) = decParts lit in L.mk_rat n (IntInf.* (d, 100)) end
  fun intOf s = valOf (Int.fromString s)

  (* ---------- narrow_v1 ---------- *)
  structure Narrow =
  struct
    fun strip s = collapse s
    fun words t = length (String.tokens Char.isSpace t)
    (* whitespace runs preceded by one of the characters in ends, in the stripped text *)
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
    fun last_sentence t =
      let
        val (s, sp) = splits ".!?;" t
      in
        case rev sp of
          [] => s
        | i :: _ => let fun skip j = if j < size s andalso Char.isSpace (String.sub (s, j)) then skip (j + 1) else j
                    in String.extract (s, skip i, NONE) end
      end
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  (* the organs' wrapper: a decline is kept only on a short direct question *)
  fun gate text (r : L.reply) = if L.answered r orelse Narrow.short_direct text then SOME r else NONE

  val N = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"

  (* ---------- genetics ---------- *)
  val GT = "\\b((?:[A-Za-z][A-Za-z]){1,6})\\b"
  val crossRe = GT ^ "\\s*(?:x|\195\151|and|(?:is\\s+)?crossed with|with)\\s*" ^ GT

  fun zygOf c1 c2 =
    case (Char.isUpper c1, Char.isUpper c2) of
      (true, true) => L.Hom_dom
    | (false, false) => L.Hom_rec
    | _ => L.Het
  fun locusOf c1 c2 = L.Locus (String.str (Char.toUpper c1), String.str (Char.toLower c1), zygOf c1 c2)
  fun lociOf s = List.tabulate (size s div 2, fn i => (String.sub (s, 2 * i), String.sub (s, 2 * i + 1)))
  fun validPair p1 p2 =
    size p1 = size p2 andalso (size p1 >= 2 andalso size p1 <= 12 andalso size p1 mod 2 = 0) andalso
    List.all (fn (a, b) => 
      let val l = Char.toLower
      in l a = l b end) (lociOf p1) andalso
    length (List.foldl (fn ((a, _), seen) => if List.exists (fn c => c = Char.toLower a) seen then seen else Char.toLower a :: seen) [] (lociOf p1)) = size p1 div 2 andalso
    List.all (fn ((a, b), (c, d)) =>
      let val l = Char.toLower in l a = l c andalso l a = l d end) (ListPair.zip (lociOf p1, lociOf p2))

  fun hwSource low : L.hwsrc option =
    let
      val q2 = search "\\b1 in ([\\d,]+)\\b" low
      val fq =
        case search "\\bq\\s*(?:=|is)\\s*(-?\\d*(?:\\.\\d+)|-?\\d+)" low of
          SOME m => SOME (g1 low m)
        | NONE => (case search "\\brecessive allele (?:frequency )?(?:is|of|=)\\s*(-?\\d*(?:\\.\\d+)|-?\\d+)" low of
                     SOME m => SOME (g1 low m) | NONE => NONE)
      val fp =
        case search "\\bp\\s*(?:=|is)\\s*(-?\\d*(?:\\.\\d+)|-?\\d+)" low of
          SOME m => SOME (g1 low m)
        | NONE => (case search "\\bdominant allele (?:frequency )?(?:is|of|=)\\s*(-?\\d*(?:\\.\\d+)|-?\\d+)" low of
                     SOME m => SOME (g1 low m) | NONE => NONE)
      val fq2 =
        case search "(\\d+(?:\\.\\d+)?)\\s*%\\s*(?:of (?:(?:the|a|an) )?(?:(?:[a-z]+\\s+){0,2}population|people|individuals) )?(?:(?:show|have|has|express)\\w*\\s+)?(?:the\\s+)?recessive" low of
          SOME m => SOME (g1 low m, true)
        | NONE =>
          (case search "\\brecessive (?:phenotype|trait|condition|disorder)\\w*[^.?]{0,40}?(?:in|affects|of)\\s+(\\d+(?:\\.\\d+)?)\\s*%" low of
             SOME m => SOME (g1 low m, true)
           | NONE =>
             (case search "\\bq\\s*(?:\\^2|\194\178|squared)\\s*(?:=|is)\\s*(-?\\d*(?:\\.\\d+)|-?\\d+)" low of
                SOME m => SOME (g1 low m, String.isSubstring "%" (Regex.whole low m))
              | NONE => NONE))
    in
      case q2 of
        SOME m => SOME (L.HWone (natS (g1 low m)))
      | NONE =>
          (case fq2 of
             SOME (lit, pct) => SOME (L.HWq2 (if pct then ratPercent lit else ratOf lit))
           | NONE =>
               (case fq of
                  SOME lit => SOME (L.HWqs (ratOf lit))
                | NONE => (case fp of SOME lit => SOME (L.HWps (ratOf lit)) | NONE => NONE)))
    end

  fun gV1 t : L.greq option =
    let
      val low = lower t
    in
      if has "\\bhardy[- ]weinberg\\b|\\ballele frequenc\\w*\\b|\\bcarriers?\\b|\\bheterozygote frequency\\b|\\brecessive (?:phenotype|trait|condition|disorder)\\b" low
         andalso has "\\bfrequenc\\w*\\b|\\bproportion\\b|\\bpercent\\w*\\b|\\bwhat fraction\\b|\\bhow many\\b|\\bcarriers?\\b|\\b1 in \\d" low
      then
        (case hwSource low of
           NONE => NONE
         | SOME src =>
             if has "\\bcarriers?\\b|\\bheterozyg\\w*\\b|\\b2pq\\b" low then SOME (L.G_HW (L.HK_carrier, src))
             else if has "\\bhomozygous dominant\\b|\\bp\\s*(?:\\^2|\194\178|squared)\\b" low then SOME (L.G_HW (L.HK_p2, src))
             else if has "\\bdominant allele\\b|\\bfrequency of p\\b|\\bwhat is p\\b" low then SOME (L.G_HW (L.HK_p, src))
             else if has "\\brecessive allele\\b|\\bfrequency of q\\b|\\bwhat is q\\b" low then SOME (L.G_HW (L.HK_q, src))
             else NONE)
      else
        (case search crossRe (lower t) of
           NONE => NONE
         | SOME m =>
             if not (has "\\bcross\\w*\\b|\\boffspring\\b|\\bprogeny\\b|\\bpunnett\\b|\\bchild\\w*\\b|\\bprobability\\b|\\bchance\\b|\\bratio\\b|\\bproportion\\b" low)
             then NONE
             else
               let
                 val p1 = valOf (grp t m 1)
                 val p2 = valOf (grp t m 2)
                 val s1 = valOf (gstart m 1)
                 val s2 = valOf (gstart m 2)
               in
                 if not (validPair p1 p2) then NONE
                 else
                   let
                     val n = size p1
                     val cands = findall ("\\b([a-z]{" ^ Int.toString n ^ "})\\b") (lower t)
                     fun okCand (c : Regex.match) =
                       let val s = #start c
                           val w = Regex.whole t c
                       in s <> s1 andalso s <> s2 andalso validPair w p1
                          andalso Char.toLower (String.sub (w, 0)) = Char.toLower (String.sub (p1, 0)) end
                     val want = Option.map (Regex.whole t) (List.find okCand cands)
                     val lp = lociOf p1
                     val lq = lociOf p2
                     val pairs = ListPair.zip (map (fn (a, b) => locusOf a b) lp, map (fn (a, b) => locusOf a b) lq)
                   in
                     if isSome want andalso has "\\bprobability\\b|\\bchance\\b|\\bproportion\\b|\\bfraction\\b|\\bwhat percent\\w*\\b|\\bhow likely\\b" low then
                       let val w = valOf want
                           val ws = map (fn (a, b) => zygOf a b) (lociOf w)
                       in SOME (L.G_Geno (map (fn ((a, b), z) => (a, (b, z))) (ListPair.zip (pairs, ws)))) end
                     else if n = 2 andalso has "\\brecessive (?:phenotype|trait)\\b|\\bshow the recessive\\b|\\bexpress the recessive\\b" low then
                       SOME (L.G_Pheno (false, #1 (hd pairs), #2 (hd pairs)))
                     else if n = 2 andalso has "\\bdominant (?:phenotype|trait)\\b|\\bshow the dominant\\b|\\bexpress the dominant\\b" low then
                       SOME (L.G_Pheno (true, #1 (hd pairs), #2 (hd pairs)))
                     else if has "\\bphenotyp\\w* ratio\\b|\\bphenotypic ratio\\b" low then SOME (L.G_PRatio pairs)
                     else if n = 2 andalso has "\\bgenotyp\\w* ratio\\b|\\bgenotypic ratio\\b" low then
                       SOME (L.G_GRatio (#1 (hd pairs), #2 (hd pairs)))
                     else NONE
                   end
               end)
    end

  fun genetics text : L.reply option =
    if Narrow.narrative text then NONE
    else if isSome (search crossRe (lower text)) andalso has "\\blinked\\b|\\blinkage\\b|\\bsex[- ]linked\\b|\\bincomplete dominance\\b|\\bcodominan\\w*\\b|\\bepistasis\\b" (lower text) then SOME (L.g_reply L.G_Model)
    else
      let
        val t0 = collapse text
        val t1 = subWith "\\bof an? (population|group|sample)\\b" (fn t => fn m => "of the " ^ g1 t m) t0
        val t2 = subWith "\\b(shows?|has|have|express(?:es)?)\\s+an?\\s+recessive\\b" (fn t => fn m => g1 t m ^ " the recessive") t1
        val t3 = subWith "\\b(what is|find|calculate|give)\\s+q\\b(?![\\w,])" (fn t => fn m => g1 t m ^ " q, the recessive allele frequency") t2
        val t = subWith "\\b(what is|find|calculate|give)\\s+p\\b(?![\\w,])" (fn t => fn m => g1 t m ^ " p, the dominant allele frequency") t3
        val viaCross =
          case search crossRe (lower t) of
            NONE => NONE
          | SOME _ =>
              let
                val tc1 = subWith "\\bwhat fraction\\b|\\bwhat proportion\\b|\\bproportion\\b|\\bwhat percent(?:age)?\\b" (fn _ => fn _ => "what probability") t
                val tc = subWith "\\bhardy[- ]weinberg\\b|\\ballele frequenc\\w*\\b" (fn _ => fn _ => "") tc1
              in gV1 tc end
        val req =
          case viaCross of
            SOME r => SOME r
          | NONE =>
              (case gV1 t of
                 SOME r => SOME r
               | NONE =>
                   if has "\\bhardy[- ]weinberg\\b|\\ballele frequenc\\w*\\b|\\bcarrier frequency\\b" (lower t) then SOME L.G_Need
                   else NONE)
      in
        case req of
          NONE => NONE
        | SOME r => gate text (L.g_reply r)
      end

  (* ---------- biology ---------- *)
  fun nucOf c =
    case c of
      #"A" => L.NA | #"C" => L.NC | #"G" => L.NG | #"T" => L.NT | #"U" => L.NU
    | _ => raise Fail "not a nucleotide"

  (* The organ matches an upper-case-only token first, then a lower-case-only
     token of six or more bases. The matcher folds case, so each candidate found
     on the lower-cased text is accepted only if the original text has the case
     the organ's pattern requires. *)
  fun allUpper s = CharVector.all (fn c => not (Char.isLower c)) s
  fun allLower s = CharVector.all (fn c => not (Char.isUpper c)) s
  fun bioSeq t : string option =
    let
      val low = lower t
      val upperPat = "\\b([acgtu]{3,}(?:[ \\-][acgtu]{3})*)\\b"
      val lowerPat = "\\b([acgtu]{6,})\\b"
      fun firstOk pat ok =
        List.find (fn m => ok (valOf (grp t m 1))) (findall pat low)
      val m = case firstOk upperPat allUpper of
                SOME m => SOME (valOf (grp t m 1))
              | NONE => (case firstOk lowerPat allLower of SOME m => SOME (valOf (grp t m 1)) | NONE => NONE)
    in
      case m of
        NONE => NONE
      | SOME g =>
          let val s = String.map Char.toUpper (String.translate (fn c => if Char.isSpace c orelse c = #"-" then "" else String.str c) g)
          in if size s >= 3 andalso CharVector.all (fn c => Char.contains "ACGTU" c) s then SOME s else NONE end
    end

  fun biology text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.b_reply r)
      in
        if not (has "\\bdna\\b|\\brna\\b|\\bmrna\\b|\\bsequence\\b|\\bstrand\\b|\\bcodon\\b|\\btranslat\\w*\\b|\\btranscri\\w*\\b|\\bcomplement\\w*\\b|\\bgc content\\b|\\bprotein\\b|\\bamino acid\\b" low)
        then NONE
        else
          case bioSeq t of
            NONE => NONE
          | SOME s =>
              let
                val xs = map nucOf (String.explode s)
                val both = String.isSubstring "U" s andalso String.isSubstring "T" s
              in
                if both then fin (L.Bio (L.Op_complement, xs))
                else if size s = 3 andalso has "\\bcodon\\b|\\bcode for\\b|\\bencode\\w*\\b|\\bamino acid\\b|\\bspecif\\w*\\b" low
                then fin (L.Bio (L.Op_codon, xs))
                else if has "\\bgc content\\b|\\bgc percent\\w*\\b|\\bgc %|\\bpercent(?:age)? (?:of )?g(?:\\s*\\+\\s*|c\\b)" low
                then fin (L.Bio (L.Op_gc, xs))
                else if has "\\breverse[- ]complement\\b" low then fin (L.Bio (L.Op_revcomp, xs))
                else if has "\\bcomplement\\w*\\b" low andalso not (has "\\btranscri\\w*\\b|\\btranslat\\w*\\b" low)
                then fin (L.Bio (L.Op_complement, xs))
                else if has "\\btranscri\\w*\\b|\\bmrna\\b(?!.*\\btranslat)" low
                        andalso not (has "\\btranslat\\w*\\b|\\bprotein\\b|\\bamino acids?\\b" low)
                then
                  (if String.isSubstring "U" s then NONE
                   else fin (L.Bio (L.Op_transcribe (has "\\btemplate\\b|\\bantisense\\b|\\bnon-?coding strand\\b" low), xs)))
                else if has "\\btranslat\\w*\\b|\\bprotein\\b|\\bamino acid sequence\\b|\\bpeptide\\b" low then
                  (if has "\\bhow many amino acids\\b|\\blength of the protein\\b|\\bhow long\\b" low
                   then fin (L.Bio (L.Op_protlen, xs))
                   else fin (L.Bio (L.Op_translate, xs)))
                else NONE
              end
      end

  fun litPos lit = IntInf.> (#1 (decParts lit), 0)

  (* ---------- ecology ---------- *)
  fun ecoCounts low : IntInf.int list option =
    case search "\\b(?:counts?|abundances?|individuals|numbers?)\\b[^0-9]{0,30}?((?:\\d+(?:,\\d{3})*\\s*(?:,|and|;)\\s*)+\\d+(?:,\\d{3})*)" low of
      NONE => NONE
    | SOME m =>
        let
          val g = g1 low m
          val g' = subWith "(\\d),(\\d{3})\\b" (fn t => fn mm => g1 t mm ^ valOf (grp t mm 2)) g
          val vals = map (fn mm => bigOf (Regex.whole g' mm)) (findall "\\d+(?:,\\d{3})*" g')
        in if length vals >= 2 then SOME vals else NONE end

  val ecoUnits = "(years?|generations?|days?|hours?|months?)"
  val ecoUnits2 = "(years?|generations?|days?|months?)"

  fun ecoTime low units =
    case search ("\\bafter\\s+" ^ N ^ "\\s*" ^ units ^ "\\b|\\bin\\s+" ^ N ^ "\\s*" ^ units ^ "\\b") low of
      NONE => NONE
    | SOME m => SOME (ratOf (valOf (firstGroup low m [1, 3])))

  fun ecoRest low : L.ereq option =
    let
      val K = search ("\\bcarrying capacity\\s*(?:\\(k\\)\\s*)?(?:of|is|=)?\\s*" ^ N ^ "|\\bk\\s*=\\s*" ^ N) low
      val r_ = search "\\b(?:intrinsic |per capita )?(?:growth )?rate\\s*(?:\\(r\\)\\s*)?(?:of|is|=)?\\s*(-?\\d*\\.?\\d+)\\s*(%)?|\\br\\s*=\\s*(-?\\d*\\.?\\d+)" low
      val n0 = search ("\\b(?:initial|starting|current) (?:population|size)\\s*(?:of|is|=)?\\s*" ^ N ^ "|\\bn0?\\s*=\\s*" ^ N ^ "|\\bpopulation (?:of|is)\\s*" ^ N) low
      val rlit = Option.map (fn m => valOf (firstGroup low m [1, 3])) r_
      val rv = case r_ of
                 NONE => NONE
               | SOME m =>
                   (case grp low m 2 of
                      SOME _ => SOME (ratPercent (valOf rlit))
                    | NONE => SOME (ratOf (valOf rlit)))
      val n0lit = Option.map (fn m => valOf (firstGroup low m [1, 2, 3])) n0
      val n0v = Option.map ratOf n0lit
      val Kv = Option.map (fn m => ratOf (valOf (firstGroup low m [1, 2]))) K
    in
      if isSome K andalso isSome r_ andalso isSome n0 andalso has "\\blogistic\\b|\\bcarrying capacity\\b" low then
        let
          val ask = lower (Narrow.last_sentence low)
          val tm = ecoTime low ecoUnits
        in
          if isSome tm andalso has "\\bpopulation\\b|\\bhow many\\b|\\bsize\\b" ask
             andalso not (has "\\bdn/dt\\b|\\bhow fast\\b|\\bgrowth rate\\b" ask)
          then
            (* N0 <= 0 is not taken by the organ *)
            (if not (litPos (valOf n0lit)) then NONE
             else SOME (L.E_LogN (valOf rv, valOf n0v, valOf Kv, valOf tm)))
          else SOME (L.E_LogRate (valOf rv, valOf n0v, valOf Kv))
        end
      else if isSome r_ andalso isSome n0 andalso has "\\bexponential\\w*\\b|\\bgrow\\w*\\b" low andalso not (isSome K) then
        let
          val tm = ecoTime low ecoUnits
        in
          if has "\\bdoubling time\\b|\\bhow long to double\\b|\\bdouble\\b" low then
            (if not (litPos (valOf rlit)) then NONE else SOME (L.E_Doubling (valOf rv)))
          else
            case tm of
              SOME t => SOME (L.E_ExpN (valOf rv, valOf n0v, t))
            | NONE => ecoLam low n0v
        end
      else ecoLam low n0v
    end
  and ecoLam low n0v : L.ereq option =
    case search "\\blambda\\s*(?:\\(\206\187\\)\\s*)?(?:of|is|=)?\\s*(\\d*\\.?\\d+)|\\b\206\187\\s*=\\s*(\\d*\\.?\\d+)|\\bfinite rate of increase\\s*(?:of|is)?\\s*(\\d*\\.?\\d+)" low of
      NONE => NONE
    | SOME lm =>
        (case n0v of
           NONE => NONE
         | SOME n0 =>
             (case ecoTime low ecoUnits2 of
                NONE => NONE
              | SOME t => SOME (L.E_Geom (ratOf (valOf (firstGroup low lm [1, 2, 3])), n0, t))))

  fun ecology text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.e_reply r)
        fun rest () = case ecoRest low of NONE => NONE | SOME r => fin r
      in
        if has "\\bshannon\\b|\\bsimpson\\w*\\b|\\bevenness\\b|\\bdiversity index\\b|\\bspecies richness\\b" low then
          (case ecoCounts low of
             NONE => NONE
           | SOME c =>
               let
                 val total = List.foldl IntInf.+ 0 c
                 val cs = map natOf c
               in
                 if total <= 0 then NONE
                 else if has "\\bevenness\\b" low then fin (L.E_Evenness cs)
                 else if has "\\bshannon\\b" low then fin (L.E_Shannon cs)
                 else if has "\\bsimpson\\w*\\b" low then
                   (if total < 2 then NONE
                    else if has "\\breciprocal\\b|\\binverse\\b|\\b1\\s*/\\s*d\\b" low then fin (L.E_SimpInv cs)
                    else if has "\\bdiversity\\b|\\b1\\s*-\\s*d\\b" low then fin (L.E_SimpDiv cs)
                    else fin (L.E_SimpD cs))
                 else if has "\\brichness\\b" low then fin (L.E_Richness cs)
                 else rest ()
               end)
        else rest ()
      end

  (* ---------- forestry ---------- *)
  val FN = "(\\d+(?:\\.\\d+)?)"

  fun forestry text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.f_reply r)
        val inchPat = FN ^ "[- ]?(?:inch|in\\.?|\")"
      in
        if not (has "\\btrees?\\b|\\blogs?\\b|\\bdbh\\b|\\bbasal area\\b|\\bstand\\b|\\btimber\\b|\\bforest\\w*\\b|\\bclinometer\\b|\\bdoyle\\b|\\bsmalian\\b|\\bseedlings?\\b|\\bplanting\\b" low)
        then NONE
        else if has "\\bdoyle\\b" low then
          let
            val d = search (inchPat ^ "\\s*(?:small[- ]end\\s*)?(?:diameter|dib|log)?|\\bdiameter\\s*(?:of|is)?\\s*" ^ FN ^ "\\s*(?:inches|in)") low
            val l = search (FN ^ "[- ]?(?:foot|feet|ft)\\b") low
          in
            case (d, l) of
              (SOME dm, SOME lm) => fin (L.F_Doyle (ratOf (valOf (firstGroup low dm [1, 2])), ratOf (g1 low lm)))
            | _ => NONE
          end
        else if has "\\bsmalian\\b|\\bcubic (?:feet|foot) (?:in|of) (?:the |a |this )?log\\b|\\blog volume\\b" low then
          let
            val ds = map (fn m => g1 low m) (findall inchPat low)
            val l = search (FN ^ "[- ]?(?:foot|feet|ft)\\b\\s*(?:long)?") low
          in
            case (ds, l) of
              (d1 :: d2 :: _, SOME lm) => fin (L.F_Smalian (ratOf d1, ratOf d2, ratOf (g1 low lm)))
            | _ => NONE
          end
        else
          let
            val sp = search (FN ^ "\\s*(?:ft|feet|foot|')?\\s*(?:x|\195\151|by)\\s*" ^ FN ^ "\\s*(?:ft|feet|foot|')\\s*(?:spacing|apart|grid)?") low
          in
            if isSome sp andalso has "\\bper acre\\b|\\ban acre\\b|\\btrees per acre\\b|\\bhow many (?:trees|seedlings)\\b" low
               andalso has "\\bspac\\w*\\b|\\bplant\\w*\\b|\\bgrid\\b" low
            then
              let val m = valOf sp
                  val a = ratOf (g1 low m) val b = ratOf (valOf (grp low m 2))
              in if not (litPos (g1 low m)) orelse not (litPos (valOf (grp low m 2))) then NONE else fin (L.F_Tpa (a, b)) end
            else if has "\\bheight\\b|\\bhow tall\\b" low andalso has "\\bangle\\b|\\bdegrees?\\b|\194\176|\\bclinometer\\b" low then
              let
                val dist = search (FN ^ "\\s*(ft|feet|m|meters?|metres?)\\s*(?:away|from the (?:tree|base)|from the trunk)|\\b(?:standing|distance of|from)\\s*" ^ FN ^ "\\s*(ft|feet|m|meters?|metres?)") low
                val ang = search (FN ^ "\\s*(?:\194\176|degrees?\\b)") low
              in
                case (dist, ang) of
                  (SOME dm, SOME am) =>
                    let
                      val (dv, du) = case grp low dm 1 of
                                       SOME v => (v, valOf (grp low dm 2))
                                     | NONE => (valOf (grp low dm 3), valOf (grp low dm 4))
                      val eye = search ("\\beye (?:height|level)\\s*(?:of|is)?\\s*" ^ FN ^ "\\s*(?:ft|feet|m|meters?)") low
                    in
                      fin (L.F_Height (ratOf dv, ratOf (g1 low am), Option.map (fn m => ratOf (g1 low m)) eye,
                                       String.isPrefix "f" du))
                    end
                | _ => NONE
              end
            else
              let
                val dbh = search ("\\b(?:dbh|diameter(?: at breast height)?)\\s*(?:of|is|=)?\\s*" ^ FN ^ "\\s*(inches|inch|in\\b|\"|cm)|" ^ FN ^ "[- ]?(inches|inch|in\\b|\"|cm)\\s*(?:dbh|diameter)") low
              in
                case dbh of
                  SOME m =>
                    if has "\\bbasal area\\b" low then
                      let
                        val (d, u) = case grp low m 1 of
                                       SOME v => (v, valOf (grp low m 2))
                                     | NONE => (valOf (grp low m 3), valOf (grp low m 4))
                        val tpa = search (FN ^ "\\s*trees\\s*(?:per|an|/)\\s*acre") low
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
  val MARK = "(?:marked|tagged|banded|marking|tagging|banding)"
  val CAP = "(?:caught|captured|trapped|netted|sampled|collected|seined)"

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
          val ofthe = anchored "\\s+of\\s+the\\s+(\\d+(?:,\\d{3})*)" aft
        in
          if isSome ofthe andalso not (isSome (!outR)) then
            (outR := SOME v; setdef outC (bigOf (g1 aft (valOf ofthe))))
          else if isSome (anchored "\\s+(?:\\w+\\s+){0,2}?(?:of (?:them|these|which)\\b|(?:were|was|had been|are)\\s+(?:already|previously)\\b|recaptur|(?:marked|tagged|banded) ones\\b|carried|bore|had (?:tags|marks|bands)|with (?:tags|marks|bands))" aft)
                  orelse has "\\b(?:recaptured|contained|including|found)\\s+$" bef
                  orelse has "\\b(?:recaptured|recaptures|recapture count)\\s*(?:of|was|were|=|:)?\\s*$" bef
          then setdef outR v
          else if has ("\\bsecond (?:sample|capture|survey|session|trapping)\\s+of\\s+$") bef
                  orelse has ("\\b(?:later|again|second|next|afterwards)\\b[^.;]{0,30}" ^ CAP ^ "\\s+$") bef
                  orelse (has (CAP ^ "\\s+$") bef
                          andalso has "^\\s+\\w*\\s*(?:in|during|on)\\s+(?:the|a)\\s+second\\b|^[^.;]{0,40}\\b(?:second|later|again)\\b" aft)
                  orelse isSome (anchored ("\\s+(?:\\w+\\s+){0,2}?" ^ CAP ^ "\\s+(?:in|during|on)\\s+(?:the|a)\\s+(?:second|recapture)") aft)
                  orelse (has ("\\b" ^ CAP ^ "\\s+$") bef andalso has "\\b(?:later|second|again)\\b" bef)
          then setdef outC v
          else if has (MARK ^ "\\s+(?:and released\\s+)?$") bef
                  orelse isSome (anchored ("\\s+(?:\\w+\\s+){0,2}?(?:were |was |had been |are )?" ^ MARK ^ "\\b") aft)
          then setdef outM v
          else ()
        end
      val _ = List.app step (findall "(?<![\\d.,])(\\d+(?:,\\d{3})*)(?![\\d.,]*\\d)" low)
    in (!outM, !outC, !outR) end

  val animals = "(?:animals|fish|deer|birds|turtles|frogs|mice|rabbits|butterflies|beetles|trout|salamanders|individuals|lizards|bats|squirrels)"

  fun wildlife text : L.reply option =
    let
      val t0 = String.concatWith " " (String.tokens Char.isSpace text)
      val low0 = lower t0
      val mr = has "\\b(?:marked|tagged|banded|recaptur\\w*|mark[- ](?:and[- ])?recapture)\\b" low0
      val mrTurn = mr andalso Narrow.sentences t0 <= 4 andalso Narrow.words t0 <= 60
    in
      if Narrow.narrative text andalso not mrTurn then NONE
      else
        let
          val low = low0
          fun fin (r : L.reply) =
            if L.answered r orelse Narrow.short_direct text orelse mrTurn then SOME r else NONE
          val mrGate = has "\\bmark[- ](?:and[- ])?recapture\\b|\\blincoln[- ]petersen\\b|\\bchapman\\b|\\brecaptur\\w*\\b|\\btagged\\b|\\bbanded\\b|\\bmarked\\b" low
                       andalso has "\\bestimate\\w*\\b|\\bpopulation\\b|\\bhow many\\b" low
        in
          if mrGate then
            let
              val (m, c, r) = roles low
              val onat = Option.map natOf
            in fin (L.w_reply (L.W_Lincoln (onat m, onat c, onat r, has "\\bchapman\\b" low))) end
          else
            let
              val dens = search (N ^ "\\s+" ^ animals ^ "\\b[^.?]{0,40}?\\b(?:in|on|across|over)\\s+(?:an?\\s+)?(\\d+(?:\\.\\d+)?)\\s*(hectares?|ha|acres?|km2|km\194\178|square (?:kilomet(?:er|re)s?|miles?)|sq mi|mi2)") low
            in
              case dens of
                SOME dm =>
                  if has "\\bdensity\\b|\\bper (?:hectare|acre|km|square)\\b" low then
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
      val surv = search (N ^ "\\s+(?:of\\s+\\d+(?:,\\d{3})*\\s+)?(?:\\w+\\s+){0,2}?(?:survived|were still alive|remained alive|lived)\\b") low
      (* Explicit "s of n" roles take precedence over a nearby monitored verb.
         Otherwise the old leftmost match can read "75 of 100 monitored" as
         75 starting animals and silently turn mortality into zero. *)
      val start = case search "\\b(?:of|out of|from)\\s+(\\d+(?:,\\d{3})*)\\b" low of
          SOME m => SOME m
        | NONE => search "(\\d+(?:,\\d{3})*)\\s+(?:\\w+\\s+){0,2}?(?:were )?(?:released|tagged|collared|monitored|hatched|born)\\b" low
    in
      case (surv, start) of
        (SOME sm, SOME st) =>
          if has "\\bsurvival\\b|\\bmortality\\b|\\bdeath rate\\b" low then
            let
              val s = bigOf (g1 low sm)
              val n0 = bigOf (valOf (firstGroup low st [1, 2]))
            in
              if n0 <= 0 orelse s > n0 then NONE
              else fin (L.w_reply (L.W_Surv (natOf s, natOf n0, has "\\bmortality\\b|\\bdeath rate\\b" low)))
            end
          else NONE
      | _ => NONE
    end

  (* ---------- microbiology v2 ---------- *)
  val SCI = "(\\d+(?:\\.\\d+)?)\\s*(?:(?:x|\195\151|\\*)\\s*10\\s*\\^?\\s*([+-]?\\d+)|e([+-]?\\d+))?"
  val TU = "\\s*(minutes?|min|hours?|hrs?|h|days?)\\b"
  val ASKS = "\\?|\\b(?:find|calculate|compute|determine|estimate|what|how many|how long|give)\\b"

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

  fun microDil low : L.rat option =
    case search "10\\s*\\^\\s*-\\s*(\\d+)|10\\s*\\^\\s*\\(\\s*-\\s*(\\d+)\\s*\\)|1\\s*[:/]\\s*10\\s*\\^\\s*(\\d+)|1e-(\\d+)|1\\s*[:/]\\s*(\\d+(?:,\\d{3})*)\\b" low of
      NONE => NONE
    | SOME m =>
        (case grp low m 5 of
           SOME g => SOME (L.mk_rat 1 (bigOf g))
         | NONE =>
             let val k = intOf (valOf (firstGroup low m [1, 2, 3, 4]))
             in SOME (L.mk_rat 1 (IntInf.pow (10, k))) end)

  fun microV1 t : L.mreq option =
    let
      val low = lower t
    in
      if has "\\bcfu\\b|\\bcolon(?:y|ies)\\b|\\bplate count\\b" low andalso has "\\bdilution\\b|10\\s*\\^|\\b1\\s*[:/]\\s*\\d" low then
        let
          val cm = search (N ^ "\\s*colon(?:y|ies)\\b") low
          val dil = microDil low
          val vm = search (N ^ "\\s*(ml|\194\181l|ul|microlit\\w+|millilit\\w+)\\s*(?:was |were )?(?:plated|spread|of the dilution)?") low
        in
          case (cm, dil) of
            (SOME c, SOME d) =>
              let
                val vol = case vm of
                            NONE => L.mk_rat 1 1
                          | SOME v =>
                              let val u = valOf (grp low v 2)
                              in if String.isPrefix "\194\181" u orelse String.isPrefix "u" u orelse String.isPrefix "micro" u
                                 then ratDiv (g1 low v) 1000 else ratOf (g1 low v) end
              in SOME (L.M_CFU (ratOf (g1 low c), d, vol)) end
          | _ => NONE
        end
      else
        case search "\\b(\\d+|two|three|four|five|six)\\s+(?:serial\\s+)?(?:1\\s*[:/]\\s*(\\d+)|(\\d+)[- ]fold)\\s+(?:serial\\s+)?dilutions?\\b" low of
          SOME sm =>
            if has "\\btotal\\b|\\bfinal\\b|\\boverall\\b" low then
              let
                val ks = g1 low sm
                val k = case ks of "two" => 2 | "three" => 3 | "four" => 4 | "five" => 5 | "six" => 6 | _ => intOf ks
                val f = intOf (valOf (firstGroup low sm [2, 3]))
              in SOME (L.M_Serial (natI f, natI k)) end
            else microGrowth low
        | NONE => microGrowth low
    end
  and microGrowth low : L.mreq option =
    if not (has "\\bbacteri\\w*\\b|\\bcells?\\b|\\bgeneration\\b|\\bdoubl\\w*\\b|\\bbinary fission\\b|\\bculture\\b|\\be\\.? coli\\b|\\bpopulation\\b" low) then NONE
    else
      let
        val gt = search ("\\b(?:generation|doubling) time\\s*(?:of|is|=)?\\s*" ^ N ^ TU ^ "|\\b(?:divides?|doubles?)\\s+every\\s+" ^ N ^ TU) low
        val tt = search ("\\b(?:after|in|for|over)\\s+" ^ N ^ TU) low
        val n0 = case search ("\\b(?:starts? with|initial(?:ly)?|beginning with|begins with|starting with|inoculated with)\\s+(?:a\\s+)?" ^ SCI ^ "\\s*(?:cells|bacteria|cfu)?") low of
                   SOME m => SOME m
                 | NONE => search (SCI ^ "\\s*(?:cells|bacteria)\\s*(?:initially|at the start|to start)") low
        val nf = search ("\\b(?:to|reaches|reach|grows? to|final(?: count| population)?(?: of| is)?|ends? with)\\s+" ^ SCI ^ "\\s*(?:cells|bacteria|cfu)?") low
        fun gMin m = minutesOf (valOf (firstGroup low m [1, 3])) (valOf (firstGroup low m [2, 4]))
        fun tMin m = minutesOf (g1 low m) (valOf (grp low m 2))
      in
        case (gt, tt) of
          (SOME g, SOME t) =>
            if isSome n0 andalso has "\\bhow many\\b|\\bpopulation\\b|\\bnumber of (?:cells|bacteria)\\b" low
               andalso not (has "\\bhow many generations\\b" low)
            then SOME (L.M_GrowthN (sciVal low (valOf n0), gMin g, tMin t))
            else if has "\\bhow many generations\\b" low then SOME (L.M_Gens (tMin t, gMin g))
            else microTime low n0 nf tt
        | _ => microTime low n0 nf tt
      end
  and microTime low n0 nf tt : L.mreq option =
    case (n0, nf, tt) of
      (SOME a, SOME b, SOME t) =>
        if has "\\bgeneration time\\b|\\bdoubling time\\b" low
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
          val NUM2 = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?(?:\\s*(?:x|\195\151|\\*)\\s*10\\s*\\^?\\s*[+-]?\\d+|e[+-]?\\d+)?)"
          val UNIT2 = "(?:cells|bacteria|bacterial cells|cfu|organisms)"
          val s1 = subWith ("\\bfrom\\s+" ^ NUM2 ^ "\\s*" ^ UNIT2 ^ "\\s+to\\s+" ^ NUM2 ^ "\\s*" ^ UNIT2 ^ "?|\\bfrom\\s+" ^ NUM2 ^ "\\s+to\\s+" ^ NUM2 ^ "\\s*" ^ UNIT2)
                     (fn t => fn m =>
                        "starting with " ^ valOf (firstGroup t m [1, 3]) ^ " cells, reaches " ^ valOf (firstGroup t m [2, 4]) ^ " cells") t0
          val s2 = subWith ("\\b(?:a |the )?(?:bacterial )?(?:population|culture|sample|colony|inoculum) of\\s+" ^ NUM2 ^ "\\s*" ^ UNIT2)
                     (fn t => fn m => "a culture starting with " ^ g1 t m ^ " cells") s1
          val s3 = subWith "\\btenfold\\b" (fn _ => fn _ => "10-fold") s2
          val s4 = subWith "\\bhundredfold\\b" (fn _ => fn _ => "100-fold") s3
          val t = subWith "\\b(successive|consecutive|sequential|repeated)\\s+(?=1\\s*[:/]|\\d+[- ]fold)" (fn _ => fn _ => "") s4
          val low = lower t
        in
          case microV1 t of
            SOME req =>
              let val r = L.m_reply req
              in if not (L.answered r) andalso not (has "\\d" t) then NONE else SOME r end
          | NONE =>
              if has "\\d" low andalso has ASKS low
                 andalso ((has "\\bdoubl\\w*\\b|\\bgeneration\\w*\\b|\\bbinary fission\\b" low
                           andalso has "\\bbacteri\\w*\\b|\\bcells?\\b|\\bculture\\b|\\be\\.? coli\\b|\\bpopulation\\b" low)
                          orelse (has "\\bcfu\\b|\\bcolon(?:y|ies)\\b" low andalso has "\\bdilution\\b|10\\s*\\^" low)
                          orelse has "\\bserial dilutions?\\b" low)
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
