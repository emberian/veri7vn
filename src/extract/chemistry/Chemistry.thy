theory Chemistry
  imports "Veri7vn_Chemistry_Base.Chem_Table"
begin

text \<open>
  The chemistry organs of Oracle7 as one verified kernel: element properties,
  the exact molar mass of any formula (nested brackets, hydrates), grams and
  moles, percent composition (chemistry, chemistry-v3), and the laboratory
  solutions (labsolutions, labsolutions-r2: mass for a molarity, molarity of a
  mass, dilution, percent w/v). Amounts are exact rationals; atomic masses are
  the decimals PubChem's table writes. The untrusted recognizer reads numbers
  and words off the question and builds a request; every value, decline and
  response text below is computed here.
\<close>

section \<open>The table\<close>

definition find_sym :: "string \<Rightarrow> pelem option" where
  "find_sym s = List.find (\<lambda>e. psym e = s) ptable"

definition elem_mass :: "string \<Rightarrow> rat" where
  "elem_mass s = (case find_sym s of Some e \<Rightarrow> pmass e | None \<Rightarrow> 0)"

definition sl :: "string \<Rightarrow> String.literal" where "sl = String.implode"

section \<open>Formulas\<close>

text \<open>A formula's element counts, in the order the organ's dictionary holds
them (first occurrence).\<close>
type_synonym counts = "(string \<times> nat) list"

datatype fparse = FOk counts | FUnknown string | FBad

fun add_count :: "string \<Rightarrow> nat \<Rightarrow> counts \<Rightarrow> counts" where
  "add_count s n [] = [(s, n)]"
| "add_count s n ((t, m) # r) = (if s = t then (t, m + n) # r else (t, m) # add_count s n r)"

definition merge_into :: "counts \<Rightarrow> nat \<Rightarrow> counts \<Rightarrow> counts" where
  "merge_into tp k base = foldl (\<lambda>acc x. add_count (fst x) (snd x * k) acc) base tp"

definition ord_of :: "char \<Rightarrow> nat" where "ord_of c = nat_of_integer (integer_of_char c)"
definition is_up :: "char \<Rightarrow> bool" where "is_up c \<longleftrightarrow> 65 \<le> ord_of c \<and> ord_of c \<le> 90"
definition is_lowc :: "char \<Rightarrow> bool" where "is_lowc c \<longleftrightarrow> 97 \<le> ord_of c \<and> ord_of c \<le> 122"
definition is_dig :: "char \<Rightarrow> bool" where "is_dig c \<longleftrightarrow> 48 \<le> ord_of c \<and> ord_of c \<le> 57"

definition num_of :: "string \<Rightarrow> nat" where
  "num_of ds = foldl (\<lambda>a c. 10 * a + (ord_of c - 48)) 0 ds"

text \<open>The organ's counts function: a stack of dictionaries, '(' pushes, ')'
pops and merges into the one below with the multiplier that follows, an
element symbol is one capital and an optional lower-case letter followed by a
count. The fuel makes the function total; each step consumes a character.\<close>
fun scan :: "string \<Rightarrow> string \<Rightarrow> counts list \<Rightarrow> fparse" where
  "scan [] _ _ = FBad"
