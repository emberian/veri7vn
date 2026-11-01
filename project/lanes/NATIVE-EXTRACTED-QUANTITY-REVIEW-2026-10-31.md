# Extracted quantity delivery review, 31 October 2026

Reviewer: Astra reader/domain lane. Source approval only. No builds, tests,
commits or specialist panel runs were performed here. No new panel numbers or
theorem claims are made.

The driver now adds an optional unit field from the recognized typed request.
This connects a real extracted provider reply to native quantity continuation.
The unit projection is handwritten and untrusted. The kernel still supplies the
answer status, kind, displayed numeric value and response. Their construction,
and the route path, are unchanged.

I checked all 24 request constructors against `Quantity.thy`'s `qval`,
`exact_text`, `approx_text` and `reply_of`:

| Requests | Unit of the stated numeric value |
| --- | --- |
| Density | kg/m3 |
| MassOf, VolumeOf | Requested output qunit label |
| Linear Convert | Target qunit label |
| SpringForce, Buoyant | N |
| SpringExtension | m |
| SpringConstant | N/m |
| SpringEnergy | J |
| SpringPeriod, SpringFrequency | s, Hz respectively |
| PressureGauge, PressureAbs, Hydrostatic | Pa |
| Submerged | 1, a fraction rather than the displayed secondary percentage |
| FuelEnergy, FuelUsefulEnergy | Requested output qunit label |
| FuelCO2, FuelMassNeeded, FuelUsefulMass | kg |
| FuelNCV | MJ/kg, rather than the secondary kWh/kg figure in prose |
| Floats, UnsupportedCondition | No unit metadata |
| Temperature Convert, ConvertDelta, mixed linear/temperature Convert | No unit metadata |

Units are not parsed from prose. This matters for replies that also display
secondary quantities: density in g/cm3, extension in cm, pressure in kPa,
fractions as percentages and fuel energy in MJ. The metadata follows the primary
stated value, not those secondary figures.

`unit_field` requires both `answered = true` and a present `stated` numeric value.
Sparse requests, mismatch, impossible, unsupported and imprecise replies cannot
create numeric anchors. Boolean `Floats` replies have no stated numeric value.
Approximate period/frequency values can carry units, but remain displayed values.

Temperature points and differences are deliberately both omitted, including
kelvin. Native-v1 stores a scalar and unit token without an affine role; labeling
both with the same unit would lose their distinction. The driver documents this
unsupported continuation. Gauge/absolute pressure retain their original reply
kind, while the native continuation is arithmetic over the displayed scalar,
not a new physical model or a recomputation of its premises.

The only export change adds the existing `unit_label` function to the generated
module signature. No theorem statement or mathematical implementation changes.
The existing theorem list does not prove the handwritten metadata projection.
The driver now says so explicitly.

The actual host consumer reads structured number/unit fields after arbitration,
binds provenance to the admitted executable hash, and marks the retained number
`DisplayedDecimal`. Exact subsequent rational arithmetic therefore does not
upgrade the source's rounding or physical precision.

Source approved for central validation. The central validator must obtain a
fresh checked Quantity export, compile the resulting driver, inspect protocol
cases for every constructor and refusal/boolean/temperature omissions, and run
the six affected specialist panels: densities, units, units-v3, springs, fluids,
fuels. Compare old status/kind/value/response/path separately from additive unit
metadata. Finally exercise the actual family binary through native cost/scale
and restart; a synthetic provider alone cannot establish this consumer path.
