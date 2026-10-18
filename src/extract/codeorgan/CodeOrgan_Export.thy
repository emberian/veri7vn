theory CodeOrgan_Export
  imports CodeOrgan
begin

definition mk_number :: "integer \<Rightarrow> cvalue" where
  "mk_number n = Number (int_of_integer n)"
definition mk_numbers :: "integer list \<Rightarrow> cvalue" where
  "mk_numbers ns = Numbers (map int_of_integer ns)"
definition number_value :: "cvalue \<Rightarrow> integer option" where
  "number_value v = (case v of Number n \<Rightarrow> Some (integer_of_int n) | _ \<Rightarrow> None)"
definition numbers_value :: "cvalue \<Rightarrow> integer list option" where
  "numbers_value v = (case v of Numbers ns \<Rightarrow> Some (map integer_of_int ns) | _ \<Rightarrow> None)"
definition truth_value :: "cvalue \<Rightarrow> bool option" where
  "truth_value v = (case v of Truth b \<Rightarrow> Some b | _ \<Rightarrow> None)"

export_code run check_program self_test mk_number mk_numbers number_value numbers_value truth_value
  Program Argument Combine Plus Minus Times Concat ZipPlus ZipTimes Truth
  Reverse Ascending Descending Unique SquareEach AbsEach NegateEach
  KeepEven KeepOdd KeepPositive KeepNegative Sum Product Length Maximum Minimum
  AllSame AllUnique IsSorted Absolute Square Cube Negate IsEven IsOdd
  AddEach MultiplyEach Above Below Take Drop int_of_integer nat_of_integer
  in SML module_name Codekernel file_prefix codekernel

ML \<open>
  val roots = @{thms check_nonempty check_every_example check_no_failed_example
    check_rejects_mismatch steps_append lookup_sound reverse_involution
    sort_preserves_members unique_preserves_members sum_of_even_squares
    length_of_map concat_length add_arguments maximum_empty_refused
    minimum_empty_refused truth_is_not_number};
  val _ = if null (Thm_Deps.all_oracles roots) then () else error "code organ oracle";
  val _ = if @{code self_test} then () else error "code organ self test";
  val marker = "VERI7VN_CODEORGAN PASS theorems=16 oracles=0";
  val _ = writeln marker;
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/codeorgan")) [XML.Text marker];
\<close>
end
