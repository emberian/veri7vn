theory JS_Expr
  imports "Veri7vn_Commons.Commons_Num"
begin

text \<open>A finite expression model following ECMAScript primitive operations.
Numbers are mathematical integers guarded to the safe-integer interval at every
step. This is not a formal IEEE-754 implementation or the full ECMAScript language.
The parser, ASCII string framing and correspondence between this integer subset
and an actual JavaScript implementation remain explicit assumptions.\<close>

datatype js_value = JNum int | JStr String.literal | JBool bool | JNull | JUndef | JNaN
datatype js_op = JAdd | JSub | JStrict | JLoose
datatype js_expr = JLit js_value | JBin js_op js_expr js_expr | JTypeof js_expr

definition js_limit :: int where "js_limit = 9007199254740991"
fun js_safe :: "js_value \<Rightarrow> bool" where
  "js_safe (JNum n) = (\<bar>n\<bar> \<le> js_limit)"
| "js_safe _ = True"

fun js_text :: "js_value \<Rightarrow> String.literal" where
  "js_text (JNum n) = show_int n"
| "js_text (JStr s) = s"
| "js_text (JBool b) = (if b then STR ''true'' else STR ''false'')"
| "js_text JNull = STR ''null''"
| "js_text JUndef = STR ''undefined''"
| "js_text JNaN = STR ''NaN''"

fun js_type :: "js_value \<Rightarrow> String.literal" where
  "js_type (JNum n) = STR ''number''"
| "js_type (JStr s) = STR ''string''"
| "js_type (JBool b) = STR ''boolean''"
| "js_type JNull = STR ''object''"
| "js_type JUndef = STR ''undefined''"
| "js_type JNaN = STR ''number''"

definition js_space :: "char \<Rightarrow> bool" where
  "js_space c \<longleftrightarrow> c \<in> {CHR 0x20, CHR 0x09, CHR 0x0a, CHR 0x0d}"
definition js_trim :: "string \<Rightarrow> string" where
  "js_trim cs = rev (dropWhile js_space (rev (dropWhile js_space cs)))"
definition js_decimal :: "string \<Rightarrow> int option" where
  "js_decimal cs = (if cs = [] \<or> \<not> list_all (\<lambda>c. 48 \<le> (of_char c :: nat) \<and> (of_char c :: nat) \<le> 57) cs
    then None else Some (foldl (\<lambda>n c. 10*n + int (of_char c :: nat) - 48) 0 cs))"
definition js_parse_decimal :: "String.literal \<Rightarrow> int option" where
  "js_parse_decimal s = (let cs = js_trim (String.explode s) in
    if cs = [] then Some 0
    else if hd cs = CHR 0x2d then map_option uminus (js_decimal (tl cs))
    else if hd cs = CHR 0x2b then js_decimal (tl cs) else js_decimal cs)"

definition js_parse_num :: "String.literal \<Rightarrow> int option" where
  "js_parse_num s = (case js_parse_decimal s of None \<Rightarrow> None | Some n \<Rightarrow>
    if \<bar>n\<bar> \<le> js_limit then Some n else None)"

lemma js_parse_num_bounded:
  "js_parse_num s = Some n \<Longrightarrow> \<bar>n\<bar> \<le> js_limit"
  by (auto simp: js_parse_num_def split: option.splits if_splits)

text \<open>Unsupported numeric strings decline; they are not guessed to be NaN.
For example hexadecimal and fractional strings need a larger numeric model.\<close>
fun js_to_number :: "js_value \<Rightarrow> js_value option" where
  "js_to_number (JStr s) = map_option JNum (js_parse_num s)"
| "js_to_number (JBool b) = Some (JNum (if b then 1 else 0))"
| "js_to_number JNull = Some (JNum 0)"
| "js_to_number JUndef = Some JNaN"
| "js_to_number v = Some v"

fun js_strict :: "js_value \<Rightarrow> js_value \<Rightarrow> bool" where
  "js_strict JNaN b = False"
| "js_strict a JNaN = False"
| "js_strict a b = (a = b)"

fun js_unbool :: "js_value \<Rightarrow> js_value" where
  "js_unbool (JBool b) = JNum (if b then 1 else 0)"
| "js_unbool v = v"
fun js_loose_core :: "js_value \<Rightarrow> js_value \<Rightarrow> bool option" where
  "js_loose_core JNull JUndef = Some True"
| "js_loose_core JUndef JNull = Some True"
| "js_loose_core (JNum a) (JStr b) = map_option (\<lambda>n. a = n) (js_parse_num b)"
| "js_loose_core (JStr a) (JNum b) = map_option (\<lambda>n. n = b) (js_parse_num a)"
| "js_loose_core a b = Some (js_strict a b)"
definition js_loose :: "js_value \<Rightarrow> js_value \<Rightarrow> bool option" where
  "js_loose a b = js_loose_core (js_unbool a) (js_unbool b)"

