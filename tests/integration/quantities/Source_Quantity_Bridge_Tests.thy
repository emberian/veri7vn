theory Source_Quantity_Bridge_Tests
  imports Veri7vn_Source_Quantity_Bridge.Source_Quantity_Bridge
begin

definition physical_source where
 "physical_source source units cell =
  \<lparr>source_id=source,sequence_id=3,configuration=''calibration-2026-10-15'',
   schema_version=''physical-integer-cell/1'',origin=Measured,
   event_clock=Some \<lparr>basis=Source_Event ''instrument'',ticks=50\<rparr>,
   receipt_clock=\<lparr>basis=Wall ''UTC'',ticks=100\<rparr>,
   payload=Valid \<lparr>reported_value=Source_Batch 1 [[cell]] True,
     reported_rank=None,reported_units=Some units,
     reported_references=[''original-instrument-report''],reported_import_loss=[],
     reported_applicability=[''instrument calibration range'']\<rparr>,
   qualifiers=[''calibrated observation''],raw_reference=Some ''retained-wire''\<rparr>"
definition physical_selection where
 "physical_selection source units cell unit =
   \<lparr>quantity_observation=physical_source source units cell,quantity_row=0,
     quantity_column=0,quantity_unit=unit\<rparr>"
definition length_selection where
 "length_selection = physical_selection ''length-sensor'' ''cm''
   (Cell_Integer False [100]) SourceCentimetres"
definition spring_selections where
 "spring_selections =
   [physical_selection ''stiffness-source'' ''N/m'' (Cell_Integer False [3]) SourceNewtonsPerMetre,
    physical_selection ''extension-source'' ''m'' (Cell_Integer False [2]) SourceMetres]"
definition converted_source where
 "converted_source = run_source_domain [length_selection]
   (ConvertLinear Centimetre Metre) [17] None"
definition spring_source where
 "spring_source model = run_source_domain spring_selections (Spring SpringForce) [17,18] model"

lemma original_observation_not_poll_time:
 "event_clock (quantity_observation length_selection)=
   Some \<lparr>basis=Source_Event ''instrument'',ticks=50\<rparr> \<and>
  receipt_clock (quantity_observation length_selection)=\<lparr>basis=Wall ''UTC'',ticks=100\<rparr>"
 by (simp add: length_selection_def physical_selection_def physical_source_def)
lemma actual_unit_mismatch_rejected:
 "project_source_quantity (physical_source ''sensor'' ''kg'' (Cell_Integer False [2]))
    0 0 SourceMetres = QuantityProjectionRejected SourceUnitMismatch"
 by (simp add: physical_source_def project_source_cell_def Let_def byte_string_def)
lemma missing_row_rejected:
 "project_source_quantity (quantity_observation length_selection) 1 0 SourceCentimetres
   = QuantityProjectionRejected (SourceCellFailure CellRowMissing)"
 by (simp add: length_selection_def physical_selection_def physical_source_def
   project_source_cell_def Let_def)

definition incompatible_source where
 "incompatible_source = run_source_domain [length_selection]
   (ConvertLinear Centimetre Kilogram) [17] None"
definition invalid_stiffness_source where
 "invalid_stiffness_source = run_source_domain
   [physical_selection ''stiffness-source'' ''N/m'' (Cell_Integer False [0]) SourceNewtonsPerMetre,
    physical_selection ''extension-source'' ''m'' (Cell_Integer False [2]) SourceMetres]
   (Spring SpringForce) [17,18] (Some 91)"

definition rejected_source where
 "rejected_source = run_source_domain
   [length_selection, physical_selection ''bad-source'' ''m'' Cell_Null SourceMetres]
   (Spring SpringForce) [17,18] (Some 91)"
definition source_exact_one :: rat where "source_exact_one = 1"
definition source_exact_six :: rat where "source_exact_six = 6"
definition projection_fixture where
 "projection_fixture cell = project_source_quantity
   (physical_source ''sensor'' ''m'' cell) 0 0 SourceMetres"

ML \<open>
local
 val _=(case @{code converted_source} of
   @{code SourceDomainResult} ([retained],call,@{code DomainAnswer} (@{code LinearValue} (@{code Metre},value),conditions))=>
     if retained= @{code length_selection} andalso conditions=[Veri7vn_Numerals.nat_of_integer 17]
       andalso value= @{code source_exact_one} then ()
     else error "Source quantity conversion lost exactness, observation or condition"
   | _=>error "Source-cell exact quantity conversion failed");
 val _=(case @{code spring_source} (SOME (Veri7vn_Numerals.nat_of_integer 91)) of
   @{code SourceDomainResult} (retained,_,@{code DomainAnswer} (@{code LinearValue} (@{code Newton},value),conditions))=>
     if retained= @{code spring_selections}
       andalso member (op =) conditions (Veri7vn_Numerals.nat_of_integer 91)
       andalso List.all (member(op =) conditions) [Veri7vn_Numerals.nat_of_integer 17,Veri7vn_Numerals.nat_of_integer 18]
       andalso value= @{code source_exact_six} then ()
     else error "Source spring force lost exact value, model or provenance"
   | _=>error "Source quantity spring dispatch failed");
 val _=(case @{code rejected_source} of
   @{code SourceInputsRejected} (retained,
     [@{code ProjectedQuantity} _,@{code QuantityProjectionRejected} (@{code SourceCellFailure} @{code CellNotInteger})])=>
       if length retained=2 andalso hd retained= @{code length_selection} then ()
       else error "Rejected source inputs lost original per-cell provenance"
   | _=>error "One invalid source cell collapsed structured projection outcomes");
 val _=(case @{code incompatible_source} of
   @{code SourceDomainResult} (_,_,@{code DomainRejected} @{code QuantityMismatch})=>()
   | _=>error "Incompatible source quantity dimensions produced an answer");
 val _=(case @{code invalid_stiffness_source} of
   @{code SourceDomainResult} (_,_,@{code DomainRejected} @{code InvalidSpringParameters})=>()
   | _=>error "Nonpositive source stiffness produced an answer");
 val _=(case @{code spring_source} NONE of
   @{code SourceDomainResult} (_,_,@{code DomainBlocked} @{code MissingIdealModel})=>()
   | _=>error "Unadopted physical model became unconditional force");
 fun projection cell=@{code projection_fixture} cell;
 val _=List.app(fn cell=>case projection cell of
   @{code QuantityProjectionRejected} (@{code SourceCellFailure} @{code CellNotInteger})=>()
   | _=>error "NULL or REAL bits became a measured rational")
   [@{code Cell_Null},@{code Cell_RealBits} (map Veri7vn_Numerals.nat_of_integer [0,0,0,0,0,0,240,63])];
in val _=writeln "INTEGRATION source_quantity_domain_pure PASS" end;
\<close>
end
