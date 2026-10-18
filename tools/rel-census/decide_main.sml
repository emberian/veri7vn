(* decide_main.sml - UNTRUSTED I/O around the exported organ decision (Relation_Organ_Code, generated
   by src/isabelle/relorgan/Relation_Organ_Export.thy). One JSON turn per stdin line, one JSON
   decision per stdout line. The JSON reader/writer below is hand-rolled and is not verified; the
   decision (organ_decide) is.

   Turn shape (built by tools/rel-census/organ_answerer.py):
     {"id": ..., "kind_conflict": b, "past": b, "qwords": [s], "value_words": [[s,[s]]],
      "dropped": [[k,"fwd"|"inv",n]], "props": [[k,n]], "time_variant": [n],
      "feats": [[s,s]], "patterns": [[["fwd"|"inv",s,s],n]], "pats": [[["fwd"|"inv",n],s]],
      "pat_cands": [{qid,links,indomain,complete,rows}], "pat_inv": [[["inv",n],[[n,b,s],b]]],
      "pronoun_guard": b, "pron_subj": [[n,s,b,b]],
      "attempts": [{key,idx,dir,pat,slot_len,cands:[...],inv_subs:[[n,b,s]],inv_capped:b}]}
   where rows are [[prop, display]]. *)

structure Json = struct
  datatype t = Null | Bool of bool | Num of IntInf.int | Str of string | Arr of t list | Obj of (string * t) list
  exception Bad of string

  fun utf8 (cp : int) : string =
    let fun ch n = String.str (Char.chr n) in
      if cp < 0x80 then ch cp
      else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
      else if cp < 0x10000 then ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
      else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64) ^ ch (0x80 + (cp div 64) mod 64)
           ^ ch (0x80 + cp mod 64)
    end

  fun parse (s : string) : t =
    let
      val n = String.size s
      fun peek i = if i < n then String.sub (s, i) else #"\000"
      fun ws i = if i < n andalso Char.isSpace (String.sub (s, i)) then ws (i + 1) else i
      fun expect (c, i) = if peek i = c then i + 1 else raise Bad ("expected " ^ String.str c)
      fun hex4 i =
        case (if i + 4 <= n then StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) else NONE)
          of SOME v => v | NONE => raise Bad "bad \\u escape"
      fun str (i, acc) =
        case peek i of
          #"\"" => (String.concat (rev acc), i + 1)
        | #"\\" =>
            (case peek (i + 1) of
               #"\"" => str (i + 2, "\"" :: acc) | #"\\" => str (i + 2, "\\" :: acc)
             | #"/" => str (i + 2, "/" :: acc) | #"b" => str (i + 2, "\b" :: acc)
             | #"f" => str (i + 2, "\012" :: acc) | #"n" => str (i + 2, "\n" :: acc)
             | #"r" => str (i + 2, "\r" :: acc) | #"t" => str (i + 2, "\t" :: acc)
             | #"u" =>
                 let val hi = hex4 (i + 2) in
                   if hi >= 0xD800 andalso hi < 0xDC00 andalso peek (i + 6) = #"\\" andalso peek (i + 7) = #"u"
                   then let val lo = hex4 (i + 8)
                        in str (i + 12, utf8 (0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)) :: acc) end
                   else str (i + 6, utf8 hi :: acc)
                 end
             | _ => raise Bad "bad escape")
        | #"\000" => raise Bad "unterminated string"
        | c => str (i + 1, String.str c :: acc)
      fun num i =
        let fun go j = if Char.isDigit (peek j) orelse (j = i andalso peek j = #"-") then go (j + 1) else j
            val j = go i
        in case IntInf.fromString (String.substring (s, i, j - i)) of
             SOME v => (Num v, j) | NONE => raise Bad "bad number"
        end
      fun value i =
        let val i = ws i in
          case peek i of
            #"{" => obj (ws (i + 1), [])
          | #"[" => arr (ws (i + 1), [])
          | #"\"" => let val (v, j) = str (i + 1, []) in (Str v, j) end
          | #"t" => if String.isPrefix "true" (String.extract (s, i, NONE)) then (Bool true, i + 4) else raise Bad "t"
          | #"f" => if String.isPrefix "false" (String.extract (s, i, NONE)) then (Bool false, i + 5) else raise Bad "f"
          | #"n" => if String.isPrefix "null" (String.extract (s, i, NONE)) then (Null, i + 4) else raise Bad "n"
          | _ => num i
        end
      and arr (i, acc) =
        if peek i = #"]" then (Arr (rev acc), i + 1)
        else let val (v, j) = value i val j = ws j in
          case peek j of #"," => arr (ws (j + 1), v :: acc) | #"]" => (Arr (rev (v :: acc)), j + 1)
                       | _ => raise Bad "array" end
      and obj (i, acc) =
        if peek i = #"}" then (Obj (rev acc), i + 1)
        else let val (k, j) = str (expect (#"\"", i), []) val j = expect (#":", ws j)
                 val (v, j) = value j val j = ws j in
          case peek j of #"," => obj (ws (j + 1), (k, v) :: acc) | #"}" => (Obj (rev ((k, v) :: acc)), j + 1)
                       | _ => raise Bad "object" end
      val (v, j) = value 0
    in if ws j = n then v else raise Bad "trailing input" end

  fun quote (s : string) : string =
    let fun esc c =
          case c of #"\"" => "\\\"" | #"\\" => "\\\\" | #"\n" => "\\n" | #"\r" => "\\r" | #"\t" => "\\t"
          | c => if Char.ord c < 0x20 then "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
                 else String.str c
    in "\"" ^ String.translate esc s ^ "\"" end

  fun field (Obj kvs) k = (case List.find (fn (k', _) => k' = k) kvs of SOME (_, v) => v | NONE => Null)
    | field _ _ = Null
  fun bool v = case v of Bool b => b | _ => raise Bad "bool"
  fun int v = case v of Num i => i | _ => raise Bad "int"
  fun string v = case v of Str x => x | _ => raise Bad "string"
  fun list v = case v of Arr xs => xs | Null => [] | _ => raise Bad "list"
  fun show v =
    case v of Null => "null" | Bool b => (if b then "true" else "false") | Num i => IntInf.toString i
    | Str x => quote x | Arr xs => "[" ^ String.concatWith "," (map show xs) ^ "]"
    | Obj kvs => "{" ^ String.concatWith "," (map (fn (k, x) => quote k ^ ":" ^ show x) kvs) ^ "}"
end

structure Main = struct
  structure R = Relation_Organ_Code
  open Json

  val nat = R.natural_of_integer
  fun unnat n = Num (R.integer_of_natural n)

  fun row r = case list r of [p, Str s] => (nat (int p), s) | _ => raise Bad "row"
  fun cand c =
    R.Cand_ext (nat (int (field c "qid")), nat (int (field c "links")), bool (field c "indomain"),
                bool (field c "complete"), map row (list (field c "rows")), ())
  fun dir v = case string v of "fwd" => R.Fwd | "inv" => R.Inv | _ => raise Bad "dir"
  fun dirS d = case d of R.Fwd => "fwd" | R.Inv => "inv"
  fun sub v = case list v of [Num q, b, Str l] => (nat q, bool b, l) | _ => raise Bad "inv_sub"
  fun drop v = case list v of [Str k, d, Num i] => (k, dir d, nat i) | _ => raise Bad "dropped"
  fun prop v = case list v of [Str k, Num p] => (k, nat p) | _ => raise Bad "props"
  fun feat v = case list v of [Str a, Str b] => (a, b) | _ => raise Bad "feat"
  fun pat v = case list v of [Arr [Str d, Str a, Str b], Num p] => ((dir (Str d), a, b), nat p) | _ => raise Bad "pattern"
  fun patid v = case list v of [Arr [Str d, Num p], Str s] => ((dir (Str d), nat p), s) | _ => raise Bad "pats"
  fun vword v = case list v of [Str s, Arr ws] => (s, map string ws) | _ => raise Bad "value_words"
  fun pron v = case list v of [Num q, Str l, b1, b2] => (nat q, l, bool b1, bool b2) | _ => raise Bad "pron"
  fun patinv v =
    case list v of
      [Arr [Str d, Num p], Arr subs, Bool capped] => ((dir (Str d), nat p), (map sub subs, capped))
    | _ => raise Bad "pat_inv"

  fun attempt a =
    R.Attempt_ext (string (field a "key"), nat (int (field a "idx")), dir (field a "dir"),
                   string (field a "pat"), nat (int (field a "slot_len")),
                   map cand (list (field a "cands")), map sub (list (field a "inv_subs")),
                   bool (field a "inv_capped"), ())

  fun turn e =
    R.Turn_ext (map attempt (list (field e "attempts")), bool (field e "kind_conflict"),
                bool (field e "past"), map string (list (field e "qwords")),
                map vword (list (field e "value_words")), map drop (list (field e "dropped")),
                map prop (list (field e "props")), map nat (map int (list (field e "time_variant"))),
                map feat (list (field e "feats")), map pat (list (field e "patterns")),
                map cand (list (field e "pat_cands")), map patinv (list (field e "pat_inv")),
                map patid (list (field e "pats")), bool (field e "pronoun_guard"),
                map pron (list (field e "pron_subj")), ())

  fun showResult r =
    case r of
      R.Answered p v s pat => Obj [("outcome", Str "answered"), ("prop", unnat p), ("value", Str v),
                                   ("subject", unnat s), ("pattern", Str pat)]
    | R.Withheld p s pat => Obj [("outcome", Str "withheld"), ("prop", unnat p), ("subject", unnat s),
                                 ("pattern", Str pat)]
    | R.Silence => Obj [("outcome", Str "silent")]

  fun handle_line line =
    let
      val e = parse line
      val id = field e "id"
    in
      show (Obj [("id", id), ("decision", showResult (R.organ_decide (turn e)))])
    end
      handle Bad msg => show (Obj [("outcome", Str "error"), ("error", Str msg)])

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME l =>
        let val l = if String.isSuffix "\n" l then String.substring (l, 0, String.size l - 1) else l in
          TextIO.output (TextIO.stdOut, handle_line l ^ "\n"); TextIO.flushOut TextIO.stdOut; loop ()
        end
end

val _ = Main.loop ()
