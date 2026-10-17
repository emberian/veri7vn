(* Untrusted driver for the codeorgan prototype (scout code-organ).
   Everything trusted lives in the generated structure Codeorgan: the move
   table, the candidate-type function and the self test. This file only
   parses command lines, prints tables and renders answers.

   Modes:
     codeorgan --self
     codeorgan --table
     codeorgan --check <ty,ty,...> '<s-expression>'
   where an s-expression is (arg N) | (const K) | (app move child ...),
   e.g. --check list '(app at (app sorted_desc (arg 0)) (const 1))'
   prints the candidate output types, or REJECT when the composition rule
   would never form that program. *)

structure CO = Codeorgan

exception Usage of string

fun find_prim name =
  let
    fun go [] = raise Usage ("unknown move: " ^ name)
      | go (p :: ps) = if CO.nameOf p = name then p else go ps
  in go CO.all_prims end

val tys_table =
  [("bool", CO.TBool), ("int", CO.TInt), ("float", CO.TFloat),
   ("str", CO.TStr), ("list", CO.TList), ("tuple", CO.TTuple),
   ("dict", CO.TDict), ("set", CO.TSet), ("any", CO.TAny)]

fun ty_of_name n =
  case List.find (fn (m, _) => m = n) tys_table of
    SOME (_, t) => t
  | NONE => raise Usage ("unknown type: " ^ n)

fun tokenize s =
  String.tokens Char.isSpace
    (String.translate (fn #"(" => " ( " | #")" => " ) " | c => str c) s)

fun parse toks =
  case toks of
    "(" :: "arg" :: n :: ")" :: rest =>
      (CO.Arg (CO.nat_of_integer
         (Option.valOf (IntInf.fromString n) handle Option => raise Usage "bad arg index")),
       rest)
  | "(" :: "const" :: k :: ")" :: rest =>
      (CO.Konst (CO.Int_of_integer
         (Option.valOf (IntInf.fromString k) handle Option => raise Usage "bad const")),
       rest)
  | "(" :: "app" :: name :: rest =>
      let
        val p = find_prim name
        fun kids (acc, ")" :: rest') = (rev acc, rest')
          | kids (acc, []) = raise Usage "unbalanced application"
          | kids (acc, t) =
              let val (u, rest') = parse t in kids (u :: acc, rest') end
        val (ts, rest'') = kids ([], rest)
      in (CO.App (p, ts), rest'') end
  | _ => raise Usage "bad program"

fun parse_prog s =
  let val (u, rest) = parse (tokenize s) in
    if null rest then u else raise Usage "trailing tokens"
  end

fun comma f xs = String.concatWith "," (map f xs)

fun run_table () =
  (print ("group|num|" ^ comma CO.tyName CO.num_tys ^ "\n");
   print ("group|seq|" ^ comma CO.tyName CO.seq_tys ^ "\n");
   print ("group|coll|" ^ comma CO.tyName CO.coll_tys ^ "\n");
   print ("group|any|" ^ comma CO.tyName CO.any_tys ^ "\n");
   List.app
     (fn p => print ("prim|" ^ CO.nameOf p ^ "|"
                     ^ String.concatWith ";" (map CO.slotName (CO.insOf p)) ^ "|"
                     ^ comma CO.tyName (CO.outsOf p) ^ "\n"))
     CO.all_prims)

fun run_check tys_s prog_s =
  let
    val ts = map ty_of_name (String.tokens (fn c => c = #",") tys_s)
    val u = parse_prog prog_s
    val out = CO.tys (CO.sig_of ts) u
  in
    if null out then print "REJECT\n"
    else print ("OK " ^ comma CO.tyName out ^ "\n")
  end

fun main () =
  case CommandLine.arguments () of
    ["--self"] =>
      (print (if CO.self_test then "self_test PASS\n" else "self_test FAIL\n");
       if CO.self_test then () else OS.Process.exit OS.Process.failure)
  | ["--table"] => run_table ()
  | ["--check", t, p] => run_check t p
  | _ => raise Usage "usage: codeorgan --self | --table | --check <ty,...> <prog>"

val () = main () handle Usage m => (print ("error: " ^ m ^ "\n");
                                    OS.Process.exit OS.Process.failure)
