(* Host-committed inert material capability, NOT a rechecked native association.
   Only the private authenticated service/store path calls the named installer.
   Hash/commit membership belongs to that existing host boundary; logical replay
   and exact saved-ID correspondence must still succeed before installation. *)
signature VERI7VN_COMMITTED_NATIVE_RECOVERY =
sig
  type materials = {workspace: string, journal_sequence: IntInf.int,
    association: IntInf.int, semantic_generation: IntInf.int, checkpoint: string,
    manifest: string, projection: string, sequent: string, context_closure: string,
    reconstruction: string}
  type committed
  val install_committed_host: materials -> committed
  val materials: committed -> materials
  val reconstruction: committed -> Veri7vn_Recovery_Manifest.reconstruction
  val is_live: committed -> bool
  val release: committed -> unit
end;
structure Veri7vn_Committed_Native_Recovery :> VERI7VN_COMMITTED_NATIVE_RECOVERY =
struct
  type materials = {workspace: string, journal_sequence: IntInf.int,
    association: IntInf.int, semantic_generation: IntInf.int, checkpoint: string,
    manifest: string, projection: string, sequent: string, context_closure: string,
    reconstruction: string};
  datatype committed = Committed of {payload: materials option Synchronized.var,
    reconstruction: Veri7vn_Recovery_Manifest.reconstruction};
  fun bounded n s = size s <= n;
  fun positive n = n>0 andalso size (IntInf.toString n)<=128;
  fun install_committed_host (m: materials) =
    let
      val _ = if positive (#journal_sequence m) andalso positive (#association m)
        andalso positive (#semantic_generation m) andalso bounded 4194304 (#checkpoint m)
        andalso bounded 1048576 (#projection m) andalso bounded 1048576 (#sequent m)
        andalso bounded 16777216 (#context_closure m) andalso bounded 100000 (#reconstruction m)
        then () else error "Committed native artifact bounds";
      val envelope = Veri7vn_Recovery_Manifest.decode {max_bytes=8192} (#manifest m);
      val _ = if #workspace envelope = #workspace m andalso
        #association envelope = #association m andalso
        #semantic_generation envelope = #semantic_generation m
        then () else error "Committed native artifact identity mismatch";
      val _ = if is_none (#executable envelope) then ()
        else error "Executable recovery requires its typed family bridge";
    in Committed {payload=Synchronized.var "veri7vn_committed_native_recovery" (SOME m),
      reconstruction= #reconstruction envelope} end;
  fun materials (Committed {payload,...}) =
    (case Synchronized.value payload of SOME m => m
    | NONE => error "Committed native recovery material is unavailable");
  fun reconstruction (Committed {reconstruction,...}) = reconstruction;
  fun is_live (Committed {payload,...}) = is_some (Synchronized.value payload);
  fun release (Committed {payload,...}) = Synchronized.change payload (K NONE);
end;
