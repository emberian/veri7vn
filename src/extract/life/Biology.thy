theory Biology
  imports Life_Core
begin

text \<open>
  Lane S09-life, biology (upstream/root/specialists/biology/organ_biology_v1.py):
  sequence operations over the standard genetic code (NCBI table 1). The
  sequences are typed lists of nucleotides; the tables (@{text aas},
  @{text aa_names}) are transcribed from the organ and checked by
  tables_check.py.
\<close>

fun comp :: "nuc \<Rightarrow> nuc" where
  "comp NA = NT" | "comp NT = NA" | "comp NC = NG" | "comp NG = NC" | "comp NU = NA"

fun to_dna :: "nuc \<Rightarrow> nuc" where
  "to_dna NU = NT" | "to_dna b = b"

fun to_rna :: "nuc \<Rightarrow> nuc" where
  "to_rna NT = NU" | "to_rna b = b"

fun tcag :: "nuc \<Rightarrow> nat" where
  "tcag NT = 0" | "tcag NU = 0" | "tcag NC = 1" | "tcag NA = 2" | "tcag NG = 3"

definition aas :: "char list" where
  "aas = ''FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG''"

definition codon_aa :: "nuc \<Rightarrow> nuc \<Rightarrow> nuc \<Rightarrow> char" where
  "codon_aa a b c = aas ! (16 * tcag a + 4 * tcag b + tcag c)"

fun codons :: "nuc list \<Rightarrow> char list" where
  "codons [] = []"
| "codons [a] = []"
| "codons [a, b] = []"
| "codons (a # b # c # r) = codon_aa a b c # codons r"

definition stop_aa :: char where "stop_aa = CHR ''*''"

definition prot_of :: "nuc list \<Rightarrow> char list" where
  "prot_of xs = takeWhile (\<lambda>c. c \<noteq> stop_aa) (codons xs)"

definition aa_names :: "(char \<times> String.literal) list" where
  "aa_names = [(CHR ''F'', STR ''phenylalanine''), (CHR ''L'', STR ''leucine''), (CHR ''S'', STR ''serine''),
     (CHR ''Y'', STR ''tyrosine''), (CHR ''*'', STR ''stop''), (CHR ''C'', STR ''cysteine''),
     (CHR ''W'', STR ''tryptophan''), (CHR ''P'', STR ''proline''), (CHR ''H'', STR ''histidine''),
     (CHR ''Q'', STR ''glutamine''), (CHR ''R'', STR ''arginine''), (CHR ''I'', STR ''isoleucine''),
     (CHR ''M'', STR ''methionine''), (CHR ''T'', STR ''threonine''), (CHR ''N'', STR ''asparagine''),
     (CHR ''K'', STR ''lysine''), (CHR ''V'', STR ''valine''), (CHR ''A'', STR ''alanine''),
     (CHR ''D'', STR ''aspartic acid''), (CHR ''E'', STR ''glutamic acid''), (CHR ''G'', STR ''glycine'')]"

definition aa_name :: "char \<Rightarrow> String.literal" where
  "aa_name c = (case map_of aa_names c of Some n \<Rightarrow> n | None \<Rightarrow> STR '''')"

definition gc_count :: "nuc list \<Rightarrow> nat" where
  "gc_count xs = length (filter (\<lambda>b. b = NG \<or> b = NC) xs)"

definition gc_val :: "nuc list \<Rightarrow> rat" where
  "gc_val xs = of_nat (gc_count xs) * 100 / of_nat (length xs)"

section \<open>Facts about the operations\<close>

lemma comp_comp_dna: "b \<noteq> NU \<Longrightarrow> comp (comp b) = b"
  by (cases b) simp_all

lemma complement_involutive:
  "NU \<notin> set xs \<Longrightarrow> map comp (map comp xs) = xs"
proof (induct xs)
  case Nil
  then show ?case by simp
next
  case (Cons x xs)
  then have "x \<noteq> NU" by auto
  then show ?case using Cons by (auto simp: comp_comp_dna)
qed

theorem revcomp_involutive:
  assumes "NU \<notin> set xs"
  shows "rev (map comp (rev (map comp xs))) = xs"
proof -
  have "rev (map comp (rev (map comp xs))) = map comp (map comp xs)" by (simp add: rev_map)
  also have "\<dots> = xs" by (rule complement_involutive[OF assms])
  finally show ?thesis .
qed

