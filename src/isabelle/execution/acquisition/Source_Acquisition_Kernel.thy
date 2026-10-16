theory Source_Acquisition_Kernel
  imports Veri7vn_Source_Acquisition.Source_Acquisition_Association
    Veri7vn_Source_Metadata.Source_Metadata_Codec
    Veri7vn_Admission.Veri7vn_Admission
    Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets
    Veri7vn_Native_Request_Scope.Native_Request_Scope
begin

text \<open>Authored settings contain semantic source choices and bounded resource
requests. Runtime occurrence identities are allocated by the protected owner.\<close>
record source_acquisition_settings =
  settings_format_version :: nat
  settings_source_key :: string
  settings_encoding :: string
  settings_schema :: string
  settings_version :: source_version_requirement
  settings_origin :: sample_origin
  settings_configuration :: string
  settings_quality :: string
  settings_calibration :: "string option"
  settings_recipe :: string
  settings_selection :: string
  settings_byte_limit :: integer
  settings_row_limit :: integer

definition instantiate_source_settings where
  "instantiate_source_settings s request attempt binding retention =
    \<lparr>required_request=request, required_attempt=attempt,
      required_source_binding=binding, required_source_key=settings_source_key s,
      required_encoding=settings_encoding s, required_schema=settings_schema s,
      required_version=settings_version s, required_origin=settings_origin s,
      required_configuration=settings_configuration s,
      required_quality_policy=settings_quality s, required_calibration=settings_calibration s,
      required_recipe=settings_recipe s, required_selection=settings_selection s,
      required_retention_policy=retention, acquisition_byte_limit=settings_byte_limit s,
      acquisition_row_limit=settings_row_limit s\<rparr>"

lemma instantiated_source_identity:
  "required_request (instantiate_source_settings s request attempt binding retention)=request \<and>
   required_attempt (instantiate_source_settings s request attempt binding retention)=attempt \<and>
   required_source_binding (instantiate_source_settings s request attempt binding retention)=binding"
  by (simp add: instantiate_source_settings_def)

definition source_owned_acquisition_meaning where
  "source_owned_acquisition_meaning settings request attempt binding limit metadata bytes a
    \<longleftrightarrow> settings_format_version settings=1 \<and>
      0 < settings_byte_limit settings \<and> 0 < settings_row_limit settings \<and>
      (case decode_source_metadata_wire limit metadata of None \<Rightarrow> False
    | Some record \<Rightarrow> metadata_private record \<and>
      association_requirement a=instantiate_source_settings settings request attempt binding 0 \<and>
      association_manifest a=construct_source_manifest (association_requirement a) record \<and>
      association_original_bytes a=bytes \<and> source_association_meaning a)"

lemma owned_acquisition_association:
  "source_owned_acquisition_meaning settings request attempt binding limit metadata bytes a
    \<Longrightarrow> source_association_meaning a"
  by (auto simp: source_owned_acquisition_meaning_def split: option.splits)

code_reflect Veri7vn_Source_Acquisition_Code
  datatypes sample_origin = _ and reading = _ and clock_basis = _
    and clock_reading_ext = _ and observation_ext = _ and source_rank = _
    and source_assertion_ext = _ and source_version_requirement = _
    and source_acquisition_requirement_ext = _ and native_source_manifest_ext = _
    and source_metadata_record_ext = _ and source_association = _
    and source_acquisition_settings_ext = _
  functions construct_source_association association_requirement association_manifest
    association_original_bytes association_batch association_observation association_wire_bytes
    association_rows association_columns association_payload_bytes association_max_cell_payload_bytes
    instantiate_source_settings decode_source_metadata_wire construct_source_manifest
    metadata_private acquisition_byte_limit acquisition_row_limit
    required_request required_attempt required_source_binding settings_byte_limit settings_row_limit settings_format_version

ML \<open>
structure Veri7vn_Source_Acquisition_Kernel =
struct
  structure C=Veri7vn_Source_Acquisition_Code;
  type association=C.source_association;
  type settings=unit C.source_acquisition_settings_ext;
  type requirement=unit C.source_acquisition_requirement_ext;
  type manifest=unit C.native_source_manifest_ext;
  val context= @{context};
  val theory= @{theory};
  val executable=Veri7vn_Executable_Identity.pin theory
    {artifact="veri7vn.source-acquisition/2",compiler="Isabelle code generator / PolyML",
     target="Eval (SML)",serializers=["exact native source association"],
     foreign_primitives=[],settings=["versioned source acquisition; fixed captured context"]};
  val construct= C.construct_source_association;
  val instantiate= C.instantiate_source_settings;
  val decode_manifest= C.decode_source_metadata_wire;
  val manifest= C.construct_source_manifest;
  val reify_manifest= @{code "Code_Evaluation.term_of :: native_source_manifest => term"};
  val reify_requirement= @{code "Code_Evaluation.term_of :: source_acquisition_requirement => term"};
  val association_observation= C.association_observation;
  val nat_of_integer=Veri7vn_Numerals.nat_of_integer;
  val integer_of_nat=Veri7vn_Numerals.integer_of_nat;
  val reify_observation= @{code "Code_Evaluation.term_of :: qualified_batch_observation => term"};
  val reify= @{code "Code_Evaluation.term_of :: source_association => term"};
  val decode_settings= @{computation "source_acquisition_settings"
    terms: "0::nat" "1::nat" "numeral::num=>nat" "0::int" "1::int"
      "numeral::num=>int" "uminus::int=>int"
    datatypes: source_acquisition_settings source_version_requirement sample_origin
      "string option" string char num nat int integer bool unit}
    (fn _ => fn value => (value:settings option));
end
\<close>

ML_file "source_acquisition_signature.ML"
ML_file "common_source_owner.ML"

end
