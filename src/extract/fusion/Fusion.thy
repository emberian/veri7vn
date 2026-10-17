theory Fusion
  imports "Veri7vn_Quantity.Quantity"
begin

text \<open>
  Oracle7's specialist fusion (upstream/root/specialists/_gate/network_v3.py,
  with network_v2.py's core math, finish rules and validity checks) as a HOL
  decision. A question has been read (by an untrusted recognizer) into typed
  givens, a typed goal and a few context facts. The planner keeps a pool of
  typed quantities: the givens and every intermediate a specialist produced.
  An operation whose typed slots can be filled from the pool asks its
  specialist; the value joins the pool and its inputs are used up. Core math
  over everything left must reach the asked dimension, using every remaining
  quantity exactly once. Search runs breadth first to depth 3; at the
  shallowest depth where any plan completes, the complete plans must agree
  within 0.5 percent or the planner declines.

  The planner is stated for an arbitrary node function @{text nd} (what a
  specialist replies to an operation), so the theorems about search, agreement
  and use of givens hold for every node. The function qnode instantiates the nodes
  with lane G's verified quantity kernel (densities, fluids, springs, fuels),
  and @{text qnode_sound} ties every node value to that kernel's value.
\<close>

section \<open>Dimensions and typed quantities\<close>

text \<open>Exponents over the base units m, kg, s, A, K and dollars (network_v2.BASE).\<close>
datatype dimv = Dim int int int int int int

fun dmul :: "dimv \<Rightarrow> dimv \<Rightarrow> int \<Rightarrow> dimv" where
  "dmul (Dim a b c d e f) (Dim a' b' c' d' e' f') k =
     Dim (a + k * a') (b + k * b') (c + k * c') (d + k * d') (e + k * e') (f + k * f')"

definition "d_one = Dim 0 0 0 0 0 0"
definition "d_len = Dim 1 0 0 0 0 0"
definition "d_mass = Dim 0 1 0 0 0 0"
definition "d_time = Dim 0 0 1 0 0 0"
definition "d_curr = Dim 0 0 0 1 0 0"
definition "d_temp = Dim 0 0 0 0 1 0"
definition "d_money = Dim 0 0 0 0 0 1"
definition "d_area = Dim 2 0 0 0 0 0"
definition "d_vol = Dim 3 0 0 0 0 0"
definition "d_freq = Dim 0 0 (-1) 0 0 0"
definition "d_charge = Dim 0 0 1 1 0 0"
definition "d_flow = Dim 3 0 (-1) 0 0 0"
definition "d_power = Dim 2 1 (-3) 0 0 0"
definition "d_energy = Dim 2 1 (-2) 0 0 0"
definition "d_force = Dim 1 1 (-2) 0 0 0"
definition "d_pressure = Dim (-1) 1 (-2) 0 0 0"
definition "d_stiff = Dim 0 1 (-2) 0 0 0"

text \<open>Roles the reader attaches (network_v2.read_givens) and roles of
specialist outputs. Only some matter to the planner: a temperature point,
a duty, a delta, a CO2 mass, a per-unit duration and the planet ratios.\<close>
datatype role = Ro_delta | Ro_duty | Ro_derived | Ro_co2 | Ro_temp | Ro_per_unit String.literal
  | Ro_earth_mass | Ro_earth_radius | Ro_out String.literal | Ro_tag String.literal

text \<open>What the reader found the amount attached to: the material
(@{text "attached(text, q.text, mat)"}), the fuel, or a depth
(@{text depth_attached}).\<close>
datatype mark = Of_material | Of_fuel | Depth_of

text \<open>The v3 operations that lane G's kernels answer (network_v3.ops_v3,
in its order). The v2 operations (acoustics, physics, planetary, coldchain,
geometry, thermo, carboncapture) have no lane G kernel and are not nodes.\<close>
datatype fop = Mass_of_volume | Volume_of_mass | Gauge_pressure | Buoyant_force
  | Spring_force | Spring_energy | Fuel_energy | Fuel_co2_mass

datatype snode = Nd_densities | Nd_fluids | Nd_springs | Nd_fuels

fun node_of :: "fop \<Rightarrow> snode" where
  "node_of Mass_of_volume = Nd_densities" | "node_of Volume_of_mass = Nd_densities"
| "node_of Gauge_pressure = Nd_fluids" | "node_of Buoyant_force = Nd_fluids"
| "node_of Spring_force = Nd_springs" | "node_of Spring_energy = Nd_springs"
| "node_of Fuel_energy = Nd_fuels" | "node_of Fuel_co2_mass = Nd_fuels"

text \<open>Where a pool entry came from: the i-th given, core math over givens i
and j, or a specialist operation (its inputs are recorded in the plan).\<close>
datatype origin = Given nat | Core nat nat | Derived fop

record quantity =
  amount :: rat
  qdim :: dimv
  role :: "role option"
  origin :: origin
  marks :: "mark list"

text \<open>A slot filler: a pool entry, or (v2) a quantity core math derives
from two givens.\<close>
datatype arg = Pool nat | Derive nat nat

datatype step = Step fop "arg list"

fun step_op :: "step \<Rightarrow> fop" where "step_op (Step f as) = f"

fun arg_uses :: "arg \<Rightarrow> nat list" where
  "arg_uses (Pool k) = [k]" | "arg_uses (Derive i j) = [i, j]"

fun step_uses :: "step \<Rightarrow> nat list" where
  "step_uses (Step f as) = concat (map arg_uses as)"

text \<open>The goal: a dimension with the asked unit's SI factor (and whether
only a specialist operation may meet it, the v3 "op" goals), a yes/no
question, or a count of per-unit spans.\<close>
datatype goal = GDim dimv rat bool | GBool | GCount String.literal

text \<open>Context facts the reader takes from the text (network_v3.read_flags_v3).\<close>
record ctx =
  c_object :: "material option"
  c_substance :: "material option"
  c_fluid :: "material option"
  c_fuel :: "fuel option"
  c_burn :: bool
  c_asks_co2 :: bool
  c_spring :: bool
  c_full_of :: bool

definition c_mat :: "ctx \<Rightarrow> material option" where
  "c_mat c = (case c_object c of Some m \<Rightarrow> Some m | None \<Rightarrow> c_substance c)"

text \<open>What a node returns: a value in SI units, or a yes/no verdict.\<close>
datatype nres = NVal rat | NBool bool

type_synonym nodefn = "fop \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> nres option"


section \<open>Core math (network_v2.core_math)\<close>

text \<open>Exponents in itertools.product order over (1, -1).\<close>
fun signs :: "nat \<Rightarrow> int list list" where
  "signs 0 = [[]]"
| "signs (Suc n) = map ((#) 1) (signs n) @ map ((#) (-1)) (signs n)"

fun dsum :: "(rat \<times> dimv) list \<Rightarrow> int list \<Rightarrow> dimv" where
  "dsum ((v, d) # xs) (e # es) = dmul (dsum xs es) d e"
| "dsum _ _ = d_one"

fun cprod :: "(rat \<times> dimv) list \<Rightarrow> int list \<Rightarrow> rat" where
  "cprod ((v, d) # xs) (e # es) = (if e = 1 then v else inverse v) * cprod xs es"
| "cprod _ _ = 1"

fun inv_zero :: "(rat \<times> dimv) list \<Rightarrow> int list \<Rightarrow> bool" where
  "inv_zero ((v, d) # xs) (e # es) = ((e \<noteq> 1 \<and> v = 0) \<or> inv_zero xs es)"
| "inv_zero _ _ = False"

text \<open>Every quantity gets exponent +1 or -1; the product must have the goal
dimension; the solution with the most +1 exponents wins; equally good
solutions with different values decline.\<close>
definition core_eval :: "(rat \<times> dimv) list \<Rightarrow> dimv \<Rightarrow> rat option" where
  "core_eval xs gd = (if xs = [] \<or> 7 < length xs then None else
     (let sols = filter (\<lambda>es. dsum xs es = gd) (signs (length xs)) in
      if sols = [] then None else
      (let best = fold max (map sum_list sols) (sum_list (hd sols));
           top = filter (\<lambda>es. sum_list es = best) sols in
       if top = [] \<or> list_ex (inv_zero xs) top then None
       else if list_ex (\<lambda>es. cprod xs es \<noteq> cprod xs (hd top)) top then None
       else Some (cprod xs (hd top)))))"

definition is_temp :: "quantity \<Rightarrow> bool" where
  "is_temp q \<longleftrightarrow> role q = Some Ro_temp"

definition is_per_unit :: "quantity \<Rightarrow> bool" where
  "is_per_unit q \<longleftrightarrow> (case role q of Some (Ro_per_unit u) \<Rightarrow> True | _ \<Rightarrow> False)"

text \<open>Two temperature points become one difference; one point alone has no
core math.\<close>
definition core_math :: "quantity list \<Rightarrow> dimv \<Rightarrow> rat option" where
  "core_math qs gd = (let pts = filter is_temp qs;
       xs = map (\<lambda>q. (amount q, qdim q)) (filter (\<lambda>q. \<not> is_temp q) qs) in
     if pts = [] then core_eval xs gd
     else if length pts = 2 then core_eval (xs @ [(\<bar>amount (pts ! 1) - amount (pts ! 0)\<bar>, d_temp)]) gd
     else None)"

lemma signs_shape: "es \<in> set (signs n) \<Longrightarrow> length es = n \<and> set es \<subseteq> {1, -1}"
proof (induction n arbitrary: es)
  case 0
  then show ?case by simp
next
  case (Suc n)
  then obtain e x where es: "es = e # x" "e = 1 \<or> e = -1" "x \<in> set (signs n)" by auto
  then have "length x = n \<and> set x \<subseteq> {1, -1}" using Suc.IH by blast
  then show ?case using es by auto
qed

theorem core_eval_sound:
  assumes "core_eval xs gd = Some v"
  shows "\<exists>es. length es = length xs \<and> set es \<subseteq> {1, -1} \<and> dsum xs es = gd \<and> v = cprod xs es"
proof -
  define sols where "sols = filter (\<lambda>es. dsum xs es = gd) (signs (length xs))"
  define best where "best = fold max (map sum_list sols) (sum_list (hd sols))"
  define top where "top = filter (\<lambda>es. sum_list es = best) sols"
  have ne: "sols \<noteq> []" and v: "v = cprod xs (hd top)" and tne: "top \<noteq> []"
    using assms by (auto simp: core_eval_def sols_def best_def top_def Let_def split: if_splits)
  have "hd top \<in> set top" using tne by simp
  then have "hd top \<in> set sols" by (simp add: top_def)
  then have "hd top \<in> set (signs (length xs)) \<and> dsum xs (hd top) = gd" by (simp add: sols_def)
  then show ?thesis using signs_shape v by blast
