theory Source_Attributes
  imports Facts_Rows
begin

text \<open>Fields deliberately transcribed from specific source assertions.
The table associates each value with its source store, source row and requested
attribute. It does not assert that arbitrary English substrings entail a field.
The interpretation of each source statement remains an explicit data premise.\<close>

datatype source_attribute = ConceptMeaning | StudyDate | StudyPlace | StudyFinding | StudyTopic

definition source_attribute_fields :: "((String.literal \<times> nat \<times> source_attribute) \<times> String.literal) list" where
  "source_attribute_fields = [
    ((STR ''facts_sociology_v1'',1,ConceptMeaning), STR ''normlessness''),
    ((STR ''facts_psychology_v1'',5,StudyTopic), STR ''obedience to authority''),
    ((STR ''facts_psychology_v1'',13,StudyTopic), STR ''attachment''),
    ((STR ''facts_psychology_v1'',5,StudyDate), STR ''1960s''),
    ((STR ''facts_psychology_v1'',6,StudyDate), STR ''1971''),
    ((STR ''facts_psychology_v1'',7,StudyFinding), STR ''observational learning''),
    ((STR ''facts_psychology_v1'',11,StudyDate), STR ''1879''),
    ((STR ''facts_psychology_v1'',11,StudyPlace), STR ''Leipzig''),
    ((STR ''facts_psychology_v1'',13,StudyFinding), STR ''importance of contact comfort'')]"

definition source_attribute_lookup :: "String.literal \<Rightarrow> nat \<Rightarrow> source_attribute \<Rightarrow> String.literal option" where
  "source_attribute_lookup name row attribute = map_of source_attribute_fields (name,row,attribute)"

theorem source_attribute_lookup_sound:
  "source_attribute_lookup name row attribute = Some value \<Longrightarrow>
    ((name,row,attribute),value) \<in> set source_attribute_fields"
  unfolding source_attribute_lookup_def by (rule map_of_SomeD)

theorem source_attributes_unique:
  "distinct (map fst source_attribute_fields)"
  by code_simp

end
