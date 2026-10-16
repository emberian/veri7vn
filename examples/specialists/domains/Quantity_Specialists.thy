theory Quantity_Specialists
  imports "Veri7vn_Domains.Domain_Plans"
begin

text \<open>A recipe is inert typed data consumed by the existing generated plan
linker. The spring premise 105 denotes the ideal elastic model; input premise
700 denotes the supplied displacement. Both survive conversion and energy.\<close>
definition spring_energy_recipe :: "domain_operation plan_node list" where
  "spring_energy_recipe = [
    \<lparr>node_id=2,node_operation=ConvertLinear Centimetre Metre,node_inputs=[0],retained_premises=[]\<rparr>,
    \<lparr>node_id=3,node_operation=Spring SpringEnergy,node_inputs=[1,2],retained_premises=[]\<rparr>]"
definition spring_energy_inputs :: "(nat \<times> (domain_value \<times> nat list)) list" where
  "spring_energy_inputs = [(0,(LinearValue Centimetre 10,[700])),(1,(LinearValue NewtonPerMetre 200,[]))]"
definition spring_energy_package where
  "spring_energy_package = run_quantity_plan (Some 105) 2 spring_energy_inputs spring_energy_recipe"

lemma package_energy_and_conditions:
  "spring_energy_package = Some [(2,NodeValue (LinearValue Metre (1/10)) [700]),
    (3,NodeValue (LinearValue Joule 1) [105,700])]"
  by eval
lemma package_missing_model_blocks:
  "run_quantity_plan None 2 spring_energy_inputs spring_energy_recipe =
    Some [(2,NodeValue (LinearValue Metre (1/10)) [700]),(3,NodeBlocked 201)]"
  by eval
lemma package_wrong_unit_rejects:
  "run_quantity_plan (Some 105) 2
    [(0,(LinearValue Gram 10,[])),(1,(LinearValue NewtonPerMetre 200,[]))]
    spring_energy_recipe = None"
  by eval

export_code spring_energy_package in SML module_name Quantity_Specialists
end