qed


section \<open>Validity of givens (network_v2.valid_given)\<close>

definition phys_dims :: "dimv list" where
  "phys_dims = [d_time, d_mass, d_len, d_area, d_vol, d_curr, d_charge, d_freq, d_flow]"

text \<open>Which of network_v2's five validity rules a given breaks, if any.\<close>
definition invalid_why :: "quantity \<Rightarrow> nat option" where
  "invalid_why q = (if role q = Some Ro_duty \<and> \<not> (0 < amount q \<and> amount q \<le> 1) then Some 1
     else if qdim q \<in> set phys_dims \<and> amount q \<le> 0 \<and> \<not> is_temp q then Some 2
     else if qdim q = d_power \<and> amount q \<le> 0 then Some 3
     else if amount q \<le> 0 \<and> qdim q \<notin> set [d_one, d_temp, d_money] \<and> \<not> is_temp q \<and> role q \<noteq> Some Ro_delta then Some 4
     else if (role q = Some Ro_earth_mass \<or> role q = Some Ro_earth_radius) \<and> amount q \<le> 0 then Some 5
     else None)"


section \<open>Operations: slots, admission, outputs (network_v3.ops_v3)\<close>

definition src :: "quantity \<Rightarrow> snode option" where
  "src q = (case origin q of Derived f \<Rightarrow> Some (node_of f) | _ \<Rightarrow> None)"

text \<open>Typed slots: a dimension and a predicate on the filler.\<close>
fun slots :: "fop \<Rightarrow> (dimv \<times> (quantity \<Rightarrow> bool)) list" where
  "slots Mass_of_volume = [(d_vol, \<lambda>q. src q \<noteq> Some Nd_densities)]"
| "slots Volume_of_mass = [(d_mass, \<lambda>q. src q \<noteq> Some Nd_densities)]"
| "slots Gauge_pressure = [(d_len, \<lambda>q. True)]"
| "slots Buoyant_force = [(d_vol, \<lambda>q. True)]"
| "slots Spring_force = [(d_stiff, \<lambda>q. True), (d_len, \<lambda>q. True)]"
| "slots Spring_energy = [(d_stiff, \<lambda>q. True), (d_len, \<lambda>q. True)]"
| "slots Fuel_energy = [(d_mass, \<lambda>q. role q \<noteq> Some Ro_co2)]"
| "slots Fuel_co2_mass = [(d_mass, \<lambda>q. role q \<noteq> Some Ro_co2)]"

fun out_dim :: "fop \<Rightarrow> dimv" where
  "out_dim Mass_of_volume = d_mass" | "out_dim Volume_of_mass = d_vol"
| "out_dim Gauge_pressure = d_pressure" | "out_dim Buoyant_force = d_force"
| "out_dim Spring_force = d_force" | "out_dim Spring_energy = d_energy"
| "out_dim Fuel_energy = d_energy" | "out_dim Fuel_co2_mass = d_mass"

fun out_role :: "fop \<Rightarrow> role" where
  "out_role Mass_of_volume = Ro_out STR ''mass''" | "out_role Volume_of_mass = Ro_out STR ''volume''"
| "out_role Gauge_pressure = Ro_out STR ''pressure''" | "out_role Buoyant_force = Ro_out STR ''buoyancy''"
| "out_role Spring_force = Ro_out STR ''force''" | "out_role Spring_energy = Ro_out STR ''energy''"
| "out_role Fuel_energy = Ro_out STR ''energy''" | "out_role Fuel_co2_mass = Ro_co2"

text \<open>The pairs of names the fuel and the material share
(network_v3 compares the fuel's name with the object's or substance's).\<close>
fun fuel_material :: "fuel \<Rightarrow> material option" where
  "fuel_material F_diesel = Some M_diesel" | "fuel_material F_petrol = Some M_petrol"
| "fuel_material _ = None"

definition fuel_is_stuff :: "ctx \<Rightarrow> bool" where
  "fuel_is_stuff c = (case c_fuel c of None \<Rightarrow> False | Some f \<Rightarrow>
     fuel_material f \<noteq> None \<and> (c_object c = fuel_material f \<or> c_substance c = fuel_material f))"

text \<open>network_v3's vol_ok: a volume OF the material is a given attached to it, or
(another specialist's result) a vessel "full of" it.\<close>
definition vol_ok :: "ctx \<Rightarrow> quantity \<Rightarrow> bool" where
  "vol_ok c v = (case src v of None \<Rightarrow> Of_material \<in> set (marks v)
     | Some Nd_densities \<Rightarrow> False | Some _ \<Rightarrow> c_full_of c)"

text \<open>network_v3's fuel_mass_ok: the mass is OF the fuel.\<close>
definition fuel_mass_ok :: "ctx \<Rightarrow> quantity \<Rightarrow> bool" where
  "fuel_mass_ok c m = (case src m of None \<Rightarrow> Of_fuel \<in> set (marks m)
     | Some Nd_densities \<Rightarrow> fuel_is_stuff c | Some _ \<Rightarrow> False)"

text \<open>When network_v3 renders a phrasing at all (its render functions
return None otherwise).\<close>
fun admits :: "fop \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> bool" where
  "admits Mass_of_volume c [v] = (c_mat c \<noteq> None \<and> \<not> c_asks_co2 c \<and> vol_ok c v)"
| "admits Volume_of_mass c [m] =
     (c_mat c \<noteq> None \<and> \<not> c_asks_co2 c \<and> src m = None \<and> Of_material \<in> set (marks m))"
| "admits Gauge_pressure c [h] = (c_fluid c \<noteq> None \<and> src h = None \<and> Depth_of \<in> set (marks h))"
| "admits Buoyant_force c [v] = (c_fluid c \<noteq> None)"
| "admits Spring_force c [k, x] = c_spring c"
| "admits Spring_energy c [k, x] = c_spring c"
| "admits Fuel_energy c [m] = (c_fuel c \<noteq> None \<and> c_burn c \<and> fuel_mass_ok c m)"
| "admits Fuel_co2_mass c [m] = (c_fuel c \<noteq> None \<and> c_burn c \<and> c_asks_co2 c \<and> fuel_mass_ok c m)"
| "admits _ _ _ = False"


section \<open>Planner state, steps and plans\<close>

record st =
  pool :: "quantity list"
  avail :: "nat list"
  steps :: "step list"
  verdict :: "bool option"

definition start_st :: "quantity list \<Rightarrow> st" where
  "start_st p = \<lparr>pool = p, avail = [0..<length p], steps = [], verdict = None\<rparr>"

definition rest_of :: "st \<Rightarrow> quantity list" where
  "rest_of s = map (\<lambda>k. pool s ! k) (avail s)"

definition dq :: "nat \<Rightarrow> nat \<Rightarrow> rat \<Rightarrow> dimv \<Rightarrow> quantity" where
  "dq i j v d = \<lparr>amount = v, qdim = d, role = Some Ro_derived, origin = Core i j, marks = []\<rparr>"

text \<open>A filler fits a slot: an available pool entry of the slot's dimension
satisfying its predicate, or core math over two available givens (not
temperature points, in pool order) reaching the slot's dimension.\<close>
fun slot_ok :: "quantity list \<Rightarrow> st \<Rightarrow> dimv \<times> (quantity \<Rightarrow> bool) \<Rightarrow> arg \<Rightarrow> bool" where
  "slot_ok p s (d, pr) (Pool k) \<longleftrightarrow>
     k \<in> set (avail s) \<and> k < length (pool s) \<and> qdim (pool s ! k) = d \<and> pr (pool s ! k)"
| "slot_ok p s (d, pr) (Derive i j) \<longleftrightarrow>
     i < j \<and> i \<in> set (avail s) \<and> j \<in> set (avail s) \<and> j < length p \<and> j < length (pool s) \<and>
     \<not> is_temp (pool s ! i) \<and> \<not> is_temp (pool s ! j) \<and>
     (case core_math [pool s ! i, pool s ! j] d of Some v \<Rightarrow> pr (dq i j v d) | None \<Rightarrow> False)"

fun arg_q :: "st \<Rightarrow> dimv \<Rightarrow> arg \<Rightarrow> quantity" where
  "arg_q s d (Pool k) = pool s ! k"
| "arg_q s d (Derive i j) =
     dq i j (case core_math [pool s ! i, pool s ! j] d of Some v \<Rightarrow> v | None \<Rightarrow> 0) d"

definition arg_qs :: "st \<Rightarrow> fop \<Rightarrow> arg list \<Rightarrow> quantity list" where
  "arg_qs s f as = map (\<lambda>(sl, a). arg_q s (fst sl) a) (zip (slots f) as)"

definition newq :: "fop \<Rightarrow> rat \<Rightarrow> quantity" where
  "newq f v = \<lparr>amount = v, qdim = out_dim f, role = Some (out_role f), origin = Derived f, marks = []\<rparr>"

text \<open>One step: the operation is in the catalogue, every filler fits its
slot, no pool entry is used twice, network_v3 renders a phrasing, and the
node answers. A value joins the pool; a verdict ends the plan.\<close>
definition apply_step :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> st \<Rightarrow> step \<Rightarrow> st option" where
  "apply_step nd ops c p s x = (case x of Step f as \<Rightarrow>
     if verdict s = None \<and> f \<in> set ops \<and> list_all2 (slot_ok p s) (slots f) as
        \<and> distinct (concat (map arg_uses as)) \<and> admits f c (arg_qs s f as)
     then (case nd f c (arg_qs s f as) of
             Some (NVal v) \<Rightarrow> Some \<lparr>pool = pool s @ [newq f v],
               avail = filter (\<lambda>k. k \<notin> set (step_uses x)) (avail s) @ [length (pool s)],
               steps = steps s @ [x], verdict = None\<rparr>
           | Some (NBool b) \<Rightarrow> Some \<lparr>pool = pool s,
               avail = filter (\<lambda>k. k \<notin> set (step_uses x)) (avail s),
               steps = steps s @ [x], verdict = Some b\<rparr>
           | None \<Rightarrow> None)
     else None)"

fun run_plan :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> st \<Rightarrow> step list \<Rightarrow> st option" where
  "run_plan nd ops c p s [] = Some s"
