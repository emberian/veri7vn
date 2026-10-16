theory Mathematics_ASCII
  imports Mathematics_Syntax
begin

text \<open>A deliberately small postfix byte grammar: unsigned/signed decimal
integers, pN parameters, ^N powers, + * / neg abs, separated by ASCII whitespace.
The byte decoder and expression evaluator are generated pure HOL functions.
Natural-language arithmetic syntax is a separate interpretation binding.\<close>
fun decimal_value :: "nat list \<Rightarrow> nat" where
  "decimal_value [] = 0"
| "decimal_value (d#ds) = (d-48)*10^(length ds) + decimal_value ds"

fun read_digits :: "nat \<Rightarrow> nat list \<Rightarrow> nat option" where
  "read_digits acc [] = Some acc"
| "read_digits acc (d#ds) = (if 48 \<le> d \<and> d \<le> 57 then read_digits (10*acc+(d-48)) ds else None)"

definition read_unsigned where
  "read_unsigned ds = (if ds=[] then None else read_digits 0 ds)"

lemma digit_accumulator_arithmetic:
  fixes a v k w :: nat
  shows "(10*a+v)*10^k+w = a*10^(Suc k)+(v*10^k+w)"
  by (simp add: power_Suc algebra_simps)

lemma read_digits_sound:
  "read_digits acc ds = Some n \<Longrightarrow>
   (\<forall>d\<in>set ds. 48 \<le> d \<and> d \<le> 57) \<and> n=acc*10^(length ds)+decimal_value ds"
proof (induction ds arbitrary: acc n)
  case Nil
  then show ?case by simp
next
  case (Cons d ds)
  have digit: "48 \<le> d \<and> d \<le> 57" and tail: "read_digits (10*acc+(d-48)) ds = Some n"
    using Cons.prems by (auto split: if_splits)
  have induction_tail: "(\<forall>d\<in>set ds. 48 \<le> d \<and> d \<le> 57) \<and>
    n=(10*acc+(d-48))*10^(length ds)+decimal_value ds"
    using Cons.IH[OF tail] .
  show ?case
    using digit induction_tail digit_accumulator_arithmetic[of acc "d-48" "length ds" "decimal_value ds"]
    by simp
qed

lemma read_unsigned_sound:
  "read_unsigned ds = Some n \<Longrightarrow> ds \<noteq> [] \<and>
   (\<forall>d\<in>set ds. 48 \<le> d \<and> d \<le> 57) \<and> n=decimal_value ds"
  using read_digits_sound[of 0 ds n] by (auto simp: read_unsigned_def split: if_splits)

definition ascii_whitespace :: "nat \<Rightarrow> bool" where
  "ascii_whitespace b \<longleftrightarrow> b \<in> {9,10,13,32}"

definition word_step :: "(nat list list \<times> nat list) \<Rightarrow> nat \<Rightarrow> (nat list list \<times> nat list)" where
  "word_step state b = (case state of (words,current) \<Rightarrow>
    if ascii_whitespace b then (if current=[] then (words,[]) else (rev current#words,[]))
    else (words,b#current))"

definition ascii_words :: "nat list \<Rightarrow> nat list list" where
  "ascii_words bytes = (case foldl word_step ([],[]) bytes of (words,current) \<Rightarrow>
     rev (if current=[] then words else rev current#words))"

fun ascii_token :: "nat list \<Rightarrow> math_token option" where
  "ascii_token [] = None"
| "ascii_token (c#cs) =
   (if c=43 \<and> cs=[] then Some PlusToken
    else if c=42 \<and> cs=[] then Some TimesToken
    else if c=47 \<and> cs=[] then Some DivideToken
    else if c#cs=[110,101,103] then Some NegateToken
    else if c#cs=[97,98,115] then Some AbsoluteToken
    else if c=94 then map_option PowerToken (read_unsigned cs)
    else if c=112 then map_option ParameterToken (read_unsigned cs)
    else if c=45 then map_option (\<lambda>n. FractionToken (-int n) 1) (read_unsigned cs)
    else map_option (\<lambda>n. FractionToken (int n) 1) (read_unsigned (c#cs)))"

fun decode_words :: "nat list list \<Rightarrow> math_token list option" where
  "decode_words [] = Some []"
| "decode_words (w#ws) = (case ascii_token w of None \<Rightarrow> None | Some t \<Rightarrow> map_option ((#) t) (decode_words ws))"

datatype math_input_result = SyntaxRejected | BoundExceeded | ParametersMissing "nat list" | Computed "rat option"

fun token_budget :: "nat \<Rightarrow> math_token \<Rightarrow> bool" where
  "token_budget max_power (PowerToken n) = (n \<le> max_power)"
| "token_budget max_power _ = True"

definition evaluate_ascii where
  "evaluate_ascii max_bytes max_tokens max_power env bytes =
    (if length bytes > max_bytes then BoundExceeded else
      (let words = ascii_words bytes in
       if length words > max_tokens then BoundExceeded else
       case decode_words words of None \<Rightarrow> SyntaxRejected | Some tokens \<Rightarrow>
        (if \<not> list_all (token_budget max_power) tokens then BoundExceeded else
         case parse_math tokens of None \<Rightarrow> SyntaxRejected | Some expression \<Rightarrow>
          (let missing = missing_math_parameters env expression in
           if missing \<noteq> [] then ParametersMissing missing else Computed (math_eval env expression)))))"

lemma evaluate_ascii_refinement:
  "evaluate_ascii max_bytes max_tokens max_power env bytes = Computed (Some q) \<Longrightarrow>
   \<exists>tokens expression. decode_words (ascii_words bytes) = Some tokens \<and>
     parse_math tokens = Some expression \<and> missing_math_parameters env expression=[] \<and> math_value env expression q"
  by (auto simp: evaluate_ascii_def Let_def math_eval_refinement split: if_splits option.splits)

lemma evaluate_ascii_undefined_refinement:
  "evaluate_ascii max_bytes max_tokens max_power env bytes = Computed None \<Longrightarrow>
   \<exists>tokens expression. decode_words (ascii_words bytes) = Some tokens \<and>
     parse_math tokens = Some expression \<and> missing_math_parameters env expression=[] \<and> \<not> (\<exists>q. math_value env expression q)"
  by (auto simp: evaluate_ascii_def Let_def math_eval_no_value
    split: if_splits option.splits)

export_code evaluate_ascii in SML module_name Mathematics_ASCII
end
