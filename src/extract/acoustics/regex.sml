(* UNTRUSTED. A small backtracking regular-expression matcher covering the
   subset of Python `re` syntax that organ_acoustics_v1.py uses, so the organ's
   patterns can be carried over verbatim:
     literals, \. \/ and other escaped punctuation, \d \s \w \b, [...] and
     [^...] classes with ranges, (...) capturing groups numbered by opening
     parenthesis, (?:...), (?!...), (?=...), alternation |, and the quantifiers
     ? * + with optional lazy suffix ?.
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
    | WordB
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
        | _ => NONE
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
        in
          case peek i of
            SOME #"?" => lazy (fn g => Rep (a, 0, SOME 1, g), i + 1)
          | SOME #"*" => lazy (fn g => Rep (a, 0, NONE, g), i + 1)
          | SOME #"+" => lazy (fn g => Rep (a, 1, NONE, g), i + 1)
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
               | _ => raise Bad ("unsupported group in " ^ p))
            else (count := !count + 1; group (SOME (!count)) (i + 1))
        | #"[" => parseClass (i + 1)
        | #"." => (Any, i + 1)
        | #"\\" =>
            let val c = String.sub (p, i + 1)
            in if c = #"b" then (WordB, i + 2)
               else case escClass c of
                      SOME f => (Cls (false, f), i + 2)
                    | NONE => (Lit c, i + 2)
            end
        | c => (Lit c, i + 1)
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
      and parseClass i =
        let
          val (neg, i) = if peek i = SOME #"^" then (true, i + 1) else (false, i)
          fun item i =
            case String.sub (p, i) of
              #"\\" =>
                let val c = String.sub (p, i + 1)
                in case escClass c of
                     SOME f => (f, i + 2)
                   | NONE => (fn x => x = c, i + 2)
                end
            | c =>
                if peek (i + 1) = SOME #"-" andalso peek (i + 2) <> SOME #"]"
                   andalso peek (i + 2) <> NONE
                then let val d = String.sub (p, i + 2)
                     in (fn x => c <= x andalso x <= d, i + 3) end
                else (fn x => x = c, i + 1)
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