| "run_plan nd ops c p s (x # xs) =
     (case apply_step nd ops c p s x of None \<Rightarrow> None | Some t \<Rightarrow> run_plan nd ops c p t xs)"


section \<open>FINISH (network_v3._finish)\<close>

datatype fin = FVal rat | FBool bool
datatype fres = FNone | FSingle | FDone fin

text \<open>At depth @{text d}: a yes/no goal needs a verdict and nothing left; a
count divides the remaining time by the one per-unit span; a dimension goal
needs core math over everything left, never at depth 0 for an "op" goal, never a
single given's conversion, never a given handed back unchanged.\<close>
definition finish :: "goal \<Rightarrow> quantity list \<Rightarrow> st \<Rightarrow> nat \<Rightarrow> fres" where
  "finish g p s d = (case g of
     GBool \<Rightarrow> (case verdict s of Some b \<Rightarrow> (if rest_of s = [] then FDone (FBool b) else FNone) | None \<Rightarrow> FNone)
   | GCount u \<Rightarrow> (if verdict s \<noteq> None then FNone else
       (case filter is_per_unit (rest_of s) of
          [pq] \<Rightarrow> (case core_math (filter (\<lambda>q. \<not> is_per_unit q) (rest_of s)) d_time of
                    Some cm \<Rightarrow> (if amount pq = 0 then FNone else FDone (FVal (cm / amount pq)))
                  | None \<Rightarrow> FNone)
        | _ \<Rightarrow> FNone))
   | GDim gd fct oponly \<Rightarrow> (if verdict s \<noteq> None then FNone else if oponly \<and> d = 0 then FNone else
       (case core_math (rest_of s) gd of
          None \<Rightarrow> FNone
        | Some cm \<Rightarrow> (if cm / fct < 0 then FNone
            else if d = 0 \<and> length p = 1 then FSingle
            else if d = 0 \<and> (\<exists>q\<in>set p. qdim q = gd \<and> amount q = cm) then FNone
            else FDone (FVal (cm / fct))))))"

text \<open>A plan completes when it runs from the givens and FINISH accepts its
end state at its own depth; its value is what FINISH gives.\<close>
definition fin_of :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> goal \<Rightarrow> quantity list \<Rightarrow> step list \<Rightarrow> fin option" where
  "fin_of nd ops c g p pl = (case run_plan nd ops c p (start_st p) pl of
     None \<Rightarrow> None
   | Some s \<Rightarrow> (case finish g p s (length pl) of FDone f \<Rightarrow> Some f | _ \<Rightarrow> None))"

definition complete :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> goal \<Rightarrow> quantity list \<Rightarrow> step list \<Rightarrow> bool" where
  "complete nd ops c g p pl \<longleftrightarrow> fin_of nd ops c g p pl \<noteq> None"


section \<open>EXPAND and breadth-first search (network_v3._expand, solve)\<close>

fun lprod :: "'a list list \<Rightarrow> 'a list list" where
  "lprod [] = [[]]"
| "lprod (xs # xss) = concat (map (\<lambda>x. map ((#) x) (lprod xss)) xs)"

text \<open>Fillers in network_v3's order: pool entries, then derived pairs.\<close>
definition fillers :: "quantity list \<Rightarrow> st \<Rightarrow> dimv \<times> (quantity \<Rightarrow> bool) \<Rightarrow> arg list" where
  "fillers p s sl = filter (slot_ok p s sl)
     (map Pool (avail s) @ concat (map (\<lambda>i. map (Derive i) (avail s)) (avail s)))"

definition cands :: "fop list \<Rightarrow> quantity list \<Rightarrow> st \<Rightarrow> step list" where
  "cands ops p s = concat (map (\<lambda>f. map (Step f) (lprod (map (fillers p s) (slots f)))) ops)"

definition expansions :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> st \<Rightarrow> st list" where
  "expansions nd ops c p s = List.map_filter (apply_step nd ops c p s) (cands ops p s)"

text \<open>Two states with the same key have the same future: the same available
entries (index and full quantity), pool length and verdict.\<close>
definition skey :: "st \<Rightarrow> nat \<times> (nat \<times> quantity) list \<times> bool option" where
  "skey s = (length (pool s), map (\<lambda>k. (k, pool s ! k)) (avail s), verdict s)"

fun dedup :: "(nat \<times> (nat \<times> quantity) list \<times> bool option) list \<Rightarrow> st list \<Rightarrow> st list" where
  "dedup seen [] = []"
| "dedup seen (s # ss) = (if skey s \<in> set seen then dedup seen ss else s # dedup (skey s # seen) ss)"

definition done_of :: "goal \<Rightarrow> quantity list \<Rightarrow> nat \<Rightarrow> st list \<Rightarrow> (fin \<times> st) list" where
  "done_of g p d fr = List.map_filter (\<lambda>s. case finish g p s d of FDone f \<Rightarrow> Some (f, s) | _ \<Rightarrow> None) fr"

definition max_ops :: nat where "max_ops = 3"
definition max_states :: nat where "max_states = 3000"

datatype sres = SDone nat "(fin \<times> st) list" | SSingle | SBudget | SNone

text \<open>The frontier at depth @{text d}: stop on a single conversion, stop with
the complete plans if any, else expand (counting new states against the
budget) while depth remains.\<close>
fun bfs :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> goal \<Rightarrow> quantity list \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> st list \<Rightarrow> sres" where
  "bfs nd ops c g p 0 d cnt fr =
     (if list_ex (\<lambda>s. finish g p s d = FSingle) fr then SSingle
      else if done_of g p d fr \<noteq> [] then SDone d (done_of g p d fr) else SNone)"
| "bfs nd ops c g p (Suc n) d cnt fr =
     (if list_ex (\<lambda>s. finish g p s d = FSingle) fr then SSingle
      else if done_of g p d fr \<noteq> [] then SDone d (done_of g p d fr)
      else (let nxt = dedup [] (concat (map (expansions nd ops c p) fr)) in
            if max_states < cnt + length nxt then SBudget
            else if nxt = [] then SNone
            else bfs nd ops c g p n (Suc d) (cnt + length nxt) nxt))"

definition search :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> goal \<Rightarrow> quantity list \<Rightarrow> sres" where
  "search nd ops c g p = bfs nd ops c g p max_ops 0 0 [start_st p]"


section \<open>AGREE and the decision\<close>

definition agree_tol :: rat where "agree_tol = 1 / 200"

text \<open>network_v3._same: within 0.5 percent of the larger magnitude.\<close>
definition near :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "near a b \<longleftrightarrow> \<bar>a - b\<bar> \<le> agree_tol * max (max \<bar>a\<bar> \<bar>b\<bar>) (1 / 10 ^ 12)"

fun same_fin :: "fin \<Rightarrow> fin \<Rightarrow> bool" where
  "same_fin (FVal a) (FVal b) = near a b"
| "same_fin (FBool a) (FBool b) = (a = b)"
| "same_fin _ _ = False"

text \<open>@{text Anchor} is network_v3 as shipped: every value is compared with
the FIRST complete plan found. @{text Pairwise} is its docstring's rule:
every two complete plans agree.\<close>
datatype agree_mode = Anchor | Pairwise

fun agree :: "agree_mode \<Rightarrow> fin list \<Rightarrow> bool" where
  "agree Anchor [] = True"
| "agree Anchor (v # vs) = (\<forall>w\<in>set vs. same_fin v w)"
| "agree Pairwise vs = (\<forall>v\<in>set vs. \<forall>w\<in>set vs. same_fin v w)"

text \<open>Path memory (network_v3: @{text "done.sort(key=... != remembered ops)"}):
after AGREE, a complete plan with the remembered operation sequence is
stated first.\<close>
definition pick :: "fop list option \<Rightarrow> (fin \<times> st) list \<Rightarrow> fin \<times> st" where
  "pick mem dn = (case mem of None \<Rightarrow> hd dn | Some ns \<Rightarrow>
     (case find (\<lambda>x. map step_op (steps (snd x)) = ns) dn of Some x \<Rightarrow> x | None \<Rightarrow> hd dn))"

datatype decision = Answer fin "step list" | Disagree "step list list" | NoPlan | BudgetExceeded
  | SingleConversion | Invalid nat nat

definition decide :: "nodefn \<Rightarrow> fop list \<Rightarrow> agree_mode \<Rightarrow> fop list option \<Rightarrow> goal \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> decision" where
  "decide nd ops m mem g c p =
     (case find (\<lambda>i. invalid_why (p ! i) \<noteq> None) [0..<length p] of
        Some i \<Rightarrow> Invalid i (the (invalid_why (p ! i)))
      | None \<Rightarrow> (case search nd ops c g p of
          SSingle \<Rightarrow> SingleConversion
        | SBudget \<Rightarrow> BudgetExceeded
        | SNone \<Rightarrow> NoPlan
        | SDone d dn \<Rightarrow> (if agree m (map fst dn)
            then Answer (fst (pick mem dn)) (steps (snd (pick mem dn)))
            else Disagree (map (steps \<circ> snd) dn))))"


section \<open>Basic facts about steps and runs\<close>

lemma set_map_filter: "set (List.map_filter f xs) = {y. \<exists>x\<in>set xs. f x = Some y}"
  by (induction xs) (auto simp: List.map_filter_simps split: option.splits)

lemma apply_step_Some:
  "apply_step nd ops c p s (Step f as) = Some t \<longleftrightarrow>
    verdict s = None \<and> f \<in> set ops \<and> list_all2 (slot_ok p s) (slots f) as \<and>
    distinct (concat (map arg_uses as)) \<and> admits f c (arg_qs s f as) \<and>
    ((\<exists>v. nd f c (arg_qs s f as) = Some (NVal v) \<and>
        t = \<lparr>pool = pool s @ [newq f v],
             avail = filter (\<lambda>k. k \<notin> set (concat (map arg_uses as))) (avail s) @ [length (pool s)],
             steps = steps s @ [Step f as], verdict = None\<rparr>) \<or>
     (\<exists>b. nd f c (arg_qs s f as) = Some (NBool b) \<and>
        t = \<lparr>pool = pool s, avail = filter (\<lambda>k. k \<notin> set (concat (map arg_uses as))) (avail s),
             steps = steps s @ [Step f as], verdict = Some b\<rparr>))"
  by (auto simp: apply_step_def split: option.splits nres.splits)

lemma apply_steps: "apply_step nd ops c p s x = Some t \<Longrightarrow> steps t = steps s @ [x]"
  by (cases x) (auto simp: apply_step_Some)