lemma to_dna_to_rna: "b \<noteq> NU \<Longrightarrow> to_dna (to_rna b) = b"
  by (cases b) simp_all

theorem transcription_inverse:
  assumes "NU \<notin> set xs"
  shows "map to_dna (map to_rna xs) = xs"
  using assms
proof (induct xs)
  case Nil
  then show ?case by simp
next
  case (Cons x xs)
  then have "x \<noteq> NU" by auto
  then show ?case using Cons by (auto simp: to_dna_to_rna)
qed

lemma codons_len: "length (codons xs) = length xs div 3"
  by (induct xs rule: codons.induct) simp_all

theorem protein_length_bound: "length (prot_of xs) \<le> length xs div 3"
proof -
  have "length (prot_of xs) \<le> length (codons xs)"
    by (simp add: prot_of_def length_takeWhile_le)
  then show ?thesis using codons_len by simp
qed

theorem protein_has_no_stop: "stop_aa \<notin> set (prot_of xs)"
  by (auto simp: prot_of_def dest: set_takeWhileD)

theorem gc_count_le: "gc_count xs \<le> length xs"
  by (simp add: gc_count_def length_filter_le)

theorem gc_val_bounds:
  assumes "xs \<noteq> []"
  shows "0 \<le> gc_val xs \<and> gc_val xs \<le> 100"
proof -
  have n: "(0::rat) < of_nat (length xs)" using assms by simp
  have le: "(of_nat (gc_count xs) :: rat) \<le> of_nat (length xs)" by (simp add: gc_count_le)
  have h: "(of_nat (gc_count xs) :: rat) * 100 \<le> 100 * of_nat (length xs)" using le by linarith
  have lo: "0 \<le> (of_nat (gc_count xs) :: rat) * 100 / of_nat (length xs)"
    by (intro divide_nonneg_nonneg) simp_all
  have hi: "(of_nat (gc_count xs) :: rat) * 100 / of_nat (length xs) \<le> 100"
    by (subst pos_divide_le_eq[OF n]) (use h in linarith)
  show ?thesis using lo hi by (simp add: gc_val_def)
qed

theorem gc_val_defining:
  assumes "xs \<noteq> []"
  shows "gc_val xs * of_nat (length xs) = 100 * of_nat (gc_count xs)"
proof -
  have n0: "(of_nat (length xs) :: rat) \<noteq> 0" using assms by (cases xs) simp_all
  show ?thesis unfolding gc_val_def using n0 by (simp add: field_simps)
qed

section \<open>The kernel\<close>

datatype bop = Op_codon | Op_gc | Op_revcomp | Op_complement | Op_transcribe bool
  | Op_translate | Op_protlen

datatype breq = Bio bop "nuc list"

definition has_both :: "nuc list \<Rightarrow> bool" where
  "has_both xs \<longleftrightarrow> NT \<in> set xs \<and> NU \<in> set xs"

fun b_bad :: "bop \<Rightarrow> nuc list \<Rightarrow> reason option" where
  "b_bad bo xs = (if has_both xs then Some R_both else
     (case bo of
        Op_codon \<Rightarrow> if length xs = 3 then None else Some R_frame
      | Op_transcribe t \<Rightarrow> if NU \<in> set xs then Some R_rna else None
      | Op_translate \<Rightarrow> if length xs mod 3 = 0 then None else Some R_frame
      | Op_protlen \<Rightarrow> if length xs mod 3 = 0 then None else Some R_frame
      | _ \<Rightarrow> None))"

definition b_decline :: "breq \<Rightarrow> decline option" where
  "b_decline r = (case r of Bio bo xs \<Rightarrow> (case b_bad bo xs of None \<Rightarrow> None | Some w \<Rightarrow> Some (Impossible w)))"

fun b_answer :: "breq \<Rightarrow> outcome" where
  "b_answer (Bio Op_codon [a, b, c]) = Amino (STR ''codon'') (codon_aa a b c)"
| "b_answer (Bio Op_codon xs) = Decline Imprecise"
| "b_answer (Bio Op_gc xs) = Exact (STR ''gc'') (gc_val xs)"
| "b_answer (Bio Op_revcomp xs) = Bases (STR ''revcomp'') (rev (map comp (map to_dna xs)))"
| "b_answer (Bio Op_complement xs) = Bases (STR ''complement'') (map comp (map to_dna xs))"
| "b_answer (Bio (Op_transcribe False) xs) = Bases (STR ''transcribe'') (map to_rna xs)"
| "b_answer (Bio (Op_transcribe True) xs) = Bases (STR ''transcribe'') (map to_rna (rev (map comp xs)))"
| "b_answer (Bio Op_translate xs) = Prot (STR ''translate'') (prot_of xs)"
| "b_answer (Bio Op_protlen xs) = Exact (STR ''protein_len'') (of_nat (length (prot_of xs)))"