fun js_numeric :: "js_op \<Rightarrow> js_value \<Rightarrow> js_value \<Rightarrow> js_value option" where
  "js_numeric op (JNum a) (JNum b) = (case op of JAdd \<Rightarrow> Some (JNum (a+b)) | JSub \<Rightarrow> Some (JNum (a-b)) | _ \<Rightarrow> None)"
| "js_numeric op JNaN b = Some JNaN"
| "js_numeric op a JNaN = Some JNaN"
| "js_numeric op a b = None"
definition js_numeric_apply :: "js_op \<Rightarrow> js_value \<Rightarrow> js_value \<Rightarrow> js_value option" where
  "js_numeric_apply op a b = (case js_to_number a of None \<Rightarrow> None | Some x \<Rightarrow>
     case js_to_number b of None \<Rightarrow> None | Some y \<Rightarrow> js_numeric op x y)"
fun js_apply :: "js_op \<Rightarrow> js_value \<Rightarrow> js_value \<Rightarrow> js_value option" where
  "js_apply JAdd (JStr a) b = Some (JStr (a + js_text b))"
| "js_apply JAdd a (JStr b) = Some (JStr (js_text a + b))"
| "js_apply JAdd a b = js_numeric_apply JAdd a b"
| "js_apply JSub a b = js_numeric_apply JSub a b"
| "js_apply JStrict a b = Some (JBool (js_strict a b))"
| "js_apply JLoose a b = map_option JBool (js_loose a b)"

definition js_checked :: "js_value option \<Rightarrow> js_value option" where
  "js_checked r = (case r of Some v \<Rightarrow> if js_safe v then Some v else None | None \<Rightarrow> None)"
fun js_eval :: "js_expr \<Rightarrow> js_value option" where
  "js_eval (JLit v) = js_checked (Some v)"
| "js_eval (JTypeof e) = map_option (JStr \<circ> js_type) (js_eval e)"
| "js_eval (JBin op e f) = (case js_eval e of None \<Rightarrow> None | Some a \<Rightarrow>
     case js_eval f of None \<Rightarrow> None | Some b \<Rightarrow> js_checked (js_apply op a b))"

inductive js_semantics :: "js_expr \<Rightarrow> js_value \<Rightarrow> bool" where
  lit: "js_safe v \<Longrightarrow> js_semantics (JLit v) v"
| typeof: "js_semantics e v \<Longrightarrow> js_semantics (JTypeof e) (JStr (js_type v))"
| bin: "js_semantics e a \<Longrightarrow> js_semantics f b \<Longrightarrow> js_apply op a b = Some v \<Longrightarrow> js_safe v \<Longrightarrow> js_semantics (JBin op e f) v"

lemma js_checked_value:
  "js_checked r = Some v \<Longrightarrow> r = Some v \<and> js_safe v"
  by (auto simp: js_checked_def split: option.splits if_splits)

theorem js_eval_sound:
  "js_eval e = Some v \<Longrightarrow> js_semantics e v"
  by (induction e arbitrary: v) (auto dest: js_checked_value intro: js_semantics.intros split: option.splits)

theorem js_semantics_safe:
  "js_semantics e v \<Longrightarrow> js_safe v"
  by (induction rule: js_semantics.induct) auto

theorem js_eval_safe_integer:
  "js_eval e = Some (JNum n) \<Longrightarrow> \<bar>n\<bar> \<le> 9007199254740991"
proof -
  assume evaluation: "js_eval e = Some (JNum n)"
  have semantic: "js_semantics e (JNum n)" using evaluation by (rule js_eval_sound)
  have "js_safe (JNum n)" using semantic by (rule js_semantics_safe)
  then show "\<bar>n\<bar> \<le> 9007199254740991" by (simp add: js_limit_def)
qed

text \<open>Two observable operator laws distinguish numeric addition from
string concatenation. They are model laws, not a claim about arbitrary source
programs or the binary64 implementation.\<close>
theorem js_numeric_add:
  assumes "\<bar>a\<bar> \<le> js_limit" "\<bar>b\<bar> \<le> js_limit" "\<bar>a+b\<bar> \<le> js_limit"
  shows "js_eval (JBin JAdd (JLit (JNum a)) (JLit (JNum b))) = Some (JNum (a+b))"
  using assms by (simp add: js_checked_def js_numeric_apply_def)

theorem js_string_add:
  assumes "js_safe v"
  shows "js_eval (JBin JAdd (JLit (JStr s)) (JLit v)) = Some (JStr (s + js_text v))"
  using assms by (simp add: js_checked_def)

theorem js_strict_type_sensitive:
  "js_type a \<noteq> js_type b \<Longrightarrow> \<not> js_strict a b"
  by (cases a; cases b) auto

end
