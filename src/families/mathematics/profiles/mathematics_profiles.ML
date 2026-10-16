(* Concrete family profile declarations. Their actual theorem handles retain
   native ownership; declaration alone does not admit or activate execution. *)
signature VERI7VN_MATHEMATICS_PROFILES =
sig
  type profiles
  val declare: Veri7vn_Native_Registry.generation -> Veri7vn_Native_Registry.registry ->
    profiles * Veri7vn_Native_Registry.registry
  val rational: profiles -> Veri7vn_Native_Profiles.declaration
  val symbolic: profiles -> Veri7vn_Native_Profiles.declaration
  val decimal: profiles -> Veri7vn_Native_Profiles.declaration
  val primitive_family: profiles -> Veri7vn_Native_Profiles.declaration
end;
structure Veri7vn_Mathematics_Profiles :> VERI7VN_MATHEMATICS_PROFILES =
struct
  structure R = Veri7vn_Native_Registry;
  structure P = Veri7vn_Native_Profiles;
  datatype profiles = Profiles of {rational: P.declaration, symbolic: P.declaration,
    decimal: P.declaration, primitive_family: P.declaration};
  fun rational (Profiles p) = #rational p;
  fun symbolic (Profiles p) = #symbolic p;
  fun decimal (Profiles p) = #decimal p;
  fun primitive_family (Profiles p) = #primitive_family p;
  fun declare generation registry =
    let
      val (rational_law, r1) = R.insert generation "mathematics.rational-representation"
        (R.Theorem @{thm rational_pair_decode_refinement}) registry;
      val (symbolic_law, r2) = R.insert generation "mathematics.symbolic-evaluator-representation"
        (R.Theorem @{thm symbolic_evaluator_representation}) r1;
      val (decimal_law, r3) = R.insert generation "mathematics.decimal-enclosure"
        (R.Theorem @{thm decimal_display_encloses}) r2;
      val (primitive_law, r4) = R.insert generation "mathematics.antiderivative-family"
        (R.Theorem @{thm antiderivative_family_complete}) r3;
      val rational = P.declare generation {
        carrier = @{typ rat}, representation = SOME @{cterm rational_pair_rep},
        numeric = P.Exact, shape = @{cterm "\<lambda>q::rat. True"}, scope = P.Complete,
        literal_policy = "signed integer numerator / strictly positive natural denominator; original byte slice retained",
        display_projection = NONE, materialization_limit = SOME 100000,
        dependencies = [rational_law]};
      val symbolic = P.declare generation {
        carrier = @{typ math_expr}, representation = SOME @{cterm symbolic_representation},
        numeric = P.Exact, shape = @{cterm "\<lambda>e::math_expr. True"}, scope = P.Complete,
        literal_policy = "inert family tokens; indexed parameters; no host source or evaluation",
        display_projection = NONE, materialization_limit = SOME 100000,
        dependencies = [symbolic_law]};
      val decimal = P.declare generation {
        carrier = @{typ decimal_enclosure}, representation = SOME @{cterm enclosure_represents},
        numeric = P.Approximate @{cterm enclosure_represents},
        shape = @{cterm "\<lambda>e::decimal_enclosure. True"}, scope = P.Complete,
        literal_policy = "signed mantissa and natural decimal places; half-open exact enclosure",
        display_projection = NONE, materialization_limit = SOME 100000,
        dependencies = [decimal_law]};
      val primitive_family = P.declare generation {
        carrier = @{typ antiderivative_family}, representation = SOME @{cterm antiderivative_member},
        numeric = P.Exact, shape = @{cterm "\<lambda>family::antiderivative_family. True"}, scope = P.Complete,
        literal_policy = "native polynomial primitive family; arbitrary real logical constant; rational runtime instances",
        display_projection = NONE, materialization_limit = SOME 100000,
        dependencies = [primitive_law]};
    in (Profiles {rational=rational, symbolic=symbolic, decimal=decimal,
        primitive_family=primitive_family}, r4) end;
end;