lemma run_snoc:
  "run_plan nd ops c p s (xs @ [x]) =
     (case run_plan nd ops c p s xs of None \<Rightarrow> None | Some t \<Rightarrow> apply_step nd ops c p t x)"
  by (induction xs arbitrary: s) (auto split: option.splits)

lemma run_steps: "run_plan nd ops c p s xs = Some t \<Longrightarrow> steps t = steps s @ xs"
  by (induction xs arbitrary: s) (auto split: option.splits dest: apply_steps)

definition wfs :: "st \<Rightarrow> bool" where
  "wfs s \<longleftrightarrow> (\<forall>k\<in>set (avail s). k < length (pool s))"

lemma wfs_start: "wfs (start_st p)"
  by (simp add: wfs_def start_st_def)

lemma apply_wfs: "apply_step nd ops c p s x = Some t \<Longrightarrow> wfs s \<Longrightarrow> wfs t"
  by (cases x) (auto simp: apply_step_Some wfs_def less_Suc_eq)

lemma run_wfs: "run_plan nd ops c p s xs = Some t \<Longrightarrow> wfs s \<Longrightarrow> wfs t"
  by (induction xs arbitrary: s) (auto split: option.splits dest: apply_wfs)

lemma slot_uses: "slot_ok p s sl a \<Longrightarrow> set (arg_uses a) \<subseteq> set (avail s)"
  by (cases sl; cases a) auto

lemma all_uses:
  "list_all2 (slot_ok p s) sls as \<Longrightarrow> set (concat (map arg_uses as)) \<subseteq> set (avail s)"
  by (induction sls as rule: list_all2_induct) (auto dest: slot_uses)


section \<open>Every given is used exactly once\<close>

definition used_ok :: "quantity list \<Rightarrow> st \<Rightarrow> bool" where
  "used_ok p s \<longleftrightarrow> distinct (concat (map step_uses (steps s)) @ avail s) \<and>
     set (concat (map step_uses (steps s)) @ avail s) = {..<length (pool s)} \<and>
     length p \<le> length (pool s)"

lemma used_ok_start: "used_ok p (start_st p)"
  by (auto simp: used_ok_def start_st_def)

lemma apply_used_ok:
  assumes a: "apply_step nd ops c p s x = Some t" and u: "used_ok p s"
  shows "used_ok p t"
proof (cases x)
  case (Step f as)
  define U where "U = concat (map arg_uses as)"
  define Ou where "Ou = concat (map step_uses (steps s))"
  define F where "F = filter (\<lambda>k. k \<notin> set U) (avail s)"
  have la: "list_all2 (slot_ok p s) (slots f) as" and dU: "distinct U"
    using a Step by (auto simp: apply_step_Some U_def)
  have sub: "set U \<subseteq> set (avail s)" using all_uses[OF la] by (simp add: U_def)
  have dOA: "distinct (Ou @ avail s)" and sOA: "set (Ou @ avail s) = {..<length (pool s)}"
    and lp: "length p \<le> length (pool s)" using u by (auto simp: used_ok_def Ou_def)
  have dO: "distinct Ou" and dA: "distinct (avail s)" and dis: "set Ou \<inter> set (avail s) = {}"
    using dOA by auto
  have dF: "distinct F" using dA by (simp add: F_def)
  have FA: "set F \<subseteq> set (avail s)" by (auto simp: F_def)
  have UF: "set U \<inter> set F = {}" by (auto simp: F_def)
  have UFA: "set U \<union> set F = set (avail s)" using sub by (auto simp: F_def)
  have dOUF: "distinct (Ou @ U @ F)"
    using dO dU dF UF sub FA dis by (auto simp: distinct_append)
  have sOUF: "set (Ou @ U @ F) = {..<length (pool s)}" using sOA UFA by auto
  have su: "step_uses x = U" by (simp add: Step U_def)
  show ?thesis
  proof (cases "\<exists>v. nd f c (arg_qs s f as) = Some (NVal v)")
    case True
    then obtain v where t: "t = \<lparr>pool = pool s @ [newq f v], avail = F @ [length (pool s)],
             steps = steps s @ [x], verdict = None\<rparr>"
      using a Step by (auto simp: apply_step_Some F_def U_def)
    have n: "length (pool s) \<notin> set (Ou @ U @ F)" using sOUF by auto
    have "distinct ((Ou @ U @ F) @ [length (pool s)])" using dOUF n by simp
    moreover have "set ((Ou @ U @ F) @ [length (pool s)]) = {..<Suc (length (pool s))}"
      using sOUF by (auto simp: lessThan_Suc)
    ultimately show ?thesis using t lp su by (simp add: used_ok_def Ou_def)
  next
    case False
    then obtain b where t: "t = \<lparr>pool = pool s, avail = F, steps = steps s @ [x], verdict = Some b\<rparr>"
      using a Step by (auto simp: apply_step_Some F_def U_def)
    show ?thesis using t lp su dOUF sOUF by (simp add: used_ok_def Ou_def)
  qed
qed

lemma run_used_ok: "run_plan nd ops c p s xs = Some t \<Longrightarrow> used_ok p s \<Longrightarrow> used_ok p t"
  by (induction xs arbitrary: s) (auto split: option.splits dest: apply_used_ok)

text \<open>Along any plan that runs from the givens, every given index is used
by exactly one step or is still available for FINISH's core math, which uses
everything still available; no index is used twice.\<close>
theorem every_given_used_once:
  assumes "run_plan nd ops c p (start_st p) pl = Some s"
  shows "distinct (concat (map step_uses pl) @ avail s) \<and>
         {..<length p} \<subseteq> set (concat (map step_uses pl) @ avail s)"
proof -
  have u: "used_ok p s" by (rule run_used_ok[OF assms used_ok_start])
  have "steps s = pl" using run_steps[OF assms] by (simp add: start_st_def)
  then show ?thesis using u by (auto simp: used_ok_def)
qed


section \<open>Soundness of the search\<close>

definition reach :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> nat \<Rightarrow> st \<Rightarrow> bool" where
  "reach nd ops c p d s \<longleftrightarrow>
     run_plan nd ops c p (start_st p) (steps s) = Some s \<and> length (steps s) = d \<and> wfs s"

lemma reach_start: "reach nd ops c p 0 (start_st p)"
  by (simp add: reach_def start_st_def wfs_def)

lemma expansions_iff:
  "t \<in> set (expansions nd ops c p s) \<longleftrightarrow> (\<exists>x\<in>set (cands ops p s). apply_step nd ops c p s x = Some t)"
  by (auto simp: expansions_def set_map_filter)

lemma expansions_reach:
  assumes r: "reach nd ops c p d s" and t: "t \<in> set (expansions nd ops c p s)"
  shows "reach nd ops c p (Suc d) t"
proof -
  obtain x where a: "apply_step nd ops c p s x = Some t" using t by (auto simp: expansions_iff)
  have st: "steps t = steps s @ [x]" by (rule apply_steps[OF a])
  have "run_plan nd ops c p (start_st p) (steps t) = Some t"
    using r a st by (simp add: reach_def run_snoc)
  moreover have "wfs t" using r a apply_wfs by (auto simp: reach_def)
  ultimately show ?thesis using r st by (simp add: reach_def)
qed

lemma dedup_subset: "set (dedup seen xs) \<subseteq> set xs"
  by (induction seen xs rule: dedup.induct) auto

lemma dedup_cover: "s \<in> set xs \<Longrightarrow> skey s \<notin> set seen \<Longrightarrow> \<exists>t\<in>set (dedup seen xs). skey t = skey s"
proof (induction seen xs rule: dedup.induct)
  case (1 seen)
  then show ?case by simp
next
  case (2 seen s' ss)
  show ?case
  proof (cases "skey s' \<in> set seen")
    case True
    then have "s \<noteq> s'" using 2 by auto
    then have "s \<in> set ss" using 2 by simp
    then show ?thesis using 2 True by simp
  next
    case False
    show ?thesis
    proof (cases "skey s = skey s'")
      case True
      then show ?thesis using False by auto
    next
      case ne: False
      then have "s \<in> set ss" using 2 by auto
      moreover have "skey s \<notin> set (skey s' # seen)" using ne 2 by simp
      ultimately show ?thesis using 2 False by auto
    qed
  qed
qed

lemma done_of_iff: "x \<in> set (done_of g p d fr) \<longleftrightarrow> snd x \<in> set fr \<and> finish g p (snd x) d = FDone (fst x)"
proof -
  have h: "\<And>s y. (case finish g p s d of FDone f \<Rightarrow> Some (f, s) | _ \<Rightarrow> None) = Some y \<longleftrightarrow>
      finish g p s d = FDone (fst y) \<and> snd y = s"
    by (auto split: fres.splits)
  show ?thesis by (auto simp: done_of_def set_map_filter h)
qed

lemma bfs_sound:
  assumes "\<forall>s\<in>set fr. reach nd ops c p d s" "bfs nd ops c g p fuel d cnt fr = SDone d' dn"
  shows "d \<le> d' \<and> d' \<le> d + fuel \<and> dn \<noteq> [] \<and>
         (\<forall>x\<in>set dn. finish g p (snd x) d' = FDone (fst x) \<and> reach nd ops c p d' (snd x))"
  using assms
proof (induction fuel arbitrary: d cnt fr)
  case 0
  then show ?case by (auto simp: done_of_iff split: if_splits)
next
  case (Suc n)
  show ?case
  proof (cases "list_ex (\<lambda>s. finish g p s d = FSingle) fr \<or> done_of g p d fr \<noteq> []")
    case True
    then show ?thesis using Suc.prems by (auto simp: done_of_iff split: if_splits)
  next
    case False
    define nxt where "nxt = dedup [] (concat (map (expansions nd ops c p) fr))"
    have b: "bfs nd ops c g p (Suc n) d cnt fr = (if max_states < cnt + length nxt then SBudget
        else if nxt = [] then SNone else bfs nd ops c g p n (Suc d) (cnt + length nxt) nxt)"
      using False by (simp add: nxt_def Let_def)
    have r: "bfs nd ops c g p n (Suc d) (cnt + length nxt) nxt = SDone d' dn"
      using Suc.prems(2) b by (auto split: if_splits)
    have "\<forall>s\<in>set nxt. reach nd ops c p (Suc d) s"
    proof
      fix s assume "s \<in> set nxt"
      then have "s \<in> set (concat (map (expansions nd ops c p) fr))"
        using dedup_subset unfolding nxt_def by blast
      then obtain t where "t \<in> set fr" "s \<in> set (expansions nd ops c p t)" by auto
      then show "reach nd ops c p (Suc d) s" using Suc.prems(1) expansions_reach by blast
    qed
    from Suc.IH[OF this r] show ?thesis by auto
  qed
