theory Pyref
  imports Pyref_Table
begin

text \<open>Lane S15-computing: python and python-r2
(upstream/root/specialists/python*/organ_pyref_v1.py; the two organs are the same
file and read the same JSON). Python 3.12.3 reference: signature, module,
docstring line of standard-library names, from the generated partial table.
The original 856 rows are preserved; separately sourced extensions are inventoried.
A missing row means no reference coverage, not that a runtime API does not exist.
The recognizer reads the question and the names it mentions; this kernel resolves
a name against the table, as the organ's _name does, and states the row.\<close>

fun pe_name :: "(String.literal \<times> String.literal \<times> String.literal \<times> String.literal \<times> String.literal \<times> String.literal) \<Rightarrow> String.literal" where
  "pe_name (n, p, s, m, g, d) = n"
fun pe_prefix where "pe_prefix (n, p, s, m, g, d) = p"
fun pe_short where "pe_short (n, p, s, m, g, d) = s"
fun pe_module where "pe_module (n, p, s, m, g, d) = m"
fun pe_sig where "pe_sig (n, p, s, m, g, d) = g"
fun pe_doc where "pe_doc (n, p, s, m, g, d) = d"

definition py_lookup where
  "py_lookup nm = find (\<lambda>e. pe_name e = nm) py_entries"

definition py_modules :: "String.literal list" where
  "py_modules = remdups (filter (\<lambda>p. p \<noteq> STR '''') (map pe_prefix py_entries)) @
     [STR ''math'', STR ''os'', STR ''sys'', STR ''re'', STR ''json'']"

definition py_types :: "String.literal list" where
  "py_types = [STR ''str'', STR ''list'', STR ''dict'', STR ''set'', STR ''tuple'', STR ''int'', STR ''float'', STR ''bytes'']"

definition py_by_short :: "String.literal \<Rightarrow> String.literal list" where
  "py_by_short c = map pe_name (filter (\<lambda>e. pe_short e = c) py_entries)"

text \<open>A name candidate as the recognizer read it from the question: the text, its
module and attribute when it has a dot (split at the last dot), and whether the
text is longer than two characters.\<close>
datatype pycand = PyCand String.literal "(String.literal \<times> String.literal) option" bool

datatype pyres = PyFound String.literal | PyAmbig "String.literal list" | PyMissing String.literal String.literal | PyNone

fun py_resolve :: "pycand list \<Rightarrow> pyres" where
  "py_resolve [] = PyNone"
| "py_resolve (PyCand c dotted long # rest) =
    (if py_lookup c \<noteq> None then PyFound c
     else case dotted of
       Some (m, a) \<Rightarrow>
         (if m + STR ''.'' + a = c \<and> (m \<in> set py_modules \<or> m \<in> set py_types) then PyMissing m a else py_resolve rest)
     | None \<Rightarrow>
         (if long \<and> py_by_short c \<noteq> [] then
            (case py_by_short c of [single] \<Rightarrow> PyFound single | many \<Rightarrow> PyAmbig many)
          else py_resolve rest))"

datatype pyask = PQ_module | PQ_signature | PQ_doc

