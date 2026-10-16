theory Domain_Checked_Display
  imports "Veri7vn_Domain_Service_Objects.Domain_Service_Objects"
    "Veri7vn_Natural_Mathematics.Natural_Mathematics"
    "Veri7vn_HTML_Bytes.HTML_Bytes"
begin

text \<open>The displayed result is tied to the original typed request by the
native same-request gate. This closed grammar states the exact typed result,
all-premise qualifier and adopted-model qualifier; it does not reinterpret
or paraphrase the original question. Full native conditions remain attached.\<close>

fun linear_display_label where
  "linear_display_label Metre = [109]"
| "linear_display_label Kilometre = [107,109]"
| "linear_display_label Centimetre = [99,109]"
| "linear_display_label Millimetre = [109,109]"
| "linear_display_label Inch = [105,110]"
| "linear_display_label Foot = [102,116]"
| "linear_display_label Yard = [121,100]"
| "linear_display_label Mile = [109,105]"
| "linear_display_label NauticalMile = [110,109,105]"
| "linear_display_label Kilogram = [107,103]"
| "linear_display_label Gram = [103]"
| "linear_display_label Milligram = [109,103]"
| "linear_display_label Pound = [108,98]"
| "linear_display_label Ounce = [111,122]"
| "linear_display_label Tonne = [116]"
| "linear_display_label Stone = [115,116,111,110,101]"
| "linear_display_label Litre = [76]"
| "linear_display_label Millilitre = [109,76]"
| "linear_display_label GallonUS = [85,83,45,103,97,108]"
| "linear_display_label QuartUS = [85,83,45,113,116]"
| "linear_display_label PintUS = [85,83,45,112,116]"
| "linear_display_label CupUS = [85,83,45,99,117,112]"
| "linear_display_label FluidOunceUS = [85,83,45,102,108,111,122]"
| "linear_display_label CubicMetre = [109,94,51]"
| "linear_display_label SquareMetre = [109,94,50]"
| "linear_display_label SquareFoot = [102,116,94,50]"
| "linear_display_label Acre = [97,99,114,101]"
| "linear_display_label Hectare = [104,97]"
| "linear_display_label SquareKilometre = [107,109,94,50]"
| "linear_display_label SquareMile = [109,105,94,50]"
| "linear_display_label MetrePerSecond = [109,47,115]"
| "linear_display_label KilometrePerHour = [107,109,47,104]"
| "linear_display_label MilePerHour = [109,112,104]"
| "linear_display_label Knot = [107,110]"
| "linear_display_label Second = [115]"
| "linear_display_label Minute = [109,105,110]"
| "linear_display_label Hour = [104]"
| "linear_display_label Day = [100]"
| "linear_display_label Week = [119,101,101,107]"
| "linear_display_label Pascal = [80,97]"
| "linear_display_label Kilopascal = [107,80,97]"
| "linear_display_label Bar = [98,97,114]"
| "linear_display_label Atmosphere = [97,116,109]"
| "linear_display_label Psi = [112,115,105]"
| "linear_display_label MmHg = [109,109,72,103,45,99,111,110,118,101,110,116,105,111,110,97,108]"
| "linear_display_label Joule = [74]"
| "linear_display_label Kilojoule = [107,74]"
| "linear_display_label Calorie = [99,97,108,45,116,104,101,114,109,111,99,104,101,109,105,99,97,108]"
| "linear_display_label Kilocalorie = [107,99,97,108,45,116,104,101,114,109,111,99,104,101,109,105,99,97,108]"
| "linear_display_label KilowattHour = [107,87,104]"
| "linear_display_label Btu = [66,84,85]"
| "linear_display_label Watt = [87]"
| "linear_display_label Kilowatt = [107,87]"
| "linear_display_label Horsepower = [104,112,45,109,101,99,104,97,110,105,99,97,108]"
| "linear_display_label Byte = [66]"
| "linear_display_label Kilobyte = [107,66]"
| "linear_display_label Megabyte = [77,66]"
| "linear_display_label Gigabyte = [71,66]"
| "linear_display_label Terabyte = [84,66]"
| "linear_display_label Kibibyte = [75,105,66]"
| "linear_display_label Mebibyte = [77,105,66]"
| "linear_display_label Gibibyte = [71,105,66]"
| "linear_display_label Newton = [78]"
| "linear_display_label NewtonPerMetre = [78,47,109]"
definition linear_display_table where
  "linear_display_table = [(linear_display_label Metre,Metre), (linear_display_label Kilometre,Kilometre), (linear_display_label Centimetre,Centimetre), (linear_display_label Millimetre,Millimetre), (linear_display_label Inch,Inch), (linear_display_label Foot,Foot), (linear_display_label Yard,Yard), (linear_display_label Mile,Mile), (linear_display_label NauticalMile,NauticalMile), (linear_display_label Kilogram,Kilogram), (linear_display_label Gram,Gram), (linear_display_label Milligram,Milligram), (linear_display_label Pound,Pound), (linear_display_label Ounce,Ounce), (linear_display_label Tonne,Tonne), (linear_display_label Stone,Stone), (linear_display_label Litre,Litre), (linear_display_label Millilitre,Millilitre), (linear_display_label GallonUS,GallonUS), (linear_display_label QuartUS,QuartUS), (linear_display_label PintUS,PintUS), (linear_display_label CupUS,CupUS), (linear_display_label FluidOunceUS,FluidOunceUS), (linear_display_label CubicMetre,CubicMetre), (linear_display_label SquareMetre,SquareMetre), (linear_display_label SquareFoot,SquareFoot), (linear_display_label Acre,Acre), (linear_display_label Hectare,Hectare), (linear_display_label SquareKilometre,SquareKilometre), (linear_display_label SquareMile,SquareMile), (linear_display_label MetrePerSecond,MetrePerSecond), (linear_display_label KilometrePerHour,KilometrePerHour), (linear_display_label MilePerHour,MilePerHour), (linear_display_label Knot,Knot), (linear_display_label Second,Second), (linear_display_label Minute,Minute), (linear_display_label Hour,Hour), (linear_display_label Day,Day), (linear_display_label Week,Week), (linear_display_label Pascal,Pascal), (linear_display_label Kilopascal,Kilopascal), (linear_display_label Bar,Bar), (linear_display_label Atmosphere,Atmosphere), (linear_display_label Psi,Psi), (linear_display_label MmHg,MmHg), (linear_display_label Joule,Joule), (linear_display_label Kilojoule,Kilojoule), (linear_display_label Calorie,Calorie), (linear_display_label Kilocalorie,Kilocalorie), (linear_display_label KilowattHour,KilowattHour), (linear_display_label Btu,Btu), (linear_display_label Watt,Watt), (linear_display_label Kilowatt,Kilowatt), (linear_display_label Horsepower,Horsepower), (linear_display_label Byte,Byte), (linear_display_label Kilobyte,Kilobyte), (linear_display_label Megabyte,Megabyte), (linear_display_label Gigabyte,Gigabyte), (linear_display_label Terabyte,Terabyte), (linear_display_label Kibibyte,Kibibyte), (linear_display_label Mebibyte,Mebibyte), (linear_display_label Gibibyte,Gibibyte), (linear_display_label Newton,Newton), (linear_display_label NewtonPerMetre,NewtonPerMetre)]"
