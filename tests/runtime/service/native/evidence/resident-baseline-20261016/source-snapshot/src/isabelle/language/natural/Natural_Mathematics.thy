theory Natural_Mathematics
  imports Veri7vn_Mathematics.Mathematics_ASCII
    Veri7vn_Interpretation_Core.Veri7vn_Grammar
begin

datatype binary_word = Sum | Difference | Product | Quotient | SubtractFrom
record binary_rule =
  cue_before :: "nat list"
  cue_between :: "nat list"
  cue_after :: "nat list"
  binary_word :: binary_word
record math_reading =
  expression :: math_expr
  literal_spans :: "span list"
  declared_operation :: binary_word

definition read_integer where
  "read_integer raw = (case ascii_token raw of
     Some (FractionToken n d) \<Rightarrow> if d=1 then Some n else None | _ \<Rightarrow> None)"
definition integer_literal where
  "integer_literal raw = map_option (\<lambda>n. of_int n::rat) (read_integer raw)"
primrec binary_expression where
  "binary_expression Sum a b = Plus (Rational a) (Rational b)" |
  "binary_expression Difference a b = Plus (Rational a) (Negate (Rational b))" |
  "binary_expression Product a b = Times (Rational a) (Rational b)" |
  "binary_expression Quotient a b = Divide (Rational a) (Rational b)" |
  "binary_expression SubtractFrom a b = Plus (Rational b) (Negate (Rational a))"

datatype binary_attempt = LiteralBlocked "span list" | Reading math_reading

definition attempt_binary where
  "attempt_binary xs r i = (let a=length (cue_before r);
    b=i+length (cue_between r); e=length xs-length (cue_after r);
    left=slice xs (a,i); right=slice xs (b,e) in
    if a\<le>i \<and> b\<le>e \<and> e\<le>length xs \<and>
       xs=cue_before r @ left @ cue_between r @ right @ cue_after r
    then Some (case (integer_literal left,integer_literal right) of
      (Some x,Some y) \<Rightarrow> Reading
        \<lparr>expression=binary_expression (binary_word r) x y,
          literal_spans=[(a,i),(b,e)], declared_operation=binary_word r\<rparr>
      | _ \<Rightarrow> LiteralBlocked
          ((if integer_literal left=None then [(a,i)] else []) @
           (if integer_literal right=None then [(b,e)] else [])))
    else None)"

definition reading_derivation :: "nat list \<Rightarrow> binary_rule \<Rightarrow> math_reading \<Rightarrow> bool" where
  "reading_derivation xs r d \<longleftrightarrow> (\<exists>a i b e x y.
    literal_spans d=[(a,i),(b,e)] \<and>
    valid_span xs (a,i) \<and> valid_span xs (b,e) \<and>
    xs=cue_before r @ slice xs (a,i) @ cue_between r @ slice xs (b,e) @ cue_after r \<and>
    integer_literal (slice xs (a,i))=Some x \<and>
    integer_literal (slice xs (b,e))=Some y \<and>
    expression d=binary_expression (binary_word r) x y \<and>
    declared_operation d=binary_word r)"
lemma binary_attempt_sound:
  "attempt_binary xs r i=Some (Reading d) \<Longrightarrow> reading_derivation xs r d"
  by (fastforce simp: attempt_binary_def reading_derivation_def Let_def valid_span_def
    split: if_splits option.splits)