| "scan (_ # n) [] st = (case st of [c] \<Rightarrow> FOk c | _ \<Rightarrow> FBad)"
| "scan (_ # n) (c # cs) st =
    (if c = CHR ''('' then scan n cs ([] # st)
     else if c = CHR '')'' then
       (let ds = takeWhile is_dig cs; rest = dropWhile is_dig cs;
            k = (if ds = [] then 1 else num_of ds) in
        case st of tp # below # more \<Rightarrow> scan n rest (merge_into tp k below # more)
                 | _ \<Rightarrow> FBad)
     else if is_up c then
       (let lo = (case cs of d # _ \<Rightarrow> is_lowc d | [] \<Rightarrow> False);
            nm = (if lo then c # take 1 cs else [c]);
            cs1 = (if lo then drop 1 cs else cs);
            ds = takeWhile is_dig cs1; rest = dropWhile is_dig cs1;
            k = (if ds = [] then 1 else num_of ds) in
        if find_sym nm = None then FUnknown nm
        else case st of tp # more \<Rightarrow> scan n rest (add_count nm k tp # more) | [] \<Rightarrow> FBad)
     else FBad)"

definition split_dot :: "string \<Rightarrow> string list" where
  "split_dot s = foldr (\<lambda>c acc. if c = CHR ''.'' then [] # acc else (c # hd acc) # tl acc) s [[]]"

fun parse_parts :: "string list \<Rightarrow> counts \<Rightarrow> fparse" where
  "parse_parts [] tot = FOk tot"
| "parse_parts (p # ps) tot =
    (let ds = takeWhile is_dig p; rest = dropWhile is_dig p;
         mult = (if ds = [] then 1 else num_of ds) in
     case scan (CHR 0x20 # rest) rest [[]] of
       FOk c \<Rightarrow> parse_parts ps (merge_into c mult tot)
     | FUnknown s \<Rightarrow> FUnknown s
     | FBad \<Rightarrow> FBad)"

definition parse_formula :: "string \<Rightarrow> fparse" where
  "parse_formula f = parse_parts (split_dot f) []"

fun mass_total :: "counts \<Rightarrow> rat" where
  "mass_total [] = 0"
| "mass_total ((s, n) # r) = elem_mass s * of_nat n + mass_total r"

definition count_of :: "string \<Rightarrow> counts \<Rightarrow> nat" where
  "count_of s cs = sum_list (map snd (filter (\<lambda>p. fst p = s) cs))"

lemma mass_total_add_count:
  "mass_total (add_count s n cs) = mass_total cs + elem_mass s * of_nat n"
  by (induction cs) (auto simp: algebra_simps)

text \<open>Merging a bracket group (or a hydrate part) into the counts below it
neither loses nor invents mass: the group's mass, times its multiplier.\<close>
theorem mass_merge:
  "mass_total (merge_into tp k base) = mass_total base + of_nat k * mass_total tp"
proof -
  have gen: "\<And>base. mass_total (foldl (\<lambda>acc x. add_count (fst x) (snd x * k) acc) base tp)
      = mass_total base + of_nat k * mass_total tp"
  proof (induction tp)
    case Nil show ?case by simp
  next
    case (Cons x xs)
    obtain e n where x: "x = (e, n)" by (cases x)
    show ?case using Cons.IH[of "add_count e (n * k) base"] x
      by (simp add: mass_total_add_count algebra_simps)
  qed
  show ?thesis unfolding merge_into_def by (rule gen)
qed

lemma mass_total_eq:
  "mass_total cs = sum_list (map (\<lambda>p. elem_mass (fst p) * of_nat (snd p)) cs)"
proof (induction cs)
  case Nil show ?case by simp
next
  case (Cons a r) then show ?case by (cases a) simp
qed

lemma sum_scale:
  fixes c :: rat and g :: "'b \<Rightarrow> rat" and xs :: "'b list"
  shows "sum_list (map (\<lambda>p. c * g p / m) xs) = c * sum_list (map g xs) / (m::rat)"
  by (induction xs) (simp_all add: algebra_simps add_divide_distrib)

section \<open>Requests and outcomes\<close>

datatype eprop = P_atomic_mass | P_atomic_number | P_electronegativity | P_melting_point
  | P_boiling_point | P_density | P_electron_configuration | P_ionization_energy
  | P_standard_state | P_group_block | P_year_discovered | P_symbol

text \<open>Formulas are character lists; an element is its symbol. @{text Property}
takes an element symbol and whether the question asked for Fahrenheit.
@{text WvMass} is percent w/v and millilitres; @{text Dilution} two
concentrations (mol/L) and the final volume (L); @{text Molarity} a formula, a
mass (g) and a volume (L); @{text MassNeeded} a formula, a molarity and a
volume (L).\<close>
datatype creq =
    MolarMass string
  | GramsToMoles rat string
  | MolesToGrams rat string
  | Percent string string
  | Property eprop string bool
  | NoSuchElement String.literal
  | WvMass rat rat
  | Dilution rat rat rat
  | Molarity string rat rat
  | MassNeeded string rat rat
  | NeedFormula

datatype ckind = CK_molar_mass | CK_g2mol | CK_mol2g | CK_percent | CK_wv_mass | CK_dilution
  | CK_molarity | CK_mass_needed

datatype cdecl = UnknownSym string string | BadFormula string | ZeroMass string
  | NoValue eprop string | UnknownWord String.literal | NeedFormulaDecl
  | NonPositiveConc | NotInFormula string string | ElementAbsent string

datatype cout = CExact ckind rat | CLookup eprop string bool | CDecline cdecl

fun prop_field :: "eprop \<Rightarrow> pelem \<Rightarrow> String.literal" where
  "prop_field P_atomic_mass e = pmass_s e"
| "prop_field P_atomic_number e = show_nat (pnum e)"
| "prop_field P_electronegativity e = pen e"
| "prop_field P_melting_point e = pmp e"
| "prop_field P_boiling_point e = pbp e"
| "prop_field P_density e = pdens e"
| "prop_field P_electron_configuration e = pconf e"
| "prop_field P_ionization_energy e = pip e"
| "prop_field P_standard_state e = pstate e"
| "prop_field P_group_block e = pblock e"
| "prop_field P_year_discovered e = pyear e"
| "prop_field P_symbol e = sl (psym e)"

section \<open>The kernel\<close>

text \<open>Molar mass of a formula string, or the organ's two failures (a symbol
that is not an element, an unreadable formula).\<close>
definition with_mass :: "string \<Rightarrow> (rat \<Rightarrow> counts \<Rightarrow> cout) \<Rightarrow> cout" where
  "with_mass f k = (case parse_formula f of
      FOk cs \<Rightarrow> k (mass_total cs) cs
    | FUnknown s \<Rightarrow> CDecline (UnknownSym s f)
    | FBad \<Rightarrow> CDecline (BadFormula f))"

fun ckernel :: "creq \<Rightarrow> cout" where
  "ckernel (MolarMass f) = with_mass f (\<lambda>m cs. CExact CK_molar_mass m)"
| "ckernel (GramsToMoles q f) = with_mass f (\<lambda>m cs.
     if m = 0 then CDecline (ZeroMass f) else CExact CK_g2mol (q / m))"
| "ckernel (MolesToGrams q f) = with_mass f (\<lambda>m cs. CExact CK_mol2g (q * m))"
| "ckernel (Percent s f) = with_mass f (\<lambda>m cs.
     if s \<notin> set (map fst cs) then CDecline (NotInFormula s f)
     else if m = 0 then CDecline (ZeroMass f)
     else CExact CK_percent (100 * elem_mass s * of_nat (count_of s cs) / m))"
| "ckernel (Property p s fh) = (case find_sym s of
     None \<Rightarrow> CDecline (ElementAbsent s)
   | Some e \<Rightarrow> if prop_field p e = STR '''' then CDecline (NoValue p s) else CLookup p s fh)"
| "ckernel (NoSuchElement w) = CDecline (UnknownWord w)"
| "ckernel (WvMass pct ml) = CExact CK_wv_mass (pct / 100 * ml)"
| "ckernel (Dilution a b v2) =
     (let c1 = max a b; c2 = min a b in
      if c1 \<le> 0 then CDecline NonPositiveConc else CExact CK_dilution (c2 * v2 / c1 * 1000))"
| "ckernel (Molarity f g v) = (case parse_formula f of
     FOk cs \<Rightarrow> if mass_total cs = 0 \<or> v = 0 then CDecline (ZeroMass f)
               else CExact CK_molarity (g / mass_total cs / v)
   | _ \<Rightarrow> CDecline (BadFormula f))"
| "ckernel (MassNeeded f mol v) = (case parse_formula f of
     FOk cs \<Rightarrow> CExact CK_mass_needed (mol * v * mass_total cs)
   | _ \<Rightarrow> CDecline (BadFormula f))"
| "ckernel NeedFormula = CDecline NeedFormulaDecl"

section \<open>What each kind means\<close>

theorem molar_mass_value:
  assumes "ckernel (MolarMass f) = CExact k m"
  shows "k = CK_molar_mass \<and> (\<exists>cs. parse_formula f = FOk cs \<and> m = mass_total cs)"
  using assms by (auto simp: with_mass_def split: fparse.splits)

theorem grams_to_moles_value:
  assumes "ckernel (GramsToMoles q f) = CExact k v"
  shows "k = CK_g2mol \<and> (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs \<noteq> 0 \<and> v * mass_total cs = q)"
  using assms by (auto simp: with_mass_def field_simps split: fparse.splits if_splits)

theorem moles_to_grams_value:
  assumes "ckernel (MolesToGrams q f) = CExact k v"
  shows "k = CK_mol2g \<and> (\<exists>cs. parse_formula f = FOk cs \<and> v = q * mass_total cs)"
  using assms by (auto simp: with_mass_def split: fparse.splits)

text \<open>Grams to moles and back is the identity.\<close>
theorem grams_moles_roundtrip:
  assumes "ckernel (GramsToMoles q f) = CExact k v"
  shows "ckernel (MolesToGrams v f) = CExact CK_mol2g q"
proof -
  from grams_to_moles_value[OF assms] obtain cs where
    p: "parse_formula f = FOk cs" and nz: "mass_total cs \<noteq> 0" and e: "v * mass_total cs = q" by blast
  show ?thesis using p e by (simp add: with_mass_def)
qed

text \<open>The declines of grams to moles are exactly the organ's: a symbol that is
no element, an unreadable formula, and (the organ would divide by zero) a
formula of zero mass.\<close>
theorem grams_to_moles_declines:
  "ckernel (GramsToMoles q f) = CDecline d \<longleftrightarrow>
     (\<exists>s. parse_formula f = FUnknown s \<and> d = UnknownSym s f) \<or>
     (parse_formula f = FBad \<and> d = BadFormula f) \<or>
     (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs = 0 \<and> d = ZeroMass f)"
  by (cases "parse_formula f") (auto simp: with_mass_def split: if_splits)

theorem percent_value:
  assumes "ckernel (Percent s f) = CExact k v"
  shows "k = CK_percent \<and> (\<exists>cs. parse_formula f = FOk cs \<and> s \<in> set (map fst cs) \<and>
     mass_total cs \<noteq> 0 \<and> v * mass_total cs = 100 * elem_mass s * of_nat (count_of s cs))"
  using assms by (auto simp: with_mass_def field_simps split: fparse.splits if_splits)

text \<open>The percentages of all the entries of a formula add up to a hundred.\<close>
theorem percent_entries_sum:
  assumes "m = mass_total cs" "m \<noteq> 0"
  shows "sum_list (map (\<lambda>p. 100 * (elem_mass (fst p) * of_nat (snd p)) / m) cs) = 100"
proof -
  have a: "sum_list (map (\<lambda>p. 100 * (elem_mass (fst p) * of_nat (snd p)) / m) cs)
      = 100 * sum_list (map (\<lambda>p. elem_mass (fst p) * of_nat (snd p)) cs) / m"
    by (rule sum_scale)
  have b: "sum_list (map (\<lambda>p. elem_mass (fst p) * of_nat (snd p)) cs) = m"
    using mass_total_eq[of cs] assms(1) by simp
  show ?thesis using a b assms(2) by simp
qed

theorem property_value:
  assumes "ckernel (Property p s fh) = CLookup p' s' fh'"
  shows "p' = p \<and> s' = s \<and> fh' = fh \<and>
     (\<exists>e. find_sym s = Some e \<and> prop_field p e \<noteq> STR '''')"
  using assms by (auto split: option.splits if_splits)

theorem property_declines:
  "ckernel (Property p s fh) = CDecline d \<longleftrightarrow>
     (find_sym s = None \<and> d = ElementAbsent s) \<or>
     (\<exists>e. find_sym s = Some e \<and> prop_field p e = STR '''' \<and> d = NoValue p s)"
  by (cases "find_sym s") (auto split: if_splits)

section \<open>Temperatures (K to C and F)\<close>

definition celsius_of :: "rat \<Rightarrow> rat" where "celsius_of k = k - 27315 / 100"
definition fahrenheit_of :: "rat \<Rightarrow> rat" where "fahrenheit_of k = k * 9 / 5 - 45967 / 100"

text \<open>The two scales the reply states are the same temperature: F = C * 9/5 + 32.\<close>
theorem fahrenheit_celsius: "fahrenheit_of k = celsius_of k * 9 / 5 + 32"
  unfolding fahrenheit_of_def celsius_of_def by (simp add: divide_simps algebra_simps)

theorem absolute_zero_fahrenheit: "0 \<le> k \<Longrightarrow> -45967 / 100 \<le> fahrenheit_of k"
  by (simp add: fahrenheit_of_def)

section \<open>Laboratory solutions\<close>

theorem wv_value:
  "ckernel (WvMass pct ml) = CExact CK_wv_mass g \<Longrightarrow> g * 100 = pct * ml"
  by simp

theorem dilution_value:
  assumes "ckernel (Dilution a b v2) = CExact k v1ml"
  shows "k = CK_dilution \<and> 0 < max a b \<and> v1ml * max a b = min a b * v2 * 1000"
proof -
  have pos: "0 < max a b" using assms by (auto split: if_splits)
  then have ne: "max a b \<noteq> 0" by simp
  have v: "v1ml = min a b * v2 / max a b * 1000" using assms by (auto split: if_splits)
  have "v1ml * max a b = min a b * v2 * 1000" using v ne by (simp add: field_simps)
  moreover have "k = CK_dilution" using assms by (auto split: if_splits)
  ultimately show ?thesis using pos by simp
qed

theorem molarity_value:
  assumes "ckernel (Molarity f g v) = CExact k mo"
  shows "k = CK_molarity \<and> (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs \<noteq> 0 \<and> v \<noteq> 0 \<and>
     mo * v * mass_total cs = g)"
proof -
  from assms obtain cs where p: "parse_formula f = FOk cs"
    by (cases "parse_formula f") auto
  have nz1: "mass_total cs \<noteq> 0" and nz2: "v \<noteq> 0" using assms p by (auto split: if_splits)
  have eq: "mo = g / mass_total cs / v" using assms p nz1 nz2 by (auto split: if_splits)
  have "mo * v * mass_total cs = g" using eq nz1 nz2 by (simp add: field_simps)
  moreover have "k = CK_molarity" using assms p by (auto split: if_splits)
  ultimately show ?thesis using p nz1 nz2 by blast
qed

theorem mass_needed_value:
  assumes "ckernel (MassNeeded f mol v) = CExact k g"
  shows "k = CK_mass_needed \<and> (\<exists>cs. parse_formula f = FOk cs \<and> g = mol * v * mass_total cs)"
  using assms by (cases "parse_formula f") auto

text \<open>Preparing a solution and then measuring its molarity gives back the
molarity asked for.\<close>
theorem mass_molarity_inverse:
  assumes "ckernel (MassNeeded f mol v) = CExact k g" "v \<noteq> 0"
    "\<And>cs. parse_formula f = FOk cs \<Longrightarrow> mass_total cs \<noteq> 0"
  shows "ckernel (Molarity f g v) = CExact CK_molarity mol"
proof -
  from mass_needed_value[OF assms(1)] obtain cs where p: "parse_formula f = FOk cs" and g: "g = mol * v * mass_total cs" by blast
  have nz: "mass_total cs \<noteq> 0" using assms(3) p by blast
  have "mol * v * mass_total cs / mass_total cs / v = mol" using nz assms(2) by (simp add: field_simps)
  then show ?thesis using p g nz assms(2) by simp
qed

theorem lab_bad_formula:
  "ckernel (MassNeeded f mol v) = CDecline d \<longleftrightarrow>
     (\<forall>cs. parse_formula f \<noteq> FOk cs) \<and> d = BadFormula f"
  by (cases "parse_formula f") auto

section \<open>Response text (ASCII)\<close>

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition g4 :: "rat \<Rightarrow> String.literal" where "g4 = gfmt 4"

fun parts_text :: "counts \<Rightarrow> String.literal" where
  "parts_text [] = STR ''''"
| "parts_text [(s, n)] = show_nat n + STR '' x '' + sl s"
| "parts_text ((s, n) # y # r) = show_nat n + STR '' x '' + sl s + STR '' + '' + parts_text (y # r)"

definition prop_name :: "eprop \<Rightarrow> String.literal" where
  "prop_name p = (case p of
     P_atomic_mass \<Rightarrow> STR ''atomic mass'' | P_atomic_number \<Rightarrow> STR ''atomic number''
   | P_electronegativity \<Rightarrow> STR ''electronegativity'' | P_melting_point \<Rightarrow> STR ''melting point''
   | P_boiling_point \<Rightarrow> STR ''boiling point'' | P_density \<Rightarrow> STR ''density''
   | P_electron_configuration \<Rightarrow> STR ''electron configuration''
   | P_ionization_energy \<Rightarrow> STR ''ionization energy'' | P_standard_state \<Rightarrow> STR ''standard state''
   | P_group_block \<Rightarrow> STR ''group block'' | P_year_discovered \<Rightarrow> STR ''year discovered''
   | P_symbol \<Rightarrow> STR ''symbol'')"

definition prop_kind :: "eprop \<Rightarrow> String.literal" where
  "prop_kind p = (case p of
     P_atomic_mass \<Rightarrow> STR ''atomic_mass'' | P_atomic_number \<Rightarrow> STR ''atomic_number''
   | P_electronegativity \<Rightarrow> STR ''electronegativity'' | P_melting_point \<Rightarrow> STR ''melting_point''
   | P_boiling_point \<Rightarrow> STR ''boiling_point'' | P_density \<Rightarrow> STR ''density''
   | P_electron_configuration \<Rightarrow> STR ''electron_configuration''
   | P_ionization_energy \<Rightarrow> STR ''ionization_energy'' | P_standard_state \<Rightarrow> STR ''standard_state''
   | P_group_block \<Rightarrow> STR ''group_block'' | P_year_discovered \<Rightarrow> STR ''year_discovered''
   | P_symbol \<Rightarrow> STR ''symbol'')"

