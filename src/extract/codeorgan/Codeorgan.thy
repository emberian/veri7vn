theory Codeorgan
  imports "HOL-Library.Code_Target_Numeral"
begin

text \<open>
  A HOL model of the code organ's typing (upstream code_organ_v3.py): programs
  are trees of applications of typed library moves to arguments and constants.
  The organ's search composes a move with child terms only when every child's
  type fits the move's argument slot (or the child's type is unknown, ``any'').
  This theory models that rule as an inductive predicate \<^term>\<open>enum\<close> and
  proves that every program the rule can compose is well typed at every node.

  Differences from the organ, stated plainly:
    \<^item> The organ types a term by the values it observes when the search runs it
      on the examples; this model types a term statically from the argument
      signature. A move's output type is therefore a SET of possible base types
      (the organ declares group outputs like ``num''), and a child is admitted
      to a slot only when ALL its possible types connect -- the sound static
      analogue of the organ's optimistic observational check.
    \<^item> The organ also admits string constants; this model has integer
      constants only.
    \<^item> The organ's declared output column is sometimes wider than its real
      semantics (e.g. fdiv on floats); here the output table transcribes the
      declared column, which is all the search ever reads.
\<close>

subsection \<open>Types and slots\<close>

datatype ty =
  TBool | TInt | TFloat | TStr | TList | TTuple | TDict | TSet | TAny

text \<open>A slot is what a move's argument position asks for: an exact type, or
one of the organ's groups (num, seq, coll) or the universal slot any.\<close>

datatype slot = SNum | SSeq | SColl | SAny | STy ty

definition num_tys :: "ty list" where [simp]: "num_tys = [TInt, TFloat]"
definition seq_tys :: "ty list" where [simp]: "seq_tys = [TList, TTuple, TStr]"
definition coll_tys :: "ty list" where [simp]: "coll_tys = [TList, TTuple, TSet]"
definition any_tys :: "ty list" where [simp]:
  "any_tys = [TBool, TInt, TFloat, TStr, TList, TTuple, TDict, TSet, TAny]"

fun fits :: "ty \<Rightarrow> slot \<Rightarrow> bool" where
  "fits t (STy u) \<longleftrightarrow> t = u"
| "fits t SNum \<longleftrightarrow> t = TInt \<or> t = TFloat"
| "fits t SSeq \<longleftrightarrow> t = TList \<or> t = TTuple \<or> t = TStr"
| "fits t SColl \<longleftrightarrow> t = TList \<or> t = TTuple \<or> t = TSet"
| "fits t SAny \<longleftrightarrow> True"

text \<open>The pool admission of the organ's search: a term whose type is
``any'' (unknown) is admitted into every pool (code_organ_v3: \<open>fits(t, want)
or t == "any"\<close>).\<close>

definition connects :: "ty \<Rightarrow> slot \<Rightarrow> bool" where [simp]:
  "connects s w \<longleftrightarrow> fits s w \<or> s = TAny"

lemma connects_char: "connects s w \<longleftrightarrow> fits s w \<or> s = TAny"
  by (rule connects_def)

subsection \<open>The move library (31 of 146 moves, every slot shape covered)\<close>

datatype prim =
  P_add | P_sqrt | P_isqrt | P_isprime | P_digits | P_bin
| P_len | P_first | P_rev | P_take | P_at
| P_sorted | P_sorted_desc | P_inter | P_concat | P_upper | P_vowels | P_ispal
| P_f_even | P_range1 | P_mean | P_max
| P_eq | P_int | P_str | P_tolist | P_totuple | P_contains | P_count
| P_index | P_f_neq

fun insOf :: "prim \<Rightarrow> slot list" where
  "insOf P_add = [SNum, SNum]"
