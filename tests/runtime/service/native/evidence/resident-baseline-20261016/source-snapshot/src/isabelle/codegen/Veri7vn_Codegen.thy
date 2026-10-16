theory Veri7vn_Codegen
  imports Code_Target_Numeral
begin

text \<open>The shared generated runtime uses the installed, proved target-integer
implementations of HOL nat and int. This loads only Code_Target_Numeral,
Code_Target_Nat, Code_Abstract_Nat and Code_Target_Int over warm Main, not the
HOL-Library session. The code setup is part of executable identity. Native logical
meanings do not change, and no hash/numeral is shortened to hide unary allocation.\<close>

definition large_nat_witness :: nat where
  "large_nat_witness = 115792089237316195423570985008687907853269984665640564039457584007913129639937"
definition large_int_witness :: int where
  "large_int_witness = -10000000000000000000000000000000000000000"

export_code large_nat_witness large_int_witness integer_of_nat integer_of_int
  in SML module_name Veri7vn_Codegen_Witness file_prefix "compact_numerals"

ML \<open>
  val started = Time.now ();
  val n = @{code integer_of_nat} @{code large_nat_witness};
  val z = @{code integer_of_int} @{code large_int_witness};
  val expected_n = the (IntInf.fromString
    "115792089237316195423570985008687907853269984665640564039457584007913129639937");
  val expected_z = the (IntInf.fromString
    "~10000000000000000000000000000000000000000");
  val _ = if n = expected_n andalso z = expected_z then ()
    else error "Target numeral code changed the exact HOL witness";
  val _ = writeln ("VERI7VN_CODEGEN compact_numerals PASS evaluation_seconds=" ^
    Time.toString (Time.- (Time.now (), started)));
\<close>

end
