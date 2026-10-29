(* UNTRUSTED. The English recognizer for the life-science family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/genetics-v2/organ_genetics_v{1,2}.py  (GeneticsOrganV2)
     upstream/root/specialists/biology/organ_biology_v1.py           (BiologyOrgan)
     upstream/root/specialists/ecology/organ_ecology_v1.py           (EcologyOrgan)
     upstream/root/specialists/forestry/organ_forestry_v1.py         (ForestryOrgan)
     upstream/root/specialists/wildlife/organ_wildlife_v1.py         (WildlifeOrgan)
     upstream/root/specialists/microbiology-v2/organ_micro_v{1,2}.py (MicroOrganV2)
   and of their shared narrowing rule narrow_v1.py. It reads numbers, genotypes,
   sequences and words off the question, converts units and binds them to typed
   Life requests. Numeric tokenization and English role/model selection remain
   untrusted. The scientific arithmetic, strand normalization, domain checks
   and response construction are extracted HOL functions. The reader also
   chooses routing and applies the shared narrowing rule.

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
  fun validOrderedPair p1 p2 =
    size p1 = size p2 andalso (size p1 >= 2 andalso size p1 <= 12 andalso size p1 mod 2 = 0) andalso
    List.all (fn (a, b) => 
      let val l = Char.toLower
      in l a = l b end) (lociOf p1) andalso
    length (List.foldl (fn ((a, _), seen) => if List.exists (fn c => c = Char.toLower a) seen then seen else Char.toLower a :: seen) [] (lociOf p1)) = size p1 div 2 andalso
    List.all (fn ((a, b), (c, d)) =>
      let val l = Char.toLower in l a = l c andalso l a = l d end) (ListPair.zip (lociOf p1, lociOf p2))

  (* Bind diploid pairs by locus identity, preserving the first parent's
     reporting order. A repeated, malformed or missing locus has no mapping. *)
  fun alignLoci reference supplied =
    if not (validOrderedPair reference reference andalso validOrderedPair supplied supplied)
       orelse size reference <> size supplied then NONE
    else
      let val pairs = lociOf supplied
          val mapped = map (fn (a, _) => List.find
             (fn (b, _) => Char.toLower a = Char.toLower b) pairs) (lociOf reference)
      in if List.all isSome mapped then SOME (map valOf mapped) else NONE end
  fun validPair p1 p2 = isSome (alignLoci p1 p2)

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
                       in s <> s1 andalso s <> s2 andalso validPair p1 w end
                     val want = case List.filter okCand cands of [c] => SOME (Regex.whole t c) | _ => NONE
                     val lp = lociOf p1
                     val lq = valOf (alignLoci p1 p2)
                     val pairs = ListPair.zip (map (fn (a, b) => locusOf a b) lp, map (fn (a, b) => locusOf a b) lq)
                   in
                     if isSome want andalso has "\\bprobability\\b|\\bchance\\b|\\bproportion\\b|\\bfraction\\b|\\bwhat percent\\w*\\b|\\bhow likely\\b" low then
                       let val w = valOf want
                           val ws = map (fn (a, b) => zygOf a b) (valOf (alignLoci p1 w))
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

  (* Direction is attached to the sequence, not guessed from a later request
     about output direction. No prime marks retains the published 5'->3'
     convention; incomplete/conflicting marks request clarification. *)
  fun bioDirection low seq : bool option =
    let
      val p = "([35])\\s*['\226\128\178\226\128\153]\\s*[-:]?\\s*([acgtu]{3,}(?:[ \\-][acgtu]{3})*)\\s*[-:]?\\s*([35])\\s*['\226\128\178\226\128\153]"
      fun bases g = String.translate (fn c => if Char.isSpace c orelse c = #"-" then "" else String.str c) g
      val ms = List.filter (fn m => bases (valOf (grp low m 2)) = lower seq) (findall p low)
    in case ms of
         [m] => if g1 low m = valOf (grp low m 3) then NONE else SOME (g1 low m = "3")
       | [] => if has "[35]\\s*['\226\128\178\226\128\153]" low then NONE else SOME false
       | _ => NONE
    end

  fun bioUnsupportedCode low =
    has "\\bmitochondri\\w*\\b|\\bciliate\\w*\\b|\\balternative (?:genetic )?code\\b|\\bnonstandard\\b|\\bnon-standard\\b|\\bselenocysteine\\b|\\bpyrrolysine\\b" low
    orelse (has "\\b(?:genetic )?code\\s*(?:table\\s*)?\\d+\\b" low andalso not (has "\\b(?:genetic )?code\\s*(?:table\\s*)?1\\b" low))

  fun bioFrame low =
    let
      val explicit = has "\\b(?:reading )?frame" low
      val rows = List.mapPartial (fn ExactNumeric.Number {start,value,...} =>
          if has "\\b(?:reading )?frame\\s*$" (String.substring(low,0,start)) then SOME value else NONE
          | _=>NONE) (ExactNumeric.scan low)
    in if not explicit then SOME(1:IntInf.int)
       else case rows of [(n,d)]=>if d=1 andalso 1<=n andalso n<=3 then SOME n else NONE | _=>NONE
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
                val template = has "\\btemplate\\b|\\bantisense\\b|\\bnon-?coding strand\\b" low
                val coding = has "\\bcoding strand\\b|\\bsense strand\\b" (subWith "\\bnon-?coding strand\\b" (fn _ => fn _ => "") low)
                val direction = bioDirection low s
                val frame = bioFrame low
                val codeTask = has "\\btranslat\\w*\\b|\\bprotein\\b|\\bamino acid\\b|\\bcodon\\b|\\bcode for\\b" low
                val strandTask = codeTask orelse has "\\btranscri\\w*\\b|\\bmrna\\b" low
                val ys = L.bio_input template (case direction of SOME x => x | NONE => false) xs
              in
                if strandTask andalso (not (isSome direction) orelse (template andalso coding) orelse (codeTask andalso (bioUnsupportedCode low orelse not(isSome frame))))
                then gate text L.bio_model_reply
                else if both then fin (L.Bio (L.Op_complement, xs))
                else if frame = SOME 1 andalso size s = 3 andalso has "\\bcodon\\b|\\bcode for\\b|\\bencode\\w*\\b|\\bamino acid\\b|\\bspecif\\w*\\b" low
                then fin (L.Bio (L.Op_codon, ys))
                else if has "\\bgc content\\b|\\bgc percent\\w*\\b|\\bgc %|\\bpercent(?:age)? (?:of )?g(?:\\s*\\+\\s*|c\\b)" low
                then fin (L.Bio (L.Op_gc, xs))
                else if has "\\breverse[- ]complement\\b" low then fin (L.Bio (L.Op_revcomp, xs))
                else if has "\\bcomplement\\w*\\b" low andalso not (has "\\btranscri\\w*\\b|\\btranslat\\w*\\b" low)
                then fin (L.Bio (L.Op_complement, xs))
                else if has "\\btranscri\\w*\\b|\\bmrna\\b(?!.*\\btranslat)" low
                        andalso not (has "\\btranslat\\w*\\b|\\bprotein\\b|\\bamino acids?\\b" low)
                then
                  (if String.isSubstring "U" s then NONE
                   else fin (L.Bio (L.Op_transcribe false, ys)))
                else if has "\\btranslat\\w*\\b|\\bprotein\\b|\\bamino acid sequence\\b|\\bhow many amino acids\\b|\\bpeptide\\b" low then
                  (if has "\\bhow many amino acids\\b|\\blength of the protein\\b|\\bhow long\\b" low
                   then gate text (L.b_frame_reply (natOf(valOf frame)) true ys)
                   else gate text (L.b_frame_reply (natOf(valOf frame)) false ys))
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
      val n = rat (fields "\\b(?:(?:initial|starting|current) (?:population|size)|population|n0?)\\s*(?:of|is|=)?\\s*$" "^")
      val k = rat (fields "\\b(?:carrying capacity(?:\\s*\\(k\\))?|k)\\s*(?:of|is|=)?\\s*$" "^")
      val rate = one (fields "\\b(?:(?:intrinsic |per capita )?(?:growth )?rate(?:\\s*\\(r\\))?|r)\\s*(?:of|is|=)?\\s*$" "^")
      val r = Option.map (fn ((num,den),suffix) => L.mk_rat num
                (if has "^\\s*%" suffix then den * 100 else den)) rate
      val timeEntry = one (fields "\\b(?:after|in|at(?:\\s+t\\s*=)?)\\s*$" ("^\\s*" ^ ecoUnits ^ "\\b"))
      val time = Option.map (fn ((num,den),_) => L.mk_rat num den) timeEntry
      fun namedUnit suffix =
        let val suffix = subWith "^\\s*%\\s*" (fn _ => fn _ => "") suffix
        in case search ("^\\s*(?:per\\s+|/\\s*)?" ^ ecoUnits ^ "\\b") suffix of
          SOME m => SOME (String.sub (g1 suffix m, 0)) | NONE => NONE end
      val mixedUnits = case (rate,timeEntry) of
        (SOME (_,rs),SOME (_,ts)) =>
          (case (namedUnit rs,namedUnit ts) of (SOME a,SOME b) => a <> b | _ => false)
      | _ => false
      val asks = findall "\\b(?:what|how|calculate|find|estimate|predict|determine)\\b" low
      val target = case rev asks of
          (m : Regex.match) :: _ => String.extract (low, #start m, NONE)
        | [] => lower (Narrow.last_sentence low)
      val wantRate = has "\\bdn\\s*/\\s*dt\\b|\\bhow fast\\b|\\bgrowth rate\\b|\\brate of (?:growth|change)\\b" target
      val wantDouble = has "\\bdoubling time\\b|\\bhow long to double\\b" target
      val wantPopulation = has "\\bpopulation\\b|\\bhow many\\b|\\bsize\\b|\\b(?:calculate|find|estimate|predict|determine)\\s+n\\b" target
      val logistic = has "\\blogistic\\b|\\bcarrying capacity\\b" low
      val exponential = has "\\bexponential\\w*\\b|\\bgrow\\w*\\b" low
      val lambda = rat (fields "(?:\\blambda(?:\\s*\\(\206\187\\))?|\206\187|\\bfinite rate of increase)\\s*(?:of|is|=)?\\s*$" "^")
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
          case search "^[- ]*(inches|inch|in\\b|\"|feet|foot|ft\\b|cm\\b|centimeters?|centimetres?|mm\\b|millimeters?|millimetres?|m\\b|meters?|metres?)\\b" post of
            SOME m => SOME(g1 post m) | NONE=>NONE
        fun metres v u = if String.isPrefix "in" u orelse u="\"" then scale v (127,5000)
          else if String.isPrefix "f" u then scale v (381,1250)
          else if String.isPrefix "c" u then scale v (1,100)
          else if String.isPrefix "mm" u orelse String.isPrefix "milli" u then scale v(1,1000)
          else v
        fun inUnit v u metric = scale (metres v u) (if metric then (100,1) else (5000,127))
        val lengths=List.mapPartial(fn(start,stop,v,pre,post)=>Option.map(fn u=>(start,stop,v,u,pre,post))(lengthUnit post)) numbers
        fun eyeRole(pre,_) = has "\\beye (?:height|level)\\s*(?:of|is|=)?\\s*$" pre
        fun diamRole(pre,post) = has "\\b(?:dbh|diameter(?: at breast height)?)\\s*(?:of|is|=)?\\s*$" pre orelse
          has "^[- ]*(?:inches|inch|in\\b|\"|cm|centimeters?|centimetres?|mm|millimeters?|millimetres?)\\s*(?:dbh|diameter|small[- ]end)\\b" post
        fun countRole(_,_,_,_,post) = has "^\\s*trees\\s*(?:per|an|/)\\s*acre\\b" post
        val counts=List.filter countRole numbers
        val diameters=List.filter(fn(_,_,_,_,pre,post)=>diamRole(pre,post)) lengths
        fun tuple(_,_,v,u,_,_)=rat(inUnit v u false)
        val forest = has "\\btrees?\\b|\\blogs?\\b|\\bdbh\\b|\\bbasal area\\b|\\bstand\\b|\\btimber\\b|\\bforest\\w*\\b|\\bclinometer\\b|\\bdoyle\\b|\\bsmalian\\b|\\bseedlings?\\b|\\bplanting\\b" low
      in
        if not forest then NONE
        else if bad then unread()
        else if has "\\bdoyle\\b|\\bsmalian\\b|\\blog volume\\b|\\bcubic (?:feet|foot) (?:in|of) (?:the |a |this )?log\\b" low then
          let
            val ds=List.filter(fn(_,_,_,u,_,_)=>String.isPrefix "in" u orelse u="\"" orelse String.isPrefix "c" u) lengths
            val ls=List.filter(fn(_,_,_,u,pre,post)=>not(eyeRole(pre,post)) andalso (String.isPrefix "f" u orelse u="m" orelse String.isPrefix "meter" u orelse String.isPrefix "metre" u)) lengths
            fun feet(_,_,v,u,_,_)=rat(scale(metres v u)(1250,381))
          in
            if has "\\bdoyle\\b" low then
              (case(ds,ls)of([d],[l])=>fin(L.F_Doyle(tuple d,feet l))|_=>unread())
            else(case(ds,ls)of([d1,d2],[l])=>fin(L.F_Smalian(tuple d1,tuple d2,feet l))|_=>unread())
          end
        else if has "\\bheight\\b|\\bhow tall\\b" low andalso has "\\bangle\\b|\\bdegrees?\\b|\194\176|\\bclinometer\\b" low then
          let
            val angles=List.filter(fn(_,_,_,_,post)=>has "^\\s*(?:degrees?\\b|\194\176)" post) numbers
            val eyes=List.filter(fn(_,_,_,_,pre,post)=>eyeRole(pre,post)) lengths
            val ds=List.filter(fn(_,_,_,_,pre,post)=>not(eyeRole(pre,post))) lengths
            val outFeet=has "\\b(?:height|tall)[^?;]*\\bin\\s*(?:feet|ft)\\b" low
            val outMetres=has "\\b(?:height|tall)[^?;]*\\bin\\s*(?:m|meters?|metres?)\\b" low
            fun convert v u ft=rat(scale(metres v u)(if ft then(1250,381)else(1,1)))
          in
            if has "\\bslope\\b|\\bsloping\\b|\\binclined\\b|\\bbase angle\\b" low orelse (outFeet andalso outMetres) then unread()
            else case(ds,angles,eyes)of
              ([(_,_,dv,du,_,_)],[(_,_,a,_,_)],[])=>let val ft=outFeet orelse(not outMetres andalso String.isPrefix "f" du)
                in fin(L.F_Height(convert dv du ft,rat a,NONE,ft))end
            | ([(_,_,dv,du,_,_)],[(_,_,a,_,_)],[(_,_,ev,eu,_,_)])=>let val ft=outFeet orelse(not outMetres andalso String.isPrefix "f" du)
                in fin(L.F_Height(convert dv du ft,rat a,SOME(convert ev eu ft),ft))end
            | _=>unread()
          end
        else if has "\\bbasal area\\b" low then
          let
            val metric=has "\\b(?:m2|m\194\178|square met(?:er|re)s?)\\b" low orelse
              (not(has "\\b(?:sq(?:uare)?\\s*ft|square feet)\\b" low) andalso List.exists(fn(_,_,_,u,_,_)=>String.isPrefix "c" u orelse String.isPrefix "m" u)diameters)
            val explicitMean=has "\\barithmetic mean\\b|\\bmean arithmetic\\b" low
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
              ([d],[])=>if has "\\bper acre\\b|\\bstand\\b" low then unread()
                         else if metric then fin(L.F_BAm(dval d))else fin(L.F_BA(dval d))
            | ([d],[n])=>fin(L.F_BAStand(metric,[(dval d,nval n)]))
            | _=>(case pair(diameters,counts)of SOME(xs as _::_)=>fin(L.F_BAStand(metric,xs))|_=>unread())
          end
        else if has "\\bspac\\w*\\b|\\bplant\\w*\\b|\\bgrid\\b" low andalso
                has "\\bper acre\\b|\\ban acre\\b|\\bhow many (?:trees|seedlings)\\b" low then
          (case numbers of
            [(_,s1,v1,_,_), (s2,_,v2,_,post2)]=>
              if has "^\\s*(?:ft|feet|foot|')?\\s*(?:x|\195\151|by)\\s*$"(String.substring(low,s1,s2-s1)) andalso
                 has "^\\s*(?:ft|feet|foot|')\\b" post2
              then fin(L.F_Tpa(rat v1,rat v2))else unread()
          | _=>unread())
        else NONE
      end

  (* ---------- wildlife ---------- *)
  val MARK = "(?:marked|tagged|banded|marking|tagging|banding)"
  val CAP = "(?:caught|captured|trapped|netted|sampled|collected|seined)"

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
          val ofthe = anchored "\\s+of\\s+the\\s+(\\d+(?:,\\d{3})*)" aft
        in
          if isSome ofthe andalso not (isSome (!outR)) then
            (setdef outR v; setdef outC (bigOf (g1 aft (valOf ofthe))))
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
      val _ = List.app step (ExactNumeric.scan low)
    in (!outM, !outC, !outR, !conflict, !invalid) end

  val animals = "(?:animals|fish|deer|birds|turtles|frogs|mice|rabbits|butterflies|beetles|trout|salamanders|individuals|lizards|bats|squirrels)"

  (* Exact numeric roles are complete tokens. Area input and output units
     are separate fields; densities do not silently retain the input unit. *)
  fun wNumbers low = List.mapPartial
    (fn ExactNumeric.Number {start,stop,value,...} => SOME(value,String.substring(low,0,start),String.extract(low,stop,NONE)) | _ => NONE)
    (ExactNumeric.scan low)
  fun wMalformed low = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) (ExactNumeric.scan low)
  fun wOne xs = case xs of [v] => SOME v | _ => NONE
  val wAreaPat = "(hectares?|ha|acres?|km2|km\194\178|square kilomet(?:er|re)s?|sq\\.?\\s*km|square miles?|sq\\.?\\s*mi|mi2)"
  fun wUnit t = if has "^(?:hectare|ha)" t then L.Hectare
                else if has "^acre" t then L.Acre
                else if has "(?:mile|mi)" t then L.SquareMile else L.SquareKm
  fun wArea suffix = case search ("^\\s*" ^ wAreaPat ^ "\\b") suffix of
      SOME m => SOME(wUnit(g1 suffix m)) | NONE => NONE

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
              val (m, c, r, conflict, invalid) = roles low
              val onat = Option.map natOf
            in fin (L.w_reply (if invalid then L.W_BadCount
                 else if conflict orelse has "\\b(?:third|fourth|multiple) (?:sample|capture|occasion|survey)\\b" low then L.W_Unread
                 else L.W_Lincoln (onat m, onat c, onat r, has "\\bchapman\\b" low))) end
          else if has "\\bdensity\\b|\\bper (?:hectare|acre|km|square)\\b" low then
            let
              val nums = wNumbers low
              val count = wOne(List.filter (fn (_,_,aft) => has ("^\\s+" ^ animals ^ "\\b") aft) nums)
              val area = wOne(List.mapPartial (fn ((n,d),bef,aft) =>
                if has "\\b(?:in|on|across|over)\\s+(?:an?\\s+)?$" bef
                then Option.map(fn u=>((n,d),u))(wArea aft) else NONE) nums)
              val targets = findall ("\\bper\\s+" ^ wAreaPat ^ "\\b") low
              val target = case targets of [] => NONE | [m] => SOME(wUnit(g1 low m)) | _ => NONE
            in
              if wMalformed low orelse length targets > 1 orelse (has "\\bper\\b" low andalso null targets) then fin(L.w_reply L.W_Unread)
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
    if not(has "\\bsurvival\\b|\\bmortality\\b|\\bdeath rate\\b" low) then NONE
    else let
      val nums = wNumbers low
      fun starting (_,bef,aft) = has "\\b(?:of|out of|from)\\s*$" bef orelse
         (not(has "^\\s+of\\b" aft) andalso has "^\\s+(?:\\w+\\s+){0,2}?(?:were )?(?:released|tagged|collared|monitored|hatched|born)\\b" aft)
      val starts = List.filter starting nums
      fun survivor (row as (_,bef,aft)) = not(starting row) andalso
        (has "^\\s+(?:of\\s+[+\226\136\146\\-\\d.,/e]+\\s+)?(?:\\w+\\s+){0,3}?(?:survived|were still alive|remained alive|lived)\\b" aft orelse
         has "\\b(?:survivors|surviving)\\s*(?:=|:|was|were)?\\s*$" bef)
      val survivors = List.filter survivor nums
      val invalid = List.exists (fn ((n,d),_,_)=>n<0 orelse d<>1) (starts@survivors)
      val mort = has "\\bmortality\\b|\\bdeath rate\\b" low
      val asks = findall "\\b(?:what|calculate|find|determine)\\b" low
      val target = case rev asks of (m:Regex.match)::_ => String.extract(low,#start m,NONE) | [] => low
      val cumulative = has "\\boverall\\b|\\bcumulative\\b|\\b(?:over|across|for) (?:both|the two|two|2) (?:years|periods)\\b" target
      val conditional = has "\\b(?:during|in|for) (?:the )?second (?:year|period)\\b" target
      val annual = has "\\bannual(?:ized)?\\b|\\bper year\\b" target
      val multiYear = List.exists(fn((n,d),bef,aft)=>has "\\b(?:over|after|for|across)\\s*$" bef andalso has "^\\s*years?\\b" aft andalso n<>d) nums
      fun periodUnit text = if has "\\byears?\\b|\\bannual(?:ized)?\\b|\\byearly\\b" text then SOME "year"
        else if has "\\bmonths?\\b|\\bmonthly\\b" text then SOME "month"
        else if has "\\bweeks?\\b|\\bweekly\\b" text then SOME "week"
        else if has "\\bdays?\\b|\\bdaily\\b" text then SOME "day" else NONE
      val outputPeriod = case search "\\b(?:annual(?:ized)?|yearly|monthly|weekly|daily|per (?:year|month|week|day))\\b" target of
        SOME m=>periodUnit(Regex.whole target m) | NONE=>NONE
      val durations = List.mapPartial(fn((n,d),bef,aft)=>
        if has "\\b(?:over|after|for|across)\\s*$" bef then
          (case search "^\\s*(years?|months?|weeks?|days?)\\b" aft of
             SOME m=>SOME(n,d,periodUnit(g1 aft m))|NONE=>NONE) else NONE) nums
      val incompatiblePeriod = case outputPeriod of NONE=>false | SOME u=>
        (case durations of [] => has "\\b(?:two|three|four|five|several|multiple) (?:years|months|weeks|days)\\b" low
                          orelse (u<>"year" andalso has "\\b(?:first|second) year\\b" low)
         | [(n,d,SOME v)]=>n<>d orelse u<>v | _=>true)
      fun period aft = case search "\\b(?:survived|were still alive|remained alive|lived)\\s+(?:the )?(first|second) (?:year|period)\\b" aft of SOME m=>SOME(g1 aft m)|NONE=>NONE
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

  (* ---------- microbiology v2 ---------- *)
  val ASKS = "\\?|\\b(?:find|calculate|compute|determine|estimate|what|how many|how long|give)\\b"

  (* Dilution powers and colon ratios are domain notation. Normalize only
     complete powers, then let shared exact tokenization preserve all signs,
     fractions and malformed runs. Never search a valid-looking numeric tail. *)
  fun microNotation low =
    let
      fun inverseExponent e = if String.isPrefix "-" e then String.extract (e,1,NONE)
        else "-" ^ (if String.isPrefix "+" e then String.extract(e,1,NONE) else e)
      val reciprocal = subWith "(?<![\\w.,+\\-/^\226\136\146])([+\\-]?1)\\s*[:/]\\s*10\\s*\\^\\s*(?:\\(\\s*([+-]?\\d+)\\s*\\)|([+-]?\\d+))(?![\\d.\\^\\)])"
        (fn t => fn m => g1 t m ^ "e" ^ inverseExponent (valOf (firstGroup t m [2,3]))) low
      val paren = subWith "(?<![\\w.,+\\-/^\226\136\146])10\\s*\\^\\s*\\(\\s*([+-]?\\d+)\\s*\\)(?![\\d.\\^])"
                    (fn t => fn m => "1e" ^ g1 t m) reciprocal
      val power = subWith "(?<![\\w.,+\\-/^\226\136\146])10\\s*\\^\\s*([+-]?\\d+)(?![\\d.\\^\\)])"
                    (fn t => fn m => "1e" ^ g1 t m) paren
      val ratio = subWith "(?<=\\d)\\s*:\\s*(?=[+\\-\226\136\146.\\d])" (fn _ => fn _ => "/") power
    in ratio end

  fun microDil low tokens : L.rat option =
    let
      fun binding (ExactNumeric.Number {start, stop, value, ...}) =
            let val prefix = String.substring (low, 0, start)
                val after = String.extract (low, stop, NONE)
            in if has "^\\s*dilution\\b" after orelse
                  has "\\bdilution\\s*(?:factor\\s*)?(?:of|is|=|:)?\\s*$" prefix
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
      if has "\\bcfu\\b|\\bcolon(?:y|ies)\\b|\\bplate count\\b" low andalso has "\\bdilution\\b|10\\s*\\^|\\b1\\s*[:/]\\s*\\d" low then
        let
          val tokens = ExactNumeric.scan low
          val malformed = has "\\^" low orelse List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
          fun role pat = List.mapPartial
            (fn ExactNumeric.Number {stop, value, ...} =>
                  let val rest = String.extract (low, stop, NONE)
                  in if has pat rest then SOME (value, rest) else NONE end
              | _ => NONE) tokens
          val colonies = role "^\\s*colon(?:y|ies)\\b"
          val volumes = role "^\\s*(?:ml|\194\181l|ul|microlit\\w+|millilit\\w+)\\b"
          val dil = microDil low tokens
        in
          if malformed then SOME L.M_Unread
          else case (colonies, dil, volumes) of
            ([((cn, cd), _)], SOME d, [((vn, vd), unit)]) =>
              let
                val micro = has "^\\s*(?:\194\181l|ul|microlit\\w+)\\b" unit
                val vol = L.mk_rat vn (if micro then vd * 1000 else vd)
              in SOME (L.M_CFU (L.mk_rat cn cd, d, vol)) end
          | _ => SOME L.M_Unread
        end
      else if has "\\bserial dilutions?\\b|\\bfold\\s+dilutions?\\b|\\b1\\s*/\\s*\\d+\\s+(?:serial\\s+)?dilutions?\\b" low
      then microSerial low
      else microGrowth low
    end
  and microSerial low : L.mreq option =
    let
      val text = subWith "\\b(two|three|four|five|six)\\s+(?=(?:serial\\s+)?(?:1\\s*/|\\d+[- ]fold))"
        (fn t => fn m => (case g1 t m of "two" => "2 " | "three" => "3 " | "four" => "4 " | "five" => "5 " | _ => "6 ")) low
      val tokens = ExactNumeric.scan text
      val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
      fun factors (ExactNumeric.Number {start,stop,value=(n,d),...}) =
            let val after = String.extract(text,stop,NONE)
            in if has "^[- ]fold\\s+(?:serial\\s+)?dilutions?\\b" after
               then SOME(start,n,d)
               else if has "^\\s+(?:serial\\s+)?dilutions?\\b" after andalso n=1
               then SOME(start,d,1) else NONE end
        | factors _ = NONE
      fun steps factorStart (ExactNumeric.Number {stop,value,...}) =
            if stop <= factorStart andalso has "^\\s+(?:serial\\s+)?$" (String.substring(text,stop,factorStart-stop))
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
    if not (has "\\bbacteri\\w*\\b|\\bcells?\\b|\\bgeneration\\b|\\bdoubl\\w*\\b|\\bbinary fission\\b|\\bculture\\b|\\be\\.? coli\\b|\\bpopulation\\b" low) then NONE
    else
      let
        val tokens = ExactNumeric.scan low
        val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
        fun parts (ExactNumeric.Number {start,stop,value,...}) = SOME(String.substring(low,0,start),String.extract(low,stop,NONE),value)
          | parts _ = NONE
        val quantities = List.mapPartial parts tokens
        fun count pred = List.mapPartial (fn (pre,post,value) =>
          if pred(pre,post) andalso has "^\\s*(?:(?:cells?|bacteria|cfu|organisms)\\b|,|and\\b|to\\b|[?.;]|$)" post
          then SOME value else NONE) quantities
        val initial = count(fn(pre,post) =>
          has "\\b(?:starts? with|initial(?:ly)?(?: count| population)?(?: of| is| =)?|beginning with|begins with|starting with|inoculated with|from|(?:population|culture|sample|colony|inoculum) of)\\s+(?:a\\s+)?$" pre
          orelse has "^\\s*(?:cells|bacteria)\\s*(?:initially|at the start|to start)\\b" post)
        val final = count(fn(pre,_) => has "\\b(?:to|reaches|reach|grows? to|final(?: count| population)?(?: of| is| =)?|ends? with)\\s+$" pre)
        fun scale (n,d) unit =
          if String.isPrefix "s" unit then (n,d*60)
          else if String.isPrefix "h" unit then (n*60,d)
          else if String.isPrefix "d" unit then (n*1440,d) else (n,d)
        fun time role = List.mapPartial (fn(pre,post,value) =>
          if has role pre then
            (case search "^\\s*(seconds?|sec|s|minutes?|mins?|hours?|hrs?|h|days?)\\b" post of
              SOME m => SOME(scale value (g1 post m)) | NONE => NONE)
          else NONE) quantities
        val generation = time "\\b(?:(?:generation|doubling) time\\s*(?:(?:of|is|=)\\s*)?|(?:divides?|doubles?)\\s+every\\s*)$"
        val elapsed = time "\\b(?:after|in|for|over)\\s+$"
        fun rat(n,d)=L.mk_rat n d
        val askGens = has "\\bhow many generations\\b|\\bnumber of generations\\b" low
        val askTime = has "(?:what|find|calculate|compute|determine|give)[^?;]*\\b(?:generation|doubling) time\\b" low
        val targetText = case search "\\b(?:what|find|calculate|compute|determine|give)\\b" low of
            SOME m => String.extract(low,#start m,NONE) | NONE => low
        val outputUnits = List.mapPartial (fn(pat,u) => if has pat targetText then SOME u else NONE)
          [("\\bin\\s+(?:seconds?|sec|s)\\b",L.M_Seconds),
           ("\\bin\\s+(?:minutes?|mins?)\\b",L.M_Minutes),
           ("\\bin\\s+(?:hours?|hrs?|h)\\b",L.M_Hours),
           ("\\bin\\s+days?\\b",L.M_Days)]
        val badUnit = askTime andalso (length outputUnits>1 orelse has "\\bin\\s+(?:weeks?|months?|years?)\\b" targetText)
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
          val s2 = subWith "(?<![\\w.,+\\-/^\226\136\146])([+\\-]?(?:\\d+(?:\\.\\d*)?|\\.\\d+))\\s*(?:x|\195\151|\\*)\\s*10\\s*\\^?\\s*([+-]?\\d+)(?![\\d.\\^])"
            (fn t => fn m => g1 t m ^ "e" ^ valOf(grp t m 2)) t0
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
