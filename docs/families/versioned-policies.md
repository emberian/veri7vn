# Versioned policy calculations

Native definitions transcribe audited airquality/architecture/coldchain. Reports are conditional calculations; jurisdiction, applicability, measurement accuracy and action authority remain premises.

| Fixed recipe | Meaning |
|---|---|
| `epa_2024_recipe pollutant premises` | Six AQI tables/units/averaging periods/truncation quanta; EPA AQS2024 PM revision, finite index≤500 and table-range guards |
| `ibc_2021_recipe use premises` | Twelve IBC2021 Table1004.5 occupancy factors, square feet and net/gross basis |
| `fda_2022_recipe premises` | FDA2022 §3-501.14(A),135F→70F first stage and135F→41F total |

Some edition must exactly match the recipe; missing/mismatched/relabelled/unsupported editions reject. `PolicyFraction` is exact nonnegative numerator/denominator; zero denominators reject. PM uses µg/m³, ozone/CO ppm, SO2/NO2 ppb, with typed averaging period. Occupancy checks basis; cooling retains optional elapsed observations and chronological order.

`registered_policy_dispatch` returns recipe/value/status/checks and recipe+call conditions. `policy_execution_refinement` connects it to `policy_call_meaning`; missing/failed first stage cannot yield `PolicyConditionsMet`. `Policy_Plans` uses a distinct typed_plan_bundle carrier.

Repairs: exact truncation/half-up AQI interpolation replaces float epsilon; exact occupancy ceiling makes150.000000001/factor150 yield2 rather than upstream1; five-hour total alone leaves cooling first-stage unresolved. [EPA table](https://aqs.epa.gov/aqsweb/documents/codetables/aqi_breakpoints.html) and [FDA §3-501.14(A),p92](https://www.fda.gov/files/food/published/FDA-FoodCode2022-FullDocument-01182023_0.pdf#page=92) identify references; the second cooling limit is six-hour total, not four hours after70F.

`python3 tests/families/domains/policies/observe_upstream.py` compares33 AQI rows/12 factors and reproduced repairs. `Policy_Bundle` has fixed generated interpreter, admitted universal contract, opaque request/output/pin, bounded projection/release and quadratic syntax charge. `Policy_Service` binds actual condition propositions/development/source slices; `Veri7vn_Scoped_Policy_Request` retains Scope child and refuses denial. The existing Domain ticket worker supplies one-shot charged execution, not quantity semantics.

Pure retry, `Policy_Examples`, `Policy_Runtime_Checks` and `Policy_Scoped_Checks` remain queued: no native/runtime PASS. `Policy_Checked_Display`/`Policy_Native_Gate` draft bounded escaped same-request output and retained scope; contracts are distinct from a theorem of the answer. Remaining: resident installation/charge/license/recovery/workbench, editable factor/table recipes, AQI aggregates/categories and further cooling/holding/cooking/date rules. Three recipes do not complete migration.