definition prop_unit :: "eprop \<Rightarrow> String.literal" where
  "prop_unit p = (case p of
     P_atomic_mass \<Rightarrow> STR '' u'' | P_electronegativity \<Rightarrow> STR '' (Pauling scale)''
   | P_density \<Rightarrow> STR '' g/cm3'' | P_ionization_energy \<Rightarrow> STR '' eV'' | _ \<Rightarrow> STR '''')"

definition lookup_text :: "eprop \<Rightarrow> pelem \<Rightarrow> bool \<Rightarrow> String.literal" where
  "lookup_text p e fh = (let v = prop_field p e in
     STR ''The '' + prop_name p + STR '' of '' + pname e + STR '' ('' + sl (psym e) + STR '') is ''
     + (if p = P_melting_point \<or> p = P_boiling_point then
          (let k = (if p = P_melting_point then pmp_r e else pbp_r e) in
           if fh then fixed 2 (fahrenheit_of k) + STR '' F ('' + v + STR '' K, '' + fixed 2 (celsius_of k) + STR '' C)''
           else v + STR '' K ('' + fixed 2 (celsius_of k) + STR '' C)'')
        else v + prop_unit p)
     + STR '', per PubChem.'')"

definition mm_note :: "rat \<Rightarrow> String.literal" where
  "mm_note m = fixed 3 m"

fun exact_text :: "creq \<Rightarrow> rat \<Rightarrow> String.literal" where
  "exact_text (MolarMass f) m = (case parse_formula f of
       FOk cs \<Rightarrow> STR ''The molar mass of '' + sl f + STR '' is '' + fixed 3 m + STR '' g/mol (''
         + parts_text cs + STR '', PubChem atomic masses).''
     | _ \<Rightarrow> STR '''')"
