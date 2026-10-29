(* UNTRUSTED bounded resident adapter; framing, scope classification and stable
   occurrence-ID projection are not HOL theorems. Every accepted candidate goes
   to external_mst_cert with the complete declared vertex list. No search here.
   Malformed/oversized/unterminated frames terminate the worker; good requests,
   including rejected and unsupported graphs, retain it until EOF. *)
structure CertificateMain =
struct
  exception BadInput
  val maxBytes = 65536
  fun need b = if b then () else raise BadInput
  (* inputLine would allocate an unbounded hostile line before checking it. *)
  fun line () =
    let fun read (n, chars) =
      case TextIO.input1 TextIO.stdIn of
          NONE => if n = 0 then NONE else raise BadInput
        | SOME c =>
            if n >= maxBytes then raise BadInput
            else if c = #"\n" then SOME (String.implode (rev chars))
            else read (n + 1, c :: chars)
    in read (0, []) end
  fun integer s =
    let val n = case IntInf.fromString s of SOME x => x | NONE => raise BadInput
        val canonical = if n < 0 then "-" ^ IntInf.toString (~n) else IntInf.toString n
    in need (s = canonical); n end
  fun small s =
    let val n = integer s
    in need (0 <= n andalso n <= 1000000); IntInf.toInt n end
  fun unique [] = true
    | unique (x::xs) = not (List.exists (fn y => x = y) xs) andalso unique xs
  fun run text =
    let
      val fields = String.tokens (fn c => c = #" ") text
      (* One canonical space between tokens; no tabs, CR or extra whitespace. *)
      val _ = need (String.concatWith " " fields = text)
      val (requestId, n, m, k, rest) = case fields of
          "mst-cert-v2" :: i :: a :: b :: c :: tail =>
            let val id = integer i
                val _ = need (0 <= id andalso id < IntInf.pow (2, 64))
            in (i, small a, small b, small c, tail) end
        | _ => raise BadInput
      val _ = need (n <= 64 andalso m <= 256 andalso k <= Int.max (n - 1, 0))
      fun edges 0 tail acc = (rev acc, tail)
        | edges count (a::b::w::tail) acc =
            let val u = small a val v = small b val z = integer w
                val _ = need (u < n andalso v < n andalso
                  ~(IntInf.pow (2, 63)) <= z andalso z < IntInf.pow (2, 63))
            in edges (count - 1) tail ((u,v,z)::acc) end
        | edges _ _ _ = raise BadInput
      val (rows, candidates) = edges m rest []
      val ids = map small candidates
      val _ = need (length ids = k andalso unique ids andalso List.all (fn i => i < m) ids)
      val es = map (fn (u,v,z) =>
        (Int.toString u, (Int.toString v, MstCertificate.mk_rat z 1))) rows
      val ev = Vector.fromList es
      val tree = map (fn id => Vector.sub (ev, id)) ids
      val vs = List.tabulate (n, Int.toString)
      (* Classification never establishes acceptance. The predicate below does. *)
      val parent = Array.tabulate (n, fn i => i)
      fun find i = if Array.sub (parent, i) = i then i else find (Array.sub (parent, i))
      val _ = List.app (fn (u,v,_) => Array.update (parent, find u, find v)) rows
      val connected = n >= 2 andalso List.all (fn v => find v = find 0) (List.tabulate (n, fn i => i))
      val status = if not connected then "unsupported"
                   else if MstCertificate.external_mst_cert vs es tree then "accept" else "reject"
    in "mst-cert-v2 " ^ requestId ^ " " ^ status ^ "\n" end
  fun loop () = case line () of
      NONE => ()
    | SOME text => (TextIO.output (TextIO.stdOut, run text);
                    TextIO.flushOut TextIO.stdOut; loop ())
end
val _ = (CertificateMain.loop () handle _ => OS.Process.exit OS.Process.failure)
