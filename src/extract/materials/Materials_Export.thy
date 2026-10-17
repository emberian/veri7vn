theory Materials_Export
  imports Materials
begin

text \<open>Constructor the untrusted SML recognizer uses to build rationals from
decimal numerals it read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     kernel (MeshEdges 3000) = Exact K_mesh_edges 4500 \<and>
     kernel (MeshEdges 1001) = Decline (Impossible R_odd_faces) \<and>
     kernel (MeshVertices 5000 0) = Exact K_mesh_vertices 2502 \<and>
     kernel (MeshFaces 502 0) = Exact K_mesh_faces 1000 \<and>
     kernel (ScadCube 20 10 5) = Exact K_scad_volume 1000 \<and>
     kernel (ScaleAmount (3 / 2) False 50 BU_g) = Exact K_scale_amount (16875 / 100) \<and>
     kernel (CtValue (Some (1 / 2)) (Some 20)) = Exact K_ct 10 \<and>
     kernel (CtValue (Some (1 / 2)) None) = Decline (Underspecified N_ct) \<and>
     kernel (PorosityAerogel (5 / 2) (11 / 5)) = Decline (Impossible R_bulk_above_skeletal) \<and>
     kernel (Expansion None 2 LU_m 40) = Decline (Underspecified N_alpha) \<and>
     kernel Potable = Decline Judgement \<and>
     kernel (Texture (Some 62) (Some 15) (Some 23)) = Class K_texture Sandy_clay_loam \<and>
     kernel (Texture (Some 50) (Some 30) (Some 40)) = Decline (Impossible R_fractions_total) \<and>
     kernel (Texture None None (Some 30)) = Decline (Underspecified N_two_fractions) \<and>
     kernel (BulkDensity (Some 145) (Some 100)) = Exact K_bulk_density (29 / 20) \<and>
     kernel (ChlorineDose (Some (5 / 2)) (Some 1)) = Exact K_dose (7 / 2) \<and>
     kernel (Pounds (Some 5) (Some (5 / 2)) None) = Exact K_pounds (10425 / 100) \<and>
     stated_of Fam_add 4500 = Some ((4500000, -3), Fixed) \<and>
     render_layout Fixed (4500000, -3) = STR ''4500'' \<and>
     render_layout Commas (1500000, 0) = STR ''1,500,000'' \<and>
     render_layout (Sig 4) (6802, -4) = STR ''0.6802'' \<and>
     render_layout Fixed (16875, -2) = STR ''168.75'' \<and>
     render_layout (Sig 3) (398, -9) = STR ''3.98e-07'' \<and>
     response (reply_of (MeshEdges 3000)) = STR ''The mesh has 4500 edges (E = 3F/2 = 3 x 3000 / 2; closed triangle mesh).''"

export_code reply_of answered reply_kind response stated silent mk_rat self_test
  integer_of_int nat_of_integer int_of_integer
  MeshVertices MeshEdges MeshFaces ScadCube ScadSphere ScadCylinder ScadFrustum ScaleAmount
  ScaleFactor ScaleUnread Extrude PackingFactor CrystalDensity PorosityAerogel Expansion Modulus
  Strain Stress MatUnread Texture SoilPorosity WaterContent VolWaterContent BulkDensity
  HardnessGpg HardnessMgl Pounds CtValue ChlorineDose Dilution PhOf HConc Potable
  St_sc St_bcc St_fcc LU_mm LU_cm LU_m AU_mm2 AU_cm2 AU_m2 FU_N FU_kN SU_Pa SU_MPa SU_GPa
  XU_pm XU_nm XU_A VA_mm3 VA_cm3 BU_g BU_kg BU_cm3 BU_mm3 BU_cm2 BU_mm2 BU_ml C_pct C_mgl
  WU_l WU_ml WU_gal
  in SML module_name Materials file_prefix materials

ML \<open>
  val theorems = [@{thm kernel_exact_sound}, @{thm kernel_approx_sound}, @{thm kernel_class_sound},
    @{thm kernel_decline_iff}, @{thm kernel_imprecise}, @{thm enclose_sound}, @{thm to_dec_sound},
    @{thm to_dec3_sound}, @{thm to_fixed_sound}, @{thm stated_of_sound}, @{thm round_sig_sound},
    @{thm mesh_vertices_euler}, @{thm mesh_edges_shared}, @{thm mesh_faces_euler},
    @{thm mesh_odd_faces_decline}, @{thm scad_cube_volume}, @{thm scad_negative_decline},
    @{thm scad_sphere_volume}, @{thm scad_cylinder_volume}, @{thm scad_frustum_volume},
    @{thm scale_volume_cubed}, @{thm scale_area_squared}, @{thm scale_factor_cubed},
    @{thm extrude_time}, @{thm extrude_underspecified},
    @{thm packing_factor}, @{thm crystal_density}, @{thm crystal_structure_needed},
    @{thm porosity_aerogel}, @{thm porosity_aerogel_decline}, @{thm stress_def}, @{thm strain_def},
    @{thm modulus_def}, @{thm expansion_def}, @{thm expansion_needs_alpha},
    @{thm classify_sand}, @{thm classify_clay}, @{thm classify_silt}, @{thm texture_sound},
    @{thm texture_underspecified}, @{thm soil_bulk_density}, @{thm soil_porosity},
    @{thm soil_porosity_decline}, @{thm gravimetric_water}, @{thm volumetric_water},
    @{thm water_content_masses}, @{thm gpg_constant}, @{thm hardness_gpg_to_mgl},
    @{thm hardness_mgl_to_gpg}, @{thm hardness_round_trip}, @{thm pounds_formula},
    @{thm pounds_product}, @{thm ct_value}, @{thm dose_value}, @{thm dilution_balance},
    @{thm ph_value}, @{thm ph_inverse}, @{thm h_conc_value}, @{thm h_conc_inverse},
    @{thm water_not_potable}, @{thm dilution_nonpositive},
    @{thm reply_answered_iff}, @{thm reply_withheld_names_decline}, @{thm reply_states_exact}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("materials theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "materials self test failed";
  val _ = writeln ("VERI7VN_MATERIALS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
