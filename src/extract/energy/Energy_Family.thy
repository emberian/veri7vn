theory Energy_Family
  imports Thermo Home Hvac Renewables Iot
begin

text \<open>The family's one request type: a typed request for any of the six
specialists. thermo takes Thermo requests (the kinds carnot, gas_*, radiated_power,
latent_*, sensible_heat), energy-v2 and energy-v3 take home_req, hvac hvac_req,
renewables ren_req, iot iot_req. The dispatcher is a total function; each branch
is the verified reply of its kernel.\<close>
datatype family_request =
    FThermo request
  | FHome home_req
  | FHvac hvac_req
  | FRen ren_req
  | FIot iot_req

fun reply_of :: "family_request \<Rightarrow> reply" where
  "reply_of (FThermo r) = reply_t r"
| "reply_of (FHome r) = reply_h r"
| "reply_of (FHvac r) = reply_v r"
| "reply_of (FRen r) = reply_r r"
| "reply_of (FIot r) = reply_i r"

fun kernel_of :: "family_request \<Rightarrow> outcome" where
  "kernel_of (FThermo r) = kernel_t r"
| "kernel_of (FHome r) = kernel_h r"
| "kernel_of (FHvac r) = kernel_v r"
| "kernel_of (FRen r) = kernel_r r"
| "kernel_of (FIot r) = kernel_i r"

text \<open>A reply is withheld exactly when its kernel declines (or the digits
cannot be pinned), whichever specialist it came from.\<close>
theorem family_declines_withheld:
  assumes "kernel_of r = Decline d w"
  shows "\<not> answered (reply_of r) \<and> response (reply_of r) = decline_text d w"
  using assms reply_t_withheld reply_h_withheld reply_v_withheld reply_r_withheld reply_i_withheld
  by (cases r) auto

end
