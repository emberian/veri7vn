(* Profile declarations are proposals/semantic vocabulary, never admission receipts.
   Executable codec implementations live in generated finite bundle modules. *)
signature VERI7VN_NATIVE_PROFILES =
sig
  datatype encoding = Bytes | Unicode of string
  datatype case_policy = Case_Sensitive | Case_Folded of string
  datatype exactness = Exact | Approximate of cterm
  datatype extent = Complete | Partial of {covered: cterm, missing: cterm}
  type literal = {source: Veri7vn_Native_Literals.slice, encoding: encoding, case_policy: case_policy,
    normalization: string, escaping: string}
  type profile = {carrier: typ, representation: cterm option,
    numeric: exactness, shape: cterm, scope: extent,
    literal_policy: string, display_projection: cterm option,
    materialization_limit: int option, dependencies: Veri7vn_Native_Registry.object_handle list}
  type declaration
  val declare: Veri7vn_Native_Registry.generation -> profile -> declaration
  val inspect: declaration -> profile
  val same_declaration: declaration * declaration -> bool
  val owner: declaration -> Veri7vn_Native_Registry.generation
  val retain_literal: literal -> literal
  val original_literal: literal -> string
end;
structure Veri7vn_Native_Profiles :> VERI7VN_NATIVE_PROFILES =
struct
  datatype encoding = Bytes | Unicode of string;
  datatype case_policy = Case_Sensitive | Case_Folded of string;
  datatype exactness = Exact | Approximate of cterm;
  datatype extent = Complete | Partial of {covered: cterm, missing: cterm};
  type literal = {source: Veri7vn_Native_Literals.slice, encoding: encoding, case_policy: case_policy,
    normalization: string, escaping: string};
  type profile = {carrier: typ, representation: cterm option,
    numeric: exactness, shape: cterm, scope: extent,
    literal_policy: string, display_projection: cterm option,
    materialization_limit: int option, dependencies: Veri7vn_Native_Registry.object_handle list};
  datatype declaration = Declaration of serial * Veri7vn_Native_Registry.generation * profile;
  fun declare generation (p: profile) =
    let
      val ctxt = Veri7vn_Native_Registry.context generation;
      val _ = Thm.ctyp_of ctxt (#carrier p);
      fun check ct = if can (Thm.transfer_cterm (Proof_Context.theory_of ctxt)) ct
        then () else error "Profile object outside native lineage";
      val _ = List.app check (the_list (#representation p) @ [#shape p] @
        the_list (#display_projection p) @
        (case #numeric p of Exact => [] | Approximate c => [c]) @
        (case #scope p of Complete => [] | Partial {covered, missing} => [covered, missing]));
      val _ = (case #materialization_limit p of SOME n =>
        if n < 0 then error "Negative materialization limit" else () | NONE => ());
    in Declaration (serial (), generation, p) end;
  fun inspect (Declaration (_, _, p)) = p;
  fun same_declaration (Declaration (a, _, _), Declaration (b, _, _)) = a = b;
  fun owner (Declaration (_, g, _)) = g;
  fun retain_literal (literal: literal) = literal;
  fun original_literal ({source, ...}: literal) = Veri7vn_Native_Literals.original source;
end;

(* Typed bulk interface specification only: there is deliberately no registration
   function taking this structure and converting it to executable authority.
   A qualified generated bundle implements this signature at its concrete carrier. *)
signature VERI7VN_TYPED_BULK_CODEC =
sig
  type value
  type batch
  type error
  datatype decoded = Decoded of batch | Rejected of error
  val length: batch -> int
  val sub: batch -> int -> value
  val encode: batch -> Word8Vector.vector
  val decode: {max_bytes: int, max_elements: int} -> Word8Vector.vector -> decoded
end;