text \<open>These are declared source-backed binary_phrase forms, not an unrestricted
English parser. Original captures reach the native family parser unchanged.\<close>
definition binary_rules :: "binary_rule list" where
  "binary_rules = [\<lparr>cue_before=[116,104,101,32,115,117,109,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Sum\<rparr>,
    \<lparr>cue_before=[116,104,101,32,115,117,109,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Sum\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,115,117,109,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Sum\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,115,117,109,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Sum\<rparr>,
    \<lparr>cue_before=[116,104,101,32,100,105,102,102,101,114,101,110,99,101,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Difference\<rparr>,
    \<lparr>cue_before=[116,104,101,32,100,105,102,102,101,114,101,110,99,101,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Difference\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,100,105,102,102,101,114,101,110,99,101,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Difference\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,100,105,102,102,101,114,101,110,99,101,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Difference\<rparr>,
    \<lparr>cue_before=[116,104,101,32,112,114,111,100,117,99,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Product\<rparr>,
    \<lparr>cue_before=[116,104,101,32,112,114,111,100,117,99,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Product\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,112,114,111,100,117,99,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Product\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,112,114,111,100,117,99,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Product\<rparr>,
    \<lparr>cue_before=[116,104,101,32,113,117,111,116,105,101,110,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Quotient\<rparr>,
    \<lparr>cue_before=[116,104,101,32,113,117,111,116,105,101,110,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Quotient\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,113,117,111,116,105,101,110,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[],binary_word=Quotient\<rparr>,
    \<lparr>cue_before=[119,104,97,116,32,105,115,32,116,104,101,32,113,117,111,116,105,101,110,116,32,111,102,32],cue_between=[32,97,110,100,32],cue_after=[63],binary_word=Quotient\<rparr>,
    \<lparr>cue_before=[115,117,98,116,114,97,99,116,32],cue_between=[32,102,114,111,109,32],cue_after=[],binary_word=SubtractFrom\<rparr>,
    \<lparr>cue_before=[115,117,98,116,114,97,99,116,32],cue_between=[32,102,114,111,109,32],cue_after=[63],binary_word=SubtractFrom\<rparr>]"
record math_interpretation =
  language_applicable :: bool
  math_alternatives :: "math_reading list"
  literal_obstructions :: "span list list"
  interpretation_budget_exceeded :: bool
fun reading_of where
  "reading_of (Reading d)=Some d" | "reading_of (LiteralBlocked ss)=None"
lemma reading_of_iff [simp]: "reading_of a=Some d \<longleftrightarrow> a=Reading d"
  by (cases a) auto
fun obstruction_of where
  "obstruction_of (Reading d)=None" | "obstruction_of (LiteralBlocked ss)=Some ss"
definition interpret_math where
  "interpret_math xs = (if length xs>256 then
      \<lparr>language_applicable=False, math_alternatives=[], literal_obstructions=[],
        interpretation_budget_exceeded=True\<rparr>
    else (let applicable=list_ex (\<lambda>r.
      take (length (cue_before r)) xs=cue_before r) binary_rules;
    attempts=concat (map (\<lambda>r. List.map_filter (attempt_binary xs r) [0..<length xs]) binary_rules)
    in \<lparr>language_applicable=applicable,
      math_alternatives=List.map_filter reading_of attempts,
      literal_obstructions=List.map_filter obstruction_of attempts,
      interpretation_budget_exceeded=False\<rparr>))"
lemma membership_map_filter:
  "y\<in>set (List.map_filter f xs) \<longleftrightarrow> (\<exists>x\<in>set xs. f x=Some y)"
  by (induction xs) (auto split: option.splits)
lemma interpretation_sound:
  "d\<in>set (math_alternatives (interpret_math xs)) \<Longrightarrow>
    \<exists>r\<in>set binary_rules. reading_derivation xs r d"
  by (auto simp: interpret_math_def Let_def membership_map_filter
    dest!: binary_attempt_sound split: if_splits binary_attempt.splits)

primrec operation_number :: "binary_word \<Rightarrow> nat" where
  "operation_number Sum=0" | "operation_number Difference=1" |
  "operation_number Product=2" | "operation_number Quotient=3" |
  "operation_number SubtractFrom=4"
definition interpretation_packet where
  "interpretation_packet xs = (let r=interpret_math xs in
    (language_applicable r, interpretation_budget_exceeded r,
     map (\<lambda>d. (operation_number (declared_operation d),literal_spans d)) (math_alternatives r),
     literal_obstructions r))"
definition math_expression_at where
  "math_expression_at xs index = (let ds=math_alternatives (interpret_math xs) in
    if index<length ds then Some (expression (ds!index)) else None)"
lemma selected_expression_sound:
  "math_expression_at xs index=Some e \<Longrightarrow>
    \<exists>r\<in>set binary_rules. \<exists>d. reading_derivation xs r d \<and> expression d=e"
proof -
  assume selected: "math_expression_at xs index=Some e"
  let ?ds = "math_alternatives (interpret_math xs)"
  have bound: "index<length ?ds" and expression: "expression (?ds!index)=e"
    using selected by (auto simp: math_expression_at_def Let_def split: if_splits)
  have member: "?ds!index\<in>set ?ds" by (rule nth_mem[OF bound])
  obtain r where member_rule: "r\<in>set binary_rules"
    and derived: "reading_derivation xs r (?ds!index)"
    using interpretation_sound[OF member] by blast
  show "\<exists>r\<in>set binary_rules. \<exists>d. reading_derivation xs r d \<and> expression d=e"
    apply (rule bexI[where x=r])
     apply (rule exI[where x="?ds!index"])
     apply (rule conjI)
      apply (rule derived)
     apply (rule expression)
    apply (rule member_rule)
    done
qed
end