definition b_kernel :: "breq \<Rightarrow> outcome" where
  "b_kernel r = (case b_decline r of Some w \<Rightarrow> Decline w | None \<Rightarrow> b_answer r)"

lemma b_kernel_bio:
  "b_kernel (Bio bo xs) = (case b_bad bo xs of Some w \<Rightarrow> Decline (Impossible w) | None \<Rightarrow> b_answer (Bio bo xs))"
  by (cases "b_bad bo xs") (simp_all add: b_kernel_def b_decline_def)

theorem bio_mixed_declines:
  "has_both xs \<Longrightarrow> b_kernel (Bio bo xs) = Decline (Impossible R_both)"
  by (simp add: b_kernel_bio)

theorem bio_codon:
  assumes "\<not> has_both [a, b, c]"
  shows "b_kernel (Bio Op_codon [a, b, c]) = Amino (STR ''codon'') (codon_aa a b c)"
  using assms by (simp add: b_kernel_bio)

theorem bio_complement:
  assumes "b_kernel (Bio Op_complement xs) = Bases k ys"
  shows "\<not> has_both xs \<and> ys = map comp (map to_dna xs) \<and> length ys = length xs"
  using assms by (cases "b_bad Op_complement xs") (auto simp: b_kernel_bio split: if_splits option.splits)

theorem bio_revcomp:
  assumes "b_kernel (Bio Op_revcomp xs) = Bases k ys"
  shows "\<not> has_both xs \<and> ys = rev (map comp (map to_dna xs)) \<and> length ys = length xs"
  using assms by (cases "b_bad Op_revcomp xs") (auto simp: b_kernel_bio split: if_splits option.splits)

theorem bio_transcribe:
  assumes "b_kernel (Bio (Op_transcribe False) xs) = Bases k ys"
  shows "NU \<notin> set xs \<and> ys = map to_rna xs \<and> map to_dna ys = xs"
proof -
  have nu: "NU \<notin> set xs"
    using assms by (cases "has_both xs") (auto simp: b_kernel_bio split: if_splits option.splits)
  have "ys = map to_rna xs"
    using assms nu by (auto simp: b_kernel_bio has_both_def split: if_splits option.splits)
  then show ?thesis using nu transcription_inverse[OF nu] by simp
qed

theorem bio_translate:
  assumes "b_kernel (Bio Op_translate xs) = Prot k p"
  shows "length xs mod 3 = 0 \<and> p = prot_of xs \<and> stop_aa \<notin> set p \<and> length p \<le> length xs div 3"
proof -
  have ok: "length xs mod 3 = 0"
    using assms by (cases "has_both xs") (auto simp: b_kernel_bio split: if_splits option.splits)
  have "p = prot_of xs"
    using assms ok by (auto simp: b_kernel_bio has_both_def split: if_splits option.splits)
  then show ?thesis using ok protein_has_no_stop protein_length_bound by simp
qed

theorem bio_translate_frame:
  "\<not> has_both xs \<Longrightarrow> length xs mod 3 \<noteq> 0 \<Longrightarrow> b_kernel (Bio Op_translate xs) = Decline (Impossible R_frame)"
  by (simp add: b_kernel_bio)

theorem bio_gc:
  assumes "b_kernel (Bio Op_gc xs) = Exact k q" "xs \<noteq> []"
  shows "q = gc_val xs \<and> 0 \<le> q \<and> q \<le> 100 \<and> q * of_nat (length xs) = 100 * of_nat (gc_count xs)"
proof -
  have "q = gc_val xs"
    using assms(1) by (cases "b_bad Op_gc xs") (auto simp: b_kernel_bio split: if_splits option.splits)
  then show ?thesis using gc_val_bounds[OF assms(2)] gc_val_defining[OF assms(2)] by simp
qed

section \<open>Response text\<close>

definition frame_note :: "nuc list \<Rightarrow> String.literal" where
  "frame_note xs = (if length (prot_of xs) * 3 < length xs
     then STR ''translation stops at the stop codon'' else STR ''no stop codon in the sequence'')"

