theory Veri7vn_Springs imports Veri7vn_IR begin

text \<open>Generated certificates for the actual lowering DAGs. The formula extraction and C emitter remain outside this theorem.\<close>

definition spring_force_source where "spring_force_source = (Binary Multiply (Input 0) (Input 1))"

definition spring_force_code where "spring_force_code = [Load 0, Load 1, Apply2 Multiply 0 1]"

lemma spring_force_certificate: "check_dag spring_force_source spring_force_code 2"

  by (simp add: check_dag_def spring_force_source_def spring_force_code_def symbolic_run_def at_def)

theorem spring_force_correct:

  "at (value_run env lit unary binary spring_force_code) 2 = meaning env lit unary binary spring_force_source"

  by (rule validated_dag_correct[OF spring_force_certificate])

definition spring_extension_source where "spring_extension_source = (Binary Divide (Input 0) (Input 1))"

definition spring_extension_code where "spring_extension_code = [Load 0, Load 1, Apply2 Divide 0 1]"

lemma spring_extension_certificate: "check_dag spring_extension_source spring_extension_code 2"

  by (simp add: check_dag_def spring_extension_source_def spring_extension_code_def symbolic_run_def at_def)

theorem spring_extension_correct:

  "at (value_run env lit unary binary spring_extension_code) 2 = meaning env lit unary binary spring_extension_source"

  by (rule validated_dag_correct[OF spring_extension_certificate])

definition spring_stiffness_source where "spring_stiffness_source = (Binary Divide (Input 0) (Input 1))"

definition spring_stiffness_code where "spring_stiffness_code = [Load 0, Load 1, Apply2 Divide 0 1]"

lemma spring_stiffness_certificate: "check_dag spring_stiffness_source spring_stiffness_code 2"

  by (simp add: check_dag_def spring_stiffness_source_def spring_stiffness_code_def symbolic_run_def at_def)

theorem spring_stiffness_correct:

  "at (value_run env lit unary binary spring_stiffness_code) 2 = meaning env lit unary binary spring_stiffness_source"

  by (rule validated_dag_correct[OF spring_stiffness_certificate])

definition spring_energy_source where "spring_energy_source = (Binary Multiply (Binary Multiply (Binary Multiply (Literal (Rational 1 2)) (Input 0)) (Input 1)) (Input 1))"

definition spring_energy_code where "spring_energy_code = [Constant (Rational 1 2), Load 0, Apply2 Multiply 0 1, Load 1, Apply2 Multiply 2 3, Apply2 Multiply 4 3]"

lemma spring_energy_certificate: "check_dag spring_energy_source spring_energy_code 5"

  by (simp add: check_dag_def spring_energy_source_def spring_energy_code_def symbolic_run_def at_def)

theorem spring_energy_correct:

  "at (value_run env lit unary binary spring_energy_code) 5 = meaning env lit unary binary spring_energy_source"

  by (rule validated_dag_correct[OF spring_energy_certificate])

definition spring_period_source where "spring_period_source = (Binary Multiply (Binary Multiply (Literal (Rational 2 1)) (Literal Pi)) (Unary SquareRoot (Binary Divide (Input 0) (Input 1))))"

definition spring_period_code where "spring_period_code = [Constant (Rational 2 1), Constant Pi, Apply2 Multiply 0 1, Load 0, Load 1, Apply2 Divide 3 4, Apply1 SquareRoot 5, Apply2 Multiply 2 6]"

lemma spring_period_certificate: "check_dag spring_period_source spring_period_code 7"

  by (simp add: check_dag_def spring_period_source_def spring_period_code_def symbolic_run_def at_def)

theorem spring_period_correct:

  "at (value_run env lit unary binary spring_period_code) 7 = meaning env lit unary binary spring_period_source"

  by (rule validated_dag_correct[OF spring_period_certificate])

definition spring_frequency_source where "spring_frequency_source = (Binary Divide (Literal (Rational 1 1)) (Binary Multiply (Binary Multiply (Literal (Rational 2 1)) (Literal Pi)) (Unary SquareRoot (Binary Divide (Input 0) (Input 1)))))"

definition spring_frequency_code where "spring_frequency_code = [Constant (Rational 1 1), Constant (Rational 2 1), Constant Pi, Apply2 Multiply 1 2, Load 0, Load 1, Apply2 Divide 4 5, Apply1 SquareRoot 6, Apply2 Multiply 3 7, Apply2 Divide 0 8]"

lemma spring_frequency_certificate: "check_dag spring_frequency_source spring_frequency_code 9"

  by (simp add: check_dag_def spring_frequency_source_def spring_frequency_code_def symbolic_run_def at_def)

theorem spring_frequency_correct:

  "at (value_run env lit unary binary spring_frequency_code) 9 = meaning env lit unary binary spring_frequency_source"

  by (rule validated_dag_correct[OF spring_frequency_certificate])

end