| "insOf P_sqrt = [SNum]"
| "insOf P_isqrt = [STy TInt]"
| "insOf P_isprime = [STy TInt]"
| "insOf P_digits = [STy TInt]"
| "insOf P_bin = [STy TInt]"
| "insOf P_len = [SSeq]"
| "insOf P_first = [SSeq]"
| "insOf P_rev = [SSeq]"
| "insOf P_take = [SSeq, STy TInt]"
| "insOf P_at = [SSeq, STy TInt]"
| "insOf P_sorted = [SColl]"
| "insOf P_sorted_desc = [SColl]"
| "insOf P_inter = [SColl, SColl]"
| "insOf P_concat = [SSeq, SSeq]"
| "insOf P_upper = [STy TStr]"
| "insOf P_vowels = [STy TStr]"
| "insOf P_ispal = [SSeq]"
| "insOf P_f_even = [SColl]"
| "insOf P_range1 = [STy TInt]"
| "insOf P_mean = [SColl]"
| "insOf P_max = [SColl]"
| "insOf P_eq = [SAny, SAny]"
| "insOf P_int = [SAny]"
| "insOf P_str = [SAny]"
| "insOf P_tolist = [SAny]"
| "insOf P_totuple = [SAny]"
| "insOf P_contains = [SAny, SSeq]"
| "insOf P_count = [SSeq, SAny]"
| "insOf P_index = [SSeq, SAny]"
| "insOf P_f_neq = [SColl, SAny]"

text \<open>Output types: the organ's declared column, with group outputs as the
list of their member base types.\<close>

fun outsOf :: "prim \<Rightarrow> ty list" where
  "outsOf P_add = num_tys"
| "outsOf P_sqrt = [TFloat]"
| "outsOf P_isqrt = [TInt]"
| "outsOf P_isprime = [TBool]"
| "outsOf P_digits = [TList]"
| "outsOf P_bin = [TStr]"
| "outsOf P_len = [TInt]"
| "outsOf P_first = any_tys"
| "outsOf P_rev = seq_tys"
| "outsOf P_take = seq_tys"
| "outsOf P_at = any_tys"
| "outsOf P_sorted = [TList]"
| "outsOf P_sorted_desc = [TList]"
| "outsOf P_inter = [TTuple]"
| "outsOf P_concat = seq_tys"
| "outsOf P_upper = [TStr]"
| "outsOf P_vowels = [TInt]"
| "outsOf P_ispal = [TBool]"
| "outsOf P_f_even = [TList]"
| "outsOf P_range1 = [TList]"
| "outsOf P_mean = [TFloat]"
| "outsOf P_max = any_tys"
| "outsOf P_eq = [TBool]"
| "outsOf P_int = [TInt]"
| "outsOf P_str = [TStr]"
| "outsOf P_tolist = [TList]"
| "outsOf P_totuple = [TTuple]"
| "outsOf P_contains = [TBool]"
| "outsOf P_count = [TInt]"
| "outsOf P_index = [TInt]"
| "outsOf P_f_neq = [TList]"

fun nameOf :: "prim \<Rightarrow> String.literal" where
  "nameOf P_add = STR ''add''"
| "nameOf P_sqrt = STR ''sqrt''"
| "nameOf P_isqrt = STR ''isqrt''"
| "nameOf P_isprime = STR ''isprime''"
| "nameOf P_digits = STR ''digits''"
| "nameOf P_bin = STR ''bin''"
| "nameOf P_len = STR ''len''"
| "nameOf P_first = STR ''first''"
| "nameOf P_rev = STR ''rev''"
| "nameOf P_take = STR ''take''"
| "nameOf P_at = STR ''at''"
| "nameOf P_sorted = STR ''sorted''"
| "nameOf P_sorted_desc = STR ''sorted_desc''"
| "nameOf P_inter = STR ''inter''"
| "nameOf P_concat = STR ''concat''"
| "nameOf P_upper = STR ''upper''"
| "nameOf P_vowels = STR ''vowels''"
| "nameOf P_ispal = STR ''ispal''"
| "nameOf P_f_even = STR ''f_even''"
| "nameOf P_range1 = STR ''range1''"
| "nameOf P_mean = STR ''mean''"
| "nameOf P_max = STR ''max''"
| "nameOf P_eq = STR ''eq''"
| "nameOf P_int = STR ''int''"
| "nameOf P_str = STR ''str''"
| "nameOf P_tolist = STR ''tolist''"
| "nameOf P_totuple = STR ''totuple''"
| "nameOf P_contains = STR ''contains''"
| "nameOf P_count = STR ''count''"
| "nameOf P_index = STR ''index''"
| "nameOf P_f_neq = STR ''f_neq''"

