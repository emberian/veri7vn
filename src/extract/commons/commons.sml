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
   Text is matched byte by byte; \w and \d are ASCII-only (Python's are
   Unicode-aware, which differs only for non-ASCII letters and digits). *)
structure Regex :
sig
  type regex
  type match = {start : int, stop : int, groups : (int * int) option vector}
  val compile : string -> regex
  val search : regex -> string -> match option
  val searchFrom : regex -> string -> int -> match option
  val findall : regex -> string -> match list
  val group : string -> match -> int -> string option
  val whole : string -> match -> string
end =
struct
  datatype node =
      Lit of char
    | Any
    | Cls of bool * (char -> bool)          (* negated, member *)
    | Grp of int option * node list list    (* capture index, alternatives *)
    | Look of bool * node list list         (* positive?, alternatives *)
    | Behind of bool * node list list       (* positive?, alternatives *)
    | WordB
    | NotWordB
    | Bol
    | Eol
    | Rep of node * int * int option * bool (* node, min, max, greedy *)

  type regex = {alts : node list list, ngroups : int}
  type match = {start : int, stop : int, groups : (int * int) option vector}

  fun isWord c = Char.isAlphaNum c orelse c = #"_"
  fun isSpace c = c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r"
                  orelse c = #"\f" orelse c = #"\v"

  exception Bad of string

  fun compile (p : string) : regex =
    let
      val n = size p
      val count = ref 0
      fun peek i = if i < n then SOME (String.sub (p, i)) else NONE
      fun escClass c =
        case c of
          #"d" => SOME Char.isDigit
        | #"s" => SOME isSpace
        | #"w" => SOME isWord
        | #"D" => SOME (not o Char.isDigit)
        | #"S" => SOME (not o isSpace)
        | #"W" => SOME (not o isWord)
        | _ => NONE
      val lc = Char.toLower
      fun parseAlt i =
        let val (s, i) = parseSeq i []
        in case peek i of
             SOME #"|" => let val (rest, j) = parseAlt (i + 1) in (s :: rest, j) end
           | _ => ([s], i)
        end
      and parseSeq i acc =
        case peek i of
          NONE => (rev acc, i)
        | SOME #"|" => (rev acc, i)
        | SOME #")" => (rev acc, i)
        | SOME _ =>
            let val (a, i) = parseAtom i
                val (a, i) = parseQuant a i
            in parseSeq i (a :: acc) end
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
      and parseAtom i =
        case String.sub (p, i) of
          #"(" =>
            if peek (i + 1) = SOME #"?" then
              (case peek (i + 2) of
                 SOME #":" => group NONE (i + 3)
               | SOME #"!" => look false (i + 3)
               | SOME #"=" => look true (i + 3)
               | SOME #"<" =>
                   (case peek (i + 3) of
                      SOME #"=" => behind true (i + 4)
                    | SOME #"!" => behind false (i + 4)
                    | _ => raise Bad ("unsupported group in " ^ p))
               | _ => raise Bad ("unsupported group in " ^ p))
            else (count := !count + 1; group (SOME (!count)) (i + 1))
        | #"[" => parseClass (i + 1)
        | #"." => (Any, i + 1)
        | #"^" => (Bol, i + 1)
        | #"$" => (Eol, i + 1)
        | #"\\" =>
            let val c = String.sub (p, i + 1)
            in if c = #"b" then (WordB, i + 2)
               else if c = #"B" then (NotWordB, i + 2)
               else case escClass c of
                      SOME f => (Cls (false, f), i + 2)
                    | NONE => (Lit (lc c), i + 2)
            end
        | c => (Lit (lc c), i + 1)
      and group idx i =
        let val (alts, j) = parseAlt i
        in if peek j = SOME #")" then (Grp (idx, alts), j + 1)
           else raise Bad ("unclosed group in " ^ p)
        end
      and look pos i =
        let val (alts, j) = parseAlt i
        in if peek j = SOME #")" then (Look (pos, alts), j + 1)
           else raise Bad ("unclosed lookahead in " ^ p)
        end
      and behind pos i =
        let val (alts, j) = parseAlt i
        in if peek j = SOME #")" then (Behind (pos, alts), j + 1)
           else raise Bad ("unclosed lookbehind in " ^ p)
        end
      and parseClass i =
        let
          val (neg, i) = if peek i = SOME #"^" then (true, i + 1) else (false, i)
          fun item i =
            case String.sub (p, i) of
              #"\\" =>
                let val c = String.sub (p, i + 1)
                in case escClass c of
                     SOME f => (f, i + 2)
                   | NONE => (let val c = lc c in fn x => x = c end, i + 2)
                end
            | c0 =>
                let val c = lc c0 in
                if peek (i + 1) = SOME #"-" andalso peek (i + 2) <> SOME #"]"
                   andalso peek (i + 2) <> NONE
                then let val d = lc (String.sub (p, i + 2))
                     in (fn x => c <= x andalso x <= d, i + 3) end
                else (fn x => x = c, i + 1)
                end
          fun loop i fs first =
            if not first andalso peek i = SOME #"]" then (fs, i + 1)
            else if peek i = NONE then raise Bad ("unclosed class in " ^ p)
            else let val (f, j) = item i in loop j (f :: fs) false end
          val (fs, j) = loop i [] true
        in (Cls (neg, fn c => List.exists (fn f => f c) fs), j) end
      val (alts, j) = parseAlt 0
    in
      if j <> n then raise Bad ("trailing input in " ^ p) else {alts = alts, ngroups = !count}
    end

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
          Lit c => i < n andalso String.sub (s, i) = c andalso k (i + 1, caps)
        | Any => i < n andalso String.sub (s, i) <> #"\n" andalso k (i + 1, caps)
        | Cls (neg, f) => i < n andalso (f (String.sub (s, i)) <> neg) andalso k (i + 1, caps)
        | WordB => (wordAt (i - 1) <> wordAt i) andalso k (i, caps)
        | NotWordB => (wordAt (i - 1) = wordAt i) andalso k (i, caps)
        | Bol => i = 0 andalso k (i, caps)
        | Eol => (i = n orelse (i = n - 1 andalso String.sub (s, i) = #"\n")) andalso k (i, caps)
        | Behind (pos, alts) =>
            let
              fun from j = j <= i andalso (mAlts alts j caps (fn (e, _) => e = i) orelse from (j + 1))
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

  fun searchFrom re s from =
    let fun go i = if i > size s then NONE
                   else case matchAt re s i of SOME m => SOME m | NONE => go (i + 1)
    in go from end

  fun search re s = searchFrom re s 0

  fun findall re s =
    let fun go i acc =
          case searchFrom re s i of
            NONE => rev acc
          | SOME (m as {start, stop, ...}) =>
              go (if stop = start then stop + 1 else stop) (m :: acc)
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
