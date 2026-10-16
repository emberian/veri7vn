theory Policy_Checked_Display
  imports "Veri7vn_Policy_Service.Policy_Service" "Veri7vn_HTML_Bytes.HTML_Bytes"
    "Veri7vn_Natural_Mathematics.Natural_Mathematics"
begin

definition policy_ascii :: "string \<Rightarrow> nat list" where "policy_ascii s = map of_char s"
fun policy_digits where
  "policy_digits 0 n=[]" |
  "policy_digits (Suc fuel) n=(if n<10 then [48+n]
    else policy_digits fuel (n div 10) @ [48+n mod 10])"
definition policy_number where "policy_number n=policy_digits 128 n"
fun policy_status_words where
  "policy_status_words PolicyComputed=policy_ascii ''computed rule value''" |
  "policy_status_words PolicyConditionsMet=policy_ascii ''listed numeric conditions met''" |
  "policy_status_words PolicyConditionsFailed=policy_ascii ''listed numeric conditions failed''" |
  "policy_status_words PolicyConditionsMissing=policy_ascii ''listed numeric conditions incomplete''"
fun policy_check_words where
  "policy_check_words InitialStage=policy_ascii ''135 F to 70 F within 2 hours''" |
  "policy_check_words TotalCooling=policy_ascii ''135 F to 41 F within 6 hours total''" |
  "policy_check_words Chronology=policy_ascii ''first-stage time no greater than total time''"
fun policy_verdict_words where
  "policy_verdict_words ConditionMet=policy_ascii ''met''" |
  "policy_verdict_words ConditionFailed=policy_ascii ''failed''" |
  "policy_verdict_words ConditionMissing=policy_ascii ''missing''"
fun policy_pollutant_units where
  "policy_pollutant_units PM25=policy_ascii ''quanta of 0.1 ug/m3 for PM2.5; 24-hour average''" |
  "policy_pollutant_units PM10=policy_ascii ''quanta of 1 ug/m3 for PM10; 24-hour average''" |
  "policy_pollutant_units Ozone=policy_ascii ''quanta of 0.001 ppm for ozone; 8-hour average''" |
  "policy_pollutant_units CarbonMonoxide=policy_ascii ''quanta of 0.1 ppm for CO; 8-hour average''" |
  "policy_pollutant_units SulfurDioxide=policy_ascii ''quanta of 1 ppb for SO2; 1-hour average''" |
  "policy_pollutant_units NitrogenDioxide=policy_ascii ''quanta of 1 ppb for NO2; 1-hour average''"
fun policy_basis_words where
  "policy_basis_words NetArea=policy_ascii ''net square feet''" |
  "policy_basis_words GrossArea=policy_ascii ''gross square feet''"
fun policy_use_words where
  "policy_use_words Business=policy_ascii ''business''" |
  "policy_use_words Mercantile=policy_ascii ''mercantile''" |
  "policy_use_words Residential=policy_ascii ''residential''" |
  "policy_use_words Classroom=policy_ascii ''classroom''" |
  "policy_use_words AssemblyStanding=policy_ascii ''assembly standing''" |
  "policy_use_words AssemblyChairs=policy_ascii ''assembly chairs only''" |
  "policy_use_words AssemblyTables=policy_ascii ''assembly tables and chairs''" |
  "policy_use_words Exercise=policy_ascii ''exercise room''" |
  "policy_use_words LibraryReading=policy_ascii ''library reading room''" |
  "policy_use_words LibraryStacks=policy_ascii ''library stacks''" |
  "policy_use_words CommercialKitchen=policy_ascii ''commercial kitchen''" |
  "policy_use_words Warehouse=policy_ascii ''warehouse''"
fun policy_value_words where
  "policy_value_words (AQIRule p) (AQIValue index concentration)=
    policy_ascii ''AQI '' @ policy_number index @ policy_ascii ''; truncated concentration '' @
    policy_number concentration @ policy_ascii '' '' @ policy_pollutant_units p" |
  "policy_value_words (OccupancyRule use) (Occupants n)=
    policy_ascii ''occupant load '' @ policy_number n @ policy_ascii '' for '' @ policy_use_words use @
    policy_ascii ''; factor '' @
    policy_number (fst (occupancy_factor use)) @ policy_ascii '' '' @
    policy_basis_words (snd (occupancy_factor use)) @ policy_ascii '' per occupant, rounded up''" |
  "policy_value_words CoolingRule CoolingAssessment=policy_ascii ''cooling rule assessment''" |
  "policy_value_words _ _=[]"