definition all_prims :: "prim list" where
  "all_prims = [P_add, P_sqrt, P_isqrt, P_isprime, P_digits, P_bin, P_len,
    P_first, P_rev, P_take, P_at, P_sorted, P_sorted_desc, P_inter, P_concat,
    P_upper, P_vowels, P_ispal, P_f_even, P_range1, P_mean, P_max, P_eq,
    P_int, P_str, P_tolist, P_totuple, P_contains, P_count, P_index, P_f_neq]"

lemma all_prims_complete: "p \<in> set all_prims"
  by (cases p) (simp_all add: all_prims_def)

lemma outs_nonempty: "outsOf p \<noteq> []"
  by (cases p) simp_all

fun tyName :: "ty \<Rightarrow> String.literal" where
  "tyName TBool = STR ''bool''"
| "tyName TInt = STR ''int''"
| "tyName TFloat = STR ''float''"
| "tyName TStr = STR ''str''"
| "tyName TList = STR ''list''"
| "tyName TTuple = STR ''tuple''"
| "tyName TDict = STR ''dict''"
| "tyName TSet = STR ''set''"
| "tyName TAny = STR ''any''"

fun slotName :: "slot \<Rightarrow> String.literal" where
  "slotName SNum = STR ''num''"
| "slotName SSeq = STR ''seq''"
| "slotName SColl = STR ''coll''"
| "slotName SAny = STR ''any''"
| "slotName (STy t) = tyName t"

subsection \<open>Programs and their candidate types\<close>

datatype prog = Arg nat | Konst int | App prim "prog list"

text \<open>\<^term>\<open>tys sig u\<close> is the list of candidate base types of \<open>u\<close> under the
argument signature \<open>sig\<close>; the empty list means rejected: an argument is
absent, or some child of an application does not connect to its slot.
\<^term>\<open>slots_ok sig ws ts\<close> is the pool admission of the search, one slot at a
time: the children and slots pair up, and every child has a type with all of
its candidate types connecting to that slot.\<close>

fun tys :: "(nat \<Rightarrow> ty option) \<Rightarrow> prog \<Rightarrow> ty list"
  and slots_ok :: "(nat \<Rightarrow> ty option) \<Rightarrow> slot list \<Rightarrow> prog list \<Rightarrow> bool" where
  "tys sig (Arg i) = (case sig i of Some t \<Rightarrow> [t] | None \<Rightarrow> [])"
| "tys sig (Konst k) = [TInt]"
| "tys sig (App p ts) =
    (if slots_ok sig (insOf p) ts then outsOf p else [])"
| "slots_ok sig [] ts \<longleftrightarrow> ts = []"
| "slots_ok sig (w # ws) [] \<longleftrightarrow> False"
| "slots_ok sig (w # ws) (t # ts) \<longleftrightarrow>
     tys sig t \<noteq> [] \<and> (\<forall>s \<in> set (tys sig t). connects s w) \<and>
     slots_ok sig ws ts"

fun subterms :: "prog \<Rightarrow> prog list" where
  "subterms (Arg i) = [Arg i]"
| "subterms (Konst k) = [Konst k]"
| "subterms (App p ts) = App p ts # concat (map subterms ts)"

