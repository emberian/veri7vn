theory Language_Fields
  imports Facts_Rows
begin

text \<open>Typed language fields transcribed from the source LANGS list. This is
source data, not a proof of linguistic classification. Row zero (Basque) has no
source branch. Exact source-language identity remains an interpretation premise.\<close>

definition language_fields :: "(String.literal \<times> String.literal \<times> String.literal) list" where
  "language_fields = [
    (STR ''english'', STR ''Indo-European'', STR ''Germanic''),
    (STR ''german'', STR ''Indo-European'', STR ''Germanic''),
    (STR ''dutch'', STR ''Indo-European'', STR ''Germanic''),
    (STR ''swedish'', STR ''Indo-European'', STR ''Germanic''),
    (STR ''spanish'', STR ''Indo-European'', STR ''Romance (Italic)''),
    (STR ''french'', STR ''Indo-European'', STR ''Romance (Italic)''),
    (STR ''italian'', STR ''Indo-European'', STR ''Romance (Italic)''),
    (STR ''portuguese'', STR ''Indo-European'', STR ''Romance (Italic)''),
    (STR ''romanian'', STR ''Indo-European'', STR ''Romance (Italic)''),
    (STR ''russian'', STR ''Indo-European'', STR ''Slavic''),
    (STR ''polish'', STR ''Indo-European'', STR ''Slavic''),
    (STR ''hindi'', STR ''Indo-European'', STR ''Indo-Aryan''),
    (STR ''bengali'', STR ''Indo-European'', STR ''Indo-Aryan''),
    (STR ''persian'', STR ''Indo-European'', STR ''Iranian''),
    (STR ''farsi'', STR ''Indo-European'', STR ''Iranian''),
    (STR ''greek'', STR ''Indo-European'', STR ''Hellenic''),
    (STR ''irish'', STR ''Indo-European'', STR ''Celtic''),
    (STR ''welsh'', STR ''Indo-European'', STR ''Celtic''),
    (STR ''finnish'', STR ''Uralic'', STR ''Finnic''),
    (STR ''estonian'', STR ''Uralic'', STR ''Finnic''),
    (STR ''hungarian'', STR ''Uralic'', STR ''Ugric''),
    (STR ''turkish'', STR ''Turkic'', STR ''Oghuz''),
    (STR ''arabic'', STR ''Afro-Asiatic'', STR ''Semitic''),
    (STR ''hebrew'', STR ''Afro-Asiatic'', STR ''Semitic''),
    (STR ''amharic'', STR ''Afro-Asiatic'', STR ''Semitic''),
    (STR ''swahili'', STR ''Niger-Congo'', STR ''Bantu''),
    (STR ''zulu'', STR ''Niger-Congo'', STR ''Bantu''),
    (STR ''yoruba'', STR ''Niger-Congo'', STR ''Volta-Niger''),
    (STR ''mandarin'', STR ''Sino-Tibetan'', STR ''Sinitic''),
    (STR ''cantonese'', STR ''Sino-Tibetan'', STR ''Sinitic''),
    (STR ''tibetan'', STR ''Sino-Tibetan'', STR ''Tibetic''),
    (STR ''japanese'', STR ''Japonic'', STR ''Japanese''),
    (STR ''korean'', STR ''Koreanic'', STR ''Korean''),
    (STR ''tagalog'', STR ''Austronesian'', STR ''Malayo-Polynesian''),
    (STR ''indonesian'', STR ''Austronesian'', STR ''Malayo-Polynesian''),
    (STR ''malay'', STR ''Austronesian'', STR ''Malayo-Polynesian''),
    (STR ''hawaiian'', STR ''Austronesian'', STR ''Polynesian''),
    (STR ''vietnamese'', STR ''Austroasiatic'', STR ''Vietic''),
    (STR ''thai'', STR ''Kra-Dai'', STR ''Tai''),
    (STR ''tamil'', STR ''Dravidian'', STR ''South Dravidian''),
    (STR ''telugu'', STR ''Dravidian'', STR ''South-Central Dravidian''),
    (STR ''quechua'', STR ''Quechuan'', STR ''Quechua''),
    (STR ''navajo'', STR ''Na-Dene'', STR ''Athabaskan'')]"

definition language_field :: "nat \<Rightarrow> (String.literal \<times> String.literal \<times> String.literal) option" where
  "language_field i = (if 0<i \<and> i \<le> length language_fields then Some (language_fields ! (i-1)) else None)"

theorem language_field_bound:
  "language_field i = Some t \<Longrightarrow> 0<i \<and> i \<le> length language_fields \<and> t=language_fields ! (i-1)"
  by (auto simp: language_field_def split: if_splits)

text \<open>The supplied family field agrees with the actual checked row value;
this validates row indexing but does not prove the independent branch assertion.\<close>
theorem language_family_rows:
  "map (\<lambda>(name,fam,branch). fam) language_fields =
     map fact_value (tl facts_linguistics_v1_rules)"
  by code_simp

end
