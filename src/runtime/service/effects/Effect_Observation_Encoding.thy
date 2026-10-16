theory Effect_Observation_Encoding
  imports Main
begin

text \<open>A closed representation checker for the fixed local-counter response.
The AST is an untrusted proposal. Its encoder must reproduce the retained bytes;
no parsing implementation or external response semantics is assumed.\<close>
datatype effect_json = EJNull | EJBool bool | EJInt int | EJString "nat list"
  | EJArray "effect_json list" | EJObject "(nat list \<times> effect_json) list"

fun effect_json_join :: "nat list \<Rightarrow> nat list list \<Rightarrow> nat list" where
  "effect_json_join sep []=[]" |
  "effect_json_join sep [x]=x" |
  "effect_json_join sep (x#y#xs)=x@sep@effect_json_join sep (y#xs)"
fun effect_json_digits_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "effect_json_digits_aux 0 n=[]" |
  "effect_json_digits_aux (Suc fuel) n=(if n<10 then [48+n]
    else effect_json_digits_aux fuel (n div 10)@[48+n mod 10])"
declare [[code drop: effect_json_digits_aux]]
lemma effect_json_digits_aux_code [code]:
  "effect_json_digits_aux fuel n=(if fuel=0 then [] else if n<10 then [48+n]
    else effect_json_digits_aux (fuel-1) (n div 10)@[48+n mod 10])"
  by (cases fuel) simp_all
definition effect_json_digits :: "nat \<Rightarrow> nat list" where
  "effect_json_digits n=effect_json_digits_aux (Suc n) n"
definition effect_json_hex :: "nat \<Rightarrow> nat" where
  "effect_json_hex n=(if n<10 then 48+n else 87+n)"
definition effect_json_utf8 :: "nat \<Rightarrow> nat list" where
  "effect_json_utf8 n=(if n<128 then [n] else if n<2048 then
    [192+n div 64,128+n mod 64] else if n<65536 then
    [224+n div 4096,128+(n div 64) mod 64,128+n mod 64] else
    [240+n div 262144,128+(n div 4096) mod 64,128+(n div 64) mod 64,128+n mod 64])"
definition effect_json_escape :: "nat \<Rightarrow> nat list" where
  "effect_json_escape n=(if n=34 then [92,34] else if n=92 then [92,92]
    else if n=8 then [92,98] else if n=12 then [92,102] else if n=10 then [92,110]
    else if n=13 then [92,114] else if n=9 then [92,116]
    else if n<32 \<or> (127\<le>n \<and> n\<le>159) then
      [92,117,48,48,effect_json_hex (n div 16),effect_json_hex (n mod 16)]
    else effect_json_utf8 n)"
definition effect_json_string :: "nat list \<Rightarrow> nat list" where
  "effect_json_string xs=[34]@concat(map effect_json_escape xs)@[34]"
fun effect_json_bytes :: "effect_json \<Rightarrow> nat list" where
  "effect_json_bytes EJNull=[110,117,108,108]" |
  "effect_json_bytes (EJBool b)=(if b then [116,114,117,101] else [102,97,108,115,101])" |
  "effect_json_bytes (EJInt n)=(if n<0 then [45]@effect_json_digits(nat(-n)) else effect_json_digits(nat n))" |
  "effect_json_bytes (EJString xs)=effect_json_string xs" |
  "effect_json_bytes (EJArray xs)=[91]@effect_json_join [44](map effect_json_bytes xs)@[93]" |
  "effect_json_bytes (EJObject xs)=[123]@effect_json_join [44]
    (map (\<lambda>(key,value). effect_json_string key@[58]@effect_json_bytes value) xs)@[125]"

definition effect_json_scalar :: "nat \<Rightarrow> bool" where
  "effect_json_scalar n \<longleftrightarrow> n\<le>1114111 \<and> \<not>(55296\<le>n \<and> n\<le>57343)"
definition effect_json_key :: "nat list \<Rightarrow> bool" where
  "effect_json_key key \<longleftrightarrow> length key\<le>16384 \<and> list_all (\<lambda>n. 32\<le>n \<and> n\<le>126) key"
fun effect_json_key_less :: "nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "effect_json_key_less [] []=False" |
  "effect_json_key_less [] (y#ys)=True" |
  "effect_json_key_less (x#xs) []=False" |
  "effect_json_key_less (x#xs) (y#ys)=(x<y \<or> (x=y \<and> effect_json_key_less xs ys))"
fun effect_json_keys_sorted :: "nat list list \<Rightarrow> bool" where
  "effect_json_keys_sorted []=True" | "effect_json_keys_sorted [x]=True" |
  "effect_json_keys_sorted (x#y#xs)=(effect_json_key_less x y \<and> effect_json_keys_sorted (y#xs))"
fun effect_json_valid :: "bool \<Rightarrow> effect_json \<Rightarrow> bool" where
  "effect_json_valid canonical EJNull=True" |
  "effect_json_valid canonical (EJBool b)=True" |
  "effect_json_valid canonical (EJInt n)=(-2147483648\<le>n \<and> n\<le>2147483647)" |
  "effect_json_valid canonical (EJString xs)=(length xs\<le>24576 \<and> list_all effect_json_scalar xs)" |
  "effect_json_valid canonical (EJArray xs)=list_all (effect_json_valid canonical) xs" |
  "effect_json_valid canonical (EJObject xs)=(distinct(map fst xs) \<and>
    (\<not>canonical \<or> effect_json_keys_sorted(map fst xs)) \<and>
    list_all (\<lambda>(key,value). effect_json_key key \<and> effect_json_valid canonical value) xs)"
