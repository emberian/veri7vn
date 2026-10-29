(* UNTRUSTED adapter. One invocation receives the bounded, whitespace-only
   internal protocol documented in README.md. The complete graph and externally
   selected edge IDs go to the extracted predicate; no tree is generated here.
   Python owns JSON syntax, schema/bounds checks and process timeout. *)
structure CertificateMain =
struct
  exception BadInput
  val maxVertices = 64
  val maxEdges = 256
  fun need b = if b then () else raise BadInput
  fun tokens () = case TextIO.inputLine TextIO.stdIn of
      NONE => raise BadInput
    | SOME s => String.tokens Char.isSpace s
  fun integer s =
    let val n = case IntInf.fromString s of SOME x => x | NONE => raise BadInput
    in need (s = IntInf.toString n orelse
      (n < 0 andalso s = "-" ^ IntInf.toString (~n))); n end
  fun small s =
    let val n = integer s
    in need (0 <= n andalso n <= 1000000); IntInf.toInt n end
  fun repeat 0 f = []
    | repeat n f = f () :: repeat (n - 1) f
  fun run () =
    let
      val (n, m, k) = case tokens () of
          ["mst-cert-v1", a, b, c] => (small a, small b, small c)
        | _ => raise BadInput
      val _ = need (n >= 2 andalso n <= maxVertices andalso m <= maxEdges
                    andalso k <= n - 1)
      fun edge () = case tokens () of
          [a,b,w] =>
            let val u = small a val v = small b val z = integer w
                val _ = need (u < n andalso v < n andalso
                  ~(IntInf.pow (2, 63)) <= z andalso z < IntInf.pow (2, 63))
            in (Int.toString u, (Int.toString v, MstCertificate.mk_rat z 1)) end
        | _ => raise BadInput
      val es = repeat m edge
      val ev = Vector.fromList es
      fun selected () = case tokens () of
          [s] => let val id = small s in need (id < m); id end
        | _ => raise BadInput
      val ids = repeat k selected
      fun unique [] = true
        | unique (x::xs) = not (List.exists (fn y => x = y) xs) andalso unique xs
      val _ = need (unique ids)
      val _ = need (TextIO.inputAll TextIO.stdIn = "")
      val tree = map (fn id => Vector.sub (ev, id)) ids
      val vs = List.tabulate (n, Int.toString)
    in
      if MstCertificate.external_mst_cert vs es tree then "accept\n" else "reject\n"
    end
  val result = run () handle _ => "invalid\n"
end
val _ = TextIO.output (TextIO.stdOut, CertificateMain.result)