definition decode_linear_display where
  "decode_linear_display token = map_of linear_display_table token"
lemma linear_display_roundtrip:
  "decode_linear_display (linear_display_label u) = Some u"
  by (cases u) (simp_all add: decode_linear_display_def linear_display_table_def)

fun temperature_display_label where
  "temperature_display_label Kelvin = [75]"
| "temperature_display_label Celsius = [100,101,103,67]"
| "temperature_display_label Fahrenheit = [100,101,103,70]"
definition decode_temperature_display where
  "decode_temperature_display token = map_of
    [(temperature_display_label Kelvin,Kelvin),
     (temperature_display_label Celsius,Celsius),
     (temperature_display_label Fahrenheit,Fahrenheit)] token"
lemma temperature_display_roundtrip:
  "decode_temperature_display (temperature_display_label u) = Some u"
  by (cases u) (simp_all add: decode_temperature_display_def)

definition display_rational where
  "display_rational token = (let left=takeWhile (\<lambda>b. b\<noteq>47) token;
    tail=drop (length left) token in
    if tail=[] then None else
      (case (read_integer left,read_integer (tl tail)) of
        (Some n,Some d) \<Rightarrow> if hd tail=47 \<and> 0<d then Some (Fract n d) else None
      | _ \<Rightarrow> None))"

definition decode_domain_quantity where
  "decode_domain_quantity words = (case words of [exact,carrier,literal,unit] \<Rightarrow>
    if exact=[69,120,97,99,116] then
      (case display_rational literal of None \<Rightarrow> None | Some q \<Rightarrow>
        if carrier=[113,117,97,110,116,105,116,121] then map_option (\<lambda>u. LinearValue u q) (decode_linear_display unit)
        else if carrier=[116,101,109,112,101,114,97,116,117,114,101,45,112,111,105,110,116] then map_option (\<lambda>u. PointValue u q) (decode_temperature_display unit)
        else if carrier=[116,101,109,112,101,114,97,116,117,114,101,45,100,105,102,102,101,114,101,110,99,101] then map_option (\<lambda>u. DeltaValue u q) (decode_temperature_display unit)
        else None)
    else None | _ \<Rightarrow> None)"

definition spring_display_suffix where
  "spring_display_suffix = [[117,110,100,101,114], [116,104,101], [97,100,111,112,116,101,100], [105,100,101,97,108], [115,112,114,105,110,103], [114,101,115,112,111,110,115,101], [109,111,100,101,108]]"
definition strip_spring_display_suffix where
  "strip_spring_display_suffix words = (if 7\<le>length words \<and>
    drop (length words-7) words=spring_display_suffix
    then (True,take (length words-7) words) else (False,words))"