definition join_lit :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_lit sep xs = (case xs of [] \<Rightarrow> STR '''' | x # r \<Rightarrow> foldl (\<lambda>a b. a + sep + b) x r)"

definition py_reply :: "pyask \<Rightarrow> pycand list \<Rightarrow> reply" where
  "py_reply q cs = (case py_resolve cs of
      PyNone \<Rightarrow> Reply False (STR ''not_taken'') (STR '''') None
    | PyMissing m a \<Rightarrow> Reply False (STR ''unknown'')
        (STR ''My Python '' + py_version + STR '' reference has no entry for '' + m + STR ''.'' + a + STR ''. This does not establish whether the API exists.'') None
    | PyAmbig ns \<Rightarrow> Reply False (STR ''clarify'')
        (STR ''Several standard-library names match: '' + join_lit (STR '', '') (take 5 (sort ns))
          + STR ''. Which one do you mean?'') None
    | PyFound nm \<Rightarrow> (case py_lookup nm of None \<Rightarrow> Reply False (STR ''not_taken'') (STR '''') None
        | Some e \<Rightarrow>
          (case q of
             PQ_module \<Rightarrow> Reply True (STR ''module'')
               (nm + STR '' is in the '' + pe_module e + STR '' module (Python '' + py_version + STR '').'') (Some (pe_module e))
           | PQ_signature \<Rightarrow>
               (if pe_sig e = STR '''' then Reply False (STR ''no_signature'')
                  (STR ''My Python '' + py_version + STR '' reference has no recorded signature for '' + nm
                    + STR '', so I won'' + apos + STR ''t guess its parameters.'') None
                else Reply True (STR ''signature'')
                  (nm + STR '' - signature '' + pe_sig e + STR '' (Python '' + py_version + STR '').'') (Some (pe_sig e)))
           | PQ_doc \<Rightarrow> Reply True (STR ''doc'')
               (nm + STR '': '' + (if pe_doc e = STR '''' then STR ''(no documentation recorded in this reference)'' else pe_doc e) + STR '' Call it as ''
                 + (if pe_sig e = STR '''' then nm else nm + pe_sig e) + STR '' (Python '' + py_version + STR '').'')
               (Some (pe_doc e)))))"

text \<open>Lane S15b: the table facts that names are distinct, that each name is its
prefix, a dot and its short name, and that the table has 856 rows were stated here
with proof by evaluation; evaluation is a code-generator oracle, which the export
refuses. They are checked by tables_check.py instead (not a proof); the resolver
below does not depend on them (it takes the first row with the name).\<close>

theorem py_lookup_sound: "py_lookup nm = Some e \<Longrightarrow> e \<in> set py_entries \<and> pe_name e = nm"
  by (auto simp: py_lookup_def dest: findSomeD)

theorem py_lookup_complete: "e \<in> set py_entries \<Longrightarrow> py_lookup (pe_name e) \<noteq> None"
  unfolding py_lookup_def find_None_iff by blast

theorem py_found_in_table:
  "py_resolve cs = PyFound nm \<Longrightarrow> \<exists>e \<in> set py_entries. pe_name e = nm"
proof (induction cs)
  case Nil then show ?case by simp
next
  case (Cons p rest)
  obtain c dotted long where p: "p = PyCand c dotted long" by (cases p)
  show ?case
  proof (cases "py_lookup c = None")
    case False
    then obtain e where e: "py_lookup c = Some e" by auto
    from Cons.prems p False have "nm = c" by simp
    with py_lookup_sound[OF e] show ?thesis by blast
  next
    case lk: True
    show ?thesis
    proof (cases dotted)
      case None
      show ?thesis
      proof (cases "long \<and> py_by_short c \<noteq> []")
        case True
        with Cons.prems p lk None
        have "(case py_by_short c of [single] \<Rightarrow> PyFound single | many \<Rightarrow> PyAmbig many) = PyFound nm" by simp
        then have "nm \<in> set (py_by_short c)" by (auto split: list.splits)
        then obtain e where e1: "e \<in> set (filter (\<lambda>e. pe_short e = c) py_entries)" and e2: "pe_name e = nm"
          unfolding py_by_short_def set_map by blast
        from e1 have "e \<in> set py_entries" by simp
        with e2 show ?thesis by blast
      next
        case False
        with Cons.prems p lk None have "py_resolve rest = PyFound nm" by simp
        then show ?thesis by (rule Cons.IH)
      qed
    next
      case (Some ma)
      obtain m' a' where ma: "ma = (m', a')" by (cases ma)
      show ?thesis
      proof (cases "m' + STR ''.'' + a' = c \<and> (m' \<in> set py_modules \<or> m' \<in> set py_types)")
        case True
        with Cons.prems p lk Some ma show ?thesis by simp
      next
        case False
        with Cons.prems p lk Some ma have "py_resolve rest = PyFound nm" by simp
        then show ?thesis by (rule Cons.IH)
      qed
    qed
  qed
qed

lemma py_found_lookup: "py_resolve cs = PyFound nm \<Longrightarrow> py_lookup nm \<noteq> None"
  using py_found_in_table py_lookup_complete by blast

theorem py_missing_sound:
  "py_resolve cs = PyMissing m a \<Longrightarrow> py_lookup (m + STR ''.'' + a) = None \<and> (m \<in> set py_modules \<or> m \<in> set py_types)"
proof (induction cs)
  case Nil then show ?case by simp
next
  case (Cons p rest)
  obtain c dotted long where p: "p = PyCand c dotted long" by (cases p)
  show ?case
  proof (cases "py_lookup c = None")
    case False
    with Cons.prems p show ?thesis by simp
  next
    case lk: True
    show ?thesis
    proof (cases dotted)
      case None
      show ?thesis
      proof (cases "long \<and> py_by_short c \<noteq> []")
        case True
        with Cons.prems p lk None
        have "(case py_by_short c of [single] \<Rightarrow> PyFound single | many \<Rightarrow> PyAmbig many) = PyMissing m a" by simp
        then show ?thesis by (auto split: list.splits)
      next
        case False
        with Cons.prems p lk None have "py_resolve rest = PyMissing m a" by simp
        then show ?thesis by (rule Cons.IH)
      qed
    next
      case (Some ma)
      obtain m' a' where ma: "ma = (m', a')" by (cases ma)
      show ?thesis
      proof (cases "m' + STR ''.'' + a' = c \<and> (m' \<in> set py_modules \<or> m' \<in> set py_types)")
        case True
        with Cons.prems p lk Some ma have "m = m'" "a = a'" by simp_all
        with True lk show ?thesis by simp
      next
        case False
        with Cons.prems p lk Some ma have "py_resolve rest = PyMissing m a" by simp
        then show ?thesis by (rule Cons.IH)
      qed
    qed
  qed
qed

theorem py_missing_is_reference_absence:
  assumes "py_resolve cs = PyMissing m a"
  shows "\<not> (\<exists>e \<in> set py_entries. pe_name e = m + STR ''.'' + a)"
    and "\<not> answered (py_reply q cs)"
proof -
  have missing: "py_lookup (m + STR ''.'' + a) = None"
    using py_missing_sound[OF assms] by (rule conjunct1)
  show "\<not> (\<exists>e \<in> set py_entries. pe_name e = m + STR ''.'' + a)"
  proof
    assume "\<exists>e \<in> set py_entries. pe_name e = m + STR ''.'' + a"
    then obtain e where member: "e \<in> set py_entries" and name: "pe_name e = m + STR ''.'' + a"
      by blast
    have "py_lookup (pe_name e) \<noteq> None" by (rule py_lookup_complete[OF member])
    with missing name show False by simp
  qed
  show "\<not> answered (py_reply q cs)" using assms by (simp add: py_reply_def)
qed

theorem py_signature_states_row:
  assumes "py_resolve cs = PyFound nm" "py_lookup nm = Some e" "pe_sig e \<noteq> STR ''''"
  shows "answered (py_reply PQ_signature cs) \<and> stated (py_reply PQ_signature cs) = Some (pe_sig e) \<and>
         response (py_reply PQ_signature cs) = nm + STR '' - signature '' + pe_sig e + STR '' (Python '' + py_version + STR '').''"
  using assms by (simp add: py_reply_def)

theorem py_module_states_row:
  assumes "py_resolve cs = PyFound nm" "py_lookup nm = Some e"
  shows "answered (py_reply PQ_module cs) \<and> stated (py_reply PQ_module cs) = Some (pe_module e)"
  using assms by (simp add: py_reply_def)

theorem py_doc_states_row:
  assumes "py_resolve cs = PyFound nm" "py_lookup nm = Some e"
  shows "answered (py_reply PQ_doc cs) \<and> stated (py_reply PQ_doc cs) = Some (pe_doc e)"
  using assms by (simp add: py_reply_def)

theorem py_withheld_iff:
  "\<not> answered (py_reply q cs) \<longleftrightarrow>
     py_resolve cs = PyNone \<or> (\<exists>m a. py_resolve cs = PyMissing m a) \<or> (\<exists>ns. py_resolve cs = PyAmbig ns) \<or>
     (\<exists>nm e. py_resolve cs = PyFound nm \<and> py_lookup nm = Some e \<and> q = PQ_signature \<and> pe_sig e = STR '''')"
proof (cases "py_resolve cs")
  case (PyFound nm)
  from py_found_lookup[OF PyFound] obtain n p s m g d where e: "py_lookup nm = Some (n, p, s, m, g, d)" by auto
  show ?thesis using PyFound e by (cases q) (auto simp: py_reply_def)
qed (auto simp: py_reply_def)

definition py_self_test :: bool where
  "py_self_test \<longleftrightarrow>
     (case py_lookup (STR ''bytes.partition'') of Some e \<Rightarrow> pe_sig e = STR ''(self, sep, /)'' | None \<Rightarrow> False) \<and>
     py_resolve [PyCand (STR ''math.frobnicate'') (Some (STR ''math'', STR ''frobnicate'')) True] = PyMissing (STR ''math'') (STR ''frobnicate'') \<and>
     py_resolve [PyCand (STR ''zzzz'') None True] = PyNone \<and>
     (case py_resolve [PyCand (STR ''split'') None True] of PyAmbig ns \<Rightarrow> 2 \<le> length ns | _ \<Rightarrow> False) \<and>
     response (py_reply PQ_module [PyCand (STR ''sys.set_asyncgen_hooks'') (Some (STR ''sys'', STR ''set_asyncgen_hooks'')) True]) =
       STR ''sys.set_asyncgen_hooks is in the sys module (Python 3.12.3).''"

end