| "exact_text (GramsToMoles q f) v = (case parse_formula f of
       FOk cs \<Rightarrow> gfmt 6 q + STR '' g of '' + sl f + STR '' is '' + g4 v + STR '' mol (molar mass ''
         + fixed 3 (mass_total cs) + STR '' g/mol, from PubChem atomic masses).''
     | _ \<Rightarrow> STR '''')"
| "exact_text (MolesToGrams q f) v = (case parse_formula f of
       FOk cs \<Rightarrow> gfmt 6 q + STR '' mol of '' + sl f + STR '' is '' + g4 v + STR '' g (molar mass ''
         + fixed 3 (mass_total cs) + STR '' g/mol, from PubChem atomic masses).''
     | _ \<Rightarrow> STR '''')"
| "exact_text (Percent s f) v = (case (find_sym s, parse_formula f) of
       (Some e, FOk cs) \<Rightarrow> pname e + STR '' is '' + fixed 2 v + STR ''% of '' + sl f + STR '' by mass (''
         + show_nat (count_of s cs) + STR '' x '' + pmass_s e + STR '' in '' + fixed 3 (mass_total cs)
         + STR '' g/mol).''
     | _ \<Rightarrow> STR '''')"
| "exact_text (WvMass pct ml) v = STR ''You need '' + g4 v + STR '' g ('' + g4 pct + STR ''% w/v = ''
     + g4 pct + STR '' g per 100 mL, x '' + g4 ml + STR '' mL).''"
| "exact_text (Dilution a b v2) v = STR ''Use '' + g4 v + STR '' mL of the '' + g4 (max a b)
     + STR '' M stock, made up to '' + g4 (v2 * 1000) + STR '' mL (M1V1 = M2V2).''"
| "exact_text (Molarity f g vol) v = (case parse_formula f of
       FOk cs \<Rightarrow> STR ''The molarity is '' + g4 v + STR '' M ('' + g4 g + STR '' g / '' + g4 (mass_total cs)
         + STR '' g/mol = '' + g4 (g / mass_total cs) + STR '' mol, / '' + g4 vol + STR '' L).''
     | _ \<Rightarrow> STR '''')"
