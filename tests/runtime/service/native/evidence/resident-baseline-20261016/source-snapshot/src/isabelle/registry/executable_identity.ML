(* Build identity, not implementation acceptance. A generated bundle closes over
   one pin; native context additions may retain it. No value casts/execute hooks. *)
signature VERI7VN_EXECUTABLE_IDENTITY =
sig
  type pin
  type manifest = {artifact: string, compiler: string, target: string,
    serializers: string list, foreign_primitives: string list, settings: string list}
  val pin: theory -> manifest -> pin
  val same: pin * pin -> bool
  val code_theory: pin -> theory
  val manifest: pin -> manifest
  val exact_code_context: pin -> theory -> bool
end;
structure Veri7vn_Executable_Identity :> VERI7VN_EXECUTABLE_IDENTITY =
struct
  type manifest = {artifact: string, compiler: string, target: string,
    serializers: string list, foreign_primitives: string list, settings: string list};
  datatype pin = Pin of {id: serial, theory: theory, manifest: manifest};
  fun pin theory manifest = Pin {id=serial (), theory=theory, manifest=manifest};
  fun same (Pin {id=a,...}, Pin {id=b,...}) = a=b;
  fun code_theory (Pin {theory,...}) = theory;
  fun manifest (Pin {manifest,...}) = manifest;
  fun exact_code_context p theory = Context.eq_thy (code_theory p, theory);
end;