fun policy_value_bounded where
  "policy_value_bounded (AQIValue a c)=(a<10^128 \<and> c<10^128)" |
  "policy_value_bounded (Occupants n)=(n<10^128)" |
  "policy_value_bounded CoolingAssessment=True"
fun policy_value_numerals_valid where
  "policy_value_numerals_valid (AQIValue a c)=
    (read_unsigned (policy_number a)=Some a \<and> read_unsigned (policy_number c)=Some c)" |
  "policy_value_numerals_valid (Occupants n)=(read_unsigned (policy_number n)=Some n)" |
  "policy_value_numerals_valid CoolingAssessment=True"
fun policy_factor_numeral_valid where
  "policy_factor_numeral_valid (OccupancyRule use)=
    (read_unsigned (policy_number (fst (occupancy_factor use)))=Some (fst (occupancy_factor use)))" |
  "policy_factor_numeral_valid _=True"
fun policy_numbers_correct where
  "policy_numbers_correct (PolicyReport recipe value status checks conditions)=
    (policy_value_numerals_valid value \<and> policy_factor_numeral_valid (recipe_rule recipe) \<and>
      read_unsigned (policy_number (length conditions))=Some (length conditions))" |
  "policy_numbers_correct (PolicyRefused reason)=False"
fun policy_sentence where
  "policy_sentence (PolicyReport recipe value status checks conditions)=
    policy_ascii ''Under selected policy '' @ policy_ascii (rule_version recipe) @
    policy_ascii '' (source '' @ policy_ascii (rule_source recipe) @
    policy_ascii ''), assuming all '' @ policy_number (length conditions) @
    policy_ascii '' attached premises: '' @ policy_value_words (recipe_rule recipe) value @
    policy_ascii ''; '' @ policy_status_words status @ policy_ascii ''. '' @
    concat (map (\<lambda>(check,verdict). policy_check_words check @ policy_ascii '': '' @
      policy_verdict_words verdict @ policy_ascii ''. '') checks) @
    policy_ascii ''Applicability and real-world observations remain assumptions.''" |
  "policy_sentence (PolicyRefused reason)=[]"
fun display_policy_supported where
  "display_policy_supported (PolicyReport recipe value status checks conditions)=
    (supported_recipe recipe \<and>
      policy_numbers_correct (PolicyReport recipe value status checks conditions) \<and> length (rule_version recipe)\<le>128 \<and>
      length (rule_source recipe)\<le>4096 \<and> length conditions\<le>64 \<and>
      length checks\<le>3 \<and> policy_value_bounded value \<and>
      policy_value_words (recipe_rule recipe) value\<noteq>[])" |
  "display_policy_supported (PolicyRefused reason)=False"
definition checked_policy_statement where
  "checked_policy_statement reply bytes=(if display_policy_supported reply \<and>
    length bytes\<le>16384 \<and> bytes=policy_sentence reply then
      map_option (\<lambda>escaped. [60,112,62] @ escaped @ [60,47,112,62])
        (bounded_escape 16384 65529 bytes) else None)"
definition policy_display_packet where
  "policy_display_packet reply=(if display_policy_supported reply then
    checked_policy_statement reply (policy_sentence reply) else None)"
lemma display_policy_supported_numbers:
  "display_policy_supported reply \<Longrightarrow> policy_numbers_correct reply"
  by (cases reply) auto
lemma policy_display_packet_exact:
  "policy_display_packet reply=Some html \<Longrightarrow>
    display_policy_supported reply \<and> policy_numbers_correct reply \<and> length html\<le>65536 \<and>
    html=[60,112,62] @ html_escape (policy_sentence reply) @ [60,47,112,62] \<and>
    html_decode (length (html_escape (policy_sentence reply)))
      (html_escape (policy_sentence reply))=Some (policy_sentence reply)"
  by (auto simp: policy_display_packet_def checked_policy_statement_def bounded_escape_def
    Let_def html_escape_roundtrip dest: display_policy_supported_numbers split: if_splits option.splits)
definition fixed_policy_display_contract where
  "fixed_policy_display_contract \<longleftrightarrow> (\<forall>reply html. policy_display_packet reply=Some html \<longrightarrow>
    display_policy_supported reply \<and> policy_numbers_correct reply \<and> length html\<le>65536 \<and>
    html=[60,112,62] @ html_escape (policy_sentence reply) @ [60,47,112,62])"
theorem fixed_policy_display_contract_checked: fixed_policy_display_contract
  unfolding fixed_policy_display_contract_def using policy_display_packet_exact by blast

ML_file "native_policy_display.ML"
ML_file "policy_native_gate.ML"
end
