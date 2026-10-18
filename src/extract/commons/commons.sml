(* UNTRUSTED commons: the SML every extracted family ships. Two parts.

   Regex: the backtracking regular-expression matcher covering the subset of
   Python `re` syntax the organs use, so their patterns can be carried over
   verbatim. Written by lane D (acoustics), extended by lane G (quantity) with
   ^, $, bounded repetition {m,n} and lookbehind; this is lane G's canonical
   version, a strict superset of lane D's. Twelve families already ship this
   file byte-identical as regex.sml; it lives here once.

   Json: the answerer-contract framing (docs/contracts/answerer.md) -- a
   minimal JSON reader for one request object per line and a string quoter
   for replies. Lane D's reader, unchanged in every family's main.sml.

   Three case modes (compile / compileI / compileCS), backreferences \1..\9
   (lane S12 discrete) and matchHere were folded in from the families that
   carried their own regex.sml (chemistry, humanities, facts, discrete); with
   no digit escapes and the default `compile`, behaviour is the old canonical
   engine's.

   A family's .mlb lists this file instead of its own regex.sml, and its
   main.sml keeps only the family dispatch. *)

(* UNTRUSTED. Copied from lane D (src/extract/acoustics/regex.sml) and
   extended for the quantity organs. A small backtracking regular-expression
   matcher covering the subset of Python `re` syntax the organs use, so their
   patterns can be carried over verbatim:
     literals, \. \/ and other escaped punctuation, \d \s \w \b, [...] and
     [^...] classes with ranges, (...) capturing groups numbered by opening
     parenthesis, (?:...), (?!...), (?=...), alternation |, and the quantifiers
     ? * + with optional lazy suffix ?.
   Lane G additions: ^ and $ (Python semantics without MULTILINE: $ matches at
   the end or before a final newline), bounded repetition {m}, {m,} and {m,n}
   (with lazy suffix ?), and lookbehind (?<=...) and (?<!...) (any width; the
   organs only use fixed-width ones).
   Case-insensitive matching: the caller lower-cases the TEXT and passes the
   pattern as written. compile lower-cases only literal characters and class
   members (including range ends) while parsing; escape classes keep their
   meaning (\d \D \s \S \w \W \b \B). Do not lower-case the pattern
   string first: that turns \S into \s (lane S17 fix; previously every
   caller did, so upper-case escapes silently changed meaning).
   Text and pattern are read as UTF-8 codepoints (lane W6-25): a literal
   multi-byte character matches as a unit, a [...] class may hold multi-byte
   members and ranges, `.` and negated classes consume one whole character, and
   an unanchored search only starts on character boundaries. Match positions
   (start, stop, groups) stay BYTE offsets into the string. A byte sequence that
   is not valid UTF-8 is read as one character per byte (outside every class
   range and never equal to a codepoint literal), so invalid input degrades to
   the old byte behaviour. Case folding stays ASCII-only: Lower, Fold and the
   class folding change A-Z / a-z and nothing else, so non-ASCII letters (E-acute,
   Greek, Cyrillic) are matched exactly. \w, \d, \s and \b are ASCII-only
   (Python's are Unicode-aware, which differs only for non-ASCII letters,
   digits and spaces; every non-ASCII character is a non-word, non-space). *)
structure Regex :
sig
  type regex
  type match = {start : int, stop : int, groups : (int * int) option vector}
  val compile : string -> regex
  val compileI : string -> regex
  val compileCS : string -> regex
  val matchHere : regex -> string -> int -> match option
  val search : regex -> string -> match option
  val searchFrom : regex -> string -> int -> match option
  val findall : regex -> string -> match list
  val group : string -> match -> int -> string option
  val whole : string -> match -> string
