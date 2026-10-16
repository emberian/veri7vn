# Versioned policy calculations

The policy family transcribes the audited `airquality`, `architecture` and
`coldchain` source modules into native definitions. It computes conditional
policy reports. It does not establish current law, applicability, measurement
accuracy, food safety or permission to act.

## Author recipe and native meaning

`Versioned_Policies.thy` owns three explicit recipe constructors:

- `epa_2024_recipe pollutant premises`: six source AQI tables, their units,
  averaging periods and truncation quanta, EPA AQS 2024 PM revision.
- `ibc_2021_recipe use premises`: twelve source occupancy factors, preserving
  square feet and net/gross area, IBC 2021 Table 1004.5.
- `fda_2022_recipe premises`: cooling first-stage and total limits,
  FDA Food Code 2022 section 3-501.14(A).

A call must supply `Some edition`, matching its supported recipe. Missing,
empty, mismatched and relabelled recipes are refused. Source strings identify
which upstream transcription supplied the rule; they are not evidence of a
jurisdiction's adoption. The selected AQI ranges were also inspected against the
[official EPA AQS breakpoint table](https://aqs.epa.gov/aqsweb/documents/codetables/aqi_breakpoints.html).
This installation retains the source specialist's range limit, including its
refusal beyond index 500 or where another averaging table is required. This initial finite installation rejects other recipes
rather than quietly treating an arbitrary edition label as a new table.

Inputs use `PolicyFraction numerator denominator`, an exact nonnegative
fraction. Zero denominators are refused. AQI input concentrations use micrograms
per cubic metre for PM, ppm for ozone/CO and ppb for SO2/NO2. A separate typed
averaging-period field is checked. The reported concentration is an integer
number of the pollutant's truncation quanta. Out-of-table concentrations are
refused, including ozone/SO2 ranges requiring different averaging tables.
Occupancy input uses square feet plus a checked net/gross basis. Cooling input
contains optional elapsed hours from 135 F to 70 F and from 135 F to 41 F.
Those endpoint meanings remain part of the input contract.

`registered_policy_dispatch` returns the exact recipe, value, status, individual
check verdicts and union of recipe/call condition IDs. `policy_call_meaning`
records this scoped calculation. `policy_execution_refinement` connects the
fixed interpreter to that meaning. The native cooling theorems additionally
establish that missing or failed first-stage evidence cannot yield
`PolicyConditionsMet`; that status requires both limits and chronological
order. Even that status concerns these numeric checks under the named policy,
not complete regulatory compliance.

`Policy_Plans.thy` installs a dedicated carrier into the existing
`typed_plan_bundle`. Policy reports are not ordinary linear quantities and are
not silently coerced into them.

## Repairs to source behavior

The source audit and actual Python observation identify three intentional
repairs. AQI uses exact truncation and half-up interpolation without the source's
floating epsilon. Occupancy uses an exact ceiling without subtracting epsilon;
150.000000001 square feet at a factor of 150 yields 2, where upstream returns 1.
Cooling with only a five-hour total has an unresolved first-stage condition;
it cannot inherit the source's total-only `True` as complete compliance.
The selected [FDA 2022 document, section 3-501.14(A), PDF page 92](https://www.fda.gov/files/food/published/FDA-FoodCode2022-FullDocument-01182023_0.pdf#page=92)
also confirms that the second requirement is a six-hour total from 135 F,
rather than a separate four-hour interval after reaching 70 F. The applicable
food category and endpoint observations remain conditions of this calculation.

Run `python3 tests/families/domains/policies/observe_upstream.py` to reproduce
these upstream observations and compare all 33 native AQI rows and 12 occupancy
factors against the actual source module. This is source-behavior evidence, not an Isabelle
proof or the generated runtime check.

## Runtime and source ownership

`Policy_Bundle` supplies a fixed closed generated interpreter, an admitted
universal native contract, opaque instance/request/output handles, exact
executable/generation associations, bounded projection and release. It reuses
the existing structurally generic execution signature, not quantity semantics.
No supplied callback, source code or asserted receipt becomes execution authority.
The work charge scales quadratically with exact input syntax, including the bits
of natural literals. This is a conservative declared charge, not a speed claim.

`Policy_Service` reuses the existing native condition objects and verifies exact
IDs, full propositions, live development/source owners and original UTF-8 slices.
Equal bytes from another physical owner do not substitute for the original.
`Veri7vn_Scoped_Policy_Request` retains the existing request-scope child through
specialization and inspection; denial invalidates it. Snapshots are inert data
and are compared against reconstructed native objects, never trusted as proofs.
The existing `Veri7vn_Domain_Ticket_Execution_Fn` is structurally usable with the
policy execution module; it enforces the same one-shot charged worker boundary.
This reuse currently brings the quantity bundle/service dependency into the
policy service; it does not claim quantity coverage for these operations.

## Evidence and remaining integration

The first actual pure-semantics check (`576f9a27f04b44dca236b009429384d4`) failed
on a natural-order proof normalization and an imported-name collision for the
binder `total`. Both received bounded source repairs; retry is queued with the
shared build steward. No native or runtime PASS is claimed yet. The pure
three-theory target is separate from the service/display dependency closure. `Policy_Examples` contains kernel `code_simp` refuting lemmas;
`Policy_Runtime_Checks` exercises the actual opaque generated interpreter;
`Policy_Scoped_Checks` exercises original-source/request identity, snapshots,
cross-request rejection, cancellation cleanup and scope denial.

The shared resident sum/host producer still needs this leaf connected through
actual operation installation, durable charge, acceptance, checked display,
retained recovery and workbench inspection. The family-owned fixed
`Policy_Checked_Display` and scope-aware `Policy_Native_Gate` now provide the
closed bounded escaped sentence and same-request native association; these
remain drafts until native/runtime qualification. The gate retains the scoped
request and rejects access after parent denial. It keeps admitted universal
execution/rendering contracts distinct from a kernel theorem of the answer. A snapshot shape alone does not
establish that recovery. Author-defined editable tables, supplied occupancy
factor recipes, AQI aggregate/category operations, remaining cooling/holding/
cooking/date-marking operations and full source-import lifecycle remain explicit
open breadth. The initial three rule families do not close the whole migration.
