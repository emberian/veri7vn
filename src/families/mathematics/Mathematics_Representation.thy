theory Mathematics_Representation
  imports Mathematics_Exact
begin

text \<open>Exact rational interchange pairs use positive denominators. Normalized
encoding retains the entire fraction; decoding never passes through a float.\<close>
definition rational_pair_rep :: "(int \<times> int) \<Rightarrow> rat \<Rightarrow> bool" where
  "rational_pair_rep pair q \<longleftrightarrow> 0 < snd pair \<and> q=Fract (fst pair) (snd pair)"

definition encode_rational_pair :: "rat \<Rightarrow> int \<times> int" where
  "encode_rational_pair q = quotient_of q"

definition decode_rational_pair :: "(int \<times> int) \<Rightarrow> rat option" where
  "decode_rational_pair pair = (if 0 < snd pair then Some (Fract (fst pair) (snd pair)) else None)"

theorem rational_pair_roundtrip:
  "decode_rational_pair (encode_rational_pair q) = Some q"
  by (simp add: decode_rational_pair_def encode_rational_pair_def quotient_of_denom_pos')

theorem rational_pair_decode_refinement:
  "decode_rational_pair pair = Some q \<longleftrightarrow> rational_pair_rep pair q"
  by (auto simp: decode_rational_pair_def rational_pair_rep_def split: if_splits)

fun decode_rational_list :: "(int \<times> int) list \<Rightarrow> rat list option" where
  "decode_rational_list [] = Some []"
| "decode_rational_list (pair#pairs) = (case decode_rational_pair pair of None \<Rightarrow> None | Some q \<Rightarrow> map_option ((#) q) (decode_rational_list pairs))"

definition decode_rational_batch where
  "decode_rational_batch max_elements pairs = (if length pairs > max_elements then None else decode_rational_list pairs)"

lemma rational_list_roundtrip:
  "decode_rational_list (map encode_rational_pair coeffs) = Some coeffs"
  by (induction coeffs) (simp_all add: rational_pair_roundtrip)

lemma rational_batch_roundtrip:
  "length coeffs \<le> max_elements \<Longrightarrow>
   decode_rational_batch max_elements (map encode_rational_pair coeffs) = Some coeffs"
  by (simp add: decode_rational_batch_def rational_list_roundtrip)

export_code encode_rational_pair decode_rational_pair decode_rational_batch
  in SML module_name Mathematics_Representation
end