end =
struct
  datatype node =
      Lit of int                            (* a codepoint (W6-25) *)
    | Any
    | Cls of bool * (int -> bool)           (* negated, member over codepoints *)
    | Grp of int option * node list list    (* capture index, alternatives *)
    | Look of bool * node list list         (* positive?, alternatives *)
    | Behind of bool * node list list       (* positive?, alternatives *)
    | WordB
    | NotWordB
    | Bol
    | Eol
    | Back of int                           (* backreference \1..\9 (lane S12) *)
    | Rep of node * int * int option * bool (* node, min, max, greedy *)

  type regex = {alts : node list list, ngroups : int}
  type match = {start : int, stop : int, groups : (int * int) option vector}

  fun isWord c = Char.isAlphaNum c orelse c = #"_"
  fun isSpace c = c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r"
                  orelse c = #"\f" orelse c = #"\v"

  (* UTF-8 decoding (W6-25). decode s i = (codepoint, byte length). Overlong
     forms, surrogates, values above U+10FFFF and truncated sequences are
     invalid: they decode as (0x110000 + byte, 1). *)
  fun decode (s : string) (i : int) : int * int =
    let
      val n = size s
      fun b j = Char.ord (String.sub (s, j))
      fun cont j = j < n andalso b j div 64 = 2
      val c = b i
      val bad = (0x110000 + c, 1)
    in
      if c < 0x80 then (c, 1)
      else if c >= 0xC2 andalso c < 0xE0 then
        (if cont (i + 1) then ((c - 0xC0) * 64 + (b (i + 1) - 0x80), 2) else bad)
      else if c >= 0xE0 andalso c < 0xF0 then
        (if cont (i + 1) andalso cont (i + 2) then
           let val cp = (c - 0xE0) * 4096 + (b (i + 1) - 0x80) * 64 + (b (i + 2) - 0x80)
           in if cp < 0x800 orelse (cp >= 0xD800 andalso cp < 0xE000) then bad else (cp, 3) end
         else bad)
      else if c >= 0xF0 andalso c < 0xF5 then
        (if cont (i + 1) andalso cont (i + 2) andalso cont (i + 3) then
           let val cp = (c - 0xF0) * 262144 + (b (i + 1) - 0x80) * 4096
                        + (b (i + 2) - 0x80) * 64 + (b (i + 3) - 0x80)
           in if cp < 0x10000 orelse cp > 0x10FFFF then bad else (cp, 4) end
         else bad)
      else bad
    end

  (* ASCII-only helpers over codepoints *)
  fun asciiLower cp = if cp >= 65 andalso cp <= 90 then cp + 32 else cp
  fun asciiUpper cp = if cp >= 97 andalso cp <= 122 then cp - 32 else cp
  fun isAsciiAlpha cp = (cp >= 65 andalso cp <= 90) orelse (cp >= 97 andalso cp <= 122)
  fun cpDigit cp = cp >= 48 andalso cp <= 57
  fun cpSpace cp = cp < 128 andalso isSpace (Char.chr cp)
  fun cpWord cp = cp < 128 andalso isWord (Char.chr cp)

  exception Bad of string

  (* How literals and class members meet case. Lower: the caller lower-cases the
     TEXT and the pattern's literals and class members are lower-cased here (the
     shared lane D/G behaviour, `compile`). Exact: nothing is folded (`compileCS`,
     lane S07/S16: patterns matched case-sensitively against the original text).
     Fold: the text keeps its case and every alphabetic literal or class matches
     either case (`compileI`, Python re.I; lane O19 facts). *)
  datatype mode = Lower | Fold | Exact

  fun compileWith (m0 : mode) (p : string) : regex =
    let
      fun fold m f = case m of
                       Fold => (fn c => f c orelse f (asciiLower c) orelse f (asciiUpper c))
                     | _ => f
      fun lit m c = case m of
                      Lower => Lit (asciiLower c)
                    | Fold => if isAsciiAlpha c
                              then Cls (false, fn x => asciiLower x = asciiLower c)
                              else Lit c
                    | Exact => Lit c
      fun nm m c = case m of Lower => asciiLower c | _ => c
      val n = size p
      val count = ref 0
      fun peek i = if i < n then SOME (String.sub (p, i)) else NONE
      (* the codepoint at pattern index i and the index after it *)
      fun cpAt i = let val (cp, l) = decode p i in (cp, i + l) end
      fun escClass c =
        case c of
          #"d" => SOME cpDigit
        | #"s" => SOME cpSpace
        | #"w" => SOME cpWord
        | #"D" => SOME (not o cpDigit)
        | #"S" => SOME (not o cpSpace)
        | #"W" => SOME (not o cpWord)
        | _ => NONE
      fun parseAlt m i =
        let val (s, i) = parseSeq m i []
        in case peek i of
             SOME #"|" => let val (rest, j) = parseAlt m (i + 1) in (s :: rest, j) end
           | _ => ([s], i)
        end
      and parseSeq m i acc =
        case peek i of
          NONE => (rev acc, i)
        | SOME #"|" => (rev acc, i)
        | SOME #")" => (rev acc, i)
        | SOME _ =>
            let val (a, i) = parseAtom m i
                val (a, i) = parseQuant a i
            in parseSeq m i (a :: acc) end
      and parseQuant a i =
        let
          fun lazy (q, i) =
            case peek i of
              SOME #"?" => (q false, i + 1)
            | _ => (q true, i)
          fun number j acc =
            case peek j of
              SOME c => if Char.isDigit c then number (j + 1) (acc * 10 + (Char.ord c - 48))
                        else (acc, j)
            | NONE => (acc, j)
        in
          case peek i of
            SOME #"?" => lazy (fn g => Rep (a, 0, SOME 1, g), i + 1)
          | SOME #"*" => lazy (fn g => Rep (a, 0, NONE, g), i + 1)
          | SOME #"+" => lazy (fn g => Rep (a, 1, NONE, g), i + 1)
          | SOME #"{" =>
              (case peek (i + 1) of
                 SOME c =>
                   if not (Char.isDigit c) then (a, i)
                   else
                     let val (lo, j) = number (i + 1) 0
                     in case peek j of
                          SOME #"}" => lazy (fn g => Rep (a, lo, SOME lo, g), j + 1)
                        | SOME #"," =>
                            (case peek (j + 1) of
                               SOME #"}" => lazy (fn g => Rep (a, lo, NONE, g), j + 2)
                             | _ => let val (hi, k) = number (j + 1) 0
                                    in if peek k = SOME #"}" then lazy (fn g => Rep (a, lo, SOME hi, g), k + 1)
                                       else raise Bad ("bad {m,n} in " ^ p)
                                    end)
                        | _ => raise Bad ("bad {m,n} in " ^ p)
                     end
               | NONE => (a, i))
          | _ => (a, i)
        end
      and parseAtom m i =
        case String.sub (p, i) of
          #"(" =>
            if peek (i + 1) = SOME #"?" then
              (case peek (i + 2) of
                 SOME #":" => group m NONE (i + 3)
               | SOME #"!" => look m false (i + 3)
               | SOME #"=" => look m true (i + 3)
               | SOME #"-" =>
                   if peek (i + 3) = SOME #"i" andalso peek (i + 4) = SOME #":"
                   then group Exact NONE (i + 5)
                   else raise Bad ("unsupported flag group in " ^ p)
               | SOME #"<" =>
                   (case peek (i + 3) of
                      SOME #"=" => behind m true (i + 4)
                    | SOME #"!" => behind m false (i + 4)
                    | _ => raise Bad ("unsupported group in " ^ p))
               | _ => raise Bad ("unsupported group in " ^ p))
            else (count := !count + 1; group m (SOME (!count)) (i + 1))
        | #"[" => parseClass m (i + 1)
        | #"." => (Any, i + 1)
        | #"^" => (Bol, i + 1)
        | #"$" => (Eol, i + 1)
        | #"\\" =>
            let val c = String.sub (p, i + 1)
            in if Char.isDigit c andalso c <> #"0" then (Back (Char.ord c - 48), i + 2)
               else if c = #"b" then (WordB, i + 2)
               else if c = #"B" then (NotWordB, i + 2)
               else case escClass c of
                      SOME f => (Cls (false, f), i + 2)
                    | NONE => let val (cp, j) = cpAt (i + 1) in (lit m cp, j) end
            end
        | _ => let val (cp, j) = cpAt i in (lit m cp, j) end
      and group m idx i =
        let val (alts, j) = parseAlt m i
        in if peek j = SOME #")" then (Grp (idx, alts), j + 1)
           else raise Bad ("unclosed group in " ^ p)
        end
      and look m pos i =
        let val (alts, j) = parseAlt m i
        in if peek j = SOME #")" then (Look (pos, alts), j + 1)
           else raise Bad ("unclosed lookahead in " ^ p)
        end
      and behind m pos i =
        let val (alts, j) = parseAlt m i
        in if peek j = SOME #")" then (Behind (pos, alts), j + 1)
           else raise Bad ("unclosed lookbehind in " ^ p)
        end
      and parseClass m i =
        let
          val (neg, i) = if peek i = SOME #"^" then (true, i + 1) else (false, i)
          fun item i =
            case String.sub (p, i) of
              #"\\" =>
                let val c = String.sub (p, i + 1)
                in case escClass c of
                     SOME f => (f, i + 2)
                   | NONE => let val (cp, j) = cpAt (i + 1)
                                 val c = nm m cp
                             in (fn x => x = c, j) end
                end
            | _ =>
                let val (c0, j) = cpAt i
                    val c = nm m c0 in
                if peek j = SOME #"-" andalso peek (j + 1) <> SOME #"]"
                   andalso peek (j + 1) <> NONE
                then let val (d0, k) = cpAt (j + 1)
                         val d = nm m d0
                     in (fn x => c <= x andalso x <= d, k) end
                else (fn x => x = c, j)
                end
          fun loop i fs first =
            if not first andalso peek i = SOME #"]" then (fs, i + 1)
            else if peek i = NONE then raise Bad ("unclosed class in " ^ p)
            else let val (f, j) = item i in loop j (f :: fs) false end
          val (fs, j) = loop i [] true
        in (Cls (neg, fold m (fn c => List.exists (fn f => f c) fs)), j) end
      val (alts, j) = parseAlt m0 0
    in
      if j <> n then raise Bad ("trailing input in " ^ p) else {alts = alts, ngroups = !count}
    end

  val compile = compileWith Lower
  val compileI = compileWith Fold
  val compileCS = compileWith Exact

  (* Continuation-passing backtracking. Captures are a persistent list. *)
  fun matchAt ({alts, ngroups} : regex) (s : string) (start : int) : match option =
    let
      val n = size s
      fun wordAt i = i >= 0 andalso i < n andalso isWord (String.sub (s, i))
      fun mAlts alts i caps k =
        List.exists (fn seq => mSeq seq i caps k) alts
      and mSeq [] i caps k = k (i, caps)
        | mSeq (a :: rest) i caps k = mNode a i caps (fn (j, c) => mSeq rest j c k)
      and mNode node i caps k =
        case node of
          Lit c => i < n andalso (let val (cp, l) = decode s i in cp = c andalso k (i + l, caps) end)
        | Any => i < n andalso String.sub (s, i) <> #"\n"
                 andalso (let val (_, l) = decode s i in k (i + l, caps) end)
        | Cls (neg, f) => i < n andalso
                 (let val (cp, l) = decode s i in (f cp <> neg) andalso k (i + l, caps) end)
        | WordB => (wordAt (i - 1) <> wordAt i) andalso k (i, caps)
        | NotWordB => (wordAt (i - 1) = wordAt i) andalso k (i, caps)
        | Back g =>
            (case List.find (fn (h, _) => h = g) caps of
               SOME (_, (a, b)) =>
                 let val len = b - a
                 in i + len <= n andalso String.substring (s, i, len) = String.substring (s, a, len)
                    andalso k (i + len, caps) end
             | NONE => false)
        | Bol => i = 0 andalso k (i, caps)
        | Eol => (i = n orelse (i = n - 1 andalso String.sub (s, i) = #"\n")) andalso k (i, caps)
        | Behind (pos, alts) =>
            let
              fun step j = if j < n then j + #2 (decode s j) else j + 1
              fun from j = j <= i andalso (mAlts alts j caps (fn (e, _) => e = i) orelse from (step j))
              val found = from 0
            in found = pos andalso k (i, caps) end
        | Look (pos, alts) =>
            let val found = mAlts alts i caps (fn _ => true)
            in found = pos andalso k (i, caps) end
        | Grp (NONE, alts) => mAlts alts i caps k
        | Grp (SOME g, alts) => mAlts alts i caps (fn (j, c) => k (j, (g, (i, j)) :: c))
        | Rep (a, lo, hi, greedy) => mRep (a, lo, hi, greedy) i caps 0 k
      and mRep (r as (a, lo, hi, greedy)) i caps cnt k =
        let
          fun more () =
            (case hi of SOME h => cnt < h | NONE => true) andalso
            mNode a i caps (fn (j, c) => j <> i andalso mRep r j c (cnt + 1) k)
          fun stop () = cnt >= lo andalso k (i, caps)
        in if greedy then more () orelse stop () else stop () orelse more () end
      val result = ref NONE
      fun finish (j, caps) =
        let
          fun lookup g = case List.find (fn (h, _) => h = g) caps of
                           SOME (_, span) => SOME span | NONE => NONE
        in result := SOME {start = start, stop = j,
                           groups = Vector.tabulate (ngroups + 1,
                             fn 0 => SOME (start, j) | g => lookup g)};
           true
        end
    in
      if mAlts alts start [] finish then !result else NONE
    end

  (* the index after the character at i (one past the end when i is the end) *)
  fun nextPos s i = if i < size s then i + #2 (decode s i) else i + 1

  fun matchHere re s pos = matchAt re s pos

  fun searchFrom re s from =
    let fun go i = if i > size s then NONE
                   else case matchAt re s i of SOME m => SOME m | NONE => go (nextPos s i)
    in go from end

  fun search re s = searchFrom re s 0

  fun findall re s =
    let fun go i acc =
          case searchFrom re s i of
            NONE => rev acc
          | SOME (m as {start, stop, ...}) =>
              go (if stop = start then nextPos s stop else stop) (m :: acc)
    in go 0 [] end

  fun group s ({groups, ...} : match) g =
    if g < Vector.length groups then
      Option.map (fn (a, b) => String.substring (s, a, b - a)) (Vector.sub (groups, g))
    else NONE

  fun whole s ({start, stop, ...} : match) = String.substring (s, start, stop - start)
end

structure Json =
struct
  exception Parse of string

  (* Skip whitespace *)
  fun ws s i = if i < size s andalso Char.isSpace (String.sub (s, i)) then ws s (i + 1) else i

  fun utf8 (cp : int) : string =
    let fun ch x = String.str (Char.chr x)
    in if cp < 0x80 then ch cp
       else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
       else if cp < 0x10000 then
         ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
       else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64)
            ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
    end

  fun hex4 s i =
    case StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) of
      SOME v => v
    | NONE => raise Parse "bad \\u escape"

  (* Parse a string starting at the opening quote; return (decoded, next index) *)
  fun str s i =
    let
      fun go j acc =
        if j >= size s then raise Parse "unterminated string"
        else case String.sub (s, j) of
          #"\"" => (String.concat (rev acc), j + 1)
        | #"\\" =>
            (case String.sub (s, j + 1) of
               #"\"" => go (j + 2) ("\"" :: acc)
             | #"\\" => go (j + 2) ("\\" :: acc)
             | #"/" => go (j + 2) ("/" :: acc)
             | #"b" => go (j + 2) ("\b" :: acc)
             | #"f" => go (j + 2) ("\f" :: acc)
             | #"n" => go (j + 2) ("\n" :: acc)
             | #"r" => go (j + 2) ("\r" :: acc)
             | #"t" => go (j + 2) ("\t" :: acc)
             | #"u" =>
                 let val hi = hex4 s (j + 2)
                 in if hi >= 0xD800 andalso hi < 0xDC00 andalso j + 11 < size s
                       andalso String.sub (s, j + 6) = #"\\" andalso String.sub (s, j + 7) = #"u"
                    then let val lo = hex4 s (j + 8)
                         in go (j + 12) (utf8 (0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)) :: acc) end
                    else go (j + 6) (utf8 hi :: acc)
                 end
             | _ => raise Parse "bad escape")
        | c => go (j + 1) (String.str c :: acc)
    in go (i + 1) [] end

  (* Skip any JSON value; return the index after it *)
  fun skip s i =
    let val i = ws s i
    in if i >= size s then raise Parse "unexpected end"
       else case String.sub (s, i) of
         #"\"" => #2 (str s i)
       | #"{" => members s (ws s (i + 1)) (fn _ => ())
       | #"[" =>
           let fun elems j =
                 let val j = ws s j
                 in if String.sub (s, j) = #"]" then j + 1
                    else let val k = ws s (skip s j)
                         in case String.sub (s, k) of
                              #"," => elems (k + 1)
                            | #"]" => k + 1
                            | _ => raise Parse "bad array"
                         end
                 end
           in elems (i + 1) end
       | _ =>
           let fun scalar j = if j < size s andalso not (Char.contains ",}] \t\r\n" (String.sub (s, j)))
                              then scalar (j + 1) else j
           in scalar i end
    end
  (* Object members from index i (just after '{'); f receives (key, valueStart, valueEnd) *)
  and members s i f =
    if String.sub (s, i) = #"}" then i + 1
    else
      let
        val (key, j) = str s (ws s i)
        val j = ws s j
        val _ = if String.sub (s, j) = #":" then () else raise Parse "expected :"
        val vstart = ws s (j + 1)
        val vend = skip s vstart
        val _ = f (key, vstart, vend)
        val k = ws s vend
      in
        case String.sub (s, k) of
          #"," => members s (ws s (k + 1)) f
        | #"}" => k + 1
        | _ => raise Parse "expected , or }"
      end

  (* The top-level object's fields as (key, raw value text) *)
  fun fields (line : string) : (string * string) list =
    let
      val i = ws line 0
      val _ = if i < size line andalso String.sub (line, i) = #"{" then () else raise Parse "not an object"
      val acc = ref []
      val _ = members line (ws line (i + 1))
                (fn (k, a, b) => acc := (k, String.substring (line, a, b - a)) :: !acc)
    in rev (!acc) end

  fun stringValue raw =
    if size raw > 0 andalso String.sub (raw, 0) = #"\"" then #1 (str raw 0)
    else raise Parse "expected a string"

  fun quote (s : string) : string =
    let
      fun esc c =
        case c of
          #"\"" => "\\\""
        | #"\\" => "\\\\"
        | #"\n" => "\\n"
        | #"\r" => "\\r"
        | #"\t" => "\\t"
        | c => if Char.ord c < 0x20 then
                 "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
               else String.str c
    in "\"" ^ String.translate esc s ^ "\"" end
end