qed

lemma find_in: "find P xs = Some x \<Longrightarrow> x \<in> set xs"
  by (induction xs) (auto split: if_splits)

lemma pick_in: "dn \<noteq> [] \<Longrightarrow> pick mem dn \<in> set dn"
  by (auto simp: pick_def hd_in_set split: option.splits dest: find_in)

lemma decide_AnswerD:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "\<exists>d dn. search nd ops c g p = SDone d dn \<and> agree m (map fst dn) \<and>
           v = fst (pick mem dn) \<and> pl = steps (snd (pick mem dn))"
  using assms by (auto simp: decide_def split: option.splits sres.splits if_splits)

lemma answer_state:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "\<exists>d dn s. search nd ops c g p = SDone d dn \<and> agree m (map fst dn) \<and> (v, s) \<in> set dn \<and>
     pick mem dn = (v, s) \<and> pl = steps s \<and> length pl = d \<and> d \<le> max_ops \<and>
     run_plan nd ops c p (start_st p) pl = Some s \<and> finish g p s d = FDone v"
proof -
  obtain d dn where sd: "search nd ops c g p = SDone d dn" and ag: "agree m (map fst dn)"
    and v: "v = fst (pick mem dn)" and pl: "pl = steps (snd (pick mem dn))"
    using decide_AnswerD[OF assms] by blast
  have r0: "\<forall>s\<in>set [start_st p]. reach nd ops c p 0 s" using reach_start by simp
  have sd': "bfs nd ops c g p max_ops 0 0 [start_st p] = SDone d dn" using sd by (simp add: search_def)
  have bs: "0 \<le> d \<and> d \<le> 0 + max_ops \<and> dn \<noteq> [] \<and>
      (\<forall>x\<in>set dn. finish g p (snd x) d = FDone (fst x) \<and> reach nd ops c p d (snd x))"
    by (rule bfs_sound[OF r0 sd'])
  define s where "s = snd (pick mem dn)"
  have pin: "pick mem dn \<in> set dn" using pick_in bs by blast
  have pv: "pick mem dn = (v, s)" using v s_def by simp
  have fr: "finish g p s d = FDone v \<and> reach nd ops c p d s" using bs pin pv by auto
  have pls: "pl = steps s" using pl unfolding s_def by simp
  have rl: "run_plan nd ops c p (start_st p) pl = Some s \<and> length pl = d"
    using fr pls by (simp add: reach_def)
  have vin: "(v, s) \<in> set dn" using pin pv by simp
  have dm: "d \<le> max_ops" using bs by simp
  show ?thesis using sd ag vin pv pls dm rl fr by blast
qed

text \<open>An answer comes with a plan that runs from the givens and completes,
and the answer is that plan's value.\<close>
theorem answer_has_complete_plan:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "complete nd ops c g p pl \<and> fin_of nd ops c g p pl = Some v"
  using answer_state[OF assms] by (auto simp: complete_def fin_of_def)

text \<open>No answer uses more than three operations.\<close>
theorem depth_bound:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "length pl \<le> 3"
  using answer_state[OF assms] by (auto simp: max_ops_def)


section \<open>Completeness of the search up to state keys\<close>

lemma skey_eqD:
  assumes "skey s = skey t"
  shows "avail s = avail t \<and> verdict s = verdict t \<and> length (pool s) = length (pool t) \<and>
         (\<forall>k\<in>set (avail s). pool s ! k = pool t ! k)"
proof -
  have m: "map (\<lambda>k. (k, pool s ! k)) (avail s) = map (\<lambda>k. (k, pool t ! k)) (avail t)"
    and v: "verdict s = verdict t" and l: "length (pool s) = length (pool t)"
    using assms by (simp_all add: skey_def)
  have "map fst (map (\<lambda>k. (k, pool s ! k)) (avail s)) = map fst (map (\<lambda>k. (k, pool t ! k)) (avail t))"
    using m by simp
  then have a: "avail s = avail t" by (simp add: comp_def)
  then have "map (\<lambda>k. (k, pool s ! k)) (avail s) = map (\<lambda>k. (k, pool t ! k)) (avail s)" using m by simp
  then have "\<forall>k\<in>set (avail s). pool s ! k = pool t ! k" by (simp add: map_eq_conv)
  then show ?thesis using a v l by simp
qed

lemma rest_skey: "rest_of s = map snd (fst (snd (skey s)))"
  by (simp add: rest_of_def skey_def comp_def)

lemma finish_skey: "skey s = skey t \<Longrightarrow> finish g p s d = finish g p t d"
proof -
  assume k: "skey s = skey t"
  have r: "rest_of s = rest_of t" using k by (simp add: rest_skey)
  have v: "verdict s = verdict t" using skey_eqD[OF k] by simp
  show ?thesis unfolding finish_def by (simp only: r v)
qed

lemma slot_ok_skey:
  assumes "skey s = skey t"
  shows "slot_ok p s = slot_ok p t"
proof (intro ext)
  fix sl a
  have e: "avail s = avail t" "length (pool s) = length (pool t)"
    "\<And>k. k \<in> set (avail s) \<Longrightarrow> pool s ! k = pool t ! k"
    using skey_eqD[OF assms] by auto
  show "slot_ok p s sl a = slot_ok p t sl a"
    by (cases sl; cases a) (auto simp: e)
qed

lemma arg_q_skey:
  assumes k: "skey s = skey t" and so: "slot_ok p s sl a"
  shows "arg_q s d a = arg_q t d a"
proof -
  have e: "\<forall>k\<in>set (avail s). pool s ! k = pool t ! k" using skey_eqD[OF k] by simp
  show ?thesis using so e by (cases sl; cases a) auto
qed

lemma arg_qs_skey:
  assumes k: "skey s = skey t" and la: "list_all2 (slot_ok p s) (slots f) as"
  shows "arg_qs s f as = arg_qs t f as"
proof -
  have z: "\<forall>(sl, a)\<in>set (zip (slots f) as). slot_ok p s sl a"
    using la by (simp add: list_all2_iff)
  have "\<forall>x\<in>set (zip (slots f) as). (\<lambda>(sl, a). arg_q s (fst sl) a) x = (\<lambda>(sl, a). arg_q t (fst sl) a) x"
  proof
    fix x assume "x \<in> set (zip (slots f) as)"
    then obtain sl a where x: "x = (sl, a)" "slot_ok p s sl a" using z by (cases x) auto
    then show "(\<lambda>(sl, a). arg_q s (fst sl) a) x = (\<lambda>(sl, a). arg_q t (fst sl) a) x"
      using arg_q_skey[OF k] by simp
  qed
  then show ?thesis unfolding arg_qs_def by (simp add: map_eq_conv)
qed

lemma skey_extend:
  assumes k: "skey s = skey t" and ws: "wfs s" and wt: "wfs t"
  shows "map (\<lambda>k. (k, (pool s @ [q]) ! k)) (filter P (avail s) @ [length (pool s)]) =
         map (\<lambda>k. (k, (pool t @ [q]) ! k)) (filter P (avail t) @ [length (pool t)])"
proof -
  have e: "avail s = avail t \<and> verdict s = verdict t \<and> length (pool s) = length (pool t) \<and>
         (\<forall>k\<in>set (avail s). pool s ! k = pool t ! k)" by (rule skey_eqD[OF k])
  have h: "\<forall>k\<in>set (filter P (avail s)). (pool s @ [q]) ! k = (pool t @ [q]) ! k"
    using ws wt e by (auto simp: wfs_def nth_append)
  have m: "map (\<lambda>k. (k, (pool s @ [q]) ! k)) (filter P (avail s)) =
           map (\<lambda>k. (k, (pool t @ [q]) ! k)) (filter P (avail t))"
    using h e by (auto simp: map_eq_conv)
  have l: "(pool s @ [q]) ! length (pool s) = (pool t @ [q]) ! length (pool t)" by simp
  have l2: "length (pool s) = length (pool t)" using e by simp
  show ?thesis using m l l2 by simp
qed

lemma skey_keep:
  assumes k: "skey s = skey t"
  shows "map (\<lambda>k. (k, pool s ! k)) (filter P (avail s)) = map (\<lambda>k. (k, pool t ! k)) (filter P (avail t))"
proof -
  have e: "avail s = avail t \<and> verdict s = verdict t \<and> length (pool s) = length (pool t) \<and>
         (\<forall>k\<in>set (avail s). pool s ! k = pool t ! k)" by (rule skey_eqD[OF k])
  then show ?thesis by (auto simp: map_eq_conv)
qed

lemma apply_skey:
  assumes k: "skey s = skey t" and ws: "wfs s" and wt: "wfs t"
    and a: "apply_step nd ops c p s x = Some s'"
  shows "\<exists>t'. apply_step nd ops c p t x = Some t' \<and> skey t' = skey s'"
proof (cases x)
  case (Step f as)
  have e: "avail s = avail t" "verdict s = verdict t" "length (pool s) = length (pool t)"
    using skey_eqD[OF k] by auto
  have so: "slot_ok p s = slot_ok p t" by (rule slot_ok_skey[OF k])
  have la: "list_all2 (slot_ok p s) (slots f) as" using a Step by (simp add: apply_step_Some)
  have aq: "arg_qs s f as = arg_qs t f as" by (rule arg_qs_skey[OF k la])
  define P where "P = (\<lambda>k. k \<notin> set (concat (map arg_uses as)))"
  show ?thesis
  proof (cases "\<exists>v. nd f c (arg_qs s f as) = Some (NVal v)")
    case True
    then obtain v where nv: "nd f c (arg_qs s f as) = Some (NVal v)" by blast
    have s': "s' = \<lparr>pool = pool s @ [newq f v], avail = filter P (avail s) @ [length (pool s)],
             steps = steps s @ [Step f as], verdict = None\<rparr>"
      using a Step nv by (auto simp: apply_step_Some P_def)
    define t' where "t' = \<lparr>pool = pool t @ [newq f v], avail = filter P (avail t) @ [length (pool t)],
             steps = steps t @ [Step f as], verdict = None\<rparr>"
    have "apply_step nd ops c p t x = Some t'"
      using a Step nv aq so e by (auto simp: apply_step_Some t'_def P_def)
    moreover have "skey t' = skey s'"
      using skey_extend[OF k ws wt, of "newq f v" P] e s' by (simp add: skey_def t'_def)
    ultimately show ?thesis by blast
  next
    case False
    then obtain b where nb: "nd f c (arg_qs s f as) = Some (NBool b)"
      using a Step by (auto simp: apply_step_Some)
    have s': "s' = \<lparr>pool = pool s, avail = filter P (avail s), steps = steps s @ [Step f as], verdict = Some b\<rparr>"
      using a Step nb by (auto simp: apply_step_Some P_def)
    define t' where "t' = \<lparr>pool = pool t, avail = filter P (avail t), steps = steps t @ [Step f as], verdict = Some b\<rparr>"
    have "apply_step nd ops c p t x = Some t'"
      using a Step nb aq so e by (auto simp: apply_step_Some t'_def P_def)
    moreover have "skey t' = skey s'"
      using skey_keep[OF k, of P] e s' by (simp add: skey_def t'_def)
    ultimately show ?thesis by blast
  qed
qed

lemma in_lprod: "ys \<in> set (lprod xss) \<longleftrightarrow> list_all2 (\<lambda>xs y. y \<in> set xs) xss ys"
  by (induction xss arbitrary: ys) (auto simp: list_all2_Cons1)

lemma fillers_iff: "a \<in> set (fillers p s sl) \<longleftrightarrow> slot_ok p s sl a"
  by (cases sl; cases a) (auto simp: fillers_def)

lemma cands_complete:
  assumes "apply_step nd ops c p s x = Some t"
  shows "x \<in> set (cands ops p s)"
proof (cases x)
  case (Step f as)
  have f: "f \<in> set ops" and la: "list_all2 (slot_ok p s) (slots f) as"
    using assms Step by (auto simp: apply_step_Some)
  have "list_all2 (\<lambda>xs y. y \<in> set xs) (map (fillers p s) (slots f)) as"
    using la by (simp add: list_all2_map1 fillers_iff)
  then have "as \<in> set (lprod (map (fillers p s) (slots f)))" by (simp add: in_lprod)
  then show ?thesis using f Step by (auto simp: cands_def)
qed

definition covers :: "nodefn \<Rightarrow> fop list \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> nat \<Rightarrow> st list \<Rightarrow> bool" where
  "covers nd ops c p d fr \<longleftrightarrow> (\<forall>pl s. length pl = d \<longrightarrow> run_plan nd ops c p (start_st p) pl = Some s \<longrightarrow>
     (\<exists>t\<in>set fr. skey t = skey s))"

lemma covers_start: "covers nd ops c p 0 [start_st p]"
  by (simp add: covers_def)

lemma covers_step:
  assumes r: "\<forall>s\<in>set fr. reach nd ops c p d s" and cv: "covers nd ops c p d fr"
  shows "covers nd ops c p (Suc d) (dedup [] (concat (map (expansions nd ops c p) fr)))"
  unfolding covers_def
proof (intro allI impI)
  fix pl s
  assume len: "length pl = Suc d" and run: "run_plan nd ops c p (start_st p) pl = Some s"
  obtain pl0 x where pl: "pl = pl0 @ [x]"
    using len by (cases pl rule: rev_cases) auto
  have l0: "length pl0 = d" using len pl by simp
  obtain s0 where r0: "run_plan nd ops c p (start_st p) pl0 = Some s0"
    and a0: "apply_step nd ops c p s0 x = Some s"
    using run pl by (auto simp: run_snoc split: option.splits)
  obtain t0 where t0: "t0 \<in> set fr" "skey t0 = skey s0" using cv l0 r0 by (auto simp: covers_def)
  have w0: "wfs s0" using run_wfs[OF r0 wfs_start] .
  have wt: "wfs t0" using r t0 by (auto simp: reach_def)
  obtain t1 where a1: "apply_step nd ops c p t0 x = Some t1" and k1: "skey t1 = skey s"
    using apply_skey[OF t0(2)[symmetric] w0 wt a0] by blast
  have "x \<in> set (cands ops p t0)" by (rule cands_complete[OF a1])
  then have "t1 \<in> set (expansions nd ops c p t0)" using a1 by (auto simp: expansions_iff)
  then have "t1 \<in> set (concat (map (expansions nd ops c p) fr))" using t0 by auto
  then have "\<exists>t\<in>set (dedup [] (concat (map (expansions nd ops c p) fr))). skey t = skey t1"
    by (rule dedup_cover) simp
  then obtain t where "t \<in> set (dedup [] (concat (map (expansions nd ops c p) fr)))" "skey t = skey t1"
    by blast
  then show "\<exists>t\<in>set (dedup [] (concat (map (expansions nd ops c p) fr))). skey t = skey s"
    using k1 by auto
qed

lemma bfs_complete:
  assumes "\<forall>s\<in>set fr. reach nd ops c p d s" "covers nd ops c p d fr"
    "bfs nd ops c g p fuel d cnt fr = SDone d' dn"
  shows "(\<forall>pl::step list. d \<le> length pl \<and> length pl < d' \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>(pl::step list) f. length pl = d' \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
  using assms
proof (induction fuel arbitrary: d cnt fr)
  case 0
  have dd: "d' = d" "dn = done_of g p d fr" using "0.prems"(3) by (auto split: if_splits)
  have "\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn"
  proof (intro allI impI)
    fix pl :: "step list" and f assume h: "length pl = d \<and> fin_of nd ops c g p pl = Some f"
    then obtain s where rs: "run_plan nd ops c p (start_st p) pl = Some s" and fs: "finish g p s d = FDone f"
      by (auto simp: fin_of_def split: option.splits fres.splits)
    obtain t where t: "t \<in> set fr" "skey t = skey s" using "0.prems"(2) h rs by (auto simp: covers_def)
    have "finish g p t d = FDone f" using fs finish_skey[OF t(2)] by simp
    then have "(f, t) \<in> set dn" using t dd by (simp add: done_of_iff)
    then show "f \<in> fst ` set dn" by force
  qed
  then show ?case using dd by auto
next
  case (Suc n)
  have no_fin: "\<forall>pl. length pl = d \<longrightarrow> fin_of nd ops c g p pl = None"
    if nd0: "done_of g p d fr = []"
  proof (intro allI impI)
    fix pl :: "step list" assume l: "length pl = d"
    show "fin_of nd ops c g p pl = None"
    proof (rule ccontr)
      assume "fin_of nd ops c g p pl \<noteq> None"
      then obtain f s where rs: "run_plan nd ops c p (start_st p) pl = Some s" and fs: "finish g p s d = FDone f"
        using l by (auto simp: fin_of_def split: option.splits fres.splits)
      obtain t where t: "t \<in> set fr" "skey t = skey s" using Suc.prems(2) l rs by (auto simp: covers_def)
      have "finish g p t d = FDone f" using fs finish_skey[OF t(2)] by simp
      then have "(f, t) \<in> set (done_of g p d fr)" using t by (simp add: done_of_iff)
      then show False using nd0 by simp
    qed
  qed
  show ?case
  proof (cases "list_ex (\<lambda>s. finish g p s d = FSingle) fr \<or> done_of g p d fr \<noteq> []")
    case True
    then have dd: "d' = d" "dn = done_of g p d fr" using Suc.prems(3) by (auto split: if_splits)
    have "\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn"
    proof (intro allI impI)
      fix pl :: "step list" and f assume h: "length pl = d \<and> fin_of nd ops c g p pl = Some f"
      then obtain s where rs: "run_plan nd ops c p (start_st p) pl = Some s" and fs: "finish g p s d = FDone f"
        by (auto simp: fin_of_def split: option.splits fres.splits)
      obtain t where t: "t \<in> set fr" "skey t = skey s" using Suc.prems(2) h rs by (auto simp: covers_def)
      have "finish g p t d = FDone f" using fs finish_skey[OF t(2)] by simp
      then have "(f, t) \<in> set dn" using t dd by (simp add: done_of_iff)
      then show "f \<in> fst ` set dn" by force
    qed
    then show ?thesis using dd by auto
  next
    case False
    define nxt where "nxt = dedup [] (concat (map (expansions nd ops c p) fr))"
    have b: "bfs nd ops c g p (Suc n) d cnt fr = (if max_states < cnt + length nxt then SBudget
        else if nxt = [] then SNone else bfs nd ops c g p n (Suc d) (cnt + length nxt) nxt)"
      using False by (simp add: nxt_def Let_def)
    have r: "bfs nd ops c g p n (Suc d) (cnt + length nxt) nxt = SDone d' dn"
      using Suc.prems(3) b by (auto split: if_splits)
    have rn: "\<forall>s\<in>set nxt. reach nd ops c p (Suc d) s"
    proof
      fix s assume "s \<in> set nxt"
      then have "s \<in> set (concat (map (expansions nd ops c p) fr))"
        using dedup_subset unfolding nxt_def by blast
      then obtain t where "t \<in> set fr" "s \<in> set (expansions nd ops c p t)" by auto
      then show "reach nd ops c p (Suc d) s" using Suc.prems(1) expansions_reach by blast
    qed
    have cn: "covers nd ops c p (Suc d) nxt" unfolding nxt_def by (rule covers_step[OF Suc.prems(1,2)])
    have ih: "(\<forall>pl. Suc d \<le> length pl \<and> length pl < d' \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>pl f. length pl = d' \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
      by (rule Suc.IH[OF rn cn r])
    have nd0: "done_of g p d fr = []" using False by simp
    have nfd: "\<forall>pl. length pl = d \<longrightarrow> fin_of nd ops c g p pl = None" by (rule no_fin[OF nd0])
    have "\<forall>pl. d \<le> length pl \<and> length pl < d' \<longrightarrow> fin_of nd ops c g p pl = None"
    proof (intro allI impI)
      fix pl :: "step list" assume h: "d \<le> length pl \<and> length pl < d'"
      show "fin_of nd ops c g p pl = None"
      proof (cases "length pl = d")
        case True
        then show ?thesis using nfd by blast
      next
        case False
        then have "Suc d \<le> length pl" using h by simp
        then show ?thesis using ih h by blast
      qed
    qed
    then show ?thesis using ih by blast
  qed