definition strip_domain_condition_header where
  "strip_domain_condition_header words = (case words of a#b#c#count#d#e#rest \<Rightarrow>
    if a=[67,111,110,100,105,116,105,111,110,97,108] \<and> b=[111,110] \<and> c=[97,108,108] \<and>
      d=[97,116,116,97,99,104,101,100] \<and> e=[112,114,101,109,105,115,101,115,58] then
      (case read_unsigned count of Some n \<Rightarrow> if 0<n then Some(n,rest) else None | None \<Rightarrow> None)
    else Some(0,words) | _ \<Rightarrow> Some(0,words))"

definition decode_domain_statement where
  "decode_domain_statement bytes = (if length bytes>16384 then None else
    (case strip_domain_condition_header (ascii_words bytes) of None \<Rightarrow> None | Some(count,words) \<Rightarrow>
      (case strip_spring_display_suffix words of (model,body) \<Rightarrow>
        map_option (\<lambda>value. (value,count,model)) (decode_domain_quantity body))))"

definition checked_domain_statement where
  "checked_domain_statement value conditions model bytes = (if length conditions\<le>64 \<and>
    (model \<longrightarrow> conditions\<noteq>[]) \<and> length bytes\<le>16384 \<and> list_all (\<lambda>b. b<256) bytes \<and>
    decode_domain_statement bytes=Some(value,length conditions,model) then
      map_option (\<lambda>escaped. [60,112,62] @ escaped @ [60,47,112,62])
        (bounded_escape 16384 65529 bytes)
    else None)"

theorem checked_domain_statement_exact:
  assumes "checked_domain_statement value conditions model bytes=Some html"
  shows "decode_domain_statement bytes=Some(value,length conditions,model)"
    "length html\<le>65536"
    "html=[60,112,62] @ html_escape bytes @ [60,47,112,62]"
    "html_decode (length (html_escape bytes)) (html_escape bytes)=Some bytes"
    "model \<longrightarrow> conditions\<noteq>[]"
  using assms
  by (auto simp: checked_domain_statement_def bounded_escape_def Let_def html_escape_roundtrip
    split: if_splits option.splits)

definition call_uses_spring_model where
  "call_uses_spring_model call \<longleftrightarrow> (case (call_operation call,call_model_premise call) of
    (Spring op,Some premise) \<Rightarrow> True | _ \<Rightarrow> False)"

theorem checked_domain_native_meaning:
  assumes checked: "checked_domain_statement value conditions (call_uses_spring_model call) bytes=Some html"
    and native: "domain_call_meaning call (DomainAnswer value conditions)"
  shows "domain_meaning (call_operation call) (call_values call) value"
    "conditions=merge_conditions (call_required_conditions call)"
    "decode_domain_statement bytes=Some(value,length conditions,call_uses_spring_model call)"
  using native checked_domain_statement_exact(1)[OF checked]
  by (auto simp: domain_call_meaning_def)

theorem checked_domain_adopted_model_meaning:
  assumes checked: "checked_domain_statement value conditions (call_uses_spring_model call) bytes=Some html"
    and native: "domain_model_call_meaning force energy call (DomainAnswer value conditions)"
  shows "domain_model_value_meaning force energy (call_operation call) (call_values call) value"
    "conditions=merge_conditions (call_required_conditions call)"
    "decode_domain_statement bytes=Some(value,length conditions,call_uses_spring_model call)"
  using native checked_domain_statement_exact(1)[OF checked]
  by (auto simp: domain_model_call_meaning_def domain_call_meaning_def)

text \<open>The fixed runtime bridge checks a proposed sentence, then compares its
reflected value with the actual same-request native output. This packet retains
only the condition count; exact condition identities and propositions travel
alongside it as opaque source-owned associations. Bound the count before any
replication, including for rejected malicious sentences.\<close>
definition domain_display_packet where
  "domain_display_packet bytes = (case decode_domain_statement bytes of
    None \<Rightarrow> None | Some(value,count,model) \<Rightarrow>
      if count>64 then None else
        map_option (\<lambda>html. (value,count,model,html))
          (checked_domain_statement value (replicate count 0) model bytes))"

lemma domain_display_packet_exact:
  assumes "domain_display_packet bytes=Some(value,count,model,html)"
  shows "decode_domain_statement bytes=Some(value,count,model) \<and> count\<le>64 \<and>
    length html\<le>65536 \<and>
    html=[60,112,62] @ html_escape bytes @ [60,47,112,62] \<and>
    (model \<longrightarrow> count>0)"
  using assms checked_domain_statement_exact
  by (auto simp: domain_display_packet_def split: option.splits if_splits prod.splits)

definition fixed_domain_display_contract where
  "fixed_domain_display_contract \<longleftrightarrow>
    (\<forall>bytes value count model html.
      domain_display_packet bytes=Some(value,count,model,html) \<longrightarrow>
      (decode_domain_statement bytes=Some(value,count,model) \<and> count\<le>64 \<and>
        length html\<le>65536 \<and>
        html=[60,112,62] @ html_escape bytes @ [60,47,112,62] \<and>
        (model \<longrightarrow> count>0)))"

theorem fixed_domain_display_contract_checked: fixed_domain_display_contract
  unfolding fixed_domain_display_contract_def using domain_display_packet_exact by blast

ML_file "native_domain_display.ML"
ML_file "domain_native_gate.ML"

end