fun effect_json_nodes :: "effect_json \<Rightarrow> nat" where
  "effect_json_nodes EJNull=1" | "effect_json_nodes (EJBool b)=1" |
  "effect_json_nodes (EJInt n)=1" | "effect_json_nodes (EJString xs)=1" |
  "effect_json_nodes (EJArray xs)=Suc(sum_list(map effect_json_nodes xs))" |
  "effect_json_nodes (EJObject xs)=Suc(length xs+sum_list(map (effect_json_nodes \<circ> snd) xs))"
fun effect_json_depth :: "effect_json \<Rightarrow> nat" where
  "effect_json_depth EJNull=0" | "effect_json_depth (EJBool b)=0" |
  "effect_json_depth (EJInt n)=0" | "effect_json_depth (EJString xs)=0" |
  "effect_json_depth (EJArray xs)=(if xs=[] then 0 else Suc(Max(insert 0 (set(map effect_json_depth xs)))))" |
  "effect_json_depth (EJObject xs)=(if xs=[] then 0 else Suc(Max(insert 0 (set(map (effect_json_depth \<circ> snd) xs)))))"

definition effect_json_encoding_exact :: "bool \<Rightarrow> effect_json \<Rightarrow> nat list \<Rightarrow> bool" where
  "effect_json_encoding_exact canonical tree bytes \<longleftrightarrow>
    effect_json_valid canonical tree \<and> effect_json_depth tree\<le>24 \<and>
    effect_json_nodes tree\<le>4096 \<and> effect_json_bytes tree=bytes"
lemma effect_json_encoding_exact_bytes:
  "effect_json_encoding_exact canonical tree bytes \<Longrightarrow> effect_json_bytes tree=bytes"
  by (simp add: effect_json_encoding_exact_def)
lemma effect_json_encoding_exact_valid:
  "effect_json_encoding_exact canonical tree bytes \<Longrightarrow> effect_json_valid canonical tree"
  by (simp add: effect_json_encoding_exact_def)

fun effect_json_insert :: "nat list \<times> effect_json \<Rightarrow> (nat list \<times> effect_json) list \<Rightarrow> (nat list \<times> effect_json) list" where
  "effect_json_insert entry []=[entry]" |
  "effect_json_insert entry (x#xs)=(if effect_json_key_less (fst entry) (fst x)
    then entry#x#xs else x#effect_json_insert entry xs)"
fun effect_json_order :: "(nat list \<times> effect_json) list \<Rightarrow> (nat list \<times> effect_json) list" where
  "effect_json_order []=[]" |
  "effect_json_order (x#xs)=effect_json_insert x (effect_json_order xs)"
fun effect_json_normalize :: "effect_json \<Rightarrow> effect_json" where
  "effect_json_normalize EJNull=EJNull" |
  "effect_json_normalize (EJBool b)=EJBool b" |
  "effect_json_normalize (EJInt n)=EJInt n" |
  "effect_json_normalize (EJString xs)=EJString xs" |
  "effect_json_normalize (EJArray xs)=EJArray(map effect_json_normalize xs)" |
  "effect_json_normalize (EJObject xs)=EJObject(effect_json_order
    (map (\<lambda>(key,value). (key,effect_json_normalize value)) xs))"
fun effect_json_small_strings :: "effect_json \<Rightarrow> bool" where
  "effect_json_small_strings EJNull=True" |
  "effect_json_small_strings (EJBool b)=True" |
  "effect_json_small_strings (EJInt n)=True" |
  "effect_json_small_strings (EJString xs)=(length xs\<le>16384)" |
  "effect_json_small_strings (EJArray xs)=list_all effect_json_small_strings xs" |
  "effect_json_small_strings (EJObject xs)=list_all
    (\<lambda>(key,value). length key\<le>16384 \<and> effect_json_small_strings value) xs"
definition effect_observation_receipt_key :: "nat list" where
  "effect_observation_receipt_key=[114,101,99,101,105,112,116,66,121,116,101,115]"
definition effect_observation_response_key :: "nat list" where
  "effect_observation_response_key=[114,101,115,112,111,110,115,101]"
definition effect_observation_encoding_check ::
  "effect_json \<Rightarrow> effect_json \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> bool" where
  "effect_observation_encoding_check record receipt record_bytes receipt_bytes \<longleftrightarrow>
    length record_bytes\<le>65536 \<and> length receipt_bytes\<le>16384 \<and>
    effect_json_encoding_exact True record record_bytes \<and>
    effect_json_encoding_exact False receipt receipt_bytes \<and>
    effect_json_nodes record+effect_json_nodes receipt\<le>4096 \<and>
    effect_json_small_strings receipt \<and>
    (case record of EJObject fields \<Rightarrow>
      list_all (\<lambda>(key,value). if key=effect_observation_receipt_key then
        (case value of EJString xs \<Rightarrow> length xs\<le>24576 | _\<Rightarrow>False)
        else effect_json_small_strings value) fields \<and>
      map_of fields effect_observation_response_key=Some(effect_json_normalize receipt)
    | _\<Rightarrow>False)"
lemma effect_observation_encoding_check_bytes:
  assumes "effect_observation_encoding_check record receipt record_bytes receipt_bytes"
  shows "effect_json_bytes record=record_bytes \<and> effect_json_bytes receipt=receipt_bytes"
  using assms by (simp add: effect_observation_encoding_check_def effect_json_encoding_exact_def)
lemma effect_json_reject_surrogate:
  "\<not>effect_json_valid True (EJString [55296])"
  by (simp add: effect_json_scalar_def)
lemma effect_json_reject_large_integer:
  "\<not>effect_json_valid False (EJInt 2147483648)"
  by simp
lemma effect_json_quote_escape:
  "effect_json_bytes (EJString [34,92,10])=[34,92,34,92,92,92,110,34]"
  by (simp add: effect_json_string_def effect_json_escape_def)

end