text \<open>The composition rule as an inductive predicate: \<^term>\<open>enum sig u\<close>
holds for exactly the programs the organ's bottom-up search can build from the
arguments and constants of a request with signature \<open>sig\<close>: the children of
an application all come from the enumeration (they were pool members) and the
pools admitted them slot by slot.\<close>

inductive enum :: "(nat \<Rightarrow> ty option) \<Rightarrow> prog \<Rightarrow> bool" where
  enum_arg: "sig i = Some t \<Longrightarrow> enum sig (Arg i)"
| enum_konst: "enum sig (Konst k)"
| enum_app:
  "\<lbrakk> slots_ok sig (insOf p) ts; \<forall>t \<in> set ts. enum sig t \<rbrakk>
   \<Longrightarrow> enum sig (App p ts)"

subsection \<open>The composition rule, stated and proved\<close>

lemma tys_app:
  "tys sig (App p ts) \<noteq> [] \<longleftrightarrow> slots_ok sig (insOf p) ts \<and> outsOf p \<noteq> []"
  by simp

lemma enum_appD:
  "enum sig (App p ts) \<Longrightarrow>
   slots_ok sig (insOf p) ts \<and> (\<forall>t \<in> set ts. enum sig t)"
  by (auto elim: enum.cases)

text \<open>Headline: every program the composition rule can build is well typed
(its candidate-type list is nonempty), and so is every node inside it.\<close>

theorem enum_well_typed: "enum sig u \<Longrightarrow> tys sig u \<noteq> []"
proof (induction u)
  case (Arg i)
  then show ?case by (auto elim: enum.cases)
next
  case (Konst k)
  then show ?case by simp
next
  case (App p ts)
  have so: "slots_ok sig (insOf p) ts"
    using enum_appD[OF App.prems] by blast
  have "tys sig (App p ts) = outsOf p" using so by simp
  then show ?case using outs_nonempty[of p] by simp
qed

lemma enum_subterm: "enum sig u \<Longrightarrow> v \<in> set (subterms u) \<Longrightarrow> enum sig v"
proof (induction u arbitrary: v)
  case (Arg i)
  then show ?case by (auto elim: enum.cases)
next
  case (Konst k)
  then show ?case by simp
next
  case (App p ts)
  have D: "\<forall>t \<in> set ts. enum sig t"
    using enum_appD[OF App.prems(1)] by blast
  from App.prems(2) have B: "v = App p ts \<or> v \<in> set (concat (map subterms ts))"
    by simp
  then show ?case
  proof
    assume "v = App p ts"
    then show ?thesis using App.prems(1) by simp
  next
    assume A: "v \<in> set (concat (map subterms ts))"
    then obtain t where t: "t \<in> set ts" "v \<in> set (subterms t)" by auto
    have en: "enum sig t" using D t(1) by auto
    from App.IH[OF t(1) en t(2)] show ?thesis .
  qed
qed

theorem enum_nodes_typed:
  assumes "enum sig u"
  shows "tys sig u \<noteq> []"
    and "\<And>v. v \<in> set (subterms u) \<Longrightarrow> tys sig v \<noteq> []"
proof -
  show "tys sig u \<noteq> []" using enum_well_typed assms by blast
  fix v assume "v \<in> set (subterms u)"
  then show "tys sig v \<noteq> []"
    using enum_well_typed enum_subterm[OF assms(1)] by blast
qed

text \<open>What the rule keeps out, as checkable instances: the search can never
form an application whose child does not connect.\<close>

lemma upper_const_rejected: "tys sig (App P_upper [Konst k]) = []"
  by simp

lemma sorted_const_rejected: "tys sig (App P_sorted [Konst k]) = []"
  by simp

lemma count_accepts: "sig 0 = Some TStr \<Longrightarrow> tys sig (App P_count [Arg 0, Konst 3]) = [TInt]"
  by simp

lemma unknown_connects_everywhere: "connects TAny w"
  by (simp add: connects_def)

end