| "exact_text (MassNeeded f mol vol) v = (case parse_formula f of
       FOk cs \<Rightarrow> STR ''You need '' + g4 v + STR '' g of '' + sl f + STR '' ('' + g4 mol + STR '' mol/L x ''
         + g4 vol + STR '' L x '' + g4 (mass_total cs) + STR '' g/mol, PubChem atomic masses).''
     | _ \<Rightarrow> STR '''')"
| "exact_text _ _ = STR ''''"

fun stated_text :: "ckind \<Rightarrow> rat \<Rightarrow> String.literal" where
  "stated_text CK_molar_mass v = fixed 3 v"
| "stated_text CK_percent v = fixed 2 v"
| "stated_text k v = g4 v"

fun ckind_name :: "ckind \<Rightarrow> String.literal" where
  "ckind_name CK_molar_mass = STR ''molar_mass''"
| "ckind_name CK_g2mol = STR ''g2mol''"
| "ckind_name CK_mol2g = STR ''mol2g''"
| "ckind_name CK_percent = STR ''percent''"
| "ckind_name CK_wv_mass = STR ''wv_mass''"
| "ckind_name CK_dilution = STR ''dilution''"
| "ckind_name CK_molarity = STR ''molarity''"
| "ckind_name CK_mass_needed = STR ''mass_needed''"