fun b_text :: "breq \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "b_text (Bio Op_codon xs) (Amino _ c) = (if c = stop_aa
     then STR ''The codon '' + nucs_lit xs + STR '' encodes stop - it is a stop codon (no amino acid; translation ends; standard genetic code).''
     else STR ''The codon '' + nucs_lit xs + STR '' encodes '' + aa_name c + STR '' ('' + String.implode [c]
       + STR ''; standard genetic code).'')"
| "b_text (Bio Op_gc xs) (Exact _ q) = STR ''The GC content is '' + fixed_lit 2 q + STR ''% (''
     + show_int (int (gc_count xs)) + STR '' G + C of '' + show_int (int (length xs)) + STR '' bases).''"
| "b_text (Bio Op_revcomp xs) (Bases _ ys) = STR ''The reverse complement is '' + nucs_lit ys
     + STR '' (5'' + apos + STR ''->3'' + apos + STR '' of the opposite strand).''"
| "b_text (Bio Op_complement xs) (Bases _ ys) = STR ''The complementary strand is '' + nucs_lit ys
     + STR '' (A-T, C-G, written 3'' + apos + STR ''->5'' + apos + STR '' under the given strand).''"
| "b_text (Bio (Op_transcribe t) xs) (Bases _ ys) = STR ''The mRNA is '' + nucs_lit ys
     + (if t then STR '' (the template strand read 3'' + apos + STR ''->5'' + apos
          + STR '', complementary bases, U for T; written 5'' + apos + STR ''->3'' + apos + STR '').''
        else STR '' (same as the coding strand with U in place of T).'')"
| "b_text (Bio Op_translate xs) (Prot _ p) = STR ''The protein is ''
     + (if p = [] then STR ''(empty - it starts with a stop codon)'' else String.implode p)
     + STR '' (standard genetic code, reading frame from the first base; '' + frame_note xs + STR '').''"
| "b_text (Bio Op_protlen xs) (Exact _ q) = STR ''The protein is '' + show_int (int (length (prot_of xs)))
     + STR '' amino acids long ('' + show_int (int (length (prot_of xs))) + STR '' codons before ''
     + (if length (prot_of xs) * 3 < length xs then STR ''the stop codon'' else STR ''the end of the sequence'') + STR '').''"
| "b_text r o' = STR ''''"

text \<open>The machine-readable value of a codon is the amino-acid name, as the organ states it.\<close>
text \<open>Normalize a stated strand into the coding strand written 5-prime to
3-prime before transcription or translation. The Boolean directions mean
that the supplied sequence is template (rather than coding) and written
3-prime to 5-prime (rather than 5-prime to 3-prime). English interpretation
of those declarations remains outside this theorem.\<close>
definition bio_input :: "bool \<Rightarrow> bool \<Rightarrow> nuc list \<Rightarrow> nuc list" where
  "bio_input template backwards xs =
    (let forward = (if backwards then rev xs else xs)
     in if template then rev (map comp forward) else forward)"

theorem bio_input_template_backwards:
  "bio_input True True xs = map comp xs"
  by (simp add: bio_input_def rev_map)

theorem bio_input_coding_backwards:
  "bio_input False True xs = rev xs"
  by (simp add: bio_input_def)

theorem bio_input_preserves_length:
  "length (bio_input template backwards xs) = length xs"
  by (cases template; cases backwards) (simp_all add: bio_input_def)

theorem bio_input_orientation_invariance:
  "bio_input template (\<not> backwards) (rev xs) = bio_input template backwards xs"
  by (cases template; cases backwards) (simp_all add: bio_input_def)

definition bio_model_reply :: reply where
  "bio_model_reply = mk_reply
     (Decline (Underspecified (STR ''I need one unambiguous strand direction and role, and this translator supports the standard genetic code from the first base.'')))
     (STR ''I need one unambiguous strand direction and role, and this translator supports the standard genetic code from the first base.'')"

theorem bio_model_declines:
  "\<not> answered bio_model_reply"
  by (simp add: bio_model_reply_def mk_reply_def)

definition b_reply :: "breq \<Rightarrow> reply" where
  "b_reply r = (let rp = mk_reply (b_kernel r) (b_text r (b_kernel r)) in
     case b_kernel r of
       Amino _ c \<Rightarrow> Reply (answered rp) (reply_kind rp) (response rp)
          (Some (quote_lit + (if c = stop_aa then STR ''stop'' else aa_name c) + quote_lit))
     | _ \<Rightarrow> rp)"

end
