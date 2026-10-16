theory Checked_Statements
  imports Controlled_Templates Veri7vn_Natural_Mathematics.Natural_Mathematics
    Veri7vn_HTML_Bytes.HTML_Bytes
begin

primrec template_view where
  "template_view (ExactSum a b c)=(0::nat,[a,b,c])" |
  "template_view (ExactDifference a b c)=(1,[a,b,c])" |
  "template_view (ExactProduct a b c)=(2,[a,b,c])" |
  "template_view (ExactQuotient a b p q)=(3,[a,b,p,q])"
lemma template_view_injective: "template_view a=template_view b \<Longrightarrow> a=b"
  by (cases a; cases b) auto

definition remove_period where
  "remove_period bs = (if bs\<noteq>[] \<and> last bs=46 then Some (butlast bs) else None)"
definition quotient_literal where
  "quotient_literal bs = (let left=takeWhile (\<lambda>b. b\<noteq>47) bs;
     tail=drop (length left) bs in
    if tail=[] then None else
      (case (read_integer left,read_integer (tl tail)) of
        (Some p,Some q) \<Rightarrow> if hd tail=47 \<and> q>0 then Some (p,q) else None
      | _ \<Rightarrow> None))"
definition decode_statement where
  "decode_statement bs = (if length bs>16384 then None else
    (case ascii_words bs of [w1,w2,operator_word,w4,a,w6,b,w8,lastword] \<Rightarrow>
      if w1=[84,104,101] \<and> w2=[101,120,97,99,116] \<and>
        w4=[111,102] \<and> w6=[97,110,100] \<and> w8=[105,115]
      then (case (read_integer a,read_integer b,remove_period lastword) of
        (Some x,Some y,Some result) \<Rightarrow>
          if operator_word=[113,117,111,116,105,101,110,116] then
            (case quotient_literal result of Some (p,q) \<Rightarrow>
              if y\<noteq>0 then Some (ExactQuotient x y p q) else None | None \<Rightarrow> None)
          else (case read_integer result of None \<Rightarrow> None | Some z \<Rightarrow>
            if operator_word=[115,117,109] then Some (ExactSum x y z)
            else if operator_word=[100,105,102,102,101,114,101,110,99,101] then Some (ExactDifference x y z)
            else if operator_word=[112,114,111,100,117,99,116] then Some (ExactProduct x y z)
            else None)
        | _ \<Rightarrow> None)
      else None
    | _ \<Rightarrow> None))"
definition statement_meaning where
  "statement_meaning bs = (case decode_statement bs of None \<Rightarrow> False |
    Some t \<Rightarrow> template_meaning t)"

definition checked_statement where
  "checked_statement expected bs = (if length bs\<le>16384 \<and> list_all (\<lambda>b. b<256) bs then
    (case decode_statement bs of None \<Rightarrow> None | Some t \<Rightarrow>
      if template_view t=expected then
        (case bounded_escape 16384 65529 bs of None \<Rightarrow> None |
          Some escaped \<Rightarrow> Some ([60,112,62] @ escaped @ [60,47,112,62]))
      else None)
    else None)"
theorem checked_statement_exact:
  assumes "checked_statement (template_view t) bs=Some out"
  shows "decode_statement bs=Some t" "length out\<le>65536"
    "out=[60,112,62] @ html_escape bs @ [60,47,112,62]"
  using assms template_view_injective
  by (auto simp: checked_statement_def bounded_escape_def Let_def
    split: if_splits option.splits)
theorem checked_statement_native_meaning:
  assumes emitted: "checked_statement (template_view t) bs=Some out"
    and native: "template_meaning t"
  shows "statement_meaning bs \<and>
    math_value env (template_expression t) (template_result t) \<and>
    html_decode (length (html_escape bs)) (html_escape bs)=Some bs"
  using checked_statement_exact(1)[OF emitted] template_native_family_law[OF native]
  by (simp add: statement_meaning_def html_escape_roundtrip native)
end