fun cdecl_name :: "cdecl \<Rightarrow> String.literal" where
  "cdecl_name (UnknownSym _ _) = STR ''unknown''"
| "cdecl_name (BadFormula _) = STR ''bad_formula''"
| "cdecl_name (ZeroMass _) = STR ''impossible''"
| "cdecl_name (NoValue _ _) = STR ''no_value''"
| "cdecl_name (UnknownWord _) = STR ''unknown''"
| "cdecl_name NeedFormulaDecl = STR ''underspecified''"
| "cdecl_name NonPositiveConc = STR ''impossible''"
| "cdecl_name (NotInFormula _ _) = STR ''absent''"
| "cdecl_name (ElementAbsent _) = STR ''absent''"

fun cdecl_text :: "cdecl \<Rightarrow> String.literal" where
  "cdecl_text (UnknownSym s f) = sl s + STR '' isn'' + apos + STR ''t an element symbol, so '' + sl f
     + STR '' isn'' + apos + STR ''t a formula I can weigh.''"
| "cdecl_text (BadFormula f) = sl f + STR '' isn'' + apos + STR ''t a formula I can read from the periodic table, so I won'' + apos + STR ''t compute a mass for it.''"
| "cdecl_text (ZeroMass f) = sl f + STR '' has no mass to divide by.''"
| "cdecl_text (NoValue p s) = STR ''PubChem lists no '' + prop_name p + STR '' for ''
     + (case find_sym s of Some e \<Rightarrow> pname e | None \<Rightarrow> sl s) + STR '', so I won'' + apos + STR ''t estimate one.''"
