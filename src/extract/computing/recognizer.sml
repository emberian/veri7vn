(* UNTRUSTED. The English recognizer for the computing family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/networking/organ_networking_v1.py
     upstream/root/specialists/embedded/organ_embedded_v1.py
     upstream/root/specialists/cyber/organ_cyber_v1.py
     upstream/root/specialists/linux-v2/organ_linux_v{1,2}.py
     upstream/root/specialists/git/organ_git_v1.py
     upstream/root/specialists/sql/organ_sql_v1.py (statement extraction; a lexer)
     upstream/root/specialists/python{,-r2}/organ_pyref_v1.py (name candidates)
     upstream/root/specialists/robotics-v2/organ_robotics_v{1,2}.py
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words off
   the question and builds a typed Computing request; it computes nothing. Every
   value, decline and response text comes from the verified HOL kernel. NONE means
   the question is not taken (the organ returns None).

   Patterns are lower-case literals and applied to the lower-cased question
   (the organs compile with re.I), except where an organ matches the original text
   case-sensitively (SIG names, chmod -R, python names); those call the *CS
   functions. Escapes such as \S and \B are passed through as written (root fix
   d85f26c). *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Computing.reply) option
end =
struct
  structure C = Computing

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
  fun gOpt s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE
  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)
  fun nat (i : IntInf.int) = C.nat_of_integer i
  fun natS s = nat (valOf (IntInf.fromString (String.translate (fn #"," => "" | c => String.str c) s)))
  fun intOf s = valOf (IntInf.fromString (String.translate (fn #"," => "" | c => String.str c) s))
  fun startOf (m : Regex.match) = #start m
  fun stopOf (m : Regex.match) = #stop m

  (* Case-sensitive organ patterns: Regex.compile folds literals to lower case, so a
     case-sensitive pattern is searched in the lower-cased text (byte positions are
     unchanged) and each match is then checked against the original characters by ok. *)
  fun findallCS p (t : string) (ok : Regex.match -> bool) = List.filter ok (findall p (lower t))
  fun searchCS p t ok = case findallCS p t ok of m :: _ => SOME m | [] => NONE
  fun span (t : string) (m : Regex.match) = String.substring (t, #start m, #stop m - #start m)
  fun isLowerSpan s = lower s = s

  (* decimal numeral "1,000.50" or "-12.5" as an exact (numerator, denominator) *)
  fun decParts (lit0 : string) : IntInf.int * IntInf.int =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "") | [a, b] => (a, b) | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
    in (if neg then IntInf.~ num else num, IntInf.pow (10, size fp)) end
  fun ratP (n : IntInf.int, d : IntInf.int) = C.mk_rat n d
  fun ratOf lit = ratP (decParts lit)
  fun mulP (n, d) (k : IntInf.int) = (n * k, d)
  fun cmpP ((n1, d1), (n2, d2)) = IntInf.compare (n1 * d2, n2 * d1)

  fun replaceSpans (s : string) (spans : (int * int * string) list) =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((a, b, r) :: rest) acc = go b rest (r :: String.substring (s, i, a - i) :: acc)
    in go 0 spans [] end

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
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  fun finishNarrow t (r : C.reply) =
    if not (C.answered r) andalso not (Narrow.short_direct t) then NONE else SOME r

  (* ================= networking ================= *)
  val IPRE = "(?<![\\d.])(\\d{1,3}(?:\\.\\d{1,3}){3})(?![\\d.]*\\d)"
  fun ip4 (s : string) =
    case String.fields (fn c => c = #".") s of
      [a, b, c, d] => C.IP (natS a, natS b, natS c, natS d)
    | _ => raise Fail "ip"
  fun maskPrefix m = case C.mask_prefix m of SOME p => p | NONE => nat 0

  fun networking text =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
      in
        if has "\\bipv6\\b|[0-9a-f]{0,4}::[0-9a-f]" low then NONE
        else
          let
            val ips = map (fn m => (g1 t m, startOf m)) (findall IPRE t)
          in
            if null ips andalso not (has "(?<![\\w.])/\\d{1,2}\\b|\\bprefix(?: length)?\\s*(?:of\\s*)?/?\\d{1,2}\\b|\\bcidr\\b|\\bsubnet|\\b(?:smallest|which|what) (?:subnet|prefix)\\b" low) then NONE
            else
              let
                val maskIps = List.filter (fn (s, a) =>
                    has "\\b(?:subnet mask|netmask|mask)\\s*(?:of|is|=|:)?\\s*$" (String.substring (low, 0, a))
                    orelse String.isPrefix "255." s) ips
                val hostIps = List.filter (fn x => not (List.exists (fn y => y = x) maskIps)) ips
                val pref0 = map (fn m => natS (g1 low m)) (findall "(?<![a-z])/\\s*(\\d{1,3})\\b" low)
                val pl = search "\\bprefix(?: length)?\\s*(?:of|is|=)?\\s*/?(\\d{1,3})\\b" low
                val pref = case pl of
                             SOME m => let val v = natS (g1 low m) in if List.exists (fn x => x = v) pref0 then pref0 else pref0 @ [v] end
                           | NONE => pref0
                val ipsAll = map (fn (s, _) => ip4 s) ips
                val maskL = map (fn (s, _) => ip4 s) maskIps
                val prefB = if null maskIps orelse not (null pref) then pref else [maskPrefix (ip4 (#1 (hd maskIps)))]
                fun mk body = finishNarrow t (C.net_reply (C.NReq (ipsAll, maskL, pref, body)))
                val hn = search "\\b(?:for|holds?|fit|support|accommodate|needs?|with)\\s+(?:at least\\s+)?([\\d,]+)\\s+(?:usable\\s+)?(?:hosts?|devices|addresses|computers|machines)\\b" low
              in
                if isSome hn andalso has "\\b(?:smallest|what|which)\\s+(?:subnet|prefix|cidr|mask|size|block)|\\bsubnet (?:size|mask) (?:do|would|should)|\\bhow (?:big|large) (?:a )?subnet" low
                   andalso null hostIps then
                  mk (C.BForHosts (natS (g1 low (valOf hn))))
                else if (has "\\bhow many\\b.*\\bsubnets?\\b|\\bhow many\\s*/\\d" low) andalso length prefB >= 2 andalso null hostIps then
                  let
                    val fm = search "/\\s*(\\d{1,2})\\b[^/]{0,40}?\\b(?:in|into|inside|within|from|of)\\s+(?:an?\\s+|one\\s+|a single\\s+)?/\\s*(\\d{1,2})\\b" low
                    val dm = search "\\b(?:divide|split|carve|break|subnet)\\w*\\s+(?:an?\\s+)?/\\s*(\\d{1,2})\\s*(?:network |block )?into\\s*/\\s*(\\d{1,2})" low
                  in
                    case (fm, dm) of
                      (SOME m, _) => mk (C.BSubnets (natS (g1 low m), natS (valOf (grp low m 2))))
                    | (NONE, SOME m) => mk (C.BSubnets (natS (valOf (grp low m 2)), natS (g1 low m)))
                    | _ => NONE
                  end
                else if has "\\bprivate\\b|\\brfc ?1918\\b|\\bpublic\\b|\\broutable\\b" low andalso length hostIps = 1
                        andalso not (has "\\bsubnet\\b|\\bbroadcast\\b" low) then
                  mk (C.BPrivate (ip4 (#1 (hd hostIps))))
                else if has "\\bsame (?:subnet|network|lan|segment)\\b" low andalso length hostIps >= 2 then
                  mk (C.BSame (ip4 (#1 (hd hostIps)), ip4 (#1 (List.nth (hostIps, 1))), case prefB of [] => NONE | p :: _ => SOME p))
                else if null hostIps then
                  (if has "\\bwildcard\\b" low andalso not (null prefB) then mk (C.BWildcard (hd prefB))
                   else if not (null maskIps) andalso has "\\bprefix\\b|\\bcidr\\b|\\bslash\\b|\\bhow many (?:network )?bits\\b|\\bnotation\\b" low then
                     mk (C.BPrefix (ip4 (#1 (hd maskIps))))
                   else if not (null prefB) andalso null maskIps andalso has "\\bmask\\b|\\bnetmask\\b|\\bdotted\\b" low then mk (C.BMask (hd prefB))
                   else if not (null prefB) andalso has "\\bhow many\\b|\\bnumber of\\b|\\bcount\\b" low
                           andalso has "\\bhosts?\\b|\\baddress(?:es)?\\b|\\bips?\\b|\\bdevices\\b" low then
                     mk (C.BCount (hd prefB, has "\\busable\\b|\\bhosts?\\b|\\bdevices\\b|\\bassign" low))
                   else NONE)
                else
                  let
                    val want =
                      if has "\\bbroadcast\\b" low then SOME C.W_broadcast
                      else if has "\\brange\\b|\\bfirst and last\\b|\\bfirst (?:usable|valid|host)\\b.*\\blast\\b" low then SOME C.W_range
                      else if has "\\bfirst (?:usable|valid|host|assignable)\\b" low then SOME C.W_first
                      else if has "\\blast (?:usable|valid|host|assignable)\\b" low then SOME C.W_last
                      else if has "\\bnetwork (?:address|id|number)\\b|\\bsubnet (?:address|id)\\b|\\bwhich (?:subnet|network)\\b|\\bwhat (?:subnet|network) (?:is|does)\\b" low then SOME C.W_network
                      else if has "\\bhow many\\b" low andalso has "\\bhosts?\\b|\\busable\\b" low then SOME C.W_hosts
                      else NONE
                  in
                    case want of
                      NONE => NONE
                    | SOME w =>
                        (case prefB of
                           [] => mk C.BNeedPrefix
                         | p :: _ => mk (C.BAddr (w, ip4 (#1 (hd hostIps)), p)))
                  end
              end
          end
      end


  (* ================= embedded ================= *)
  val NUMP = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val FREQP = NUMP ^ "\\s*(ghz|mhz|khz|hz)\\b"
  fun unitMul u = case u of "ghz" => 1000000000 | "mhz" => 1000000 | "khz" => 1000 | _ => 1 : IntInf.int
  fun freqsP low =
    map (fn m => mulP (decParts (g1 low m)) (unitMul (valOf (grp low m 2)))) (findall FREQP low)
  fun maxP ps = List.foldl (fn (x, best) => if cmpP (x, best) = GREATER then x else best) (hd ps) (tl ps)
  fun clockP low =
    case search (NUMP ^ "\\s*(ghz|mhz|khz|hz)\\s*(?:clock|crystal|cpu|system clock|oscillator)\\b|\\bclock\\w*\\s*(?:of|at|is|=|:)?\\s*" ^ NUMP ^ "\\s*(ghz|mhz|khz|hz)\\b") low of
      SOME m =>
        (case grp low m 1 of
           SOME v => SOME (mulP (decParts v) (unitMul (valOf (grp low m 2))))
         | NONE => SOME (mulP (decParts (valOf (grp low m 3))) (unitMul (valOf (grp low m 4)))))
    | NONE => (case freqsP low of [] => NONE | fs => SOME (maxP fs))

  fun embedded text =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin req = finishNarrow t (C.emb_reply req)
        fun r p = ratP p
        val al = search "\\b(\\d{1,2})\\s+address (?:lines|bits|pins)\\b|\\b(\\d{1,2})[- ]bit address(?: bus)?\\b" low
      in
        if isSome al andalso has "\\bhow many\\b|\\baddress(?:able)? (?:space|locations)\\b|\\bhow much memory\\b|\\bmemory locations\\b" low then
          let
            val n = natS (valOf (gOpt low (valOf al) [1, 2]))
            val dw = search "\\b(\\d{1,2})[- ]bit (?:data|word|wide)\\b|\\bdata (?:bus|width) (?:of )?(\\d{1,2}) bits\\b" low
          in
            if isSome dw andalso has "\\bbytes\\b|\\bhow much memory\\b" low then
              fin (C.EAddr (n, SOME (natS (valOf (gOpt low (valOf dw) [1, 2])))))
            else fin (C.EAddr (n, NONE))
          end
        else
          let
            val baud = search (NUMP ^ "\\s*(?:baud|bps|bits? per second)\\b|\\bbaud(?: rate)?\\s*(?:of|is|=)?\\s*" ^ NUMP) low
          in
            if isSome baud andalso has "\\buart\\b|\\bserial\\b|\\bbaud\\b|\\brs-?232\\b|\\b8n1\\b|\\b8e1\\b|\\b8n2\\b" low then
              let
                val bP = decParts (valOf (gOpt low (valOf baud) [1, 2]))
                val B = r bP
                val fc = clockP low
              in
                if isSome fc andalso has "\\bubrr\\b|\\bbaud (?:rate )?register\\b|\\bdivisor\\b" low then fin (C.EUbrr (r (valOf fc), B))
                else
                  let
                    val unit = if has "\\bcharacters? per second\\b|\\bhow many characters?\\b" low
                                  andalso not (has "\\bbytes? per second\\b|\\bhow many bytes?\\b" low)
                               then C.E_char else C.E_byte
                    val (data, par, stop) =
                      case search "\\b([5-9])([neo])([12])\\b" low of
                        SOME m => (natS (g1 low m), if valOf (grp low m 2) = "n" then nat 0 else nat 1, natS (valOf (grp low m 3)))
                      | NONE =>
                          let
                            val dm = search "\\b([5-9]) data bits?\\b" low
                            val sm = search "\\b([12]) stop bits?\\b" low
                            val par = if has "\\b(?:even|odd) parity\\b|\\bparity bit\\b|\\bwith parity\\b" low andalso not (has "\\bno parity\\b" low)
                                      then nat 1 else nat 0
                          in (case dm of SOME m => natS (g1 low m) | NONE => nat 8, par, case sm of SOME m => natS (g1 low m) | NONE => nat 1) end
                  in
                    if has "\\bbytes? per second\\b|\\bthroughput\\b|\\bcharacters per second\\b|\\bhow many bytes\\b" low then fin (C.EUartTp (unit, B, data, par, stop))
                    else if has "\\bhow long\\b|\\btime\\b|\\bduration\\b" low then
                      let
                        val nb = search (NUMP ^ "\\s*(bytes|characters|chars)\\b") low
                        val k = case nb of SOME m => ratOf (g1 low m) | NONE => ratP (1, 1)
                        val countUnit = case nb of SOME m => if grp low m 2 = SOME "bytes" then C.E_byte else C.E_char
                                                   | NONE => if has "\\b(?:a|one) character\\b" low then C.E_char else C.E_byte
                      in fin (C.EUartTime (countUnit, B, k, data, par, stop)) end
                    else NONE
                  end
              end
            else
              let
                val fc = clockP low
                val pre = search "\\bprescal\\w*\\s*(?:of|is|=|:)?\\s*(\\d+)\\b|\\b(\\d+)\\s*prescal\\w*\\b|/\\s*(\\d+)\\s*prescal" low
                val bits = search "\\b(8|10|16|24|32)[- ]bit (?:timer|counter)\\b" low
              in
                if isSome fc andalso has "\\btimer\\b|\\bcounter\\b|\\btick\\b|\\bctc\\b|\\bocr\\w*\\b|\\bcompare\\b" low then
                  let
                    val fcP = valOf fc
                    val P = case pre of SOME m => natS (valOf (gOpt low m [1, 2, 3])) | NONE => nat 1
                    val bitsN = Option.map (fn m => natS (g1 low m)) bits
                  in
                    if has "\\bctc\\b|\\bcompare (?:value|match|register)\\b|\\bocr\\w*\\b" low andalso isSome bitsN then
                      (case List.find (fn x => cmpP (x, fcP) <> EQUAL) (freqsP low) of
                         NONE => NONE
                       | SOME ft => fin (C.ECtc (r fcP, P, r ft, valOf bitsN)))
                    else if isSome bitsN andalso has "\\boverflow\\b" low then
                      fin (C.EOvf (valOf bitsN, r fcP, P, has "\\bfrequency\\b|\\bhow often\\b|\\bper second\\b" low))
                    else if has "\\btick\\b|\\bresolution\\b|\\bperiod of (?:one|each) (?:tick|count)\\b|\\btimer frequency\\b|\\bcount rate\\b" low then
                      fin (C.ETick (r fcP, P, has "\\btimer frequency\\b|\\bcount rate\\b|\\btick rate\\b" low))
                    else NONE
                  end
                else NONE
              end
          end
      end

  (* ================= cyber ================= *)
  val setPats = [
    ("\\bprintable ascii\\b|\\ball printable\\b|\\b95[- ]character\\b|\\bascii printable\\b", C.CS_printable),
    ("\\balphanumeric\\b|\\bletters and digits\\b|\\bletters and numbers\\b|\\bupper(?:case)?,? lower(?:case)? and digits\\b", C.CS_alnum),
    ("\\bmixed[- ]case letters\\b|\\bupper(?:case)? and lower(?:case)? letters\\b|\\bletters \\(both cases\\)", C.CS_mixed),
    ("\\blower[- ]?case letters\\b|\\blowercase\\b", C.CS_lower),
    ("\\bdigits only\\b|\\bnumeric pin\\b|\\bpin\\b|\\bdigits\\b|\\bnumbers only\\b", C.CS_digits)]
  val digestBits = [("md5", 128), ("sha-1", 160), ("sha1", 160), ("sha-224", 224), ("sha224", 224), ("sha-256", 256),
                    ("sha256", 256), ("sha-384", 384), ("sha384", 384), ("sha-512", 512), ("sha512", 512)] : (string * int) list

  val nonuniform = "\\bnon[- ]?uniform(?:ly)?\\b|\\bnot (?:uniform(?:ly)?|independent(?:ly)?|equally likely)\\b|\\bunequal(?:ly)?\\b|\\bbiased\\b|\\bcorrelated\\b|\\bdependent (?:characters|choices|symbols)\\b"

  fun cyber text =
    if Narrow.narrative text then NONE
    else
      let
        val t = collapse text
        val low = lower t
        fun fin req = finishNarrow t (C.cyb_reply req)
      in
        if has "\\bhow (?:do|can|to) (?:i |you |we )?(?:crack|hack|bypass|break into|steal|brute[- ]force (?:a|an|my|someone|the))\\b|\\bexploit\\b" low then NONE
        else
          let
            val dg = search "\\b(md5|sha-?1|sha-?224|sha-?256|sha-?384|sha-?512)\\b" low
            val dgBits = Option.map (fn m => #2 (valOf (List.find (fn (k, _) => k = g1 low m) digestBits))) dg
          in
            if isSome dg andalso has "\\bhex\\w*\\b|\\bcharacters\\b|\\bhow long\\b|\\blength\\b" low andalso not (has "\\bcollision\\b|\\bbirthday\\b" low) then
              fin (C.CDigest (nat (IntInf.fromInt (valOf dgBits))))
            else if has "\\bcollision\\b|\\bbirthday\\b" low then
              let val bm = search "\\b(\\d{2,3})[- ]bit\\b" low
                  val n = case bm of SOME m => SOME (natS (g1 low m)) | NONE => Option.map (fn b => nat (IntInf.fromInt b)) dgBits
              in case n of NONE => NONE | SOME n => fin (C.CBirthday n) end
            else
              let val b6 = search "(\\d+(?:,\\d{3})*)\\s*(?:bytes?|octets?)\\b" low in
                if isSome b6 andalso has "\\bbase ?64\\b" low andalso has "\\blength\\b|\\bhow (?:many|long)\\b|\\bcharacters\\b|\\bsize\\b" low then
                  fin (C.CBase64 (natS (g1 low (valOf b6))))
                else
                  let val lm = search "\\b(\\d{1,3})[- ](?:character|char|digit|letter)\\b|\\blength (?:of )?(\\d{1,3})\\b|\\b(\\d{1,3}) characters? long\\b" low in
                    if isSome lm andalso has "\\bpasswords?\\b|\\bpassphrases?\\b|\\bpins?\\b|\\bkeys?\\b|\\bcodes?\\b" low then
                      let
                        val L = natS (valOf (gOpt low (valOf lm) [1, 2, 3]))
                        val sm = search "\\b(?:set|alphabet|character set|charset) of (\\d+)\\b|\\b(\\d+)[- ](?:symbol|character) (?:set|alphabet)\\b" low
                        val cs =
                          case sm of
                            SOME m => SOME (C.CS_custom (natS (valOf (gOpt low m [1, 2]))))
                          | NONE =>
                              if has "\\b\\d{1,3}[- ]digit\\b" low then SOME C.CS_digits
                              else Option.map #2 (List.find (fn (p, _) => has p low) setPats)
                      in
                        case cs of
                          NONE => NONE
                        | SOME cs =>
                            if has "\\bhow long\\b|\\btime\\b|\\bbrute[- ]force\\b|\\bexhaust\\w*\\b|\\bto crack\\b|\\bto guess\\b" low then
                              let
                                val avg = has "\\baverage\\b|\\bon average\\b|\\bexpected\\b" low
                                val rate = search "(\\d+(?:\\.\\d+)?(?:e\\d+)?)\\s*(billion|million|thousand|trillion)?\\s*(?:guesses|attempts|hashes|tries|keys)\\s*(?:per|a|/)\\s*(second|sec|s)\\b" low
                                val R = Option.map (fn m =>
                                    let
                                      val s = g1 low m
                                      val (mant, ex) = case String.fields (fn c => c = #"e") s of [a] => (a, 0) | [a, b] => (a, valOf (Int.fromString b)) | _ => (s, 0)
                                      val (n, d) = decParts mant
                                      val mul = case grp low m 2 of SOME "thousand" => 1000 | SOME "million" => 1000000 | SOME "billion" => 1000000000
                                                                  | SOME "trillion" => 1000000000000 | _ => 1 : IntInf.int
                                    in ratP (n * mul * IntInf.pow (10, ex), d) end) rate
                              in fin (if avg andalso has nonuniform low then C.CDistribution else C.CBrute (avg, cs, L, R)) end
                            else if has "\\bentropy\\b|\\bbits\\b" low then fin (if has nonuniform low then C.CDistribution else C.CEntropy (cs, L))
                            else if has "\\bhow many (?:possible )?(?:passwords|combinations|pins|keys|codes)\\b|\\bkeyspace\\b|\\bcombinations\\b|\\bpossibilities\\b" low then
                              fin (C.CKeyspace (cs, L))
                            else NONE
                      end
                    else NONE
                  end
              end
          end
      end


  (* ================= linux-v2 ================= *)
  fun digitsOf s = map (fn c => nat (IntInf.fromInt (Char.ord c - 48))) (String.explode s)

  (* "5-field" cron item parsing (untrusted; the kernel validates ranges) *)
  fun cronField (f : string) : C.citem list =
    map (fn part =>
      case search "^(\\*|\\d+(?:-\\d+)?)(?:/(\\d+))?$" part of
        NONE => C.CBad
      | SOME m =>
          let
            val base = g1 part m
            val step = Option.map natS (grp part m 2)
            val b =
              if base = "*" then C.CStar
              else case String.fields (fn c => c = #"-") base of
                     [a, z] => C.CRange (natS a, natS z)
                   | _ => C.CSingle (natS base)
          in C.CI (b, step) end) (String.fields (fn c => c = #",") f)

  fun permOf (grp3 : string) : C.perm =
    let
      val c = String.explode grp3
      val r = List.nth (c, 0) = #"r" and w = List.nth (c, 1) = #"w"
      val x = case List.nth (c, 2) of
                #"x" => C.X_x | #"s" => C.X_sp | #"t" => C.X_sp | #"S" => C.X_SP | #"T" => C.X_SP | _ => C.X_no
    in C.Perm (r, w, x) end

  fun subCI pat rep (t : string) =
    let val low = lower t
    in replaceSpans t (map (fn m => (startOf m, stopOf m, rep m low)) (findall pat low)) end

  fun linuxV1 t =
    if Narrow.narrative t then NONE
    else
      let
        val low = lower t
        fun fin req = finishNarrow t (C.lin_reply req)
        val sigName = searchCS "\\b(sig[a-z0-9]+)\\b" t
                        (fn m => CharVector.all (fn c => Char.isUpper c orelse Char.isDigit c) (span t m))
        val sigNum = search "\\bsignal\\s+(\\d{1,2})\\b" low
        val sm = case sigName of
                   SOME m => SOME (true, g1 t m)
                 | NONE => (case sigNum of SOME m => SOME (false, g1 low m) | NONE => NONE)
        val sigCtx = isSome (searchCS "\\bsignal\\b|\\bexit (?:code|status)\\b|\\bkill\\b|\\bsig" t
                       (fn m => let val w = span t m
                                in if lower w = "sig" then w = "SIG" else isLowerSpan w end))
        (* None => not taken, outer SOME r => answered by this branch, NONE inner => fall through *)
        val sigResult : (bool * C.reply option) =
          case sm of
            SOME (isName, s0) =>
              if sigCtx then
                let
                  val s = s0
                  val nOpt = if isName then C.sig_num s else (let val n = natS s in case C.sig_name n of SOME _ => SOME n | NONE => NONE end)
                in
                  case nOpt of
                    NONE => (true, NONE)
                  | SOME n =>
                      if has "\\bexit (?:code|status)\\b|\\$\\?" low then (false, SOME (C.lin_reply (C.LExit n)))
                      else if has "\\bwhich signal\\b|\\bwhat signal\\b|\\bsignal name\\b|\\bname of signal\\b" low andalso not isName then
                        (false, SOME (C.lin_reply (C.LSigName n)))
                      else if isName andalso has "\\bnumber\\b|\\bwhat (?:is|number)\\b|\\bwhich number\\b|\\bvalue\\b" low then
                        (false, SOME (C.lin_reply (C.LSigNum s)))
                      else (false, NONE)
                end
              else (false, NONE)
          | NONE => (false, NONE)
      in
        case sigResult of
          (true, _) => NONE
        | (_, SOME r) => finishNarrow t r
        | _ =>
          let val um = search "\\bumask\\s*(?:of|is|=)?\\s*(\\d{3,4})\\b" low in
            case um of
              SOME m =>
                let
                  val ds = digitsOf (g1 low m)
                  val dir = has "\\bdirector(?:y|ies)\\b|\\bfolders?\\b" low
                  val fil = has "\\bfiles?\\b" low
                  val w = if dir andalso not fil then C.UM_dir else if fil andalso not dir then C.UM_file else C.UM_both
                in fin (C.LUmask (ds, w)) end
            | NONE =>
              let val cm = search "[`'\"]\\s*(\\S+\\s+\\S+\\s+\\S+\\s+\\S+\\s+\\S+)\\s*[`'\"]" t in
                if isSome cm andalso has "\\bcron\\w*\\b|\\bcrontab\\b" low andalso has "\\bhow many times\\b|\\bhow often\\b|\\bhow many runs\\b" low then
                  let
                    val whole = g1 t (valOf cm)
                    val fields = String.tokens Char.isSpace whole
                    val parsed = map cronField fields
                    fun mkc ph = C.LCron (ph, parsed, List.nth (fields, 0), whole)
                    val valid = C.lin_reply (mkc false)
                    (* a malformed field declines before the period is read *)
                    val malformed = (not (C.answered valid)) andalso C.reply_kind valid = "impossible"
                  in
                    if malformed then fin (mkc false)
                    else if has "\\bper hour\\b|\\ban hour\\b|\\beach hour\\b|\\bevery hour\\b" low then
                      (if List.nth (fields, 1) <> "*" then NONE else fin (mkc true))
                    else if has "\\bper day\\b|\\ba day\\b|\\beach day\\b|\\bdaily\\b|\\bin a day\\b" low then
                      (if List.drop (fields, 2) <> ["*", "*", "*"] then NONE else fin (mkc false))
                    else NONE
                  end
                else
                  let
                    val classes = ["r-", "w-", "xsS-", "r-", "w-", "xsS-", "r-", "w-", "xtT-"]
                    fun symOk m =
                      let
                        val s9 = valOf (grp t m 2)
                        val typeOk = case grp t m 1 of NONE => true | SOME c => CharVector.all (fn ch => Char.contains "-dlbcps" ch) c
                      in typeOk andalso size s9 = 9 andalso
                         List.all (fn (i, cl) => Char.contains cl (String.sub (s9, i)))
                           (ListPair.zip (List.tabulate (9, fn i => i), classes))
                      end
                    val sy = searchCS "(?<![\\w-])([-dlbcps])?([r-][w-][xsS-][r-][w-][xsS-][r-][w-][xtT-])(?![\\w-])" t symOk
                  in
                    if isSome sy andalso has "\\boctal\\b|\\bnumeric\\b|\\bchmod\\b|\\bin numbers\\b|\\bnumber\\b" low then
                      let val s9 = valOf (grp t (valOf sy) 2)
                          val sub = fn i => String.substring (s9, 3 * i, 3)
                      in fin (C.LOctFromSym (C.Sym (permOf (sub 0), permOf (sub 1), permOf (sub 2)))) end
                    else
                      let
                        fun chmodOk m =
                          let val w = span t m
                          in String.isPrefix "chmod" w andalso
                             (not (String.isSubstring "-r" (lower w)) orelse String.isSubstring "-R" w)
                          end
                        val om = case searchCS "\\bchmod\\s+(?:-R\\s+)?(\\d{3,4})\\b" t chmodOk of
                                   SOME m => SOME (g1 t m)
                                 | NONE =>
                                   (case search "\\b(?:permissions?|mode)\\s+(?:of\\s+)?(\\d{3,4})\\b" low of
                                      SOME m => SOME (g1 low m)
                                    | NONE => Option.map (fn m => g1 low m) (search "\\b(\\d{3,4})\\s+permissions?\\b" low))
                      in
                        case om of
                          SOME md =>
                            if has "\\bpermissions?(?: bits?)?\\b.{0,40}\\b(?:denied|not granted|missing|unset|clear)\\b" low
                               andalso not (has "\\bnot (?:denied|missing|unset|clear)\\b|\\baren(?:'|\226\128\153)t (?:denied|missing|unset|clear)\\b" low) then
                              let
                                val ds = digitsOf md
                                val (sp, u, g, o') = case ds of [u,g,o'] => (nat 0,u,g,o')
                                                         | [sp,u,g,o'] => (sp,u,g,o')
                                                         | _ => raise Fail "bounded mode parser"
                                val classes = List.mapPartial (fn (pat,c) => if has pat low then SOME c else NONE)
                                  [("\\bowner\\b|\\buser\\b",C.P_owner), ("\\bgroup\\b",C.P_group), ("\\bothers?\\b",C.P_other)]
                                val who = case classes of [c] => SOME c | _ => NONE
                                val multiMode = has "\\b\\d{3,4}\\b.*\\b\\d{3,4}\\b" low
                                val extraAction = has "\\b(?:and|then|also)\\s+(?:how|what|which|change|set|grant|remove|run|execute|chmod)\\b" low
                              in if multiMode orelse extraAction then finishNarrow t C.permission_scope_reply
                                 else if has "\\bacls?\\b|\\beffective (?:access|permissions?)\\b|\\b(?:root|privileged) (?:user|process)\\b" low
                                 then finishNarrow t C.permission_effective_reply
                                 else finishNarrow t (C.permission_reply (C.Mode (sp,u,g,o')) who) end
                            else if has "\\bmean\\b|\\bsymbolic\\b|\\brwx\\b|\\bwhat (?:permissions|access)\\b|\\bls -l\\b|\\bgive\\b|\\bgrant\\b|\\bset\\b" low
                            then fin (C.LSymFromOct (digitsOf md)) else NONE
                        | NONE => NONE
                      end
                  end
              end
          end
      end

  fun linuxV2 text =
    let
      val t0 = collapse text
      val day = "\\bin (?:one|a single|1) day\\b|\\bin a 24[- ]hour (?:period|day)\\b|\\bin 24 hours\\b|\\bevery day\\b|\\bover a day\\b"
      val hour = "\\bin (?:one|a single|1) hour\\b|\\bin 60 minutes\\b|\\bover an hour\\b"
      val t1 = subCI day (fn _ => fn _ => "per day") t0
      val t2 = subCI hour (fn _ => fn _ => "per hour") t1
      val t3 = subCI "\\bsignal\\s+(?:has|with|is)\\s+(?:the\\s+)?number\\s+(\\d{1,2})\\b" (fn m => fn low => "signal " ^ g1 low m) t2
      val t4 = subCI "\\bsignal (?:name )?for (?:the )?number\\s+(\\d{1,2})\\b" (fn m => fn low => "name of signal " ^ g1 low m) t3
    in
      case linuxV1 t4 of
        SOME r => SOME r
      | NONE =>
          let val low = lower t4 in
            (if isSome (search "[`'\"]\\s*\\S+\\s+\\S+\\s+\\S+\\s+\\S+\\s+\\S+\\s*[`'\"]" t4)
                  andalso has "\\bcron\\w*\\b|\\bcrontab\\b" low
                  andalso has "\\bhow many (?:times|runs)\\b|\\bhow often\\b" low
                  andalso not (has "\\bper (?:day|hour)\\b|\\ba day\\b|\\ban hour\\b|\\bdaily\\b" low)
               then SOME (C.lin_reply C.LCronNoPeriod) else NONE)
          end
    end

  (* ================= git ================= *)
  val gitIntents = [
    ("\\bundo\\b.*\\blast commit\\b.*\\bkeep\\w*\\b|\\blast commit\\b.*\\bkeep\\w* (?:the )?changes\\b|\\buncommit\\b", C.G_reset_soft),
    ("\\bundo\\b.*\\blast commit\\b.*\\b(?:discard|throw away|lose|delete)\\b|\\bdiscard\\b.*\\blast commit\\b", C.G_reset_hard),
    ("\\b(?:change|edit|fix|reword)\\w*\\b.*\\blast commit(?:\\'s)? message\\b|\\bamend\\w*\\b.*\\bcommit\\b", C.G_amend),
    ("\\bcreate\\b.*\\b(?:new )?branch\\b.*\\bswitch\\b|\\bcreate and switch\\b|\\bnew branch and (?:switch|check (?:it )?out)\\b", C.G_switch_c),
    ("\\bswitch\\b.*\\b(?:to )?(?:another|a different|an existing) branch\\b|\\bchange branches?\\b", C.G_switch),
    ("\\bunstage\\b|\\bremove\\b.*\\bfrom (?:the )?(?:staging area|index)\\b", C.G_unstage),
    ("\\bdiscard\\b.*\\b(?:changes|edits)\\b.*\\bfile\\b|\\brevert\\b.*\\bfile\\b.*\\blast commit\\b", C.G_restore),
    ("\\bstage all\\b|\\badd all\\b.*\\bchanges\\b|\\bstage every\\w*\\b", C.G_add_all),
    ("\\brename\\b.*\\bbranch\\b", C.G_rename),
    ("\\bdelete\\b.*\\bremote branch\\b|\\bremove\\b.*\\bbranch\\b.*\\bremote\\b", C.G_del_remote),
    ("\\bdelete\\b.*\\b(?:local )?branch\\b", C.G_del_local),
    ("\\b(?:list|show|see)\\b.*\\bremotes?\\b|\\bremote urls?\\b", C.G_remotes),
    ("\\b(?:list|show|see)(?:s|ing)?\\b.*\\bstash(?:es)?\\b", C.G_stash_list),
    ("\\bstash\\b.*\\b(?:appl(?:y|ies|ied|ying)|restor(?:e|es|ed|ing)|bring(?:s|ing)? back|pop(?:s|ped|ping)?)\\b|\\b(?:appl(?:y|ies|ied|ying)|restor(?:e|es|ed|ing)|bring(?:s|ing)? back)\\b.*\\bstash\\w*\\b", C.G_stash_pop),
    ("\\bstash(?:es|ing)? (?:my|your|the|all|these|our|uncommitted|changes)\\b|\\bsave\\b.*\\bchanges\\b.*\\bwithout committing\\b|\\bset aside\\b.*\\bchanges\\b", C.G_stash),
    ("\\bstaged (?:changes|diff)\\b|\\bdiff\\b.*\\bstaged\\b|\\bwhat (?:is|i'?ve) staged\\b", C.G_diff_staged),
    ("\\bcommit history\\b|\\bsee (?:the )?history\\b|\\blist (?:of )?commits\\b|\\bshow(?:s|ing)? (?:the )?log\\b", C.G_log),
    ("\\bclone\\b", C.G_clone),
    ("\\binitiali[sz]e\\b.*\\brepo\\w*\\b|\\bstart a new (?:git )?repo\\w*\\b|\\bcreate a (?:new )?(?:git )?repo\\w*\\b", C.G_init),
    ("\\bset\\b.*\\b(?:user ?name|name)\\b.*\\bgit\\b|\\bconfigure\\b.*\\bname\\b", C.G_config_name),
    ("\\bcurrent status\\b|\\bwhich files (?:have )?changed\\b|\\bsee\\b.*\\bchanged files\\b", C.G_status),
    ("\\bfetch\\b.*\\bwithout merging\\b|\\bdownload\\b.*\\bwithout merging\\b", C.G_fetch),
    ("\\bpull\\b.*\\brebase\\b", C.G_pull_rebase),
    ("\\bcherry[- ]pick(?:s|ed|ing)?\\b|\\bapply a (?:single|specific) commit\\b|\\bcopy a commit\\b", C.G_cherry_pick),
    ("\\bannotated tag\\b", C.G_tag_a),
    ("\\bwho (?:changed|wrote|last modified)\\b.*\\bline\\b|\\bblame\\b", C.G_blame),
    ("\\bundo\\b.*\\bpushed commit\\b|\\bnew commit that undoes\\b|\\breverse a commit\\b|\\brevert a commit\\b", C.G_revert)]

  fun git text =
    if Narrow.narrative text then NONE
    else
      let val low = lower (collapse text) in
        if not (has "\\bgit\\b|\\bcommit\\w*\\b|\\bbranch\\w*\\b|\\brepo\\w*\\b|\\bstash\\w*\\b|\\bstag(?:e|ed|ing)\\b" low) then NONE
        else if not (has "\\bhow\\b|\\bwhat (?:command|git command)\\b|\\bwhich command\\b|\\bcommand\\b" low) then NONE
        else case List.find (fn (p, _) => has p low) gitIntents of
               SOME (_, C.G_stash_pop) =>
                 SOME (C.git_reply (if has "\\b(?:keep|retain|preserve)\\b|\\bwithout (?:dropping|removing|deleting)\\b" low
                                      then C.G_stash_apply else C.G_stash_pop))
             | SOME (_, i) => SOME (C.git_reply i)
             | NONE => NONE
      end


  (* ================= python / python-r2 ================= *)
  val SIGRE = "\\b(?:parameters?|arguments?|args|signatures?|what does .* take|how (?:do i|to) call|call signature)\\b"
  val DOESRE = "\\bwhat does\\b.*\\b(?:do|return)\\b|\\bwhat is\\b.*\\b(?:for|used for)\\b|\\bexplain\\b|\\bdescribe\\b"
  val MODRE = "\\bwhich modules?\\b|\\bwhat modules?\\b|\\bwhere (?:is|does)\\b.*\\b(?:defined|live|come from)\\b|\\bimport\\b.*\\bfrom\\b"
  val PYRE = "\\bpython\\b|`|\\bfunction\\b|\\bmethod\\b|\\bmodule\\b|\\bbuilt-?in\\b|\\bstdlib\\b|\\bstandard library\\b|\\w\\.\\w+|\\(\\)"

  fun rstripDot s = if String.isSuffix "." s then rstripDot (String.substring (s, 0, size s - 1)) else s
  fun rpartition (c : string) : (string * string) option =
    let
      val cs = String.explode c
      fun lastDot i best = if i >= length cs then best else lastDot (i + 1) (if List.nth (cs, i) = #"." then SOME i else best)
    in case lastDot 0 NONE of
         NONE => NONE
       | SOME i => SOME (String.substring (c, 0, i), String.substring (c, i + 1, size c - i - 1))
    end

  (* Bounded complete list/clause grammar. NONE means no batch syntax; SOME NONE
     means recognized compound syntax with an unsupported residual clause. *)
  fun pythonBatch text =
    let
      val original = collapse text
      fun cutSuffix p s = case search p (lower s) of NONE => s | SOME m => String.substring (s, 0, #start m)
      val noEnd = cutSuffix "[?.!]+$" original
      val noPython = cutSuffix "(?:,)?\\s+in python$" noEnd
      val body0 = case search "^(?:in python,?\\s+|python:\\s*)" (lower noPython) of
                   NONE => noPython | SOME m => String.extract (noPython, #stop m, NONE)
      val body = if has "^explain what\\b" (lower body0) then cutSuffix "\\s+(?:do|does|return|returns)$" body0 else body0
      val separator = ",\\s*(?:and\\s+)?|\\s+and\\s+|;\\s*"
      val cuts = findall separator (lower body)
      fun parts i [] = [String.extract (body,i,NONE)]
        | parts i ((m : Regex.match)::ms) = String.substring(body,i,#start m-i) :: parts (#stop m) ms
      val pieces = map collapse (parts 0 cuts)
      val lead = "^(?:(?:please )?(?:what (?:is|are)|give|show|list) (?:the )?|the )?"
      val roles = [
        (lead ^ "(?:signatures?|parameters?|arguments?) (?:of|for) (.+)$", C.PQ_signature),
        (lead ^ "modules? (?:of|for) (.+)$", C.PQ_module),
        ("^(?:which|what) modules? (?:contains?|provides?) (.+)$", C.PQ_module),
        ("^(?:explain what|describe|explain) (.+?)(?: does| do)?$", C.PQ_doc),
        (lead ^ "descriptions? (?:of|for) (.+)$", C.PQ_doc)]
      fun role piece =
        case List.find (fn (p,_) => has p (lower piece)) roles of
          NONE => NONE
        | SOME(p,q) => SOME(q,g1 piece (valOf(search p (lower piece))))
      fun name piece =
        case search "^`?([A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*)(?:\\(\\))?`?$" (lower piece) of
          NONE => NONE
        | SOME m => SOME(g1 piece m)
      fun jobs _ [] acc = SOME(rev acc)
        | jobs inherited (piece::rest) acc =
            let val rq = case role piece of SOME x => SOME x | NONE => Option.map (fn q => (q,piece)) inherited
            in case rq of NONE => NONE
             | SOME(q,raw) => (case name raw of NONE => NONE | SOME n =>
                 jobs (SOME q) rest (C.PyJob(q,C.PyCand(n,rpartition n,size n>2))::acc))
            end
    in
      if null cuts orelse not (isSome (role (hd pieces)) orelse has SIGRE (lower body)
          orelse has DOESRE (lower body) orelse has MODRE (lower body))
      then NONE else SOME(jobs NONE pieces [])
    end

  fun python text =
    let
      val t = collapse text
      val low = lower t
      val batch = pythonBatch t
    in
      if t = "" orelse not (isSome batch orelse has SIGRE low orelse has DOESRE low orelse has MODRE low) orelse not (has PYRE low) then NONE
      else
        let
          (* [A-Za-z_] classes cover both cases, so matching the lower-cased text finds the
             same spans; the names are read back from the original text *)
          fun csFind p = map (fn m => g1 t m) (findall p low)
          val c1 = case search "`([A-Za-z_][\\w.]*)(?:\\(\\))?`" low of SOME m => [g1 t m] | NONE => []
          val c2 = csFind "\\b([A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)+)(?:\\(\\))?"
          val c3 = csFind "\\b([A-Za-z_]\\w*)\\(\\)"
          val c4 = map (fn m => String.substring (t, #1 (valOf (Vector.sub (#groups m, 1))), #2 (valOf (Vector.sub (#groups m, 1))) - #1 (valOf (Vector.sub (#groups m, 1)))))
                       (findall "\\b(?:function|method|builtin|built-in)\\s+`?([a-z_]\\w*)`?" low)
          (* the keyword is case-sensitive in the organ *)
          val c5 = map (fn m => g1 t m)
                     (findallCS "\\b(?:of|does|is|for|provides)\\s+`?([A-Za-z_][A-Za-z0-9_]*)`?\\b" t
                        (fn m => isLowerSpan (String.substring (t, #start m, #1 (valOf (Vector.sub (#groups m, 1))) - #start m))))
          (* A bare name after "explain what" is a reference request too. Keep
             original case and leave unknown/ambiguous resolution to the kernel. *)
          val c6 = csFind "\\b(?:explain|describe) what ([A-Za-z_][A-Za-z0-9_]*) (?:does|returns)\\b"
          val c7 = csFind "\\bpython(?:'s|\226\128\153s)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+take\\b"
          val cands = map rstripDot (c1 @ c2 @ c3 @ c4 @ c5 @ c6 @ c7)
          val pcs = map (fn c => C.PyCand (c, rpartition c, size c > 2)) cands
          val q = if has MODRE low then C.PQ_module else if has SIGRE low then C.PQ_signature else C.PQ_doc
          val r = case batch of
                    NONE => C.py_reply q pcs
                  | SOME NONE => C.py_batch_scope_reply
                  | SOME (SOME jobs) => C.py_batch_reply jobs
        in
          if C.reply_kind r = "not_taken" then NONE else SOME r
        end
    end

  (* ================= robotics-v2 ================= *)
  val NR = "(-?\\d+(?:\\.\\d+)?)"
  val NR1 = "(-?\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val MS = "\\s*m\\s*/\\s*s\\b"
  val VERB = "(?:moves|turns|spins|runs|rotates|travels|goes|drives|rolls)(?:\\s+at)?"
  val LU = "\\s*(mm|cm|m|millimet\\w+|centimet\\w+|met(?:er|re)s?)\\b(?!\\s*/)"
  val LEN = "\\s*(mm|cm|m|millimet\\w+|centimet\\w+|met\\w+)\\b"

  fun toM (v : IntInf.int * IntInf.int) (u : string) =
    if String.isPrefix "c" u then mulPDiv v 100
    else if String.isPrefix "mm" u orelse String.isPrefix "milli" u then mulPDiv v 1000
    else v
  and mulPDiv (n, d) (k : IntInf.int) = (n, d * k)

  fun sideSpeed low side =
    let
      val p1 = "\\b" ^ side ^ "(?:[- ]hand)?(?:\\s+wheel(?:'s)?)?(?:\\s+of\\s+(?:the|a|an|its|this)\\s+\\w+)?(?:\\s+(?:speed|velocity))?(?:\\s+" ^ VERB ^ ")?\\s*(?:of|is|=|at|:)?\\s*" ^ NR ^ MS
      val p2 = NR ^ MS ^ "\\s*(?:\\(\\s*" ^ side ^ "\\s*\\)|(?:on|for) the " ^ side ^ "\\b|" ^ side ^ "\\b)"
    in case search p1 low of
         SOME m => SOME (decParts (g1 low m))
       | NONE => (case search p2 low of SOME m => SOME (decParts (g1 low m)) | NONE => NONE)
    end

  fun trackW low =
    case search ("\\b(?:track width|track|wheel ?base|wheel separation|wheel spacing|axle length|axle track)\\s*(?:of|is|=|:)?\\s*" ^ NR ^ LU) low of
      SOME m => SOME (toM (decParts (g1 low m)) (valOf (grp low m 2)))
    | NONE =>
      (case search (NR ^ LU ^ "\\s*(?:apart|track(?: width)?|wheel ?base|between the wheels|axle)\\b") low of
         SOME m => SOME (toM (decParts (g1 low m)) (valOf (grp low m 2)))
       | NONE =>
         (case search ("\\bspaced\\s*(?:by\\s*)?" ^ NR ^ LU) low of
            SOME m => SOME (toM (decParts (g1 low m)) (valOf (grp low m 2)))
          | NONE => NONE))

  fun robotics text =
      let
        val t = collapse text
        val low = lower t
        fun rp p = ratP p
        val diff = has "\\bleft\\b" low andalso has "\\bright\\b" low andalso length (findall "m\\s*/\\s*s" low) >= 2
                   andalso has "\\bwheels?\\b|\\brobot\\b|\\bdifferential\\b|\\brover\\b" low
      in
        (* The three-sentence wheel-speed form is still a single fully
           parameterized request. Long/relational stories remain outside it. *)
        if Narrow.narrative text andalso not
            (diff andalso Narrow.sentences text <= 3 andalso Narrow.words text <= 40
             andalso not (has Narrow.RELATION low orelse has Narrow.RATE low)) then NONE
        else if diff then
          let
            val wantR = has "\\bturning radius\\b|\\bradius of (?:the |its )?turn\\b|\\bturn radius\\b" low
            val wantW = has "\\byaw\\b|\\bangular\\b|\\bturn(?:ing)? rate\\b|\\brotation rate\\b|\\brate of (?:turn|rotation)\\b|\\brad\\s*/\\s*s\\b" low
            val wantV = has "\\blinear\\b|\\bforward speed\\b|\\brobot'?s? speed\\b|\\bhow fast\\b.*\\b(?:robot|forward)\\b|\\bvelocity of the robot\\b|\\bspeed of the robot\\b" low
          in
            if not (wantR orelse wantW orelse wantV) then NONE
            else
              let
                val w = if wantR then C.RW_radius else if wantW then C.RW_angular else C.RW_linear
                val vL = sideSpeed low "left"
                val vR = sideSpeed low "right"
                val L = trackW low
              in SOME (C.rob_reply (C.RDiff (w, Option.map rp vL, Option.map rp vR, Option.map rp L))) end
          end
        else
          let
            val r : C.reply option =
              if has "\\bpwm\\b|\\bduty cycle\\b" low andalso has "\\baverage voltage\\b|\\beffective voltage\\b|\\bmean voltage\\b|\\bwhat voltage\\b" low then
                (case (search "(\\d+(?:\\.\\d+)?)\\s*%" low, search (NR1 ^ "\\s*v\\b(?!\\w)") low) of
                   (SOME dm, SOME vm) => SOME (C.rob_reply (C.RPwm (ratOf (g1 low dm), ratOf (g1 low vm))))
                 | _ => NONE)
              else if has "\\blink\\w*\\b|\\barm\\b" low andalso
                      has "\\bforward kinematics\\b|\\bend[- ]effector\\b|\\bwhere is (?:the )?(?:tip|end|gripper)\\b|\\bposition of (?:the )?(?:tip|end|gripper)\\b|\\btip position\\b" low then
                let
                  val ls = map (fn m => (g1 low m, valOf (grp low m 2))) (findall (NR1 ^ LEN) low)
                  val angs = map (fn m => g1 low m) (findall (NR1 ^ "\\s*(?:\194\176|(?:degrees?|deg)\\b)") low)
                in
                  if length ls < 2 orelse length angs < 2 then NONE
                  else
                    let
                      val (v1, u1) = List.nth (ls, 0)
                      val (v2, u2) = List.nth (ls, 1)
                    in
                      if String.sub (u1, 0) <> String.sub (u2, 0) then NONE
                      else
                        let
                          val l1m = search ("\\b(?:l1|l_1|link 1|first link)\\s*(?:=|is|of|:)?\\s*" ^ NR1) low
                          val l2m = search ("\\b(?:l2|l_2|link 2|second link)\\s*(?:=|is|of|:)?\\s*" ^ NR1) low
                          val (L1, L2) = case (l1m, l2m) of (SOME a, SOME b) => (g1 low a, g1 low b) | _ => (v1, v2)
                          val t1m = search ("(?:\206\184" ^ "1|\206\184_1|theta ?1|joint 1|first joint)\\s*(?:=|is|of|at|:)?\\s*" ^ NR1) low
                          val t2m = search ("(?:\206\184" ^ "2|\206\184_2|theta ?2|joint 2|second joint)\\s*(?:=|is|of|at|:)?\\s*" ^ NR1) low
                          val (a1, a2) = case (t1m, t2m) of (SOME a, SOME b) => (g1 low a, g1 low b)
                                                          | _ => (List.nth (angs, 0), List.nth (angs, 1))
                          val unit = if u1 = "m" orelse u1 = "cm" orelse u1 = "mm" then u1
                                     else if String.isPrefix "c" u1 then "cm" else if String.isPrefix "mi" u1 then "mm" else "m"
                        in SOME (C.rob_reply (C.RFk (ratOf L1, ratOf L2, ratOf a1, ratOf a2, unit))) end
                    end
                end
              else if has "\\bencoder\\b|\\bticks\\b|\\bcounts per rev\\w*\\b|\\bcpr\\b|\\bppr\\b" low andalso has "\\bdistance\\b|\\bhow far\\b|\\btravel\\w*\\b" low then
                let
                  val ticks = search (NR1 ^ "\\s*(?:ticks|counts|pulses)\\b(?!\\s*per)") low
                  val per = search (NR1 ^ "\\s*(?:ticks|counts|pulses)\\s*(?:per|/|a)\\s*rev\\w*|\\b(?:cpr|ppr|ticks per rev\\w*|counts per rev\\w*)\\s*(?:of|is|=)?\\s*" ^ NR1) low
                  val dm = search (NR1 ^ LEN ^ "\\s*(?:diameter\\s*)?(?:wheel)|\\bwheel\\s*(?:diameter\\s*)?(?:of|is|=)?\\s*" ^ NR1 ^ LEN ^ "|\\bdiameter\\s*(?:of|is|=)?\\s*" ^ NR1 ^ LEN) low
                in
                  case (ticks, per, dm) of
                    (SOME tk, SOME pm, SOME d) =>
                      let
                        val (dv, du) = case grp low d 1 of SOME v => (v, valOf (grp low d 2))
                                       | NONE => (case grp low d 3 of SOME v => (v, valOf (grp low d 4)) | NONE => (valOf (grp low d 5), valOf (grp low d 6)))
                        val Pv = valOf (gOpt low pm [1, 2])
                        val (pn, pd) = decParts Pv
                      in
                        if pn <= 0 then NONE
                        else SOME (C.rob_reply (C.REnc (ratOf (g1 low tk), ratP (pn, pd), ratP (toM (decParts dv) du))))
                      end
                  | _ => NONE
                end
              else
                (case (search (NR1 ^ "\\s*rpm\\b") low,
                       search (NR1 ^ LEN ^ "\\s*(?:diameter\\s*)?wheel|\\bwheel\\s*(?:diameter\\s*)?(?:of|is|=)?\\s*" ^ NR1 ^ LEN ^ "|\\bdiameter\\s*(?:of|is|=)?\\s*" ^ NR1 ^ LEN) low) of
                   (SOME rm, SOME d) =>
                     if has "\\bwheel\\b" low andalso has "\\bspeed\\b|\\bhow fast\\b|\\bvelocity\\b|\\bm/s\\b" low then
                       let
                         val (dv, du) = case grp low d 1 of SOME v => (v, valOf (grp low d 2))
                                        | NONE => (case grp low d 3 of SOME v => (v, valOf (grp low d 4)) | NONE => (valOf (grp low d 5), valOf (grp low d 6)))
                       in SOME (C.rob_reply (C.RWheel (ratOf (g1 low rm), ratP (toM (decParts dv) du)))) end
                     else NONE
                 | _ => NONE)
          in
            case r of
              SOME rr => if not (C.answered rr) andalso not (has "\\d" t) then NONE else SOME rr
            | NONE => NONE
          end
      end


  (* ================= sql ================= *)
  exception LexFail

  fun lexSql (s : string) : C.tok list =
    let
      val n = size s
      fun ch i = String.sub (s, i)
      fun isId c = Char.isAlphaNum c orelse c = #"_"
      fun spanWhile p i = if i < n andalso p (ch i) then spanWhile p (i + 1) else i
      fun go i acc =
        if i >= n then rev acc
        else
          let val c = ch i in
            if Char.isSpace c then go (i + 1) acc
            else if Char.isAlpha c orelse c = #"_" then
              let val j = spanWhile isId i
                  val w = String.substring (s, i, j - i)
              in go j (C.TW (String.map Char.toUpper w, w) :: acc) end
            else if Char.isDigit c then
              let
                val j = spanWhile Char.isDigit i
                val (j2, frac) = if j < n andalso ch j = #"." then (spanWhile Char.isDigit (j + 1), true) else (j, false)
                val (j3, ex) =
                  if j2 < n andalso (ch j2 = #"e" orelse ch j2 = #"E") then
                    let val k = if j2 + 1 < n andalso (ch (j2 + 1) = #"+" orelse ch (j2 + 1) = #"-") then j2 + 2 else j2 + 1
                        val k2 = spanWhile Char.isDigit k
                    in if k2 > k then (k2, true) else (j2, false) end
                  else (j2, false)
                val txt = String.substring (s, i, j3 - i)
              in
                if not frac andalso not ex then go j3 (C.TI (C.Int_of_integer (valOf (IntInf.fromString txt))) :: acc)
                else
                  let
                    val (mant, e) = case String.fields (fn c => c = #"e" orelse c = #"E") txt of
                                      [a] => (a, 0) | [a, b] => (a, valOf (Int.fromString (String.translate (fn #"+" => "" | c => String.str c) b))) | _ => raise LexFail
                    val mant' = if String.isSuffix "." mant then mant ^ "0" else mant
                    val (nn, dd) = decParts mant'
                    val (nn2, dd2) = if e >= 0 then (nn * IntInf.pow (10, e), dd) else (nn, dd * IntInf.pow (10, ~e))
                  in go j3 (C.TR (ratP (nn2, dd2)) :: acc) end
              end
            else if c = #"'" then
              let
                fun str j buf =
                  if j >= n then raise LexFail
                  else if ch j = #"'" then
                    (if j + 1 < n andalso ch (j + 1) = #"'" then str (j + 2) (#"'" :: buf) else (j + 1, String.implode (rev buf)))
                  else str (j + 1) (ch j :: buf)
                val (j, lit) = str (i + 1) []
              in go j (C.TS lit :: acc) end
            else if c = #"\"" orelse c = #"`" orelse c = #"[" orelse c = #"?" orelse c = #":" orelse c = #"@" orelse c = #"$" then raise LexFail
            else
              let val two = if i + 1 < n then String.substring (s, i, 2) else ""
              in
                if List.exists (fn x => x = two) ["<=", ">=", "<>", "!=", "==", "||", "<<", ">>"] then go (i + 2) (C.TP two :: acc)
                else if Char.contains "(),*=<>+-/;.%&|~" c then go (i + 1) (C.TP (String.str c) :: acc)
                else raise LexFail
              end
          end
    in go 0 [] end

  fun flat s = String.map (fn #"\n" => #" " | #"\r" => #" " | c => c) s

  fun sql text =
    let
      val t = flat text
      val low = lower t
      val sqlDash = "(?:\226\128\148|\226\128\147|-)"
    in
      if size t > 20000 then NONE
      else if has "\\bvalid (?:sql|sqlite|query)\\b|\\bis this (?:sql|query) valid\\b|\\bsyntax(?:ly)? (?:correct|valid)\\b|\\bwill this (?:sql|query) (?:run|parse)\\b" low then
        let
          val body = case search "`([^`]+)`" t of
                       SOME m => SOME (g1 t m)
                     | NONE => Option.map (fn m => g1 t m) (search ":\\s*(.+?)\\s*\\??$" t)
        in
          case body of
            NONE => NONE
          | SOME b0 =>
              let
                fun rstrip s = if size s > 0 andalso (String.sub (s, size s - 1) = #"?" orelse Char.isSpace (String.sub (s, size s - 1))) then rstrip (String.substring (s, 0, size s - 1)) else s
                val b = rstrip b0
              in
                (case (SOME (lexSql b) handle LexFail => NONE) of
                   NONE => NONE
                 | SOME toks =>
                     let val r = C.validity_reply (C.sql_validity toks)
                     in if C.answered r then SOME r else NONE end)
              end
        end
      else
        let
          val qre = "\\b((?:select|with)\\b.*?)(?=;|`|\\?\\s*$|\\?\\s+\\w|\\s+" ^ sqlDash ^ "\\s|\\s+(?:return|returns|give|gives|produce|produces|output|outputs|yield|yields)\\b|$)"
          val qs = findall qre low
        in
          case List.rev qs of
            [] => NONE
          | q :: _ =>
              if not (has "\\breturn|\\bresult|\\boutput|\\bgive|\\bproduce|\\byield|\\bwhat does\\b|\\bwhat is\\b|\\bwhat's\\b" low) then NONE
              else
                let
                  val query = String.substring (t, startOf q, stopOf q - startOf q)
                  val qlow = lower query
                  val qstart = startOf q
                in
                  if not (has "\\bfrom\\b" qlow) andalso not (has "^(?:with\\b.*\\bselect|select)\\s+(?:[\\d'\"(+-]|\\w+\\s*\\()" qlow) then NONE
                  else
                    (let
                      val stmts = findall "\\b(create\\s+table\\b.*?;|insert\\s+into\\b.*?;)" low
                      val setup = List.filter (fn m =>
                          let val txt = String.substring (low, startOf m, stopOf m - startOf m)
                              fun find i = if i + size txt > size low then size low
                                           else if String.substring (low, i, size txt) = txt then i else find (i + 1)
                          in find 0 < qstart end) stmts
                      val setupToks = map (fn m => lexSql (String.substring (t, startOf m, stopOf m - startOf m))) setup
                      val qtoks = lexSql query
                      val r = C.sql_answer setupToks qtoks
                    in if C.reply_kind r = "unsupported" then NONE else SOME r end
                    handle LexFail => NONE)
                end
        end
    end

  (* ================= dispatch ================= *)
  val organs = ["networking", "embedded", "cyber", "linux-v2", "git", "sql", "python", "python-r2", "robotics-v2"]

  fun runOrgan id text =
    case id of
      "networking" => networking text
    | "embedded" => embedded text
    | "cyber" => cyber text
    | "linux-v2" => linuxV2 text
    | "git" => git text
    | "sql" => sql text
    | "python" => python text
    | "python-r2" => python text
    | "robotics-v2" => robotics text
    | _ => NONE

  (* family order when no specialist is named: the most specific cue first *)
  val familyOrder = ["sql", "python", "networking", "cyber", "embedded", "linux-v2", "robotics-v2", "git"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (o1 :: rest) = (case runOrgan o1 text of SOME r => SOME (o1, r) | NONE => go rest)
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (runOrgan mode text)
end
