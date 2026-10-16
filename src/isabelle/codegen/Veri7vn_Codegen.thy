theory Veri7vn_Codegen
  imports Code_Target_Numeral
begin

text \<open>The shared generated runtime uses the installed, proved target-integer
implementations of HOL nat and int. This loads only Code_Target_Numeral,
Code_Target_Nat, Code_Abstract_Nat and Code_Target_Int over warm Main, not the
HOL-Library session. The code setup is part of executable identity. Native logical
meanings do not change, and no hash/numeral is shortened to hide unary allocation.\<close>

text \<open>The Eval target shares the same proved compact numerical carriers
across reflected family modules. A family may not generate a second nominal
nat/int type for fields of an already reflected source batch.\<close>
code_reflect Veri7vn_Numeral_Code
  datatypes nat and int = _
  functions integer_of_nat nat_of_integer integer_of_int int_of_integer

lemma abstract_nat_is_public_conversion:
  "Code_Target_Nat.Nat k = nat_of_integer k"
  including integer.lifting by transfer simp

text \<open>Type-only reflection keeps the abstract constructor out of export
roots. Its proved equal public conversion constructs the same canonical compact
value, including clamping negative integer inputs.\<close>
code_printing
  constant Code_Target_Nat.Nat \<rightharpoonup> (Eval) "Veri7vn'_Numeral'_Code.nat'_of'_integer"

ML \<open>
structure Veri7vn_Numerals =
struct
  val nat_of_integer = Veri7vn_Numeral_Code.nat_of_integer;
  val integer_of_nat = Veri7vn_Numeral_Code.integer_of_nat;
  val int_of_integer = Veri7vn_Numeral_Code.Int_of_integer;
  val integer_of_int = Veri7vn_Numeral_Code.integer_of_int;
end;
\<close>

definition large_nat_witness :: nat where
  "large_nat_witness = 115792089237316195423570985008687907853269984665640564039457584007913129639937"
definition large_int_witness :: int where
  "large_int_witness = -10000000000000000000000000000000000000000"

export_code large_nat_witness large_int_witness integer_of_nat integer_of_int
  in SML module_name Veri7vn_Codegen_Witness file_prefix "compact_numerals"

ML \<open>
  val started = Time.now ();
  val n = Veri7vn_Numerals.integer_of_nat @{code large_nat_witness};
  val z = Veri7vn_Numerals.integer_of_int @{code large_int_witness};
  val expected_n = the (IntInf.fromString
    "115792089237316195423570985008687907853269984665640564039457584007913129639937");
  val expected_z = the (IntInf.fromString
    "~10000000000000000000000000000000000000000");
  val _ = if n = expected_n andalso z = expected_z then ()
    else error "Target numeral code changed the exact HOL witness";
  val _ = writeln ("VERI7VN_CODEGEN compact_numerals PASS evaluation_seconds=" ^
    Time.toString (Time.- (Time.now (), started)));
\<close>

definition shared_numeric_step :: "nat \<Rightarrow> int \<Rightarrow> nat \<times> int" where
  "shared_numeric_step n z = (n + 19, z - 23)"

text \<open>This separate reflected consumer exercises arithmetic across the
canonical numeric type/constructor mapping, rather than only its conversions.\<close>
code_reflect Veri7vn_Numeral_Consumer
  functions shared_numeric_step

ML \<open>
  val (n, z) = Veri7vn_Numeral_Consumer.shared_numeric_step
    @{code large_nat_witness} @{code large_int_witness};
  val expected_n = the (IntInf.fromString
    "115792089237316195423570985008687907853269984665640564039457584007913129639956");
  val expected_z = the (IntInf.fromString
    "~10000000000000000000000000000000000000023");
  val _ = if Veri7vn_Numerals.integer_of_nat n = expected_n andalso
      Veri7vn_Numerals.integer_of_int z = expected_z then ()
    else error "Reflected consumer changed exact target arithmetic";
  val _ = if Veri7vn_Numerals.integer_of_nat
      (Veri7vn_Numerals.nat_of_integer (~23)) = 0 then ()
    else error "Canonical natural conversion did not clamp a negative input";
  val _ = writeln "VERI7VN_CODEGEN shared_numeric_arithmetic PASS";
\<close>

code_reflect Veri7vn_Character_Code
  datatypes char = _
  functions integer_of_char char_of_integer

ML \<open>
structure Veri7vn_Characters =
struct
  val char_of_integer = Veri7vn_Character_Code.char_of_integer;
  val integer_of_char = Veri7vn_Character_Code.integer_of_char;
end;
\<close>

record codegen_primitive_probe =
  probe_nat :: nat
  probe_int :: int
  probe_bytes :: string

definition make_primitive_probe :: "nat \<Rightarrow> int \<Rightarrow> string \<Rightarrow> codegen_primitive_probe" where
  "make_primitive_probe n z bytes = \<lparr>probe_nat=n,probe_int=z,probe_bytes=bytes\<rparr>"
definition transform_primitive_probe :: "codegen_primitive_probe \<Rightarrow> codegen_primitive_probe" where
  "transform_primitive_probe input = \<lparr>probe_nat=probe_nat input+19,
    probe_int=probe_int input-23,probe_bytes=probe_bytes input @ [char_of_integer 0]\<rparr>"

code_reflect Veri7vn_Primitive_Record_Code
  datatypes codegen_primitive_probe_ext = _
  functions make_primitive_probe probe_nat probe_int probe_bytes
code_reflect Veri7vn_Primitive_Record_Consumer
  functions transform_primitive_probe

ML \<open>
  val original_bytes = map Veri7vn_Characters.char_of_integer [0,127,128,255];
  val original = Veri7vn_Primitive_Record_Code.make_primitive_probe
    @{code large_nat_witness} @{code large_int_witness} original_bytes;
  val transformed = Veri7vn_Primitive_Record_Consumer.transform_primitive_probe original;
  val observed_bytes = map Veri7vn_Characters.integer_of_char
    (Veri7vn_Primitive_Record_Code.probe_bytes transformed);
  val expected_nat = the (IntInf.fromString
    "115792089237316195423570985008687907853269984665640564039457584007913129639956");
  val expected_int = the (IntInf.fromString
    "~10000000000000000000000000000000000000023");
  val rebuilt = Veri7vn_Primitive_Record_Code.make_primitive_probe
    (Veri7vn_Primitive_Record_Code.probe_nat transformed)
    (Veri7vn_Primitive_Record_Code.probe_int transformed)
    (Veri7vn_Primitive_Record_Code.probe_bytes transformed);
  val _ = if observed_bytes=[0,127,128,255,0] andalso rebuilt=transformed andalso
      Veri7vn_Numerals.integer_of_nat (Veri7vn_Primitive_Record_Code.probe_nat transformed)=expected_nat andalso
      Veri7vn_Numerals.integer_of_int (Veri7vn_Primitive_Record_Code.probe_int transformed)=expected_int
    then () else error "Shared primitive record changed exact bytes or numbers";
  val _ = writeln "VERI7VN_CODEGEN shared_primitive_record PASS";
\<close>

end