qed

lemma search_complete:
  assumes "search nd ops c g p = SDone d dn"
  shows "(\<forall>pl. length pl < d \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
proof -
  have r0: "\<forall>s\<in>set [start_st p]. reach nd ops c p 0 s" using reach_start by simp
  have sd: "bfs nd ops c g p max_ops 0 0 [start_st p] = SDone d dn" using assms by (simp add: search_def)
  have "(\<forall>pl. 0 \<le> length pl \<and> length pl < d \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
    by (rule bfs_complete[OF r0 covers_start sd])
  then show ?thesis by simp
qed


section \<open>AGREE: what an answer guarantees\<close>

lemma near_refl: "near a a"
  by (simp add: near_def agree_tol_def)

lemma same_fin_refl: "same_fin f f"
  by (cases f) (simp_all add: near_refl)

text \<open>An answer is stated at the shallowest depth where any plan completes,
and every complete plan of that depth is within 0.5 percent of the stated
value (yes/no: the same verdict). This holds for the pairwise rule with any
path memory, and for network_v3's shipped anchor rule without memory.\<close>
theorem answer_all_shallowest_agree:
  assumes "decide nd ops m mem g c p = Answer v pl" and "m = Pairwise \<or> mem = None"
  shows "(\<forall>pl'. complete nd ops c g p pl' \<longrightarrow> length pl \<le> length pl') \<and>
         (\<forall>pl' f. fin_of nd ops c g p pl' = Some f \<and> length pl' = length pl \<longrightarrow> same_fin v f)"
proof -
  obtain d dn s where sd: "search nd ops c g p = SDone d dn" and ag: "agree m (map fst dn)"
    and vs: "(v, s) \<in> set dn" and pk: "pick mem dn = (v, s)" and lp: "length pl = d"
    using answer_state[OF assms(1)] by blast
  have sc: "(\<forall>pl. length pl < d \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
    by (rule search_complete[OF sd])
  have shallow: "\<forall>pl'. complete nd ops c g p pl' \<longrightarrow> length pl \<le> length pl'"
    using sc lp unfolding complete_def by (metis not_le)
  have agv: "\<forall>f\<in>fst ` set dn. same_fin v f"
  proof (cases m)
    case Pairwise
    then show ?thesis using ag vs by force
  next
    case Anchor
    then have mn: "mem = None" using assms(2) by simp
    have ne: "dn \<noteq> []" using vs by auto
    have hv: "fst (hd dn) = v" using pk mn by (simp add: pick_def)
    obtain x xs where dnx: "dn = x # xs" using ne by (cases dn) auto
    have "\<forall>w\<in>set (map fst xs). same_fin v w" using ag Anchor dnx hv by simp
    then show ?thesis using dnx hv same_fin_refl by auto
  qed
  have "\<forall>pl' f. fin_of nd ops c g p pl' = Some f \<and> length pl' = length pl \<longrightarrow> same_fin v f"
    using sc agv lp by blast
  then show ?thesis using shallow by blast
qed

text \<open>Under the pairwise rule, two complete plans at the shallowest depth
whose values differ by more than 0.5 percent are never resolved by picking
one: the planner does not answer.\<close>
theorem disagreement_never_picked:
  assumes f1: "fin_of nd ops c g p pl1 = Some f1" and f2: "fin_of nd ops c g p pl2 = Some f2"
    and len: "length pl1 = length pl2" and dis: "\<not> same_fin f1 f2"
    and shallow: "\<forall>pl. complete nd ops c g p pl \<longrightarrow> length pl1 \<le> length pl"
  shows "\<nexists>v pl. decide nd ops Pairwise mem g c p = Answer v pl"
proof
  assume "\<exists>v pl. decide nd ops Pairwise mem g c p = Answer v pl"
  then obtain v pl where a: "decide nd ops Pairwise mem g c p = Answer v pl" by blast
  obtain d dn s where sd: "search nd ops c g p = SDone d dn" and ag: "agree Pairwise (map fst dn)"
    and lp: "length pl = d"
    using answer_state[OF a] by blast
  have fv: "fin_of nd ops c g p pl = Some v" using answer_has_complete_plan[OF a] by simp
  have sc: "(\<forall>pl. length pl < d \<longrightarrow> fin_of nd ops c g p pl = None) \<and>
         (\<forall>pl f. length pl = d \<and> fin_of nd ops c g p pl = Some f \<longrightarrow> f \<in> fst ` set dn)"
    by (rule search_complete[OF sd])
  have "length pl1 \<le> d" using shallow fv lp by (auto simp: complete_def)
  moreover have "\<not> length pl1 < d" using sc f1 by auto
  ultimately have "length pl1 = d" by simp
  then have "f1 \<in> fst ` set dn" "f2 \<in> fst ` set dn" using sc f1 f2 len by auto
  then have "same_fin f1 f2" using ag by auto
  then show False using dis by simp
qed

text \<open>An answer is a value of the plans the search found, decided by AGREE
over their values in the order the search found them.\<close>
lemma decide_on_search:
  assumes "search nd ops c g p = SDone d dn" "\<forall>q\<in>set p. invalid_why q = None"
  shows "decide nd ops m mem g c p = (if agree m (map fst dn)
            then Answer (fst (pick mem dn)) (steps (snd (pick mem dn)))
            else Disagree (map (steps \<circ> snd) dn))"
proof -
  have "\<forall>i<length p. invalid_why (p ! i) = None" using assms(2) nth_mem by blast
  then have "find (\<lambda>i. invalid_why (p ! i) \<noteq> None) [0..<length p] = None"
    by (simp add: find_None_iff)
  then show ?thesis using assms(1) by (simp add: decide_def)
qed


section \<open>Path memory and order\<close>

fun is_answer :: "decision \<Rightarrow> bool" where
  "is_answer (Answer v pl) = True" | "is_answer _ = False"

text \<open>Path memory never decides whether to answer, and when the planner
does not answer, memory changes nothing.\<close>
theorem memory_never_decides:
  "is_answer (decide nd ops m mem g c p) = is_answer (decide nd ops m None g c p)"
  "\<not> is_answer (decide nd ops m None g c p) \<Longrightarrow> decide nd ops m mem g c p = decide nd ops m None g c p"
  by (auto simp: decide_def split: option.splits sres.splits)

text \<open>The pairwise rule depends only on the set of values found, not on the
order in which the search found them.\<close>
theorem pairwise_order_independent:
  "set vs = set ws \<Longrightarrow> agree Pairwise vs = agree Pairwise ws"
  by simp

text \<open>Agreement within 0.5 percent is not transitive: 100 and 100.4 agree,
100.4 and 100.8 agree, 100 and 100.8 do not.\<close>
theorem agree_not_transitive_counterexample:
  "near 100 (502 / 5)" "near (502 / 5) (504 / 5)" "\<not> near 100 (504 / 5)"
  "agree Anchor [FVal (502 / 5), FVal 100, FVal (504 / 5)]"
  "\<not> agree Anchor [FVal 100, FVal (502 / 5), FVal (504 / 5)]"
  "\<not> agree Anchor [FVal (504 / 5), FVal (502 / 5), FVal 100]"
  "\<not> agree Pairwise [FVal (502 / 5), FVal 100, FVal (504 / 5)]"
  by code_simp+

text \<open>What network_v3 does with three complete plans at 100, 100.4 and 100.8
at the shallowest depth: as shipped (@{const Anchor}) it answers 100.4 when the
search found 100.4 first and declines when it found 100 (or 100.8) first; the
pairwise rule declines in every order. So under the shipped rule the outcome
depends on the order of the operation catalogue, and an answer can stand
although two shallowest plans disagree.\<close>
theorem anchor_three_plans:
  assumes "\<forall>q\<in>set p. invalid_why q = None"
  shows "search nd ops c g p = SDone d [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)] \<Longrightarrow>
           decide nd ops Anchor None g c p = Answer (FVal (502 / 5)) (steps s1) \<and>
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"
    and "search nd ops c g p = SDone d [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)] \<Longrightarrow>
           decide nd ops Anchor mem g c p = Disagree [steps s1, steps s2, steps s3] \<and>
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"
proof -
  have c1: "agree Anchor [FVal (502 / 5), FVal 100, FVal (504 / 5)]"
    and c2: "\<not> agree Anchor [FVal 100, FVal (502 / 5), FVal (504 / 5)]"
    and c3: "\<not> agree Pairwise [FVal (502 / 5), FVal 100, FVal (504 / 5)]"
    and c4: "\<not> agree Pairwise [FVal 100, FVal (502 / 5), FVal (504 / 5)]"
    by code_simp+
  show "decide nd ops Anchor None g c p = Answer (FVal (502 / 5)) (steps s1) \<and>
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"
    if h: "search nd ops c g p = SDone d [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)]"
  proof -
    have a: "decide nd ops Anchor None g c p = (if agree Anchor (map fst [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)])
            then Answer (fst (pick None [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)]))
                        (steps (snd (pick None [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)])))
            else Disagree (map (steps \<circ> snd) [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)]))"
      by (rule decide_on_search[OF h assms])
    have b: "decide nd ops Pairwise mem g c p = (if agree Pairwise (map fst [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)])
            then Answer (fst (pick mem [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)]))
                        (steps (snd (pick mem [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)])))
            else Disagree (map (steps \<circ> snd) [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)]))"
      by (rule decide_on_search[OF h assms])
    show ?thesis using a b c1 c3 by (simp add: pick_def del: agree.simps)
  qed
  show "decide nd ops Anchor mem g c p = Disagree [steps s1, steps s2, steps s3] \<and>
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"
    if h: "search nd ops c g p = SDone d [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)]"
  proof -
    have a: "decide nd ops Anchor mem g c p = (if agree Anchor (map fst [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)])
            then Answer (fst (pick mem [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)]))
                        (steps (snd (pick mem [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)])))
            else Disagree (map (steps \<circ> snd) [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)]))"
      by (rule decide_on_search[OF h assms])
    have b: "decide nd ops Pairwise mem g c p = (if agree Pairwise (map fst [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)])
            then Answer (fst (pick mem [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)]))
                        (steps (snd (pick mem [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)])))
            else Disagree (map (steps \<circ> snd) [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)]))"
      by (rule decide_on_search[OF h assms])
    show ?thesis using a b c2 c4 by (simp del: agree.simps)
  qed
qed


section \<open>The v1.1 rules: a single conversion and an echo are not answers\<close>

lemma bfs_single: "list_ex (\<lambda>s. finish g p s d = FSingle) fr \<Longrightarrow> bfs nd ops c g p fuel d cnt fr = SSingle"
  by (cases fuel) simp_all

theorem single_conversion_not_answer:
  assumes "p = [q]" "g = GDim gd fct False" "core_math [q] gd = Some cm" "0 \<le> cm / fct"
  shows "decide nd ops m mem g c p = SingleConversion \<or> (\<exists>i w. decide nd ops m mem g c p = Invalid i w)"
proof -
  have "rest_of (start_st p) = [q]" using assms(1) by (simp add: rest_of_def start_st_def)
  then have "finish g p (start_st p) 0 = FSingle"
    using assms by (simp add: finish_def start_st_def not_less)
  then have "search nd ops c g p = SSingle" by (simp add: search_def bfs_single)
  then show ?thesis by (auto simp: decide_def split: option.splits)
qed

theorem echo_not_answer:
  assumes "decide nd ops m mem g c p = Answer (FVal v) []" "g = GDim gd fct b" "fct \<noteq> 0"
  shows "\<forall>q\<in>set p. qdim q = gd \<longrightarrow> amount q \<noteq> v * fct"
proof -
  obtain s where fs: "finish g p s 0 = FDone (FVal v)"
    using answer_state[OF assms(1)] by auto
  then obtain cm where cm: "v = cm / fct" and ne: "\<not> (\<exists>q\<in>set p. qdim q = gd \<and> amount q = cm)"
    using assms(2) by (auto simp: finish_def split: option.splits if_splits)
  have "v * fct = cm" using cm assms(3) by (simp add: field_simps)
  then show ?thesis using ne by auto
qed

text \<open>A goal marked "op" (pressure, force, mass) is never met by core math
alone.\<close>
theorem op_goal_needs_operation:
  assumes "decide nd ops m mem g c p = Answer v pl" "g = GDim gd fct True"
  shows "pl \<noteq> []"
proof
  assume "pl = []"
  then obtain s where "finish g p s 0 = FDone v" using answer_state[OF assms(1)] by auto
  then show False using assms(2) by (auto simp: finish_def split: if_splits)
qed

theorem answer_uses_givens_once:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "\<exists>s. run_plan nd ops c p (start_st p) pl = Some s \<and>
     distinct (concat (map step_uses pl) @ avail s) \<and>
     {..<length p} \<subseteq> set (concat (map step_uses pl) @ avail s)"
  using answer_state[OF assms] every_given_used_once by blast


section \<open>The nodes: lane G's quantity kernel\<close>

fun all_some :: "'a option list \<Rightarrow> 'a list option" where
  "all_some [] = Some []"
| "all_some (x # xs) = (case x of None \<Rightarrow> None | Some y \<Rightarrow> map_option ((#) y) (all_some xs))"

definition dec_rat :: "int \<times> int \<Rightarrow> rat" where
  "dec_rat d = (case d of (m, e) \<Rightarrow> of_int m * (if 0 \<le> e then 10 ^ nat e else inverse (10 ^ nat (- e))))"

lemma rl_dec_rat: "rl (dec_rat d) = dec_val d"
  by (cases d) (auto simp: dec_rat_def dec_val_def pow10_def of_rat_mult of_rat_power of_rat_inverse)

text \<open>network_v2.g: a number is put into a phrasing with six significant
digits (@{text "%.6g"}). Below 1e-4 network_v2 writes an exponent form; this
model declines there.\<close>
definition phrase :: "rat \<Rightarrow> rat option" where
  "phrase x = (if \<bar>x\<bar> < 1 / 10000 then None else map_option dec_rat (round_sig 6 (rl x)))"

lemma phrase_sound: "phrase x = Some y \<Longrightarrow> \<bar>rl y - rl x\<bar> \<le> \<bar>rl x\<bar> / (2 * 10 ^ 5)"
proof -
  assume "phrase x = Some y"
  then obtain d where d: "round_sig 6 (rl x) = Some d" "y = dec_rat d"
    by (auto simp: phrase_def split: if_splits)
  have "\<bar>dec_val d - rl x\<bar> \<le> \<bar>rl x\<bar> / (2 * 10 ^ (6 - 1))" by (rule round_sig_sound[OF d(1)])
  then show ?thesis using d(2) by (simp add: rl_dec_rat)
qed

text \<open>The request each operation's phrasing asks its organ (network_v3's
DEV phrasings), in lane G's typed request language: volume in m3, mass in
kg, depth and stretch in m, stiffness in N/m, energy asked in MJ.\<close>
fun request_of :: "fop \<Rightarrow> ctx \<Rightarrow> rat list \<Rightarrow> request option" where
  "request_of Mass_of_volume c [v] = map_option (\<lambda>m. MassOf m (Some (v, U_cubic_metre)) U_kilogram) (c_mat c)"
| "request_of Volume_of_mass c [m] = map_option (\<lambda>mt. VolumeOf mt (Some (m, U_kilogram)) U_cubic_metre) (c_mat c)"
| "request_of Gauge_pressure c [h] = map_option (\<lambda>f. PressureGauge f (Some (h, U_metre))) (c_fluid c)"
| "request_of Buoyant_force c [v] = map_option (\<lambda>f. Buoyant f (Some (v, U_cubic_metre))) (c_fluid c)"
| "request_of Spring_force c [k, x] = Some (SpringForce (Some k) (Some (x, U_metre)))"
| "request_of Spring_energy c [k, x] = Some (SpringEnergy (Some k) (Some (x, U_metre)))"
| "request_of Fuel_energy c [m] = map_option (\<lambda>f. FuelEnergy f (Some (m, U_kilogram)) U_megajoule) (c_fuel c)"
| "request_of Fuel_co2_mass c [m] = map_option (\<lambda>f. FuelCO2 f (Some (m, U_kilogram))) (c_fuel c)"
| "request_of _ _ _ = None"

text \<open>The reply's unit to SI (network_v3 parses MJ and multiplies by 1e6).\<close>
fun out_factor :: "fop \<Rightarrow> rat" where
  "out_factor Fuel_energy = 1000000" | "out_factor _ = 1"

text \<open>The value the organ states: the kernel's exact value rounded as the
reply prints it (four significant digits for these kinds).\<close>
definition stated_val :: "outcome \<Rightarrow> rat option" where
  "stated_val r = (case r of Exact k q \<Rightarrow> map_option dec_rat (stated_dec k q) | _ \<Rightarrow> None)"

definition qnode :: nodefn where
  "qnode f c qs = (case all_some (map (phrase \<circ> amount) qs) of None \<Rightarrow> None | Some xs \<Rightarrow>
     (case request_of f c xs of None \<Rightarrow> None | Some rq \<Rightarrow>
       (case stated_val (kernel rq) of None \<Rightarrow> None | Some y \<Rightarrow> Some (NVal (y * out_factor f)))))"

definition ops_v3 :: "fop list" where
  "ops_v3 = [Mass_of_volume, Volume_of_mass, Gauge_pressure, Buoyant_force, Spring_force,
     Spring_energy, Fuel_energy, Fuel_co2_mass]"

lemma request_sig: "request_of f c xs = Some rq \<Longrightarrow> sig_digits (kind_of rq) = 4"
  by (induction f c xs rule: request_of.induct) (auto simp: sig_digits_def)

lemma out_factor_pos: "0 < out_factor f"
  by (cases f) simp_all

lemma scale_bound:
  fixes a b F C :: real
  assumes F: "0 < F" and b: "\<bar>a - b\<bar> \<le> \<bar>b\<bar> / C"
  shows "\<bar>a * F - b * F\<bar> \<le> \<bar>b * F\<bar> / C"
proof -
  have "\<bar>a * F - b * F\<bar> = \<bar>a - b\<bar> * F"
    using F by (simp add: left_diff_distrib[symmetric] abs_mult abs_of_pos)
  also have "\<dots> \<le> \<bar>b\<bar> / C * F" using b F by (intro mult_right_mono) auto
  also have "\<dots> = \<bar>b * F\<bar> / C" using F by (simp add: abs_mult abs_of_pos)
  finally show ?thesis .
qed

text \<open>Every node value is lane G's kernel value for the phrased request,
times the unit factor, within the organ's four significant digits; the
kernel's exact value is the request's value (@{thm kernel_exact_sound}), so the
per-kind equations of lane G (mass from volume, buoyant force, fuel energy,
Hooke's law, ...) apply to it.\<close>
theorem qnode_sound:
  assumes "qnode f c qs = Some r"
  shows "\<exists>xs rq q y. all_some (map (phrase \<circ> amount) qs) = Some xs \<and> request_of f c xs = Some rq \<and>
     kernel rq = Exact (kind_of rq) q \<and> q = qval rq \<and> r = NVal y \<and>
     \<bar>rl y - rl (q * out_factor f)\<bar> \<le> \<bar>rl (q * out_factor f)\<bar> / (2 * 10 ^ 3)"
proof -
  obtain xs where xs: "all_some (map (phrase \<circ> amount) qs) = Some xs"
    using assms by (auto simp: qnode_def split: option.splits)
  obtain rq where rq: "request_of f c xs = Some rq"
    using assms xs by (auto simp: qnode_def split: option.splits)
  obtain y0 where y0: "stated_val (kernel rq) = Some y0" and r: "r = NVal (y0 * out_factor f)"
    using assms xs rq by (auto simp: qnode_def split: option.splits)
  obtain k q d where kq: "kernel rq = Exact k q" and sd: "stated_dec k q = Some d" and yd: "y0 = dec_rat d"
    using y0 by (auto simp: stated_val_def split: outcome.splits)
  have ks: "k = kind_of rq \<and> q = qval rq" using kernel_exact_sound[OF kq] by simp
  have sig: "sig_digits k = 4" using request_sig[OF rq] ks by simp
  have b: "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ 3)"
    using stated_dec_sound[OF sd] sig by simp
  have F: "0 < rl (out_factor f)" using out_factor_pos[of f] by simp
  have "\<bar>dec_val d * rl (out_factor f) - rl q * rl (out_factor f)\<bar> \<le> \<bar>rl q * rl (out_factor f)\<bar> / (2 * 10 ^ 3)"
    by (rule scale_bound[OF F b])
  then have bnd: "\<bar>rl (y0 * out_factor f) - rl (q * out_factor f)\<bar> \<le> \<bar>rl (q * out_factor f)\<bar> / (2 * 10 ^ 3)"
    by (simp add: yd rl_dec_rat of_rat_mult)
  have kq': "kernel rq = Exact (kind_of rq) q" using kq ks by simp
  show ?thesis using xs rq kq' ks r bnd by blast
qed

text \<open>The fusion decision with lane G's kernels as nodes, the v3 catalogue
order and no path memory: the exported planner.\<close>
definition qdecide :: "agree_mode \<Rightarrow> goal \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> decision" where
  "qdecide m g c p = decide qnode ops_v3 m None g c p"

end
