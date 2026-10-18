theory Earth
  imports Earth_Geo Earth_Geol Earth_Seis Earth_Hydro Earth_Ocean Earth_Weather Earth_Green
begin

text \<open>
  The earth family as one kernel: a request is one of the seven domains' typed requests, and
  its reply is the domain kernel's reply. The untrusted recognizer builds requests from
  English; nothing else decides an answer, a decline or a number.
\<close>

datatype request =
    RGeo geo_req
  | RGeol geol_req
  | RSeis seis_req
  | RHydro hyd_req
  | ROcean ocean_req
  | RWeather weather_req
  | RGreen gh_req

fun reply_of :: "request \<Rightarrow> reply" where
  "reply_of (RGeo r) = geo_reply r"
| "reply_of (RGeol r) = gl_reply r"
| "reply_of (RSeis r) = seis_reply r"
| "reply_of (RHydro r) = hy_reply r"
| "reply_of (ROcean r) = oc_reply r"
| "reply_of (RWeather r) = w_reply r"
| "reply_of (RGreen r) = gh_reply r"

definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

text \<open>A withheld reply is the kernel's decline, never a number.\<close>
theorem reply_withheld_has_no_value:
  "\<not> answered (reply_of r) \<Longrightarrow> stated (reply_of r) = None"
  by (cases r)
     (auto simp: geo_reply_def gl_reply_def seis_reply_def hy_reply_def oc_reply_def w_reply_def gh_reply_def
        reply_val_def reply_with_def decline_reply_def
        split: outcome.splits option.splits decl.splits)

theorem answers_iff_kernel_answers:
  "answers (RGeo r1) = answered (geo_reply r1)"
  "answers (RGeol r2) = answered (gl_reply r2)"
  "answers (RSeis r3) = answered (seis_reply r3)"
  "answers (RHydro r4) = answered (hy_reply r4)"
  "answers (ROcean r5) = answered (oc_reply r5)"
  "answers (RWeather r6) = answered (w_reply r6)"
  "answers (RGreen r7) = answered (gh_reply r7)"
  by (simp_all add: answers_def)

end
