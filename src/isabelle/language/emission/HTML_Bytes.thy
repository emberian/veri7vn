theory HTML_Bytes
  imports Veri7vn_Codegen.Veri7vn_Codegen
begin

definition escape_atom :: "nat \<Rightarrow> nat list" where
  "escape_atom b = (if b=38 then [38,97,109,112,59]
    else if b=60 then [38,108,116,59]
    else if b=62 then [38,103,116,59]
    else if b=34 then [38,113,117,111,116,59]
    else if b=39 then [38,35,51,57,59] else [b])"
definition html_escape where
  "html_escape bs = concat (map escape_atom bs)"
definition html_atom where
  "html_atom bs = (case bs of [] \<Rightarrow> None | b#rest \<Rightarrow>
    if b\<noteq>38 then Some (b,rest)
    else if take 4 rest=[97,109,112,59] then Some (38,drop 4 rest)
    else if take 3 rest=[108,116,59] then Some (60,drop 3 rest)
    else if take 3 rest=[103,116,59] then Some (62,drop 3 rest)
    else if take 5 rest=[113,117,111,116,59] then Some (34,drop 5 rest)
    else if take 4 rest=[35,51,57,59] then Some (39,drop 4 rest)
    else None)"
lemma html_atom_inverse:
  "html_atom (escape_atom b @ tail) = Some (b,tail)"
  by (auto simp: html_atom_def escape_atom_def split: if_splits)
fun html_decode :: "nat \<Rightarrow> nat list \<Rightarrow> nat list option" where
  "html_decode 0 bs = (if bs=[] then Some [] else None)" |
  "html_decode (Suc fuel) bs = (if bs=[] then Some [] else
    (case html_atom bs of None \<Rightarrow> None |
      Some (b,rest) \<Rightarrow> map_option ((#) b) (html_decode fuel rest)))"
lemma escaped_nonempty: "escape_atom b \<noteq> []"
  by (simp add: escape_atom_def)
lemma decode_escaped:
  "length bs \<le> fuel \<Longrightarrow> html_decode fuel (html_escape bs) = Some bs"
proof (induction bs arbitrary: fuel)
  case Nil then show ?case by (cases fuel) (simp_all add: html_escape_def)
next
  case (Cons b bs)
  then obtain f where F: "fuel=Suc f" by (cases fuel) auto
  have tail: "html_decode f (html_escape bs)=Some bs"
    using Cons.IH Cons.prems F by simp
  show ?case using F tail escaped_nonempty[of b]
    by (simp add: html_escape_def html_atom_inverse)
qed
lemma escape_length: "length bs \<le> length (html_escape bs)"
  by (induction bs) (auto simp: html_escape_def escape_atom_def)
theorem html_escape_roundtrip:
  "html_decode (length (html_escape bs)) (html_escape bs) = Some bs"
  by (rule decode_escaped[OF escape_length])
lemma html_escape_injective:
  "html_escape xs=html_escape ys \<Longrightarrow> xs=ys"
  by (metis html_escape_roundtrip option.inject)

definition bounded_escape where
  "bounded_escape max_input max_output bs =
    (if length bs\<le>max_input then
      (let escaped=html_escape bs in
       if length escaped\<le>max_output then Some escaped else None)
     else None)"
theorem bounded_escape_sound:
  "bounded_escape ni no bs=Some out \<Longrightarrow>
    length bs\<le>ni \<and> length out\<le>no \<and>
    html_decode (length out) out=Some bs"
  by (auto simp: bounded_escape_def Let_def html_escape_roundtrip split: if_splits)

end
