theory Source_Provenance
  imports Source_Semantics
begin

text \<open>Source qualifiers are part of the native adopted payload, not a display
projection. Unknown rank/units remain unknown. Import loss is explicit.\<close>
datatype source_rank = Ordinal_Rank int | Named_Rank string

record 'a source_assertion =
  reported_value :: 'a
  reported_rank :: "source_rank option"
  reported_units :: "string option"
  reported_references :: "string list"
  reported_import_loss :: "string list"
  reported_applicability :: "string list"

definition qualified_source_meaning where
  "qualified_source_meaning meaning scope qs assertion =
    meaning scope qs (reported_rank assertion) (reported_units assertion)
      (reported_references assertion) (reported_import_loss assertion)
      (reported_applicability assertion) (reported_value assertion)"
lemma qualified_adoption_preserves_fields:
  "adopted_premise (qualified_source_meaning meaning) a \<Longrightarrow>
   payload (adopted_report a) = Valid assertion \<Longrightarrow>
   meaning (adoption_scope a) (qualifiers (adopted_report a))
     (reported_rank assertion) (reported_units assertion)
     (reported_references assertion) (reported_import_loss assertion)
     (reported_applicability assertion) (reported_value assertion)"
  by (simp add: adopted_premise_def qualified_source_meaning_def)

text \<open>This operation changes only the reported value. The importer must
establish its own decoder association before using it.\<close>
definition replace_reported_value :: "'b \<Rightarrow> 'a source_assertion \<Rightarrow> 'b source_assertion" where
  "replace_reported_value value assertion = \<lparr>reported_value = value,
    reported_rank = reported_rank assertion, reported_units = reported_units assertion,
    reported_references = reported_references assertion,
    reported_import_loss = reported_import_loss assertion,
    reported_applicability = reported_applicability assertion\<rparr>"
lemma replacement_retains_qualifiers:
  "reported_rank (replace_reported_value x a) = reported_rank a \<and>
   reported_units (replace_reported_value x a) = reported_units a \<and>
   reported_references (replace_reported_value x a) = reported_references a \<and>
   reported_import_loss (replace_reported_value x a) = reported_import_loss a \<and>
   reported_applicability (replace_reported_value x a) = reported_applicability a"
  by (simp add: replace_reported_value_def)

text \<open>Concrete source adoption also retains the entire observation, including
unknown origin, schema/configuration, clocks and raw reference, in its meaning.\<close>
definition qualified_observation_premise where
  "qualified_observation_premise meaning a =
    (case payload (adopted_report a) of Valid assertion \<Rightarrow>
      qualified_source_meaning (meaning (adopted_report a)) (adoption_scope a)
        (qualifiers (adopted_report a)) assertion | _ \<Rightarrow> False)"
lemma qualified_observation_adoption_fields:
  "qualified_observation_premise meaning a \<Longrightarrow>
   payload (adopted_report a) = Valid assertion \<Longrightarrow>
   meaning (adopted_report a) (adoption_scope a) (qualifiers (adopted_report a))
     (reported_rank assertion) (reported_units assertion)
     (reported_references assertion) (reported_import_loss assertion)
     (reported_applicability assertion) (reported_value assertion)"
  by (simp add: qualified_observation_premise_def qualified_source_meaning_def)
lemma unknown_origin_cannot_be_known:
  "origin (adopted_report a) = Unknown_Origin \<Longrightarrow>
   origin (adopted_report a) \<noteq> Measured \<and> origin (adopted_report a) \<noteq> Simulated"
  by simp

lemma unknown_qualified_adoption_fields:
  "qualified_observation_premise meaning a \<Longrightarrow>
   payload (adopted_report a) = Valid assertion \<Longrightarrow>
   origin (adopted_report a) = Unknown_Origin \<Longrightarrow>
   origin (adopted_report a) = Unknown_Origin \<and>
   meaning (adopted_report a) (adoption_scope a) (qualifiers (adopted_report a))
     (reported_rank assertion) (reported_units assertion)
     (reported_references assertion) (reported_import_loss assertion)
     (reported_applicability assertion) (reported_value assertion)"
  by (simp add: qualified_observation_premise_def qualified_source_meaning_def)

end
