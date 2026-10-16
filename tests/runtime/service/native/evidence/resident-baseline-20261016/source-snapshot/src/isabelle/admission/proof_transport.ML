(* Inert bounded proof terms. No worker source/tactic/theorem-handle evaluation. *)
signature VERI7VN_PROOF_TRANSPORT =
sig
  val receive: Veri7vn_Native_Admission.policy ->
    Veri7vn_Native_Registry.generation -> Veri7vn_Native_Admission.request ->
    string -> Veri7vn_Native_Admission.result
  val export: theory -> theory -> thm -> string
  val release_generation: Veri7vn_Native_Registry.generation -> unit
end;
structure Veri7vn_Proof_Transport :> VERI7VN_PROOF_TRANSPORT =
struct
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  val max_bytes = 100000;
  val max_depth = 128;
  val max_nodes = 20000;
  fun guard true _ = () | guard false message = error message;
  (* Bound nesting before YXML's recursive tree allocation, including term/types. *)
  fun framing bytes =
    let
      val _ = guard (size bytes <= max_bytes) "Proof byte bound exceeded";
      fun chunk text (depth,nodes) =
        let
          val nodes' = nodes + 1;
          val depth' = if text = "\006" then depth - 1
            else if String.isPrefix "\006" text then depth + 1 else depth;
          val _ = guard (nodes' <= max_nodes andalso depth' >= 0 andalso
            depth' <= max_depth) "Proof shape bound exceeded";
        in (depth',nodes') end;
      val (depth,_) = fold chunk (String.fields (fn c => c = #"\005") bytes) (0,0);
    in guard (depth=0) "Unbalanced proof framing" end;
  (* Partial application caches Isabelle's actual canonical theorem lookup table. *)
  val checkers = Synchronized.var "veri7vn_proof_checkers"
    ([]: (theory * (Proofterm.proof -> thm)) list);
  fun release_generation gen =
    let val thy = Proof_Context.theory_of (R.context gen)
    in Synchronized.change checkers
      (filter_out (fn (old,_) => Context.subthy (thy,old))) end;
  fun checker thy = Synchronized.change_result checkers (fn entries =>
    case find_first (fn (old,_) => Context.eq_thy (old,thy)) entries of
      SOME (_,check) => (check,entries)
    | NONE => let val check=Proof_Checker.thm_of_proof thy
      in (check,take 4 ((thy,check)::entries)) end);
  fun inspect allowed proof =
    let
      open Proofterm;
      fun walk depth nodes p =
        let
          val _ = guard (depth <= max_depth andalso nodes < max_nodes) "Proof node bound exceeded";
          fun next q = walk (depth+1) (nodes+1) q;
        in case p of
          MinProof => error "Unavailable proof body"
        | Oracle _ => error "Worker oracle nodes are forbidden"
        | Hyp t => (guard (exists (fn h => h aconv t) allowed) "Undeclared proof hypothesis";nodes+1)
        | Abst (_,_,q) => next q
        | AbsP (_,_,q) => next q
        | q % _ => next q
        | q %% r => walk (depth+1) (next q) r
        | _ => nodes+1 end;
    in ignore (walk 0 0 proof) end;
  fun receive pol gen (request as {hypotheses,...}: A.request) bytes =
    (Timeout.apply (Time.fromSeconds 5) (fn () =>
      let
        val _ = framing bytes;
        val thy = Proof_Context.theory_of (R.context gen);
        val proof = Proofterm.decode thy (YXML.parse_body bytes);
        val _ = inspect hypotheses proof;
        val th = checker thy proof |> Thm.transfer thy |> Thm.strip_shyps;
        val (h,r) = R.insert gen "received-proof" (R.Theorem th) R.empty;
      in A.admit pol gen r h A.Kernel request end) ())
    handle ERROR msg => A.Rejected [msg]
      | THM (msg,_,_) => A.Rejected [msg]
      | CTERM (msg,_) => A.Rejected [msg]
      | Thm.CONTEXT (msg,_,_,_,_) => A.Rejected [msg]
      | Subscript => A.Rejected ["Invalid proof index"]
      | Overflow => A.Rejected ["Proof index overflow"]
      | TERM (msg,_) => A.Rejected [msg]
      | TYPE (msg,_,_) => A.Rejected [msg]
      | XML.XML_ATOM _ => A.Rejected ["Malformed proof atom"]
      | XML.XML_BODY _ => A.Rejected ["Malformed proof structure"]
      | Timeout.TIMEOUT _ => A.Rejected ["Proof reconstruction deadline exceeded"];
  fun export receiver worker raw_th = Timeout.apply (Time.fromSeconds 5) (fn () =>
    let
      val th = Thm.transfer worker raw_th;
      fun available ({thm_name,...}: Proofterm.thm_header) =
        can (Global_Theory.get_thm_name receiver) thm_name;
      fun local_name header = if available header then NONE else SOME Thm_Name.none;
      (* Concrete class evidence may have an unavailable ancestor body even
         though its class judgment is already derivable in the receiver. Only
         the exact closed OFCLASS shape is normalized; the receiver kernel
         independently checks PClass via its own class algebra. *)
      val normalized_nodes=Unsynchronized.ref 0;
      fun normalize depth prf =
        let
          open Proofterm;
          val _=normalized_nodes := !normalized_nodes+1;
          val _=guard (depth<=max_depth andalso !normalized_nodes<=max_nodes)
            "Proof normalization bound exceeded";
          fun next p=normalize (depth+1) p;
        in case prf of
          Abst (s,T,p) => Abst (s,T,next p)
        | AbsP (s,t,p) => AbsP (s,t,next p)
        | p % t => next p % t
        | p %% q => next p %% next q
        | p as PThm (header as {types,prop,...},body) =>
            if available header then p else
            (case try Logic.dest_of_class prop of
                  SOME (T,c) =>
                    if types=SOME [] andalso null (Term.add_tvars prop []) andalso
                      null (Term.add_tfrees prop []) andalso null (Term.add_vars prop []) andalso
                      null (Term.add_frees prop []) andalso Sign.of_sort receiver (T,[c])
                    then PClass (T,c) else p
                | NONE =>
                    let val q=thm_body_proof_open body
                      |> reconstruct_proof worker prop |> next
                    in PThm (header,thm_body (no_proof_body ZTerm.ZNop q)) end)
        | p => p end;
      val proof = Thm.reconstruct_proof_of th
        |> normalize 0
        |> Proofterm.expand_proof worker local_name
        |> Proofterm.reconstruct_proof worker (Thm.prop_of th)
        |> Proofterm.no_thm_proofs;
      val _ = inspect (Thm.hyps_of th) proof;
      val bytes = Proofterm.encode worker proof |> YXML.string_of_body;
      val _ = framing bytes;
    in bytes end) ();
end;
