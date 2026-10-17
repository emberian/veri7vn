theory Discrete
  imports Disc_Games Disc_Logic Disc_Algos Disc_Calc Disc_Formats
begin

text \<open>The discrete family: one typed request over the five specialists
(games-v3, logic-v3, algorithms, calculus, dataformats) and one reply
function. Each organ's kernel and its theorems are in its own theory.\<close>

datatype request =
    RGames greq
  | RLogic lreq
  | RAlgos areq
  | RCalc creq
  | RFormats freq

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case r of
     RGames q \<Rightarrow> g_reply q
   | RLogic q \<Rightarrow> l_reply q
   | RAlgos q \<Rightarrow> a_reply q
   | RCalc q \<Rightarrow> c_reply q
   | RFormats q \<Rightarrow> f_reply q)"

definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition card_list :: "card list" where
  "card_list = [C_ace, C_king, C_queen, C_jack, C_face, C_heart, C_spade, C_diamond, C_club, C_red, C_black]"

definition form_list :: "form list" where
  "form_list = [F_mp, F_mt, F_ac, F_da, F_hs, F_ds]"

text \<open>Whether the kernel states an answer for a request (the narrowing of
some organs consults it).\<close>
definition answers :: "request \<Rightarrow> bool" where
  "answers r = answered (reply_of r)"

theorem reply_of_games: "reply_of (RGames q) = g_reply q" by (simp add: reply_of_def)
theorem reply_of_logic: "reply_of (RLogic q) = l_reply q" by (simp add: reply_of_def)
theorem reply_of_algos: "reply_of (RAlgos q) = a_reply q" by (simp add: reply_of_def)
theorem reply_of_calc: "reply_of (RCalc q) = c_reply q" by (simp add: reply_of_def)
theorem reply_of_formats: "reply_of (RFormats q) = f_reply q" by (simp add: reply_of_def)

end
