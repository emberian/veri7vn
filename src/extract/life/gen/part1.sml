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
    val RELATION = ⟦\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\s+(?:\w+\s+){0,2}(?:more|less|fewer|longer|shorter)\s+than\b|\b(?:twice|three times|half)\s+(?:as\s+\w+\s+as\s+)?the\s+\w+\b⟧
    val RATE = ⟦\b\d+(?:\.\d+)?\s+[a-z]+\s+(?:for|per|every)\s+(?:\d+(?:\.\d+)?|a|an|one|each)\s+[a-z]+⟧
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  (* the organs' wrapper: a decline is kept only on a short direct question *)
  fun gate text (r : L.reply) = if L.answered r orelse Narrow.short_direct text then SOME r else NONE

  val N = ⟦(\d+(?:,\d{3})*(?:\.\d+)?)⟧

  (* ---------- genetics ---------- *)
  val GT = ⟦\b((?:[A-Za-z][A-Za-z]){1,6})\b⟧
  val crossRe = GT ^ ⟦\s*(?:x|×|and|(?:is\s+)?crossed with|with)\s*⟧ ^ GT

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
      val q2 = search ⟦\b1 in ([\d,]+)\b⟧ low
      val fq =
        case search ⟦\bq\s*(?:=|is)\s*(-?\d*(?:\.\d+)|-?\d+)⟧ low of
          SOME m => SOME (g1 low m)
        | NONE => (case search ⟦\brecessive allele (?:frequency )?(?:is|of|=)\s*(-?\d*(?:\.\d+)|-?\d+)⟧ low of
                     SOME m => SOME (g1 low m) | NONE => NONE)
      val fp =
        case search ⟦\bp\s*(?:=|is)\s*(-?\d*(?:\.\d+)|-?\d+)⟧ low of
          SOME m => SOME (g1 low m)
        | NONE => (case search ⟦\bdominant allele (?:frequency )?(?:is|of|=)\s*(-?\d*(?:\.\d+)|-?\d+)⟧ low of
                     SOME m => SOME (g1 low m) | NONE => NONE)
      val fq2 =
        case search ⟦(\d+(?:\.\d+)?)\s*%\s*(?:of (?:(?:the|a|an) )?(?:(?:[a-z]+\s+){0,2}population|people|individuals) )?(?:(?:show|have|has|express)\w*\s+)?(?:the\s+)?recessive⟧ low of
          SOME m => SOME (g1 low m, true)
        | NONE =>
          (case search ⟦\brecessive (?:phenotype|trait|condition|disorder)\w*[^.?]{0,40}?(?:in|affects|of)\s+(\d+(?:\.\d+)?)\s*%⟧ low of
             SOME m => SOME (g1 low m, true)
           | NONE =>
             (case search ⟦\bq\s*(?:\^2|²|squared)\s*(?:=|is)\s*(-?\d*(?:\.\d+)|-?\d+)⟧ low of
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
      if has ⟦\bhardy[- ]weinberg\b|\ballele frequenc\w*\b|\bcarriers?\b|\bheterozygote frequency\b|\brecessive (?:phenotype|trait|condition|disorder)\b⟧ low
         andalso has ⟦\bfrequenc\w*\b|\bproportion\b|\bpercent\w*\b|\bwhat fraction\b|\bhow many\b|\bcarriers?\b|\b1 in \d⟧ low
      then
        (case hwSource low of
           NONE => NONE
         | SOME src =>
             if has ⟦\bcarriers?\b|\bheterozyg\w*\b|\b2pq\b⟧ low then SOME (L.G_HW (L.HK_carrier, src))
             else if has ⟦\bhomozygous dominant\b|\bp\s*(?:\^2|²|squared)\b⟧ low then SOME (L.G_HW (L.HK_p2, src))
             else if has ⟦\bdominant allele\b|\bfrequency of p\b|\bwhat is p\b⟧ low then SOME (L.G_HW (L.HK_p, src))
             else if has ⟦\brecessive allele\b|\bfrequency of q\b|\bwhat is q\b⟧ low then SOME (L.G_HW (L.HK_q, src))
             else NONE)
      else
        (case search crossRe (lower t) of
           NONE => NONE
         | SOME m =>
             if not (has ⟦\bcross\w*\b|\boffspring\b|\bprogeny\b|\bpunnett\b|\bchild\w*\b|\bprobability\b|\bchance\b|\bratio\b|\bproportion\b⟧ low)
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
                     if isSome want andalso has ⟦\bprobability\b|\bchance\b|\bproportion\b|\bfraction\b|\bwhat percent\w*\b|\bhow likely\b⟧ low then
                       let val w = valOf want
                           val ws = map (fn (a, b) => zygOf a b) (valOf (alignLoci p1 w))
                       in SOME (L.G_Geno (map (fn ((a, b), z) => (a, (b, z))) (ListPair.zip (pairs, ws)))) end
                     else if n = 2 andalso has ⟦\brecessive (?:phenotype|trait)\b|\bshow the recessive\b|\bexpress the recessive\b⟧ low then
                       SOME (L.G_Pheno (false, #1 (hd pairs), #2 (hd pairs)))
                     else if n = 2 andalso has ⟦\bdominant (?:phenotype|trait)\b|\bshow the dominant\b|\bexpress the dominant\b⟧ low then
                       SOME (L.G_Pheno (true, #1 (hd pairs), #2 (hd pairs)))
                     else if has ⟦\bphenotyp\w* ratio\b|\bphenotypic ratio\b⟧ low then SOME (L.G_PRatio pairs)
                     else if n = 2 andalso has ⟦\bgenotyp\w* ratio\b|\bgenotypic ratio\b⟧ low then
                       SOME (L.G_GRatio (#1 (hd pairs), #2 (hd pairs)))
                     else NONE
                   end
               end)
    end

  fun genetics text : L.reply option =
    if Narrow.narrative text then NONE
    else if isSome (search crossRe (lower text)) andalso has ⟦\blinked\b|\blinkage\b|\bsex[- ]linked\b|\bincomplete dominance\b|\bcodominan\w*\b|\bepistasis\b⟧ (lower text) then SOME (L.g_reply L.G_Model)
    else
      let
        val t0 = collapse text
        val t1 = subWith ⟦\bof an? (population|group|sample)\b⟧ (fn t => fn m => "of the " ^ g1 t m) t0
        val t2 = subWith ⟦\b(shows?|has|have|express(?:es)?)\s+an?\s+recessive\b⟧ (fn t => fn m => g1 t m ^ " the recessive") t1
        val t3 = subWith ⟦\b(what is|find|calculate|give)\s+q\b(?![\w,])⟧ (fn t => fn m => g1 t m ^ " q, the recessive allele frequency") t2
        val t = subWith ⟦\b(what is|find|calculate|give)\s+p\b(?![\w,])⟧ (fn t => fn m => g1 t m ^ " p, the dominant allele frequency") t3
        val viaCross =
          case search crossRe (lower t) of
            NONE => NONE
          | SOME _ =>
              let
                val tc1 = subWith ⟦\bwhat fraction\b|\bwhat proportion\b|\bproportion\b|\bwhat percent(?:age)?\b⟧ (fn _ => fn _ => "what probability") t
                val tc = subWith ⟦\bhardy[- ]weinberg\b|\ballele frequenc\w*\b⟧ (fn _ => fn _ => "") tc1
              in gV1 tc end
        val req =
          case viaCross of
            SOME r => SOME r
          | NONE =>
              (case gV1 t of
                 SOME r => SOME r
               | NONE =>
                   if has ⟦\bhardy[- ]weinberg\b|\ballele frequenc\w*\b|\bcarrier frequency\b⟧ (lower t) then SOME L.G_Need
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
      val upperPat = ⟦\b([acgtu]{3,}(?:[ \-][acgtu]{3})*)\b⟧
      val lowerPat = ⟦\b([acgtu]{6,})\b⟧
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
      val p = ⟦([35])\s*['′]\s*[-:]?\s*([acgtu]{3,}(?:[ \-][acgtu]{3})*)\s*[-:]?\s*([35])\s*['′]⟧
      fun bases g = String.translate (fn c => if Char.isSpace c orelse c = #"-" then "" else String.str c) g
      val ms = List.filter (fn m => bases (valOf (grp low m 2)) = lower seq) (findall p low)
    in case ms of
         [m] => if g1 low m = valOf (grp low m 3) then NONE else SOME (g1 low m = "3")
       | [] => if has ⟦[35]\s*['′]⟧ low then NONE else SOME false
       | _ => NONE
    end

  fun bioUnsupportedCode low =
    has ⟦\bmitochondri\w*\b|\bciliate\w*\b|\balternative (?:genetic )?code\b|\bnonstandard\b|\bnon-standard\b|\bselenocysteine\b|\bpyrrolysine\b|\b(?:reading )?frame\s*(?:[023456]|-[123])\b⟧ low
    orelse (has ⟦\b(?:genetic )?code\s*(?:table\s*)?\d+\b⟧ low andalso not (has ⟦\b(?:genetic )?code\s*(?:table\s*)?1\b⟧ low))

  fun biology text : L.reply option =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin r = gate text (L.b_reply r)
      in
        if not (has ⟦\bdna\b|\brna\b|\bmrna\b|\bsequence\b|\bstrand\b|\bcodon\b|\btranslat\w*\b|\btranscri\w*\b|\bcomplement\w*\b|\bgc content\b|\bprotein\b|\bamino acid\b⟧ low)
        then NONE
        else
          case bioSeq t of
            NONE => NONE
          | SOME s =>
              let
                val xs = map nucOf (String.explode s)
                val both = String.isSubstring "U" s andalso String.isSubstring "T" s
                val template = has ⟦\btemplate\b|\bantisense\b|\bnon-?coding strand\b⟧ low
                val coding = has ⟦\bcoding strand\b|\bsense strand\b⟧ (subWith ⟦\bnon-?coding strand\b⟧ (fn _ => fn _ => "") low)
                val direction = bioDirection low s
                val codeTask = has ⟦\btranslat\w*\b|\bprotein\b|\bamino acid\b|\bcodon\b|\bcode for\b⟧ low
                val strandTask = codeTask orelse has ⟦\btranscri\w*\b|\bmrna\b⟧ low
                val ys = L.bio_input template (case direction of SOME x => x | NONE => false) xs
              in
                if strandTask andalso (not (isSome direction) orelse (template andalso coding) orelse (codeTask andalso bioUnsupportedCode low))
                then gate text L.bio_model_reply
                else if both then fin (L.Bio (L.Op_complement, xs))
                else if size s = 3 andalso has ⟦\bcodon\b|\bcode for\b|\bencode\w*\b|\bamino acid\b|\bspecif\w*\b⟧ low
                then fin (L.Bio (L.Op_codon, ys))
                else if has ⟦\bgc content\b|\bgc percent\w*\b|\bgc %|\bpercent(?:age)? (?:of )?g(?:\s*\+\s*|c\b)⟧ low
                then fin (L.Bio (L.Op_gc, xs))
                else if has ⟦\breverse[- ]complement\b⟧ low then fin (L.Bio (L.Op_revcomp, xs))
                else if has ⟦\bcomplement\w*\b⟧ low andalso not (has ⟦\btranscri\w*\b|\btranslat\w*\b⟧ low)
                then fin (L.Bio (L.Op_complement, xs))
                else if has ⟦\btranscri\w*\b|\bmrna\b(?!.*\btranslat)⟧ low
                        andalso not (has ⟦\btranslat\w*\b|\bprotein\b|\bamino acids?\b⟧ low)
                then
                  (if String.isSubstring "U" s then NONE
                   else fin (L.Bio (L.Op_transcribe false, ys)))
                else if has ⟦\btranslat\w*\b|\bprotein\b|\bamino acid sequence\b|\bpeptide\b⟧ low then
                  (if has ⟦\bhow many amino acids\b|\blength of the protein\b|\bhow long\b⟧ low
                   then fin (L.Bio (L.Op_protlen, ys))
                   else fin (L.Bio (L.Op_translate, ys)))
                else NONE
              end
      end