| "cdecl_text (UnknownWord w) = STR ''There'' + apos + STR ''s no element called '' + w
     + STR '' in PubChem'' + apos + STR ''s periodic table.''"
| "cdecl_text NeedFormulaDecl = STR ''I need the compound'' + apos + STR ''s formula (e.g. NaCl, CuSO4.5H2O) to work that out; I won'' + apos + STR ''t assume it.''"
| "cdecl_text NonPositiveConc = STR ''Concentrations must be positive.''"
| "cdecl_text (NotInFormula s f) = sl s + STR '' is not in '' + sl f + STR ''.''"
| "cdecl_text (ElementAbsent s) = STR ''No element '' + sl s + STR ''.''"

definition reply_c :: "creq \<Rightarrow> reply" where
  "reply_c r = (case ckernel r of
     CExact k q \<Rightarrow> Reply True (ckind_name k) (exact_text r q) (Some (stated_text k q))
   | CLookup p s fh \<Rightarrow> (case find_sym s of
         Some e \<Rightarrow> Reply True (prop_kind p) (lookup_text p e fh)
                     (Some (dq + prop_field p e + dq))
       | None \<Rightarrow> Reply False (STR ''absent'') (STR '''') None)
   | CDecline d \<Rightarrow> Reply False (cdecl_name d) (cdecl_text d) None)"

theorem reply_c_answered:
  "answered (reply_c r) \<longleftrightarrow>
     (\<exists>k q. ckernel r = CExact k q) \<or> (\<exists>p s fh e. ckernel r = CLookup p s fh \<and> find_sym s = Some e)"
  by (cases "ckernel r") (auto simp: reply_c_def split: option.splits)

theorem reply_c_exact_stated:
  "ckernel r = CExact k q \<Longrightarrow> stated (reply_c r) = Some (stated_text k q)"
  by (simp add: reply_c_def)

theorem reply_c_withheld:
  "ckernel r = CDecline d \<Longrightarrow> \<not> answered (reply_c r) \<and> reply_kind (reply_c r) = cdecl_name d"
  by (simp add: reply_c_def)

end
